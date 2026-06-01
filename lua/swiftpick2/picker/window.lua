local M = {}

local function get_window_size()
  return {
    width = vim.o.columns,
    height = vim.o.lines,
  }
end

function M.get_centered_win_config(buf_line_count)
  local size = get_window_size()
  local row = math.floor((vim.o.lines - size.height) / 2)
  local col = math.floor((vim.o.columns - size.width) / 2)
  return {
    relative = "editor",
    row = row,
    col = col,
    width = size.width,
    height = size.height,
    border = "rounded",
    style = "minimal",
  }
end

function M.refresh_window_config(win_id)
  local config = get_centered_win_config()
  vim.api.nvim_win_set_config(win_id, config)
end

return M
