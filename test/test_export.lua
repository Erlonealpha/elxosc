-- Static export organization has no Define scope or transaction dependencies.
local F = require 'framework'
local export_mod = require 'export'

F.section('export: source selection and publication')

F.test('raw shallow snapshots preserve false, sparse keys and value identities', function()
    local exports = export_mod.new()
    local nested = {}
    local callback = function() end
    local class = require('src.widgets.framework').Widget
    local metatable = {
        __index = { inherited = 1 },
        __pairs = function()
            error('export must not consult __pairs')
        end,
    }
    local source = setmetatable({ flag = false, nested = nested, callback = callback,
        Widget = class, [1] = 'first', [4] = 'fourth', [-2] = 'negative', [0] = 'zero' }, metatable)
    exports.export('values', source)
    source.flag = true
    source.later = 2
    source[4] = 'changed'
    local values = exports.get('values')
    F.eq(values.flag, false, 'false captured at declaration time')
    F.eq(values[4], 'fourth', 'sparse key captured without renumbering')
    F.eq(values[2], nil, 'sparse gap retained')
    F.eq(values[-2], 'negative', 'negative integer key')
    F.eq(values[0], 'zero', 'zero integer key')
    F.eq(values.nested, nested, 'nested identity')
    F.eq(values.callback, callback, 'function identity')
    F.eq(values.Widget, class, 'class identity')
    F.eq(values.inherited, nil, 'no __index exports')
    F.eq(values.later, nil, 'snapshot does not read later additions')
    F.eq(getmetatable(values), nil, 'ordinary output table')
    F.eq(getmetatable(source), metatable, 'source metatable unchanged')
    F.eq(source.later, 2, 'source remains caller owned')
    local keys, first = 0, nil
    for _ in next, values do
        keys = keys + 1
    end
    for _, value in ipairs(values) do
        first = value
    end
    F.eq(keys, 8, 'next enumerates own members')
    F.eq(first, 'first', 'ipairs stops at the original gap')
end)

F.test('selection applies once to its own source and handles survive other declarations', function()
    local exports = export_mod.new()
    local first = { shared = 1, retained = false }
    exports.export('controls', first)
    local handle = exports.export('controls', { shared = 2, selected = 3 }, true)
    exports.export('other', { unrelated = 4 })
    handle.hide('shared')
    local another = exports.export('controls', { excluded = 5, shown = false, [3] = 'third' }, true)
    another.show('shown', 3)
    local values = exports.get('controls')
    F.eq(values.shared, 1, 'hide cannot remove an earlier source')
    F.eq(values.retained, false, 'earlier false member retained')
    F.eq(values.selected, 3, 'hide keeps the other own member')
    F.eq(values.shown, false, 'show can select false')
    F.eq(values[3], 'third', 'show selects sparse integer key')
    F.eq(values.excluded, nil, 'show excludes other own keys')
    F.eq(first.shared, 1, 'filter does not mutate input')
    F.raises(function() another.hide('shown') end, 'RuntimeError', 'second selection after publication')

    local pending = export_mod.new()
    local selected = pending.export('pending', { a = 1 }).show('a')
    F.raises(function() selected.hide('a') end, 'RuntimeError', 'one selection per source')
end)

F.test('empty filters and sources preserve their defined semantics', function()
    local exports = export_mod.new()
    exports.export('empty', {})
    exports.export('show', { value = 1 }).show()
    exports.export('hide', { value = false }).hide()
    F.eq(next(exports.get('empty')), nil, 'empty source')
    F.eq(next(exports.get('show')), nil, 'empty show selects nothing')
    F.eq(exports.get('hide').value, false, 'empty hide keeps everything')
end)

F.test('selection failures leave the source available for a valid filter', function()
    local exports = export_mod.new()
    local selected = exports.export('selection', { a = false, [2] = 'second' })
    -- Deliberately invalid inputs exercise runtime validation beyond the typed API.
    local show = selected.show
    local show_invalid = show --[[@as fun(...: any): any]]
    for _, keys in ipairs({ { 'missing' }, { 'a', 'a' }, { 2, 2 }, { 1.5 }, { true } }) do
        F.raises(function() show_invalid(unpack(keys)) end, 'ValueError', 'invalid filter')
    end
    F.raises(function() show_invalid(nil) end, 'ValueError', 'nil filter is not an empty call')
    F.raises(function() show_invalid(0 / 0) end, 'ValueError', 'NaN is not a selection key')
    show('a')
    F.eq(exports.get('selection').a, false, 'valid filter after failures')
end)

F.test('raw same-value deduplication does not use equality metamethods', function()
    local exports = export_mod.new()
    local nested, callback = {}, function() end
    exports.export('same', { nested = nested, callback = callback, flag = false, number = 1, [3] = 'sparse' })
    exports.export('same', { nested = nested, callback = callback, flag = false, number = 1, [3] = 'sparse' }, true)
    F.eq(exports.get('same').nested, nested, 'same table deduplicates')
    F.eq(exports.get('same')[3], 'sparse', 'same array member deduplicates')
    local metatable = { __eq = function() return true end }
    local a, b = setmetatable({}, metatable), setmetatable({}, metatable)
    exports.export('different', { value = a })
    exports.export('different', { value = b }, true)
    F.raises(function() exports.get('different') end,
        "package 'different' key 'value' conflicts between sources 1 and 2", 'raw conflict detail')
    exports.export('different', { value = a })
    F.eq(exports.get('different').value, a, 'failed get did not seal the package')
    exports.export('array', { [1] = 'a' })
    exports.export('array', { [1] = 'b' }, true)
    F.raises(function() exports.get('array') end, 'ValueError', 'arrays do not concatenate')
end)

