-- Initialization-only builders reuse the framework result boundary.
local builder_mod = require 'src.widget.builder'

---@class elxosc.mod.define.src.builder
local M = {}

---@alias elxosc.define.SlotBuilder fun(value: Widget|Widget[]|nil, opts: table<string, any>?): Widget?

---@param callback elxosc.define.SlotBuilder
---@param value Widget|Widget[]|nil
---@param opts table<string, any>?
---@param name string
---@return Widget?
function M.call_slot(callback, value, opts, name)
    name = type(name) == 'string' and name ~= '' and name or 'SlotBuilder'
    builder_mod.validate_callback(callback, name)
    return builder_mod.validate_result(callback(value, opts), name)
end

return M
