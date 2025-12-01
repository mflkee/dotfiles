#!/bin/bash

# Улучшенная версия скрипта обновления VPN-конфигураций с поддержкой выбора файла
# 
# Изменения между старыми и новыми конфигами:
# 
# Удаленные конфиги:
# - canada-chambly-routers
# - france-paris-s6
# - norway-asker-routers
# - norway-sandefjord-openvpn
# - norway-sandefjord-s3
# - sweden-stockholm-openvpn
# - sweden-stockholm-s10
# - ukraine-kyiv-l1
# - usa-clarks-summit-l1
# - united-kingdom-london-l1 (был заменен новой версией, но сохранился)
# 
# Новые конфиги:
# - hong-kong-central-district-s2
# - hungary-budapest-s4
# - hungary-budapest-s5
# - kazakhstan-almaty-slow2
# - netherlands-amsterdam-routers2
# - netherlands-amsterdam-s1
# - norway-sandefjord-routers
# - norway-sandefjord-s8
# - sweden-stockholm-routers2
# - sweden-vasteras-openvpn
# 
# Сохраненные специальные split-конфиги:
# - estonia-openai-split (маршрутизация для OpenAI)
# - netherlands-chatgpt-split (маршрутизация для ChatGPT)
# - norway-chatgpt-split (маршрутизация для ChatGPT)
# 
# Обновленные конфиги:
# - hungary-budapest-s2 (старый) -> hungary-budapest-s4, hungary-budapest-s5 (новые)

