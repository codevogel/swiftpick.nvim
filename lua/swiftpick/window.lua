---@module "swiftpick.window"

---Overrides that can be applied when opening the picker window, allowing for temporary changes to the display of absolute paths and the use of global context.
---@class SwiftpickOpenPickerOverrides
---@field display_absolute_paths? boolean Whether to override the default display of absolute paths in the picker
---@field use_global_context? boolean Whether to override the default use of global context for the picker

local config = require("swiftpick.config")
local binds = require("swiftpick.binds")
local storage = require("swiftpick.storage")
local paths = require("swiftpick.helper.paths")
local state = require("swiftpick.state")
local footer = require("swiftpick.helper.footer")

local HINT_NAMESPACE = vim.api.nvim_create_namespace("swiftpick_hints")
local NUMBERWIDTH = 2
local edit_line_count = 0
local exit_edit_mode_auto_cmd_id = nil
local show_hints_in_edit_mode_autocmd_id = nil
local old_guicursor = nil

---Hides the cursor inside the picker window by applying a fully-blended
---highlight group to the cursor option string. The original value is saved
---so it can be restored by `show_cursor()`.
local function hide_cursor()
  if old_guicursor == nil then
    old_guicursor = vim.o.guicursor
  end
  vim.api.nvim_set_hl(0, "SwiftpickCursor", { blend = 100, nocombine = true })
  vim.opt.guicursor:append("a:SwiftpickCursor/SwiftpickCursor")
end

---Restores the original `guicursor` value saved by `hide_cursor()`.
local function show_cursor()
  if old_guicursor ~= nil then
    vim.o.guicursor = old_guicursor
    old_guicursor = nil
  end
end

--- Returns the identifier used for empty entries in the picker, as defined in the config.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
end

--- Converts a list of file paths to either absolute or relative paths based on the current `state.display_absolute_paths`.
---@param entries string[] The list of file paths to be displayed in the picker, typically retrieved from storage.
---@return string[] result The entries to display in the picker, in either absolute or relative form.
local function get_display_entries(entries)
  if state.display_absolute_paths then
    return entries
  end

  local relative_entries = {}

  local cwd = vim.uv.cwd()
  if not cwd then
    vim.notify("Error retrieving current working directory; cannot convert to relative paths.", vim.log.levels.ERROR)
    return entries
  end

  for _, entry in ipairs(entries) do
    table.insert(relative_entries, paths.to_relative(entry, cwd))
  end

  return relative_entries
end

--- Calculates the appropriate size for the picker window based on the number
--- of entries to display and the length of the longest entry,
--- while respecting the current editor dimensions
--- and ensuring space for line numbers and padding.
---@param buf_size { width: integer, height: integer }
---@param footer_content string
---@return { width: integer, height: integer }
local function get_window_size(buf_size, footer_content)
  local footer_size = #footer_content
  local padding_r = 2
  local numberwidth_extra_padding = 2

  return {
    width = vim.fn.max({
      vim.fn.min({
        buf_size.width + NUMBERWIDTH + numberwidth_extra_padding,
        vim.o.columns - 4,
      }),
      footer_size,
    }) + padding_r,

    height = vim.fn.min({
      vim.fn.max({ buf_size.height + 1, 5 }),
      vim.o.lines - 4,
    }),
  }
end

---Measures the content of a buffer and returns its width and height.
---Used to compute the initial floating window dimensions before it is displayed.
---@param entry_buf_nr integer Buffer handle to measure.
---@return { width: integer, height: integer }  Width is the longest line length; height is the line count.
local function get_buf_size(entry_buf_nr)
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

--- Calculates the configuration for the picker window, centering it in
--- the editor and sizing it based on the number of entries and their lengths.
---@param picker_buf_handle integer The buffer handle for the picker buffer.
---@param display_entries string[] The list of entries to be displayes in the picker.
---@return vim.api.keyset.win_config
local function get_centered_win_config(picker_buf_handle, display_entries)
  local footer_content = footer.get_picker_footer(display_entries)
  local win_size = get_window_size(get_buf_size(picker_buf_handle), footer_content)

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
    title = state.use_global_context and "swiftpick [global]" or "swiftpick",
    title_pos = "center",
    footer = footer_content,
    footer_pos = "center",
  }
end

--- Renders extmarks in the picker buffer to show keybind hints for the first 10 entries,
--- based on the configured keybinds for picking entries.
local function show_hints()
  local char_keybinds = config.values.keybinds.pick_entry.chars

  local hints = {}
  for i = 1, 10 do
    local key = char_keybinds["_" .. i]
    if key ~= nil then
      hints[i] = key
    end
  end

  local buf = state.edit_mode and state.picker_list_edit_buf or state.picker_list_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    error("Cannot show hints: picker buffer " .. buf .. " is not valid")
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, HINT_NAMESPACE, 0, -1)

  local count = vim.api.nvim_buf_line_count(buf)
  for i, label in ipairs(hints) do
    if i <= count then
      vim.api.nvim_buf_set_extmark(buf, HINT_NAMESPACE, i - 1, 0, {
        sign_text = label,
        sign_hl_group = "Comment",
      })
    end
  end
