-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Compatibility aggregate. Definitions live in one module per widget family so
-- direct imports and this legacy entry point always share class identity.
---@diagnostic disable: missing-fields
---@class elxwidgets_layout
---@field Padding table
---@field Align table
---@field Center fun(child: Widget?, options: table?): Widget
---@field SizedBox table
---@field DecoratedBox table
---@field Flexible table
---@field Expanded fun(child: Widget?, options: table?): Widget
---@field Spacer fun(options: table?): Widget
---@field Flex table
---@field Row fun(options: table?): Widget
---@field Column fun(options: table?): Widget
---@field Stack table
---@field ConstrainedBox table
---@field LimitedBox table
---@field UnconstrainedBox table
---@field OverflowBox table
---@field FittedBox table
---@field Container table
local modules = {
    require 'widget.widgets.padding', require 'widget.widgets.align', require 'widget.widgets.sized_box',
    require 'widget.widgets.decorated_box', require 'widget.widgets.flex', require 'widget.widgets.stack',
    require 'widget.widgets.constraints', require 'widget.widgets.overflow', require 'widget.widgets.container',
}
---@type elxwidgets_layout
local M = {}
for _, module in ipairs(modules) do
    for name, value in pairs(module) do M[name] = value end
end
return M