if [ "$1" = "--interactive" ]; then
    # Интерактивный режим - выбор архива через Rofi
    VPN_ARCHIVE=$(find ~/Downloads -name "hideme_*.zip" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.xz" 2>/dev/null | rofi -dmenu -p "Выберите VPN архив:")

    if [ -z "$VPN_ARCHIVE" ] || [ ! -f "$VPN_ARCHIVE" ]; then
        echo "Архив не выбран или не существует"
        exit 1
    fi
else
    if [ -z "$1" ]; then
        echo "Использование:"
        echo "  $0 <путь_к_архиву_с_vpn_конфигами>     # Прямое указание архива"
        echo "  $0 --interactive                       # Интерактивный выбор через Rofi"
        echo ""
        echo "Пример: $0 ~/Downloads/hideme_956278698472306(2).zip"
        exit 1
    fi

    VPN_ARCHIVE="$1"
fi

set -e  # Выход при ошибке

TEMP_DIR="/tmp/vpn_update_$(date +%s)"
BACKUP_DIR="$HOME/.config/vpn-manager-backup-$(date +%Y%m%d_%H%M%S)"

echo "Создание резервной копии..."
cp -r ~/.config/vpn-manager "$BACKUP_DIR"

echo "Создание временной директории: $TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Распаковка архива: $VPN_ARCHIVE"
if [[ "$VPN_ARCHIVE" == *.zip ]]; then
    unzip -q "$VPN_ARCHIVE" -d "$TEMP_DIR"
elif [[ "$VPN_ARCHIVE" == *.tar.gz || "$VPN_ARCHIVE" == *.tgz ]]; then
    tar -xzf "$VPN_ARCHIVE" -C "$TEMP_DIR"
elif [[ "$VPN_ARCHIVE" == *.tar.xz ]]; then
    tar -xJf "$VPN_ARCHIVE" -C "$TEMP_DIR"
else
    echo "Неподдерживаемый формат архива. Поддерживаются: .zip, .tar.gz, .tgz, .tar.xz"
    exit 1
fi

# Поиск директории с конфигами (обычно other os или similar)
VPN_CONFIG_DIR=""
for dir in "$TEMP_DIR"/*/; do
    if [ -d "$dir" ] && [[ "$(ls "$dir"/*.ovpn 2>/dev/null | head -1)" ]]; then
        VPN_CONFIG_DIR="$dir"
        break
    fi
done

if [ -z "$VPN_CONFIG_DIR" ]; then
    echo "Не найдена директория с .ovpn файлами в архиве"
    exit 1
fi

echo "Найдена директория с конфигами: $VPN_CONFIG_DIR"

# Создание временной директории для новых конфигов
NEW_CONFIGS_DIR="/tmp/new_vpn_configs_$(date +%s)"
mkdir -p "$NEW_CONFIGS_DIR"

echo "Копирование новых конфигов и преобразование имен под slug формат..."
for file in "$VPN_CONFIG_DIR"/*.ovpn; do
    if [ -f "$file" ]; then
        # Преобразование имени файла к slug формату
        base_name=$(basename "$file" .ovpn)
        slug_name=$(echo "$base_name" | sed "s/, /-/g" | sed "s/ (/-/g" | sed "s/ /-/g" | sed "s/)//g" | tr "[:upper:]" "[:lower:]")
        cp "$file" "$NEW_CONFIGS_DIR/$slug_name.ovpn"
        echo "  $base_name -> $slug_name.ovpn"
    fi
done

# Создание нового index.json
echo "Создание нового index.json..."
cat > "$TEMP_DIR/index.json.new" << 'EOF'
[
  {
    "slug": "austria-graz-s1",
    "name": "Austria, Graz S1"
  },
  {
    "slug": "belgium-brussels-s2",
    "name": "Belgium, Brussels S2"
  },
  {
    "slug": "canada-quebec-s2",
    "name": "Canada, Quebec S2"
  },
  {
    "slug": "chile-vina-del-mar",
    "name": "Chile, Vina del Mar"
  },
  {
    "slug": "croatia-zagreb-s2",
    "name": "Croatia, Zagreb S2"
  },
  {
    "slug": "denmark-copenhagen-s5",
    "name": "Denmark, Copenhagen S5"
  },
  {
    "slug": "estonia-tallinn-s1",
    "name": "Estonia, Tallinn S1"
  },
  {
    "slug": "estonia-openai-split",
    "name": "Estonia, Tallinn S1 (OpenAI split)",
    "tags": ["gpt"]
  },
  {
    "slug": "finland-helsinki-s2",
    "name": "Finland, Helsinki S2"
  },
  {
    "slug": "france-paris-s11",
    "name": "France, Paris S11"
  },
  {
    "slug": "germany-limburg-s10",
    "name": "Germany, Limburg S10"
  },
  {
    "slug": "germany-offenbach-s6",
    "name": "Germany, Offenbach S6"
  },
  {
    "slug": "hong-kong-central-district-s2",
    "name": "Hong Kong, Central District S2"
  },
  {
    "slug": "hungary-budapest-s4",
    "name": "Hungary, Budapest S4"
  },
  {
    "slug": "hungary-budapest-s5",
    "name": "Hungary, Budapest S5"
  },
  {
    "slug": "kazakhstan-almaty-slow2",
    "name": "Kazakhstan, Almaty SLOW2"
  },
  {
    "slug": "lithuania-vilnius-routers",
    "name": "Lithuania, Vilnius ROUTERS"
  },
  {
    "slug": "netherlands-amsterdam-routers2",
    "name": "Netherlands, Amsterdam ROUTERS2"
  },
  {
    "slug": "netherlands-amsterdam-s1",
    "name": "Netherlands, Amsterdam S1"
  },
  {
    "slug": "netherlands-kerkrade-s3",
    "name": "Netherlands, Kerkrade S3"
  },
  {
    "slug": "netherlands-chatgpt-split",
    "name": "Netherlands, Kerkrade (ChatGPT split)",
    "tags": ["gpt"]
  },
  {
    "slug": "norway-sandefjord-routers",
    "name": "Norway, Sandefjord ROUTERS"
  },
  {
    "slug": "norway-sandefjord-s8",
    "name": "Norway, Sandefjord S8"
  },
  {
    "slug": "norway-chatgpt-split",
    "name": "Norway, Asker (ChatGPT split)",
    "tags": ["gpt"]
  },
  {
    "slug": "poland-warsaw-s2",
    "name": "Poland, Warsaw S2"
  },
  {
    "slug": "serbia-belgrade-s2",
    "name": "Serbia, Belgrade S2"
  },
  {
    "slug": "sweden-stockholm-routers2",
    "name": "Sweden, Stockholm ROUTERS2"
  },
  {
    "slug": "sweden-vasteras-openvpn",
    "name": "Sweden, Vasteras OPENVPN"
  },
  {
    "slug": "switzerland-zurich-s2",
    "name": "Switzerland, Zurich S2"
  },
  {
    "slug": "united-kingdom-london-l1",
    "name": "United Kingdom, London L1"
  },
  {
    "slug": "usa-ashburn",
    "name": "USA, Ashburn"
  },
  {
    "slug": "usa-new-york-l1",
    "name": "USA, New York L1"
  },
  {
    "slug": "usa-salt-lake-city",
    "name": "USA, Salt Lake City"
  },
  {
    "slug": "usa-utah",
    "name": "USA, Utah"
  }
]
EOF

# Копирование специальных split конфигов из резервной копии, если они существуют
if [ -f "$BACKUP_DIR/estonia-openai-split.ovpn" ]; then
    echo "Копирование специального конфига estonia-openai-split.ovpn"
    cp "$BACKUP_DIR/estonia-openai-split.ovpn" "$NEW_CONFIGS_DIR/"
fi

if [ -f "$BACKUP_DIR/netherlands-chatgpt-split.ovpn" ]; then
    echo "Копирование специального конфига netherlands-chatgpt-split.ovpn"
    cp "$BACKUP_DIR/netherlands-chatgpt-split.ovpn" "$NEW_CONFIGS_DIR/"
fi

if [ -f "$BACKUP_DIR/norway-chatgpt-split.ovpn" ]; then
    echo "Копирование специального конфига norway-chatgpt-split.ovpn"
    cp "$BACKUP_DIR/norway-chatgpt-split.ovpn" "$NEW_CONFIGS_DIR/"
fi

# Обновление системной директории VPN конфигов
echo "Обновление системной директории VPN конфигов..."
sudo mkdir -p /etc/vpn-manager/configs/
sudo cp "$TEMP_DIR/index.json.new" /etc/vpn-manager/configs/index.json
sudo cp "$NEW_CONFIGS_DIR"/*.ovpn /etc/vpn-manager/configs/

# Обработка split-конфигов для обеспечения правильной работы split-маршрутизации
echo "Обновление split-конфигов для правильной работы split-маршрутизации..."
for split_config in estonia-openai-split netherlands-chatgpt-split norway-chatgpt-split; do
    if [ -f "/etc/vpn-manager/configs/$split_config.ovpn" ]; then
        # Определение основного сервера для каждого split-конфига
        case "$split_config" in
            estonia-openai-split)
                main_server="estonia-tallinn-s1"
                ;;
            netherlands-chatgpt-split)
                main_server="netherlands-kerkrade-s3"
                ;;
            norway-chatgpt-split)
                main_server="norway-sandefjord-routers"
                ;;
        esac
        
        # Создание правильного split-конфига с route-noexec
        cat > "/tmp/${split_config}_updated.ovpn" << EOF
config ${main_server}.ovpn

# Отключаем автоматическую установку маршрутов для правильной split-маршрутизации
route-noexec

script-security 2
setenv SPLIT_TUNNEL_STATE /run/vpn-manager/${split_config}.routes
setenv SPLIT_TUNNEL_DOMAINS "api.openai.com platform.openai.com chat.openai.com chatgpt.com auth.openai.com status.openai.com labs.openai.com sora.openai.com codex.openai.com codex-gateway.openai.com cli.openai.com files.openai.com"
route-up "/usr/local/lib/vpn-manager/$(echo $split_config | sed 's/.*-//' | sed 's/-split.*//')-split-routes.sh"
down "/usr/local/lib/vpn-manager/$(echo $split_config | sed 's/.*-//' | sed 's/-split.*//')-split-routes.sh"
EOF
        
        # Копирование обновленного конфига
        sudo cp "/tmp/${split_config}_updated.ovpn" "/etc/vpn-manager/configs/${split_config}.ovpn"
        echo "  Обновлен конфиг для $split_config"
    fi
done

echo "Очистка временных файлов..."
rm -rf "$TEMP_DIR"
rm -rf "$NEW_CONFIGS_DIR"
rm -f /tmp/*_updated.ovpn

echo "VPN-конфигурации успешно обновлены!"
echo "Для проверки используйте: ~/.local/bin/vpn-manager list"

# Показываем нотификацию об успешном обновлении
if command -v notify-send &> /dev/null; then
    notify-send "VPN Конфигурации Обновлены" "Конфигурации успешно обновлены. Всего: $(~/.local/bin/vpn-manager list | wc -l) конфигураций, включая специальные split-конфиги для OpenAI/ChatGPT маршрутизации."
fi