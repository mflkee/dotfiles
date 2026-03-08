-- Code chunk insertion.
vim.keymap.set({ 'i', 'n' }, '<m-i>', '<esc>i```{python}<cr>```<esc>O', { desc = '[I]nsert code chunk' })
vim.keymap.set('n', '<leader>ci', ':split term://ipython<cr>', { desc = 'Split terminal (ipython)' })

-- Run code by filetype.
vim.keymap.set('n', '<leader>R', function()
  local filetype = vim.bo.filetype
  local current_file = vim.fn.expand '%:p'
  local dir = vim.fn.expand '%:p:h'

  local function term_exec(cmd, cwd)
    local args = { 'cmd=' .. cmd }
    if cwd and cwd ~= '' then
      table.insert(args, 'dir=' .. cwd)
    end
    vim.api.nvim_cmd({ cmd = 'TermExec', args = args }, {})
  end

  local runners = {
    rust = function()
      term_exec('cargo run', dir)
    end,
    python = function()
      term_exec('python ' .. vim.fn.shellescape(current_file))
    end,
    quarto = function()
      vim.cmd 'QuartoPreview'
    end,
    cpp = function()
      local output_file = vim.fn.expand '%:p:r'
      local compile_and_run = string.format(
        'g++ -o %s %s && %s',
        vim.fn.shellescape(output_file),
        vim.fn.shellescape(current_file),
        vim.fn.shellescape(output_file)
      )
      term_exec(compile_and_run, dir)
    end,
  }

  local runner = runners[filetype]
  if runner then
    runner()
  else
    vim.notify('Unsupported filetype: ' .. filetype, vim.log.levels.WARN)
  end
end, { desc = '[R]un code based on filetype' })
