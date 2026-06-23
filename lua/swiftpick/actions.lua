---Provides actions for the Swiftpick plugin
---@module "swiftpick.actions"
---@class SwiftpickActions

local state = require("swiftpick.state")
local storage = require("swiftpick.storage")
local paths = require("swiftpick.helper.paths")
local config = require("swiftpick.config")

local function EMPTY()
  return config.values.empty_entry_identifier
end

---Actions module for Swiftpick plugin. Provides functions to manipulate the picker list, open/close the picker window, and toggle display and storage context settings.
---@class SwiftpickActions
local M = {}

---@class SwiftpickAddOpts
---@field filename? string The filename to add. Defaults to the buffer that the picker was opened from.
---@field cwd? string The cwd entry to add the file under. Defaults to `vim.uv.cwd()`.
---@field index? integer The 1-based index at which to insert the filename in the entry list. Defaults to appending at the end.
---@field use_global_context? boolean Whether to use the global context for storage. Defaults to `false`. Overrides `SwiftpickAddOpts.cwd` if `true`.

--- Add a file to the picker list.
--- Defaults to appending the file of the buffer that the picker was opened from to the end of the list, under either the storage context based on plugin state.
--- @param opts? SwiftpickAddOpts Options to override default add behavior.
function M.add(opts)
  opts = opts or {}

  if not opts.filename and not state.opened_picker_from.buf then
    vim.notify(
      "Not adding as no filename was provided, and can't retrieve it from the picker state (probably not open).",
      vim.log.levels.ERROR
    )
    return
  end
  local filename = opts.filename or vim.api.nvim_buf_get_name(state.opened_picker_from.buf)
  local cwd = opts.cwd or vim.uv.cwd()

  -- if index is provided, we insert rather than append
  if opts.index then
    if opts.use_global_context then
      storage.add_filename_at_global(filename, opts.index)
    else
      storage.add_filename_at_for_cwd(cwd, filename, opts.index)
    end
  -- if no index is provided, we append as usual
  else
    if opts.use_global_context then
      storage.add_filename_global(filename)
    else
      storage.add_filename_for_cwd(cwd, filename)
    end
  end

  require("swiftpick.window").refresh_picker_window()
end

---@class SwiftpickRemoveOpts
---@field file? string|integer The filename or 1-based index of the entry to remove.
---@field cwd? string The cwd entry to remove the file from. Defaults to `vim.uv.cwd()`.
---@field use_global_context? boolean Whether to use the global context for storage. Defaults to `false`. Overrides `SwiftpickRemoveOpts.cwd` if `true`.

--- Remove a file from the picker list by filename or index.
--- Defaults to removing the file of the buffer that the picker was opened from, under the storage context based on plugin state.
--- @param opts? SwiftpickRemoveOpts Options to override default remove behavior.
function M.remove(opts)
  opts = opts or {}

  if not opts.file and not state.opened_picker_from.buf then
    vim.notify(
      "Not removing as no file was provided, and can't retrieve it from the picker state (probably not open).",
      vim.log.levels.ERROR
    )
    return
  end

  local file = opts.file or vim.api.nvim_buf_get_name(state.opened_picker_from.buf)
  local cwd = opts.cwd or vim.uv.cwd()

  if type(file) == "number" then
    local index = file
    if opts.use_global_context then
      storage.remove_filename_at_global(index)
    else
      storage.remove_filename_at_for_cwd(cwd, index)
    end
  elseif type(file) == "string" then
    local filename = file
    if opts.use_global_context then
      storage.remove_filename_global(filename)
    else
      storage.remove_filename_for_cwd(cwd, filename)
    end
  else
    vim.notify(
      "Invalid file identifier for removal: must be filename string or 1-based index number",
      vim.log.levels.ERROR
    )
    return
  end

  require("swiftpick.window").refresh_picker_window()
end

---Open the swiftpick picker window.
---Respects `config.global_picker_by_default` when `global_picker` is not provided.
---Stores the calling window and buffer in `state` so they can be restored on close.
---Does nothing if the picker is already open.
---@param opts? SwiftpickOpenPickerOverrides options to customize the picker behavior
function M.open_picker(opts)
  if state.picker_win ~= nil then
    return
  end
  -- Resolve the nil/bool tri-state: nil → config default, bool → explicit override.
  state.opened_picker_from = { buf = vim.api.nvim_get_current_buf(), win = vim.api.nvim_get_current_win() }
  require("swiftpick.window").create_picker_window(opts)
