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

# Update mlocate database (ensure mlocate is installed)
if command -v updatedb &> /dev/null; then
    sudo updatedb
else
    echo "mlocate is not installed. Skipping updatedb."
fi

# Clean home directory cache (optional)
rm -rf ~/.cache/*

echo "Cleanup complete!"
