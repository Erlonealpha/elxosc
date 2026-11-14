-- Static Define API. Scope-bound imports and binds belong to DefineSession.
local session_mod = require 'define.src.session'
local modules_mod = require 'define.src.modules'
local slot_mod = require 'define.src.slot'
local bind_mod = require 'define.src.bind'
local dsl_mod = require 'define.src.dsl'
local builder_mod = require 'define.src.builder'

---@class elxosc.mod.define : elxosc.mod.define.src.slot, elxosc.mod.define.src.bind, elxosc.mod.define.src.dsl
local M = {
    DefineSession = session_mod.DefineSession,
    ModuleRegistry = modules_mod.ModuleRegistry,
    call_slot = builder_mod.call_slot,
    sandbox = require 'define.src.sandbox',
}
for _, source in ipairs({ slot_mod, bind_mod, dsl_mod }) do
    for name, value in pairs(source) do
        M[name] = value
    end
end
return M
