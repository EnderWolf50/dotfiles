-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Inside tmux only: Ctrl+F opens tmux-sessionizer in a new window (see plugins/noice.lua).
if vim.env.TMUX then
  vim.keymap.set("n", "<C-f>", "<cmd>!tmux neww tmux-sessionizer<cr>", { silent = true })
end