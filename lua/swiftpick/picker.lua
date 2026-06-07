local M = {}

local window = require("swiftpick.lib.picker.window")
local state = require("swiftpick.state")

function M.open_picker()
  if state.opened then
    return
  end
  state.opened_from_window = vim.api.nvim_get_current_win()
  state.opened_from_buffer = vim.api.nvim_get_current_buf()
  window.create_picker_window(M.on_close_picker)
end

function M.on_close_picker()
  state.opened_from_window = nil
  state.opened_from_buffer = nil
  state.opened = false
end

return M
