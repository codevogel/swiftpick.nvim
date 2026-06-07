local M = {}

local config = require("swiftpick.config")
local helper = require("swiftpick.lib.picker.helper")
local binds = require("swiftpick.lib.picker.binds")
local storage = require("swiftpick.storage")
local paths = require("swiftpick.lib.picker.paths")
local plugin_state = require("swiftpick.state")

-- Extmark namespace used to render char-keybind sign-column hints.
local HINT_NAMESPACE = vim.api.nvim_create_namespace("swiftpick_hints")
-- Width (in columns) reserved for the line-number column.
local NUMBERWIDTH = 2

---Returns the configured sentinel string for empty slots.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
end

---@class SwiftpickWindowState
---@field entry_list_buf                  integer|nil Buffer handle for the read-only entry list view
---@field edit_mode_buf                   integer|nil Buffer handle for the editable entry view
---@field edit_line_count                 integer     Last known line count of the edit buffer (used to detect additions/removals)
---@field picker_win                      integer|nil Floating window handle
---@field old_statuscolumn                string|nil  Saved `statuscolumn` value restored on close (currently unused)
---@field show_absolute                   boolean     When `true` display absolute paths; when `false` display relative paths
---@field default_value_for_show_absolute_set boolean  Whether `show_absolute` has been initialised from the config yet
---@field HINT_NS                         integer     Extmark namespace for rendering char-hint signs (alias of HINT_NAMESPACE)

---@type SwiftpickWindowState
local window_state = {
  entry_list_buf = nil,
  edit_mode_buf = nil,
  edit_line_count = 0,
  picker_win = nil,
  old_statuscolumn = nil,
  show_absolute = false,
  default_value_for_show_absolute_set = false,
  HINT_NS = vim.api.nvim_create_namespace("swiftpick_hints"),
}

---Returns the list of paths to display in the picker for the given cwd.
---Paths are converted to relative form unless `window_state.show_absolute` is `true`.
---For the global picker the current working directory is used as the relative base.
---@param cwd string Absolute path of the current working directory.
---@return string[]  Ordered list of display strings (may include EMPTY sentinels).
local function get_display_entries(cwd)
  local entries = {}
  if plugin_state.global_picker then
    entries = storage.get_filenames_global()
  else
    entries = storage.get_filenames_for_cwd(cwd)
  end
  if window_state.show_absolute then
    return entries
  end
  local result = {}
  if entries == nil then
    return result
  end
  for _, entry in ipairs(entries) do
    table.insert(result, paths.to_relative(entry, plugin_state.global_picker and vim.uv.cwd() or cwd))
  end
  return result
end

---Compute the floating window dimensions from the buffer content size and the footer.
---
---Width: clamps the content width between the footer length and 4 columns less than
---the full editor width, then adds padding. Height: clamps between a minimum of 5
---lines and 4 lines less than the full editor height.
---@param buf_size { width: integer, height: integer }  Content dimensions from `helper.get_buf_size()`.
---@param footer   string                               Footer string (its length is used as minimum width).
---@return { width: integer, height: integer }
local function get_window_size(buf_size, footer)
  local footer_size = #footer
  local padding_r = 2
  local numberwidth_extra_padding = 2
  local win_size = {
    width = vim.fn.max({
      vim.fn.min({ buf_size.width + NUMBERWIDTH + numberwidth_extra_padding, vim.o.columns - 4 }),
      footer_size,
    }) + padding_r,
    height = vim.fn.min({ vim.fn.max({ buf_size.height + 1, 5 }), vim.o.lines - 4 }),
  }
  return win_size
end

---Build a centered floating window config table for `nvim_open_win` / `nvim_win_set_config`.
---@param entry_buf_nr    integer  Buffer whose content determines the initial dimensions.
---@param display_entries string[] Current display entries (forwarded to the footer builder).
---@return table  Config table compatible with `nvim_open_win`.
local function get_centered_win_config(entry_buf_nr, display_entries)
  local footer = helper.get_picker_footer(display_entries, window_state)
  local win_size = get_window_size(helper.get_buf_size(entry_buf_nr), footer)
  local row = math.floor((vim.o.lines - win_size.height) / 2)
  local col = math.floor((vim.o.columns - win_size.width) / 2)
  return {
    relative = "editor",
    row = row,
    col = col,
    width = win_size.width,
    height = win_size.height,
    border = "rounded",
    style = "minimal",
    title = plugin_state.global_picker and "swiftpick [global]" or "swiftpick",
    title_pos = "center",
    footer = footer,
    footer_pos = "center",
  }
