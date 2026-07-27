return {
  settings = {
    Lua = {
      codeLens = {
        enable = true,
      },
      completion = {
        callSnippet = 'Replace',
      },
      diagnostics = { disable = { 'missing-fields' } },
      hint = {
        enable = true,
        setType = false,
        paramType = true,
        paramName = 'Enable',
        semicolon = 'Enable',
        arrayIndex = 'Enable',
      },
    },
  },
}
