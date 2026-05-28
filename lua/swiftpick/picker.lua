local M = {}

local function relpath(base, target)
  base = vim.fs.normalize(base)
  target = vim.fs.normalize(target)

  local base_parts = vim.split(base, "/", { plain = true, trimempty = true })
  local target_parts = vim.split(target, "/", { plain = true, trimempty = true })

  -- find common prefix
  local i = 1
  while base_parts[i] and target_parts[i] and base_parts[i] == target_parts[i] do
    i = i + 1
  end

  local rel = {}

  -- go up for remaining base parts
  for _ = i, #base_parts do
    table.insert(rel, "..")
  end

  -- append remaining target parts
  for j = i, #target_parts do
    table.insert(rel, target_parts[j])
  end

  if #rel == 0 then
    return "."
  end

  return table.concat(rel, "/")
end

function M.open(entries)
  -- transform absolute paths to relative to CWD path for better display
  local cwd = vim.fn.getcwd()
  local longest_entry_length = 0
  for i, entry in ipairs(entries) do
    local relative = relpath(cwd, entry)
    entries[i] = relative
    longest_entry_length = math.max(longest_entry_length, #entries[i])
  end

  local numberwidth = 3

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, entries)
  local window = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = vim.fn.min({ longest_entry_length + numberwidth + 2, vim.o.columns - 2 }),
    height = math.min(10, #entries + 1),
    border = "rounded",
    style = "minimal",
  })

  vim.wo[window].number = true
  vim.wo[window].cursorline = true
  vim.wo[window].numberwidth = numberwidth
end

return M
