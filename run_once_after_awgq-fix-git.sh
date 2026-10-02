#!/bin/sh
# run_once_after_awgq-fix-git.sh — самолечение перед раскаткой awgq через dsync.
#
# Если awgq уже стоял как обычный каталог (старый install.sh), он не является
# git-репозиторием, и хаб не может сделать `git clone` (каталог непустой).
# Тогда превращаем каталог в git-репо с origin=GitHub и синхронизируем с main.
#
# Идемпотентно: если .git уже есть — выходим. Сработает один раз на машину.
set -e

D="$HOME/projects/awgq"
[ -d "$D" ] || exit 0
[ -d "$D/.git" ] && exit 0

echo "[awgq-fix-git] превращаю $D в git-репозиторий"
cd "$D"
git init -q
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:mflkee/awgq.git
git fetch -q origin main
git checkout -f -B main origin/main
bash scripts/awgq-post-pull.sh || true
echo "[awgq-fix-git] готово"
