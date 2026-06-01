local M = {
  window = require("swiftpick2.picker.window"),
  storage = require("swiftpick2.storage"),
}

function M.open_picker()
  local entry_buf_nr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(entry_buf_nr, 0, -1, false, { "Hello from SwiftPick2!" })
  vim.api.nvim_open_win(entry_buf_nr, false, M.window.get_centered_win_config(entry_buf_nr))
end

return M
