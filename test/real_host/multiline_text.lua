-- Native layout, per-row libass positioning and isolated multiline cost evidence.
---@namespace test.realMultilineText
---@using elxosc
---@using elxosc.host
local mp = require 'mp'
local utils = require 'mp.utils'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
assert(loadfile(scripts .. '/elxosc/lib/module_loader.lua'))().install(scripts .. '/elxosc')
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local app_mod = require 'host.mpv_app'
local widgets = require 'widgets'
local AssMeasure = require('host.ass_measure').AssMeasure
local AssTextLayout = require('src.backends.ass_text_layout').AssTextLayout
local AssCanvas = require('src.backends.ass_canvas').AssCanvas
local TextStyle = require('src.text.text_style').TextStyle
local TextPaint = require('src.painting.text_paint').TextPaint
local RenderText = require('src.render.text').RenderText
local Constraints = require('src.layout.constraints').Constraints
local Offset = require('src.foundation.geometry').Offset
local RecordCanvas = require('src.backends.record').RecordCanvas
local binding_mod = require 'src.widgets.widgets_binding'

local app = app_mod.start(function()
    return widgets.Text('multiline fixture', { style = TextStyle({ wrap = false }) })
end)
---@type AssMeasure?
local raw_measure
local preview_overlay
local preview_pages = {}

---@return AssCanvas
local function new_canvas()
    local canvas = AssCanvas()
    canvas.default_font_family = 'Arial'
    return canvas
end

---@param paragraph Paragraph
---@param canvas AssCanvas
---@param measurer AssMeasure
---@return table
local function result(paragraph, canvas, measurer)
    local bounds = {}
    for index, event in ipairs(canvas.events) do
        local raw, err = measurer:measure(event)
        assert(raw, err)
        bounds[index] = raw
    end
    return { text = paragraph.text, lines = paragraph.lines, metrics = paragraph.line_metrics,
        width = paragraph.size.width, height = paragraph.size.height,
        line_height = paragraph.line_height, truncated = paragraph.truncated,
        events = canvas.events, bounds = bounds }
end

---@param values number[] seconds
---@return table
local function distribution(values)
    table.sort(values)
    local count = #values
    return { count = count, p50_ms = assert(values[math.ceil(count * 0.5)]) * 1000,
        p95_ms = assert(values[math.ceil(count * 0.95)]) * 1000,
        p99_ms = assert(values[math.ceil(count * 0.99)]) * 1000, max_ms = assert(values[count]) * 1000 }
end

