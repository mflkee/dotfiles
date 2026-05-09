# awgq

Advanced WireGuard & Tailscale Manager

## Установка

```bash
# Клонировать репозиторий
git clone <repo> ~/projects/awgq
cd ~/projects/awgq

# Создать virtual environment
uv venv

# Установить зависимости
uv pip install pyyaml rich

# Сделать symlink для глобального доступа
ln -s ~/projects/awgq/awgq.sh ~/.local/bin/awgq
```

## Использование

### CLI

```bash
awgq on              # Включить VPN
awgq off             # Выключить VPN
awgq status          # Показать статус
awgq test            # Запустить тесты
awgq mode split      # Split tunneling
awgq tailscale fix   # Исправить маршруты tailscale
```

### TUI (интерактивный режим)

```bash
awgq tui
```

Команды в TUI:
- `1` — Toggle VPN
- `2` — Fix Tailscale Routes
- `3` — Change Mode
- `4` — Test Connectivity
- `5` — Show Logs
- `6` — Run Tests
- `s` — Show Status
- `q` — Quit

## Конфигурация

Конфиг хранится в `~/.config/awgq/config.yaml`

## Интеграция с chezmoi

```bash
# Добавить в chezmoi
chezmoi add ~/.local/bin/awgq
chezmoi add ~/projects/awgq
```

## Лицензия

MIT
