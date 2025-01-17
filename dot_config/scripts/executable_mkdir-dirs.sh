#!/bin/bash

# Объявляем переменные для директорий
XDG_DESKTOP_DIR="$HOME/desktop"
XDG_DOWNLOAD_DIR="$HOME/downloads"
XDG_TEMPLATES_DIR="$HOME/templates"
XDG_PUBLICSHARE_DIR="$HOME/public"
XDG_DOCUMENTS_DIR="$HOME/documents"
XDG_MUSIC_DIR="$HOME/music"
XDG_PICTURES_DIR="$HOME/pictures"
XDG_VIDEOS_DIR="$HOME/videos"

# Создаем функцию для создания директории, если она не существует
create_dir_if_not_exists() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo "Создана директория: $dir"
  else
    echo "Директория уже существует: $dir"
  fi
}

# Вызываем функцию для каждой директории
create_dir_if_not_exists "$XDG_DESKTOP_DIR"
create_dir_if_not_exists "$XDG_DOWNLOAD_DIR"
create_dir_if_not_exists "$XDG_TEMPLATES_DIR"
create_dir_if_not_exists "$XDG_PUBLICSHARE_DIR"
create_dir_if_not_exists "$XDG_DOCUMENTS_DIR"
create_dir_if_not_exists "$XDG_MUSIC_DIR"
create_dir_if_not_exists "$XDG_PICTURES_DIR"
create_dir_if_not_exists "$XDG_VIDEOS_DIR"
