-- A tiny `mp` stub for the host-layer tests.
--
-- `host/*` requires `mp`; the offline suite installs this instead, so the app
-- wiring (frame clock, overlay, input) and the define window can be exercised
-- without mpv. It is deliberately ONE stable table: host modules capture
-- `require 'mp'` at load time, so `reset()` clears the state in place.

local S = {}

local fake = {
    messages = {},
    props = {},
    events = {},
    commands = {},
    timeouts = {},
    log = {},
    time = 0,
}

S.fake = fake

function S.reset()
    fake.messages, fake.props, fake.events = {}, {}, {}
    fake.commands, fake.timeouts, fake.log = {}, {}, {}
    fake.time = 0
    fake.osd_width, fake.osd_height = 1280, 720
    fake.fps = 60
    fake.overlay = nil
end

--- Run every timeout queued since the last call (one frame of the host loop).
function S.pump()
    local queued = fake.timeouts
    fake.timeouts = {}
    for _, cb in ipairs(queued) do
        cb()
    end
end

---@return table mp the stub, also installed as `package.loaded['mp']`
function S.install()
    local mp = {}

    mp.msg = {
        info = function(...) fake.messages[#fake.messages + 1] = { 'info', ... } end,
        warn = function(...) fake.messages[#fake.messages + 1] = { 'warn', ... } end,
        error = function(...) fake.messages[#fake.messages + 1] = { 'error', ... } end,
    }

    function mp.get_property_native(name)
        if name == 'mouse-pos' then
            return fake.mouse
        end
        return 'native:' .. name
    end

    function mp.set_property_native(name, value)
        fake.props[name] = value
    end

    function mp.get_property_number(name)
        if name == 'display-fps' or name == 'estimated-display-fps' then
            return fake.fps
        end
        return nil
    end

    function mp.get_time()
        return fake.time
    end

    function mp.commandv(...)
        fake.commands[#fake.commands + 1] = { ... }
    end

    function mp.observe_property(name, _, cb)
        fake.events[#fake.events + 1] = { name = name, cb = cb }
    end

    function mp.unobserve_property() end

    function mp.register_script_message(name, cb)
        fake.log[name] = cb
    end

    function mp.unregister_script_message(name)
        fake.log[name] = nil
    end

    function mp.register_event(name, cb)
        fake.log['event:' .. name] = cb
    end

    function mp.unregister_event() end

    function mp.wait_event() end

    function mp.add_timeout(_, cb)
        fake.timeouts[#fake.timeouts + 1] = cb
        return { cb = cb }
    end

    function mp.create_osd_overlay(format)
        fake.overlay = {
            format = format,
            z = 0,
            data = nil,
            res_x = nil,
            res_y = nil,
            updates = 0,
        }
        fake.overlay.update = function(self)
            self.updates = self.updates + 1
        end
        fake.overlay.remove = function() end
        return fake.overlay
    end

    function mp.get_osd_size()
        return fake.osd_width, fake.osd_height
    end

    function mp.set_key_bindings(list, section, flags)
        fake.bindings = { list = list, section = section, flags = flags }
    end

    function mp.enable_key_bindings(section, flags)
        fake.bindings_enabled = { section = section, flags = flags }
    end

    function mp.disable_key_bindings(section)
        fake.bindings_enabled = nil
        fake.bindings_disabled = section
    end

    package.loaded['mp'] = mp
    return mp
end

return S
