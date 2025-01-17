#!/bin/bash

# Переменные
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
OTHER_BRANCH=""
if [[ "$CURRENT_BRANCH" == "desktop" ]]; then
    OTHER_BRANCH="thinkpad"
else
    OTHER_BRANCH="desktop"
fi

echo "Вы на ветке '$CURRENT_BRANCH'."
echo ""

# Меню для пользователя
echo "Выберите опцию:"
echo "1. Закоммитить и запушить в текущей ветке ('$CURRENT_BRANCH')"
echo "2. Закоммитить и запушить в текущей ветке и в другой ('$OTHER_BRANCH')"
echo "3. Полная проверка репозиториев: список изменённых файлов и различия внутри"
echo "4. Выйти из программы"
read -rp "Введите номер опции (1-4): " choice

# Функция для коммита и пуша в текущую ветку
commit_push_current_branch() {
    read -rp "Введите сообщение коммита: " commit_msg
    git add -A
    git commit -m "$commit_msg"
    git push origin "$CURRENT_BRANCH"
}

# Функция для коммита и пуша в текущую и другую ветку
commit_push_both_branches() {
    read -rp "Введите сообщение коммита: " commit_msg
    git add -A
    git commit -m "$commit_msg"
    git push origin "$CURRENT_BRANCH"
    echo "Переключение на '$OTHER_BRANCH'..."
    git checkout "$OTHER_BRANCH"
    git pull origin "$OTHER_BRANCH"
    git merge "$CURRENT_BRANCH" -m "$commit_msg"
    git push origin "$OTHER_BRANCH"
    git checkout "$CURRENT_BRANCH"
}

# Функция для проверки различий между ветками
check_diff() {
    echo "Проверка списка изменённых файлов между '$CURRENT_BRANCH' и '$OTHER_BRANCH'..."
    git fetch origin
    git diff --name-status "$CURRENT_BRANCH".."origin/$OTHER_BRANCH"
    echo ""
    echo "Проверка различий внутри файлов между '$CURRENT_BRANCH' и '$OTHER_BRANCH'..."
    git diff "$CURRENT_BRANCH".."origin/$OTHER_BRANCH"
}

# Выполнение выбранного действия
case $choice in
    1)
        commit_push_current_branch
        ;;
    2)
        commit_push_both_branches
        ;;
    3)
        check_diff
        ;;
    4)
        echo "Выход из программы."
        exit 0
        ;;
    *)
        echo "Неверный выбор. Пожалуйста, выберите 1, 2, 3 или 4."
        ;;
esac
