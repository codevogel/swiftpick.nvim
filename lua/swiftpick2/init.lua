local M = {}

local config = require("swiftpick2.config")
local storage = require("swiftpick2.storage")
local picker = require("swiftpick2.picker")

function M.setup(opts)
  config.setup(opts or {})
  storage.init_storage()
end

function M.open_picker()
  picker.open_picker()
end

return M
