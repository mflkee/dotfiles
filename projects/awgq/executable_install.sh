#!/bin/bash
# install.sh - Установка awgq

set -e

echo "=== awgq Installer ==="

PROJECT_DIR="$HOME/projects/awgq"
BIN_DIR="$HOME/.local/bin"

# Проверяем зависимости
if ! command -v uv &> /dev/null; then
    echo "Error: uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Создаём директорию
mkdir -p "$PROJECT_DIR"

# Копируем файлы (если запускаем из директории проекта)
if [ -f "awgq" ]; then
    echo "Copying files..."
    cp -r . "$PROJECT_DIR/"
fi

# Создаём virtual environment
cd "$PROJECT_DIR"
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Устанавливаем зависимости
echo "Installing dependencies..."
uv pip install pyyaml rich

# Создаём symlink
mkdir -p "$BIN_DIR"
if [ ! -L "$BIN_DIR/awgq" ]; then
    echo "Creating symlink..."
    ln -s "$PROJECT_DIR/awgq.sh" "$BIN_DIR/awgq"
fi

# Проверяем PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "Warning: $BIN_DIR not in PATH"
    echo "Add to ~/.zshrc: export PATH=\"$BIN_DIR:\$PATH\""
fi

# Создаём директорию для логов
mkdir -p "$HOME/.local/share/kimi/logs"

echo ""
echo "=== Installation complete ==="
echo "Run: awgq --help"
echo "Run: awgq status"
