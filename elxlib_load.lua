local mp = require 'mp'

local scripts_dir = mp.command_native{"expand-path", "~~/scripts"}
local script_dir = mp.get_script_directory()
package.path = package.path .. ';' .. scripts_dir .. '/?.lua'
package.path = package.path .. ';' .. scripts_dir .. '/?/init.lua'
package.path = package.path .. ';' .. script_dir  .. '/?/init.lua'

return require 'elxlib'
