-- Autotag: auto-close and rename HTML/JSX tags using treesitter
-- Type <div> and it auto-inserts </div>
-- Rename opening tag and closing tag updates automatically
return {
  'windwp/nvim-ts-autotag',
  config = function()
    require('nvim-ts-autotag').setup()
  end,
}
