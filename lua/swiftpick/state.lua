---@module "swiftpick.state"

local config = require("swiftpick.config")

---Shared mutable state for the swiftpick picker.
---@class SwiftpickState
local M = {}

---@type { buf: integer?, win: integer? } Tracks the buffer and window from which the currently open picker was launched, or `nil` if no picker is open.
M.opened_picker_from = {
  ---@type integer? The buffer number of the buffer from which the picker was opened, or `nil` if no picker is open.
  buf = nil,
  ---@type integer? The window number of the window from which the picker was opened, or `nil` if no picker is open.
  win = nil,
}

---@type boolean? Whether the picker is currently in edit mode, or `nil` if the picker is not open.
M.edit_mode = nil
---@type integer? The buffer number of the picker list buffer, or `nil` if the picker is not open.
M.picker_list_buf = nil
---@type integer? The buffer number of the picker list edit buffer, or `nil` if the picker is not open.
M.picker_list_edit_buf = nil
---@type integer? The window number of the picker list window, or `nil` if the picker is not open.
M.picker_win = nil
---@type boolean? The window number of the picker list edit window, or `nil` if the picker is not open.
M.display_absolute_paths = nil
---@type boolean? Whether to use the global storage context for the picker, or `nil` if the picker is not open.
M.use_global_context = nil

---Session memory for the swiftpick picker.
---This is used to store values that should persist across multiple invocations of the picker within the same Neovim session.
---@class SwiftpickSessionMemory
M.session_memory = {
  ---@type boolean Whether to display absolute paths by default when opening the picker.
  default_value_for_use_global_context_set = false,
  ---@type boolean Whether to use the global storage context by default when opening the picker.
  default_value_for_display_absolute_paths_set = false,
  ---@class SwiftpickSessionOverrideMemory
  before_overrides = {
    ---@type boolean? Whether to display absolute paths, or `nil` if the picker was not open.
    display_absolute_paths = nil,
    ---@type boolean? Whether to use the global storage context, or `nil` if the picker was not open.
    use_global_context = nil,
  },
}

---Initializes the state module with default values from the configuration.
---@return nil
M.initialize = function()
  M.edit_mode = false
  if M.display_absolute_paths == nil then
    M.display_absolute_paths = config.values.display_absolute_path_by_default
  end
  if M.use_global_context == nil then
    M.use_global_context = config.values.use_global_context_by_default
  end
end

return M
