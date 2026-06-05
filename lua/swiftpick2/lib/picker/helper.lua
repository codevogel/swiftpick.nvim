local M = {}

local config = require("swiftpick2.config")
local storage = require("swiftpick2.storage")

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

local function get_prune_segment()
  local kb = config.values.keybinds
  local entries = storage.get_filenames_for_cwd(vim.uv.cwd())
  local has_empty = false
  for _, entry in ipairs(entries) do
    if entry == "<empty>" then
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

function M.get_picker_footer()
  local kb = config.values.keybinds
  local sh = config.values.show_hints

  if require("swiftpick2.state").edit_mode then
    local segments = {}
    if sh.pick_highlighted_entry then
      table.insert(segments, "[" .. kb.pick_highlighted_entry .. "] pick entry")
    end
    table.insert(segments, "[:w] save changes")
    if sh.exit_edit_mode then
      table.insert(segments, "[" .. get_first_keybind_if_table(kb.exit_edit_mode) .. "] exit")
    end
    return "  " .. table.concat(segments, " • ") .. "  "
  end

  local segments = {}
  if sh.add or sh.add_at then
    local add_part = sh.add and kb.add or nil
    local add_at_part = sh.add_at and kb.add_at or nil
    local lhs = (add_part and add_at_part) and (add_part .. "|" .. add_at_part)
      or (add_part or add_at_part)
    if lhs then
      table.insert(segments, "[" .. lhs .. "] add")
    end
  end
  if sh.remove or sh.remove_at then
    local remove_part = sh.remove and kb.remove or nil
    local remove_at_part = sh.remove_at and kb.remove_at or nil
    local rhs = (remove_part and remove_at_part) and (remove_part .. "|" .. remove_at_part)
      or (remove_part or remove_at_part)
    if rhs then
      table.insert(segments, "[" .. rhs .. "] remove")
    end
  end
  if sh.prune_empty then
    local prune = get_prune_segment()
    if prune ~= "" then
      table.insert(segments, prune:gsub("^ • ", ""))
    end
  end
  if sh.edit_entries then
    table.insert(segments, "[" .. kb.edit_entries .. "] edit")
  end
  if sh.toggle_absolute then
    table.insert(segments, "[" .. kb.toggle_absolute .. "] abs/rel")
  end
  if sh.close_picker then
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
