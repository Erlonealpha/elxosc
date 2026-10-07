-- Foundation layer: geometry value types, colour, paint, path and the canvas
-- contract. Pure Lua -- nothing here touches mpv.

local F = require('framework')
local std = require('elxlibs.std')

local geometry = require('foundation.geometry')
local color = require('foundation.color')
local paint = require('painting.paint')
local path = require('painting.path')
local canvas = require('painting.canvas')

local Offset, Size, Rect, EdgeInsets =
    geometry.Offset, geometry.Size, geometry.Rect, geometry.EdgeInsets
local Color = color.Color
local Paint, Style = paint.Paint, paint.Style
local Path = path.Path
local Canvas = canvas.Canvas

--== Offset ================================================================

F.section('geometry: Offset')

F.test('constructs with defaults and compares by value', function()
    local a = Offset(1, 2)
    F.eq(a.x, 1, 'x')
    F.eq(a.y, 2, 'y')
    F.eq(Offset().x, 0, 'default x')
    F.eq(Offset().y, 0, 'default y')
    F.ok(a == Offset(1, 2), 'equal values compare equal')
    F.ok(a ~= Offset(1, 3), 'different values compare unequal')
    F.eq(tostring(a), 'Offset(1, 2)', 'tostring')
end)

F.test('supports value arithmetic and helpers', function()
    local a = Offset(1, 2)
    F.ok(a + Offset(3, 4) == Offset(4, 6), 'add')
    F.ok(a - Offset(3, 4) == Offset(-2, -2), 'sub')
    F.ok(a * 2 == Offset(2, 4), 'mul')
    F.ok(-a == Offset(-1, -2), 'unm')
    F.ok(a:translate(2, 3) == Offset(3, 5), 'translate')
    F.ok(a:scale(3) == Offset(3, 6), 'scale uniform')
    F.ok(a:scale(3, 4) == Offset(3, 8), 'scale anisotropic')
    F.eq(Offset.zero().x + Offset.zero().y, 0, 'zero')
end)

F.test('measures length and distance', function()
    F.close(Offset(3, 4):length(), 5, 'length')
    F.close(Offset(0, 0):distance(Offset(3, 4)), 5, 'distance')
end)

--== Size ==================================================================

F.section('geometry: Size')

F.test('constructs, compares and combines', function()
    local s = Size(4, 2)
    F.ok(s == Size(4, 2), 'eq')
    F.ok(s + Size(1, 1) == Size(5, 3), 'add')
    F.ok(s - Size(1, 2) == Size(3, 0), 'sub')
    F.ok(s * 2 == Size(8, 4), 'mul')
    F.eq(Size.square(3).width, 3, 'square')
end)

F.test('reports aspect ratio, area and emptiness', function()
    F.close(Size(4, 2):aspect_ratio(), 2, 'aspect ratio')
    F.close(Size(4, 2):area(), 8, 'area')
    F.ok(Size(0, 5):is_empty(), 'zero width is empty')
    F.ok(not Size(1, 1):is_empty(), 'positive size is not empty')
end)

--== Rect ==================================================================

F.section('geometry: Rect')

F.test('builds from ltwh and exposes edges and metrics', function()
    local r = Rect.from_ltwh(10, 20, 30, 40)
    F.eq(r.left, 10, 'left')
    F.eq(r.top, 20, 'top')
    F.eq(r.right, 40, 'right')
    F.eq(r.bottom, 60, 'bottom')
    F.close(r:width(), 30, 'width')
    F.close(r:height(), 40, 'height')
    F.ok(r:size() == Size(30, 40), 'size')
    F.ok(r:center() == Offset(25, 40), 'center')
    F.ok(r:top_left() == Offset(10, 20), 'top_left')
end)

