# =====================
#  Custom Functions
# =====================

# Create and navigate to directory
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# Open manpage in Neovim
vman() {
  nvim -c "Man $1" -c "only"
}

# Calculator
calc() {
  echo "$*" | bc -l
}

ranger-cd() {
  local tmpfile
  local target

  tmpfile="$(mktemp -t ranger-cd.XXXXXX)" || return
  ranger --choosedir="$tmpfile" "${1:-$PWD}"

  if [[ -s "$tmpfile" ]]; then
    target="$(<"$tmpfile")"
    if [[ -d "$target" && "$target" != "$PWD" ]]; then
      cd -- "$target" || true
    fi
  fi

  rm -f -- "$tmpfile"
}

function csync {
    # ---- 1. Инициализация ----
    echo "🔵 Starting sync process..."
    local original_dir="$PWD"
    local chezmoi_dir="${CHEZMOI_HOME:-$HOME/.local/share/chezmoi}"

    # ---- 2. Применение изменений chezmoi ----
    echo "🔄 Applying chezmoi changes..."
    if chezmoi apply -v; then
        echo "✅ Chezmoi changes applied successfully"
    else
        echo "❌ Failed to apply chezmoi changes!" >&2
        return 1
    fi

    # ---- 3. Переход в директорию chezmoi ----
    echo "📂 Entering chezmoi directory..."
    if [[ ! -d "$chezmoi_dir" ]]; then
        echo "❌ Chezmoi directory not found at: $chezmoi_dir" >&2
        return 1
    fi

    # ---- 4. Git операции в подпроцессе ----
    (
        cd "$chezmoi_dir" || {
            echo "❌ Could not enter chezmoi directory" >&2
            exit 1
        }

        echo "🔍 Checking git status in: $PWD"
        if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "❌ Not a git repository!" >&2
            exit 1
        fi

        echo "➕ Staging changes..."
        git add . || exit 1

        if git diff-index --quiet HEAD --; then
            echo "🔄 No changes to commit"
            exit 0
        fi

        echo "💾 Committing changes..."
        git commit -m "Update config $(date +'%Y-%m-%d %H:%M')" || exit 1

        echo "🚀 Pushing to remote..."
        git push || exit 1

        echo "✅ Sync completed successfully in: $PWD"
    )

    # ---- 5. Возврат в исходную директорию ----
    cd "$original_dir" || true
}
