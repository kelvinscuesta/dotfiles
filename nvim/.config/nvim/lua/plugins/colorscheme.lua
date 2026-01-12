return {
  'sainnhe/gruvbox-material',
  lazy = false,
  priority = 1000,
  config = function()
    -- Optionally configure and load the colorscheme
    -- directly inside the plugin declaration.
    vim.g.gruvbox_material_background = 'soft'
    vim.g.gruvbox_material_better_performance = 1
    vim.g.gruvbox_material_enable_italic = 1
    vim.g.gruvbox_material_enable_bold = 1
    vim.g.gruvbox_material_inlay_hints_background = 'dimmed'
    vim.g.gruvbox_material_ui_contrast = 'high'
    vim.cmd.colorscheme 'gruvbox-material'
  end,
}
