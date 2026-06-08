# swiftpick.nvim

`swiftpick.nvim` is a [Neovim](https://neovim.io/) plugin that provides a simple
and efficient way to quickly switch between files in a project. It's heavily
inspired by [Harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2),
with some additions that I find to immensely improve the user experience.

## Features

- **Instant File Navigation**: Quickly switch between files in your project with
  just one or two keystrokes.
- **Easy Editing**: Modify your switch list directly like a normal buffer.
- **Project-aware or global contexts**: Use separate file lists per project or
  one shared, global list.
- **Relative or absolute paths**: Toggle how file paths are displayed.
- **Flexible Hotkey Placement**: Insert or remove files at any hotkey. Entries
  automatically shift, and missing slots are filled as needed.
- **Prune empty entries**: Remove all empty slots in one action, compacting the
  list.
- **Highly configurable**: Easily change key mappings, picker hints, and more.

## Options

The default options for `swiftpick` are as follows:

```lua
{
  -- name of the storage file
  filename = "swiftpick.json",
  -- directory where the storage file will be saved
  storage_path = vim.fn.stdpath("data") .. "/swiftpick/",
  -- show relative (true) or absolute (false) paths in the picker
  show_relative_path_by_default = true,
  -- show global picker (true) or project-specific picker (false)
  -- by default. can be overridden with a keybind:
  -- `swiftpick.picker.open_picker({ global_picker = true | false })`
  global_picker_by_default = false,
  -- placeholder text for empty entries.
  -- you can shorten this to something like "<e>" if you tend to
  -- add empty entries manually
  empty_entry_identifier = "<empty>",
  -- whether to automatically create user commands for common picker actions.
  create_default_user_commands = true,
  -- the prefix for automatically created user commands.
  default_user_command_prefix = "SwiftPick",
  -- built-in keybinds for picker actions.
  -- these change the hints shown in the picker as well.
  keybinds = {
    -- open the picker
    open_picker = "<leader>h",
    -- close the picker (in addition to :q)
    close_picker = { "q", "<Esc>", "<C-c>" },
    -- exit edit mode without closing the picker
    exit_edit_mode = { "q", "<Esc>", "<C-c>" },
    -- add the current file to the end of the list
    add = "a",
    -- add the current file at a hotkey pick_entry hotkey or 1-based index
    -- (listens for a key to determine where to add the file)
    add_at = "A",
    -- remove the currently selected entry
    remove = "r",
    -- remove the entry at a hotkey pick_entry hotkey or 1-based index
    remove_at = "R",
    -- prune all empty entries from the list
    prune_empty = "p",
    -- switch to edit mode, which allows you to edit the file list
    -- directly, or navigate it's entries with vim motions and pick with 'pick_highlighted_entry'
    edit_entries = "e",
    -- toggle between global picker mode and project-specific mode
    toggle_global_picker = "t",
    -- toggle between showing relative paths and absolute paths
    toggle_absolute = "T",
    -- in edit mode, picks the currently highlighted entry in the picker.
    pick_highlighted_entry = "<CR>",
    -- pick the relevant entry from the picker window
    pick_entry = {
      -- maps character keys to the corresponding pick_entry digit.
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
      -- configurable in case you want to 0-index for some reason
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
  -- which hints to show in the picker window.
  -- e.g. hints that show the keybinds you have set above.
  show_hints = {
    -- overrides other hint options and shows all hints if set to true.
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
```

## Differences with `harpoon`

Think of `swiftpick` as `harpoon` with visibility built in, and some added
niceties.

With `harpoon`, you usually jump straight to a file via hotkeys without opening
any UI. The downside is that it’s easy to forget which key maps to what file.

`swiftpick` flips that slightly: by default, it always opens a picker to show
your full file list and bindings, but you can also just ignore these and jump
instantly like you would in `harpoon` if you already know the shortcut. So you
get both speed _and_ context when you need it.

Additionally, `swiftpick` has a few features that `harpoon` lacks:

Visible hotkey mappings: The picker shows exactly which keys map to which files.
Global + local contexts: Separate project-specific and cross-project file lists.
1st-party Lualine integration: Optional status display for current bindings and
selection.

> But why? I want to jump to files without opening a picker!

Well, you can do that with `swiftpick` too!

> Well... I still don't like it.

Fair enough. Feel free to use what you like!
