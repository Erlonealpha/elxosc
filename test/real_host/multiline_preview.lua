-- Annotated review pages. Guides describe logical layout, never glyph baselines.
---@namespace test.multilinePreview
---@using elxosc

local AssCanvas = require('src.backends.ass_canvas').AssCanvas
local TextStyle = require('src.text.text_style').TextStyle
local TextPaint = require('src.painting.text_paint').TextPaint
local RenderText = require('src.render.text').RenderText
local Constraints = require('src.layout.constraints').Constraints
local geometry_mod = require 'src.foundation.geometry'
local Color = require('src.foundation.color').Color
local Paint = require('src.painting.paint').Paint
local anchor_mod = require 'src.foundation.anchor'

local Offset = geometry_mod.Offset
local Rect = geometry_mod.Rect
local palette = {
    background = Color.rgba255(12, 17, 25),
    panel = Color.rgba255(21, 29, 41),
    muted = Color.rgba255(165, 178, 195),
    text = Color.rgba255(244, 246, 250),
    constraint = Color.rgba255(68, 212, 236),
    natural = Color.rgba255(138, 222, 135),
    row = Color.rgba255(220, 164, 72),
    anchor = Color.rgba255(244, 117, 193),
}

---@class PreviewCase
---@field id string
---@field title string
---@field text string
---@field input string escaped source for review
---@field expected string[] independent acceptance statements
---@field style _TextStyleOptions
---@field width number
---@field height number
---@field anchor AnchorName?
---@field offset Offset?
---@field expected_rows integer

---@class PreviewPage
---@field id string
---@field title string
---@field cases PreviewCase[]

---@type PreviewPage[]
local pages = {
    { id = 'layout', title = '多行审阅 1 / 2：空白、行距、对齐与截断', cases = {
        { id = 'A', title = '空格 / Tab / 空行', text = ' A  V\tX\r\n\nHg\r',
            input = '" A  V\\tX\\r\\n\\nHg\\r"', width = 310, height = 108,
            style = { font_size = 18, line_height = 1.5 }, expected_rows = 4,
            expected = { '预期：Tab = 4 空格；第 2 / 4 行为空行。', '4 行各占 27 px；空行保留推进，不绘制字形。' } },
        { id = 'B', title = '不等长行居中', text = 'Hg\nWider word\nHg', input = '"Hg\\nWider word\\nHg"',
            width = 310, height = 99, anchor = 'top_center', expected_rows = 3,
            style = { font_size = 22, line_height = 1.5, align = 'center' },
            expected = { '预期：三行共用竖直中心线；短行仍居中。', '每行推进 33 px；自然段落宽度取最长行。' } },
        { id = 'C', title = '组合序列遇到极窄宽度', text = '👩‍💻👍🏽🇨🇳', input = '"👩‍💻👍🏽🇨🇳"',
            width = 20, height = 108, expected_rows = 3,
            style = { font_family = 'Segoe UI Emoji', font_size = 24, line_height = 1.5 },
            expected = { '预期：ZWJ / 肤色 / 旗帜各整组保留，共 3 行。', '超宽组 visible 越界；一组可因字体 fallback 显示多个字形。' } },
        { id = 'D', title = 'max_lines = 2 / ellipsis',
            text = 'hello   world and long words\nsecond row\nthird hidden row',
            input = '"hello   world and long words\\nsecond row\\nthird hidden row"',
            width = 310, height = 66, expected_rows = 2,
            style = { font_size = 22, line_height = 1.5, max_lines = 2, overflow = 'ellipsis' },
            expected = { '预期：最多 2 行；末行以 … 表示后续内容被截断。', '省略号参与整行测量；显示宽度不超过 310 px。' } },
    } },
    { id = 'overflow', title = '多行审阅 2 / 2：相同约束下的溢出与绘制偏移', cases = {
        { id = 'E', title = 'overflow = visible', text = 'WWWWWWWW\nWWWWWWWW\nWWWWWWWW',
            input = '"WWWWWWWW\\nWWWWWWWW\\nWWWWWWWW"', width = 100, height = 72, expected_rows = 3,
            style = { font_size = 24, line_height = 1.5, wrap = false, overflow = 'visible' },
            expected = { '预期：原文 3 行完整绘制，可越过青色约束盒。', '不自动缩字或省略；自然高度为 108 px。' } },
        { id = 'F', title = 'overflow = clip', text = 'WWWWWWWW\nWWWWWWWW\nWWWWWWWW',
            input = '与 E 完全相同的原文 / 字号 / 约束', width = 100, height = 72, expected_rows = 3,
            style = { font_size = 24, line_height = 1.5, wrap = false, overflow = 'clip' },
            expected = { '预期：字形裁剪在青色盒内；不产生省略号。', '仍排 3 行，第三行在盒外不可见；自然高度不变。' } },
        { id = 'G', title = 'overflow = ellipsis / wrap = false', text = 'WWWWWWWW\nWWWWWWWW\nWWWWWWWW',
            input = '与 E 完全相同的原文 / 字号 / 约束', width = 100, height = 72, expected_rows = 3,
            style = { font_size = 24, line_height = 1.5, wrap = false, overflow = 'ellipsis' },
            expected = { '预期：过宽行各自以 … 收尾，行宽不超过 100 px。', '高度仍为 108 px，第三行裁剪；未设 max_lines。' } },
        { id = 'H', title = 'TextPaint.offset = (14, 8)', text = 'Hg\nHg\nHg', input = '"Hg\\nHg\\nHg"',
            width = 240, height = 108, anchor = 'top_center', offset = Offset(14, 8), expected_rows = 3,
            style = { font_size = 22, line_height = 1.5, align = 'center' },
            expected = { '预期：字形及绿色自然盒沿紫色箭头右移 14、下移 8。', '青色布局盒和原锚点不动；行推进仍为 33 px。' } },
    } },
}

