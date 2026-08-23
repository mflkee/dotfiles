# Repository Guidelines

## Project Structure & Module Organization
- `init.lua`: entry point; bootstraps `lazy.nvim` via `lua/config/lazy.lua`.
- `lua/config/lazy.lua`: LazyVim setup (core + extras: python, rust, markdown; imports `plugins`).
- `lua/config/options.lua`, `lua/config/keymaps.lua`: core options and keymaps (auto-loaded by LazyVim).
- `lua/plugins/`: Lazy plugin specs (`colorscheme.lua` = cyberdream, `base16.lua`, `vim-translator.lua`).
- `lua/matugen.lua`: matugen → base16 dynamic colorscheme helper (required by `plugins/base16.lua`).
- `lua/mflkee/config/functions.lua`: helpers used by `ftplugin/markdown.lua` and `ftplugin/quarto.lua`. Keep this path stable.
- `after/plugin/`: highlight overrides loaded after plugins (e.g., `rainbow_highlights.lua`).
- `ftplugin/`: filetype-specific tweaks.
- `lazy-lock.json`: plugin versions lockfile (stored in `stdpath("data")`, not tracked here).

## Build, Test, and Development Commands
- Run locally: `nvim` (loads this config from `~/.config/nvim`).
- Install/sync plugins: `:Lazy sync` or `nvim --headless '+Lazy! sync' +qa`.
- Health checks: `:checkhealth` or `nvim --headless '+checkhealth' +qa`.
- Format Lua: `stylua .` (uses `.stylua.toml`). Example: `stylua lua/ init.lua`.

## Coding Style & Naming Conventions
- Lua formatting: 2-space indent, Unix line endings; enforce with `stylua`.
- Avoid globals; return module tables.
- Plugin spec files: kebab-case (e.g., `colorscheme.lua`, `base16-nvim.lua`).

## Testing Guidelines
- Ensure `:Lazy sync` completes without errors; restart Neovim.
- Run `:checkhealth` and resolve reported issues.
- Smoke test config changes: `nvim --headless +qa` must exit cleanly.
- Manually verify LSPs by opening representative files (e.g., `*.py`, `*.rs`).

## Security & Configuration Tips
- Do not commit secrets or machine-specific paths.
- To experiment safely, consider a separate app name: `NVIM_APPNAME=nvim-dev nvim` with a mirrored config dir.
