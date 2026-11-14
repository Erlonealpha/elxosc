-- Static construction and protocol members; scoped APIs belong to DefineSession.
local exports = require('export').new()

local export = exports.export

export('define', require 'define.src.slot')
export('define', require 'define.src.bind', true)
export('define', require 'define.src.dsl', true)
export('define', require 'define.src.session', true).show('DefineSession')
export('define', require 'define.src.modules', true).show('ModuleRegistry')
export('define', require 'define.src.builder', true).show('call_slot')
export('define', require 'define.src.sandbox', true)

---@class elxosc.mod.define :
--- elxosc.mod.define.src.slot,
--- elxosc.mod.define.src.bind,
--- elxosc.mod.define.src.dsl,
--- elxosc.mod.define.src.sandbox
---@field DefineSession elxosc.define.DefineSession
---@field ModuleRegistry elxosc.define.ModuleRegistry
---@field call_slot fun(callback: elxosc.define.SlotBuilder, value: Widget|Widget[]|nil, opts: table<string, any>?, name: string): Widget?
local M = exports.get('define')
return M
