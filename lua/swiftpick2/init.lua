local M = {}

local config = require("swiftpick2.config")
local storage = require("swiftpick2.storage")

function M.setup(opts)
  config.setup(opts or {})
  storage.init_storage()
end

return M