---@param canvas AssCanvas
---@param layout TextLayout
---@param text string
---@param x number
---@param y number
---@param color Color?
---@param size number?
local function label(canvas, layout, text, x, y, color, size)
    local paragraph = layout:layout(text, TextStyle({ font_family = 'Microsoft YaHei',
        font_size = size or 17, color = color or palette.text, wrap = false }))
    canvas:draw_text(paragraph, Offset(x, y), TextPaint({ anchor = 'top_left' }))
end

---@param canvas AssCanvas
---@param x number
---@param y number
---@param width number
---@param height number
---@param color Color
local function outline(canvas, x, y, width, height, color)
    canvas:draw_rect(Rect.from_ltwh(x, y, width, height), Paint(color, 'stroke', 1))
end

---@param canvas AssCanvas
---@param x number
---@param y number
---@param width number
---@param height number
local function natural_outline(canvas, x, y, width, height)
    for start = 0, width - 1, 12 do
        local finish = math.min(start + 6, width)
        canvas:draw_line(Offset(x + start, y), Offset(x + finish, y), Paint(palette.natural))
        canvas:draw_line(Offset(x + start, y + height), Offset(x + finish, y + height), Paint(palette.natural))
    end
    for start = 0, height - 1, 12 do
        local finish = math.min(start + 6, height)
        canvas:draw_line(Offset(x, y + start), Offset(x, y + finish), Paint(palette.natural))
        canvas:draw_line(Offset(x + width, y + start), Offset(x + width, y + finish), Paint(palette.natural))
    end
end

---@param canvas AssCanvas
---@param x number
---@param y number
---@param color Color
local function cross(canvas, x, y, color)
    canvas:draw_line(Offset(x - 5, y), Offset(x + 5, y), Paint(color))
    canvas:draw_line(Offset(x, y - 5), Offset(x, y + 5), Paint(color))
end

---@param canvas AssCanvas
---@param x number
---@param y number
---@param width number
local function row_guide(canvas, x, y, width)
    for start = x, x + width - 1, 12 do
        canvas:draw_line(Offset(start, y), Offset(math.min(start + 5, x + width), y),
            Paint(palette.row:with_alpha(0.5)))
    end
end

