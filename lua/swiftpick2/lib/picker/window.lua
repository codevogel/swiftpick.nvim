local M = {}

local config = require("swiftpick2.config")
local helper = require("swiftpick2.lib.picker.helper")
local binds = require("swiftpick2.lib.picker.binds")

local HINT_NAMESPACE = vim.api.nvim_create_namespace("swiftpick_hints")

local state = {
  buf = nil,
  win = nil,
  old_statuscolumn = nil,
  HINT_NS = vim.api.nvim_create_namespace("swiftpick_hints"),
}

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

local function get_centered_win_config(entry_buf_nr, numberwidth)
  local win_size = get_window_size(helper.get_buf_size(entry_buf_nr), numberwidth)
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

local function show_hints(buf)
  local char_keybinds = config.values.keybinds.open_entry.chars
  -- select all non-nil values from char_keybinds and couple them with their index in a table
  local hints = {}
  for i = 1, 10 do
    local key = char_keybinds["_" .. i]
    if key ~= nil then
      hints[i] = key
    end
  end

  vim.api.nvim_buf_clear_namespace(buf, HINT_NAMESPACE, 0, -1)
  local count = vim.api.nvim_buf_line_count(buf)
  for i, label in ipairs(hints) do
    if i <= count then
      vim.api.nvim_buf_set_extmark(buf, HINT_NAMESPACE, i - 1, 0, {
        sign_text = label,
        sign_hl_group = "Comment",
      })
    end
  end
end

local function on_exit_picker(on_exit_callback)
  helper.show_cursor()
  vim.api.nvim_buf_delete(state.buf, { force = true })

  state.buf = nil
  state.win = nil
  if on_exit_callback then
    on_exit_callback()
  end
end

function M.create_picker_window(entry_lines, on_exit_callback)
  state.buf = vim.api.nvim_create_buf(false, true)
  helper.hide_cursor()

  local numberwidth = 2

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, entry_lines)
  state.win = vim.api.nvim_open_win(state.buf, true, get_centered_win_config(state.buf, numberwidth))

  vim.wo[state.win].number = true
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].numberwidth = numberwidth

  show_hints(state.buf)

  vim.api.nvim_create_autocmd("WinLeave", {
    once = true,
    callback = function()
      on_exit_picker(on_exit_callback)
    end,
    buf = state.buf,
  })
  binds.create_picker_keybinds(state.win, state.buf)
end

return M
