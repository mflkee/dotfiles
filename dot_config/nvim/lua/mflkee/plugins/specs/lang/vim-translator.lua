return {
  {
    'voldikss/vim-translator',
    config = function()
      local cyrillic_pattern = vim.regex [=[\v[А-Яа-яЁё]]=]
      local preview_max_height = 10

      local function configure_translation_window()
        local current_width = vim.api.nvim_win_get_width(0)

        -- Use a bottom preview split so paragraph translations stay readable.
        vim.g.translator_window_type = 'preview'
        vim.g.translator_window_max_width = math.max(1, current_width - 4)
        vim.g.translator_window_max_height = preview_max_height
      end

      local function get_visual_selection()
        local visual_mode = vim.fn.mode()
        if visual_mode == '\22' then
          vim.notify('Blockwise translation is not supported', vim.log.levels.WARN)
          return nil
        end

        local start_pos = vim.fn.getpos 'v'
        local cursor = vim.api.nvim_win_get_cursor(0)
        local start_row, start_col = start_pos[2], start_pos[3]
        local end_row, end_col = cursor[1], cursor[2] + 1

        if start_row == 0 or end_row == 0 then
          return nil
        end

        if visual_mode == 'V' then
          start_col = 1
          end_col = #vim.fn.getline(end_row)
        end

        if start_row > end_row or (start_row == end_row and start_col > end_col) then
          start_row, end_row = end_row, start_row
          start_col, end_col = end_col, start_col
        end

        local lines = vim.fn.getline(start_row, end_row)
        if vim.tbl_isempty(lines) then
          return nil
        end

        if start_row == end_row then
          lines[1] = string.sub(lines[1], start_col, end_col)
        else
          lines[1] = string.sub(lines[1], start_col)
          lines[#lines] = string.sub(lines[#lines], 1, end_col)
        end

        return table.concat(lines, '\n')
      end

      local function translate_visual_selection(display_mode)
        local selection = get_visual_selection()
        if not selection or vim.trim(selection) == '' then
          vim.notify('Nothing selected for translation', vim.log.levels.WARN)
          return
        end

        local source_lang, target_lang = 'en', 'ru'
        if cyrillic_pattern:match_str(selection) then
          source_lang, target_lang = 'ru', 'en'
        end

        if display_mode == 'window' then
          configure_translation_window()
        end

        vim.fn['translator#logger#init']()
        vim.fn['translator#translate']({
          text = vim.fn['translator#util#text_proc'](selection),
          source_lang = source_lang,
          target_lang = target_lang,
          engines = vim.g.translator_default_engines,
        }, display_mode)
      end

      vim.g.translator_source_lang = 'auto'
      vim.g.translator_target_lang = 'ru'
      vim.g.translator_default_engines = { 'google', 'bing' }
      configure_translation_window()

      vim.keymap.set('v', '<leader>t', function()
        translate_visual_selection 'window'
      end, {
        noremap = true,
        silent = true,
        desc = 'Translate selection ru/en in window',
      })

      vim.keymap.set('v', '<leader>T', function()
        translate_visual_selection 'echo'
      end, {
        noremap = true,
        silent = true,
        desc = 'Translate selection ru/en in command line',
      })
    end,
  },
}
