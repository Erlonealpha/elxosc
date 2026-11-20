-- Test-only transport into the production MpInput; installed in staged Apps.
---@namespace test.directInput
---@using elxosc
local mp = require 'mp'
local json = require 'elxlibs.json'
local M = {}

---@param app table
function M.install(app)
    local input = app.input
    if input._mouse_callback then
        mp.unobserve_property(input._mouse_callback)
    end
    -- Button events use the explicit test position rather than the desktop mouse.
    input._refresh_position = function()
    end
    mp.set_property('user-data/elxosc-test-input-result', '')
    mp.register_script_message('elxosc-test-input', function(sequence, event, x, y, button)
        local ok, result = pcall(function()
            if event == 'leave' then
                input.hover = false
                input.owner:clear_hover()
                input:cancel_capture()
            else
                input.x, input.y = assert(tonumber(x)), assert(tonumber(y))
                input.hover = true
                assert(event == 'move' or event == 'down' or event == 'up' or event == 'double',
                    'unsupported direct input event')
                local section = input._pressed_section
                if section == nil then
                    for index = #input._input_sections, 1, -1 do
                        local candidate = input._input_sections[index]
                        local area = input._active_sections[candidate]
                        if area and input.x >= area.left and input.x < area.right
                            and input.y >= area.top and input.y < area.bottom then
                            section = candidate
                            break
                        end
                    end
                end
                input:_dispatch(event, button ~= '' and button or nil, section)
            end
            return { capture = app.owner:has_pointer_capture(), pressed = input._pressed,
                pause = mp.get_property_native('pause') }
        end)
        mp.set_property('user-data/elxosc-test-input-result', json.dumps({ sequence = sequence,
            ok = ok, result = ok and result or nil, error = not ok and tostring(result) or nil }))
    end)
    mp.set_property('user-data/elxosc-test-input-ready', 'yes')
end

return M
