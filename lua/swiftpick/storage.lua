---Module for managing the storage of file paths in SwiftPicks' JSON file.
---@module "swiftpick.storage"

local config = require("swiftpick.config")

---Returns the configured sentinel string that represents an empty slot.
---Wrapped in a function so it always reflects the live config value.
---@return string
local function EMPTY()
  return config.values.empty_entry_identifier
end

---Virtual cwd key used to store the global (cross-project) file list.
local GLOBAL_CWD_EQUIVALENT = "swiftpick://global"

---Reads and parses the JSON storage file.
---@return table<string, string[]>  Decoded Lua table, or `{}` on any read/parse failure.
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

---Serialises `data` as JSON and overwrites the storage file.
---@param data table<string, string[]> The full storage table to persist.
local function write_data(data)
  local file = io.open(config.values.storage_file_path, "w")
  if not file then
    error("Could not write to storage file at " .. config.values.storage_file_path)
  end
  file:write(vim.fn.json_encode(data) .. "\n")
  file:close()
end

---Creates the storage directory (if absent) and writes an empty JSON object to the file.
local function create_new_storage_file()
  vim.fn.mkdir(vim.fn.fnamemodify(config.values.storage_file_path, ":h"), "p")
  local file = io.open(config.values.storage_file_path, "w")
  if not file then
    error("Could not create storage file at " .. config.values.storage_file_path)
  end
  file:write("{}\n")
  file:close()
end

---Provides functions to manage the storage of file paths in SwiftPicks' JSON file.
---@class SwiftpickStorageModule
local M = {}

---Ensures the storage file exists and contains valid JSON.
---Creates a fresh file when it is missing, not writable, or holds invalid JSON.
function M.ensure_storage_exists()
  -- If the file doesn't exist or isn't writable, attempt to create it with an empty JSON object.
  if vim.fn.filewritable(config.values.storage_file_path) == 0 then
    create_new_storage_file()
    return
  end
  -- If the file exists but contains invalid JSON, reset it to an empty object
  -- because it is likely corrupted.
  local data = read_data()
  if vim.tbl_isempty(data) then
    write_data({})
  end
end

---Returns the ordered list of file paths stored for the given cwd.
---@param cwd string Absolute path to the working directory key.
---@return string[]  List of stored file paths (may include EMPTY sentinels); empty table when none exist.
function M.get_filenames_for_cwd(cwd)
  local data = read_data()
  return data[cwd] or {}
end

---Returns the ordered list of globally stored file paths.
---@return string[]
function M.get_filenames_global()
  return M.get_filenames_for_cwd(GLOBAL_CWD_EQUIVALENT)
end

function M.get_filename_at_for_cwd(cwd, index)
  local list = M.get_filenames_for_cwd(cwd)
  return list[index]
end

function M.get_filename_at_global(index)
  return M.get_filename_at_for_cwd(GLOBAL_CWD_EQUIVALENT, index)
end

---Appends `filename` to the stored list for the given cwd.
---Does nothing if `filename` is empty or already present (no duplicates).
---@param cwd      string? Absolute path to the working directory key.
---@param filename string Absolute path of the file to add.
function M.add_filename_for_cwd(cwd, filename)
  if filename == "" then
    return
  end
  if cwd == nil or cwd == "" then
    vim.notify("Cannot add file to storage: cwd is nil or empty", vim.log.levels.ERROR)
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

---Appends `filename` to the global file list.
---@param filename string Absolute path of the file to add.
function M.add_filename_global(filename)
  M.add_filename_for_cwd(GLOBAL_CWD_EQUIVALENT, filename)
end

---Removes the first occurrence of `filename` from the stored list for the given cwd.
---Does nothing when the cwd has no entries or `filename` is not found.
---@param cwd      string? Absolute path to the working directory key.
---@param filename string Absolute path of the file to remove.
function M.remove_filename_for_cwd(cwd, filename)
  if cwd == nil or cwd == "" then
    vim.notify("Cannot add file to storage: cwd is nil or empty", vim.log.levels.ERROR)
    return
  end

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

---Removes `filename` from the global file list.
---@param filename string Absolute path of the file to remove.
function M.remove_filename_global(filename)
  M.remove_filename_for_cwd(GLOBAL_CWD_EQUIVALENT, filename)
end

