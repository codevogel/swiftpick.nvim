---Configures all keybinds for the picker.
---@module "swiftpick.binds"

local config = require("swiftpick.config")
local state = require("swiftpick.state")
local actions = require("swiftpick.actions")

---Set a buffer-local normal-mode keymap that does not remap and is silent.
---@param buf      integer  Buffer handle to scope the keymap to.
---@param mode     string   Vim mode string (e.g. `"n"`).
---@param key      string   Left-hand-side key sequence.
---@param callback function Callback invoked when the key is pressed.
---@return nil
local function create_local_buffer_keybind(buf, mode, key, callback)
  vim.keymap.set(mode, key, callback, { buffer = buf, noremap = true, silent = true })
end

---Register close-picker keybinds on the given buffer.
---Handles both single-key and table-of-keys configurations.
---@param buf integer Picker buffer handle.
---@return nil
local function create_close_picker_keybinds(buf)
  -- if values.keybinds.close_picker is a table, create keybinds for each key in the table
  -- otherwise, create a single keybind for the close_picker key
  if type(config.values.keybinds.close_picker) == "table" then
    for _, key in
      ipairs(config.values.keybinds.close_picker --[[@as table]])
    do
      create_local_buffer_keybind(buf, "n", key, function()
        actions.close_picker()
      end)
    end
  else
    create_local_buffer_keybind(buf, "n", config.values.keybinds.close_picker --[[@as string]], function()
      actions.close_picker()
    end)
  end
end

---Register the "add current buffer" keybind on `buf`.
---@param buf integer Picker buffer handle.
---@return nil
local function create_add_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.add, function()
    actions.add({ use_global_context = state.use_global_context })
  end)
end

---Register the "remove current buffer" keybind on `buf`.
---@param buf integer Picker buffer handle.
---@return nil
local function create_remove_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.remove, function()
    actions.remove({ use_global_context = state.use_global_context })
  end)
end

---Build a flat map of `key → 1-based slot index` from the nested `pick_entry` config.
---
---The config groups keys into sub-tables (e.g. `digits`, `chars`), each with entries
---named `_1`–`_10`. This function collapses all groups into a single lookup table so
---the caller can resolve a pressed key to its slot index in O(1).
---@return table<string, integer>  Map from key string to slot index (1–10).
---@return nil
local function pick_entry_key_to_index()
  local map = {}
  for _, group in pairs(config.values.keybinds.pick_entry) do
    if type(group) == "table" then
      for name, key in pairs(group) do
        if key ~= nil then
          -- Extract the numeric suffix from names like "_1", "_10".
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

---Register the "add at index" keybind.
---After pressing the bound key the user presses a second key that selects the
---target slot index via `pick_entry_key_to_index()`.
---@param buf integer Picker buffer handle.
---@return nil
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
    actions.add({ use_global_context = state.use_global_context, index = index })
  end)
end

---Register the "remove at index" keybind.
---After pressing the bound key the user presses a second key that selects the
---target slot index via `pick_entry_key_to_index()`.
---@param buf integer Picker buffer handle.
---@return nil
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
    actions.remove({ use_global_context = state.use_global_context, index = index })
  end)
end

---Register the "prune empty slots" keybind.
---@param buf integer Picker buffer handle.
---@return nil
local function create_prune_empty_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.prune_empty, function()
    actions.prune_empty_entries({ use_global_context = state.use_global_context })
  end)
end

---Register the "toggle absolute/relative path display" keybind.
---@param buf integer Picker buffer handle.
---@return nil
local function create_toggle_display_absolute_paths_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.toggle_display_absolute_paths, function()
    actions.toggle_display_absolute_paths()
  end)
end

---Register the "switch to edit mode" keybind.
---@param buf integer Picker buffer handle.
---@return nil
local function create_edit_mode_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.edit_entries, function()
    actions.switch_to_edit_mode()
  end)
end

---Register a keybind for every slot key so pressing it opens the corresponding entry.
---@param buf integer Picker buffer handle.
---@return nil
local function create_pick_entry_keybinds(buf)
  local key_map = pick_entry_key_to_index()
  for key, index in pairs(key_map) do
    create_local_buffer_keybind(buf, "n", key, function()
      actions.pick_file(index)
    end)
  end
end

---Register the keybind that opens the entry currently under the cursor.
---@param buf integer Picker buffer handle.
---@return nil
local function create_pick_highlighted_entry_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.pick_highlighted_entry, function()
    if state.picker_win == nil or not vim.api.nvim_win_is_valid(state.picker_win) then
      error("Cannot pick highlighted entry: picker window is not valid")
      return
    end
    local row = vim.api.nvim_win_get_cursor(state.picker_win)[1]
    actions.pick_file(row)
  end)
end

---Register "exit edit mode" keybinds that return to the normal entry-list view.
---Handles both single-key and table-of-keys configurations.
---@param buf integer Edit-mode buffer handle.
---@return nil
local function create_exit_edit_mode_keybinds(buf)
  -- Reuse the close_picker key(s) to exit edit mode instead of closing.
  if type(config.values.keybinds.close_picker) == "table" then
    for _, key in
      ipairs(config.values.keybinds.close_picker --[[@as table]])
    do
      create_local_buffer_keybind(buf, "n", key, function()
        actions.switch_to_pick_mode()
      end)
    end
  else
    create_local_buffer_keybind(buf, "n", config.values.keybinds.close_picker --[[@as string]], function()
      actions.switch_to_pick_mode()
    end)
  end
end

---Register the "toggle global/local picker" keybind.
---@param buf integer Picker buffer handle.
---@return nil
local function create_toggle_global_picker_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.toggle_use_global_context, function()
    actions.toggle_use_global_context()
  end)
end

---@class SwiftpickPickerBinds
local M = {}

---Create all pick-mode keybinds for the `picker_list_buf`
---@param buf integer Picker buffer handle.
---@return nil
function M.create_picker_keybinds(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    vim.notify("Cannot create picker keybinds: buffer " .. buf .. " is not valid", vim.log.levels.ERROR)
  end

  create_close_picker_keybinds(buf)
  create_add_keybind(buf)
  create_add_at_keybind(buf)
  create_remove_keybind(buf)
  create_remove_at_keybind(buf)
  create_prune_empty_keybind(buf)
  create_edit_mode_keybind(buf)
  create_pick_entry_keybinds(buf)
  create_toggle_display_absolute_paths_keybind(buf)
  create_toggle_global_picker_keybind(buf)
end

---Create all edit-mode keybinds for the `picker_list_edit_buf`
---@param buf integer Picker buffer handle.
---@return nil
function M.create_edit_mode_keybinds(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    vim.notify("Cannot create edit mode keybinds: buffer " .. buf .. " is not valid", vim.log.levels.ERROR)
  end

  create_exit_edit_mode_keybinds(buf)
  create_pick_highlighted_entry_keybind(buf)
end

return M
