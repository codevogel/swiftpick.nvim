local M = {}

local storage = require("swiftpick2.storage")
local window = require("swiftpick2.lib.picker.window")
local state = require("swiftpick2.state")

function M.open_picker()
  state.opened_from_window = vim.api.nvim_get_current_win()
  state.opened_from_buffer = vim.api.nvim_get_current_buf()
  local entry_list = storage.get_filenames_for_cwd(vim.fn.getcwd())
  window.create_picker_window(entry_list, M.on_close_picker)
end

function M.on_close_picker()
  state.opened_from_window = nil
  state.opened_from_buffer = nil
end

return M
