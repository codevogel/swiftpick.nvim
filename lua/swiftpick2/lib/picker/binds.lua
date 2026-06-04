local M = {}

local config = require("swiftpick2.config")

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

function M.create_picker_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  create_close_picker_keybinds(win, buf)
end

return M
