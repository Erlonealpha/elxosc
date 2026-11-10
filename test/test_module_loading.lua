-- Production and offline entry points share canonical source-module loading.
local F = require 'framework'
local modules_mod = require 'extension.modules'
local mp_stub = require 'mp_stub'
mp_stub.install()
local host_define = require 'host.mpv_define'

F.section('modules: library layout and source aliases')

F.test('source path spellings reuse modules and canonical classes', function()
    local keys = require 'src.foundation.key'
    -- EmmyLua's file resolver does not run the custom Lua package searcher.
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src/foundation/key.lua'), keys, 'slash and suffix share module table')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src.foundation.key.lua'), keys, 'dot suffix shares module table')
    local widget = require 'src.widget'
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src/widget/init.lua'), widget, 'explicit init shares aggregate')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src.widget.init'), widget, 'dot init shares aggregate')
    F.eq(require('src.widget.key').Key, keys.Key, 'local key class identity')
    F.eq(require('foundation').key, keys, 'library collector shares source module')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src/foundation/init.lua'), require('foundation'), 'foundation init uses collector')
    F.eq(require('src.render'), require('render'), 'render init uses collector')
end)

F.test('every library layer exposes canonical source namespaces without mp', function()
    for _, name in ipairs({ 'foundation', 'painting', 'text', 'layout', 'render',
        'animation', 'scheduler', 'widget', 'backends', 'material', 'player' }) do
        F.eq(type(require(name)), 'table', 'library entry: ' .. name)
    end
    F.eq(require('render').stack, require('src.render.stack'), 'render submodule identity')
    F.eq(require('widget').widgets.slider, require('src.widget.widgets.slider'),
        'deep namespace identity')
    F.eq(require('material').Slider, require('src.widget.widgets.slider').Slider,
        'material uses canonical control')
    F.eq(rawget(require('material'), 'bind'), nil, 'material excludes registry helper')
end)

F.test('multi-level imports preserve protocol names and namespace protection', function()
    local registry = modules_mod.ModuleRegistry()
    host_define.install_modules(registry, require('src.widget.player_context').PlayerStore())
    local session = require('extension.define').DefineSession({ modules = registry })
    session:define_start()
    session:define('nested', [[
        stack = import_as('render.stack')
        slider = import_as('widget.widgets.slider')
        import('render.stack')
        import('widget.bind')
        same_stack = stack.RenderStack == RenderStack
        control = slider.Slider({ value = 0.5 })
    ]])
    local env = session:env_for('nested')
    F.ok(env.same_stack, 'flat and local imports share classes')
    F.eq(env.control.__class, require('src.widget.widgets.slider').Slider,
        'deep package constructs canonical widget')
    F.eq(env.bind, session.api.bind, 'deep import retains Define bind')
    F.raises(function() registry:publish('render.stack', {}) end, 'protected', 'registered child')
    F.raises(function() registry:publish('render.unregistered', {}) end, 'protected', 'protected parent')
    F.raises(function() registry:import_as('render.missing', 'nested') end, 'ImportError', 'unknown child')
    F.raises(function() registry:import_as('render.stack.RenderStack', 'nested') end,
        'ImportError', 'module resolution does not traverse arbitrary export fields')
end)
