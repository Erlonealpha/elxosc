-- Design sketch (dev/design/DESIGN.md §4): not runnable code, kept for reference.
---@diagnostic disable: unused, undefined-field, inject-field, undefined-global, global-in-non-module

local mp = require 'mp'

--
-- Server defines example
--

-- can directly use without prefix
local builtins = {
    text = {},
    button = {},
    ...
}
local mods = {
    mp = {
        get_prop = function(name)
        end,
        on_prop = function(name, cb)
        end,
    },
}
local mods_loader = {
    mp = function(scope, env)
        function env.on_message(cb)
        end
    end,
    ...
}
local protected_mods = {}
---@[lsp_optimization('delayed_definition')]
local current_env
local current_define
local function import(modname)
    local mod
    if mods[modname] then
        mod = true
        for k, v in pairs(mods[modname]) do
            current_env[k] = v
        end
    end
    if mods_loader[modname] then
        mod = true
        mods_loader[modname](current_env, current_define)
    end
    if not mod then
        error('...')
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
for _, mod in pairs(builtins) do
    for n, v in pairs(mod) do
        define_env_mt[n] = v
    end
end
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
    local allow_start = true
    local define_ok = false
    local start = mp.get_time()
    local deadline_start = start + wait_start_timeout
    local deadline = start + all_timeout

    local function dispatch_event(ev)
    end
    local function register_script_message(name, cb)
    end
    local function unregister()
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

    local define_start_count = 0

    register_script_message('define_start', function()
        if allow_start then
            define_start_count = define_start_count + 1
        end
    end)

    register_script_message('define_end', function()
        define_start_count = define_start_count - 1
        if not allow_start and define_start_count == 0 then
            define_ok = true
        end
    end)

    -- target widget must has binded
    -- name: state {id.name}
    register_script_message('state', function(name, ...)
    end)

    while true do
        local curr = mp.get_time()
        local next_deadline
        if curr > deadline then
            break
        elseif curr > deadline_start then
            allow_start = false
            next_deadline = deadline
        else
            next_deadline = deadline_start
        end
        local ev = mp.wait_event(next_deadline - curr)
        dispatch_event(ev)
        if define_ok then
            break
        end
    end
    unregister()
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
    self.pause = get_prop('pause')

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
