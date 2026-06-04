local M = {}

local config = require("swiftpick2.config")
local storage = require("swiftpick2.storage")
local state = require("swiftpick2.state")

local function create_local_buffer_keybind(buf, mode, key, callback)
  vim.keymap.set(mode, key, callback, { buffer = buf, noremap = true, silent = true })
end

local function create_close_picker_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  -- if values.keybinds.close_picker is a table, create keybinds for each key in the table
  -- otherwise, create a single keybind for the close_picker key
  if type(config.values.keybinds.close_picker) == "table" then
    for _, key in ipairs(config.values.keybinds.close_picker) do
      create_local_buffer_keybind(buf, "n", key, function()
        vim.api.nvim_win_close(win, true)
      end)
    end
  else
    create_local_buffer_keybind(buf, "n", config.values.keybinds.close_picker, function()
      vim.api.nvim_win_close(win, true)
    end)
  end
end

local function create_add_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.add, function()
    storage.add_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(state.opened_from_buffer))
  end)
end

local function create_remove_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.remove, function()
    storage.remove_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(state.opened_from_buffer))
  end)
end

function M.create_picker_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  create_close_picker_keybinds(win, buf)
  create_add_keybind(buf)
  create_remove_keybind(buf)
end

return M
