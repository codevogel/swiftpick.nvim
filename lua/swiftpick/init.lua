---Main module for SwiftPick.
---@module "swiftpick"

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")
local state = require("swiftpick.state")
local actions = require("swiftpick.actions")

---Register all built-in `:SwiftPick*` user commands using the configured prefix.
---Each command delegates to the corresponding `storage` or `picker` function.
---Called automatically by `setup()` when `config.create_default_user_commands` is `true`.
local function create_default_user_commands()
  local prefix = config.values.default_user_command_prefix
  -- Helper function to get the name of the current buffer, or an empty string if it cannot be determined.
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
    actions.open_picker()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "Global", function()
    actions.open_picker({ use_global_context = true })
  end, {})
  vim.api.nvim_create_user_command(prefix .. "Local", function()
    actions.open_picker({ use_global_context = false })
  end, {})
  vim.api.nvim_create_user_command(prefix .. "Edit", function()
    actions.open_picker()
    actions.switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "EditLocal", function()
    actions.open_picker({ use_global_context = false })
    actions.switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "EditGlobal", function()
    actions.open_picker({ use_global_context = true })
    actions.switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "AddLocal", function()
    actions.add({
      filename = get_current_buf_name(),
      use_global_context = false,
    })
  end, {})
  vim.api.nvim_create_user_command(prefix .. "AddGlobal", function()
    actions.add({
      filename = get_current_buf_name(),
      use_global_context = true,
    })
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
    actions.add({
      filename = get_current_buf_name(),
      index = index_num,
      use_global_context = false,
    })
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
    actions.add({
      filename = get_current_buf_name(),
      index = index_num,
      use_global_context = true,
    })
  end, { nargs = 1 })
  vim.api.nvim_create_user_command(prefix .. "RemoveLocal", function()
    actions.remove({
      file = get_current_buf_name(),
      use_global_context = false,
    })
  end, {})
  vim.api.nvim_create_user_command(prefix .. "RemoveGlobal", function()
    actions.remove({
      file = get_current_buf_name(),
      use_global_context = true,
    })
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
    actions.remove({
      file = index_num,
      use_global_context = false,
    })
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
    actions.remove({
      file = index_num,
      use_global_context = true,
    })
  end, { nargs = 1 })
  vim.api.nvim_create_user_command(prefix .. "PruneEmptyLocal", function()
    actions.prune_empty_entries({ use_global_context = false })
  end, {})
  vim.api.nvim_create_user_command(prefix .. "PruneEmptyGlobal", function()
    actions.prune_empty_entries({ use_global_context = true })
  end, {})
  vim.api.nvim_create_user_command(prefix .. "FlushStorageLocal", function()
    storage.flush_local()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "FlushStorageGlobal", function()
    storage.flush_global()
  end, {})
  vim.api.nvim_create_user_command(prefix .. "FlushStorageAll", function()
    storage.flush_all()
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

---@class SwiftpickModule Main module for SwiftPick. Used for bootstrapping the plugin.
local M = {}

---Bootstrap swiftpick: merge user options, ensure storage, and register user commands.
---This should be the single entry point called from the user's Neovim config.
---@param opts? SwiftpickConfigOpts
function M.setup(opts)
  config.setup(opts or {})
  storage.ensure_storage_exists()
  state.initialize()

  if config.values.create_default_user_commands then
    create_default_user_commands()
  end
end

return M
