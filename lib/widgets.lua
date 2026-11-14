-- Public layer members retain their direct-source identity.
local exports = require('export').new()

local export = exports.export

export('widgets', require 'src.widgets.align', true)
export('widgets', require 'src.widgets.ambient', true)
export('widgets', require 'src.widgets.app', true)
export('widgets', require 'src.widgets.binding', true)
export('widgets', require 'src.widgets.build_owner', true)
export('widgets', require 'src.widgets.build_scope', true)
export('widgets', require 'src.widgets.builder', true)
export('widgets', require 'src.widgets.constraints', true)
export('widgets', require 'src.widgets.container', true)
export('widgets', require 'src.widgets.custom_paint', true)
export('widgets', require 'src.widgets.decorated_box', true)
export('widgets', require 'src.widgets.element', true)
export('widgets', require 'src.widgets.flex', true)
export('widgets', require 'src.widgets.framework', true)
export('widgets', require 'src.widgets.gesture_detector', true)
export('widgets', require 'src.widgets.hover_text', true)
export('widgets', require 'src.widgets.icon', true)
export('widgets', require 'src.widgets.key', true)
export('widgets', require 'src.widgets.navigation', true)
export('widgets', require 'src.widgets.offset_box', true)
export('widgets', require 'src.widgets.overflow', true)
export('widgets', require 'src.widgets.overlay', true)
export('widgets', require 'src.widgets.padding', true)
export('widgets', require 'src.widgets.positioned', true)
export('widgets', require 'src.widgets.provider', true)
export('widgets', require 'src.widgets.sized_box', true)
export('widgets', require 'src.widgets.stack', true)
export('widgets', require 'src.widgets.state', true)
export('widgets', require 'src.widgets.text', true)
export('widgets', require 'src.widgets.tooltip', true)
export('widgets', require 'src.widgets.transform_box', true)
export('widgets', require 'src.widgets.visibility', true)
export('widgets', require 'src.widgets.widgets_binding', true)

---@class elxosc.mod.widgets :
--- elxosc.mod.src.widgets.align,
--- elxosc.mod.src.widgets.ambient,
--- elxosc.mod.src.widgets.app,
--- elxosc.mod.src.widgets.binding,
--- elxosc.mod.src.widgets.build_owner,
--- elxosc.mod.src.widgets.build_scope,
--- elxosc.mod.src.widgets.builder,
--- elxosc.mod.src.widgets.constraints,
--- elxosc.mod.src.widgets.container,
--- elxosc.mod.src.widgets.custom_paint,
--- elxosc.mod.src.widgets.decorated_box,
--- elxosc.mod.src.widgets.element,
--- elxosc.mod.src.widgets.flex,
--- elxosc.mod.src.widgets.framework,
--- elxosc.mod.src.widgets.gesture_detector,
--- elxosc.mod.src.widgets.hover_text,
--- elxosc.mod.src.widgets.icon,
--- elxosc.mod.src.widgets.key,
--- elxosc.mod.src.widgets.navigation,
--- elxosc.mod.src.widgets.offset_box,
--- elxosc.mod.src.widgets.overflow,
--- elxosc.mod.src.widgets.overlay,
--- elxosc.mod.src.widgets.padding,
--- elxosc.mod.src.widgets.positioned,
--- elxosc.mod.src.widgets.provider,
--- elxosc.mod.src.widgets.sized_box,
--- elxosc.mod.src.widgets.stack,
--- elxosc.mod.src.widgets.state,
--- elxosc.mod.src.widgets.text,
--- elxosc.mod.src.widgets.tooltip,
--- elxosc.mod.src.widgets.transform_box,
--- elxosc.mod.src.widgets.visibility,
--- elxosc.mod.src.widgets.widgets_binding
local M = exports.get('widgets')

return M
