local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")
local state = require("swiftpick.state")
local paths = require("swiftpick.lib.picker.paths")

---Returns the configured sentinel string for empty slots.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
end

---Set a buffer-local normal-mode keymap that does not remap and is silent.
---@param buf      integer  Buffer handle to scope the keymap to.
---@param mode     string   Vim mode string (e.g. `"n"`).
---@param key      string   LHS key sequence.
---@param callback function Callback invoked when the key is pressed.
local function create_local_buffer_keybind(buf, mode, key, callback)
  vim.keymap.set(mode, key, callback, { buffer = buf, noremap = true, silent = true })
end

---Register close-picker keybinds on the given buffer.
---Handles both single-key and table-of-keys configurations.
---@param win integer Picker window handle (validated to be non-nil).
---@param buf integer Picker buffer handle.
local function create_close_picker_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  -- if values.keybinds.close_picker is a table, create keybinds for each key in the table
  -- otherwise, create a single keybind for the close_picker key
  if type(config.values.keybinds.close_picker) == "table" then
    for _, key in
      ipairs(config.values.keybinds.close_picker --[[@as table]])
    do
      create_local_buffer_keybind(buf, "n", key, function()
        vim.api.nvim_win_close(win, true)
      end)
    end
  else
    create_local_buffer_keybind(buf, "n", config.values.keybinds.close_picker --[[@as string]], function()
      vim.api.nvim_win_close(win, true)
    end)
  end
end

---Register the "add current buffer" keybind on `buf`.
---@param buf integer Picker buffer handle.
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

---Register the "remove current buffer" keybind on `buf`.
---@param buf integer Picker buffer handle.
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

---Build a flat map of `key → 1-based slot index` from the nested `pick_entry` config.
---
---The config groups keys into sub-tables (e.g. `digits`, `chars`), each with entries
---named `_1`–`_10`. This function collapses all groups into a single lookup table so
---the caller can resolve a pressed key to its slot index in O(1).
---@return table<string, integer>  Map from key string to slot index (1–10).
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

---Register the "remove at index" keybind.
---After pressing the bound key the user presses a second key that selects the
---target slot index via `pick_entry_key_to_index()`.
---@param buf integer Picker buffer handle.
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

---Register the "prune empty slots" keybind.
---@param buf integer Picker buffer handle.
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

---Register the "toggle absolute/relative path display" keybind.
---@param buf integer Picker buffer handle.
local function create_toggle_absolute_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.toggle_absolute, function()
    require("swiftpick.lib.picker.window").toggle_absolute()
  end)
end

---Register the "switch to edit mode" keybind.
---@param buf integer Picker buffer handle.
local function create_edit_mode_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.edit_entries, function()
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end)
end

---Open the file at `filepath` in the window that was active before the picker opened.
---Converts relative paths to absolute before editing.
---Does nothing for empty strings or EMPTY sentinel values.
---@param win      integer Picker window handle (will be closed).
---@param filepath string  Path from the picker buffer line.
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

---Register a keybind for every slot key so pressing it opens the corresponding entry.
---@param win integer Picker window handle.
---@param buf integer Picker buffer handle.
local function create_pick_entry_keybinds(win, buf)
  local key_map = pick_entry_key_to_index()
  for key, index in pairs(key_map) do
    create_local_buffer_keybind(buf, "n", key, function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      pick_file(win, lines[index])
    end)
  end
end

---Register the keybind that opens the entry currently under the cursor.
---@param win integer Picker window handle.
---@param buf integer Picker buffer handle.
local function create_pick_highlighted_entry_keybind(win, buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.pick_highlighted_entry, function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    pick_file(win, lines[row])
  end)
end

---Register "exit edit mode" keybinds that return to the normal entry-list view.
---Handles both single-key and table-of-keys configurations.
---@param win integer Picker window handle (validated to be non-nil).
---@param buf integer Edit-mode buffer handle.
local function create_exit_edit_mode_keybinds(win, buf)
  if win == nil then
    error("Picker window number is nil. Cannot create keybinds.")
  end

  -- Reuse the close_picker key(s) to exit edit mode instead of closing.
  if type(config.values.keybinds.close_picker) == "table" then
    for _, key in
      ipairs(config.values.keybinds.close_picker --[[@as table]])
    do
      create_local_buffer_keybind(buf, "n", key, function()
        require("swiftpick.lib.picker.window").switch_to_entry_list()
      end)
    end
  else
    create_local_buffer_keybind(buf, "n", config.values.keybinds.close_picker --[[@as string]], function()
      require("swiftpick.lib.picker.window").switch_to_entry_list()
    end)
  end
end

---Register the "toggle global/local picker" keybind.
---@param buf integer Picker buffer handle.
local function create_toggle_global_picker_keybind(buf)
  create_local_buffer_keybind(buf, "n", config.values.keybinds.toggle_global_picker, function()
    require("swiftpick.lib.picker.window").toggle_global_picker()
  end)
end

---Register all keybinds for the normal (entry-list) picker mode.
---@param win integer Picker window handle.
---@param buf integer Entry-list buffer handle.
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

---Register all keybinds for the edit-mode buffer.
---@param win integer Picker window handle.
---@param buf integer Edit-mode buffer handle.
function M.create_edit_mode_keybinds(win, buf)
  create_exit_edit_mode_keybinds(win, buf)
  create_pick_highlighted_entry_keybind(win, buf)
end

return M
