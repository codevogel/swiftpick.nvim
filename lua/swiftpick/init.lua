local M = {}

function M.setup(opts)
  opts = opts or {}
  M.cfg = {
    filename = opts.filename or "swiftpick.json",
    storage_path = opts.storage_path or vim.fn.stdpath("data") .. "/swiftpick/",
  }
  if not M.cfg.filename:match("%.json$") then
    error("Filename must end with .json")
  end
  if not M.cfg.storage_path:match("/$") then
    M.cfg.storage_path = M.cfg.storage_path .. "/"
  end
  M.cfg.storage_file_path = M.cfg.storage_path .. M.cfg.filename
  M.storage = require("swiftpick.storage")
  M.storage.init_storage(M.cfg.storage_file_path)
  M.picker = require("swiftpick.picker")
end

function M.add()
  local cwd = vim.fn.getcwd()
  M.storage.add_filename_for_cwd(M.cfg.storage_file_path, cwd)
end

function M.get_all()
  local cwd = vim.fn.getcwd()
  return M.storage.get_filenames_for_cwd(M.cfg.storage_file_path, cwd)
end

function M.remove(filename)
  local cwd = vim.fn.getcwd()
  -- Default to current buffer if no filename given
  filename = filename or vim.api.nvim_buf_get_name(0)
  M.storage.remove_filename_for_cwd(M.cfg.storage_file_path, cwd, filename)
end

function M.open_picker()
  local cwd = vim.fn.getcwd()
  M.picker.open(M.get_all(), function(new_abs_paths)
    M.storage.set_filenames_for_cwd(M.cfg.storage_file_path, cwd, new_abs_paths)
  end, function(path)
    M.storage.add_path_for_cwd(M.cfg.storage_file_path, cwd, path)
    return M.storage.get_filenames_for_cwd(M.cfg.storage_file_path, cwd)
  end, function(path)
    M.storage.remove_filename_for_cwd(M.cfg.storage_file_path, cwd, path)
    return M.storage.get_filenames_for_cwd(M.cfg.storage_file_path, cwd)
  end)
end

return M
