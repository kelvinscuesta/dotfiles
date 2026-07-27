return {
  cmd = { 'bundle', 'exec', 'rubocop', '--lsp' },
  filetypes = { 'ruby' },
  root_markers = { '.rubocop.yml', 'Gemfile' },
  init_options = {
    safeAutocorrect = true,
  },
  on_attach = function(client)
    client.server_capabilities.hoverProvider = false
  end,
}
