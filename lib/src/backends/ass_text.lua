-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha
-- Shared ASS shape and literal-text encoding, independent of layout and host.
---@namespace elxosc
---@using elxosc

local format = string.format
local concat = table.concat

---@class mod.src.backends.ass_text
local M = {}

---@param style TextStyle
---@param default_font_family string?
---@return string
function M.shape_tags(style, default_font_family)
    local tags = { format('\\fs%g', style.font_size) }
    local family = style.font_family or default_font_family
    if family then
        tags[#tags + 1] = '\\fn' .. family
    end
    if style.bold then
        tags[#tags + 1] = '\\b1'
    end
    if style.italic then
        tags[#tags + 1] = '\\i1'
    end
    if style.letter_spacing ~= 0 then
        tags[#tags + 1] = format('\\fsp%g', style.letter_spacing)
    end
    tags[#tags + 1] = '\\q2'
    return concat(tags)
end

--- Preserve boundary spaces which libass otherwise trims. Interior spaces keep
--- their normal semantics; callers supply already selected hard lines.
---@param text string
---@return string
function M.escape_line(text)
    text = text:gsub('\\', '\\\226\128\128'):gsub('{', '\\{')
    text = text:gsub('^ +', function(spaces)
        return string.rep('\\h', #spaces)
    end)
    text = text:gsub(' +$', function(spaces)
        return string.rep('\\h', #spaces)
    end)
    return text
end

return M
