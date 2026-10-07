local mp = require 'mp'

local scripts_dir = mp.command_native{"expand-path", "~~/scripts"}
package.path = package.path .. ';' .. scripts_dir .. '/?.lua'
package.path = package.path .. ';' .. scripts_dir .. '/?/init.lua'

return require 'elxlib'
