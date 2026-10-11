-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Small, pure progress curves. Curves accept and return a normalized value.

local M = {}

---@param t number
---@return number
function M.linear(t)
    return t
end

---@param t number
---@return number
function M.ease_in(t)
    return t * t
end

---@param t number
---@return number
function M.ease_out(t)
    return 1 - (1 - t) * (1 - t)
end

---@param t number
---@return number
function M.ease_in_out(t)
    if t < 0.5 then
        return 2 * t * t
    end
    local inverse = 1 - t
    return 1 - 2 * inverse * inverse
end

M.Curves = {
    linear = M.linear,
    ease_in = M.ease_in,
    ease_out = M.ease_out,
    ease_in_out = M.ease_in_out,
}

return M
