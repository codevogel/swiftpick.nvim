local state = require("swiftpick.state")
local storage = require("swiftpick.storage")
local config = require("swiftpick.config")

local M = {}

--- Gets the shortcuts string for the given files and options.
---@param files string[] List of file names.
---@param opts SwiftpickLualineComponentOpts Options for the shortcuts string.
local function get_shortcuts_string(files, opts)
  local keys = {}

  local current_file = vim.api.nvim_buf_get_name(0)

  for i, file in ipairs(files) do
    local table_key = "_" .. i
    if file == config.values.empty_entry_identifier then
      if opts.empty_entry ~= nil and opts.empty_entry ~= "" then
        table.insert(keys, opts.empty_entry)
      end
    else
      local key = (not opts.use_digits and config.values.keybinds.pick_entry.chars[table_key])
        or config.values.keybinds.pick_entry.digits[table_key]
      table.insert(keys, file == current_file and ("%s%s%s"):format(opts.active_prefix, key, opts.active_suffix) or key)
    end
  end

  return table.concat(keys, opts.concat_separator)
end

---@type SwiftpickLualineComponentOpts
local defaults = {
  prefix = "󱗆  ",
  local_indicator = "󰟙",
  local_indicator_active = "!",
  local_prefix = " ",
  local_suffix = "",
  local_global_separator = "   ",
  global_indicator = "",
  global_indicator_active = "!",
  global_prefix = " ",
  global_suffix = "",
  active_prefix = "[",
  active_suffix = "]",
  empty_entry = "",
  concat_separator = " ",
  use_digits = false,
  only_show_active_context = false,
}

---@class SwiftpickLualineComponentOpts
---@field prefix string|nil Icon to display as indicator for the swiftpick component.
---@field local_indicator string|nil Indicator to display before the local shortcuts. (This is never shown when `only_show_active_context` is true.)
---@field local_indicator_active string|nil Indicator to display before the local shortcuts when the context is active.
---@field local_prefix string|nil Prefix to display before the local shortcuts.
---@field local_suffix string|nil Suffix to display after the local shortcuts.
---@field local_global_separator string|nil Separator to display between the local and global segments. Not used if `only_show_active_context` is true.
---@field global_indicator string|nil Indicator to display before the global shortcuts. (This is never shown when `only_show_active_context` is true.)
---@field global_indicator_active string|nil Indicator to display before the global shortcuts when the context is active.
---@field global_prefix string|nil Prefix to display before the global shortcuts.
---@field global_suffix string|nil Suffix to display after the global shortcuts.
---@field active_prefix string|nil Prefix to display before a shortcut when the file is active.
---@field active_suffix string|nil Suffix to display after a shortcut when the file is active.
---@field empty_entry string|nil String to display for an empty entry in the shortcuts list.
---@field concat_separator string|nil Separator to use when concatenating the shortcuts list.
---@field use_digits boolean|nil Whether to use digits instead of characters for the shortcuts list.
---@field only_show_active_context boolean|nil Whether to only show the keybinds for the active context.

--- Creates a lualine component function for the swiftpick plugin.
---@param opts? SwiftpickLualineComponentOpts Options for the lualine component.
function M.component(opts)
  local values = vim.tbl_deep_extend("force", defaults, opts or {})

  return function()
    local files_local = storage.get_filenames_for_cwd(vim.uv.cwd() --[[@as string]])
    local files_global = storage.get_filenames_global()

    local shortcuts_local_string = get_shortcuts_string(files_local, values)
    local shortcuts_global_string = get_shortcuts_string(files_global, values)

    if values.only_show_active_context then
      if state.use_global_context then
        return ("%s%s%s%s%s"):format(
          values.prefix,
          values.global_indicator_active,
          values.global_prefix,
          shortcuts_global_string,
          values.global_suffix
        )
      else
        return ("%s%s%s%s%s"):format(
          values.prefix,
          values.local_indicator_active,
          values.local_prefix,
          shortcuts_local_string,
          values.local_suffix
        )
      end
    end

    return ("%s%s%s%s%s%s%s%s%s"):format(
      values.prefix,
      state.use_global_context and values.local_indicator or values.local_indicator_active,
      values.local_prefix,
      shortcuts_local_string,
      values.local_suffix,
      values.local_global_separator,
      state.use_global_context and values.global_indicator_active or values.global_indicator,
      values.global_prefix,
      shortcuts_global_string,
      values.global_suffix
    )
  end
end

return M
