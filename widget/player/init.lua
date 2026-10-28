-- Default player components and their public aggregate.

local app_mod = require 'widget.player.app'
local progress_mod = require 'widget.player.progress_bar'

local M = {}
for _, mod in ipairs({ app_mod, progress_mod }) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

return M
