local function load_builtin_configs()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local this_file = vim.fs.normalize(source)

  for _, path in ipairs(vim.api.nvim_get_runtime_file('lua/nvim-treesitter/configs.lua', true)) do
    if vim.fs.normalize(path) ~= this_file then
      local chunk = loadfile(path)
      if chunk then
        local ok, mod = pcall(chunk)
        if ok and type(mod) == 'table' and type(mod.setup) == 'function' then
          return mod
        end
      end
    end
  end
end

local builtin = load_builtin_configs()
if builtin then
  return builtin
end

local M = {}

local group = vim.api.nvim_create_augroup('TreesitterCompatConfig', { clear = true })
local module_opts = {}

local function as_list(value)
  if value == nil then
    return {}
  end

  if type(value) == 'table' then
    return value
  end

  return { value }
end

local function enable_for_buffer(bufnr, opts, indent_disabled)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= '' then
    return
  end

  local ft = vim.bo[bufnr].filetype
  if ft == '' then
    return
  end

  local parser_ok = pcall(vim.treesitter.get_parser, bufnr)
  if not parser_ok then
    return
  end

  if not (opts.highlight and opts.highlight.enable == false) then
    pcall(vim.treesitter.start, bufnr)
  end

  if opts.indent and opts.indent.enable and not indent_disabled[ft] then
    vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

function M.setup(opts)
  opts = opts or {}
  module_opts = opts

  local ok, treesitter = pcall(require, 'nvim-treesitter')
  if not ok then
    return
  end

  treesitter.setup {}

  local indent_disabled = {}
  for _, ft in ipairs(as_list(opts.indent and opts.indent.disable)) do
    indent_disabled[ft] = true
  end

  vim.api.nvim_clear_autocmds { group = group }
  vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
    group = group,
    callback = function(args)
      enable_for_buffer(args.buf, opts, indent_disabled)
    end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    enable_for_buffer(bufnr, opts, indent_disabled)
  end
end

function M.get_module(name)
  return module_opts[name] or {}
end

function M.is_enabled(name, lang, bufnr)
  local opts = M.get_module(name)
  if opts.enable == false then
    return false
  end

  local disabled = as_list(opts.disable)
  local ft = bufnr and vim.bo[bufnr].filetype or nil
  if vim.tbl_contains(disabled, lang) or (ft and vim.tbl_contains(disabled, ft)) then
    return false
  end

  if type(opts.disable) == 'function' then
    local ok, result = pcall(opts.disable, lang, bufnr)
    if ok and result then
      return false
    end
  end

  return true
end

return M
