# Скрипт обновления VPN-конфигураций

## Описание
Этот скрипт автоматизирует процесс обновления VPN-конфигураций из новых архивов, скачанных с hideme.

## Содержимое
1. `update_vpn_configs.sh` - Основной скрипт для обновления конфигов
2. `update_vpn_configs_interactive.sh` - Скрипт с поддержкой выбора архива через Rofi

## Изменения между старыми и новыми конфигами

### Удаленные конфиги:
- canada-chambly-routers
- france-paris-s6
- norway-asker-routers
- norway-sandefjord-openvpn
- norway-sandefjord-s3
- sweden-stockholm-openvpn
- sweden-stockholm-s10
- ukraine-kyiv-l1
- usa-clarks-summit-l1
- united-kingdom-london-l1 (был заменен новой версией, но сохранился)

### Новые конфиги:
- hong-kong-central-district-s2
- hungary-budapest-s4
- hungary-budapest-s5
- kazakhstan-almaty-slow2
- netherlands-amsterdam-routers2
- netherlands-amsterdam-s1
- norway-sandefjord-routers
- norway-sandefjord-s8
- sweden-stockholm-routers2
- sweden-vasteras-openvpn

### Сохраненные специальные split-конфиги:
- estonia-openai-split (маршрутизация для OpenAI)
- netherlands-chatgpt-split (маршрутизация для ChatGPT)
- norway-chatgpt-split (маршрутизация для ChatGPT)

### Обновленные конфиги:
- hungary-budapest-s2 (старый) -> hungary-budapest-s4, hungary-budapest-s5 (новые)

## Особенности работы split-конфигов

Специальные split-конфиги (те, что с суффиксом `-split`) теперь правильно настроены для правильной маршрутизации:

- Вместо `pull-filter ignore "redirect-gateway"` и `route-nopull` используется `route-noexec`
- Это обеспечивает корректную работу split-маршрутизации
- Трафик к доменам OpenAI/ChatGPT (api.openai.com, chat.openai.com и др.) проходит через VPN
- Весь остальной трафик использует обычное соединение

## Использование

### Прямое обновление:
```bash
~/update_vpn_configs.sh ~/Downloads/hideme_956278698472306(2).zip
```

### Интерактивное обновление с выбором файла:
```bash
~/update_vpn_configs_interactive.sh --interactive
```

## Особенности

1. **Резервное копирование**: Скрипт автоматически создает резервную копию текущих конфигов
2. **Специальные split-конфиги**: Особые конфиги для маршрутизации трафика (например, к OpenAI/ChatGPT) автоматически сохраняются и восстанавливаются с правильными настройками
3. **Поддержка форматов**: Скрипт поддерживает .zip, .tar.gz, .tgz, .tar.xz архивы
4. **Slug-преобразование**: Имена файлов автоматически преобразуются к формату, необходимому для VPN-менеджера
5. **Автонастройка split-конфигов**: Split-конфиги автоматически настраиваются с использованием `route-noexec` для корректной работы

## Интеграция с Rofi

Для добавления скрипта в ваше Rofi меню, вы можете создать ярлык или добавить команду:
```
bash ~/update_vpn_configs_interactive.sh --interactive
```

## Проверка обновления

После обновления можно проверить список доступных конфигов:
```bash
~/.local/bin/vpn-manager list
```

Для проверки работы split-конфигов:
1. Подключитесь к split-VPN: `~/.local/bin/vpn-manager connect estonia-openai-split`
2. Проверьте маршруты: `ip route | grep tun`
3. Убедитесь, что нет маршрутов 0.0.0.0/1 или 128.0.0.0/1, но есть специфичные маршруты к IP-адресам OpenAI