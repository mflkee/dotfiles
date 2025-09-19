# Repository Guidelines

## Project Structure & Module Organization
- `init.lua`: entry point; configures `lazy.nvim` and loads modules.
- `lua/mflkee/config/`: core config (`options.lua`, `keymaps.lua`, `autocomands.lua`, helpers).
- `lua/mflkee/plugins/`: Lazy plugin specs; one plugin per file. Language servers in `plugins/lsp/`.
- `lua/mflkee/colorscheme/`: theme selections and settings.
- `after/` and `ftplugin/`: plugin/filetype-specific tweaks.
- `doc/`: help docs (e.g., `:h kickstart.txt`).
- `lazy-lock.json`: plugin versions lockfile; commit when plugin updates change it.

## Build, Test, and Development Commands
- Run locally: `nvim` (loads this config from `~/.config/nvim`).
- Install/sync plugins: `:Lazy sync` or `nvim --headless '+Lazy! sync' +qa`.
- Health checks: `:checkhealth` or `nvim --headless '+checkhealth' +qa`.
- Format Lua: `stylua .` (uses `dot_stylua.toml`). Example: `stylua lua/ init.lua`.

## Coding Style & Naming Conventions
- Lua formatting: 2-space indent, Unix line endings, prefer single quotes; enforce with `stylua`.
- Keep modules under the `mflkee` namespace; avoid globals; return module tables.
- Plugin spec files: kebab-case (e.g., `nvim-treesitter.lua`, `gitsigns-nvim.lua`).
- Small, focused modules; colocate LSP-specific settings in `plugins/lsp/<lang>.lua`.

## Testing Guidelines
- Ensure `:Lazy sync` completes without errors; restart Neovim.
- Run `:checkhealth` and resolve reported issues.
- Manually verify LSPs by opening representative files (e.g., `*.py`, `*.rs`).
- For filetype tweaks, open matching files and confirm keymaps/highlights.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`. Example: `feat(lsp): add Rust tools`.
- Keep commits scoped and descriptive; include rationale in body when non-obvious.
- If plugin versions changed, include updated `lazy-lock.json` in the same PR.
- PRs should include: summary, linked issues (if any), and screenshots for visual changes (colorscheme/UI).

## Security & Configuration Tips
- Do not commit secrets or machine-specific paths. Keep local overrides outside the repo or ignore via `dot_gitignore`.
- To experiment safely, consider a separate app name: `NVIM_APPNAME=nvim-dev nvim` with a mirrored config dir.
