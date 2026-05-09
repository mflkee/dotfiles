#!/usr/bin/env python3
"""
TUI - Text User Interface для awgq
Простая версия с input() вместо select
"""

import time
import sys
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from rich import box

class TUI:
    def __init__(self, vpn_manager, tailscale_manager, route_manager, config_manager, logger):
        self.vpn = vpn_manager
        self.tailscale = tailscale_manager
        self.routes = route_manager
        self.config = config_manager
        self.logger = logger
        self.console = Console()
        self.running = False
    
    def _show_status(self):
        """Показать статус"""
        # VPN статус
        vpn_status = self.vpn.get_status()
        
        # Tailscale статус
        ts_status = self.tailscale.status()
        
        # Маршрут
        route = self.routes.get_route("100.80.114.18")
        
        # Создаём таблицу
        table = Table(title="awgq Status", box=box.ROUNDED)
        table.add_column("Service", style="cyan")
        table.add_column("Status", style="green")
        table.add_column("Details", style="yellow")
        
        # VPN
        if vpn_status["active"]:
            table.add_row("VPN", "🟢 ON", f"{vpn_status['interface']} | {vpn_status['ip'] or 'N/A'}")
        else:
            table.add_row("VPN", "🔴 OFF", "-")
        
        # Tailscale
        if ts_status["active"]:
            table.add_row("Tailscale", "🟢 ON", f"IP: {ts_status['ip'] or 'N/A'}")
        else:
            table.add_row("Tailscale", "🔴 OFF", "-")
        
        # Route
        route_line = route.strip().split('\n')[0]
        table.add_row("Route to mkair", "📡", route_line)
        
        # Info
        table.add_row("Profile", "⚙️", self.config.current_profile)
        table.add_row("Mode", "🔄", "full")
        
        self.console.print(table)
    
    def _show_configs(self):
        """Показать список конфигов"""
        configs = self.config.get_configs()
        
        table = Table(title="AWG Configs", box=box.ROUNDED)
        table.add_column("Name", style="cyan")
        table.add_column("Description", style="green")
        table.add_column("File", style="yellow")
        
        for name, c in configs.items():
            marker = " *" if name == "awg0" else ""
            table.add_row(f"{name}{marker}", c.get('description', ''), c.get('file', 'N/A'))
        
        self.console.print(table)
    
    def _show_menu(self):
        """Показать меню с учётом текущего статуса"""
        vpn_status = self.vpn.get_status()
        vpn_action = "OFF" if vpn_status["active"] else "ON"
        
        menu = Panel(
            f"[1] Turn VPN {vpn_action}\n"
            "[2] Select Config\n"
            "[3] Import Config\n"
            "[4] Fix Tailscale Routes\n"
            "[5] Test Connectivity\n"
            "[6] Show Logs\n"
            "[7] Run Tests\n"
            "[c] Show Configs\n"
            "[s] Show Status\n"
            "[q] Quit",
            title="Commands",
            border_style="green"
        )
        self.console.print(menu)
    
    def _select_config(self):
        """Выбрать конфиг для подключения"""
        configs = self.config.get_configs()
        
        if not configs:
            self.console.print("[red]No configs available![/red]")
            return None
        
        self.console.print("[cyan]Available configs:[/cyan]")
        config_list = list(configs.keys())
        for i, name in enumerate(config_list, 1):
            c = configs[name]
            self.console.print(f"  [{i}] {name} - {c.get('description', '')}")
        
        try:
            choice = input("\nSelect config (number): ").strip()
            idx = int(choice) - 1
            if 0 <= idx < len(config_list):
                return config_list[idx]
            else:
                self.console.print("[red]Invalid selection[/red]")
                return None
        except ValueError:
            self.console.print("[red]Please enter a number[/red]")
            return None
    
    def _handle_command(self, cmd: str):
        """Обработать команду"""
        if cmd == '1':
            vpn_status = self.vpn.get_status()
            action = "OFF" if vpn_status["active"] else "ON"
            self.console.print(f"[yellow]Turning VPN {action}...[/yellow]")
            
            if vpn_status["active"]:
                # Выключить текущий VPN
                self.vpn.stop("awg-quick@wg0.service")
            else:
                # Включить с выбором конфига
                selected = self._select_config()
                if selected:
                    unit = f"awg-quick@{selected}.service"
                    self.vpn.start(unit)
                    time.sleep(5)
                    self.tailscale.fix_routes()
            
            time.sleep(2)
            self._show_status()
            
        elif cmd == '2':
            self.console.print("[yellow]Select config to activate:[/yellow]")
            selected = self._select_config()
            if selected:
                # Сначала выключаем текущий
                self.vpn.stop("awg-quick@wg0.service")
                time.sleep(2)
                # Включаем новый
                unit = f"awg-quick@{selected}.service"
                self.console.print(f"[green]Starting {selected}...[/green]")
                self.vpn.start(unit)
                time.sleep(5)
                self.tailscale.fix_routes()
                self._show_status()
            
        elif cmd == '3':
            self.console.print("[yellow]Import config from file:[/yellow]")
            file_path = input("Path to config file: ").strip()
            name = input("Config name (optional): ").strip() or None
            
            try:
                imported = self.config.import_config(file_path, name)
                self.console.print(f"[green]✓ Config imported as: {imported}[/green]")
            except FileNotFoundError:
                self.console.print(f"[red]Error: File not found: {file_path}[/red]")
            except PermissionError:
                self.console.print("[red]Error: Permission denied. Try with sudo?[/red]")
            except Exception as e:
                self.console.print(f"[red]Error: {e}[/red]")
            
        elif cmd == '4':
            self.console.print("[green]Fixing Tailscale routes...[/green]")
            self.tailscale.fix_routes()
            time.sleep(1)
            self._show_status()
            
        elif cmd == '5':
            self.console.print("[blue]Testing connectivity...[/blue]")
            result = self.routes.test_connectivity("100.80.114.18")
            if result["reachable"]:
                self.console.print(f"[green]✓ mkair-server reachable (latency: {result['latency']})[/green]")
            else:
                self.console.print("[red]✗ mkair-server not reachable[/red]")
            time.sleep(1)
            
        elif cmd == '6':
            self.logger.show(20)
            
        elif cmd == '7':
            self.console.print("[blue]Running tests...[/blue]")
            import subprocess
            import os
            project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            result = subprocess.run([sys.executable, "test-automation.py"], 
                                  cwd=project_dir)
            if result.returncode == 0:
                self.console.print("[green]✓ All tests passed![/green]")
            else:
                self.console.print("[red]✗ Some tests failed[/red]")
            
        elif cmd == 'c':
            self._show_configs()
        
        elif cmd == 's':
            self._show_status()
            
        elif cmd == 'q':
            self.running = False
            
        else:
            self.console.print("[yellow]Unknown command. Press s for status, q to quit.[/yellow]")
    
    def run(self):
        """Запустить TUI"""
        self.running = True
        
        self.console.print("[bold blue]awgq - VPN & Tailscale Manager[/bold blue]")
        self.console.print("[dim]Mode: full (only)[/dim]")
        self.console.print()
        
        # Показываем начальный статус
        self._show_status()
        self._show_menu()
        
        while self.running:
            try:
                # Читаем команду
                cmd = input("\nEnter command: ").strip().lower()
                
                if cmd:
                    self._handle_command(cmd)
                    
                    if self.running:
                        self._show_menu()
                        
            except KeyboardInterrupt:
                self.running = False
            except EOFError:
                # Non-interactive mode
                self.console.print("[yellow]Non-interactive mode detected. Use CLI commands.[/yellow]")
                self.running = False
        
        self.console.print("[green]awgq TUI exited[/green]")
