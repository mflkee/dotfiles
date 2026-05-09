"""
Config Manager - управление профилями и конфигурацией awgq
"""

import yaml
import os
from pathlib import Path
from typing import Dict, List, Optional

class ConfigManager:
    def __init__(self, config_dir: str = None):
        self.config_dir = Path(config_dir or os.path.expanduser("~/.config/awgq"))
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.profiles_dir = self.config_dir / "profiles"
        self.profiles_dir.mkdir(exist_ok=True)
        self.config_file = self.config_dir / "config.yaml"
        
        # Загружаем или создаём дефолтный конфиг
        self.config = self._load_config()
    
    def _load_config(self) -> Dict:
        """Загрузить конфиг или создать дефолтный"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                return yaml.safe_load(f) or {}
        
        # Дефолтный конфиг (только full режим)
        default_config = {
            "current_profile": "default",
            "mode": "full",
            "profiles": {
                "default": {
                    "name": "Default Profile",
                    "vpn": {
                        "type": "amneziawg",
                        "interface": "wg0",
                        "configs": {
                            "awg0": {
                                "file": "/etc/amnezia/amneziawg/awg0.conf",
                                "description": "Основной конфиг"
                            },
                            "awg1": {
                                "file": "/etc/amnezia/amneziawg/awg1.conf",
                                "description": "Запасной конфиг"
                            }
                        },
                        "unit": "awg-quick@wg0.service"
                    },
                    "tailscale": {
                        "enabled": True,
                        "fix_routes": True
                    },
                    "servers": [
                        {"name": "mkair-server", "ip": "100.80.114.18", "description": "Tailscale server"},
                        {"name": "localhost", "ip": "127.0.0.1", "description": "Local test"}
                    ]
                }
            }
        }
        
        self._save_config(default_config)
        return default_config
    
    def _save_config(self, config: Dict = None):
        """Сохранить конфиг"""
        config = config or self.config
        with open(self.config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, allow_unicode=True)
    
    @property
    def current_profile(self) -> str:
        return self.config.get("current_profile", "default")
    
    def get_profile(self, name: str = None) -> Dict:
        """Получить профиль"""
        name = name or self.current_profile
        return self.config.get("profiles", {}).get(name, {})
    
    def list_profiles(self) -> List[str]:
        """Список профилей"""
        return list(self.config.get("profiles", {}).keys())
    
    def add_profile(self, name: str, base_profile: str = None):
        """Добавить профиль"""
        profiles = self.config.setdefault("profiles", {})
        
        if base_profile and base_profile in profiles:
            # Копируем существующий профиль
            import copy
            profiles[name] = copy.deepcopy(profiles[base_profile])
        else:
            # Создаём новый пустой профиль
            profiles[name] = {
                "vpn": {"type": "awg", "interface": "wg0", "unit": f"awg-quick@{name}.service"},
                "routes": {"vpn_domains": [], "bypass_networks": ["100.64.0.0/10"]},
                "tailscale": {"enabled": True, "fix_routes": True}
            }
        
        self._save_config()
        return True
    
    def remove_profile(self, name: str):
        """Удалить профиль"""
        profiles = self.config.get("profiles", {})
        if name in profiles:
            del profiles[name]
            if self.current_profile == name:
                self.config["current_profile"] = "default"
            self._save_config()
            return True
        return False
    
    def set_profile(self, name: str):
        """Установить текущий профиль"""
        if name in self.config.get("profiles", {}):
            self.config["current_profile"] = name
            self._save_config()
            return True
        return False
    
    def get_mode(self) -> str:
        """Получить текущий режим маршрутизации"""
        return self.config.get("mode", "split")
    
    def set_mode(self, mode: str):
        """Установить режим маршрутизации"""
        valid_modes = ["full", "split", "bypass", "direct"]
        if mode in valid_modes:
            self.config["mode"] = mode
            self._save_config()
            return True
        return False
    
    def get_configs(self) -> Dict:
        """Получить список конфигов"""
        profile = self.get_profile()
        vpn = profile.get("vpn", {})
        return vpn.get("configs", {})
    
    def add_config(self, name: str, file_path: str, description: str = ""):
        """Добавить конфиг"""
        profile = self.get_profile()
        vpn = profile.setdefault("vpn", {})
        configs = vpn.setdefault("configs", {})
        
        configs[name] = {
            "file": file_path,
            "description": description or name
        }
        
        self._save_config()
        return True
    
    def remove_config(self, name: str):
        """Удалить конфиг"""
        profile = self.get_profile()
        vpn = profile.get("vpn", {})
        configs = vpn.get("configs", {})
        
        if name in configs:
            del configs[name]
            self._save_config()
            return True
        return False
    
    def import_config(self, source_path: str, name: str = None) -> str:
        """Импортировать конфиг из файла"""
        import shutil
        
        source = Path(source_path)
        if not source.exists():
            raise FileNotFoundError(f"File not found: {source_path}")
        
        # Определяем имя конфига
        if not name:
            name = source.stem  # имя без расширения
        
        # Копируем в /etc/amnezia/amneziawg/
        target_dir = Path("/etc/amnezia/amneziawg")
        target_dir.mkdir(parents=True, exist_ok=True)
        
        target = target_dir / f"{name}.conf"
        shutil.copy2(source, target)
        
        # Добавляем в конфиг
        self.add_config(name, str(target), f"Imported from {source.name}")
        
        return name
    
    def get_vpn_config(self) -> Dict:
        """Получить конфиг VPN для текущего профиля"""
        profile = self.get_profile()
        return profile.get("vpn", {})
    
    def get_routes_config(self) -> Dict:
        """Получить конфиг маршрутизации"""
        profile = self.get_profile()
        return profile.get("routes", {})
    
    def get_tailscale_config(self) -> Dict:
        """Получить конфиг Tailscale"""
        profile = self.get_profile()
        return profile.get("tailscale", {})
