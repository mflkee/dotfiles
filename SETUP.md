# Machine Setup Guide

Быстрое развёртывание новой машины с нуля до рабочего состояния.

## 1. Базовая установка Arch Linux

```bash
# Разметка диска и установка Arch — стандартная процедура.
# Минимальный набор пакетов:
pacstrap /mnt base base-devel linux linux-firmware sudo git zsh networkmanager
```

После arch-chroot:
```bash
# Пароль root
passwd

# Пользователь
useradd -m -G wheel -s /bin/zsh mflkee
passwd mflkee

# sudo
EDITOR=vim visudo  # раскомментировать %wheel ALL=(ALL:ALL) ALL

# Сеть
systemctl enable --now NetworkManager

# chrony (точное время)
pacman -S chrony
systemctl enable --now chronyd
```

## 2. paru (AUR helper)

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru && makepkg -si && cd
```

## 3. Dotfiles через chezmoi

```bash
sudo pacman -S chezmoi

# Если есть SSH-ключи (скопированы с флешки в ~/Sync/bootstrap):
bootstrap-secrets ~/Sync/bootstrap

# Инициализация dotfiles
chezmoi init --apply mflkee
```

> Без SSH-доступа: `chezmoi init --apply https://github.com/mflkee/dotfiles.git`

## 4. Установка пакетов

```bash
bootstrap-workstation
```

Это установит всё из `REPO_PACKAGES` и `AUR_PACKAGES`: neovim, ghostty, niri, tmux,
nodejs, syncthing, zsh, fzf, bat, lsd, btop, lazygit и т.д.

## 5. Первый chezmoi apply

После установки пакетов:

```bash
chezmoi apply
```

Это:
- Установит GTK тему Tokyonight-Dark
- Настроит шрифты, иконки Tela-circle-dracula
- Применит tokyonight цвета для niri, ghostty, starship
- Запустит `run_once_setup-appearance.sh` (gsettings)
- Запустит `run_onchange_install-appearance-packages.sh` (недостающие пакеты)

## 6. Плагины Neovim

```bash
nvim --headless '+Lazy! sync' +qa
nvim --headless '+checkhealth' +qa
```

## 7. Плагины Tmux

Запустить tmux, нажать `prefix + I` (Ctrl+B, Shift+I) — TPM установит плагины.

## 8. Ноутбук — niri + Noctalia

```bash
# Включить сервисы niri
chezmoi apply

# Запустить niri
niri-session
```

Noctalia настроит обои, лаунчер, уведомления, цвета автоматически.
Импорт профиля из бэкапа (если есть):

```bash
noctalia-import-buffer ~/buffer/noctalia
```

## 9. Сервер — mkair-server

Головной сервер с Syncthing. После базовой установки достаточно:

```bash
chezmoi init --apply mflkee      # dotfiles
bootstrap-workstation             # пакеты
```

Syncthing запустится автоматически через systemd user service.

## 10. Пост-настройка

```bash
# Сменить shell (если ещё не zsh)
chsh -s /bin/zsh

# Проверить сервисы
systemctl --user status syncthing
systemctl --user status ssh-agent.socket

# Настроить Kvantum тему (если не подхватилась):
#   kvantummanager → Change/Delete Theme → выбрать Kvantum-Tokyo-Night → Use this theme

# Настроить GTK тему вручную (если не применилась):
gsettings set org.gnome.desktop.interface gtk-theme Tokyonight-Dark
gsettings set org.gnome.desktop.interface icon-theme Tela-circle-dracula
```

## Быстрый старт (одной командой)

Всё с нуля, после установки Arch с base-devel + git + zsh + NetworkManager:

```bash
# paru
git clone https://aur.archlinux.org/paru.git /tmp/paru && (cd /tmp/paru && makepkg -si) && \
# dotfiles
sudo pacman -S chezmoi && chezmoi init --apply mflkee && \
# пакеты
bootstrap-workstation && \
# всё остальное
chezmoi apply && \
nvim --headless '+Lazy! sync' +qa
```

После этого: перелогиниться, запустить tmux (prefix+I), наслаждаться.
