return {
  init_options = {
    settings = {
      lineLength = 88,
      lint = {
        enable = true,
        select = { 'E', 'W', 'F', 'I', 'B', 'C4', 'UP', 'SIM', 'TCH', 'RUF' },
        ignore = { 'E501' },
      },
      format = {
        preview = true,
      },
      organizeImports = true,
    },
  },
  on_attach = function(client)
    client.server_capabilities.hoverProvider = false
  end,
}
