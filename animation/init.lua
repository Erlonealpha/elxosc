-- Public animation aggregate.

local controller_mod = require 'animation.controller'
local curve_mod = require 'animation.curve'
local tween_mod = require 'animation.tween'

return {
    AnimationController = controller_mod.AnimationController,
    Tween = tween_mod.Tween,
    Curves = curve_mod.Curves,
    linear = curve_mod.linear,
    ease_in = curve_mod.ease_in,
    ease_out = curve_mod.ease_out,
    ease_in_out = curve_mod.ease_in_out,
}
