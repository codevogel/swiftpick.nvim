---@class SwiftpickPickEntryKeybinds
---@field digits table<string, string|nil> Digit shortcuts for picker slots 1–10 (keys `_1`–`_10`)
---@field chars  table<string, string|nil> Char shortcuts for picker slots 1–10 (keys `_1`–`_10`)

---@class SwiftpickKeybinds
---@field open_picker            string
---@field close_picker           string|string[]
---@field exit_edit_mode         string|string[]
---@field add                    string
---@field add_at                 string
---@field remove                 string
---@field remove_at              string
---@field prune_empty            string
---@field edit_entries           string
---@field toggle_global_picker   string
---@field toggle_absolute        string
---@field pick_highlighted_entry string
---@field pick_entry             SwiftpickPickEntryKeybinds

---@class SwiftpickShowHints
---@field all                    boolean Master switch – when `true` all hints are shown regardless of individual flags
---@field add                    boolean
---@field add_at                 boolean
---@field remove                 boolean
---@field remove_at              boolean
---@field prune_empty            boolean
---@field edit_entries           boolean
---@field toggle_absolute        boolean
---@field toggle_global_picker   boolean
---@field close_picker           boolean
---@field pick_highlighted_entry boolean
---@field exit_edit_mode         boolean

---@class SwiftpickConfig
---@field filename                      string            JSON storage filename (must end with `.json`)
---@field storage_path                  string            Directory that holds the JSON file
---@field storage_file_path             string            Full resolved path (`storage_path .. filename`); populated by `setup()`
---@field show_relative_path_by_default boolean           Display relative paths in the picker by default
---@field global_picker_by_default      boolean           Open the global (cross-cwd) picker by default
---@field empty_entry_identifier        string            Sentinel string used as a placeholder for empty slots
---@field create_default_user_commands  boolean           Register `:SwiftPick*` user commands automatically on setup
---@field default_user_command_prefix   string            Prefix prepended to every generated user command name
---@field keybinds                      SwiftpickKeybinds
---@field show_hints                    SwiftpickShowHints

local M = {}

---Default configuration values.
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

---Active resolved configuration, populated after calling `setup()`.
---@type SwiftpickConfig
M.values = {}

---Initialise swiftpick with user options merged on top of `M.defaults`.
---Must be called before using any other swiftpick module.
---@param opts? SwiftpickConfig Partial config overrides; missing keys fall back to `M.defaults`
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
