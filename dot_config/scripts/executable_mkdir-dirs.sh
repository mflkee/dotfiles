#!/bin/bash
# Создаёт XDG-каталоги в нижнем регистре.
#
# ⚠️ ВАЖНО: раньше скрипт начинался с `rm -rf $HOME/Documents` и т.п. —
# это стирало пользовательские данные (в т.ч. ~/Documents, который синкается
# через Syncthing). Удаление убрано навсегда. Скрипт только создаёт каталоги.
set -u

XDG_DESKTOP_DIR="$HOME/desktop"
XDG_DOWNLOAD_DIR="$HOME/downloads"
XDG_TEMPLATES_DIR="$HOME/templates"
XDG_PUBLICSHARE_DIR="$HOME/public"
XDG_DOCUMENTS_DIR="$HOME/documents"
XDG_MUSIC_DIR="$HOME/music"
XDG_PICTURES_DIR="$HOME/pictures"
XDG_VIDEOS_DIR="$HOME/videos"

create_dir_if_not_exists() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo "Создана директория: $dir"
  else
    echo "Директория уже существует: $dir"
  fi
}

create_dir_if_not_exists "$XDG_DESKTOP_DIR"
create_dir_if_not_exists "$XDG_DOWNLOAD_DIR"
create_dir_if_not_exists "$XDG_TEMPLATES_DIR"
create_dir_if_not_exists "$XDG_PUBLICSHARE_DIR"
create_dir_if_not_exists "$XDG_DOCUMENTS_DIR"
create_dir_if_not_exists "$XDG_MUSIC_DIR"
create_dir_if_not_exists "$XDG_PICTURES_DIR"
create_dir_if_not_exists "$XDG_VIDEOS_DIR"

# Каталоги с заглавной буквы не трогаем — только предупреждаем.
for d in Desktop Downloads Templates Public Documents Music Pictures Videos; do
  if [ -d "$HOME/$d" ]; then
    echo "⚠️  ~/$d существует — не тронут (удаляй вручную, если действительно не нужен)"
  fi
done
