-- Host-independent display ambient for layout and placement decisions.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local provider_mod = require 'widget.provider'

local raise = std.raise
local InheritedWidget = widget_mod.InheritedWidget
local Provider = provider_mod.Provider

local M = {}

local function finite_non_negative(name, value)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge or value < 0 then
        raise(std.ValueError('DisplaySnapshot.' .. name .. ' must be finite and non-negative'))
    end
    return value
end

---@class _DisplaySnapshotOptions
---@field width number
---@field height number
---@field initialized boolean?
---@field generation integer?
---@field coordinate_space 'osd'?

---@class DisplaySnapshot : std.object
---@field width number
---@field height number
---@field initialized boolean
---@field generation integer
---@field coordinate_space 'osd'
---@overload fun(options: _DisplaySnapshotOptions): self
local DisplaySnapshot = std.class.new('DisplaySnapshot', {})

function DisplaySnapshot:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('DisplaySnapshot expects an options table'))
    end
    local generation = options.generation or 0
    if type(generation) ~= 'number' or generation ~= math.floor(generation) or generation < 0 then
        raise(std.ValueError('DisplaySnapshot.generation must be a non-negative integer'))
    end
    if options.initialized ~= nil and type(options.initialized) ~= 'boolean' then
        raise(std.TypeError('DisplaySnapshot.initialized must be a boolean'))
    end
    if options.coordinate_space ~= nil and options.coordinate_space ~= 'osd' then
        raise(std.ValueError("DisplaySnapshot.coordinate_space must be 'osd'"))
    end
    self.width = finite_non_negative('width', options.width or 0)
    self.height = finite_non_negative('height', options.height or 0)
    self.initialized = options.initialized == true
    self.generation = generation
    self.coordinate_space = 'osd'
end

---@param options _DisplaySnapshotOptions?
---@return DisplaySnapshot
function DisplaySnapshot:copy(options)
    options = options or {}
    return DisplaySnapshot({
        width = options.width == nil and self.width or options.width,
        height = options.height == nil and self.height or options.height,
        initialized = options.initialized == nil and self.initialized or options.initialized,
        generation = options.generation == nil and self.generation or options.generation,
        coordinate_space = 'osd',
    })
end

---@class _DisplayScopeOptions
---@field snapshot DisplaySnapshot
---@field child Widget?
---@field key any?

---@class DisplayScope : InheritedWidget
---@field snapshot DisplaySnapshot
---@field child Widget?
---@overload fun(options: _DisplayScopeOptions): self
local DisplayScope = std.class.new('DisplayScope', { InheritedWidget })

function DisplayScope:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('DisplayScope expects an options table'))
    end
    if not std.isinstance(options.snapshot, DisplaySnapshot) then
        raise(std.TypeError('DisplayScope.snapshot must be a DisplaySnapshot'))
    end
    self.key = options.key
    self.snapshot = options.snapshot
    self.child = options.child
end

---@param context BuildContext
---@return DisplayScope
function DisplayScope.of(context)
    return Provider.of(context, DisplayScope --[[@as std.Class]]) --[[@as DisplayScope]]
end

---@param context BuildContext
---@return DisplayScope?
function DisplayScope.maybe_of(context)
    return Provider.maybe_of(context, DisplayScope --[[@as std.Class]]) --[[@as DisplayScope?]]
end

---@param context BuildContext
---@return DisplayScope
function DisplayScope.read(context)
    return Provider.read(context, DisplayScope --[[@as std.Class]]) --[[@as DisplayScope]]
end

---@param context BuildContext
---@return DisplayScope?
function DisplayScope.maybe_read(context)
    return Provider.maybe_read(context, DisplayScope --[[@as std.Class]]) --[[@as DisplayScope?]]
end

---@param context BuildContext
---@return DisplaySnapshot
function DisplayScope.snapshot_of(context)
    return DisplayScope.of(context).snapshot
end

---@param old_widget InheritedWidget
---@return boolean
function DisplayScope:update_should_notify(old_widget)
    return self.snapshot ~= old_widget.snapshot
end

M.DisplaySnapshot = DisplaySnapshot
M.DisplayScope = DisplayScope

return M
