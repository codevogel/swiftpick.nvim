---@module "swiftpick.picker"
---@class SwiftpickPickerModule
---@field open_picker fun(opts?: boolean)
---@field on_close_picker fun()

---@type SwiftpickPickerModule
local M = {}

local window = require("swiftpick.lib.picker.window")
local state = require("swiftpick.state")
local config = require("swiftpick.config")

---Open the swiftpick picker window.
---Respects `config.global_picker_by_default` when `global_picker` is not provided.
---Stores the calling window and buffer in `state` so they can be restored on close.
---Does nothing if the picker is already open.
---@param opts? boolean `true` to open the global picker, `false` for cwd-local, `nil` to use the config default
function M.open_picker(opts)
  if state.opened then
    return
  end
  -- Resolve the nil/bool tri-state: nil → config default, bool → explicit override.
  if opts ~= nil then
    state.global_picker = opts
  else
    state.global_picker = config.values.global_picker_by_default
  end
  state.opened_from_window = vim.api.nvim_get_current_win()
  state.opened_from_buffer = vim.api.nvim_get_current_buf()
  window.create_picker_window(M.on_close_picker)
end

---Callback invoked by the picker window when it closes.
---Resets the opener context in `state` so a new picker can be opened later.
function M.on_close_picker()
  state.opened_from_window = nil
  state.opened_from_buffer = nil
  state.opened = false
end

return M
