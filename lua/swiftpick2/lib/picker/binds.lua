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
    require("swiftpick2.lib.picker.window").refresh_picker_window()
  end)
end

local function create_remove_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.remove, function()
    storage.remove_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(state.opened_from_buffer))
    require("swiftpick2.lib.picker.window").refresh_picker_window()
  end)
end

-- Builds a flat key -> 1-based-index map from config.values.keybinds.pick_entry.
local function pick_entry_key_to_index()
  local map = {}
  for _, group in pairs(config.values.keybinds.pick_entry) do
    if type(group) == "table" then
      for name, key in pairs(group) do
        if key ~= nil then
          local idx = tonumber(name:match("_(%d+)"))
          if idx then
            map[key] = idx
          end
        end
      end
    end
  end
  return map
end

local function create_add_at_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.add_at, function()
    local key_map = pick_entry_key_to_index()
    local key = vim.fn.getcharstr()
    if key == "" then
      return
    end
    local index = key_map[key]
    if not index then
      return
    end
    local filename = vim.api.nvim_buf_get_name(state.opened_from_buffer)
    storage.add_filename_at_for_cwd(vim.uv.cwd(), filename, index)
    require("swiftpick2.lib.picker.window").refresh_picker_window()
  end)
end

local function create_remove_at_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.remove_at, function()
    local key_map = pick_entry_key_to_index()
    local key = vim.fn.getcharstr()
    if key == "" then
      return
    end
    local index = key_map[key]
    if not index then
      return
    end
    storage.remove_filename_at_for_cwd(vim.uv.cwd(), index)
    require("swiftpick2.lib.picker.window").refresh_picker_window()
  end)
end

local function create_prune_empty_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.prune_empty, function()
    storage.prune_empty_for_cwd(vim.uv.cwd())
    require("swiftpick2.lib.picker.window").refresh_picker_window()
  end)
end

function M.create_picker_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  create_close_picker_keybinds(win, buf)
  create_add_keybind(buf)
  create_add_at_keybind(buf)
  create_remove_keybind(buf)
  create_remove_at_keybind(buf)
  create_prune_empty_keybind(buf)
end

return M
