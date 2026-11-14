-- Complete static package inventory; no filesystem scan or incidental require order.
local exports = require('export').new()

local export = exports.export

---@class elxosc.mod.define.package_catalog
local M = {}

export('define', require 'define')
export('define.bind', require 'define.src.bind')
export('define.builder', require 'define.src.builder')
export('define.dsl', require 'define.src.dsl')
export('define.modules', require 'define.src.modules')
export('define.sandbox', require 'define.src.sandbox')
export('define.session', require 'define.src.session')
export('define.slot', require 'define.src.slot')

---@return elxosc.export.Package<elxosc.export.Exports>[]
function M.collect()
    return exports.collect()
end

export('define.package_catalog', M)

return M