end

--- Cleans up the picker buffers and window when exiting the picker, and restores any overridden settings.
---@param overrides_applied SwiftpickOpenPickerOverrides A table indicating which overrides were applied when opening the picker.
local function on_exit_picker(overrides_applied)
  show_cursor()

  vim.api.nvim_buf_delete(state.picker_list_buf, { force = true })
  vim.api.nvim_buf_delete(state.picker_list_edit_buf, { force = true })

  state.picker_list_buf = nil
  state.picker_win = nil

  state.opened_picker_from = { buf = nil, win = nil }

  if overrides_applied.display_absolute_paths then
    state.display_absolute_paths = state.session_memory.before_overrides.display_absolute_paths
    state.session_memory.before_overrides.display_absolute_paths = nil
  end

  if overrides_applied.use_global_context then
    state.use_global_context = state.session_memory.before_overrides.use_global_context
    state.session_memory.before_overrides.display_absolute_paths = nil
  end

  if exit_edit_mode_auto_cmd_id then
    vim.api.nvim_del_autocmd(exit_edit_mode_auto_cmd_id)
    exit_edit_mode_auto_cmd_id = nil
  end
  if show_hints_in_edit_mode_autocmd_id then
    vim.api.nvim_del_autocmd(show_hints_in_edit_mode_autocmd_id)
    show_hints_in_edit_mode_autocmd_id = nil
  end
end

--- Applies any overrides specified when opening the picker, such as forcing absolute path display or global context.
--- Overrides are stored in `state.session_memory.before_overrides` to be restored when the picker is closed.
---@param override_opts? SwiftpickOpenPickerOverrides An optional table of overrides to apply when opening the picker.
---@return SwiftpickOpenPickerOverrides applied_overrides A table indicating which overrides were applied.
local function apply_open_picker_overrides(override_opts)
  local display_absolute_paths_overridden = false
  local use_global_context_overridden = false

  override_opts = override_opts or {}

  if override_opts.display_absolute_paths ~= nil then
    state.session_memory.before_overrides.display_absolute_paths = state.display_absolute_paths
    state.display_absolute_paths = not override_opts.display_absolute_paths
    display_absolute_paths_overridden = true
  end

  if override_opts.use_global_context ~= nil then
    state.session_memory.before_overrides.use_global_context = state.use_global_context
    state.use_global_context = override_opts.use_global_context
    use_global_context_overridden = true
  end

  if
    not display_absolute_paths_overridden and not state.session_memory.default_value_for_display_absolute_paths_set
  then
    state.display_absolute_paths = not config.values.display_absolute_path_by_default
    state.session_memory.default_value_for_display_absolute_paths_set = true
  end

  if not use_global_context_overridden and not state.session_memory.default_value_for_use_global_context_set then
    state.use_global_context = config.values.use_global_context_by_default
    state.session_memory.default_value_for_use_global_context_set = true
  end

  return {
    display_absolute_paths = display_absolute_paths_overridden,
    use_global_context = use_global_context_overridden,
  }
end

---Creates and manages the picker window.
---@class SwiftpickWindow
local M = {}

---Creates the picker window and its associated buffers, applies any specified overrides, and sets up autocmds and keybinds for managing the picker session.
---@param open_picker_overrides? SwiftpickOpenPickerOverrides An optional table of overrides to
function M.create_picker_window(open_picker_overrides)
  -- Apply any overrides specified for this picker session and store the original values for restoration on exit
  local overrides_applied = apply_open_picker_overrides(open_picker_overrides)

  -- Create the picker buffer and window with minimal config (we override the window config later)
  state.picker_list_buf = vim.api.nvim_create_buf(false, true)
  state.picker_win = vim.api.nvim_open_win(
    state.picker_list_buf,
    true,
    { relative = "editor", width = 1, height = 1, row = 0, col = 0, style = "minimal" }
  )

  -- Create the edit buffer for edit mode, which is hidden until edit mode is activated
  state.picker_list_edit_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(state.picker_list_edit_buf, "swiftpick://edit")
  vim.bo[state.picker_list_edit_buf].buftype = "acwrite"

  -- Register autocmds to clean up buffers and window when the picker is closed,
  -- either by picking an entry or manually closing the window.
  local function make_win_leave_autocmd(buf)
    vim.api.nvim_create_autocmd("WinLeave", {
      once = true,
      callback = function()
        on_exit_picker(overrides_applied)
      end,
      buf = buf,
    })
  end
  make_win_leave_autocmd(state.picker_list_buf)
  make_win_leave_autocmd(state.picker_list_edit_buf)

  -- Cresate keybinds for the picker buffer and edit buffer
  binds.create_picker_keybinds(state.picker_list_buf)
  binds.create_edit_mode_keybinds(state.picker_list_edit_buf)
  -- Enter picker mode
  M.switch_to_pick_mode()
