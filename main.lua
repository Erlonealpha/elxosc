-- elxosc entry point (loaded by mpv as scripts/elxosc/main.lua).
--
-- Loads elxlib, then starts the render loop with a
-- small interactive smoke demo (hover + click) so the ASS backend and the
-- input layer can be eyeballed in mpv. Replace `build()` with a real widget
-- tree as the framework grows.

local mp = require 'mp'

require 'elxlib_load' -- sets up elxlibs.*


local dbg = true

function debug_msg(arg0, ...)
    if dbg then
        if type(arg0) == "function" then
            mp.msg.info('DEBUG', arg0())
        else
            mp.msg.info('DEBUG', arg0, ...)
        end
    end
end
function debug_msgf(arg0, ...)
    if dbg then
        mp.msg.info('DEBUG', string.format(arg0, ...))
    end
end

local geometry = require 'foundation.geometry'
local color = require 'foundation.color'
local paint = require 'painting.paint'
local text_style = require 'text.text_style'
local ass_text = require 'backends.ass_text_layout'
local custom_paint = require 'render.custom_paint'
local gesture = require 'render.gesture'
local mpv_app = require 'host.mpv_app'

local Offset, Size, Rect = geometry.Offset, geometry.Size, geometry.Rect
local Color = color.Color
local Paint = paint.Paint
local TextStyle = text_style.TextStyle
local AssTextLayout = ass_text.AssTextLayout
local RenderCustomPaint = custom_paint.RenderCustomPaint
local RenderGesture = gesture.RenderGesture

local text = AssTextLayout()

---@type App?
local app
local state = { hovered = false, taps = 0 }

local function repaint()
    ---@cast app -?
    app.owner:mark_needs_paint()
end

local function build()
    local box = RenderCustomPaint(function(canvas, offset, size)
        local background = state.hovered
            and Color.rgba255(0x32, 0x32, 0x32, 0xF0)
            or Color.rgba255(0x1E, 0x1E, 0x1E, 0xE0)
        canvas:draw_rrect(Rect.from_offset_size(offset, size), 12, Paint(background))
        local label = text:layout('elxosc  ' .. state.taps, TextStyle(28, {
            color = Color.rgba255(0xF0, 0xF0, 0xF0),
        }))
        canvas:draw_text(label, (offset + Offset(24, 16)) --[[@as Offset]])
    end, { preferred_size = Size(240, 96) })

    return RenderGesture(box, {
        on_enter = function()
            state.hovered = true
            repaint()
        end,
        on_leave = function()
            state.hovered = false
            repaint()
        end,
        on_tap = function()
            state.taps = state.taps + 1
            repaint()
        end,
    })
end

app = mpv_app.start(build)
