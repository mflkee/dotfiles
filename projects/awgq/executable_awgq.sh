#!/bin/bash
# awgq wrapper — запускает Python скрипт из venv

# Находим реальную директорию скрипта (следуем symlink)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Если это symlink в ~/.local/bin, ищем реальный проект
if [[ "$SCRIPT_DIR" == *".local/bin"* ]]; then
    # Пробуем найти проект в ~/projects/awgq
    if [ -d "$HOME/projects/awgq" ]; then
        SCRIPT_DIR="$HOME/projects/awgq"
    fi
fi

VENV_DIR="${SCRIPT_DIR}/.venv"
PYTHON="${VENV_DIR}/bin/python"

if [ ! -f "$PYTHON" ]; then
    echo "Error: Python virtual environment not found at $VENV_DIR"
    echo "Run: cd $SCRIPT_DIR && uv venv && uv pip install pyyaml rich"
    exit 1
fi

exec "$PYTHON" "${SCRIPT_DIR}/awgq" "$@"
