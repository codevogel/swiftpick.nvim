local M = {}

local config = require("swiftpick.config")

---Returns the configured sentinel string for empty slots.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
end

---Split a POSIX path string into its component parts, discarding empty segments.
---@param path string Absolute or relative POSIX path.
---@return string[]  Ordered list of path components (no `/` separators).
local function split_path(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

---Convert an absolute path to a path relative to `cwd`, using `../` notation.
---
---The algorithm finds the longest common prefix between the two paths and then
---counts how many directory levels remain in `cwd` beyond that prefix to build
---the correct number of `..` components.
---
---Returns the EMPTY sentinel unchanged when `abs_path` equals the sentinel.
---Returns `"."` when `abs_path` and `cwd` are identical.
---@param abs_path string Absolute file path to convert.
---@param cwd      string Absolute path of the working directory to make relative to.
---@return string  Relative path, or EMPTY sentinel if input was the sentinel.
function M.to_relative(abs_path, cwd)
  if type(abs_path) ~= "string" then
    return EMPTY()
  end
  if abs_path == EMPTY() then
    return abs_path
  end

  -- Strip trailing slashes so the split is consistent.
  abs_path = abs_path:gsub("/$", "")
  cwd = cwd:gsub("/$", "")

  local abs_parts = split_path(abs_path)
  local cwd_parts = split_path(cwd)

  -- Walk forward until the components diverge to find the common prefix length.
  local common = 0
  local len = math.min(#abs_parts, #cwd_parts)
  for i = 1, len do
    if abs_parts[i] == cwd_parts[i] then
      common = i
    else
      break
    end
  end

  -- For each cwd component beyond the common prefix, add a ".." up-level.
  local rel_parts = {}
  for _ = common + 1, #cwd_parts do
    table.insert(rel_parts, "..")
  end
  -- Append the remaining components of the target path after the common prefix.
  for i = common + 1, #abs_parts do
    table.insert(rel_parts, abs_parts[i])
  end

  if #rel_parts == 0 then
    return "."
  end
  return table.concat(rel_parts, "/")
end

---Convert a relative path to an absolute path resolved against `cwd`.
---
---Returns the EMPTY sentinel unchanged when `path` equals the sentinel.
---Returns `path` unchanged when it is already absolute (starts with `/`).
---@param path string  Relative or absolute file path.
---@param cwd  string  Absolute path of the working directory to resolve against.
---@return string  Absolute path with trailing slash removed, or EMPTY sentinel.
function M.to_absolute(path, cwd)
  if type(path) ~= "string" then
    return EMPTY()
  end
  if path == EMPTY() then
    return path
  end
  if path:sub(1, 1) == "/" then
    return path
  end
  return vim.fn.fnamemodify(cwd .. "/" .. path, ":p"):gsub("/$", "")
end

return M
