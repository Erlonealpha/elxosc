-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Canonical Flutter-aligned entry point.  The old WidgetBinding export is the
-- same class object during the migration window.

local binding = require 'widget.binding'

return {
    WidgetsBinding = binding.WidgetsBinding,
    WidgetBinding = binding.WidgetBinding,
}