end

--- Close the picker window if it is open and valid.
function M.close_picker()
  if state.picker_win and vim.api.nvim_win_is_valid(state.picker_win) then
    vim.api.nvim_win_close(state.picker_win, true)
  end
end

---@class SwiftpickPruneOpts
---@field cwd? string The cwd entry to prune entries from. Defaults to `vim.uv.cwd()`.
---@field use_global_context? boolean Whether to use the global context for storage. Defaults to `false`. Overrides `SwiftpickPruneOpts.cwd` if `true`.

--- Prune empty and duplicate entries from the picker list.
--- Defaults to pruning the storage context based on plugin state.
--- @param opts? SwiftpickPruneOpts Options to override default prune behavior.
function M.prune_entries(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.uv.cwd()
  if opts.use_global_context then
    storage.prune_entries_global()
  else
    storage.prune_entries(cwd)
  end

  require("swiftpick.window").refresh_picker_window()
end

--- Toggle the display of absolute paths in the picker.
function M.toggle_display_absolute_paths()
  state.display_absolute_paths = not state.display_absolute_paths
  require("swiftpick.window").refresh_picker_window()
end

--- Set whether to display absolute paths in the picker.
--- @param absolute boolean Whether to display absolute paths.
function M.set_display_absolute_paths(absolute)
  state.display_absolute_paths = absolute
  require("swiftpick.window").refresh_picker_window()
end

--- Toggle between global and local storage contexts for the picker.
--- Note that individual add/remove/prune actions can be overridden to use either context regardless of this state.
function M.toggle_use_global_context()
  state.use_global_context = not state.use_global_context
  require("swiftpick.window").refresh_picker_window()
end

--- Set whether to use the global storage context for the picker.
--- Note that individual add/remove/prune actions can be overridden to use either context regardless of this state.
--- @param use_global boolean Whether to use the global context.
function M.set_use_global_context(use_global)
  state.use_global_context = use_global
  require("swiftpick.window").refresh_picker_window()
end

--- Switch the picker window to pick mode, allowing selection and opening of files.
--- No-ops if the picker window is not open or valid.
function M.switch_to_pick_mode()
  require("swiftpick.window").switch_to_pick_mode()
end

--- Switch the picker window to edit mode, allowing direct editing of the entry list.
--- No-ops if the picker window is not open or valid.
function M.switch_to_edit_mode()
  require("swiftpick.window").switch_to_edit_mode()
end

---@class SwiftpickPickFileOpts
---@field cwd? string The cwd entry to pick the file from. Defaults to `vim.uv.cwd()`.
---@field use_global_context? boolean Whether to use the global context for storage. Defaults to `false`. Overrides `SwiftpickPickFileOpts.cwd` if `true`.

--- Open the specified file from the picker list.
--- Defaults to picking from the storage context based on plugin state.
--- @param file string|integer The filename or 1-based index of the entry to pick.
--- @param opts? SwiftpickPickFileOpts Options to override default pick behavior.
function M.pick_file(file, opts)
  opts = opts or {}

  local cwd = opts.cwd or vim.uv.cwd()
  local use_global_context = opts.use_global_context or state.use_global_context

  -- Parse the filepath from file as either a 1-based index or a filename string
  local filepath = file
      and type(file) == "number"
      and (use_global_context and storage.get_filename_at_global(file) or storage.get_filename_at_for_cwd(cwd, file))
    or (
      type(file) == "string" and file --[[@as string]]
    )

  if filepath then
    if filepath ~= "" and filepath ~= EMPTY() then
      local absolute_path = paths.to_absolute(filepath, vim.uv.cwd())
      M.close_picker()
      if state.opened_picker_from.win and vim.api.nvim_win_is_valid(state.opened_picker_from.win) then
        vim.api.nvim_set_current_win(state.opened_picker_from.win)
      end
      vim.cmd("edit " .. vim.fn.fnameescape(absolute_path))
    end
  else
    vim.notify("No file specified to pick. Provide a file identifier in the options.", vim.log.levels.ERROR)
  end
end

return M
