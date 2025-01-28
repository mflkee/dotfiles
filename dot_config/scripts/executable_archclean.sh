#!/bin/bash
echo "Starting Arch Linux cleanup with Yay..."

# Update the package database and upgrade installed packages
yay -Syu --noconfirm

# Clean the Yay cache
if yay -Yc --noconfirm; then
    echo "Yay cache cleaned."
else
    echo "No packages to clean in Yay cache."
fi

# Remove unused packages (orphans)
if yay -Rns $(yay -Qtdq) --noconfirm; then
    echo "Unused packages removed."
else
    echo "No unused packages to remove."
fi

# Remove unused dependencies
if yay -Rns $(pacman -Qdtq) --noconfirm; then
    echo "Unused dependencies removed."
else
    echo "No unused dependencies to remove."
fi

# Clean system package cache
sudo pacman -Sc --noconfirm
echo "System package cache cleaned."

# Remove old logs
sudo journalctl --vacuum-time=7d
echo "Old logs removed."

# Clean temporary files
sudo rm -rf /tmp/* /var/tmp/*
echo "Temporary files cleared."

# Check disk usage before cleanup
echo "Disk usage before cleanup:"
df -h

# Clean home directory cache (optional)
rm -rf ~/.cache/*
echo "Home directory cache cleared."

# Remove old kernels
CURRENT_KERNEL=$(uname -r)
sudo pacman -Rns $(pacman -Q | grep linux | grep -v "$CURRENT_KERNEL" | awk '{print $1}') --noconfirm || echo "No old kernels to remove."
echo "Old kernels removed."

# Remove empty directories in home directory
find /home/$USER -type d -empty -delete
echo "Empty directories in home directory removed."

# Update mlocate database (ensure mlocate is installed)
if command -v updatedb &> /dev/null; then
    sudo updatedb
else
    echo "mlocate is not installed. Skipping updatedb."
fi

# Check disk usage after cleanup
echo "Disk usage after cleanup:"
df -h

echo "Cleanup complete!"
