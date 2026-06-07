local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")
local state = require("swiftpick.state")
local paths = require("swiftpick.lib.picker.paths")
local function EMPTY()
  return config.values.empty_entry_identifier
end

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
    if state.global_picker then
      storage.add_filename_global(vim.api.nvim_buf_get_name(state.opened_from_buffer))
    else
      storage.add_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(state.opened_from_buffer))
    end
    require("swiftpick.lib.picker.window").refresh_picker_window()
  end)
end

local function create_remove_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.remove, function()
    if state.global_picker then
      storage.remove_filename_global(vim.api.nvim_buf_get_name(state.opened_from_buffer))
    else
      storage.remove_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(state.opened_from_buffer))
    end
    require("swiftpick.lib.picker.window").refresh_picker_window()
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
    if state.global_picker then
      storage.add_filename_at_global(filename, index)
    else
      storage.add_filename_at_for_cwd(vim.uv.cwd(), filename, index)
    end
    require("swiftpick.lib.picker.window").refresh_picker_window()
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
    if state.global_picker then
      storage.remove_filename_at_global(index)
    else
      storage.remove_filename_at_for_cwd(vim.uv.cwd(), index)
    end
    require("swiftpick.lib.picker.window").refresh_picker_window()
  end)
end

local function create_prune_empty_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.prune_empty, function()
    if state.global_picker then
      storage.prune_empty_global()
    else
      storage.prune_empty_for_cwd(vim.uv.cwd())
    end
    require("swiftpick.lib.picker.window").refresh_picker_window()
  end)
end

local function create_toggle_absolute_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.toggle_absolute, function()
    require("swiftpick.lib.picker.window").toggle_absolute()
  end)
end

local function create_edit_mode_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.edit_entries, function()
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end)
end

local function pick_file(win, filepath)
  if not filepath or filepath == "" or filepath == EMPTY() then
    return
  end
  local abs = paths.to_absolute(filepath, vim.uv.cwd())
  vim.api.nvim_win_close(win, true)
  if state.opened_from_window and vim.api.nvim_win_is_valid(state.opened_from_window) then
    vim.api.nvim_set_current_win(state.opened_from_window)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(abs))
end

local function create_pick_entry_keybinds(win, buf)
  local key_map = pick_entry_key_to_index()
  for key, index in pairs(key_map) do
    create_local_buffer_keybind(buf, "n", key, function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      pick_file(win, lines[index])
    end)
  end
end

local function create_pick_highlighted_entry_keybind(win, buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.pick_highlighted_entry, function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    pick_file(win, lines[row])
  end)
end

local function create_exit_edit_mode_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  -- if values.keybinds.close_picker is a table, create keybinds for each key in the table
  -- otherwise, create a single keybind for the close_picker key
  if type(config.values.keybinds.close_picker) == "table" then
    for _, key in ipairs(config.values.keybinds.close_picker) do
      create_local_buffer_keybind(buf, "n", key, function()
        require("swiftpick.lib.picker.window").switch_to_entry_list()
      end)
    end
  else
    create_local_buffer_keybind(buf, "n", config.values.keybinds.close_picker, function()
      require("swiftpick.lib.picker.window").switch_to_entry_list()
    end)
  end
end

local function create_toggle_global_picker_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.toggle_global_picker, function()
    require("swiftpick.lib.picker.window").toggle_global_picker()
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
  create_edit_mode_keybind(buf)
  create_pick_entry_keybinds(win, buf)
  create_toggle_absolute_keybind(buf)
  create_toggle_global_picker_keybind(buf)
end

function M.create_edit_mode_keybinds(win, buf)
  create_exit_edit_mode_keybinds(win, buf)
  create_pick_highlighted_entry_keybind(win, buf)
end

return M
