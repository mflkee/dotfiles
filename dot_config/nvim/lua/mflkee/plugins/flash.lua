-- Flash.nvim: молниеносные прыжки по символам/дереву (s, S, r, R).
local gh = require('mflkee.util').gh

vim.pack.add { gh 'folke/flash.nvim' }
require('flash').setup {} -- дефолтные s/S (вперёд/назад), r/R (remote)
