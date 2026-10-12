-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend agnostic vector path.
--
-- A Path is a *recording* of drawing verbs (move / line / quad / cubic /
-- close) with no geometry of its own. Higher level shapes such as rectangles,
-- rounded rectangles and ovals are lowered to those five verbs here, so a
-- render backend only ever has to implement the primitives -- never the
-- convenience shapes. This mirrors Flutter, where every shape bottoms out in
-- `Canvas.drawPath`.

local std = require 'elxlibs.std'

local math = math
local string = string
local min = math.min

local M = {}

--- The drawing verbs a backend must understand.
---@alias PathVerb
--- | 'move_to'
--- | 'line_to'
--- | 'quad_to'
--- | 'cubic_to'
--- | 'close'

M.Verb = {
    MOVE_TO = 'move_to',
    LINE_TO = 'line_to',
    QUAD_TO = 'quad_to',
    CUBIC_TO = 'cubic_to',
    CLOSE = 'close',
}

local Verb = M.Verb

--- kappa: control point distance that turns a cubic bezier into a quarter arc.
local KAPPA = 0.5522847498307936

---@class Path : std.object
---@overload fun(): self
local Path = std.class.new('Path', {})

function Path:__init()
    --- Each entry is `{ verb, numbers... }`, e.g. `{ 'line_to', x, y }`.
    ---@type any[][]
    self._verbs = {}
end

function Path:__tostring()
    return string.format('Path(%d verbs)', #self._verbs)
end

---@return boolean
function Path:is_empty()
    return #self._verbs == 0
end

---@return any[][] the raw verb list, for backends to iterate
function Path:verbs()
    return self._verbs
end

---@param x number
---@param y number
---@return Path self (chainable)
function Path:move_to(x, y)
    local verbs = self._verbs
    verbs[#verbs + 1] = { Verb.MOVE_TO, x, y }
    return self
end

---@param x number
---@param y number
---@return Path self (chainable)
function Path:line_to(x, y)
    local verbs = self._verbs
    verbs[#verbs + 1] = { Verb.LINE_TO, x, y }
    return self
end

---@param cx number control point
---@param cy number
---@param x number end point
---@param y number
---@return Path self (chainable)
function Path:quad_to(cx, cy, x, y)
    local verbs = self._verbs
    verbs[#verbs + 1] = { Verb.QUAD_TO, cx, cy, x, y }
    return self
end

---@param c1x number first control point
---@param c1y number
---@param c2x number second control point
---@param c2y number
---@param x number end point
---@param y number
---@return Path self (chainable)
function Path:cubic_to(c1x, c1y, c2x, c2y, x, y)
    local verbs = self._verbs
    verbs[#verbs + 1] = { Verb.CUBIC_TO, c1x, c1y, c2x, c2y, x, y }
    return self
end

---@return Path self (chainable)
function Path:close()
    local verbs = self._verbs
    verbs[#verbs + 1] = { Verb.CLOSE }
    return self
end

---@return Path self
function Path:reset()
    self._verbs = {}
    return self
end

--- Append a closed axis aligned rectangle.
---@param rect Rect
---@return Path self (chainable)
function Path:add_rect(rect)
    local l, t, r, b = rect.left, rect.top, rect.right, rect.bottom
    return self:move_to(l, t):line_to(r, t):line_to(r, b):line_to(l, b):close()
end

--- Append a rectangle with uniform rounded corners of `radius`.
---@param rect Rect
---@param radius number? defaults to 0 (a plain rectangle)
---@return Path self (chainable)
function Path:add_rrect(rect, radius)
    local l, t, r, b = rect.left, rect.top, rect.right, rect.bottom
    local rad = min(radius or 0, min(r - l, b - t) / 2)
    if rad <= 0 then
        return self:add_rect(rect)
    end
    local c = rad * KAPPA
    return self
        :move_to(l + rad, t)
        :line_to(r - rad, t)
        :cubic_to(r - rad + c, t, r, t + rad - c, r, t + rad)
        :line_to(r, b - rad)
        :cubic_to(r, b - rad + c, r - rad + c, b, r - rad, b)
        :line_to(l + rad, b)
        :cubic_to(l + rad - c, b, l, b - rad + c, l, b - rad)
        :line_to(l, t + rad)
        :cubic_to(l, t + rad - c, l + rad - c, t, l + rad, t)
        :close()
end

--- Append an ellipse inscribed in `rect` (four cubic arcs).
---@param rect Rect
---@return Path self (chainable)
function Path:add_oval(rect)
    local l, t, r, b = rect.left, rect.top, rect.right, rect.bottom
    local cx, cy = (l + r) / 2, (t + b) / 2
    local rx, ry = (r - l) / 2, (b - t) / 2
    local ox, oy = rx * KAPPA, ry * KAPPA
    return self
        :move_to(cx, t)
        :cubic_to(cx + ox, t, r, cy - oy, r, cy)
        :cubic_to(r, cy + oy, cx + ox, b, cx, b)
        :cubic_to(cx - ox, b, l, cy + oy, l, cy)
        :cubic_to(l, cy - oy, cx - ox, t, cx, t)
        :close()
end

M.Path = Path

return M
