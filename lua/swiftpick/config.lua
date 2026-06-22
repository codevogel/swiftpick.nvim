---@module "swiftpick.config"

---Configuration management for SwiftPick, including default values, user-provided options, and derived values.
---@class SwiftpickConfigModule
local M = {}

--- Configuration options for SwiftPick.
---@class SwiftpickConfigOpts
M.defaults = {}

---@type string The name of the JSON file where SwiftPick data is stored. Must end with '.json'.
M.defaults.filename = "swiftpick.json"
---@type string The path to the directory where SwiftPick data is stored. Defaults to Neovim's standard data path.
M.defaults.storage_path = vim.fn.stdpath("data") .. "/swiftpick/"
---@type boolean Whether to display absolute paths in the picker by default. If false, paths will be displayed relative to the current working directory.
M.defaults.display_absolute_path_by_default = false
---@type boolean Whether to use the global storage context by default.
M.defaults.use_global_context_by_default = false
---@type string The identifier used to represent empty entries in the picker.
M.defaults.empty_entry_identifier = "<empty>"
---@type boolean Whether to create default user commands for SwiftPick.
M.defaults.create_default_user_commands = true
---@type string The prefix for default user commands created by SwiftPick.
M.defaults.default_user_command_prefix = "SwiftPick"

---Keybinds that are available when the picker window is open. These keybinds are non-conflicting with your other keybinds, as they are only active when the picker window is open.
---@class SwiftpickKeybindOpts
M.defaults.keybinds = {}
---@type string Keybind to open the SwiftPick picker window.
M.defaults.keybinds.open_picker = "<leader>h"
---@type string[] Keybinds to close the SwiftPick picker window.
M.defaults.keybinds.close_picker = { "q", "<Esc>", "<C-c>" }
---@type string[] Keybinds to close the SwiftPick picker window.
M.defaults.keybinds.exit_edit_mode = { "q", "<Esc>", "<C-c>" }
---@type string Keybind to add the file that the picker was opened from to the picker list.
M.defaults.keybinds.add = "a"
---@type string Keybind to add the file that the picker was opened from to the picker list at a specific index.
M.defaults.keybinds.add_at = "A"
---@type string Keybind to remove the file that the picker was opened from from the picker list.
M.defaults.keybinds.remove = "r"
---@type string Keybind to remove the file that the picker was opened from from the picker list at a specific index.
M.defaults.keybinds.remove_at = "R"
---@type string Keybind to prune all empty and duplicate entries from the picker list.
M.defaults.keybinds.prune_entries = "p"
---@type string Keybind to enter edit mode for the picker list.
M.defaults.keybinds.edit_entries = "e"
---@type string Keybind to toggle the use of the global storage context for the picker list.
M.defaults.keybinds.toggle_use_global_context = "T"
---@type string Keybind to toggle the display of absolute paths in the picker list.
M.defaults.keybinds.toggle_display_absolute_paths = "t"
---@type string Keybind to pick the currently highlighted entry in edit mode.
M.defaults.keybinds.pick_highlighted_entry = "<CR>"

---Keybinds to pick specific entries in the picker list by index.
---@class SwiftpickPickEntryKeybindOpts
M.defaults.keybinds.pick_entry = {
  ---@type table<string, string|nil> Keybinds to pick specific entries in the picker list by index.
  chars = {
    _1 = "h",
    _2 = "j",
    _3 = "k",
    _4 = "l",
    _5 = nil,
    _6 = nil,
    _7 = nil,
    _8 = nil,
    _9 = nil,
    _10 = nil,
  },
  ---@type table<string, string|nil> Keybinds to pick specific entries in the picker list by index using digits.
  digits = {
    _1 = "1",
    _2 = "2",
    _3 = "3",
    _4 = "4",
    _5 = "5",
    _6 = "6",
    _7 = "7",
    _8 = "8",
    _9 = "9",
    _10 = "0",
  },
}

---Options for which hints to show in the picker window. These hints indicate which keybinds to use for different actions, and can be toggled on or off based on user preference.
---@class SwiftpickShowHintsOpts
M.defaults.show_hints = {
  ---@type boolean? `all` overrides all other values in this table if not `nil`.
  all = nil,
  add = true,
  add_at = true,
  remove = true,
  remove_at = true,
  prune_empty = true,
  switch_to_edit_mode = true,
  toggle_display_absolute_paths = false,
  toggle_use_global_context = false,
  close_picker = true,
  pick_highlighted_entry = true,
  exit_edit_mode = true,
}

---Derived configuration values for SwiftPick, merged from user-provided options and defaults.
---This is the table to use for all configuration values in SwiftPick, as it contains the final merged values.
---@class SwiftpickConfigValues : SwiftpickConfigOpts
M.values = {}
---@type string|nil The absolute path to the storage file where SwiftPick data is stored, derived from `storage_path` and `filename`.
M.values.storage_file_path = nil

---Bootstrap the SwiftPick configuration with user-provided options.
---@param opts? SwiftpickConfigOpts
function M.setup(opts)
  -- Deep-merge user opts over a copy of defaults so defaults are never mutated.

  local merged_opts = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  -- verify filename opt is valid
  if not merged_opts.filename:match("%.json$") then
    error("Filename must end with .json")
  end
  if not merged_opts.storage_path:match("/$") then
    merged_opts.storage_path = merged_opts.storage_path .. "/"
  end

  M.values = vim.tbl_extend("force", merged_opts, {
    storage_file_path = merged_opts.storage_path .. merged_opts.filename,
  })
end

return M