F.test('contains uses a half-open range', function()
    local r = Rect(0, 0, 10, 10)
    F.ok(r:contains(Offset(0, 0)), 'top-left corner is inside')
    F.ok(r:contains(Offset(9.5, 9.5)), 'interior is inside')
    F.ok(not r:contains(Offset(10, 5)), 'right edge is exclusive')
    F.ok(not r:contains(Offset(5, 10)), 'bottom edge is exclusive')
    F.ok(not r:contains(Offset(-1, 5)), 'outside is outside')
end)

F.test('inflates, deflates, shifts and translates', function()
    local r = Rect(10, 10, 20, 20)
    F.ok(r:inflate(2) == Rect(8, 8, 22, 22), 'inflate')
    F.ok(r:deflate(2) == Rect(12, 12, 18, 18), 'deflate')
    F.ok(r:shift(Offset(1, 2)) == Rect(11, 12, 21, 22), 'shift')
    F.ok(r:translate(1, 2) == Rect(11, 12, 21, 22), 'translate')
end)

F.test('intersects and detects overlap', function()
    local a = Rect(0, 0, 10, 10)
    F.ok(a:intersect(Rect(5, 5, 15, 15)) == Rect(5, 5, 10, 10), 'overlap region')
    F.ok(a:intersect(Rect(20, 20, 30, 30)):is_empty(), 'disjoint intersect is empty')
    F.ok(a:overlaps(Rect(5, 5, 15, 15)), 'overlapping')
    F.ok(not a:overlaps(Rect(10, 0, 20, 10)), 'touching edges do not overlap')
end)

F.test('builds from points and offset+size', function()
    F.ok(Rect.from_points(Offset(5, 1), Offset(2, 9)) == Rect(2, 1, 5, 9), 'from_points')
    F.ok(Rect.from_offset_size(Offset(3, 4), Size(5, 6)) == Rect(3, 4, 8, 10), 'from_offset_size')
end)

--== EdgeInsets ============================================================

F.section('geometry: EdgeInsets')

F.test('constructs from all/symmetric/only', function()
    F.ok(EdgeInsets.all(4) == EdgeInsets(4, 4, 4, 4), 'all')
    F.ok(EdgeInsets.symmetric(2, 3) == EdgeInsets(2, 3, 2, 3), 'symmetric')
    F.ok(EdgeInsets.only({ top = 5 }) == EdgeInsets(0, 5, 0, 0), 'only')
    F.ok(EdgeInsets.zero() == EdgeInsets(0, 0, 0, 0), 'zero')
end)

F.test('inflates and deflates rects', function()
    local insets = EdgeInsets(1, 2, 3, 4)
    F.eq(insets:horizontal(), 4, 'horizontal')
    F.eq(insets:vertical(), 6, 'vertical')
    F.ok(insets:inflate_rect(Rect(10, 10, 20, 20)) == Rect(9, 8, 23, 24), 'inflate_rect')
    F.ok(insets:deflate_rect(Rect(10, 10, 20, 20)) == Rect(11, 12, 17, 16), 'deflate_rect')
end)

--== Color =================================================================

F.section('color: Color')

F.test('builds from rgba255 and exposes bytes', function()
    local c = Color.rgba255(255, 128, 0, 255)
    F.close(c.r, 1, 'r')
    F.close(c.a, 1, 'a')
    local r, g, b, a = c:to_rgba255()
    F.eq(r, 255, 'r byte')
    F.eq(g, 128, 'g byte')
    F.eq(b, 0, 'b byte')
    F.eq(a, 255, 'a byte')
end)

F.test('decodes 0xAARRGGBB and hex strings', function()
    F.ok(Color.argb(0xFF102030) == Color.rgba255(0x10, 0x20, 0x30, 0xFF), 'argb')
    F.ok(Color.hex('#102030') == Color.rgba255(0x10, 0x20, 0x30, 0xFF), 'hex rrggbb')
    F.ok(Color.hex('10203080') == Color.rgba255(0x10, 0x20, 0x30, 0x80), 'hex rrggbbaa')
    F.ok(Color.hex('#f00') == Color.rgba255(0xFF, 0x00, 0x00, 0xFF), 'hex rgb shorthand')
end)

