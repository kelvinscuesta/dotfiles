-- Colorscheme: gruvbox-material (softer contrast variant of gruvbox)
-- Retro groove color palette with earthy tones (bg: brown/tan, fg: cream/orange)
return {
  'sainnhe/gruvbox-material',
  lazy = false, -- load immediately (not lazy)
  priority = 1000, -- load before other plugins to set colors first
  config = function()
    vim.g.gruvbox_material_background = 'soft' -- softer contrast: 'hard', 'medium', 'soft'
    vim.g.gruvbox_material_better_performance = 1 -- faster by reducing highlight groups
    vim.g.gruvbox_material_enable_italic = 1 -- italic comments and keywords
    vim.g.gruvbox_material_enable_bold = 1 -- bold functions and titles
    vim.g.gruvbox_material_inlay_hints_background = 'dimmed' -- subtle inlay hint bg
    vim.g.gruvbox_material_ui_contrast = 'high' -- higher contrast for UI elements
    vim.cmd.colorscheme 'gruvbox-material'
  end,
}
