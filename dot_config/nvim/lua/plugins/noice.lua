-- Inside tmux, Ctrl+F belongs to tmux-sessionizer (see config/keymaps.lua), so noice gives
-- up its Ctrl+F / Ctrl+B doc scrolling there. Outside tmux LazyVim's defaults stay.
if not vim.env.TMUX then
  return {}
end

return {
  "folke/noice.nvim",
  keys = {
    { "<C-f>", false, mode = { "i", "n", "s" } },
    { "<C-b>", false, mode = { "i", "n", "s" } },
  },
}