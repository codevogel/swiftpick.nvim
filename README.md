# swiftpick.nvim

`swiftpick.nvim` is a [Neovim](https://neovim.io/) plugin that provides a simple
and efficient way to quickly switch between files in a project. It's heavily
inspired by [Harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2),
with some workflow changes that I find to immensely improve the user experience.

Demo:

![Demo of swiftpick.nvim in action](https://raw.githubusercontent.com/codevogel/swiftpick.nvim/refs/heads/main/demo/cwd/demo.gif)

## Features

- **Instant File Navigation**: Quickly switch between files in your project with
  just one or two keystrokes.
- **Easy Editing**: Modify your switch list directly like a normal buffer.
- **Project-aware or global contexts**: Use separate file lists per project or
  one shared, global list.
- **Relative or absolute paths**: Toggle how file paths are displayed.
- **Flexible Hotkey Placement**: Insert or remove files at any hotkey. Entries
  automatically shift, and missing slots are filled as needed.
- **Prune entries**: Remove all empty or duplicate slots in one action,
  compacting the list.
- **Highly configurable**: Easily change key mappings, picker hints, and more.

## Quickstart

This section contains ready-made configurations you can copy and paste straight
into your Neovim setup.

### `lz.n`

Example configuration for [`lz.n`](https://github.com/lumen-oss/lz.n):

```lua
return {
  "swiftpick.nvim",
  keys = {
    { "<leader>h", "<CMD>SwiftPick", desc = "Open SwiftPick" },
    { "<leader>H", "<CMD>SwiftPickGlobal", desc = "Open SwiftPick [Global]" },
  },
  after = function()
    require("swiftpick").setup({
      -- your options here
    })
  end,
}
```

### `lazy.nvim`

Example configuration for [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
return {
  "codevogel/swiftpick.nvim",
  opts = {
      -- your options here
  },
  keys = {
    { "<leader>h", "<CMD>SwiftPick", desc = "Open SwiftPick" },
    { "<leader>H", "<CMD>SwiftPickGlobal", desc = "Open SwiftPick" },
  },
}
```

### Manual Setup

A minimal manual setup for `swiftpick` is as follows:

```lua
require("swiftpick").setup({})
vim.keymap.set("n", "<leader>h", function()
  require("swiftpick.actions").open_picker()
end, { desc = "Open SwiftPick" })

-- Optional: Configure an alternative hotkey to open the picker with
-- the global context as default.
vim.keymap.set("n", "<leader>H", function()
  require("swiftpick.actions").open_picker({ use_global_context = true })
end, { desc = "Open SwiftPick" })
```

## Configuration

`swiftpick` is designed to work out of the box with zero configuration, but you
can change it's behavior to fit your workflow. See the tables below (or your
`lua-ls` type hints!) for a detailed description of what each configuration
option does.

The options that are of main interest are:

<!-- markdownlint-disable MD013 -->

- `display_absolute_path_by_default`: Whether to show absolute paths in the
  picker by default.
- `use_global_context_by_default` and `use_global_context_by_default`: Whether
  to use the global storage context by default (This sets the context used when
  `swiftpick` is opened for the first time using `:SwiftPick` or
  `require("swiftpick.actions").open_picker()`. Individual calls can be
  overridden with
  `require("swiftpick.actions").open_picker({ use_global_context = true|false, display_absolute_paths = true|false })`.
  Note that these overrides do not store the current toggle state in your
  session.
- `keybinds`: Keybinds that are available when the picker window is open. Feel
  free to re-use other keybinds from your config, as they will be overridden in
  the picker context.
  - `keybinds.pick_entry.chars` is a `<string, string|nil>` table that takes in
    a `_<index>` on the lefthand side and a `char` on the righthand side which
    you want to assign that index to. By default, this makes `<leader>ha` pick
    the first file, `<leader>hj` the second file, etc. **Note:** Changing these
    values will automatically update the key hint shown in the picker window as
    well!
  - `keybinds.pick_entry.digits` is a similar table, allowing you re-assign the
    digit mappings. 1-indexed by default, so `<leader>h1` picks the first file,
    `<leader>h2` picks the second file, etc., but if you really want to 0-index
    them for some strange reason, you can!
- `show_hints`: A table that enables / disables keybind-hints for any of the
  actions available in the picker window. If you already know the keybinds, you
  can disable them to clean up how the picker window looks. If `all` is `true`,
  all hints are shown. If `all` is `false`, no hints are shown. Set `all` to
  `nil` (default) if you want to only show/hide specific hint keys.

<!-- markdownlint-restore -->

The default options for `swiftpick` are as follows:

```lua
require("swiftpick".setup({
  filename = "swiftpick.json"
  storage_path = vim.fn.stdpath("data") .. "/swiftpick/"
  display_absolute_path_by_default = false
  use_global_context_by_default = false
  empty_entry_identifier = "<empty>"
  create_default_user_commands = true
  default_user_command_prefix = "SwiftPick"
  keybinds = {
    open_picker = "<leader>h"
    close_picker = { "q", "<Esc>", "<C-c>" }
    exit_edit_mode = { "q", "<Esc>", "<C-c>" }
    add = "a"
    add_at = "A"
    remove = "r"
    remove_at = "R"
    prune_entries = "p"
    edit_entries = "e"
    toggle_use_global_context = "t"
    toggle_display_absolute_paths = "T"
    pick_highlighted_entry = "<CR>"

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
    }
  }
  show_hints = {
    -- `all` overrides all other values in this table if not `nil`.
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
})
```

### General Options

<!-- markdownlint-disable MD013 -->

| Option                             | Type      | Default                                   | Description                                                                                                               |
| ---------------------------------- | --------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `filename`                         | `string`  | `"swiftpick.json"`                        | Name of the JSON file used to store SwiftPick data. Must end with `.json`.                                                |
| `storage_path`                     | `string`  | `vim.fn.stdpath("data") .. "/swiftpick/"` | Directory where SwiftPick data is stored.                                                                                 |
| `display_absolute_path_by_default` | `boolean` | `false`                                   | Display absolute paths in the picker by default. When `false`, paths are shown relative to the current working directory. |
| `use_global_context_by_default`    | `boolean` | `false`                                   | Use the global storage context by default.                                                                                |
| `empty_entry_identifier`           | `string`  | `"<empty>"`                               | Text used to represent empty entries in the picker.                                                                       |
| `create_default_user_commands`     | `boolean` | `true`                                    | Create the default SwiftPick user commands automatically.                                                                 |
| `default_user_command_prefix`      | `string`  | `"SwiftPick"`                             | Prefix used when creating default user commands.                                                                          |

### Keybind options

| Option                                   | Type                         | Default                     | Description                                                  |
| ---------------------------------------- | ---------------------------- | --------------------------- | ------------------------------------------------------------ |
| `keybinds.open_picker`                   | `string`                     | `"<leader>h"`               | Open the SwiftPick picker window.                            |
| `keybinds.close_picker`                  | `string[]`                   | `{ "q", "<Esc>", "<C-c>" }` | Close the picker window.                                     |
| `keybinds.exit_edit_mode`                | `string[]`                   | `{ "q", "<Esc>", "<C-c>" }` | Exit edit mode.                                              |
| `keybinds.add`                           | `string`                     | `"a"`                       | Add the current file to the picker list.                     |
| `keybinds.add_at`                        | `string`                     | `"A"`                       | Add the current file at a specific index.                    |
| `keybinds.remove`                        | `string`                     | `"r"`                       | Remove the current file from the picker list.                |
| `keybinds.remove_at`                     | `string`                     | `"R"`                       | Remove a file at a specific index.                           |
| `keybinds.prune_entries`                 | `string`                     | `"p"`                       | Remove all empty and duplicate entries from the picker list. |
| `keybinds.edit_entries`                  | `string`                     | `"e"`                       | Enter edit mode.                                             |
| `keybinds.toggle_use_global_context`     | `string`                     | `"T"`                       | Toggle between local and global storage contexts.            |
| `keybinds.toggle_display_absolute_paths` | `string`                     | `"t"`                       | Toggle absolute path display.                                |
| `keybinds.pick_highlighted_entry`        | `string`                     | `"<CR>"`                    | Open the currently highlighted entry while in edit mode.     |
| `keybinds.pick_entry.chars`              | `table<string, string\|nil>` | See default config          | Map of single-character keys to picker indices.              |
| `keybinds.pick_entry.digits`             | `table<string, string\|nil>` | See default config          | Map of digit keys to picker indices.                         |

<!-- markdownlint-restore -->

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
