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

function M.get_picker_footer()
  local kb = config.values.keybinds

  if require("swiftpick2.state").edit_mode then
    return string.format("  [%s] pick entry • [:w] save changes • [q] exit  ", kb.pick_highlighted_entry)
  end

  local footer = string.format(
    "  [%s|%s] add • [%s|%s] remove%s • [%s] edit  ",
    kb.add,
    kb.add_at,
    kb.remove,
    kb.remove_at,
    get_prune_segment(),
    kb.edit_entries
  )
  return footer
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
