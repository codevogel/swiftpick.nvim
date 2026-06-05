local M = {}

local config = require("swiftpick2.config")
local helper = require("swiftpick2.lib.picker.helper")
local binds = require("swiftpick2.lib.picker.binds")
local storage = require("swiftpick2.storage")
local paths = require("swiftpick2.lib.picker.paths")

local HINT_NAMESPACE = vim.api.nvim_create_namespace("swiftpick_hints")
local NUMBERWIDTH = 2
local function EMPTY()
  return config.values.empty_entry_identifier
end

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

local function get_display_entries(cwd)
  local entries = storage.get_filenames_for_cwd(cwd)
  if window_state.show_absolute then
    return entries
  end
  local result = {}
  for _, entry in ipairs(entries) do
    table.insert(result, paths.to_relative(entry, cwd))
  end
  return result
end

local plugin_state = require("swiftpick2.state")

local function get_window_size(buf_size)
  local footer_size = #helper.get_picker_footer()
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

local function get_centered_win_config(entry_buf_nr)
  local win_size = get_window_size(helper.get_buf_size(entry_buf_nr))
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
    title = "swiftpick",
    title_pos = "center",
    footer = helper.get_picker_footer(),
    footer_pos = "center",
  }
end

local function show_hints(buf)
  local char_keybinds = config.values.keybinds.pick_entry.chars
  -- select all non-nil values from char_keybinds and couple them with their index in a table
  local hints = {}
  for i = 1, 10 do
    local key = char_keybinds["_" .. i]
    if key ~= nil then
      hints[i] = key
    end
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

function M.create_picker_window(on_exit_callback)
  if not window_state.default_value_for_show_absolute_set then
    window_state.show_absolute = not config.values.show_relative_path_by_default
    window_state.default_value_for_show_absolute_set = true
  end
  window_state.entry_list_buf = vim.api.nvim_create_buf(false, true)
  window_state.picker_win =
    vim.api.nvim_open_win(window_state.entry_list_buf, true, get_centered_win_config(window_state.entry_list_buf))
  window_state.edit_mode_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(window_state.edit_mode_buf, "swiftpick://edit")
  vim.bo[window_state.edit_mode_buf].buftype = "acwrite"

  -- WinLeave fires for whichever buffer is current in the picker window,
  -- so register the autocmd on both buffers.
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

function M.switch_to_entry_list()
  plugin_state.edit_mode = false
  vim.cmd("stopinsert")

  vim.api.nvim_buf_set_lines(window_state.entry_list_buf, 0, -1, false, get_display_entries(vim.uv.cwd()))
  vim.api.nvim_win_set_buf(window_state.picker_win, window_state.entry_list_buf)
  helper.hide_cursor()

  vim.wo[window_state.picker_win].number = true
  vim.wo[window_state.picker_win].cursorline = false
  vim.wo[window_state.picker_win].numberwidth = NUMBERWIDTH

  M.refresh_picker_window()
end

function M.switch_to_edit_mode()
  plugin_state.edit_mode = true

  vim.api.nvim_buf_set_lines(window_state.edit_mode_buf, 0, -1, false, get_display_entries(vim.uv.cwd()))
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
          table.insert(valid_lines, abs)
        elseif vim.fn.filereadable(abs) == 1 and not seen[abs] then
          seen[abs] = true
          table.insert(valid_lines, abs)
        end
      end
      -- Remove trailing <empty> entries
      while #valid_lines > 0 and valid_lines[#valid_lines] == EMPTY() do
        table.remove(valid_lines)
      end
      storage.set_filenames_for_cwd(cwd, valid_lines)
      vim.bo[window_state.edit_mode_buf].modified = false
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

function M.toggle_absolute()
  window_state.show_absolute = not window_state.show_absolute
  M.refresh_picker_window()
end

function M.refresh_picker_window()
  local buf = require("swiftpick2.state").edit_mode and window_state.edit_mode_buf or window_state.entry_list_buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, get_display_entries(vim.uv.cwd()))
    if buf == window_state.edit_mode_buf then
      vim.bo[buf].modified = false
    end
    vim.api.nvim_win_set_config(window_state.picker_win, get_centered_win_config(buf))
    show_hints(buf)
  end
end

return M
