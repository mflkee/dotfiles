# Neovim Configuration

## Architecture

Thin entry point + modular tree (no distribution; plugins via the built-in
`vim.pack` manager).

```
init.lua                    → thin bootstrap: vim.loader, leader, requires modules below
lua/mflkee/options.lua      → core options (vim.o.*, vim.opt.*)
lua/mflkee/keymaps.lua      → keymaps, diagnostics config, terminal/cargo runner, augroups
lua/mflkee/pack.lua         → vim.pack build hooks (PackChanged autoamd) for installed/updated plugins
lua/mflkee/util.lua         → shared helpers (e.g. gh() GitHub URL builder)
lua/mflkee/plugins/core.lua → UI/Core UX: guess-indent, gitsigns, which-key, bufferline,
                              cyberdream+base16 colorscheme, render-markdown, todo-comments, mini.nvim
lua/mflkee/plugins/search.lua      → Telescope + LSP pickers + <leader>o (path/URL under cursor)
lua/mflkee/plugins/lsp.lua         → fidget, LSP keymaps, servers table, Mason + tool installer
lua/mflkee/plugins/format.lua      → conform.nvim (stylua / ruff_format / rustfmt / pg_format)
lua/mflkee/plugins/completion.lua  → LuaSnip + blink.cmp
lua/mflkee/plugins/treesitter.lua  → parsers, highlighting, indentation
lua/mflkee/config/functions.lua    → helpers used by ftplugin/markdown.lua, ftplugin/quarto.lua
                                     and the global <leader>o mapping. KEEP THIS PATH STABLE.
lua/matugen.lua             → matugen → base16 dynamic colorscheme (wallpaper-driven,
                              SIGUSR1 live updates); pcall-guarded
lua/custom/plugins/         → personal plugins (dsync-capture, translate, sql); auto-loaded via
                              `custom.plugins` (files are loaded in unspecified order)
lua/kickstart/plugins/      → optional examples (debug, indent_line, lint, autopairs, neo-tree)
after/plugin/               → highlight overrides loaded after plugins (rainbow_highlights.lua)
ftplugin/                   → filetype-specific tweaks
doc/, nvim-pack-lock.json   → kickstart docs; vim.pack lockfile
```

## Plugin management (vim.pack, built-in)

- Plugins are declared with `vim.pack.add { … }` in `lua/mflkee/plugins/*.lua`.
- They install into `stdpath("data")/site/pack/core/opt` (load on demand).
- Inspect/update: `:lua vim.pack.update(nil, { offline = true })` (dry run),
  `:lua vim.pack.update()` (apply). Lockfile: `nvim-pack-lock.json`.

## Commands

- Run locally: `nvim` (loads this config from `~/.config/nvim`).
- Health checks: `:checkhealth` or `nvim --headless '+checkhealth' +qa`.
- Format Lua: `stylua lua/ init.lua` (uses `.stylua.toml`).
- Smoke test config changes: `nvim --headless +qa` must exit cleanly, and
  `nvim --headless "+lua <module>" +qa` must resolve.

## Coding Style

- Lua: 2-space indent, Unix line endings — enforce with `stylua`.
- Avoid globals; return module tables.
- Plugin spec files: one file per area under `lua/mflkee/plugins/`; new plugin
  specs go there (keep related setup calls in the same file).

## Notes

- `mflkee.config.functions` is required by `ftplugin/markdown.lua` and
  `ftplugin/quarto.lua` — do not rename/move without updating them.
- Do not commit secrets or machine-specific paths.
- Older LazyVim-based layout (lua/config/*, lua/plugins/*, lazyvim.json) was
  removed — do not recreate it; the config is kickstart/vim.pack-based now.