## 快速开发示例

#### 快速嵌入开发
```lua
script_name = mp.get_script_name()
code = [[
import 'player'

bind('player.controls.right', PlayerTooltip({
    child = PlayerControlButton({
        key = 'example',
        icon = 'example',
        on_click = function()
            print('example click!')
        end,
    }),
    text = 'try click example',
}))
]]
mp.commandv('script-message-to', 'elxosc', 'define_start')
mp.commandv('script-message-to', 'elxosc', 'define', script_name, code)
mp.commandv('script-message-to', 'elxosc', 'define_end')
```

#### 分离UI以及类型化
main.lua
```lua
local file, err = io.open(mp.get_script_directory() .. '/ui.t.lua', 'r')
if file == nil then
    mp.msg.warn('cannot open ui code file,', err)
    return
end
local code = file:read('*a')
file:close()

mp.commandv('script-message-to', 'elxosc', 'define_start')
mp.commandv('script-message-to', 'elxosc', 'define', script_name, code)
mp.commandv('script-message-to', 'elxosc', 'define_end')
```
ui.t.lua
```lua
if false then -- for typing hints
    local builtins = {}
    ---@cast builtins elxosc.meta.Builtins
    import_as = builtins.import_as
    mod = builtins.mod
    bind = builtins.bind
    print = builtins.print
    new_widget = builtins.new_widget
    new_state = builtins.new_state
end

local player = import_as 'player'

local PlayerTooltip = player.PlayerTooltip
local PlayerControlButton = player.PlayerControlButton

bind('player.controls.right', PlayerTooltip({
    child = PlayerControlButton({
        key = 'example',
        icon = 'example',
        on_click = function()
            print('example click!')
        end,
    }),
    text = 'try click example',
}))
```