---@param canvas AssCanvas
---@param layout TextLayout
---@param scene PreviewCase
---@param x number
---@param y number
---@return table
local function panel(canvas, layout, scene, x, y)
    canvas:draw_rect(Rect.from_ltwh(x, y, 608, 270), Paint(palette.panel))
    label(canvas, layout, scene.id .. '  ' .. scene.title, x + 16, y + 10, nil, 20)
    for index, expected in ipairs(scene.expected) do
        label(canvas, layout, expected, x + 16, y + 42 + (index - 1) * 23, palette.text, 16)
    end
    label(canvas, layout, '输入：' .. scene.input, x + 16, y + 91, palette.muted, 12)
    local style_options = {}
    for name, value in pairs(scene.style) do
        style_options[name] = value
    end
    style_options.font_family = style_options.font_family or 'Arial'
    style_options.color = palette.text
    local style = TextStyle(style_options)
    local anchor = scene.anchor or 'top_left'
    local visual_offset = scene.offset or Offset.zero()
    local node = RenderText(scene.text, style, layout, TextPaint({ anchor = anchor, offset = visual_offset }))
    node:layout(Constraints.tight(scene.width, scene.height))
    local paragraph = assert(node.paragraph)
    local box_x, box_y = x + 96, y + 126
    local fraction = anchor_mod.fraction(anchor)
    local anchor_x, anchor_y = box_x + scene.width * fraction.x, box_y + scene.height * fraction.y
    local natural_x = anchor_x - paragraph.size.width * fraction.x + visual_offset.x
    local natural_y = anchor_y - paragraph.size.height * fraction.y + visual_offset.y
    outline(canvas, box_x, box_y, scene.width, scene.height, palette.constraint)
    natural_outline(canvas, natural_x, natural_y, paragraph.size.width, paragraph.size.height)
    local expected_advance = style.font_size * style.line_height
    for index = 1, scene.expected_rows do
        local center_y = box_y + visual_offset.y + (index - 0.5) * expected_advance
        row_guide(canvas, box_x, center_y, math.max(scene.width, paragraph.size.width))
        label(canvas, layout, tostring(index), box_x - 30, center_y - 8, palette.row, 14)
        if paragraph.lines[index] == '' then
            label(canvas, layout, '空行', box_x + scene.width + 12, center_y - 8, palette.muted, 14)
        end
    end
    if fraction.x == 0.5 then
        canvas:draw_line(Offset(anchor_x, box_y - 5), Offset(anchor_x, box_y + 118),
            Paint(palette.constraint:with_alpha(0.4)))
    end
    node:paint(canvas, Offset(box_x, box_y))
    cross(canvas, anchor_x, anchor_y, palette.anchor)
    if scene.offset then
        local target_x, target_y = anchor_x + visual_offset.x, anchor_y + visual_offset.y
        canvas:draw_line(Offset(anchor_x, anchor_y), Offset(target_x, target_y), Paint(palette.anchor))
        cross(canvas, target_x, target_y, palette.anchor)
        canvas:draw_line(Offset(target_x, target_y), Offset(target_x - 6, target_y - 1), Paint(palette.anchor))
        canvas:draw_line(Offset(target_x, target_y), Offset(target_x - 2, target_y - 6), Paint(palette.anchor))
    end
    label(canvas, layout, string.format('排版：%d 行 | 自然 %.1f × %.1f | 约束 %g × %g | 原文截断 %s',
        #paragraph.lines, paragraph.size.width, paragraph.size.height, scene.width, scene.height,
        paragraph.truncated and '是' or '否'), x + 16, y + 245, palette.muted, 14)
    return { id = scene.id, input = scene.text, expected = scene.expected,
        expected_rows = scene.expected_rows, expected_advance = expected_advance,
        lines = paragraph.lines, metrics = paragraph.line_metrics, truncated = paragraph.truncated,
        constraint = { x = box_x, y = box_y, width = scene.width, height = scene.height },
        natural = { x = natural_x, y = natural_y, width = paragraph.size.width, height = paragraph.size.height },
        anchor = { name = anchor, x = anchor_x, y = anchor_y },
        offset = { x = visual_offset.x, y = visual_offset.y } }
end

local M = {}

---@param layout TextLayout
---@return table[]
function M.build(layout)
    local output = {}
    for _, page in ipairs(pages) do
        local canvas = AssCanvas()
        canvas.default_font_family = 'Arial'
        canvas:draw_rect(Rect.from_ltwh(0, 0, 1280, 720), Paint(palette.background))
        label(canvas, layout, page.title, 24, 15, nil, 24)
        label(canvas, layout, '青：约束布局盒', 24, 57, palette.constraint, 17)
        label(canvas, layout, '绿虚框：自然段落尺寸', 245, 57, palette.natural, 17)
        label(canvas, layout, '橙虚线：预期行中心 / 行号', 478, 57, palette.row, 17)
        label(canvas, layout, '紫十字：锚点 / 偏移', 855, 57, palette.anchor, 17)
        local cases = {}
        for index, scene in ipairs(page.cases) do
            local x = index % 2 == 1 and 24 or 648
            local y = index <= 2 and 98 or 384
            cases[#cases + 1] = panel(canvas, layout, scene, x, y)
        end
        label(canvas, layout, '判读：先看“预期”，再对照字形与边界。辅助线是逻辑尺寸，不是 glyph baseline 或 ink bounds。',
            24, 674, palette.muted, 16)
        output[#output + 1] = { id = page.id, data = canvas:text(), cases = cases, res_x = 1280, res_y = 720 }
    end
    return output
end

return M
