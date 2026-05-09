#!/usr/bin/env python3
"""
Route Manager - управление маршрутизацией и split tunneling
"""

import subprocess
import socket
from typing import List, Dict
from logger import Logger

class RouteManager:
    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger()
        self.vpn_table = "51820"
        self.main_table = "main"
    
    def _run(self, cmd: list, check: bool = True) -> subprocess.CompletedProcess:
        """Выполнить команду"""
        self.logger.debug(f"Running: {' '.join(cmd)}")
        return subprocess.run(cmd, capture_output=True, text=True, check=check)
    
    def resolve_domain(self, domain: str) -> List[str]:
        """Получить IP адреса домена"""
        try:
            # Используем gethostbyname_ex для получения всех IP
            _, _, ips = socket.gethostbyname_ex(domain)
            return ips
        except socket.gaierror:
            self.logger.warning(f"Could not resolve {domain}")
            return []
    
    def add_vpn_route(self, target: str, interface: str = "wg0"):
        """Добавить маршрут через VPN в таблицу main (не 51820)"""
        try:
            if self._is_ip(target):
                self._add_ip_route_main(target, interface)
            else:
                ips = self.resolve_domain(target)
                for ip in ips:
                    self._add_ip_route_main(ip, interface)
        except Exception as e:
            self.logger.error(f"Error adding route for {target}: {e}")
    
    def _is_ip(self, target: str) -> bool:
        """Проверить является ли строка IP адресом"""
        try:
            socket.inet_aton(target)
            return True
        except socket.error:
            return False
    
    def _add_ip_route_main(self, ip: str, interface: str):
        """Добавить маршрут в таблицу main через VPN интерфейс"""
        try:
            # Удаляем старый маршрут если есть
            self._run(
                ["sudo", "ip", "route", "del", ip],
                check=False
            )
            # Добавляем маршрут в таблицу main (не 51820!)
            self._run([
                "sudo", "ip", "route", "add", ip,
                "dev", interface
            ])
            self.logger.success(f"Route added: {ip} via {interface} (table main)")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to add route for {ip}: {e.stderr}")
    
    def add_bypass_route(self, network: str):
        """Добавить маршрут для обхода VPN (через основной шлюз)"""
        try:
            # Получаем основной шлюз
            result = self._run(["ip", "route", "show", "default"], check=False)
            if result.returncode != 0:
                self.logger.error("Could not find default gateway")
                return
            
            # Парсим шлюз
            parts = result.stdout.strip().split()
            gateway = None
            dev = None
            for i, part in enumerate(parts):
                if part == "via" and i + 1 < len(parts):
                    gateway = parts[i + 1]
                elif part == "dev" and i + 1 < len(parts):
                    dev = parts[i + 1]
            
            if not gateway:
                self.logger.error("Could not parse gateway")
                return
            
            # Добавляем маршрут через основной шлюз (table main)
            cmd = ["sudo", "ip", "route", "add", network]
            if gateway:
                cmd.extend(["via", gateway])
            if dev:
                cmd.extend(["dev", dev])
            cmd.extend(["table", self.main_table])
            
            self._run(cmd, check=False)
            self.logger.success(f"Bypass route added: {network} via {gateway}")
            
        except Exception as e:
            self.logger.error(f"Error adding bypass route: {e}")
    
    def apply_mode(self, mode: str, profile_config: Dict):
        """Применить режим маршрутизации"""
        routes_config = profile_config.get("routes", {})
        vpn_domains = routes_config.get("vpn_domains", [])
        vpn_networks = routes_config.get("vpn_networks", [])
        bypass_networks = routes_config.get("bypass_networks", [])
        
        self.logger.info(f"Applying mode: {mode}")
        
        if mode == "full":
            self.logger.info("Full mode: all traffic through VPN")
            # Удаляем bypass маршруты
            for network in bypass_networks:
                self._run(
                    ["sudo", "ip", "route", "del", network, "table", self.main_table],
                    check=False
                )
            
        elif mode == "split":
            self.logger.info(f"Split mode: {len(vpn_domains)} domains through VPN")
            
            # Добавляем маршруты для доменов в таблицу main (не 51820!)
            for domain in vpn_domains:
                self.add_vpn_route(domain)
            
            # Добавляем bypass для локальных сетей
            for network in bypass_networks:
                self.add_bypass_route(network)
            
            # Добавляем bypass для tailscale
            self.add_bypass_route("100.64.0.0/10")
            
        elif mode == "bypass":
            self.logger.info("Bypass mode: minimal VPN routing")
            for network in vpn_networks:
                self._add_ip_route_main(network, "wg0")
            
        elif mode == "direct":
            self.logger.info("Direct mode: no VPN")
            pass
        
        self.logger.success(f"Mode {mode} applied successfully")
    
    def get_route(self, target: str) -> str:
        """Получить текущий маршрут до цели"""
        try:
            result = self._run(["ip", "route", "get", target], check=False)
            if result.returncode == 0:
                return result.stdout
            return f"No route to {target}"
        except Exception as e:
            return f"Error: {e}"
    
    def test_connectivity(self, target: str = "100.80.114.18", count: int = 3) -> Dict:
        """Проверить доступность цели"""
        try:
            result = self._run(
                ["ping", "-c", str(count), "-W", "2", target],
                check=False
            )
            
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'avg' in line:
                        parts = line.split('/')
                        if len(parts) > 4:
                            latency = parts[4]
                            return {
                                "reachable": True,
                                "latency": f"{latency}ms",
                                "target": target
                            }
                
                return {
                    "reachable": True,
                    "latency": "unknown",
                    "target": target
                }
            else:
                return {
                    "reachable": False,
                    "latency": None,
                    "target": target
                }
                
        except Exception as e:
            return {
                "reachable": False,
                "latency": None,
                "target": target,
                "error": str(e)
            }
    
    def list_routes(self):
        """Показать текущие маршруты"""
        self.logger.info("\n=== VPN Routes (table main with dev wg0) ===")
        result = self._run(["ip", "route", "show", "table", self.main_table], check=False)
        if result.stdout:
            # Фильтруем только маршруты через wg0
            for line in result.stdout.split('\n'):
                if 'wg0' in line and 'default' not in line:
                    print(line)
        else:
            print("No routes")
        
        self.logger.info("\n=== Bypass Routes ===")
        result = self._run(["ip", "route", "show", "table", self.main_table], check=False)
        if result.stdout:
            for line in result.stdout.split('\n'):
                if 'via' in line and 'wg0' not in line and 'default' not in line:
                    print(line)
        else:
            print("No routes")
        
        self.logger.info("\n=== IP Rules ===")
        result = self._run(["ip", "rule", "show"], check=False)
        if result.stdout:
            print(result.stdout)
        else:
            print("No rules")
