local M = {}

-- Reads and parses the JSON file, returns a Lua table (or {} on failure)
local function read_data(storage_file_path)
  local file = io.open(storage_file_path, "r")
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
local function write_data(storage_file_path, data)
  local file = io.open(storage_file_path, "w")
  if not file then
    error("Could not write to storage file at " .. storage_file_path)
  end
  file:write(vim.fn.json_encode(data) .. "\n")
  file:close()
end

function M.init_storage(storage_file_path)
  -- If the file doesn't exist or isn't writeable, attempt create it with an empty JSON object
  if vim.fn.filewritable(storage_file_path) == 0 then
    M.create_new_storage_file(storage_file_path)
    return
  end
  -- If the file exists but contains invalid JSON, reset it
  -- as it's probably corrupted
  local data = read_data(storage_file_path)
  if vim.tbl_isempty(data) then
    write_data(storage_file_path, {})
  end
end

function M.create_new_storage_file(storage_file_path)
  vim.fn.mkdir(vim.fn.fnamemodify(storage_file_path, ":h"), "p")
  local file = io.open(storage_file_path, "w")
  if not file then
    error("Could not create storage file at " .. storage_file_path)
  end
  file:write("{}\n")
  file:close()
end

--- Returns the list of filenames stored for the given cwd.
function M.get_filenames_for_cwd(storage_file_path, cwd)
  local data = read_data(storage_file_path)
  return data[cwd] or {}
end

--- Adds the current buffer's filename to the list for the given cwd.
--- Does nothing if the filename is already present.
function M.add_filename_for_cwd(storage_file_path, cwd)
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    return
  end

  local data = read_data(storage_file_path)
  data[cwd] = data[cwd] or {}

  -- Avoid duplicates
  for _, existing in ipairs(data[cwd]) do
    if existing == filename then
      return
    end
  end

  table.insert(data[cwd], filename)
  write_data(storage_file_path, data)
end

--- Adds an explicit path to the list for the given cwd.
--- Does nothing if the path is already present.
function M.add_path_for_cwd(storage_file_path, cwd, path)
  if not path or path == "" then
    return
  end

  local data = read_data(storage_file_path)
  data[cwd] = data[cwd] or {}

  for _, existing in ipairs(data[cwd]) do
    if existing == path then
      return
    end
  end

  table.insert(data[cwd], path)
  write_data(storage_file_path, data)
end

--- Removes a specific filename from the list for the given cwd.
function M.remove_filename_for_cwd(storage_file_path, cwd, filename)
  local data = read_data(storage_file_path)
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
  write_data(storage_file_path, data)
end

--- Replaces the entire list of filenames for the given cwd.
function M.set_filenames_for_cwd(storage_file_path, cwd, filenames)
  local data = read_data(storage_file_path)
  data[cwd] = filenames
  write_data(storage_file_path, data)
end

return M
