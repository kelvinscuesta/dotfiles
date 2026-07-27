-- LSP behavior: keymaps, diagnostics, inlay hints
-- Server configs live in lsp/*.lua files

-- Enable bundle-managed servers (Mason can't install these)
vim.lsp.enable { 'ruby_lsp', 'sorbet', 'rubocop' }

-- Keymaps: set when LSP attaches to buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map('<leader>ca', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })

    -- Document Highlight: highlight other references to symbol under cursor
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
        end,
      })
    end

    -- Inlay hints: enable by default, hide in insert mode
    -- Toggle via snacks <leader>uh
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
      vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })

      vim.api.nvim_create_autocmd('InsertEnter', {
        buffer = event.buf,
        callback = function()
          vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })
        end,
      })
      vim.api.nvim_create_autocmd('InsertLeave', {
        buffer = event.buf,
        callback = function()
          vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
        end,
      })
    end
  end,
})

-- Diagnostics
vim.diagnostic.config {
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_lines = { current_line = true },
  virtual_text = false,
}

-- Sorbet restart on git branch change
do
  local last_head = nil
  local function current_head()
    local f = io.open((vim.fn.getcwd() or '.') .. '/.git/HEAD', 'r')
    if not f then return nil end
    local head = f:read('*l')
    f:close()
    return head
  end
  last_head = current_head()
  vim.api.nvim_create_autocmd({ 'FocusGained', 'DirChanged' }, {
    callback = function()
      local head = current_head()
      if head and last_head and head ~= last_head then
        vim.cmd 'LspRestart sorbet'
      end
      last_head = head
    end,
  })
  vim.api.nvim_create_user_command('SorbetRestart', function()
    vim.cmd 'LspRestart sorbet'
  end, {})
end
