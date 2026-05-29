local M = {}

local HINT_NS = vim.api.nvim_create_namespace("swiftpick_hints")
local HINT_LABELS = { "h", "j", "k", "l" }

local FOOTER_NORMAL = " [hjkl | 1-9] open · [f] filter · [e] edit"

local FOOTER_FILTERED = " [hjkl | 1-9] open · [f] filter · [r] reset · [e] edit "
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
  filtered = {}, -- currently visible subset (mirrors entries when no filter is active)
  filter_buf = nil,
  filter_win = nil,
  cwd = nil, -- working directory when picker was opened
  save_fn = nil, -- callback(abs_paths) called when the user saves in edit mode
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

local function fuzzy_match(query, str)
  if query == "" then
    return true
  end
  query = query:lower()
  str = str:lower()
  local qi = 1
  for si = 1, #str do
    if str:sub(si, si) == query:sub(qi, qi) then
      qi = qi + 1
      if qi > #query then
        return true
      end
    end
  end
  return false
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

local function apply_filter_hints(buf)
  vim.api.nvim_buf_clear_namespace(buf, HINT_NS, 0, -1)
  if vim.api.nvim_buf_line_count(buf) >= 1 then
    vim.api.nvim_buf_set_extmark(buf, HINT_NS, 0, 0, {
      sign_text = ">",
      sign_hl_group = "Comment",
    })
  end
end

local function is_filtered()
  return #state.filtered ~= #state.entries
end

local function update_footer()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  local footer = is_filtered() and FOOTER_FILTERED or FOOTER_NORMAL
  vim.api.nvim_win_set_config(state.win, { footer = footer, footer_pos = "center" })
end

local function set_normal_title_footer()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return
  end
  vim.api.nvim_win_set_config(state.win, {
    title = TITLE_NORMAL,
    title_pos = "center",
    footer = is_filtered() and FOOTER_FILTERED or FOOTER_NORMAL,
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
  update_footer()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
  end
end

local function close_filter()
  if state.filter_win and vim.api.nvim_win_is_valid(state.filter_win) then
    vim.api.nvim_win_close(state.filter_win, true)
    state.filter_win = nil
  end
  if state.filter_buf and vim.api.nvim_buf_is_valid(state.filter_buf) then
    vim.api.nvim_buf_delete(state.filter_buf, { force = true })
    state.filter_buf = nil
  end
end

local function close_picker()
  close_filter()
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
  local entry = state.filtered[idx]
  if entry then
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

local function open_filter()
  if state.filter_win and vim.api.nvim_win_is_valid(state.filter_win) then
    return
  end

  local cfg = vim.api.nvim_win_get_config(state.win)
  local picker_row = cfg.row
  local picker_col = cfg.col
  -- Neovim may return row/col as 1-element arrays in some configurations.
  if type(picker_row) == "table" then
    picker_row = picker_row[1]
  end
  if type(picker_col) == "table" then
    picker_col = picker_col[1]
  end

  -- With border="rounded" the bottom border sits at picker_row + picker_height,
  -- so the filter float content (with its own top border) starts one row below that.
  local filter_row = picker_row + cfg.height + 1

  state.filter_buf = vim.api.nvim_create_buf(false, true)
  -- Disable completion popups (blink.cmp, nvim-cmp, etc.) in the filter buffer.
  vim.b[state.filter_buf].completion = false
  vim.bo[state.filter_buf].omnifunc = ""
  vim.bo[state.filter_buf].completefunc = ""
  state.filter_win = vim.api.nvim_open_win(state.filter_buf, true, {
    relative = "editor",
    row = filter_row,
    col = picker_col,
    width = cfg.width,
    height = 1,
    border = "rounded",
    style = "minimal",
  })

  show_cursor()
  apply_filter_hints(state.buf)

  local iopts = { noremap = true, silent = true, buffer = state.filter_buf }

  -- <Esc>/<C-c>: close filter, keep filtered list, return focus to picker
  local function dismiss_filter()
    if #state.filtered == 0 then
      state.filtered = state.entries
      update_picker_buf(state.entries)
    end
    close_filter()
    apply_hints(state.buf)
    update_footer()
    hide_cursor()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
    end
    vim.cmd("stopinsert")
  end

  -- <CR>: open the first (top) entry in the filtered list.
  -- If there are no matches, reset the filter and return to the picker instead.
  vim.keymap.set("i", "<CR>", function()
    if #state.filtered == 0 then
      state.filtered = state.entries
      update_picker_buf(state.entries)
      dismiss_filter()
    else
      close_filter()
      open_entry_by_index(1)
    end
  end, iopts)

  vim.keymap.set("i", "<Esc>", dismiss_filter, iopts)
  vim.keymap.set("i", "<C-c>", dismiss_filter, iopts)

  -- <BS> when buffer is empty: dismiss filter
  vim.keymap.set("i", "<BS>", function()
    local line = vim.api.nvim_buf_get_lines(state.filter_buf, 0, 1, false)[1] or ""
    if line == "" then
      dismiss_filter()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", false)
    end
  end, iopts)

  -- Re-filter the picker on every keystroke
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.filter_buf,
    callback = function()
      local query = vim.api.nvim_buf_get_lines(state.filter_buf, 0, 1, false)[1] or ""
      local filtered = {}
      for _, entry in ipairs(state.entries) do
        if fuzzy_match(query, entry.display) then
          table.insert(filtered, entry)
        end
      end
      state.filtered = filtered
      update_picker_buf(filtered)
      apply_filter_hints(state.buf)
    end,
  })

  vim.cmd("startinsert")
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
  state.filtered = state.entries
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
  nmap("f", open_filter)
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
  -- Always edit the full entry list, even if a filter was active.
  -- update_picker_buf sets modifiable=false, so set buftype/modifiable after.
  state.filtered = state.entries
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

  -- Open fuzzy filter bar
  map("f", open_filter)

  -- Reset filter to original entry list
  map("r", function()
    if not is_filtered() then
      return
    end
    state.filtered = state.entries
    update_picker_buf(state.entries)
  end)

  -- Enter edit mode
  map("e", enter_edit_mode)

  -- Close picker
  map("q", close_picker)
  map("<Esc>", close_picker)
end

function M.open(abs_entries, save_fn)
  local cwd = vim.fn.getcwd()
  state.entries = {}
  state.filtered = {}
  state.deleted = {}
  state.cwd = cwd
  state.save_fn = save_fn
  state.edit_mode = false

  local longest = 0
  for _, abs_path in ipairs(abs_entries) do
    local display = relpath(cwd, abs_path)
    table.insert(state.entries, { path = abs_path, display = display })
    longest = math.max(longest, #display)
  end

  if #state.entries == 0 then
    vim.notify("swiftpick: no entries", vim.log.levels.INFO)
    return
  end

  state.filtered = state.entries

  local numberwidth = 3
  local width = math.min(longest + numberwidth + 2, vim.o.columns - 4)
  local height = math.min(10, #state.entries)

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
