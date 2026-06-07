local M = {}

M.state = {
  opened = false,
  opened_from_window = nil,
  opened_from_buffer = nil,
  pending_at_action = nil,
  edit_mode = false,
}

return M
