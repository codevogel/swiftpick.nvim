local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")
local state = require("swiftpick.state")
local function EMPTY()
  return config.values.empty_entry_identifier
end

-- Store the old guicursor value so we can restore it when the picker is closed.
local old_guicursor = nil

-- Hides the cursor by setting a transparent highlight group and appending it to guicursor.
function M.hide_cursor()
  if old_guicursor == nil then
    old_guicursor = vim.o.guicursor
  end
  vim.api.nvim_set_hl(0, "SwiftpickCursor", { blend = 100, nocombine = true })
  vim.opt.guicursor:append("a:SwiftpickCursor/SwiftpickCursor")
end

-- Restores the original guicursor value to show the cursor again.
function M.show_cursor()
  if old_guicursor ~= nil then
    vim.o.guicursor = old_guicursor
    old_guicursor = nil
  end
end

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

local function get_first_keybind_if_table(keybind)
  if type(keybind) == "table" then
    return keybind[1] or ""
  else
    return keybind or ""
  end
end

local is_hint_enabled = function(show_hint_Key)
  local show_hints = config.values.show_hints
  return show_hints.all or show_hint_Key
end

function M.get_picker_footer(display_entries, window_state)
  local kb = config.values.keybinds
  local show_hints = config.values.show_hints

  if state.edit_mode then
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

  local segments = {}
  if is_hint_enabled(show_hints.add) or is_hint_enabled(show_hints.add_at) then
    local add_part = is_hint_enabled(show_hints.add) and kb.add or nil
    local add_at_part = is_hint_enabled(show_hints.add_at) and kb.add_at or nil
    local lhs = (add_part and add_at_part) and (add_part .. "|" .. add_at_part) or (add_part or add_at_part)
    if lhs then
      table.insert(segments, "[" .. lhs .. "] add")
    end
  end
  if is_hint_enabled(show_hints.remove) or is_hint_enabled(show_hints.remove_at) then
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
      local prune_text = prune:gsub("^ • ", "")
      table.insert(segments, prune_text)
    end
  end
  if is_hint_enabled(show_hints.edit_entries) then
    table.insert(segments, "[" .. kb.edit_entries .. "] edit")
  end

  local toggle_global_part = state.global_picker and "local" or "global"
  local toggle_absolute_part = window_state.show_absolute and "rel" or "abs"

  if is_hint_enabled(show_hints.toggle_global_picker) and is_hint_enabled(show_hints.toggle_absolute) then
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
