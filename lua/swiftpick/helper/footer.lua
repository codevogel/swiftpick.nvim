---Helper module for constructing the footer string shown in the picker window.
---@module "swiftpick.helper.footer"

local config = require("swiftpick.config")
local state = require("swiftpick.state")

---Returns the configured sentinel string for empty slots.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
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
    return " • [" .. kb.prune_entries .. "] prune"
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
---@param show_specific_hint_key boolean Individual hint flag value from `config.show_hints`.
---@return boolean
local is_hint_enabled = function(show_specific_hint_key)
  local show_all_hints = config.values.show_hints.all
  if show_all_hints == nil then
    return show_specific_hint_key
  end
  return show_all_hints
end

---@class FooterHelper Helper class for constructing the footer string shown in the picker window.
local M = {}

---Build the footer string shown at the bottom of the picker window.
---
---The footer is context-sensitive: it shows different hints depending on whether
---the picker is in normal mode or edit mode, and only includes segments for
---hint flags that are enabled in the config.
---@param display_entries string[]     Current list of display paths (used for prune hint detection).
---@return string  Padded footer string ready to pass to `nvim_open_win` / `nvim_win_set_config`.
function M.get_picker_footer(display_entries)
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
  if is_hint_enabled(show_hints.switch_to_edit_mode) then
    table.insert(segments, "[" .. kb.edit_entries .. "] edit")
  end

  -- Toggle hints describe what the key will *switch to*, not the current state.
  local toggle_global_part = state.use_global_context and "local" or "global"
  local toggle_absolute_part = state.display_absolute_paths and "abs" or "rel"

  if
    is_hint_enabled(show_hints.toggle_use_global_context) and is_hint_enabled(show_hints.toggle_display_absolute_paths)
  then
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
  elseif is_hint_enabled(show_hints.toggle_use_global_context) then
    table.insert(segments, "[" .. kb.toggle_global_picker .. "] " .. toggle_global_part)
  elseif is_hint_enabled(show_hints.toggle_display_absolute_paths) then
    table.insert(segments, "[" .. kb.toggle_absolute .. "] " .. toggle_absolute_part)
  end

  if is_hint_enabled(show_hints.close_picker) then
    table.insert(segments, "[" .. get_first_keybind_if_table(kb.close_picker) .. "] exit")
  end
  return "  " .. table.concat(segments, " • ") .. "  "
end

return M
