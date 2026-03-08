local modules = {
  'mflkee.config.keymaps.diagnostics',
  'mflkee.config.keymaps.navigation',
  'mflkee.config.keymaps.buffers',
  'mflkee.config.keymaps.coding',
  'mflkee.config.keymaps.tools',
}

for _, module in ipairs(modules) do
  require(module)
end
