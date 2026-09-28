-- Treesitter: parser installation, syntax highlighting, folds, indentation.
local gh = require('mflkee.util').gh

vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

-- nvim-treesitter (main) хранит queries (highlights/injections/…) в runtime/queries/,
-- но :packadd добавляет на rtp только корень плагина, поэтому queries недоступны:
-- нет подсветки в .rs, а в md-блоках языки не инжектятся (всё одним цветом @markup.raw).
-- Добавляем подкаталог runtime/ явно.
local ts_query = vim.fn.globpath(vim.o.runtimepath, 'lua/nvim-treesitter/init.lua', false, true)[1]
if ts_query then
  -- <root>/lua/nvim-treesitter/init.lua → корень плагина (3 уровня вверх)
  local ts_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(ts_query)))
  local ts_runtime = vim.fs.joinpath(ts_root, 'runtime')
  if vim.fn.isdirectory(ts_runtime) == 1 then
    vim.opt.runtimepath:append(ts_runtime)
  end
end

-- Ensure basic parsers are installed
local parsers = {
  'bash',
  'c',
  'diff',
  'html',

  'lua',
  'luadoc',

  'python',
  'rust',
  'sql',

  'json',
  'yaml',
  'toml',
  'regex',
  'gitignore',

  'markdown',
  'markdown_inline',

  'query',
  'vim',
  'vimdoc',
}

require('nvim-treesitter').install(parsers)

---@param buf integer
---@param language string
local function treesitter_try_attach(buf, language)
  -- Check if a parser exists and load it
  if not vim.treesitter.language.add(language) then return end
  -- Enable syntax highlighting and other treesitter features
  vim.treesitter.start(buf, language)

  -- Folds (experiment): vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  --                     vim.wo.foldmethod = 'expr'

  -- Enable treesitter based indentation when an indent query exists
  local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
  if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
end

local available_parsers = require('nvim-treesitter').get_available()
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local buf, filetype = args.buf, args.match

    local language = vim.treesitter.language.get_lang(filetype)
    if not language then return end

    local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

    if vim.tbl_contains(installed_parsers, language) then
      treesitter_try_attach(buf, language)
    elseif vim.tbl_contains(available_parsers, language) then
      -- Auto-install on demand and attach when the parser is ready
      require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
    else
      treesitter_try_attach(buf, language)
    end
  end,
})