---@param bundle table
---@return table
local function run(bundle)
    app:render()
    local width, height = app.text_layout.res_x, app.text_layout.res_y
    local measurer = AssMeasure({ res_x = width, res_y = height })
    raw_measure = measurer
    local samples = {}
    for _, request in ipairs(bundle.samples) do
        local style = TextStyle(request.style)
        local before = app.text_layout:cache_stats().native_calls
        local paragraph = app.text_layout:layout(request.text, style, request.width)
        local canvas = new_canvas()
        canvas:translate(100, 100)
        canvas:scale(request.scale or 1)
        canvas:draw_text(paragraph, Offset(200, 110),
            TextPaint({ anchor = request.anchor, offset = Offset(3, 4) }))
        local sample = result(paragraph, canvas, measurer)
        sample.name = request.name
        sample.native_calls = app.text_layout:cache_stats().native_calls - before
        local after = app.text_layout:cache_stats().native_calls
        app.text_layout:layout(request.text, style:copy_with(), request.width)
        sample.repeat_native_calls = app.text_layout:cache_stats().native_calls - after
        samples[#samples + 1] = sample
    end
    local clips = {}
    for _, overflow in ipairs({ 'visible', 'clip', 'ellipsis' }) do
        local style = TextStyle({ font_family = 'Arial', font_size = 24, line_height = 2,
            wrap = false, overflow = overflow })
        local node = RenderText('WWWW\nWWWW\nWWWW', style, app.text_layout)
        node:layout(Constraints.tight(30, 35))
        local canvas = new_canvas()
        node:paint(canvas, Offset(400, 250))
        clips[overflow] = result(assert(node.paragraph), canvas, measurer)
    end
    local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(widgets.TextLayoutScope({
        layout = app.text_layout, child = widgets.Tooltip({ text = 'hello world\nsecond row',
            bounds_width = 80, bounds_height = 400, anchor_top = 200, margin = 0,
            style = TextStyle({ font_family = 'Arial', font_size = 24, line_height = 2,
                max_lines = 2, overflow = 'ellipsis' }),
            child = widgets.SizedBox({ width = 100, height = 20 }),
        }),
    }))
    tree.render_owner:set_viewport(Constraints.tight(100, 20))
    tree.render_owner:layout()
    tree.render_owner:dispatch_pointer('move', Offset(10, 10))
    tree.render_owner:layout()
    local recording = RecordCanvas()
    tree.render_owner:paint(recording)
    local tooltip
    for _, op in ipairs(recording.ops) do
        if op.name == 'draw_text' then
            local canvas = new_canvas()
            canvas:translate(100, 200)
            canvas:draw_text(op[1], op[2], op[3])
            tooltip = result(op[1], canvas, measurer)
        end
    end
    tree:dispose()
    local benchmarks = {}
    for _, scene in ipairs(bundle.benchmarks) do
        local style = TextStyle(scene.style)
        local cold, hot, paint, bounds_times = {}, {}, {}, {}
        local calls, counts, bytes, final_stats = {}, {}, {}, {}
        for round = 1, 12 do
            local layout = AssTextLayout({ res_x = width, res_y = height, default_font_family = 'Arial',
                measure_ass = function(data)
                    local raw, err, kind = measurer:measure(data)
                    return raw --[[@as AssTextRawBounds?]], err, kind
                end })
            local start = mp.get_time()
            local paragraph = layout:layout(scene.text, style, scene.width)
            cold[round] = mp.get_time() - start
            calls[round] = layout:cache_stats().native_calls
            for _ = 1, 5 do
                start = mp.get_time()
                layout:layout(scene.text, style, scene.width)
                hot[#hot + 1] = mp.get_time() - start
            end
            local canvas = new_canvas()
            start = mp.get_time()
            canvas:draw_text(paragraph, Offset(100, 300))
            paint[round] = mp.get_time() - start
            local payload = canvas:text()
            counts[round], bytes[round] = #canvas.events, #payload
            start = mp.get_time()
            local raw, err = measurer:measure(payload)
            assert(raw, err)
            bounds_times[round] = mp.get_time() - start
            final_stats = layout:cache_stats()
        end
        benchmarks[#benchmarks + 1] = { name = scene.name, cold = distribution(cold),
            hot = distribution(hot), paint = distribution(paint), compute_bounds = distribution(bounds_times),
            cold_native_calls = calls, event_counts = counts, payload_bytes = bytes, stats = final_stats }
    end
    preview_pages = require('multiline_preview').build(app.text_layout)
    local removed, remove_error = measurer:dispose()
    assert(removed, remove_error)
    raw_measure = nil
    app:shutdown()
    preview_overlay = mp.create_osd_overlay('ass-events')
    preview_overlay.res_x, preview_overlay.res_y = 1280, 720
    preview_overlay.data = assert(preview_pages[1]).data
    preview_overlay:update()
    local preview_reports = {}
    for index, page in ipairs(preview_pages) do
        preview_reports[index] = { id = page.id, cases = page.cases, res_x = page.res_x, res_y = page.res_y }
    end
    return { samples = samples, clips = clips, tooltip = tooltip, benchmarks = benchmarks, cleanup = true,
        previews = preview_reports,
        environment = { mpv = mp.get_property('mpv-version'), luajit = jit.version,
            elxlib = require 'elxlib.version', res_x = width, res_y = height,
            osd = mp.get_property_native('osd-dimensions'), jit_enabled = jit.status(),
            clock = 'mp.get_time wall seconds', cold_rounds = 12, hot_per_cold = 5 } }
end

mp.register_script_message('elxosc-multiline-text', function(source)
    local ok, report = pcall(function()
        local file = assert(io.open(source, 'rb'))
        local data = file:read('*a')
        file:close()
        return run(assert(utils.parse_json(data)))
    end)
    if not ok then
        if raw_measure then
            raw_measure:dispose()
        end
        app:shutdown()
        if preview_overlay then
            preview_overlay:remove()
        end
        report = { error = tostring(report) }
    end
    mp.set_property('user-data/elxosc-multiline-report', utils.format_json(report))
end)
mp.register_script_message('elxosc-multiline-preview-page', function(id)
    for _, page in ipairs(preview_pages) do
        if page.id == id and preview_overlay then
            preview_overlay.data = page.data
            preview_overlay:update()
            mp.set_property('user-data/elxosc-multiline-preview-page', id)
            return
        end
    end
end)
mp.register_script_message('elxosc-multiline-preview-close', function()
    if preview_overlay then
        preview_overlay:remove()
        preview_overlay = nil
    end
    mp.set_property('user-data/elxosc-multiline-preview-closed', 'yes')
end)
mp.set_property('user-data/elxosc-multiline-ready', 'yes')
