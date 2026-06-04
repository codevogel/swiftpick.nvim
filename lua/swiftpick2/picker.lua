local M = {}

local storage = require("swiftpick2.storage")
local window = require("swiftpick2.lib.picker.window")

function M.open_picker()
  local entry_list = storage.get_filenames_for_cwd(vim.fn.getcwd())
  window.create_picker_window(entry_list)
end

return M
