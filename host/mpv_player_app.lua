-- Explicit player assembly; generic App owns the runtime and its cleanup hook.
---@namespace elxosc
---@using elxosc
---@using elxosc.host

local std = require 'elxlibs.std'
local mpv_app = require 'host.mpv_app'
local player_ambients = require 'player.src.ambients'
local player_context = require 'player.src.context'
local material_theme = require 'src.material.theme'
local player_theme = require 'player.src.theme'
local mpv_actions = require 'host.mpv_actions'

local ipairs = ipairs
local type = type
local pcall = pcall
local error = error
local App = mpv_app.App
local PlayerApp = player_ambients.PlayerApp
local PlayerScope = player_context.PlayerScope
local ThemeData = material_theme.ThemeData
local PlayerThemeData = player_theme.PlayerThemeData

---@class mod.host.mpv_player_app
local M = {}

---@class host._PlayerHostAppOptions
---@field z                  number?
---@field delay              number?
---@field player_store       player.PlayerStore?
---@field player_context     MpPlayerContext?
---@field theme              material.ThemeData?
---@field player_theme       player.PlayerThemeData?
---@field actions            player.HostActions?
---@field default_text_style TextStyle?

---@class host.PlayerHostApp: host.App
---@field player_store    player.PlayerStore?
---@field player_context  MpPlayerContext?
---@field theme           material.ThemeData
---@field player_theme    player.PlayerThemeData
---@field actions         player.HostActions
---@field _activity_cache _TreeQueryCache?
---@overload fun(root_widget: Widget, options?: _PlayerHostAppOptions): self
local PlayerHostApp = std.class.new('PlayerHostApp', App)

-- Input activity is a player policy, kept outside the generic frame owner.
---@param app      PlayerHostApp
---@param x        number?
---@param y        number?
---@param viewport Rect?
local function notify_activity(app, x, y, viewport)
    local root = app.binding and app.binding.root_element
    local cache = app._activity_cache
    if cache == nil then
        cache = {}
        app._activity_cache = cache
        if app.binding then
            app.binding.build_owner:_register_tree_cache(cache)
        end
    end
    if cache.value == nil or root ~= cache.value.root then
        local elements = {}
        local function visit(element)
            if element.state then
                elements[#elements + 1] = element.state
            end
            for _, child in ipairs(element:element_children()) do
                visit(child)
            end
        end
        if root then
            visit(root)
        end
        cache.value = { root = root, elements = elements }
    end
    for _, state in ipairs(cache.value.elements) do
        if state and type(state.notify_activity) == 'function' then
            state:notify_activity(x, y, viewport)
        end
    end
end

---@param root_widget Widget
---@param options     _PlayerHostAppOptions?
function PlayerHostApp:__init(root_widget, options)
    options = options or {}
    local default_text_style = options.default_text_style
    self.player_store = options.player_store
    self.player_context = options.player_context
    self.theme = options.theme or ThemeData()
    self.player_theme = options.player_theme or PlayerThemeData()
    local context = self.player_context

    local disposed = false
    local function dispose()
        if disposed then
            return
        end
        disposed = true
        self._activity_cache = nil
        if context then
            context:dispose()
        end
    end

    local ok, err = pcall(function ()
        self.actions = options.actions or mpv_actions.default({ player_context = context })
        if context then
            context:observe_default_properties({ batch = true })
            context:observe_thumbfast()
            context:observe_yt_dlp()
            context:observe_sponsorblock()
        end
        App.__init(self, root_widget, {
            z = options.z,
            delay = options.delay,
            on_dispose = dispose,
            on_activity = notify_activity,
            root_wrapper = function (root, display)
                return PlayerApp({
                    theme = self.theme,
                    player_theme = self.player_theme,
                    display = display,
                    default_text_style = default_text_style,
                    actions = self.actions,
                    child = self.player_store and PlayerScope({ store = self.player_store, child = root }) or root
                })
            end
        })
    end)
    if not ok then
        pcall(dispose)
        error(err, 0)
    end
end

---@param build   fun(): Widget
---@param options _PlayerHostAppOptions?
---@return PlayerHostApp
function M.start(build, options)
    local ok, root = pcall(build)
    if not ok then
        if options and options.player_context then
            pcall(options.player_context.dispose, options.player_context)
        end
        error(root, 0)
    end
    local app = PlayerHostApp(root, options)
    local started, err = pcall(app.request_frame, app)
    if not started then
        pcall(app.shutdown, app)
        error(err, 0)
    end
    return app
end

M.PlayerHostApp = PlayerHostApp

return M
