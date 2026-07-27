return {
  cmd = { 'ruby-lsp' },
  filetypes = { 'ruby' },
  root_markers = { 'Gemfile', '.ruby-lsp' },
  init_options = {
    enabledFeatures = {
      definition = true,
      references = true,
      documentSymbols = true,
      workspaceSymbol = true,
      codeActions = true,
      diagnostics = true,
      hover = true,
      completion = false,
    },
  },
}
