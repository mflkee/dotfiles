-- Treesitter: parser installation, syntax highlighting, folds, indentation.
local gh = require('mflkee.util').gh

vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

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
