-- Production and offline entry points share canonical source-module loading.
local F = require 'framework'
local modules_mod = require 'define.src.modules'
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
    local widget = require 'src.widgets'
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src/widgets/init.lua'), widget, 'explicit init shares aggregate')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src.widgets.init'), widget, 'dot init shares aggregate')
    F.eq(require('src.widgets.key').Key, keys.Key, 'local key class identity')
    F.eq(require('foundation').Key, keys.Key, 'library collector shares source class')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('src/foundation/init.lua'), require('foundation'), 'foundation init uses collector')
    F.eq(require('src.render'), require('render'), 'render init uses collector')
end)

F.test('every library layer exposes canonical members without mp', function()
    for _, name in ipairs({ 'foundation', 'painting', 'text', 'layout', 'render',
        'animation', 'scheduler', 'widgets', 'backends', 'material', 'player' }) do
        F.eq(type(require(name)), 'table', 'library entry: ' .. name)
    end
    F.eq(require('render').RenderStack, require('src.render.stack').RenderStack,
        'render member identity')
    F.eq(require('widgets').Text, require('src.widgets.text').Text,
        'widget member identity')
    F.eq(require('material').Slider, require('src.material.slider').Slider,
        'material uses canonical control')
    F.eq(rawget(require('material'), 'bind'), nil, 'material excludes registry helper')
end)

