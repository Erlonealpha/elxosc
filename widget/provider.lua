-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Small provider helpers built on top of `InheritedWidget`.
--
-- `of`/`maybe_of` are listening lookups and return the Provider Widget itself.
-- `read`/`maybe_read` are non-listening lookups. This is deliberately a small
-- InheritedWidget API, not a compatibility implementation of package:provider.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local raise = std.raise
local InheritedWidget = widget_mod.InheritedWidget

local M = {}

---@class _ProviderOptions
---@field child Widget?
---@field key any?

---@class Provider : InheritedWidget
---@field child Widget?
---@field key any?
---@overload fun(options: _ProviderOptions?): self
local Provider = std.class.new('Provider', { InheritedWidget })

function Provider:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
end

---@param context BuildContext|std.Class
---@param provider_class std.Class|BuildContext?
---@return Provider?
function Provider.maybe_of(context, provider_class)
    ---@type BuildContext
    local target_context
    ---@type std.Class?
    local target_class
    if std.kindof(context, 'class') then
        target_context = provider_class --[[@as BuildContext]]
        target_class = context --[[@as std.Class]]
    else
        target_context = context --[[@as BuildContext]]
        target_class = provider_class --[[@as std.Class?]]
    end
    if target_context == nil
        or type(target_context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError('Provider lookup expects a BuildContext'))
    end
    target_class = target_class or Provider
    if not std.kindof(target_class, 'class') then
        raise(std.TypeError('Provider lookup expects a provider class'))
    end
    return target_context:depend_on_inherited_widget_of_exact_type(target_class) --[[@as Provider?]]
end

---@param context BuildContext|std.Class
---@param provider_class std.Class|BuildContext?
---@return Provider?
function Provider.maybe_read(context, provider_class)
    local target_context, target_class
    if std.kindof(context, 'class') then
        target_context = provider_class --[[@as BuildContext]]
        target_class = context --[[@as std.Class]]
    else
        target_context = context --[[@as BuildContext]]
        target_class = provider_class --[[@as std.Class?]]
    end
    if target_context == nil
        or type(target_context.get_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError('Provider lookup expects a BuildContext'))
    end
    target_class = target_class or Provider
    if not std.kindof(target_class, 'class') then
        raise(std.TypeError('Provider lookup expects a provider class'))
    end
    return target_context:get_inherited_widget_of_exact_type(target_class) --[[@as Provider?]]
end

---@param context BuildContext|std.Class
---@param provider_class std.Class|BuildContext?
---@return Provider
function Provider.of(context, provider_class)
    local target_class = provider_class
    if std.kindof(context, 'class') then
        target_class = context
    end
    local provider = Provider.maybe_of(context, provider_class)
    if not provider then
        raise(std.RuntimeError(string.format(
            'no %s ancestor was found', tostring(target_class or Provider))))
    end
    return provider
end

---@param context BuildContext|std.Class
---@param provider_class std.Class|BuildContext?
---@return Provider
function Provider.read(context, provider_class)
    local target_class = provider_class
    if std.kindof(context, 'class') then
        target_class = context
    end
    local provider = Provider.maybe_read(context, provider_class)
    if not provider then
        raise(std.RuntimeError(string.format(
            'no %s ancestor was found', tostring(target_class or Provider))))
    end
    return provider
end

M.Provider = Provider

return M
