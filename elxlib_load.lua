local mp = require 'mp'

local scripts_dir = mp.command_native { "expand-path", "~~/scripts" }
local script_dir = mp.get_script_directory()
local module_loader = assert(loadfile(script_dir .. '/lib/module_loader.lua'))()
module_loader.install(script_dir)
package.path = package.path .. ';' .. scripts_dir .. '/?.lua'
package.path = package.path .. ';' .. scripts_dir .. '/?/init.lua'
package.path = package.path .. ';' .. script_dir .. '/?/init.lua'

return require 'elxlib'
