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
