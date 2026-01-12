-- Sidekick: AI assistant integration (Claude, etc.) in neovim
-- Opens CLI tools in tmux panes, sends code/files to AI for help
--
-- Keymaps:
--   <C-.> or <leader>aa = toggle AI CLI    <leader>ac = toggle Claude
--   <leader>at = send current code         <leader>af = send file
--   <leader>av = send visual selection     <leader>ap = prompt picker
--   <Tab> = apply AI edit suggestions
return {
  'folke/sidekick.nvim',
  opts = {
    cli = {
      mux = { backend = 'tmux', enabled = true }, -- use tmux for CLI panes
    },
  },
  keys = {
    -- Tab: jump to or apply AI edit suggestions
    {
      '<tab>',
      function()
        if not require('sidekick').nes_jump_or_apply() then
          return '<Tab>'
        end
      end,
      expr = true,
      desc = 'Apply/goto next edit suggestion',
    },
    -- Toggle AI CLI
    { '<c-.>', function() require('sidekick.cli').toggle() end, desc = 'Toggle AI CLI', mode = { 'n', 't', 'i', 'x' } },
    { '<leader>aa', function() require('sidekick.cli').toggle() end, desc = 'Toggle AI CLI' },
    { '<leader>as', function() require('sidekick.cli').select() end, desc = 'Select CLI tool' },
    { '<leader>ad', function() require('sidekick.cli').close() end, desc = 'Detach CLI session' },
    -- Send context to AI
    { '<leader>at', function() require('sidekick.cli').send { msg = '{this}' } end, mode = { 'x', 'n' }, desc = 'Send this' },
    { '<leader>af', function() require('sidekick.cli').send { msg = '{file}' } end, desc = 'Send file' },
    { '<leader>av', function() require('sidekick.cli').send { msg = '{selection}' } end, mode = { 'x' }, desc = 'Send selection' },
    { '<leader>ap', function() require('sidekick.cli').prompt() end, mode = { 'n', 'x' }, desc = 'Prompt picker' },
    -- Quick Claude toggle
    { '<leader>ac', function() require('sidekick.cli').toggle { name = 'claude', focus = true } end, desc = 'Toggle Claude' },
  },
}
