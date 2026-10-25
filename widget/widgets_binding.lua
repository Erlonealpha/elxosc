-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Canonical Flutter-aligned entry point.  The old WidgetBinding export is the
-- same singleton-capable class object during the migration window.  Attach
-- additional Widget trees through `ensure_initialized():attach(...)` so each
-- tree receives its own BuildOwner without creating another Binding.

local binding = require 'widget.binding'

return {
    WidgetsBinding = binding.WidgetsBinding,
    WidgetBinding = binding.WidgetBinding,
}
