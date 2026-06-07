local M = {}

local config = require("swiftpick.config")
local storage = require("swiftpick.storage")

function M.setup(opts)
  config.setup(opts or {})
  storage.init_storage()
end

return M
