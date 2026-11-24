-- Static construction and protocol members; scoped APIs belong to DefineSession.
---@namespace elxosc
---@using elxosc
---@using elxosc.define

local exports = require('export').new()

local export = exports.export

export('define', require 'define.src.slot')
export('define', require 'define.src.bind', true)
export('define', require 'define.src.dsl', true)
export('define', require 'define.src.session', true).show('DefineSession')
export('define', require 'define.src.modules', true).show('ModuleRegistry')
export('define', require 'define.src.builder', true).show('call_slot')
export('define', require 'define.src.sandbox', true)

---@class mod.define :
--- mod.define.src.slot,
--- mod.define.src.bind,
--- mod.define.src.dsl,
--- mod.define.src.sandbox
---@field DefineSession DefineSession
---@field ModuleRegistry ModuleRegistry
---@field call_slot fun(callback: SlotBuilder, value: Widget|Widget[]|nil, opts: SpecOptions?, name: string): Widget?
local M = exports.get('define')
return M