F.test('collect validates all pending packages atomically and preserves published ones', function()
    local exports = export_mod.new()
    exports.export('published', { stable = true })
    local published = exports.get('published')
    local good = exports.export('good', { a = 1, b = 2 })
    exports.export('bad', { value = 1 })
    exports.export('bad', { value = 2 }, true)
    F.raises(function() exports.collect() end, 'ValueError', 'collect fails for conflict')
    good.show('a')
    exports.export('bad', { value = 3 })
    exports.export('good', { c = 4 }, true)
    local packages = exports.collect()
    local stable, valid, fixed = assert(packages[1]), assert(packages[2]), assert(packages[3])
    F.eq(stable.exports, published, 'published identity survives failure')
    F.eq(valid.exports.a, 1, 'valid pending filter survived failure')
    F.eq(valid.exports.b, nil, 'good was not prematurely sealed')
    F.eq(valid.exports.c, 4, 'append allowed after failed collect')
    F.eq(fixed.exports.value, 3, 'bad was not sealed')
end)

F.test('first declaration order, replacement, aliases and repeated collection are stable', function()
    local exports = export_mod.new()
    local a, b = {}, {}
    local stale = exports.export('first', { old = a })
    exports.export('second', { b = b })
    exports.export('first', { replacement = a })
    F.raises(function() stale.show('old') end, 'RuntimeError', 'replaced source handle is stale')
    exports.export('first', { alias = a }, true)
    local values = exports.get('first')
    F.eq(values.old, nil, 'default operation replaces whole package')
    F.eq(values.alias, values.replacement, 'explicit alias shares value')
    local first, second = exports.collect(), exports.collect()
    local first_package, second_package = assert(first[1]), assert(second[1])
    F.eq(first_package.name, 'first', 'replacement preserves first declaration position')
    F.eq(assert(first[2]).name, 'second', 'declaration order')
    F.ok(not rawequal(first, second), 'fresh list container')
    F.ok(not rawequal(first_package, second_package), 'fresh descriptor container')
    F.eq(first_package.exports, second_package.exports, 'same published exports')
    F.eq(first_package.exports, values, 'get and collect share exports')
    first_package.name = 'caller_changed'
    F.eq(assert(exports.collect()[1]).name, 'first', 'caller descriptor edits do not affect catalog')
    F.raises(function() exports.export('first', {}) end, 'RuntimeError', 'published replace')
    F.raises(function() exports.export('first', {}, true) end, 'RuntimeError', 'published append')
    exports.export('third', {})
    F.eq(#exports.collect(), 3, 'new package allowed after publication')
end)

F.test('get publishes only its requested package and empty contexts collect cleanly', function()
    local exports = export_mod.new()
    F.eq(#exports.collect(), 0, 'empty context')
    exports.export('a', { value = false })
    local pending = exports.export('b', { value = true })
    exports.get('a')
    pending.show()
    F.eq(next(exports.get('b')), nil, 'unrelated get does not seal pending selection')
end)

F.test('names, parameter types and own keys are checked before declaration changes', function()
    local exports = export_mod.new()
    for _, name in ipairs({ '', 'a..b', '.a', 'a.', 'a/b', 'a-b', '1a', 'a b', 'a.lua', '../a' }) do
        F.raises(function() exports.export(name, {}) end, 'ValueError', 'invalid name ' .. name)
    end
    local export = exports.export
    local export_invalid = export --[[@as fun(...: any): any]]
    F.raises(function() export_invalid(false, {}) end, 'TypeError', 'name type')
    F.raises(function() export_invalid('valid', false) end, 'TypeError', 'source type')
    F.raises(function() export_invalid('valid', {}, 1) end, 'TypeError', 'append type')
    for _, key in ipairs({ true, {}, 0.5, math.huge, -math.huge }) do
        F.raises(function() export('valid', { [key] = 1 }) end, 'ValueError', 'invalid source key')
    end
    local existing = export('retained', { value = false })
    F.raises(function() export('retained', { [true] = 1 }) end, 'ValueError', 'invalid replacement is atomic')
    existing.show('value')
    F.eq(exports.get('retained').value, false, 'invalid replacement preserves declaration')
    F.eq(#exports.collect(), 1, 'invalid declarations do not create packages')
    export('Case._name2', { value = 1 })
    F.raises(function() exports.get('case._name2') end, 'ImportError', 'names are case sensitive')
    F.raises(function() exports.get('missing') end, 'ImportError', 'unknown get')
    F.eq(exports.get('Case._name2').value, 1, 'dot identifiers accepted')
end)

F.test('module convenience context and independent contexts stay separate', function()
    export_mod.export('export_test', { value = false })
    F.eq(export_mod.get('export_test').value, false, 'direct module API')
    F.eq(assert(export_mod.collect()[1]).name, 'export_test', 'direct collection')
    local separate = export_mod.new()
    F.eq(#separate.collect(), 0, 'fresh context has no shared declarations')
    separate.export('export_test', { value = true })
    F.eq(separate.get('export_test').value, true, 'same name in independent context')
end)
