-- Design sketch (DESIGN.md §4): not runnable code, kept for reference.
---@diagnostic disable: unused, undefined-field, inject-field, undefined-global, global-in-non-module

local mp = require 'mp'

--
-- Server defines example
--

local mods = {}
local mods_init = {}
local protected_mods = {}
---@[lsp_optimization('delayed_definition')]
local current_env
local current_define
local function import(mod)
    if not mods[mod] then
        error('...')
    end
    if mods_init[mod] then
        mods_init[mod](current_env, current_define) -- wrap mp.on_message here
    end
    for k, v in pairs(mods[mod]) do
        current_env[k] = v
    end
end

local function module(mod, env)
    if protected_mods[mod] then
        error('...')
    end
    if type(env) ~= 'table' then
        error('...')
    end
    mods[mod] = env or current_env
end

local function bind(id, widget)
end

local define_env_mt = {
    new_state = function(name, parent) end,
    new_widget = function(name, parent) end,
    import = function(mod) end, -- import('button')
    require = import, -- alias
    mod = module,
    bind = bind,
    print = mp.msg.info,
    ...
}
local protected = {}
define_env_mt.__index = define_env_mt
define_env_mt.__newindex = function (obj, k, v)
    if protected[k] then
        error('...')
    end
    rawset(obj, k, v)
end

local function wait_define(wait_start_timeout, all_timeout)
    -- run light event loop
    local function register_script_message(name, cb)
    end

    -- id: scope id
    -- code: code for define
    register_script_message('define', function(id, code)
        if id == nil then
            mp.msg.error('...')
            return
        end
        if code == nil then
            mp.msg.error('...')
            return
        end
        current_define = id
        local locals = {}
        local env = setmetatable(locals, define_env_mt)
        current_env = locals
        local rv, err = load(code, 'define' .. id, 't', env)
        if not err then
            rv()
        end
        current_env = nil
    end)

    -- target widget must has binded
    -- name: state {id.name}
    register_script_message('state', function(name)
    end)
end

local ev_loop = _G.mp_event_loop
_G.mp_event_loop = function()
    wait_define(0.5, 1)
    ev_loop()
end


--
-- Client usage example
--


local function message_to_elxosc(...)
    mp.commandv('script-message-to', 'elxosc', ...)
end
local function define(id, s)
    message_to_elxosc('define', id, s)
end

message_to_elxosc('define_start')
define('define_scope_a', [[
import('mp')

MyState = new_state('MyState')
function MyState:__init()
    self.count = 0
    self.pause = mp.get_prop('pause')

    on_prop('pause', function(_, puase)
        if pause ~= nil and ~= self.pause then
            self:set_state(function() 
                self.pause = pause
            end)
        end
    end)
    on_message(function()
        self:set_state(function()
            self.count = self.count + 1
        end)
    end)
end
function MyState:build(ctx)
    return Container{
        margin = EdgeInsets.only(10, nil, 10, nil),
        child = Text(string.format('Count %d Paused %s', self.count, self.pause))
    }
end
MyWidget = new_widget('MyWidget')
function MyWidget:create_state()
    return MyState()
end

bind('title_bar', MyWidget())
mod('custum_mod')
]])
define('define_scope_b', [[
import('mp')
import('custum_mod')

print('get MyWidget', MyWidget)

bind('bottom_bar', Button{
    on_pressed = function() print('Click') end,
    child = Text('A Button')
})
]])
message_to_elxosc('define_end')
