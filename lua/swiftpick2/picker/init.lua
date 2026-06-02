local M = {}

local storage = require("swiftpick2.storage")
local window = require("swiftpick2.picker.window")
local helper = require("swiftpick2.picker.helper")

local state = {
  buf = nil,
  win = nil,
  old_statuscolumn = nil,
  HINT_NS = vim.api.nvim_create_namespace("swiftpick_hints"),
}

local function on_exit_picker()
  helper.show_cursor()
  vim.api.nvim_buf_delete(state.buf, { force = true })

  state.buf = nil
  state.win = nil
end

local function create_picker_keybind(mode, key, callback)
  vim.keymap.set(mode, key, callback, { buffer = state.buf, noremap = true, silent = true })
end

local function create_picker_keybinds()
  if state.win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end
  create_picker_keybind("n", "<Esc>", function()
    vim.api.nvim_win_close(state.win, true)
  end)
  create_picker_keybind("n", "<C-c>", function()
    vim.api.nvim_win_close(state.win, true)
  end)
end

-- Show H J K L on the first four lines of the picker window in the number gutter before the line numbers.
local function show_hints()
  local hints = { "H", "J", "K", "L" }
  vim.api.nvim_buf_clear_namespace(state.buf, state.HINT_NS, 0, -1)
  local count = vim.api.nvim_buf_line_count(state.buf)
  for i, label in ipairs(hints) do
    if i <= count then
      vim.api.nvim_buf_set_extmark(state.buf, state.HINT_NS, i - 1, 0, {
        sign_text = label,
        sign_hl_group = "Comment",
      })
    end
  end
end

function M.open_picker()
  state.buf = vim.api.nvim_create_buf(false, true)
  helper.hide_cursor()

  local numberwidth = 2

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, storage.get_filenames_for_cwd(vim.fn.getcwd()))
  state.win = vim.api.nvim_open_win(state.buf, true, window.get_centered_win_config(state.buf, numberwidth))

  vim.wo[state.win].number = true
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].numberwidth = numberwidth

  show_hints()

  vim.api.nvim_create_autocmd("WinLeave", {
    once = true,
    callback = function()
      on_exit_picker()
    end,
    buf = state.buf,
  })
  create_picker_keybinds()
end

return M
