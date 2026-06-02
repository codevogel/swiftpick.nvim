local M = {}

local helper = require("swiftpick2.picker.helper")

local function get_window_size(buf_size, numberwidth)
  local footer_size = #helper.get_picker_footer()
  local padding_r = 2
  local numberwidth_extra_padding = 2
  local win_size = {
    width = vim.fn.max({
      vim.fn.min({ buf_size.width + numberwidth + numberwidth_extra_padding, vim.o.columns - 4 }),
      footer_size,
    }) + padding_r,
    height = vim.fn.min({ buf_size.height + 1, vim.o.lines - 4 }),
  }
  return win_size
end

local function get_buf_size(entry_buf_nr)
  local line_count = vim.api.nvim_buf_line_count(entry_buf_nr)

  local max_line_length = 0
  for i = 1, line_count do
    local line_length = #vim.api.nvim_buf_get_lines(entry_buf_nr, i - 1, i, false)[1]
    if line_length > max_line_length then
      max_line_length = line_length
    end
  end

  return {
    width = max_line_length,
    height = line_count,
  }
end

function M.get_centered_win_config(entry_buf_nr, numberwidth)
  local win_size = get_window_size(get_buf_size(entry_buf_nr), numberwidth)
  local row = math.floor((vim.o.lines - win_size.height) / 2)
  local col = math.floor((vim.o.columns - win_size.width) / 2)
  return {
    relative = "editor",
    row = row,
    col = col,
    width = win_size.width,
    height = win_size.height,
    border = "rounded",
    style = "minimal",
    title = "swiftpick",
    title_pos = "center",
    footer = helper.get_picker_footer(),
    footer_pos = "center",
  }
end

return M
