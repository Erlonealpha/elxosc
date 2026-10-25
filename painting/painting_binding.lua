-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Flutter-style PaintingBinding role facade.  Canvas instances are owned by
-- the host/owner scope; this capability does not create another Binding.

local M = {}

---@class PaintingBindingRole
local PaintingBinding = {}

function PaintingBinding.ensure_initialized()
    local widgets_binding = require 'widget.binding'
    return widgets_binding.WidgetsBinding.ensure_initialized()
end

function PaintingBinding.instance()
    local widgets_binding = require 'widget.binding'
    return widgets_binding.WidgetsBinding.instance()
end

M.PaintingBinding = PaintingBinding

return M