end

---Render char-keybind hints as sign-column extmarks next to each buffer line.
---Only the `chars` group of pick-entry keybinds is shown; `nil` entries are skipped.
---Clears existing hints in the namespace before re-rendering.
---@param buf integer Buffer handle to render hints into.
local function show_hints(buf)
  local char_keybinds = config.values.keybinds.pick_entry.chars
  -- Collect all non-nil char keybinds together with their 1-based slot index.
  local hints = {}
  for i = 1, 10 do
    local key = char_keybinds["_" .. i]
    if key ~= nil then
      hints[i] = key
    end
  end

  -- Clear stale hints before writing the new ones.
  vim.api.nvim_buf_clear_namespace(buf, HINT_NAMESPACE, 0, -1)
  local count = vim.api.nvim_buf_line_count(buf)
  for i, label in ipairs(hints) do
    -- Only add a hint for lines that actually exist in the buffer.
    if i <= count then
      vim.api.nvim_buf_set_extmark(buf, HINT_NAMESPACE, i - 1, 0, {
        sign_text = label,
        sign_hl_group = "Comment",
      })
    end
  end
end

---Tear down the picker: show cursor, delete both buffers, and invoke the exit callback.
---@param on_exit_callback function|nil Optional callback invoked after cleanup.
local function on_exit_picker(on_exit_callback)
  helper.show_cursor()
  vim.api.nvim_buf_delete(window_state.entry_list_buf, { force = true })
  vim.api.nvim_buf_delete(window_state.edit_mode_buf, { force = true })

  window_state.entry_list_buf = nil
  window_state.picker_win = nil
  if on_exit_callback then
    on_exit_callback()
  end
end

---Create and open the picker floating window.
---
---Two buffers are created up-front:
--- - `entry_list_buf`: scratch buffer shown in normal (pick) mode.
--- - `edit_mode_buf`:  named `acwrite` buffer shown in edit mode.
---
---A `WinLeave` autocmd is registered on **both** buffers so that moving focus
---away from the floating window always triggers cleanup, regardless of which
---buffer is currently displayed.
---
---@param on_exit_callback function Callback invoked when the picker window is closed.
function M.create_picker_window(on_exit_callback)
  -- Initialise the show_absolute toggle from config on first open only.
  if not window_state.default_value_for_show_absolute_set then
    window_state.show_absolute = not config.values.show_relative_path_by_default
    window_state.default_value_for_show_absolute_set = true
  end
  window_state.entry_list_buf = vim.api.nvim_create_buf(false, true)
  -- Open with a minimal 1×1 size; refresh_picker_window will resize it correctly.
  window_state.picker_win = vim.api.nvim_open_win(
    window_state.entry_list_buf,
    true,
    { relative = "editor", width = 1, height = 1, row = 0, col = 0, style = "minimal" }
  )
  window_state.edit_mode_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(window_state.edit_mode_buf, "swiftpick://edit")
  -- `acwrite` buftype: Neovim fires `BufWriteCmd` instead of writing to disk,
  -- allowing us to intercept `:w` and validate/persist the edited entries.
  vim.bo[window_state.edit_mode_buf].buftype = "acwrite"

  -- WinLeave fires for whichever buffer is current in the picker window,
  -- so register the autocmd on both buffers to guarantee cleanup.
  local function make_win_leave_autocmd(buf)
    vim.api.nvim_create_autocmd("WinLeave", {
      once = true,
      callback = function()
        on_exit_picker(on_exit_callback)
      end,
      buf = buf,
    })
  end
  make_win_leave_autocmd(window_state.entry_list_buf)
  make_win_leave_autocmd(window_state.edit_mode_buf)
  binds.create_picker_keybinds(window_state.picker_win, window_state.entry_list_buf)
  binds.create_edit_mode_keybinds(window_state.picker_win, window_state.edit_mode_buf)

  M.switch_to_entry_list()
end

