local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")
local state = require("swiftpick.state")

---Returns the configured sentinel string for empty slots.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
end

-- Saved guicursor value restored when the picker is closed.
local old_guicursor = nil

---Hides the cursor inside the picker window by applying a fully-blended
---highlight group to the cursor option string. The original value is saved
---so it can be restored by `show_cursor()`.
function M.hide_cursor()
  if old_guicursor == nil then
    old_guicursor = vim.o.guicursor
  end
  vim.api.nvim_set_hl(0, "SwiftpickCursor", { blend = 100, nocombine = true })
  vim.opt.guicursor:append("a:SwiftpickCursor/SwiftpickCursor")
end

---Restores the original `guicursor` value saved by `hide_cursor()`.
function M.show_cursor()
  if old_guicursor ~= nil then
    vim.o.guicursor = old_guicursor
    old_guicursor = nil
  end
end

---Returns a prune-hint segment if the display list contains at least one EMPTY sentinel,
---or an empty string when no pruning is needed.
---@param display_entries string[] Current list of display paths shown in the picker.
---@return string  Hint segment string, e.g. `" • [p] prune"`, or `""`.
local function get_prune_segment(display_entries)
  local kb = config.values.keybinds
  local has_empty = false
  for _, entry in ipairs(display_entries) do
    if entry == EMPTY() then
      has_empty = true
      break
    end
  end

  if has_empty then
    return " • [" .. kb.prune_empty .. "] prune"
  else
    return ""
  end
end

---Returns the first element when `keybind` is a table, or the value itself when it is a string.
---Used so the footer always shows a single representative key even when multiple keys are bound.
---@param keybind string|string[] A configured keybind value.
---@return string
local function get_first_keybind_if_table(keybind)
  if type(keybind) == "table" then
    return keybind[1] or ""
  else
    return keybind or ""
  end
end

---Returns `true` when the hint identified by `show_hint_Key` should be displayed.
---The master `show_hints.all` flag overrides individual hint flags.
---@param show_hint_Key boolean Individual hint flag value from `config.show_hints`.
---@return boolean
local is_hint_enabled = function(show_hint_Key)
  local show_hints = config.values.show_hints
  return show_hints.all or show_hint_Key
end

---Build the footer string shown at the bottom of the picker window.
---
---The footer is context-sensitive: it shows different hints depending on whether
---the picker is in normal mode or edit mode, and only includes segments for
---hint flags that are enabled in the config.
---
---@param display_entries string[]     Current list of display paths (used for prune hint detection).
---@param window_state    table        Local window state table from `window.lua` (needs `.show_absolute`).
---@return string  Padded footer string ready to pass to `nvim_open_win` / `nvim_win_set_config`.
function M.get_picker_footer(display_entries, window_state)
  local kb = config.values.keybinds
  local show_hints = config.values.show_hints

  if state.edit_mode then
    -- Edit mode: show save/pick/exit hints only.
    local segments = {}
    if is_hint_enabled(show_hints.pick_highlighted_entry) then
      table.insert(segments, "[" .. kb.pick_highlighted_entry .. "] pick entry")
    end
    table.insert(segments, "[:w] save changes")
    if is_hint_enabled(show_hints.exit_edit_mode) then
      table.insert(segments, "[" .. get_first_keybind_if_table(kb.exit_edit_mode) .. "] exit")
    end
    return "  " .. table.concat(segments, " • ") .. "  "
  end

  -- Normal mode: conditionally build each hint segment and join them.
  local segments = {}
  if is_hint_enabled(show_hints.add) or is_hint_enabled(show_hints.add_at) then
    -- Combine add and add_at into a single "[a|A] add" segment when both are enabled.
    local add_part = is_hint_enabled(show_hints.add) and kb.add or nil
    local add_at_part = is_hint_enabled(show_hints.add_at) and kb.add_at or nil
    local lhs = (add_part and add_at_part) and (add_part .. "|" .. add_at_part) or (add_part or add_at_part)
    if lhs then
      table.insert(segments, "[" .. lhs .. "] add")
    end
  end
  if is_hint_enabled(show_hints.remove) or is_hint_enabled(show_hints.remove_at) then
    -- Combine remove and remove_at into a single "[r|R] remove" segment when both are enabled.
    local remove_part = is_hint_enabled(show_hints.remove) and kb.remove or nil
    local remove_at_part = is_hint_enabled(show_hints.remove_at) and kb.remove_at or nil
    local remove_hint_combined = (remove_part and remove_at_part) and (remove_part .. "|" .. remove_at_part)
      or (remove_part or remove_at_part)
    if remove_hint_combined then
      table.insert(segments, "[" .. remove_hint_combined .. "] remove")
    end
  end
  if is_hint_enabled(show_hints.prune_empty) then
    local prune = get_prune_segment(display_entries)
    if prune ~= "" then
      -- Strip the leading " • " prefix that get_prune_segment adds; the
      -- separator is added uniformly by table.concat below.
      local prune_text = prune:gsub("^ • ", "")
      table.insert(segments, prune_text)
    end
  end
  if is_hint_enabled(show_hints.edit_entries) then
    table.insert(segments, "[" .. kb.edit_entries .. "] edit")
  end

  -- Toggle hints describe what the key will *switch to*, not the current state.
  local toggle_global_part = state.global_picker and "local" or "global"
  local toggle_absolute_part = window_state.show_absolute and "rel" or "abs"

  if is_hint_enabled(show_hints.toggle_global_picker) and is_hint_enabled(show_hints.toggle_absolute) then
    -- Combine both toggle hints into a single segment when both are enabled.
    table.insert(
      segments,
      "["
        .. kb.toggle_global_picker
        .. "|"
        .. kb.toggle_absolute
        .. "] "
        .. toggle_global_part
        .. "/"
        .. toggle_absolute_part
    )
  elseif is_hint_enabled(show_hints.toggle_global_picker) then
    table.insert(segments, "[" .. kb.toggle_global_picker .. "] " .. toggle_global_part)
  elseif is_hint_enabled(show_hints.toggle_absolute) then
    table.insert(segments, "[" .. kb.toggle_absolute .. "] " .. toggle_absolute_part)
  end

  if is_hint_enabled(show_hints.close_picker) then
    table.insert(segments, "[" .. get_first_keybind_if_table(kb.close_picker) .. "] exit")
  end
  return "  " .. table.concat(segments, " • ") .. "  "
end

---Measures the content of a buffer and returns its width and height.
---Used to compute the initial floating window dimensions before it is displayed.
---@param entry_buf_nr integer Buffer handle to measure.
---@return { width: integer, height: integer }  Width is the longest line length; height is the line count.
function M.get_buf_size(entry_buf_nr)
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

return M
