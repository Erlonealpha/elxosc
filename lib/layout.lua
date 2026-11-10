-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.layout : elxosc.src.layout.constraints
local M = {}

M.constraints = require 'src.layout.constraints'

for _, source in ipairs({
    M.constraints,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
