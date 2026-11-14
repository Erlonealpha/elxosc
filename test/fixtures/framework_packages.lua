-- Runs in a staged tree containing only lib and the independent elxlib.
local framework_root, dependency_root = ...
package.path = dependency_root .. '/?.lua;' .. dependency_root .. '/?/init.lua;' .. package.path
assert(loadfile(framework_root .. '/lib/module_loader.lua'))().install(framework_root)

local original_require = require
function require(name)
    assert(not name:match('^mp[%.]?') and not name:match('^host%.')
        and not name:match('^player[%.]?') and not name:match('^define[%.]?'),
        'framework attempted application import: ' .. name)
    return original_require(name)
end

for _, name in ipairs({ 'foundation', 'painting', 'text', 'layout', 'render',
    'animation', 'scheduler', 'widget', 'material', 'backends' }) do
    assert(type(require(name)) == 'table', 'framework collector ' .. name)
end

local widget = require 'widget'
local geometry = require 'foundation'
local Constraints = require('layout').Constraints
local canvas = require('backends').RecordCanvas()
require('src.text.text_layout').set_default(require('backends').AssTextLayout())
local clicks = 0
local tree = widget.WidgetsBinding.ensure_initialized():attach(widget.WidgetsApp({
    child = widget.GestureDetector(widget.SizedBox({
        width = 100, height = 20, child = widget.Text('framework'),
    }), {
        on_tap = function()
            clicks = clicks + 1
        end,
    }),
}))
tree.render_owner:set_viewport(Constraints.tight(100, 20))
tree:flush_build()
tree.render_owner:layout()
tree.render_owner:paint(canvas)
assert(canvas:count('draw_text') > 0, 'framework painting')
assert(assert(tree.render_owner.root).size.width == 100, 'finite framework layout')
tree.render_owner:dispatch_pointer('down', geometry.Offset(50, 10), 'left')
tree.render_owner:dispatch_pointer('up', geometry.Offset(50, 10), 'left')
assert(clicks == 1, 'framework input')
tree:dispose()
assert(tree.render_owner.root == nil, 'framework teardown')
print('framework mount/paint/input/dispose passed')
