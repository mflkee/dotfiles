#!/usr/bin/env zsh

# Конфигурация
VENV_HOME="${HOME}/.venvs"
PYTHON_EXEC="python3"

# Создание директории для окружений
mkdir -p "$VENV_HOME"

venv() {
  case "$1" in
    create)
      if [ -z "$2" ]; then
        echo "Usage: venv create <name>"
        return 1
      fi
      if [ -d "${VENV_HOME}/$2" ]; then
        echo "Environment '$2' already exists!"
        return 1
      fi
      echo "Creating environment '$2'..."
      $PYTHON_EXEC -m venv "${VENV_HOME}/$2"
      ;;

    list)
      echo "Available environments:"
      ls -d "${VENV_HOME}"/*/ 2>/dev/null | xargs -L1 basename | sed 's/^/  - /'
      ;;

    activate)
      if [ -z "$2" ]; then
        echo "Usage: venv activate <name>"
        return 1
      fi
      if [ ! -d "${VENV_HOME}/$2" ]; then
        echo "Environment '$2' not found!"
        return 1
      fi
      source "${VENV_HOME}/$2/bin/activate"
      ;;

    delete)
      if [ -z "$2" ]; then
        echo "Usage: venv delete <name>"
        return 1
      fi
      if [ ! -d "${VENV_HOME}/$2" ]; then
        echo "Environment '$2' does not exist!"
        return 1
      fi
      read -r "confirm?Delete environment '$2'? [y/N] "
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "${VENV_HOME}/$2"
        echo "Environment '$2' deleted."
      fi
      ;;

    *)
      echo "Virtual environment manager:"
      echo "  venv create <name>   Create new environment"
      echo "  venv list           List all environments"
      echo "  venv activate <name> Activate environment"
      echo "  venv delete <name>  Delete environment"
      ;;
  esac
}

# Автодополнение для Zsh
_venv() {
  local -a subcmds
  subcmds=(
    'create:Create new virtual environment'
    'list:List available environments'
    'activate:Activate environment'
    'delete:Delete environment'
  )

  _arguments \
    "1: :{_describe 'command' subcmds}" \
    "*:: :->args"

  case "$state" in
    (args)
      case ${words[1]} in
        activate|delete)
          _path_files -W "$VENV_HOME" -/
          ;;
      esac
      ;;
  esac
}

compdef _venv venv