end

---Switches the picker to pick mode, allowing the user to pick from the list of entries.
function M.switch_to_pick_mode()
  if not state.picker_win or not vim.api.nvim_win_is_valid(state.picker_win) then
    vim.notify("Cannot switch to pick mode: picker window is not valid", vim.log.levels.ERROR)
    return
  end

  -- Set picker mode state
  state.edit_mode = false
  vim.cmd("stopinsert")
  vim.api.nvim_win_set_buf(state.picker_win, state.picker_list_buf)

  -- Apply style settings for picker mode
  hide_cursor()
  vim.wo[state.picker_win].number = true
  vim.wo[state.picker_win].cursorline = false
  vim.wo[state.picker_win].numberwidth = NUMBERWIDTH

  -- Refresh the picker window to load the correct entries and rescale the window.
  M.refresh_picker_window()
end

---Switches the picker to edit mode, allowing the user to directly edit the list of entries
---or pick from the highlighted line.
function M.switch_to_edit_mode()
  if not state.picker_win or not vim.api.nvim_win_is_valid(state.picker_win) then
    vim.notify("Cannot switch to edit mode: picker window is not valid", vim.log.levels.ERROR)
    return
  end

  -- Set edit mode state
  state.edit_mode = true
  vim.bo[state.picker_list_edit_buf].modified = false
  vim.api.nvim_win_set_buf(state.picker_win, state.picker_list_edit_buf)

  -- Apply style settings for edit mode
  show_cursor()
  vim.wo[state.picker_win].number = true
  vim.wo[state.picker_win].cursorline = true
  vim.wo[state.picker_win].numberwidth = NUMBERWIDTH

  -- Register an autocmd to validate and save the edited list of entries when the user writes the buffer.
  -- We store it's id so we can remove it in on_exit_picker.
  exit_edit_mode_auto_cmd_id = vim.api.nvim_create_autocmd("BufWriteCmd", {
    once = false, -- we want this to trigger every time the user writes in edit mode until the picker is closed
    buf = state.picker_list_edit_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(state.picker_list_edit_buf, 0, -1, false)
      local cwd = vim.uv.cwd()
      local seen = {}
      local valid_lines = {}

      for _, line in ipairs(lines) do
        local abs = paths.to_absolute(line, cwd)

        if abs == EMPTY() then
          table.insert(valid_lines, abs)
        elseif vim.fn.filereadable(abs) == 1 and not seen[abs] then
          seen[abs] = true
          table.insert(valid_lines, abs)
        end
      end

      while #valid_lines > 0 and valid_lines[#valid_lines] == EMPTY() do
        table.remove(valid_lines)
      end

      if state.use_global_context then
        storage.set_filenames_global(valid_lines)
      else
        storage.set_filenames_for_cwd(cwd, valid_lines)
      end

      vim.bo[state.picker_list_edit_buf].modified = false

      vim.schedule(function()
        M.switch_to_pick_mode()
      end)
    end,
  })

  -- Register an autocmd to update the hints extmarks whenever the user adds a new line in edit mode,
  -- we show hints for those new lines as well.
  -- We store it's id so we can remove it in on_exit_picker.
  -- We track the line count in the edit buffer and only update hints when it changes to avoid unnecessary updates on every text change.
  edit_line_count = vim.api.nvim_buf_line_count(state.picker_list_edit_buf)
  show_hints_in_edit_mode_autocmd_id = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    once = false, -- we want this to trigger every time the user changes text in edit mode until the picker is closed
    buf = state.picker_list_edit_buf,
    callback = function()
      local current_count = vim.api.nvim_buf_line_count(state.picker_list_edit_buf)
      if current_count ~= edit_line_count then
        edit_line_count = current_count
        show_hints()
      end
    end,
  })

  M.refresh_picker_window()
end

---Refreshes the contents of the picker window based on the current storage entries and display settings,
---and updates the window configuration to ensure it is sized and centered appropriately.
function M.refresh_picker_window()
  local buf = state.edit_mode and state.picker_list_edit_buf or state.picker_list_buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local display_entries = get_display_entries(
      state.use_global_context and storage.get_filenames_global()
        or storage.get_filenames_for_cwd(vim.uv.cwd() --[[@as string]])
    )

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_entries)

    if buf == state.picker_list_edit_buf then
      vim.bo[buf].modified = false
    end

    vim.api.nvim_win_set_config(state.picker_win, get_centered_win_config(buf, display_entries))

    show_hints()
    return
  end
  -- buf is nil or not valid here, likely because the window was closed while this was called, so this is just a no-op.
end

return M
