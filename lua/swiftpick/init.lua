---@module "swiftpick"
---@class SwiftpickModule
---@field setup fun(opts?: SwiftpickConfigOpts)
---@field create_default_user_commands fun()

local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")

---Bootstrap swiftpick: merge user options, ensure storage, and register user commands.
---This should be the single entry point called from the user's Neovim config.
---@param opts? SwiftpickConfigOpts Partial config overrides passed directly to `config.setup()`
function M.setup(opts)
  config.setup(opts or {})
  storage.ensure_storage_exists()

  if config.values.create_default_user_commands then
    M.create_default_user_commands()
  end
end

---Register all built-in `:SwiftPick*` user commands using the configured prefix.
---Each command delegates to the corresponding `storage` or `picker` function.
---Called automatically by `setup()` when `config.create_default_user_commands` is `true`.
function M.create_default_user_commands()
  local prefix = config.values.default_user_command_prefix
  local function get_current_buf_name()
    return vim.api.nvim_buf_get_name(0) or ""
  end

  ---@param raw string
  ---@param action string
  ---@return integer?
  local function parse_index(raw, action)
    if raw == "" or not raw:match("^%d+$") then
      vim.notify("Please provide a valid integer index to " .. action .. " the file at", vim.log.levels.ERROR)
      return nil
    end
    local index_num = tonumber(raw)
    if not index_num then
      return nil
    end
    ---@cast index_num integer
    return index_num
  end

  vim.api.nvim_create_user_command(prefix .. "", function()
    require("swiftpick.picker").open_picker()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "Global", function()
    require("swiftpick.picker").open_picker(true)
  end, {})
  vim.api.nvim_create_user_command(prefix .. "Local", function()
    require("swiftpick.picker").open_picker(false)
  end, {})
  vim.api.nvim_create_user_command(prefix .. "Edit", function()
    require("swiftpick.picker").open_picker()
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "EditLocal", function()
    require("swiftpick.picker").open_picker(true)
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "EditGlobal", function()
    require("swiftpick.picker").open_picker(true)
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "AddLocal", function()
    storage.add_filename_for_cwd(vim.uv.cwd(), get_current_buf_name())
  end, {})
  vim.api.nvim_create_user_command(prefix .. "AddGlobal", function()
    storage.add_filename_global(get_current_buf_name())
  end, {})
  vim.api.nvim_create_user_command(prefix .. "AddAtLocal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to add the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = parse_index(index.args, "add")
    if not index_num then
      return
    end
    storage.add_filename_at_for_cwd(vim.uv.cwd(), get_current_buf_name(), index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command(prefix .. "AddAtGlobal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to add the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = parse_index(index.args, "add")
    if not index_num then
      return
    end
    storage.add_filename_at_global(get_current_buf_name(), index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command(prefix .. "RemoveLocal", function()
    storage.remove_filename_for_cwd(vim.uv.cwd(), get_current_buf_name())
  end, {})
  vim.api.nvim_create_user_command(prefix .. "RemoveGlobal", function()
    storage.remove_filename_global(get_current_buf_name())
  end, {})
  vim.api.nvim_create_user_command(prefix .. "RemoveAtLocal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to remove the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = parse_index(index.args, "remove")
    if not index_num then
      return
    end
    storage.remove_filename_at_for_cwd(vim.uv.cwd(), index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command(prefix .. "RemoveAtGlobal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to remove the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = parse_index(index.args, "remove")
    if not index_num then
      return
    end
    storage.remove_filename_at_global(index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command(prefix .. "PruneEmptyLocal", function()
    storage.prune_empty_for_cwd(vim.uv.cwd())
  end, {})
  vim.api.nvim_create_user_command(prefix .. "PruneEmptyGlobal", function()
    storage.prune_empty_global()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "FlushStorageLocal", function()
    require("swiftpick.storage").flush_local()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "FlushStorageGlobal", function()
    require("swiftpick.storage").flush_global()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "FlushStorageAll", function()
    require("swiftpick.storage").flush_all()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "PrintStorageFileLocation", function()
    print(config.values.storage_file_path or "")
  end, {})
  vim.api.nvim_create_user_command(prefix .. "PrintStorageFileContent", function()
    local path = config.values.storage_file_path
    if not path then
      vim.notify("Storage path is not initialized. Call setup() first.", vim.log.levels.ERROR)
      return
    end

    local fd = io.open(path, "r")
    if not fd then
      vim.notify("Could not open file: " .. path, vim.log.levels.ERROR)
      return
    end

    local content = fd:read("*a")
    fd:close()

    print(content)
  end, {})
end

return M --[[@as SwiftpickModule]]
