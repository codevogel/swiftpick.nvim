local M = {}

M.defaults = {
  filename = "swiftpick.json",
  storage_path = vim.fn.stdpath("data") .. "/swiftpick/",
  keybinds = {
    open_picker = "<leader>h",
    close_picker = { "<Esc>", "q", "<C-c>" },
    add = "a",
    add_at = "A",
    remove = "r",
    remove_at = "R",
    prune_empty = "p",
    edit_entries = "e",
    pick_highlighted_entry = "<CR>",
    pick_entry = {
      digits = {
        _1 = "1",
        _2 = "2",
        _3 = "3",
        _4 = "4",
        _5 = "5",
        _6 = "6",
        _7 = "7",
        _8 = "8",
        _9 = "9",
        _10 = "0",
      },
      chars = {
        _1 = "h",
        _2 = "j",
        _3 = "k",
        _4 = "l",
        _5 = nil,
        _6 = nil,
        _7 = nil,
        _8 = nil,
        _9 = nil,
        _10 = nil,
      },
    },
  },
}

M.values = {}

function M.setup(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  -- verify filename opt is valid
  if not M.values.filename:match("%.json$") then
    error("Filename must end with .json")
  end
  if not M.values.storage_path:match("/$") then
    M.values.storage_path = M.values.storage_path .. "/"
  end
  -- join storage path and filename to get full path to storage file
  M.values.storage_file_path = M.values.storage_path .. M.values.filename
end

return M
