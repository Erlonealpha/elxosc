-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The host registers each owning library's complete static inventory.
local exports = require('export').new()

local export = exports.export

for _, catalog in ipairs({
    require 'package_catalog',
    require 'player.package_catalog',
    require 'define.package_catalog'
}) do
    for _, package in ipairs(catalog.collect()) do
        export(package.name, package.exports, true)
    end
end

---@class elxosc.mod.host.package_catalog
local M = {}

---@return elxosc.export.Package<elxosc.export.Exports>[]
function M.collect()
    return exports.collect()
end

return M
