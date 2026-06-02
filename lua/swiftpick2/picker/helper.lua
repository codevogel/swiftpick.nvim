local M = {}

local config = require("swiftpick2.config")

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

function M.get_picker_footer()
  local kb = config.values.keybinds
  local footer = string.format(
    "  [%s|%s] add • [%s|%s] remove • [%s] edit  ",
    vim.api.nvim_replace_termcodes(kb.add, true, true, true),
    vim.api.nvim_replace_termcodes(kb.add_at, true, true, true),
    vim.api.nvim_replace_termcodes(kb.remove, true, true, true),
    vim.api.nvim_replace_termcodes(kb.remove_at, true, true, true),
    vim.api.nvim_replace_termcodes(kb.edit_entries, true, true, true)
  )
  return footer
end

return M
