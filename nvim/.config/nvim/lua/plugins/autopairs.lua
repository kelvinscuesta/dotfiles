-- Autopairs: automatically insert closing brackets, quotes, etc.
-- Type ( and it inserts (), placing cursor between them
-- Works with: () [] {} '' "" `` and language-specific pairs
return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter', -- load when entering insert mode (lazy)
  opts = {},
}
