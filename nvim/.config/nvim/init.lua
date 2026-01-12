-- enable experimental lua loader
vim.loader.enable(true)

require 'config.keymap'
require 'config.options'
require 'config.autocmds'
require 'config.lazy'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
