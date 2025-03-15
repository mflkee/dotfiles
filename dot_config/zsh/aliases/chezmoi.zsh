# Переход в директорию с исходными файлами chezmoi
alias cdm="chezmoi cd"

# Отображение статуса (показывает, какие файлы изменены или неотслеживаемы)
alias cstatus="chezmoi status"

# Применение изменений (перенос из источника в домашнюю директорию)
alias capply="chezmoi apply"

# Редактирование файла под управлением chezmoi
alias cedit="chezmoi edit"

# Добавление файла в управление chezmoi
alias cadd="chezmoi add"

# Удаление файла из управления chezmoi
alias cremove="chezmoi remove"

# Просмотр различий между текущей версией и версией в chezmoi
alias cdiff="chezmoi diff"

# Обновление файлов из исходного каталога chezmoi
alias cupdate="chezmoi update"

# Синхронизация изменений: применение, переход в директорию, добавление в git, коммит и push
alias csync="chezmoi apply && chezmoi cd && git add . && git commit -m 'Update config' && git push"
