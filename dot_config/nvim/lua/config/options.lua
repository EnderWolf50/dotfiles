-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- prettier formats only where a prettier config exists, so it does not fight biome
vim.g.lazyvim_prettier_needs_config = true