F.test('derives new colours without mutating the source', function()
    local c = Color(0.1, 0.2, 0.3, 0.4)
    F.close(c:with_alpha(1).a, 1, 'with_alpha')
    F.close(c.a, 0.4, 'source unchanged')
    F.ok(c:with_rgb(0.5, 0.6, 0.7) == Color(0.5, 0.6, 0.7, 0.4), 'with_rgb keeps alpha')
end)

F.test('rejects malformed hex', function()
    F.raises(function() Color.hex('#12345') end, 'ValueError', 'bad hex raises')
end)

--== Paint =================================================================

F.section('painting: Paint')

F.test('has fill defaults', function()
    local p = Paint()
    F.eq(p.style, Style.FILL, 'default style')
    F.eq(p.stroke_width, 1, 'default stroke width')
    F.eq(tostring(p.color), tostring(Color.argb(0xFF000000)), 'default black')
end)

F.test('copy is independent from the original', function()
    local p = Paint(Color(1, 0, 0), Style.STROKE, 3)
    local q = p:copy()
    q.stroke_width = 9
    F.eq(p.stroke_width, 3, 'original untouched')
    F.eq(q.stroke_width, 9, 'copy mutated')
    F.eq(q.style, Style.STROKE, 'style copied')
end)

--== Path ==================================================================

F.section('painting: Path')

F.test('records primitive verbs in order', function()
    local p = Path():move_to(0, 0):line_to(10, 0):quad_to(1, 2, 3, 4):cubic_to(1, 1, 2, 2, 3, 3):close()
    local v = p:verbs()
    F.eq(#v, 5, 'verb count')
    F.eq(v[1][1], path.Verb.MOVE_TO, 'first verb')
    F.eq(v[2][1], path.Verb.LINE_TO, 'second verb')
    F.eq(v[3][1], path.Verb.QUAD_TO, 'third verb')
    F.eq(v[4][1], path.Verb.CUBIC_TO, 'fourth verb')
    F.eq(v[5][1], path.Verb.CLOSE, 'fifth verb')
    F.ok(p:move_to(1, 1) == p, 'verbs are chainable')
end)

F.test('lowers rect, rrect and oval to primitives', function()
    F.eq(#Path():add_rect(Rect(0, 0, 10, 10)):verbs(), 5, 'rect -> move,3 lines,close')
    F.eq(#Path():add_oval(Rect(0, 0, 10, 10)):verbs(), 6, 'oval -> move,4 cubics,close')
    F.eq(#Path():add_rrect(Rect(0, 0, 10, 10), 2):verbs(), 10, 'rrect -> 4 lines,4 cubics,close')
    F.eq(#Path():add_rrect(Rect(0, 0, 10, 10), 0):verbs(), 5, 'zero radius is a plain rect')
end)

F.test('reports and resets emptiness', function()
    local p = Path()
    F.ok(p:is_empty(), 'fresh path is empty')
    p:move_to(0, 0)
    F.ok(not p:is_empty(), 'after a verb it is not empty')
    F.ok(p:reset():is_empty(), 'reset empties the path')
end)

--== Canvas ================================================================

F.section('painting: Canvas')

F.test('the base contract raises NotImplementedError', function()
    local c = Canvas()
    F.raises(function() c:save() end, 'NotImplementedError', 'save')
    F.raises(function() c:draw_rect(Rect(0, 0, 1, 1), Paint()) end, 'NotImplementedError', 'draw_rect')
end)

F.test('a backend only needs to override the methods it uses', function()
    local Recorder = std.class.new('test.Recorder', { Canvas })
    function Recorder:__init()
        self.saved = 0
    end
    function Recorder:save()
        self.saved = self.saved + 1
    end
    local r = Recorder()
    r:save()
    F.eq(r.saved, 1, 'overridden method runs')
    F.raises(function() r:translate(1, 2) end, 'NotImplementedError', 'non-overridden method still raises')
end)
