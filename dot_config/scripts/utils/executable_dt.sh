#!/bin/sh

TRASH_DIR="$HOME/.trash"

show_help() {
    echo "Использование: dt [ОПЦИИ] <ФАЙЛЫ...>"
    echo ""
    echo "Опции:"
    echo "  -l, --list     Показать содержимое корзины"
    echo "  -c, --clean    Очистить корзину"
    echo "  -h, --help     Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  dt file.txt              # Переместить файл в корзину"
    echo "  dt file1.txt file2.jpg   # Переместить несколько файлов"
    echo "  dt -l                    # Показать содержимое корзины"
    echo "  dt -c                    # Очистить корзину"
}

list_trash() {
    if [ -d "$TRASH_DIR" ] && [ "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
        echo "Содержимое корзины ($TRASH_DIR):"
        ls -la "$TRASH_DIR"
    else
        echo "Корзина пуста"
    fi
}

clean_trash() {
    if [ -d "$TRASH_DIR" ]; then
        echo "Очистка корзины..."
        rm -rf "$TRASH_DIR"/*
        echo "Корзина очищена"
    else
        echo "Корзина не существует"
    fi
}

move_to_trash() {
    local item="$1"
    local basename=$(basename "$item")
    local destination="$TRASH_DIR/$basename"
    
    if [ ! -e "$item" ]; then
        echo "Ошибка: $item не существует"
        return 1
    fi
    
    # Добавляем временную метку если файл уже существует в корзине
    if [ -e "$destination" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        destination="$TRASH_DIR/${basename}_${timestamp}"
    fi
    
    if mv "$item" "$destination" 2>/dev/null; then
        echo "✓ $item -> $(basename "$destination")"
    else
        echo "✗ Ошибка перемещения: $item"
        return 1
    fi
}

main() {
    # Создаем папку корзины
    mkdir -p "$TRASH_DIR"
    
    case "${1:-}" in
        -l|--list)
            list_trash
            ;;
        -c|--clean)
            clean_trash
            ;;
        -h|--help)
            show_help
            ;;
        *)
            if [ $# -eq 0 ]; then
                show_help
                exit 1
            fi
            
            # Перемещаем все переданные файлы
            for item in "$@"; do
                move_to_trash "$item"
            done
            ;;
    esac
}

main "$@"
