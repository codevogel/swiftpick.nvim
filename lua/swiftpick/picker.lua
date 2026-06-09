---@module "swiftpick.picker"

---@class SwiftpickPickerModule
---@field open_picker fun(opts?: SwiftpickOpenPickerOverrides)

---@class SwiftpickOpenPickerOverrides
---@field global_picker boolean | nil `true` to open the global picker, `false` for cwd-local, `nil` to use the config default
---@field relative_path boolean | nil `true` to show relative paths, `false` for absolute paths, `nil` to use the config default

local window = require("swiftpick.lib.picker.window")
local state = require("swiftpick.state")
local config = require("swiftpick.config")

-- Callback for when the picker window is closed.
local function on_close_picker()
  state.opened_from_window = nil
  state.opened_from_buffer = nil
  state.opened = false
end

---@type SwiftpickPickerModule
local M = {
  ---Open the swiftpick picker window.
  ---Respects `config.global_picker_by_default` when `global_picker` is not provided.
  ---Stores the calling window and buffer in `state` so they can be restored on close.
  ---Does nothing if the picker is already open.
  ---@param opts? SwiftpickOpenPickerOverrides options to customize the picker behavior
  open_picker = function(opts)
    if state.opened then
      return
    end
    -- Resolve the nil/bool tri-state: nil → config default, bool → explicit override.
    state.opened_from_window = vim.api.nvim_get_current_win()
    state.opened_from_buffer = vim.api.nvim_get_current_buf()
    window.create_picker_window(on_close_picker, opts)
  end,
}

return M
