local M = {}

local window = require("swiftpick.lib.picker.window")
local state = require("swiftpick.state")
local config = require("swiftpick.config")

function M.open_picker(global_picker)
  if state.opened then
    return
  end
  if global_picker == nil then
    state.global_picker = config.values.global_picker_by_default
  else
    state.global_picker = global_picker
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
