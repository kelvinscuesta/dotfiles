-- Autocommands: run code automatically when events occur
--
-- An autocmd has 3 parts:
--   1. Event   - what triggers it (e.g., BufEnter, FileType, FocusGained)
--   2. Pattern - filter for when to run (e.g., "*.lua", "markdown")
--   3. Action  - what to do (callback function or command)
--
-- Example: format on save
--   vim.api.nvim_create_autocmd('BufWritePre', {
--     pattern = '*.lua',
--     callback = function() vim.lsp.buf.format() end,
--   })
--
-- Augroups prevent duplicate autocmds when re-sourcing config (clear = true)

-- Helper: create augroup with consistent naming
local function augroup(name)
  return vim.api.nvim_create_augroup('lazyvim_' .. name, { clear = true })
end

-- Auto-reload: check if file changed outside vim when refocusing
-- Events: returning to nvim, closing/leaving terminal
vim.api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  group = augroup 'checktime',
  callback = function()
    if vim.o.buftype ~= 'nofile' then
      vim.cmd 'checktime' -- prompts to reload if file changed on disk
    end
  end,
})

-- Auto-resize: equalize splits when terminal window is resized
vim.api.nvim_create_autocmd({ 'VimResized' }, {
  group = augroup 'resize_splits',
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd =' -- equalize all splits in all tabs
    vim.cmd('tabnext ' .. current_tab) -- return to original tab
  end,
})

-- Quick close: press q to close these temporary/info buffers
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'close_with_q',
  pattern = {
    'PlenaryTestPopup', -- plenary test output
    'checkhealth', -- :checkhealth results
    'dbout', -- database output
    'gitsigns-blame', -- git blame popup
    'grug-far', -- search/replace panel
    'help', -- help pages
    'lspinfo', -- :LspInfo window
    'neotest-output', -- test output
    'neotest-output-panel',
    'neotest-summary',
    'notify', -- notification popups
    'qf', -- quickfix list
    'spectre_panel', -- search/replace
    'startuptime', -- :StartupTime results
    'tsplayground', -- treesitter playground
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false -- hide from buffer list
    vim.schedule(function()
      vim.keymap.set('n', 'q', function()
        vim.cmd 'close'
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = 'Quit buffer',
      })
    end)
  end,
})

-- Man pages: hide from buffer list (don't clutter :ls)
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'man_unlisted',
  pattern = { 'man' },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

-- Text files: enable word wrap and spell check
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'wrap_spell',
  pattern = { 'text', 'plaintex', 'tex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true -- wrap long lines
    vim.opt_local.spell = true -- highlight misspellings
  end,
})

-- JSON: disable concealment (show quotes and syntax fully)
vim.api.nvim_create_autocmd({ 'FileType' }, {
  group = augroup 'json_conceal',
  pattern = { 'json', 'jsonc', 'json5' },
  callback = function()
    vim.opt_local.conceallevel = 0 -- 0 = show everything, no hiding
  end,
})

-- Auto mkdir: create parent directories when saving new file
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
  group = augroup 'auto_create_dir',
  callback = function(event)
    -- skip URLs (e.g., scp://, ftp://)
    if event.match:match '^%w%w+:[\\/][\\/]' then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p') -- create dirs recursively
  end,
})

-- Yank highlight: briefly flash yanked text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Briefly highlight yanked text',
  group = augroup 'highlight_yank',
  callback = function()
    vim.highlight.on_yank()
  end,
})
