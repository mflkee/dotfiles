#!/usr/bin/env bash
set -euo pipefail

# --- Настройки/переменные ---
TARGET_USER="${SUDO_USER:-${USER}}"
if [[ "$TARGET_USER" == "root" ]]; then
  echo "❌ Запусти скрипт так: из-под своего пользователя -> sudo ./setup-syncthing.sh"
  exit 1
fi

USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config/syncthing"
CONFIG_XML="$CONFIG_DIR/config.xml"

# Определяем основной IPv4 для LAN (не 127.0.0.1)
LAN_IP="$(ip -4 -o addr show scope global | awk '{print $4}' | head -n1 | cut -d/ -f1 || true)"
if [[ -z "${LAN_IP}" ]]; then
  # fallback — оставим 0.0.0.0, если вдруг не нашли адрес интерфейса
  LAN_IP="0.0.0.0"
fi

# Определяем CIDR локальной сети для firewall (первый глобальный адрес)
LAN_CIDR="$(ip -4 -o addr show scope global | awk '{print $4}' | head -n1 || true)"

echo "==> Используем пользователя: $TARGET_USER"
echo "==> Домашний каталог:        $USER_HOME"
echo "==> LAN IP для GUI:          $LAN_IP:8384"
echo "==> CIDR для UFW:            ${LAN_CIDR:-не найден}"

# --- 1) Обновление и установка пакетов ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release \
  openssh-server ufw syncthing

# --- 2) Включаем SSH (на случай, если не включен) ---
systemctl enable --now ssh

# --- 3) Включаем Syncthing как user service ---
# Обеспечим права на каталог конфигов
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$CONFIG_DIR"

# Запуск и автозапуск сервиса под целевым пользователем
systemctl enable "syncthing@${TARGET_USER}.service"
systemctl start  "syncthing@${TARGET_USER}.service"

# --- 4) Ждём, пока Syncthing создаст config.xml ---
echo "==> Ждём появления $CONFIG_XML ..."
for i in {1..60}; do
  [[ -f "$CONFIG_XML" ]] && break
  sleep 1
done
if [[ ! -f "$CONFIG_XML" ]]; then
  echo "❌ Не найден $CONFIG_XML. Проверь: systemctl status syncthing@${TARGET_USER}"
  exit 1
fi

# --- 5) Меняем GUI адрес на LAN_IP:8384 ---
# По умолчанию там 127.0.0.1:8384 — меняем на <LAN_IP>:8384 (или 0.0.0.0:8384, если IP не нашли)
echo "==> Обновляем адрес GUI в $CONFIG_XML ..."
# Резервная копия
cp -a "$CONFIG_XML" "$CONFIG_XML.bak.$(date +%s)"

# Заменяем только текущий address="127.0.0.1:8384" (или что там стоит) на нужный
# Небольшой sed-хак: заменим содержимое атрибута address у <gui ...>.
# Сначала пытаемся точечно:
if grep -q '<gui ' "$CONFIG_XML"; then
  sed -i -E "s#(<gui[^>]*address=\")([^\"]+)(\"[^>]*>)#\1${LAN_IP}:8384\3#g" "$CONFIG_XML"
else
  # В редких случаях блок может отличаться; грубая подстановка:
  sed -i "s/127.0.0.1:8384/${LAN_IP}:8384/g" "$CONFIG_XML" || true
fi

# --- 6) Перезапускаем Syncthing для применения настроек ---
systemctl restart "syncthing@${TARGET_USER}.service"

# --- 7) Настраиваем firewall (UFW) ---
echo "==> Настраиваем UFW (аккуратно, чтобы не закрыть доступ по SSH)..."
ufw --force reset || true
ufw default deny incoming
ufw default allow outgoing

# Разрешаем SSH всем из LAN (и вообще, чтобы не отрезать текущую сессию)
ufw allow ssh

# Разрешаем доступ к GUI Syncthing только из локальной сети (если CIDR известен),
# иначе откроем на весь интерфейс — при необходимости сузишь позже.
if [[ -n "${LAN_CIDR:-}" ]]; then
  ufw allow from "$LAN_CIDR" to any port 8384 proto tcp
  ufw allow from "$LAN_CIDR" to any port 22000 proto tcp
  ufw allow from "$LAN_CIDR" to any port 21027 proto udp
else
  ufw allow 8384/tcp
  ufw allow 22000/tcp
  ufw allow 21027/udp
fi

ufw --force enable

# --- 8) Вывод справки ---
cat <<EOF

✅ Готово!

• Сервис Syncthing запущен под пользователем: ${TARGET_USER}
• Веб-интерфейс:   http://${LAN_IP}:8384
• Конфиг:          ${CONFIG_XML}
• Порты:
    - 8384/tcp (GUI)
    - 22000/tcp (Data)
    - 21027/udp (Local discovery)

🔐 Рекомендую сразу включить авторизацию в GUI:
   Actions → Settings → GUI → set Username/Password → Save → Restart

ℹ️ Управление сервисом:
   systemctl status  syncthing@${TARGET_USER}
   systemctl restart syncthing@${TARGET_USER}
   systemctl stop    syncthing@${TARGET_USER}

Если веб не открывается, проверь IP:  ip -4 addr | grep inet
EOF

