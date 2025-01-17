#!/bin/bash

# Обновление системы и установка базовых пакетов
sudo pacman -Syu
sudo pacman -S --needed git base-devel

# Установка yay (AUR Helper)
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay

# Установка neovim и других программ
yay -S neovim ranger firefox telegram-desktop redshift geoclue2 polybar jq bluez npm bluez-utils pulsemixer xclip bat lsd dust ripgrep tldr gtop procs z zoxide xorg fzf feh zsh-syntax-highlighting xcursor-hackneyed-dark ipython quarto-cli-bin fzf vlc unzip bluetui udiskie ntfs-3g lazygit lxappearance xdotool scrot ffmpegthumbnailer xscreensaver freerdp noto-fonts speedtest-cli ttf-iosevka-nerd kdeconnect zenity rar unrar zip unzip dosfstools w3m-imgcat obsidian

# установка смены раскладки
localectl set-x11-keymap --no-convert us,ru pc105 "" grp:alt_shift_toggle

# Установка tmux и TPM (Tmux Plugin Manager)
yay -S tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Установка zsh и oh-my-zsh
sudo pacman -S zsh
chsh -s /usr/bin/zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
# # Установка zsh-syntax-highlighting (предполагается, что oh-my-zsh уже установлен)
# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting


# Добавление строки для активации zsh-syntax-highlighting в .zshrc
echo "source ${(q-)ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc

echo '%network ALL=(ALL) NOPASSWD: /sbin/nmcli radio wifi off, /sbin/nmcli radio wifi on' | sudo tee -a /etc/sudoers.d/network-wifi > /dev/null

# Обновление кэша шрифтов
fc-cache -fv
