#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

info() {
  echo -e "🔹 $1"
}

success() {
  echo -e "✅ $1"
}

warn() {
  echo -e "⚠️  $1"
}

echo "🚀 Full System Cleanup for Arch + Btrfs"

# 0) Установка pacman-contrib
info "Проверка pacman-contrib..."
if ! pacman -Qi pacman-contrib &>/dev/null; then
  info "Устанавливаю pacman-contrib..."
  if sudo pacman -Sy --noconfirm pacman-contrib; then
    success "pacman-contrib установлен."
  else
    warn "Не удалось установить pacman-contrib!"
  fi
else
  success "pacman-contrib уже установлен."
fi

# 1) Обновление системы
info "Обновление системы..."
if updates=$(yay -Qu 2>/dev/null) && [[ -n "$updates" ]]; then
  echo "$updates"
  if yay -Syu --noconfirm; then
    success "Система успешно обновлена."
  else
    warn "Ошибка обновления системы."
  fi
else
  success "Обновлений нет."
fi

# 2) Очистка кэша yay
info "Очистка кэша yay..."
if yay -Yc --noconfirm --answerclean None; then
  success "Кэш yay очищен."
else
  warn "Ошибка очистки кэша yay."
fi

# 3) Удаление orphan-пакетов
info "Удаление orphan-пакетов..."
orphans=$(yay -Qtdq 2>/dev/null || true)
if [[ -n "$orphans" ]]; then
  echo "$orphans"
  if yay -Rns $orphans --noconfirm; then
    success "Orphan-пакеты удалены."
  else
    warn "Ошибка удаления orphan-пакетов."
  fi
else
  success "Нет orphan-пакетов."
fi

# 4) Удаление неиспользуемых зависимостей
info "Удаление неиспользуемых зависимостей..."
deps=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n "$deps" ]]; then
  echo "$deps"
  if sudo pacman -Rns $deps --noconfirm; then
    success "Неиспользуемые зависимости удалены."
  else
    warn "Ошибка удаления зависимостей."
  fi
else
  success "Нет неиспользуемых зависимостей."
fi

# 5) Глубокая очистка кэша pacman
info "Глубокая очистка кэша pacman..."
if command -v paccache &>/dev/null; then
  if sudo paccache -rvk0; then
    success "Кэш pacman очищен (paccache)."
  else
    warn "Ошибка очистки кэша через paccache."
  fi
else
  if sudo pacman --noconfirm -Scc; then
    success "Кэш pacman очищен (Scc fallback)."
  else
    warn "Ошибка очистки кэша через pacman -Scc."
  fi
fi

# 6) Очистка логов старше 7 дней
info "Очистка логов старше 7 дней..."
if sudo journalctl --vacuum-time=7d; then
  success "Логи очищены."
else
  warn "Ошибка очистки логов."
fi

# 7) Очистка временных файлов (>1 день)
info "Очистка /tmp и /var/tmp..."
{
  sudo find /tmp -mindepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null
  sudo find /var/tmp -mindepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null
  success "Временные файлы очищены."
} || {
  warn "Ошибка очистки временных файлов."
}

# 8) Очистка пользовательского кэша
info "Очистка ~/.cache..."
if [[ -d "$HOME/.cache" ]]; then
  for entry in "$HOME"/.cache/* "$HOME"/.cache/.*; do
    [[ "$(basename "$entry")" =~ ^\.\.?$ ]] && continue
    [[ ! -e "$entry" ]] && continue
    if [[ -O "$entry" ]]; then
      rm -rf "$entry"
    else
      warn "Пропущено (не ваш файл): $entry"
    fi
  done
  success "Очистка ~/.cache завершена."
else
  warn "~/.cache не найден."
fi

# 9) Удаление пустых директорий в $HOME
info "Удаление пустых директорий в $HOME..."
if find "$HOME" -maxdepth 2 -type d -user "$USER" -empty -delete 2>/dev/null; then
  success "Пустые директории удалены."
else
  warn "Ошибка удаления пустых директорий."
fi

# 10) Обновление базы mlocate
info "Обновление базы mlocate..."
if command -v updatedb &>/dev/null; then
  if sudo updatedb; then
    success "База mlocate обновлена."
  else
    warn "Ошибка обновления базы mlocate."
  fi
else
  warn "updatedb не установлен."
fi

echo "🎉 Полная очистка системы завершена!"
