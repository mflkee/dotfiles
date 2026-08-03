local groups = require 'mflkee.config.autocmds.groups'

local modules = {
  'mflkee.config.autocmds.general',
  'mflkee.config.autocmds.terminal',
  'mflkee.config.autocmds.format',
  'mflkee.config.autocmds.language',
  'mflkee.config.autocmds.sql',
  'mflkee.config.autocmds.plantuml',
  'mflkee.config.autocmds.autosave',
}

for _, module in ipairs(modules) do
  require(module).setup(groups)
end
