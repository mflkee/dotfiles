"""
Tailscale Manager - управление Tailscale и маршрутизацией
Альтернативный подход: используем from (source IP) правило вместо to
"""

import subprocess
import re
from typing import Dict, Optional, List
from logger import Logger

class TailscaleManager:
    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger()
        self.tailnet_cidr = "100.64.0.0/10"
        self.tailscale_table = "52"
        # Используем from правило вместо to
        # from all to 100.64.0.0/10 lookup 52
        # Но AWG перехватывает to правила
        # Попробуем from tailscale0 интерфейс
        self.tailscale_rule_pref = "1000"  # Высокий номер, но с from iif
        self.tailscale_fwmark = "0x80000/0xff0000"
        self.tailscale_fwmark_rule_pref = "85"
        self.awg_table = "51820"
        self.old_tailscale_rule_prefs: List[str] = ["5", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55", "70", "80", "85", "90", "100", "5190", "5200", "5210", "5230", "5250"]
    
    def _run(self, cmd: list, check: bool = True) -> subprocess.CompletedProcess:
        """Выполнить команду"""
        self.logger.debug(f"Running: {' '.join(cmd)}")
        return subprocess.run(cmd, capture_output=True, text=True, check=check)
    
    def _get_ip_rules(self) -> List[Dict]:
        """Парсить вывод `ip rule show` в список правил"""
        result = self._run(["ip", "rule", "show"], check=False)
        rules = []
        if result.returncode != 0:
            return rules
        for line in result.stdout.strip().splitlines():
            # Формат: "priority: rule text"
            match = re.match(r"^(\d+):\s+(.+)$", line.strip())
            if match:
                rules.append({
                    "priority": int(match.group(1)),
                    "text": match.group(2).strip()
                })
        return rules
    
    def _find_awg_min_priority(self) -> Optional[int]:
        """Найти минимальный приоритет среди всех AWG правил"""
        rules = self._get_ip_rules()
        awg_priorities = []
        for rule in rules:
            text = rule["text"]
            if f"lookup {self.awg_table}" in text or "suppress_prefixlength" in text:
                awg_priorities.append(rule["priority"])
        return min(awg_priorities) if awg_priorities else None
    
    def _find_tailnet_rule_priorities(self) -> List[int]:
        """Найти все приоритеты правил Tailscale to 100.64.0.0/10"""
        rules = self._get_ip_rules()
        prefs = []
        for rule in rules:
            if f"to {self.tailnet_cidr} lookup {self.tailscale_table}" in rule["text"]:
                prefs.append(rule["priority"])
        return prefs
    
    def _flush_route_cache(self):
        """Сбросить кэш маршрутов"""
        self._run(["sudo", "ip", "route", "flush", "cache"], check=False)
    
    def status(self) -> Dict:
        """Получить статус Tailscale"""
        result = self._run(["tailscale", "status"], check=False)
        
        # Проверяем что tailscale0 интерфейс существует и имеет IP
        iface_result = self._run(["ip", "addr", "show", "tailscale0"], check=False)
        has_ip = "inet " in iface_result.stdout if result.returncode == 0 else False
        
        # Получаем Tailscale IP
        ip_result = self._run(["tailscale", "ip", "-4"], check=False)
        ts_ip = ip_result.stdout.strip() if ip_result.returncode == 0 else None
        
        # Проверяем активность сервиса
        service_result = self._run(["systemctl", "is-active", "tailscaled"], check=False)
        is_active = service_result.returncode == 0
        
        return {
            "active": is_active and has_ip,
            "ip": ts_ip,
            "has_ip": has_ip,
            "service_active": is_active
        }
    
    def fix_routes(self, target: str = "100.80.114.18"):
        """Применить fix маршрутизации Tailscale"""
        self.logger.info("Applying Tailscale route fix")
        
        try:
            # Находим минимальный приоритет AWG правил
            awg_min_priority = self._find_awg_min_priority()
            if awg_min_priority is not None:
                # Tailnet правило должно быть ВЫШЕ ВСЕХ AWG правил (меньше число = выше)
                tailnet_priority = awg_min_priority - 1
                while tailnet_priority > 0:
                    if not any(r["priority"] == tailnet_priority for r in self._get_ip_rules()):
                        break
                    tailnet_priority -= 1
                tailnet_priority = max(0, tailnet_priority)
                self.logger.info(f"AWG rules start at priority {awg_min_priority}, "
                                 f"placing Tailscale tailnet rule at priority {tailnet_priority}")
            else:
                tailnet_priority = 10
                self.logger.info("AWG rule not found, using default priority 10")
            
            # Удаляем ВСЕ старые tailnet правила (включая динамические)
            existing_tailnet_prefs = self._find_tailnet_rule_priorities()
            for pref in existing_tailnet_prefs:
                self._run(
                    ["sudo", "ip", "rule", "del", "pref", str(pref)],
                    check=False
                )
            
            # Удаляем остальные старые правила
            for old_pref in self.old_tailscale_rule_prefs:
                self._run(
                    ["sudo", "ip", "rule", "del", "pref", old_pref],
                    check=False
                )
            
            # Удаляем существующие правила
            self._run(
                ["sudo", "ip", "rule", "del", "pref", self.tailscale_fwmark_rule_pref],
                check=False
            )
            self._run(
                ["sudo", "ip", "rule", "del", "pref", self.tailscale_rule_pref],
                check=False
            )
            self._run(
                ["sudo", "ip", "rule", "del", "pref", "999"],
                check=False
            )
            
            # Получаем tailscale IP
            ts_status = self.status()
            ts_ip = ts_status.get("ip")
            
            if not ts_ip:
                self.logger.error("Tailscale IP not available")
                return False
            
            # Добавляем to правило: пакеты К tailnet идут в table 52
            # Должно быть ВЫШЕ ВСЕХ AWG правил
            self._run([
                "sudo", "ip", "rule", "add", "pref", str(tailnet_priority),
                "to", self.tailnet_cidr, "lookup", self.tailscale_table
            ])
            
            # Добавляем fwmark правило: tailscale control plane через VPN (AWG table)
            # Это предотвращает отправку tailscale-контрола напрямую (заблокировано в РФ)
            self._run([
                "sudo", "ip", "rule", "add", "pref", self.tailscale_fwmark_rule_pref,
                "fwmark", self.tailscale_fwmark, "lookup", self.awg_table
            ], check=False)
            
            # Добавляем from правило: пакеты ОТ tailscale IP идут в table 52
            self._run([
                "sudo", "ip", "rule", "add", "pref", self.tailscale_rule_pref,
                "from", ts_ip, "lookup", self.tailscale_table
            ])
            
            # Добавляем iif правило: пакеты с tailscale0 идут в table 52
            self._run([
                "sudo", "ip", "rule", "add", "pref", "999",
                "iif", "tailscale0", "lookup", self.tailscale_table
            ], check=False)
            
            # Сбрасываем кэш маршрутов, иначе старый маршрут может остаться
            self._flush_route_cache()
            
            # Проверяем маршрут
            result = self._run(["ip", "route", "get", target], check=False)
            if result.returncode == 0:
                route = result.stdout.strip()
                self.logger.success(f"Tailscale route fix applied: {route}")
                
                if "tailscale0" in route:
                    self.logger.success("✅ Route goes through tailscale0")
                elif "wg0" in route:
                    self.logger.warning("⚠️ Route goes through wg0 (VPN), not tailscale0")
                
                return True
            else:
                self.logger.error("Failed to apply Tailscale route fix")
                return False
                
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error fixing Tailscale routes: {e.stderr}")
            return False
    
    def unfix_routes(self):
        """Убрать fix маршрутизации"""
        self.logger.info("Removing Tailscale route fix")
        
        try:
            # Удаляем все tailnet правила
            existing_tailnet_prefs = self._find_tailnet_rule_priorities()
            for pref in existing_tailnet_prefs:
                self._run(
                    ["sudo", "ip", "rule", "del", "pref", str(pref)],
                    check=False
                )
            
            self._run(
                ["sudo", "ip", "rule", "del", "pref", self.tailscale_fwmark_rule_pref],
                check=False
            )
            self._run(
                ["sudo", "ip", "rule", "del", "pref", self.tailscale_rule_pref],
                check=False
            )
            self._run(
                ["sudo", "ip", "rule", "del", "pref", "999"],
                check=False
            )
            
            self._flush_route_cache()
            
            self.logger.success("Tailscale route fix removed")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error removing Tailscale routes: {e.stderr}")
            return False
    
    def is_active(self) -> bool:
        """Проверить активность Tailscale"""
        status = self.status()
        return status["active"]
