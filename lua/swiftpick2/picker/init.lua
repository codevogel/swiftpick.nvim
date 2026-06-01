local M = {
  window = require("swiftpick2.picker.window"),
  storage = require("swiftpick2.storage"),
}

function M.open_picker()
  local entry_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(entry_buf, 0, -1, false, { "Hello from SwiftPick2!" })
  vim.api.nvim_open_win(entry_buf, false, M.window.get_centered_win_config(vim.api.nvim_buf_line_count(entry_buf)))
end

return M
