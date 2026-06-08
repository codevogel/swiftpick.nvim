---@class SwiftpickPickEntryKeys
---@field _1 string?
---@field _2 string?
---@field _3 string?
---@field _4 string?
---@field _5 string?
---@field _6 string?
---@field _7 string?
---@field _8 string?
---@field _9 string?
---@field _10 string?

---@class SwiftpickPickEntryKeybinds
---@field chars SwiftpickPickEntryKeys
---@field digits SwiftpickPickEntryKeys

---@class SwiftpickKeybinds
---@field open_picker string
---@field close_picker string|string[]
---@field exit_edit_mode string|string[]
---@field add string
---@field add_at string
---@field remove string
---@field remove_at string
---@field prune_empty string
---@field edit_entries string
---@field toggle_global_picker string
---@field toggle_absolute string
---@field pick_highlighted_entry string
---@field pick_entry SwiftpickPickEntryKeybinds

---@class SwiftpickShowHints
---@field all boolean
---@field add boolean
---@field add_at boolean
---@field remove boolean
---@field remove_at boolean
---@field prune_empty boolean
---@field edit_entries boolean
---@field toggle_absolute boolean
---@field toggle_global_picker boolean
---@field close_picker boolean
---@field pick_highlighted_entry boolean
---@field exit_edit_mode boolean

---@class SwiftpickPickEntryKeybindsOpts
---@field chars? SwiftpickPickEntryKeys
---@field digits? SwiftpickPickEntryKeys

---@class SwiftpickKeybindsOpts
---@field open_picker? string
---@field close_picker? string|string[]
---@field exit_edit_mode? string|string[]
---@field add? string
---@field add_at? string
---@field remove? string
---@field remove_at? string
---@field prune_empty? string
---@field edit_entries? string
---@field toggle_global_picker? string
---@field toggle_absolute? string
---@field pick_highlighted_entry? string
---@field pick_entry? SwiftpickPickEntryKeybindsOpts

---@class SwiftpickShowHintsOpts
---@field all? boolean
---@field add? boolean
---@field add_at? boolean
---@field remove? boolean
---@field remove_at? boolean
---@field prune_empty? boolean
---@field edit_entries? boolean
---@field toggle_absolute? boolean
---@field toggle_global_picker? boolean
---@field close_picker? boolean
---@field pick_highlighted_entry? boolean
---@field exit_edit_mode? boolean

---@class SwiftpickConfigOpts
---@field filename? string
---@field storage_path? string
---@field show_relative_path_by_default? boolean
---@field global_picker_by_default? boolean
---@field empty_entry_identifier? string
---@field create_default_user_commands? boolean
---@field default_user_command_prefix? string
---@field keybinds? SwiftpickKeybindsOpts
---@field show_hints? SwiftpickShowHintsOpts

---@class SwiftpickConfig
---@field filename string
---@field storage_path string
---@field storage_file_path? string Derived full path; set by `setup()`.
---@field show_relative_path_by_default boolean
---@field global_picker_by_default boolean
---@field empty_entry_identifier string
---@field create_default_user_commands boolean
---@field default_user_command_prefix string
---@field keybinds SwiftpickKeybinds
---@field show_hints SwiftpickShowHints

local M = {}

---@type SwiftpickConfig
M.defaults = {
  filename = "swiftpick.json",
  storage_path = vim.fn.stdpath("data") .. "/swiftpick/",
  show_relative_path_by_default = true,
  global_picker_by_default = false,
  empty_entry_identifier = "<empty>",
  create_default_user_commands = true,
  default_user_command_prefix = "SwiftPick",
  keybinds = {
    open_picker = "<leader>h",
    close_picker = { "q", "<Esc>", "<C-c>" },
    exit_edit_mode = { "q", "<Esc>", "<C-c>" },
    add = "a",
    add_at = "A",
    remove = "r",
    remove_at = "R",
    prune_empty = "p",
    edit_entries = "e",
    toggle_global_picker = "t",
    toggle_absolute = "T",
    pick_highlighted_entry = "<CR>",
    pick_entry = {
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
    },
  },
  show_hints = {
    all = false,
    add = true,
    add_at = true,
    remove = true,
    remove_at = true,
    prune_empty = true,
    edit_entries = true,
    toggle_absolute = false,
    toggle_global_picker = false,
    close_picker = true,
    pick_highlighted_entry = true,
    exit_edit_mode = true,
  },
}

---@type SwiftpickConfig
M.values = vim.deepcopy(M.defaults)

---@param opts? SwiftpickConfigOpts
function M.setup(opts)
  -- Deep-merge user opts over a copy of defaults so defaults are never mutated.
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  -- verify filename opt is valid
  if not M.values.filename:match("%.json$") then
    error("Filename must end with .json")
  end
  if not M.values.storage_path:match("/$") then
    M.values.storage_path = M.values.storage_path .. "/"
  end
  -- Derive the full storage file path from the (possibly corrected) parts.
  M.values.storage_file_path = M.values.storage_path .. M.values.filename
end

return M
