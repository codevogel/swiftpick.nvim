local M = {}

local storage = require("swiftpick2.storage")
local window = require("swiftpick2.picker.window")
local helper = require("swiftpick2.picker.helper")

local state = {
  buf = nil,
  win = nil,
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

function M.open_picker()
  state.buf = vim.api.nvim_create_buf(false, true)
  helper.hide_cursor()

  local numberwidth = 1

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, storage.get_filenames_for_cwd(vim.fn.getcwd()))
  state.win = vim.api.nvim_open_win(state.buf, true, window.get_centered_win_config(state.buf, numberwidth))

  vim.wo[state.win].number = true
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].numberwidth = numberwidth

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
