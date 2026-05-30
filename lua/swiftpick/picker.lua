local M = {}

local HINT_NS = vim.api.nvim_create_namespace("swiftpick_hints")
local HINT_LABELS = { "h", "j", "k", "l" }

local FOOTER_NORMAL = " [hjkl | 1-9] open · [a/A] add · [r/R] remove · [e] edit"
local FOOTER_ADD_AT = " add at: [hjkl | 1-9] pick slot · [Esc] cancel"
local FOOTER_REMOVE_AT = " remove at: [hjkl | 1-9] pick slot · [Esc] cancel"

local FOOTER_EDIT = " [CR] open curr line · [:w] save · [Esc] exit edit "
local TITLE_NORMAL = " swiftpick "
local TITLE_EDIT = " swiftpick [edit] "

local saved_guicursor = nil

local function hide_cursor()
  if saved_guicursor == nil then
    saved_guicursor = vim.o.guicursor
  end
  vim.api.nvim_set_hl(0, "SwiftpickCursor", { blend = 100, nocombine = true })
  vim.opt.guicursor:append("a:SwiftpickCursor/SwiftpickCursor")
end

local function show_cursor()
  if saved_guicursor ~= nil then
    vim.o.guicursor = saved_guicursor
    saved_guicursor = nil
  end
end

-- Module-level state for the active picker session.
-- `deleted` is reserved for future use (removing entries from storage on close).
local state = {
  buf = nil,
  win = nil,
  entries = {}, -- all entries: { path = string, display = string }
  cwd = nil, -- working directory when picker was opened
  origin_buf = nil, -- absolute path of the buffer that was active when the picker opened
  save_fn = nil, -- callback(abs_paths) called when the user saves in edit mode
  add_fn = nil, -- callback(path) -> abs_paths[] called when user presses 'a'
  remove_fn = nil, -- callback(path) -> abs_paths[] called when user presses 'r'
  edit_mode = false,
  deleted = {}, -- reserved for future deletion support
}

local function relpath(base, target)
  base = vim.fs.normalize(base)
  target = vim.fs.normalize(target)

  local base_parts = vim.split(base, "/", { plain = true, trimempty = true })
  local target_parts = vim.split(target, "/", { plain = true, trimempty = true })

  local i = 1
  while base_parts[i] and target_parts[i] and base_parts[i] == target_parts[i] do
    i = i + 1
  end

  local rel = {}
  for _ = i, #base_parts do
    table.insert(rel, "..")
  end
  for j = i, #target_parts do
    table.insert(rel, target_parts[j])
  end

  if #rel == 0 then
    return "."
  end
  return table.concat(rel, "/")
end

local function get_centered_win_config(width, height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
  }
end

local function apply_hints(buf)
  vim.api.nvim_buf_clear_namespace(buf, HINT_NS, 0, -1)
  local count = vim.api.nvim_buf_line_count(buf)
  for i, label in ipairs(HINT_LABELS) do
    if i <= count then
      vim.api.nvim_buf_set_extmark(buf, HINT_NS, i - 1, 0, {
        sign_text = label,
        sign_hl_group = "Comment",
      })
    end
  end
end

local function set_normal_title_footer()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  vim.api.nvim_win_set_config(state.win, {
    title = TITLE_NORMAL,
    title_pos = "center",
    footer = FOOTER_NORMAL,
    footer_pos = "center",
  })
end

local function set_edit_title_footer()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  vim.api.nvim_win_set_config(state.win, {
    title = TITLE_EDIT,
    title_pos = "center",
    footer = FOOTER_EDIT,
    footer_pos = "center",
  })
end

local function update_picker_buf(entries_list)
  local lines = {}
  for _, entry in ipairs(entries_list) do
    table.insert(lines, entry.display)
  end
  if #lines == 0 then
    lines = { "" }
  end
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  apply_hints(state.buf)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
  end
end

local function has_entry(path)
  for _, entry in ipairs(state.entries) do
    if entry.path == path then
      return true
    end
  end
  return false
end

