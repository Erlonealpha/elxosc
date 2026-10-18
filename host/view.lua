-- Host-side view handle for mounting one application root into an OverlayHost.

local std = require 'elxlibs.std'

local raise = std.raise
local M = {}

---@class ViewOptions : OverlayLayerOptions
---@field id string?
---@field z_policy OverlayZPolicy?
---@field input_policy OverlayInputPolicy?
---@field visible boolean?
---@field opaque boolean?
---@field keep_alive boolean?
---@field binds BindRegistry?
---@field player_store PlayerStore?

---@class View : std.object
---@field host OverlayHost
---@field layer_id string
---@field layer LayerRecord
---@field root_widget Widget
---@field options ViewOptions
---@overload fun(host: OverlayHost, root_widget: Widget, options?: ViewOptions): self
local View = std.class.new('View', {})

function View:__init(host, root_widget, options)
    if type(host) ~= 'table' or type(host.create) ~= 'function' then
        raise(std.TypeError('View.host must be an OverlayHost'))
    end
    if type(root_widget) ~= 'table' or type(root_widget.create_element) ~= 'function' then
        raise(std.TypeError('View.root_widget must be a Widget'))
    end
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('View options must be a table'))
    end
    self.host = host
    self.root_widget = root_widget
    self.options = {}
    for name, value in pairs(options) do
        self.options[name] = value
    end
    self.layer_id = options.id or 'main'
    self.layer = host:create(self.layer_id, root_widget, options)
end

---@param root_widget Widget
function View:set_root_widget(root_widget)
    if type(root_widget) ~= 'table' or type(root_widget.create_element) ~= 'function' then
        raise(std.TypeError('View.root_widget must be a Widget'))
    end
    self.root_widget = root_widget
    local layer = self.host:update(self.layer_id, root_widget, self.options)
    if layer == nil then
        raise(std.RuntimeError('View layer has been removed: ' .. self.layer_id))
    end
    self.layer = layer
end

---@return boolean
function View:remove()
    return self.host:remove(self.layer_id)
end

M.View = View

return M
