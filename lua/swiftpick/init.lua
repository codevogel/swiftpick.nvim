local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")

function M.setup(opts)
  config.setup(opts or {})
  storage.ensure_storage_exists()

  vim.api.nvim_create_user_command("SwiftPick", function()
    require("swiftpick.picker").open_picker()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickGlobal", function()
    require("swiftpick.picker").open_picker(true)
  end, {})
  vim.api.nvim_create_user_command("SwiftPickLocal", function()
    require("swiftpick.picker").open_picker(false)
  end, {})
  vim.api.nvim_create_user_command("SwiftPickEdit", function()
    require("swiftpick.picker").open_picker()
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickEditLocal", function()
    require("swiftpick.picker").open_picker(true)
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickEditGlobal", function()
    require("swiftpick.picker").open_picker(true)
    require("swiftpick.lib.picker.window").switch_to_edit_mode()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickAddLocal", function()
    storage.add_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(0))
  end, {})
  vim.api.nvim_create_user_command("SwiftPickAddGlobal", function()
    storage.add_filename_global(vim.api.nvim_buf_get_name(0))
  end, {})
  vim.api.nvim_create_user_command("SwiftPickAddAtLocal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to add the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = tonumber(index.args)
    storage.add_filename_at_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(0), index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command("SwiftPickAddAtGlobal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to add the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = tonumber(index.args)
    storage.add_filename_at_global(vim.api.nvim_buf_get_name(0), index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command("SwiftPickRemoveLocal", function()
    storage.remove_filename_for_cwd(vim.uv.cwd(), vim.api.nvim_buf_get_name(0))
  end, {})
  vim.api.nvim_create_user_command("SwiftPickRemoveGlobal", function()
    storage.remove_filename_global(vim.api.nvim_buf_get_name(0))
  end, {})
  vim.api.nvim_create_user_command("SwiftPickRemoveAtLocal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to remove the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = tonumber(index.args)
    storage.remove_filename_at_for_cwd(vim.uv.cwd(), index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command("SwiftPickRemoveAtGlobal", function(index)
    if not index.args or index.args == "" then
      vim.notify("Please provide an index to remove the file at", vim.log.levels.ERROR)
      return
    end
    local index_num = tonumber(index.args)
    storage.remove_filename_at_global(index_num)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command("SwiftPickPruneEmptyLocal", function()
    storage.prune_empty_for_cwd(vim.uv.cwd())
  end, {})
  vim.api.nvim_create_user_command("SwiftPickPruneEmptyGlobal", function()
    storage.prune_empty_global()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickFlushStorageLocal", function()
    require("swiftpick.storage").flush_local()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickFlushStorageGlobal", function()
    require("swiftpick.storage").flush_global()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickFlushStorageAll", function()
    require("swiftpick.storage").flush_all()
  end, {})
  vim.api.nvim_create_user_command("SwiftPickPrintStorageFileLocation", function()
    print(config.values.storage_file_path)
  end, {})
  vim.api.nvim_create_user_command("SwiftPickPrintStorageFileContent", function()
    local path = config.values.storage_file_path

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

return M