---Switch the picker window to the normal entry-list view.
---Disables cursor visibility and resets window-local options appropriate for
---browsing entries, then calls `refresh_picker_window()` to populate the buffer.
function M.switch_to_entry_list()
  plugin_state.edit_mode = false
  vim.cmd("stopinsert")

  vim.api.nvim_win_set_buf(window_state.picker_win, window_state.entry_list_buf)
  helper.hide_cursor()

  vim.wo[window_state.picker_win].number = true
  vim.wo[window_state.picker_win].cursorline = false
  vim.wo[window_state.picker_win].numberwidth = NUMBERWIDTH

  M.refresh_picker_window()
end

---Switch the picker window to edit mode.
---
---Populates the edit buffer with the current entry list and enables cursor
---visibility. Two autocmds are registered (non-persistently, bound to the edit
---buffer's lifetime):
--- - `BufWriteCmd`: validates each edited line (resolves to absolute, checks
---   readability, deduplicates), strips trailing EMPTY sentinels, persists the
---   result, then returns to the entry-list view.
--- - `TextChanged` / `TextChangedI`: re-renders char-hint extmarks whenever the
---   line count changes (entries added or removed).
function M.switch_to_edit_mode()
  plugin_state.edit_mode = true

  vim.bo[window_state.edit_mode_buf].modified = false
  vim.api.nvim_win_set_buf(window_state.picker_win, window_state.edit_mode_buf)

  vim.wo[window_state.picker_win].number = true
  vim.wo[window_state.picker_win].cursorline = true
  vim.wo[window_state.picker_win].numberwidth = NUMBERWIDTH

  helper.show_cursor()

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    once = false,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(window_state.edit_mode_buf, 0, -1, false)
      local cwd = vim.uv.cwd()
      local seen = {}
      local valid_lines = {}
      for _, line in ipairs(lines) do
        local abs = paths.to_absolute(line, cwd)
        if abs == EMPTY() then
          -- Always keep EMPTY sentinels; they are filtered out by prune.
          table.insert(valid_lines, abs)
        elseif vim.fn.filereadable(abs) == 1 and not seen[abs] then
          -- Only include readable files and skip duplicates.
          seen[abs] = true
          table.insert(valid_lines, abs)
        end
      end
      -- Strip any trailing EMPTY sentinels; they serve no purpose at the end.
      while #valid_lines > 0 and valid_lines[#valid_lines] == EMPTY() do
        table.remove(valid_lines)
      end
      if plugin_state.global_picker then
        storage.set_filenames_global(valid_lines)
      else
        storage.set_filenames_for_cwd(cwd, valid_lines)
      end
      vim.bo[window_state.edit_mode_buf].modified = false
      -- Defer the switch so BufWriteCmd finishes before the buffer is swapped.
      vim.schedule(function()
        M.switch_to_entry_list()
      end)
    end,
    buf = window_state.edit_mode_buf,
  })

  window_state.edit_line_count = vim.api.nvim_buf_line_count(window_state.edit_mode_buf)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    once = false,
    callback = function()
      -- Only re-render hints when the number of lines has actually changed
      -- (an entry was added or removed), not on every keystroke.
      local current_count = vim.api.nvim_buf_line_count(window_state.edit_mode_buf)
      if current_count ~= window_state.edit_line_count then
        window_state.edit_line_count = current_count
        show_hints(window_state.edit_mode_buf)
      end
    end,
    buf = window_state.edit_mode_buf,
  })

  M.refresh_picker_window()
end

---Toggle between absolute and relative path display and refresh the window.
function M.toggle_absolute()
  window_state.show_absolute = not window_state.show_absolute
  M.refresh_picker_window()
end

---Toggle between the global and local entry list and refresh the window.
function M.toggle_global_picker()
  plugin_state.global_picker = not plugin_state.global_picker
  M.refresh_picker_window()
end

---Reload the entry list from storage, repopulate the active buffer, resize
---the floating window to fit the new content, and re-render hint extmarks.
---Safe to call from either normal or edit mode.
function M.refresh_picker_window()
  local buf = plugin_state.edit_mode and window_state.edit_mode_buf or window_state.entry_list_buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local display_entries = get_display_entries(vim.uv.cwd())
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_entries)
    if buf == window_state.edit_mode_buf then
      vim.bo[buf].modified = false
    end
    vim.api.nvim_win_set_config(window_state.picker_win, get_centered_win_config(buf, display_entries))
    show_hints(buf)
  end
end

return M
