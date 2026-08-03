return {
  {
    'nickjvandyke/opencode.nvim',
    version = '*',
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {}

      vim.o.autoread = true

      -- Toggle opencode terminal
      vim.keymap.set({ 'n', 't' }, '<M-c>', function()
        require('opencode').toggle()
      end, { desc = 'Toggle opencode' })

      -- Ask opencode about current context (submit immediately)
      vim.keymap.set({ 'n', 'x' }, '<M-a>', function()
        require('opencode').ask('@this: ', { submit = true })
      end, { desc = 'Ask opencode…' })

      -- Select prompt / command
      vim.keymap.set({ 'n', 'x' }, '<M-x>', function()
        require('opencode').select()
      end, { desc = 'Select opencode…' })

      -- Operator: send motion / visual selection to opencode
      vim.keymap.set({ 'n', 'x' }, 'go', function()
        return require('opencode').operator '@this '
      end, { desc = 'Add range to opencode', expr = true })

      -- Operator: send current line to opencode
      vim.keymap.set('n', 'goo', function()
        return require('opencode').operator '@this ' .. '_'
      end, { desc = 'Add line to opencode', expr = true })

      -- Scroll opencode session
      vim.keymap.set('n', '<S-C-u>', function()
        require('opencode').command 'session.half.page.up'
      end, { desc = 'Scroll opencode up' })

      vim.keymap.set('n', '<S-C-d>', function()
        require('opencode').command 'session.half.page.down'
      end, { desc = 'Scroll opencode down' })
    end,
  },
}
