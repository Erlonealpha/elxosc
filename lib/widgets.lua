-- Public layer members retain their direct-source identity.
---@namespace elxosc
---@using elxosc

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

---@class mod.widgets:
--- mod.src.widgets.align,
--- mod.src.widgets.ambient,
--- mod.src.widgets.app,
--- mod.src.widgets.binding,
--- mod.src.widgets.build_owner,
--- mod.src.widgets.build_scope,
--- mod.src.widgets.builder,
--- mod.src.widgets.constraints,
--- mod.src.widgets.container,
--- mod.src.widgets.custom_paint,
--- mod.src.widgets.decorated_box,
--- mod.src.widgets.element,
--- mod.src.widgets.flex,
--- mod.src.widgets.framework,
--- mod.src.widgets.gesture_detector,
--- mod.src.widgets.hover_text,
--- mod.src.widgets.icon,
--- mod.src.widgets.key,
--- mod.src.widgets.navigation,
--- mod.src.widgets.offset_box,
--- mod.src.widgets.overflow,
--- mod.src.widgets.overlay,
--- mod.src.widgets.padding,
--- mod.src.widgets.positioned,
--- mod.src.widgets.provider,
--- mod.src.widgets.sized_box,
--- mod.src.widgets.stack,
--- mod.src.widgets.state,
--- mod.src.widgets.text,
--- mod.src.widgets.tooltip,
--- mod.src.widgets.transform_box,
--- mod.src.widgets.visibility,
--- mod.src.widgets.widgets_binding
local M = exports.get('widgets')

return M
