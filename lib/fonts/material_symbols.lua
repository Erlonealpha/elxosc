-- Bundled font resource contract shared by Icon and the Material collection.
local std = require 'elxlibs.std'
local raise = std.raise

---@class MaterialSymbolsVariations
---@field fill number? FILL axis, 0..1
---@field weight number? wght axis, 100..700
---@field grade number? GRAD axis, -25..200
---@field optical_size number? opsz axis, 20..48

---@class MaterialSymbolsFont
---@field font_family FluentIconFontName
local MaterialSymbols = { font_family = 'Material Symbols Rounded' }

local function axis(name, value, lower, upper)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge
        or value < lower or value > upper then
        raise(std.ValueError(string.format(
            'Icon.%s must be a finite number between %g and %g', name, lower, upper)))
    end
    return value
end

---@param options MaterialSymbolsVariations?
---@return MaterialSymbolsVariations
function MaterialSymbols.normalize(options)
    options = options or {}
    return {
        fill = axis('fill', options.fill == nil and 0 or options.fill, 0, 1),
        weight = axis('weight', options.weight == nil and 400 or options.weight, 100, 700),
        grade = axis('grade', options.grade == nil and 0 or options.grade, -25, 200),
        optical_size = axis('optical_size', options.optical_size == nil and 24 or options.optical_size, 20, 48),
    }
end

---@param options MaterialSymbolsVariations
---@return TextStyleExtra
function MaterialSymbols.text_extra(options)
    return { type = 'material-symbols', fill = options.fill, weight = options.weight,
        grade = options.grade, optical_size = options.optical_size }
end

---@class elxosc.mod.fonts.material_symbols
local M = { MaterialSymbols = MaterialSymbols }
return M
