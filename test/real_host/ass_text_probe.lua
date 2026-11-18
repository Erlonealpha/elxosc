-- Isolated text-metric probe. Reuses production encoding without starting App.
---@namespace elxosc
---@using elxosc
---@using elxosc.host

local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local AssMeasure = require('host.ass_measure').AssMeasure
local AssCanvas = require('src.backends.ass_canvas').AssCanvas
local AssTextLayout = require('src.backends.ass_text_layout').AssTextLayout
local TextStyle = require('src.text.text_style').TextStyle
local TextPaint = require('src.painting.text_paint').TextPaint
local Paragraph = require('src.text.paragraph').Paragraph
local geometry = require 'src.foundation.geometry'
local Offset, Size = geometry.Offset, geometry.Size
local estimate = AssTextLayout()

---@class AssTextProbeRequest
---@field name string
---@field text string
---@field style _TextStyleOptions?
---@field scale number?
---@field shift number?
---@field clip boolean?
---@field soft_wrap boolean?
---@field literal_ass string? diagnostic override, never used by production
---@field environment_font boolean?

---@param request AssTextProbeRequest
---@param anchor AnchorName
---@param x number
---@param y number
---@return string
local function encode(request, anchor, x, y)
    local style = TextStyle(request.style)
    -- Deliberately retain the old fs0 diagnostic. Production suppresses fs0;
    -- this probe explicitly asks libass what that raw override means.
    local zero_font = style.font_size == 0
    if zero_font then
        style = style:copy_with({ font_size = 1 })
    end
    if request.environment_font then
        style = style:copy_with({ font_family = mp.get_property('osd-font') })
    end
    local paragraph = Paragraph(request.text, style, Size(0, 0), { request.text }, style:line_height_px())
    local canvas = AssCanvas()
    local scale = request.scale or 1
    canvas:scale(scale, scale)
    if request.clip then
        canvas:clip_rect(geometry.Rect.from_ltwh(x - 8, y - 32, 32, 64))
    end
    canvas:draw_text(paragraph, Offset(x, y), TextPaint({ anchor = anchor }))
    local event = assert(canvas.events[1])
    if zero_font then
        event = event:gsub('\\fs1', '\\fs0', 1)
    end
    if request.soft_wrap then
        event = event:gsub('\\q2', '\\q0', 1)
    end
    if not request.soft_wrap then
        event = event:gsub('}', '\\q2}', 1)
    end
    if request.literal_ass then
        event = event:match('^({.-})') .. request.literal_ass
    end
    return event
end

---@param data string
---@param width number
---@param height number
---@param service AssMeasure
---@return table
local function sample(data, width, height, service)
    local start = mp.get_time()
    local raw, err, kind = service:measure(data)
    local elapsed = (mp.get_time() - start) * 1000
    if raw == nil then
        return { data = data, error = err, kind = kind, elapsed_ms = elapsed }
    end
    if next(raw) == nil then
        return { data = data, raw = raw, empty = true, elapsed_ms = elapsed }
    end
    local bounds = raw --[[@as AssMeasureBounds]]
    return { data = data, raw = raw, elapsed_ms = elapsed,
        edge = bounds.x0 <= 0 or bounds.y0 <= 0 or bounds.x1 >= width or bounds.y1 >= height }
end

mp.register_script_message('elxosc-text-probe', function(path)
    local report = { samples = {}, removed = false }
    local service
    local ok, err = pcall(function()
        local file = assert(io.open(path, 'rb'))
        local contents = file:read('*a')
        file:close()
        local bundle = assert(utils.parse_json(contents))
        local width, height = mp.get_osd_size()
        assert(width > 0 and height > 0, 'OSD is not initialized')
        local res_scale = bundle.res_scale or 1
        local res_x, res_y = width * res_scale, height * res_scale
        service = AssMeasure({ res_x = res_x, res_y = res_y })
        report.environment = { width = width, height = height,
            mpv = mp.get_property('mpv-version'), ffmpeg = mp.get_property('ffmpeg-version'),
            osd_font = mp.get_property('osd-font'), display_fps = mp.get_property_number('display-fps'),
            luajit = jit.version, elxlib = require 'elxlib.version' }
        for _, request in ipairs(bundle.samples) do
            local scale = request.scale or 1
            local x = (res_x / 2 + (request.shift or 0)) / scale
            local y = res_y / 2 / scale
            local result = { request = request, estimate = estimate:line_width(request.text, TextStyle(request.style)),
                anchors = {} }
            for _, anchor in ipairs({ 'center_left', 'center', 'center_right' }) do
                local data = encode(request, anchor, x, y)
                result.anchors[anchor] = sample(data, res_x, res_y, service)
            end
            -- Repeat at the same location after other payloads have been submitted.
            result.repeat_left = sample(encode(request, 'center_left', x, y), res_x, res_y, service)
            -- A left/right pair can use separate safe positions to fit longer runs.
            local left_x, right_x = 32 / scale, (res_x - 32) / scale
            result.safe_pair = {
                left_x = left_x * scale, right_x = right_x * scale,
                left = sample(encode(request, 'center_left', left_x, y), res_x, res_y, service),
                right = sample(encode(request, 'center_right', right_x, y), res_x, res_y, service),
            }
            report.samples[#report.samples + 1] = result
        end
        local empty = service:measure('')
        report.empty_image = empty
        local after_empty = service:measure(encode(bundle.samples[1], 'center_left', res_x / 2, res_y / 2))
        report.after_empty = after_empty
        report.res_scale = res_scale
        local data = encode(bundle.samples[1], 'center_left', res_x / 2, res_y / 2)
        local timing = { encode = {}, native_same = {}, native_changed = {}, pair = {} }
        for index = 1, 110 do
            local start = mp.get_time()
            encode(bundle.samples[1], 'center_left', res_x / 2, res_y / 2)
            local encoded = (mp.get_time() - start) * 1000
            start = mp.get_time()
            service:measure(data)
            local same = (mp.get_time() - start) * 1000
            local changed_data = encode({ name = 'timed-label', text = tostring(index) .. ':23',
                style = { font_size = 24, font_family = 'Arial' } }, 'center_left', res_x / 2, res_y / 2)
            start = mp.get_time()
            service:measure(changed_data)
            local changed = (mp.get_time() - start) * 1000
            local right_data = encode(bundle.samples[1], 'center_right', res_x / 2, res_y / 2)
            start = mp.get_time()
            service:measure(data)
            service:measure(right_data)
            local pair = (mp.get_time() - start) * 1000
            if index > 10 then
                timing.encode[#timing.encode + 1] = encoded
                timing.native_same[#timing.native_same + 1] = same
                timing.native_changed[#timing.native_changed + 1] = changed
                timing.pair[#timing.pair + 1] = pair
            end
        end
        report.timing = timing
    end)
    if service then
        local removed, cleanup_error = service:dispose()
        report.removed = removed
        report.cleanup_error = cleanup_error
        local _, closed_error, closed_kind = service:measure('closed')
        report.closed = { error = closed_error, kind = closed_kind }
    end
    if not ok then
        report.error = tostring(err)
    end
    mp.set_property('user-data/elxosc-text-probe-report', utils.format_json(report))
end)
mp.set_property('user-data/elxosc-text-probe-ready', 'yes')
