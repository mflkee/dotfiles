"""
VPN Manager - управление VPN через systemd
"""

import subprocess
import time
from typing import Dict, Optional
from logger import Logger

class VPNManager:
    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger()
    
    def _run(self, cmd: list, check: bool = True) -> subprocess.CompletedProcess:
        """Выполнить команду"""
        self.logger.debug(f"Running: {' '.join(cmd)}")
        return subprocess.run(cmd, capture_output=True, text=True, check=check)
    
    def is_active(self, unit: str = "awg-quick@wg0.service") -> bool:
        """Проверить активность VPN"""
        try:
            result = self._run(["systemctl", "is-active", "--quiet", unit], check=False)
            return result.returncode == 0
        except Exception:
            return False
    
    def start(self, unit: str = "awg-quick@wg0.service"):
        """Запустить VPN"""
        self.logger.info(f"Starting VPN: {unit}")
        try:
            self._run(["sudo", "systemctl", "start", unit])
            time.sleep(2)  # Ждём инициализации
            
            if self.is_active(unit):
                self.logger.success(f"VPN {unit} started successfully")
                return True
            else:
                self.logger.error(f"Failed to start VPN {unit}")
                return False
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error starting VPN: {e.stderr}")
            return False
    
    def stop(self, unit: str = "awg-quick@wg0.service"):
        """Остановить VPN"""
        self.logger.info(f"Stopping VPN: {unit}")
        try:
            self._run(["sudo", "systemctl", "stop", unit])
            self.logger.success(f"VPN {unit} stopped")
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error stopping VPN: {e.stderr}")
            return False
    
    def restart(self, unit: str = "awg-quick@wg0.service"):
        """Перезапустить VPN"""
        self.logger.info(f"Restarting VPN: {unit}")
        try:
            self._run(["sudo", "systemctl", "restart", unit])
            time.sleep(2)
            
            if self.is_active(unit):
                self.logger.success(f"VPN {unit} restarted successfully")
                return True
            else:
                self.logger.error(f"Failed to restart VPN {unit}")
                return False
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error restarting VPN: {e.stderr}")
            return False
    
    def toggle(self, unit: str = "awg-quick@wg0.service"):
        """Переключить VPN"""
        if self.is_active(unit):
            return self.stop(unit)
        else:
            return self.start(unit)
    
    def get_status(self, unit: str = "awg-quick@wg0.service") -> Dict:
        """Получить статус VPN"""
        status = {
            "active": False,
            "unit": unit,
            "ip": None,
            "interface": None
        }
        
        try:
            # Проверяем активность
            status["active"] = self.is_active(unit)
            
            # Получаем IP интерфейса
            interface = unit.split('@')[1].replace('.service', '') if '@' in unit else 'wg0'
            status["interface"] = interface
            
            result = self._run(["ip", "addr", "show", interface], check=False)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'inet ' in line:
                        status["ip"] = line.split()[1].split('/')[0]
                        break
            
        except Exception as e:
            self.logger.error(f"Error getting VPN status: {e}")
        
        return status
    
    def monitor(self, unit: str = "awg-quick@wg0.service"):
        """Мониторинг VPN в реальном времени"""
        import select
        import sys
        
        self.logger.info("Starting VPN monitor (press Ctrl+C to stop)")
        
        try:
            while True:
                status = self.get_status(unit)
                active = "🟢 ON" if status["active"] else "🔴 OFF"
                ip = status["ip"] or "N/A"
                
                print(f"\rVPN: {active} | IP: {ip} | Interface: {status['interface']}", end='', flush=True)
                
                # Проверяем нажатие клавиши
                if select.select([sys.stdin], [], [], 0)[0]:
                    if sys.stdin.read(1) == '\n':
                        break
                
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        
        print()  # Новая строка после выхода