local function resize_win()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  local new_height = math.max(1, math.min(10, #state.entries))
  local cfg = vim.api.nvim_win_get_config(state.win)
  local width = cfg.width
  local row = math.floor((vim.o.lines - new_height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  vim.api.nvim_win_set_config(state.win, { relative = "editor", height = new_height, row = row, col = col })
end

local function refresh_entries(new_abs_paths)
  state.entries = {}
  for _, abs_path in ipairs(new_abs_paths) do
    local display = abs_path == "" and "<empty>" or relpath(state.cwd, abs_path)
    table.insert(state.entries, { path = abs_path, display = display })
  end
  update_picker_buf(state.entries)
  resize_win()
end

local function do_add()
  if not (state.add_fn and state.origin_buf and state.origin_buf ~= "") then
    return
  end
  if has_entry(state.origin_buf) then
    return
  end
  local new_paths = state.add_fn(state.origin_buf)
  if new_paths then
    refresh_entries(new_paths)
  end
end

local function do_remove()
  if not (state.remove_fn and state.origin_buf and state.origin_buf ~= "") then
    return
  end
  if not has_entry(state.origin_buf) then
    return
  end
  local new_paths = state.remove_fn(state.origin_buf)
  if new_paths then
    refresh_entries(new_paths)
  end
end

local function get_position_from_char(char)
  for i, label in ipairs(HINT_LABELS) do
    if char == label then
      return i
    end
  end
  local n = tonumber(char)
  if n and n >= 1 and n <= 9 then
    return n
  end
  return nil
end

local function persist_entries()
  if state.save_fn then
    local abs_paths = {}
    for _, e in ipairs(state.entries) do
      table.insert(abs_paths, e.path)
    end
    state.save_fn(abs_paths)
  end
end

local function await_position(footer, callback)
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  vim.api.nvim_win_set_config(state.win, { footer = footer, footer_pos = "center" })
  vim.cmd("redraw")
  local ok, input = pcall(vim.fn.getchar)
  set_normal_title_footer()
  if not ok then
    return
  end
  if type(input) == "number" and input == 27 then
    return
  end
  local char = type(input) == "number" and vim.fn.nr2char(input) or tostring(input)
  local pos = get_position_from_char(char)
  if pos then
    callback(pos)
  end
end

local function do_add_at()
  if not (state.origin_buf and state.origin_buf ~= "") then
    return
  end
  await_position(FOOTER_ADD_AT, function(pos)
    local new_entries = {}
    for i = 1, pos - 1 do
      new_entries[i] = state.entries[i] or { path = "", display = "<empty>" }
    end
    new_entries[pos] = { path = state.origin_buf, display = relpath(state.cwd, state.origin_buf) }
    for i = pos, #state.entries do
      new_entries[i + 1] = state.entries[i]
    end
    state.entries = new_entries
    persist_entries()
    update_picker_buf(state.entries)
    resize_win()
  end)
end

local function do_remove_at()
  await_position(FOOTER_REMOVE_AT, function(pos)
    if pos > #state.entries then
      return
    end
    table.remove(state.entries, pos)
    persist_entries()
    update_picker_buf(state.entries)
    resize_win()
  end)
end

local function close_picker()
  show_cursor()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end
end

local function open_file(path)
  close_picker()
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function open_entry_by_index(idx)
  local entry = state.entries[idx]
  if entry and entry.path ~= "" then
    open_file(entry.path)
  end
end

local function open_entry_at_cursor()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  local line = vim.api.nvim_win_get_cursor(state.win)[1]
  open_entry_by_index(line)
end

-- Forward declarations needed for mutual reference between enter/exit_edit_mode.
local enter_edit_mode
local exit_edit_mode

-- Resolve a display path (relative to state.cwd) back to an absolute path.
-- Paths that are already absolute are returned unchanged.
local function resolve_abs(display)
  if display:sub(1, 1) == "/" then
    return display
  end
  return (vim.fn.fnamemodify(state.cwd .. "/" .. display, ":p"):gsub("/$", ""))
end

-- Sync the current buffer contents to storage and mark the buffer as clean.
local function save_edit()
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local new_abs = {}
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line ~= "" then
      table.insert(new_abs, resolve_abs(line))
    end
  end
  if state.save_fn then
    state.save_fn(new_abs)
  end
  -- Rebuild state.entries so the picker reflects what was just saved.
  state.entries = {}
  for _, abs_path in ipairs(new_abs) do
    local display = relpath(state.cwd, abs_path)
    table.insert(state.entries, { path = abs_path, display = display })
  end
  vim.bo[state.buf].modified = false
  vim.notify("swiftpick: saved", vim.log.levels.INFO)
end

exit_edit_mode = function()
  pcall(vim.api.nvim_clear_autocmds, { group = "swiftpick_edit", buffer = state.buf })
  state.edit_mode = false
  vim.bo[state.buf].buftype = "nofile"
  update_picker_buf(state.entries)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.wo[state.win].cursorline = false
    hide_cursor()
  end
  -- Restore all standard keymaps.
  local buf = state.buf
  local nmap = function(key, fn)
    vim.keymap.set("n", key, fn, { noremap = true, silent = true, buffer = buf })
  end
  for i, label in ipairs(HINT_LABELS) do
    nmap(label, function()
      open_entry_by_index(i)
    end)
  end
  for i = 1, 9 do
    nmap(tostring(i), function()
      open_entry_by_index(i)
    end)
  end
  nmap("<CR>", open_entry_at_cursor)
  nmap("a", do_add)
  nmap("r", do_remove)
  nmap("A", do_add_at)
  nmap("R", do_remove_at)
  nmap("e", enter_edit_mode)
  nmap("q", close_picker)
  nmap("<Esc>", close_picker)
  set_normal_title_footer()
end

enter_edit_mode = function()
  if state.edit_mode then
    return
  end
  state.edit_mode = true
  -- update_picker_buf sets modifiable=false, so set buftype/modifiable after.
  update_picker_buf(state.entries)
  vim.bo[state.buf].buftype = "acwrite"
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_name(state.buf, "swiftpick://entries")
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.wo[state.win].cursorline = true
    show_cursor()
  end
  set_edit_title_footer()
  -- Remove h/j/k/l quick-open keymaps so normal hjkl navigation works.
  for _, label in ipairs(HINT_LABELS) do
    pcall(vim.keymap.del, "n", label, { buffer = state.buf })
  end
  -- <CR> in normal mode: open the file at the cursor line as-is.
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_win_get_cursor(state.win)[1]
    local display = vim.api.nvim_buf_get_lines(state.buf, line - 1, line, false)[1] or ""
    display = vim.trim(display)
    if display ~= "" then
      open_file(resolve_abs(display))
    end
  end, { noremap = true, silent = true, buffer = state.buf })
  -- <Esc> exits edit mode, discarding unsaved changes.
  vim.keymap.set("n", "<Esc>", exit_edit_mode, { noremap = true, silent = true, buffer = state.buf })
  -- Intercept :w to sync storage instead of writing the scratch buffer to disk.
  vim.api.nvim_create_augroup("swiftpick_edit", { clear = true })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = "swiftpick_edit",
    buffer = state.buf,
    callback = save_edit,
  })
end

local function setup_keymaps(buf)
  local map = function(key, fn)
    vim.keymap.set("n", key, fn, { noremap = true, silent = true, buffer = buf })
  end

  -- Quick-pick by number (1-9)
  for i = 1, 9 do
    map(tostring(i), function()
      open_entry_by_index(i)
    end)
  end

  -- Quick-pick by hint label (h/j/k/l → entries 1-4)
  for i, label in ipairs(HINT_LABELS) do
    map(label, function()
      open_entry_by_index(i)
    end)
  end

  -- Open file at cursor line
  map("<CR>", open_entry_at_cursor)

  -- Add/remove origin buffer
  map("a", do_add)
  map("r", do_remove)
  map("A", do_add_at)
  map("R", do_remove_at)

  -- Enter edit mode
  map("e", enter_edit_mode)

  -- Close picker
  map("q", close_picker)
  map("<Esc>", close_picker)
end

function M.open(abs_entries, save_fn, add_fn, remove_fn)
  local cwd = vim.fn.getcwd()
  state.entries = {}
  state.deleted = {}
  state.cwd = cwd
  state.origin_buf = vim.api.nvim_buf_get_name(0)
  state.save_fn = save_fn
  state.add_fn = add_fn
  state.remove_fn = remove_fn
  state.edit_mode = false

  local longest = 0
  for _, abs_path in ipairs(abs_entries) do
    local display = abs_path == "" and "<empty>" or relpath(cwd, abs_path)
    table.insert(state.entries, { path = abs_path, display = display })
    longest = math.max(longest, #display)
  end

  local numberwidth = 3
  local width = math.max(15, math.min(longest + numberwidth + 2, vim.o.columns - 4))
  local height = math.max(1, math.min(10, #state.entries))

  local display_lines = {}
  for _, entry in ipairs(state.entries) do
    table.insert(display_lines, entry.display)
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, display_lines)
  vim.bo[state.buf].modifiable = false

  local win_cfg = get_centered_win_config(width, height)
  win_cfg.title = TITLE_NORMAL
  win_cfg.title_pos = "center"
  win_cfg.footer = FOOTER_NORMAL
  win_cfg.footer_pos = "center"
  state.win = vim.api.nvim_open_win(state.buf, true, win_cfg)
  vim.wo[state.win].number = true
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].numberwidth = numberwidth
  vim.wo[state.win].signcolumn = "yes:1"
  hide_cursor()

  apply_hints(state.buf)
  setup_keymaps(state.buf)
end

return M
