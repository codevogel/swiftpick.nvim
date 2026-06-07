---Shared mutable state for the swiftpick picker.
---
---All fields are accessed and mutated directly on this module table
---(e.g. `state.opened = true`), making this module a lightweight singleton.
---The `state` sub-table below documents the expected fields and their initial
---values but is not read at runtime.
---@class SwiftpickState
---@field opened                boolean|nil Whether the picker window is currently open
---@field opened_from_window    integer|nil Window handle that was active when the picker was opened; restored on close
---@field opened_from_buffer    integer|nil Buffer handle that was active when the picker was opened
---@field pending_at_action     any|nil     Stored context for a deferred add-at / remove-at operation
---@field edit_mode             boolean|nil Whether the picker is currently in edit mode
---@field global_picker         boolean|nil Whether the global (cross-cwd) entry list is active

---@type SwiftpickState
local M = {}

---Initial/default values documenting the fields managed on this module table.
M.state = {
  opened = false,
  opened_from_window = nil,
  opened_from_buffer = nil,
  pending_at_action = nil,
  edit_mode = false,
  global_picker = false,
}

return M
