return {
  'Julian/lean.nvim',
  event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },
  opts = {
    mappings = true,
  },
}
