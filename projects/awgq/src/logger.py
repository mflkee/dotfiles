#!/usr/bin/env python3
"""
Logger - цветное логирование с записью в файл
"""

import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

class Logger:
    def __init__(self, verbose: bool = False, log_file: Optional[str] = None):
        self.verbose = verbose
        self.log_file = log_file or str(Path.home() / ".local" / "share" / "kimi" / "logs" / "awgq.log")
        
        # Создаём директорию для логов если нужно
        log_dir = Path(self.log_file).parent
        log_dir.mkdir(parents=True, exist_ok=True)
    
    def _write_to_file(self, level: str, message: str):
        """Записать в файл логов"""
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            with open(self.log_file, 'a') as f:
                f.write(f"{timestamp} [{level}] {message}\n")
        except Exception:
            pass  # Не критично если файл недоступен
    
    def _log(self, level: str, message: str, color: str):
        """Вывести сообщение"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        formatted = f"{timestamp} [{level}] {message}"
        
        # Цветной вывод в терминал
        colors = {
            "INFO": "\033[36m",    # Cyan
            "OK": "\033[32m",      # Green
            "WARN": "\033[33m",    # Yellow
            "ERROR": "\033[31m",   # Red
            "DEBUG": "\033[90m",   # Gray
            "RESET": "\033[0m"
        }
        
        color_code = colors.get(level, "")
        reset = colors["RESET"]
        
        print(f"{color_code}{formatted}{reset}")
        
        # Записываем в файл
        self._write_to_file(level, message)
    
    def info(self, message: str):
        """Информационное сообщение"""
        self._log("INFO", message, "cyan")
    
    def success(self, message: str):
        """Успешное действие"""
        self._log("OK", message, "green")
    
    def warning(self, message: str):
        """Предупреждение"""
        self._log("WARN", message, "yellow")
    
    def error(self, message: str):
        """Ошибка"""
        self._log("ERROR", message, "red")
    
    def debug(self, message: str):
        """Отладочное сообщение (только при verbose=True)"""
        if self.verbose:
            self._log("DEBUG", message, "gray")
    
    def show(self, lines: int = 50):
        """Показать последние строки логов"""
        try:
            if not Path(self.log_file).exists():
                print("No log file found")
                return
            
            with open(self.log_file, 'r') as f:
                all_lines = f.readlines()
                
            # Показываем последние N строк
            for line in all_lines[-lines:]:
                print(line.rstrip())
                
        except Exception as e:
            print(f"Error reading logs: {e}")
