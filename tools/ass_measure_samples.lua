-- Backend output and RecordCanvas logical evidence for offline host calibration.
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local binding_mod = require 'widget.widgets_binding'
local text_layout_mod = require 'text.text_layout'
local text_style_mod = require 'text.text_style'
local ass_layout_mod = require 'backends.ass_text_layout'
local ass_canvas_mod = require 'backends.ass_canvas'
local record_mod = require 'backends.record'
local basic_mod = require 'widget.widgets.basic'
local layout_mod = require 'widget.widgets.layout'

local M = {}
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local TextStyle = text_style_mod.TextStyle
local Text = basic_mod.Text
local Icon = basic_mod.Icon
local Row = layout_mod.Row
local SizedBox = layout_mod.SizedBox
local TransformBox = layout_mod.TransformBox

local function text(value)
    return Text(value, { style = TextStyle({ font_family = 'Arial', font_size = 24,
        wrap = false, outline_width = 0 }) })
end

---@return table bundle
function M.build()
    local old_measurer = text_layout_mod.get_default()
    text_layout_mod.set_default(ass_layout_mod.AssTextLayout())
    local samples = {
        { name = 'text-latin', widget = text('ASS bounds'), font = 'Arial' },
        { name = 'text-cjk', widget = text('播放器文字'), font = 'Arial' },
        { name = 'icon-play', widget = Icon('play_arrow', { size = 24 }), font = 'Material Symbols Rounded' },
        { name = 'scaled-text', widget = TransformBox(text('Scale'), { scale = Size(1.5, 1.25) }), font = 'Arial' },
        { name = 'clipped-text', widget = TransformBox(SizedBox({ width = 80, height = 30,
            child = text('Clipped long text') }), { clip = true }), font = 'Arial' },
        { name = 'composed-row', widget = Row({ main_alignment = 'start', main_axis_size = 'min', cross_alignment = 'center',
            spacing = 12, children = { Icon('play_arrow', { size = 24 }), text('Play') } }),
            font = 'Material Symbols Rounded / Arial' },
    }
    local output = {}
    local ok, err = pcall(function()
        for _, sample in ipairs(samples) do
            local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(sample.widget)
            local painted, paint_error = pcall(function()
                local owner = tree.render_owner
                owner:set_viewport(Constraints.loose(640, 360))
                owner:layout()
                local recorded = record_mod.RecordCanvas()
                owner:paint(recorded)
                local ass = ass_canvas_mod.AssCanvas()
                ass:translate(50, 50)
                for _, op in ipairs(recorded.ops) do
                    ass[op.name](ass, unpack(op, 1, op.n))
                end
                local size = assert(owner.root).size
                local evidence = { size = { width = size.width, height = size.height },
                    box = { left = 50, top = 50, right = 50 + size.width, bottom = 50 + size.height },
                    operations = recorded:names(), event_count = #ass.events }
                output[#output + 1] = { name = sample.name, data = ass:text(), res_x = 640, res_y = 360,
                    metadata = { font_family = sample.font, font_size = 24, scene_version = 1 },
                    logical = evidence }
            end)
            tree:dispose()
            if not painted then
                error(paint_error, 0)
            end
        end
    end)
    text_layout_mod.set_default(old_measurer)
    if not ok then
        error(err, 0)
    end
    return { schema_version = 1, scene = 'framework-ass-calibration', scene_version = 1,
        samples = output }
end

return M