---Removes all EMPTY sentinel slots from the stored list for the given cwd.
---@param cwd string? Absolute path to the working directory key.
function M.prune_empty_for_cwd(cwd)
  if cwd == nil or cwd == "" then
    vim.notify("Cannot add file to storage: cwd is nil or empty", vim.log.levels.ERROR)
    return
  end

  local data = read_data()
  if not data[cwd] then
    return
  end
  local pruned = {}
  for _, entry in ipairs(data[cwd]) do
    if entry ~= EMPTY() then
      table.insert(pruned, entry)
    end
  end
  data[cwd] = pruned
  write_data(data)
end

---Removes all EMPTY sentinel slots from the global file list.
function M.prune_empty_global()
  M.prune_empty_for_cwd(GLOBAL_CWD_EQUIVALENT)
end

---Replaces the entire stored list for the given cwd with `filenames`.
---@param cwd       string?   Absolute path to the working directory key.
---@param filenames string[] New ordered list of file paths to store.
function M.set_filenames_for_cwd(cwd, filenames)
  if cwd == nil or cwd == "" then
    vim.notify("Cannot add file to storage: cwd is nil or empty", vim.log.levels.ERROR)
    return
  end

  local data = read_data()
  data[cwd] = filenames
  write_data(data)
end

---Replaces the entire global file list with `filenames`.
---@param filenames string[] New ordered list of file paths to store.
function M.set_filenames_global(filenames)
  M.set_filenames_for_cwd(GLOBAL_CWD_EQUIVALENT, filenames)
end

---Removes the entry at a specific 1-based index from the stored list for the given cwd.
---Does nothing when the cwd has no entries or the index is out of range.
---@param cwd   string?  Absolute path to the working directory key.
---@param index integer 1-based index of the slot to remove.
function M.remove_filename_at_for_cwd(cwd, index)
  if cwd == nil or cwd == "" then
    vim.notify("Cannot add file to storage: cwd is nil or empty", vim.log.levels.ERROR)
    return
  end

  local data = read_data()
  if not data[cwd] or not data[cwd][index] then
    return
  end
  table.remove(data[cwd], index)
  write_data(data)
end

---Removes the entry at a specific 1-based index from the global file list.
---@param index integer 1-based index of the slot to remove.
function M.remove_filename_at_global(index)
  M.remove_filename_at_for_cwd(GLOBAL_CWD_EQUIVALENT, index)
end

---Inserts `filename` at a specific 1-based index in the stored list for the given cwd.
---
---Behaviour depends on what currently occupies `index`:
--- - **Slot is EMPTY sentinel** → the sentinel is replaced in-place.
--- - **Slot holds a real entry** → `filename` is inserted, shifting subsequent entries down.
--- - **Index is beyond the list end** → preceding gaps are padded with EMPTY sentinels first.
---
---Does nothing when `filename` is empty.
---@param cwd      string?  Absolute path to the working directory key.
---@param filename string  Absolute path of the file to insert.
---@param index    integer 1-based target slot index.
function M.add_filename_at_for_cwd(cwd, filename, index)
  if filename == "" then
    return
  end

  if cwd == nil or cwd == "" then
    vim.notify("Cannot add file to storage: cwd is nil or empty", vim.log.levels.ERROR)
    return
  end

  local data = read_data()
  data[cwd] = data[cwd] or {}
  local list = data[cwd]

  if #list < index then
    -- Pad any gap between the current end of the list and the target index
    -- with EMPTY sentinels so slots are contiguous.
    for i = #list + 1, index - 1 do
      list[i] = EMPTY()
    end
    list[index] = filename
  elseif list[index] == EMPTY() then
    -- Replace an existing placeholder without shifting anything.
    list[index] = filename
  else
    -- A real entry already occupies this slot – insert before it.
    table.insert(list, index, filename)
  end

  write_data(data)
end

---Inserts `filename` at a specific 1-based index in the global file list.
---@param filename string  Absolute path of the file to insert.
---@param index    integer 1-based target slot index.
function M.add_filename_at_global(filename, index)
  M.add_filename_at_for_cwd(GLOBAL_CWD_EQUIVALENT, filename, index)
end

---Clears all entries for the current working directory.
function M.flush_local()
  local cwd = vim.fn.getcwd()
  M.set_filenames_for_cwd(cwd, {})
end

---Clears the global file list.
function M.flush_global()
  M.set_filenames_global({})
end

---Wipes the entire storage file, removing entries for all cwds including global.
function M.flush_all()
  write_data({})
end

return M
