-- Public animation aggregate.

local controller_mod = require 'src.animation.controller'
local curve_mod = require 'src.animation.curve'
local tween_mod = require 'src.animation.tween'

---@class elxosc.src.animation
local M = {
    AnimationController = controller_mod.AnimationController,
    Tween = tween_mod.Tween,
    Curves = curve_mod.Curves,
    linear = curve_mod.linear,
    ease_in = curve_mod.ease_in,
    ease_out = curve_mod.ease_out,
    ease_in_out = curve_mod.ease_in_out,
}

return M