F.test('framework collectors do not attach registered source modules', function()
    local packages = require('host.package_catalog').collect()
    for _, name in ipairs({ 'foundation', 'painting', 'text', 'layout', 'render',
        'animation', 'scheduler', 'widgets', 'backends', 'material', 'player', 'define' }) do
        local exports = require(name)
        local attached = {}
        for _, package in ipairs(packages) do
            if package.name:sub(1, #name + 1) == name .. '.' then
                for key, value in pairs(exports) do
                    if value == package.exports then
                        attached[#attached + 1] = tostring(key) .. ' -> ' .. package.name
                    end
                end
            end
        end
        F.eq(#attached, 0, name .. ' attached modules: ' .. table.concat(attached, '; '))
    end
    F.eq(require('foundation').Anchor, require('src.foundation.anchor').Anchor,
        'named anchor values remain public')
    F.eq(require('animation').Curves, require('src.animation.curve').Curves,
        'named curve values remain public')
    F.eq(require('player').PlayerIcons, require('player.src.icon_map'), 'named player icon API retained')
    F.eq(rawget(require('define'), 'sandbox'), nil, 'Define does not attach its sandbox source table')
    F.eq(require('define').new_env, require('define.src.sandbox').new_env, 'sandbox members collected')
    F.eq(require('src.animation'), require('animation'), 'animation init is a one-way alias')
    F.eq(require('render').normalize_slider, require('src.render.slider').normalize, 'explicit helper alias')
    F.eq(rawget(require('material'), 'normalize'), nil, 'Material selects controls from numeric source modules')
end)

F.test('multi-level imports preserve protocol names and namespace protection', function()
    local registry = modules_mod.ModuleRegistry()
    host_define.install_modules(registry, require('player.src.context').PlayerStore())
    local session = require('define.src.session').DefineSession({ modules = registry })
    session:define_start()
    session:define('nested', [[
        stack = import_as('render.stack')
        slider = import_as('material.slider')
        render = import_as('render')
        widgets = import_as('widgets')
        material = import_as('material')
        player_context = import_as('player.context')
        painting = import_as('painting.canvas')
        export_tool = import_as('export')
        local organized = export_tool.new()
        organized.export('extension.controls', { Text = widgets.Text })
        organized_text = organized.get('extension.controls').Text
        import('render.stack')
        import('define.bind')
        same_stack = stack.RenderStack == RenderStack
        control = slider.Slider({ value = 0.5 })
    ]])
    local env = session:env_for('nested')
    F.ok(env.same_stack, 'flat and local imports share classes')
    F.eq(env.render.RenderStack, env.stack.RenderStack, 'integrated and source import member identity')
    F.eq(env.material.Slider, env.slider.Slider, 'integrated material import member identity')
    F.eq(env.material.Text, env.widgets.Text, 'material reexports basic widgets')
    F.eq(env.render.stack, nil, 'render import does not attach the stack module')
    F.eq(env.widgets.widgets, nil, 'widget import does not attach the controls module')
    F.eq(env.control.__class, require('src.material.slider').Slider,
        'deep package constructs canonical widget')
    F.eq(env.organized_text, require('widgets').Text, 'framework export tool available to extensions')
    F.eq(env.player_context.PlayerStore, require('player.src.context').PlayerStore, 'canonical context package')
    F.eq(env.painting.Canvas, require('src.painting.canvas').Canvas, 'lower-level framework import')
    F.eq(env.Canvas, nil, 'local imports do not inject environment fields')
    F.raises(function() registry:import_as('player_context', 'nested') end, 'ImportError', 'legacy context name removed')
    F.eq(env.bind, session.api.bind, 'deep import retains Define bind')
    F.raises(function() registry:publish('render.stack', {}) end, 'protected', 'registered child')
    F.raises(function() registry:publish('render.unregistered', {}) end, 'protected', 'protected parent')
    F.raises(function() registry:import_as('render.missing', 'nested') end, 'ImportError', 'unknown child')
    F.raises(function() registry:import_as('render.stack.RenderStack', 'nested') end,
        'ImportError', 'module resolution does not traverse arbitrary export fields')
end)

F.test('flat widget and material collectors preserve owning members and boundaries', function()
    local widgets = require 'widgets'
    local material = require 'material'
    F.eq(require('src.widgets'), widgets, 'widget source alias uses collector')
    F.eq(require('src.material'), material, 'material source alias uses collector')
    for name, member in pairs(widgets) do
        F.eq(material[name], member, 'material reexport: ' .. name)
    end
    for _, name in ipairs({ 'Theme', 'ThemeData', 'Button', 'ButtonBase', 'ButtonStyle',
        'ElevatedButton', 'OutlinedButton', 'TextButton', 'IconButton', 'Slider', 'LinearProgressIndicator' }) do
        F.eq(rawget(widgets, name), nil, 'base widgets exclude ' .. name)
        F.ok(rawget(material, name) ~= nil, 'material owns ' .. name)
    end
    local registry = modules_mod.ModuleRegistry()
    host_define.install_modules(registry, require('player.src.context').PlayerStore())
    ---@type elxosc.mod.src.widgets.framework
    local framework = registry:import_as('widgets.framework', 'consumer')
    ---@type elxosc.mod.src.material.theme
    local theme = registry:import_as('material.theme', 'consumer')
    ---@type elxosc.mod.src.material.icons
    local icons = registry:import_as('material.icons', 'consumer')
    F.eq(framework.Widget, widgets.Widget, 'runtime subpackage')
    F.eq(theme.Theme, material.Theme, 'theme subpackage')
    F.eq(icons.MaterialSymbols, material.MaterialSymbols, 'font resource identity')
    for _, name in ipairs({ 'widget', 'widget.widgets', 'widget.widgets.slider' }) do
        F.raises(function() registry:import_as(name, 'consumer') end, 'ImportError', 'removed package ' .. name)
    end
end)

F.test('static Define collector imports preserve protocol publication and retry behavior', function()
    local registry = modules_mod.ModuleRegistry()
    host_define.install_modules(registry, require('player.src.context').PlayerStore())
    local session = require('define.src.session').DefineSession({ modules = registry })
    local protocol = session.api.bind
    session:define_start()
    F.raises(function() session:define('organized', [[
        import('define')
        local organizer = import_as('export').new()
        organizer.export('organized.controls', { marker = false, Text = import_as('widgets.text').Text })
        local packages = organizer.collect()
        mod(packages[1].name, packages[1].exports)
        mod('render.forbidden', {})
    ]]) end, 'protected', 'failed organization payload')
    F.eq(registry:has('organized.controls'), false, 'failed payload does not publish organized descriptors')
    session:define('organized', [[
        import('define')
        local organizer = import_as('export').new()
        organizer.export('organized.controls', { marker = false, Text = import_as('widgets.text').Text })
        local packages = organizer.collect()
        mod(packages[1].name, packages[1].exports)
        local_controls = import_as('organized.controls')
        bind('slot', local_controls.Text('organized'))
    ]])
    local env = session:env_for('organized')
    F.eq(env.bind, protocol, 'collector import keeps scope-aware bind')
    F.eq(env.mod, session.api.mod, 'collector import keeps transaction-aware publication')
    F.eq(env.local_controls.marker, false, 'organized false export imported')
    F.eq(env.local_controls.Text, require('widgets').Text, 'organized class identity')
    F.eq(env.Text, nil, 'local import does not inject Text')
    F.ok(registry:has('organized.controls'), 'successful retry publishes through mod')
end)

F.test('application packages share canonical classes and stay outside framework collectors', function()
    local player = require 'player'
    local define = require 'define'
    local widget = require 'widgets'
    F.eq(player.Main, require('player.src.app').Main, 'player root Main identity')
    F.eq(player.PlayerMain, player.Main, 'player naming alias identity')
    F.eq(player.PlayerStore, require('player.src.context').PlayerStore, 'player Store identity')
    F.eq(define.SlotSpec, require('define.src.slot').SlotSpec, 'Define Slot identity')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('player/src/context.lua'), require('player.src.context'), 'player slash alias')
    ---@diagnostic disable-next-line: unresolved-require
    F.eq(require('define/src/slot.lua'), require('define.src.slot'), 'Define slash alias')
    for _, name in ipairs({ 'PlayerStore', 'HostActions', 'AutoHide', 'Timeline', 'SlotSpec',
        'SlotWrap', 'new_widget', 'new_state', 'bind' }) do
        F.eq(rawget(widget, name), nil, 'framework excludes ' .. name)
        F.eq(rawget(require('material'), name), nil, 'material excludes ' .. name)
    end
    local count = 0
    for _ in pairs(host_define.builtins()) do
        count = count + 1
    end
    F.eq(count, 115, 'explicit default builtin field count remains stable')
end)
