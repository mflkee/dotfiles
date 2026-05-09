# awgq v2 - Тестовый мануал

## Установка

```bash
cd ~/projects/awgq
pip install -r requirements.txt
```

## Тест-кейсы

### Кейс 1: Базовый статус
```bash
python awgq status
```

**Ожидаемый результат:**
```
VPN: ON/OFF
  Interface: wg0
  IP: 10.110.236.62
Tailscale: ON
  IP: 100.104.105.63
Profile: default
Mode: split
Route to mkair-server:
100.80.114.18 dev tailscale0 table 52 src 100.104.105.63
```

**Проверить:**
- [ ] VPN показывает правильный статус
- [ ] Tailscale показывает IP
- [ ] Маршрут идёт через tailscale0 (не wg0)
- [ ] Профиль и режим отображаются

---

### Кейс 2: Переключение режимов
```bash
# Проверяем текущий режим
python awgq status | grep Mode

# Меняем режимы
python awgq mode full
python awgq status | grep Mode

python awgq mode split
python awgq status | grep Mode

python awgq mode bypass
python awgq status | grep Mode

python awgq mode direct
python awgq status | grep Mode
```

**Ожидаемый результат:**
- Режим меняется в конфиге
- При активном VPN применяются маршруты

**Проверить:**
- [ ] Режим сохраняется в ~/.config/awgq/config.yaml
- [ ] Маршруты меняются при смене режима

---

### Кейс 3: Управление VPN
```bash
# Выключить VPN
python awgq off
python awgq status

# Включить VPN (автоматически применит tailscale fix)
python awgq on
python awgq status

# Проверить маршрут
python awgq route 100.80.114.18
```

**Ожидаемый результат:**
- VPN включается/выключается
- При включении автоматически `ts-fix`
- Маршрут через tailscale0

**Проверить:**
- [ ] awgq off останавливает VPN
- [ ] awgq on запускает VPN
- [ ] После awgq on маршрут через tailscale0
- [ ] awgq route показывает правильный путь

---

### Кейс 4: Tailscale fix/unfix
```bash
# Проверить текущий маршрут
python awgq route 100.80.114.18

# Убрать fix
python awgq tailscale unfix
python awgq route 100.80.114.18

# Применить fix
python awgq tailscale fix
python awgq route 100.80.114.18
```

**Ожидаемый результат:**
- Без fix: маршрут через wg0
- С fix: маршрут через tailscale0

**Проверить:**
- [ ] unfix → маршрут через wg0
- [ ] fix → маршрут через tailscale0

---

### Кейс 5: Профили
```bash
# Список профилей
python awgq profile list

# Добавить профиль
python awgq profile add
# Вводим имя: test

# Переключиться
python awgq profile use
# Вводим имя: test

# Проверить
python awgq status | grep Profile

# Вернуть default
python awgq profile use
# Вводим имя: default
```

**Проверить:**
- [ ] Профиль создаётся
- [ ] Профиль переключается
- [ ] Конфиг сохраняется

---

## Проверка конфига

```bash
cat ~/.config/awgq/config.yaml
```

Должен содержать:
```yaml
current_profile: default
mode: split
profiles:
  default:
    vpn:
      type: awg
      interface: wg0
      unit: awg-quick@wg0.service
    routes:
      vpn_domains:
        - telegram.org
        - youtube.com
        - instagram.com
      bypass_networks:
        - 100.64.0.0/10
        - 192.168.0.0/16
    tailscale:
      enabled: true
      fix_routes: true
```

---

## Если что-то не работает

### VPN не запускается
```bash
sudo systemctl status awg-quick@wg0.service
sudo journalctl -u awg-quick@wg0.service -n 20
```

### Tailscale не работает
```bash
sudo systemctl status tailscaled
ip rule show | grep tailscale
ip route get 100.80.114.18
```

### awgq падает с ошибкой
```bash
python awgq status 2>&1
# Присылай ошибку
```

---

## После тестирования

Отправь результаты:
1. Что работает ✅
2. Что не работает ❌
3. Что нужно доработать 🔧

Потом делаем TUI под это!
