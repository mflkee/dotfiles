# MFLKEE — личные шпаргалки (navi)

# dsync

## Статус синхронизации
$ dsync status

## Отправить изменения
$ dsync push

## Забрать изменения
$ dsync pull

## Диагностика конфигурации
$ dsync doctor

# niri

## Скриншот области (grim+slurp, файл+буфер)
$ sh ~/.config/scripts/screenshot_region_clipboard.sh

## Запись экрана (toggle, wf-recorder)
$ sh ~/.config/scripts/screenrec-toggle.sh

## Запись аудио (toggle, ffmpeg)
$ sh ~/.config/scripts/screenrec-toggle.sh audio

## Локскрин (блюр экрана)
$ sh ~/.config/scripts/lock.sh

## Мониторы (память разметки)
$ niri msg outputs

# awgq

## Включить VPN
$ awgq on

## Выключить VPN
$ awgq off

## Статус VPN
$ awgq status

# chezmoi

## Применить source → live
$ chezmoi apply

## Показать изменения
$ chezmoi diff

## Захватить правки live-файла
$ chezmoi re-add ~/{path}

# ssh

## Сервер (obsidian/хаб dsync)
$ ssh archlinux-server

## ИБП на mkair-server-tmn
$ ssh mkair-server-tmn "upsc apc-ups"