local M = {}

local config = require("swiftpick2.config")

-- Reads and parses the JSON file, returns a Lua table (or {} on failure)
local function read_data()
  local file = io.open(config.values.storage_file_path, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()
  if not content or content == "" then
    return {}
  end
  local ok, decoded = pcall(vim.fn.json_decode, content)
  return (ok and type(decoded) == "table") and decoded or {}
end

-- Serialises a Lua table and writes it to the JSON file
local function write_data(data)
  local file = io.open(config.values.storage_file_path, "w")
  if not file then
    error("Could not write to storage file at " .. config.values.storage_file_path)
  end
  file:write(vim.fn.json_encode(data) .. "\n")
  file:close()
end

-- Creates a new storage file with an empty JSON object
local function create_new_storage_file()
  vim.fn.mkdir(vim.fn.fnamemodify(config.values.storage_file_path, ":h"), "p")
  local file = io.open(config.values.storage_file_path, "w")
  if not file then
    error("Could not create storage file at " .. config.values.storage_file_path)
  end
  file:write("{}\n")
  file:close()
end

-- Initialises the storage file, creating it if necessary and resetting it if it contains invalid JSON.
function M.init_storage()
  -- If the file doesn't exist or isn't writeable, attempt create it with an empty JSON object
  if vim.fn.filewritable(config.values.storage_file_path) == 0 then
    create_new_storage_file()
    return
  end
  -- If the file exists but contains invalid JSON, reset it
  -- as it's probably corrupted
  local data = read_data()
  if vim.tbl_isempty(data) then
    write_data({})
  end
end

--- Returns the list of filenames stored for the given cwd.
function M.get_filenames_for_cwd(cwd)
  local data = read_data()
  return data[cwd] or {}
end

--- Adds the current buffer's filename to the list for the given cwd.
--- Does nothing if the filename is already present.
function M.add_filename_for_cwd(cwd, filename)
  if filename == "" then
    return
  end

  local data = read_data()
  data[cwd] = data[cwd] or {}

  -- Avoid duplicates
  for _, existing in ipairs(data[cwd]) do
    if existing == filename then
      return
    end
  end

  table.insert(data[cwd], filename)
  write_data(data)
end

--- Adds an explicit path to the list for the given cwd.
--- Does nothing if the path is already present.
function M.add_path_for_cwd(cwd, path)
  if not path or path == "" then
    return
  end

  local data = read_data()
  data[cwd] = data[cwd] or {}

  for _, existing in ipairs(data[cwd]) do
    if existing == path then
      return
    end
  end

  table.insert(data[cwd], path)
  write_data(data)
end

--- Removes a specific filename from the list for the given cwd.
function M.remove_filename_for_cwd(cwd, filename)
  local data = read_data()
  if not data[cwd] then
    return
  end

  local filtered = {}
  for _, existing in ipairs(data[cwd]) do
    if existing ~= filename then
      table.insert(filtered, existing)
    end
  end

  data[cwd] = filtered
  write_data(data)
end

--- Removes all "<empty>" slots from the list for the given cwd.
function M.prune_empty_for_cwd(cwd)
  local data = read_data()
  if not data[cwd] then
    return
  end
  local pruned = {}
  for _, entry in ipairs(data[cwd]) do
    if entry ~= "<empty>" then
      table.insert(pruned, entry)
    end
  end
  data[cwd] = pruned
  write_data(data)
end

--- Replaces the entire list of filenames for the given cwd.
function M.set_filenames_for_cwd(cwd, filenames)
  local data = read_data()
  data[cwd] = filenames
  write_data(data)
end

--- Removes the entry at a specific 1-based index from the list for the given cwd.
--- If no entry exists at that index, does nothing.
function M.remove_filename_at_for_cwd(cwd, index)
  local data = read_data()
  if not data[cwd] or not data[cwd][index] then
    return
  end
  table.remove(data[cwd], index)
  write_data(data)
end

--- Adds a filename at a specific 1-based index in the list for the given cwd.
--- If the slot holds "<empty>", replaces it.
--- If a real entry exists there, inserts (shifting subsequent entries down).
--- If the list is shorter than index, pads preceding slots with "<empty>" first.
function M.add_filename_at_for_cwd(cwd, filename, index)
  if filename == "" then
    return
  end
  local data = read_data()
  data[cwd] = data[cwd] or {}
  local list = data[cwd]

  if #list < index then
    for i = #list + 1, index - 1 do
      list[i] = "<empty>"
    end
    list[index] = filename
  elseif list[index] == "<empty>" then
    list[index] = filename
  else
    table.insert(list, index, filename)
  end

  write_data(data)
end

return M
