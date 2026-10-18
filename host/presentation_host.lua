-- Physical presentation adapter for the host-independent logical Overlay.
--
-- OverlayHost owns the actual shared frame/input pipeline.  This module gives
-- that implementation the Stage 6 vocabulary and the Stage 8 plan adapter
-- without exposing numeric ASS z values to logical or Define callers.

local std = require 'elxlibs.std'
local overlay_host_mod = require 'host.overlay_host'
local overlay_mod = require 'player.overlay'
local layout_widgets = require 'widget.widgets.layout'

local raise = std.raise
local OverlayHost = overlay_host_mod.OverlayHost
local OverlayEntry = overlay_mod.OverlayEntry
local Overlay = overlay_mod.Overlay
local Stack = layout_widgets.Stack
local SizedBox = layout_widgets.SizedBox

local M = {}

---@alias PresentationSurfaceName
--- | 'default'
--- | 'extension'
--- | 'popup'
--- | 'system'

local POLICY_TO_ID = {
    default = 'default',
    extension = 'extension',
    popup = 'popup',
    system = 'system',
}

local INPUT_RANK = {
    passive = 1,
    interactive = 2,
    exclusive = 3,
}

---@param value any
---@return boolean
local function is_widget(value)
    return type(value) == 'table' and type(value.create_element) == 'function'
end

---@param children Widget[]
---@return Widget
local function combine(children)
    if #children == 1 then
        return children[1]
    end
    return Stack({ children = children })
end

---@param plan PresentationPlan
---@return table<string, LayerRecord>
function OverlayHost:apply_presentation_plan(plan)
    if type(plan) ~= 'table' or type(plan.entries) ~= 'table' then
        raise(std.TypeError('PresentationPlan must contain an entries array'))
    end

    local grouped = {}
    for policy in pairs(POLICY_TO_ID) do
        grouped[policy] = {
            children = {},
            input_policy = 'passive',
            opaque = false,
            visible = false,
        }
    end

    for _, record in ipairs(plan.entries) do
        local policy = record.surface_policy
        local group = grouped[policy]
        if group == nil then
            raise(std.ValueError('unknown presentation surface policy: ' .. tostring(policy)))
        end
        if record.visible then
            group.visible = true
        end
        if record.opaque and record.paintable then
            group.opaque = true
        end
        if record.input_active and INPUT_RANK[record.input_policy]
            > INPUT_RANK[group.input_policy] then
            group.input_policy = record.input_policy
        end
        local child = record.entry and record.entry.child
        if record.paintable and is_widget(child) then
            group.children[#group.children + 1] = child
        end
    end

    local result = {}
    local active_ids = {}
    for policy, group in pairs(grouped) do
        if group.visible and (#group.children > 0 or group.input_policy == 'exclusive') then
            local id = POLICY_TO_ID[policy]
            local root = #group.children > 0 and combine(group.children) or SizedBox.expand()
            local options = {
                surface_policy = policy,
                input_policy = group.input_policy,
                opaque = group.opaque,
                visible = true,
            }
            local surface = self.registry:get(id)
            if surface then
                surface = self:update_surface(id, root, options)
            else
                surface = self:create_surface(id, root, options)
            end
            result[id] = surface
            active_ids[id] = true
        end
    end

    for _, id in ipairs(self._plan_surface_ids or {}) do
        if not active_ids[id] then
            self:remove_surface(id)
        end
    end
    self._plan_surface_ids = {}
    for id in pairs(active_ids) do
        self._plan_surface_ids[#self._plan_surface_ids + 1] = id
    end
    self._presentation_plan_generation = plan.generation
    return result
end

---@param declarations OverlayDeclaration[]|{ contributions: OverlayDeclaration[] }
---@return table<string, LayerRecord>
function OverlayHost:mount_declarations_as_plan(declarations)
    local entries = declarations
    if declarations and declarations.contributions then
        entries = declarations.contributions
    end
    local overlay = Overlay()
    for _, declaration in ipairs(entries or {}) do
        local policy = declaration.options.z_policy == 'popup' and 'popup' or 'extension'
        overlay:insert(OverlayEntry({
            key = declaration.id,
            child = declaration.root_widget,
            kind = policy == 'popup' and 'popup' or 'extension',
            surface_policy = policy,
            input_policy = declaration.options.input_policy or 'interactive',
            opaque = declaration.options.opaque == true,
            maintain_state = declaration.options.keep_alive ~= false,
            visible = declaration.options.visible ~= false,
        }))
    end
    return self:apply_presentation_plan(overlay:plan())
end

M.PresentationHost = OverlayHost
M.PresentationSurface = overlay_host_mod.PresentationSurface
M.RegionSnapshot = overlay_host_mod.RegionSnapshot
M.OverlayInputRouter = overlay_host_mod.OverlayInputRouter
M.Z_POLICIES = overlay_host_mod.Z_POLICIES

return M
