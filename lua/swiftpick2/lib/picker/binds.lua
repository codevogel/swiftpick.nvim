local M = {}

local function create_local_buffer_keybind(buf, mode, key, callback)
  vim.keymap.set(mode, key, callback, { buffer = buf, noremap = true, silent = true })
end

function M.create_picker_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end
  create_local_buffer_keybind(buf, "n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end)
  create_local_buffer_keybind(buf, "n", "<C-c>", function()
    vim.api.nvim_win_close(win, true)
  end)
end

return M
