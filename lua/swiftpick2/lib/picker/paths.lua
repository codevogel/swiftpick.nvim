local M = {}

local EMPTY = "<empty>"

local function split_path(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

--- Convert an absolute path to a path relative to cwd, using ../ notation.
--- Returns the path unchanged if it is the "<empty>" sentinel.
function M.to_relative(abs_path, cwd)
  if abs_path == EMPTY then
    return abs_path
  end

  abs_path = abs_path:gsub("/$", "")
  cwd = cwd:gsub("/$", "")

  local abs_parts = split_path(abs_path)
  local cwd_parts = split_path(cwd)

  local common = 0
  local len = math.min(#abs_parts, #cwd_parts)
  for i = 1, len do
    if abs_parts[i] == cwd_parts[i] then
      common = i
    else
      break
    end
  end

  local rel_parts = {}
  for _ = common + 1, #cwd_parts do
    table.insert(rel_parts, "..")
  end
  for i = common + 1, #abs_parts do
    table.insert(rel_parts, abs_parts[i])
  end

  if #rel_parts == 0 then
    return "."
  end
  return table.concat(rel_parts, "/")
end

--- Convert a relative path to an absolute path resolved against cwd.
--- Returns the path unchanged if it is the "<empty>" sentinel.
--- Returns the path unchanged if it is already absolute.
function M.to_absolute(path, cwd)
  if path == EMPTY then
    return path
  end
  if path:sub(1, 1) == "/" then
    return path
  end
  return vim.fn.fnamemodify(cwd .. "/" .. path, ":p"):gsub("/$", "")
end

return M
