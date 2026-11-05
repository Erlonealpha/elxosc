-- Diagnostic conversion for offline reports, separate from the hot host utility.
local M = {}

---@alias AssMeasureStatus
---| 'ok'
---| 'empty'
---| 'unavailable'
---| 'error'

---@class AssMeasureRequest
---@field name string
---@field data string
---@field res_x integer
---@field res_y integer

---@class AssMeasureReportBounds
---@field left number
---@field top number
---@field right number
---@field bottom number
---@field width number
---@field height number

---@class AssMeasureResult
---@field name string
---@field status AssMeasureStatus
---@field res_x integer
---@field res_y integer
---@field bounds AssMeasureReportBounds?
---@field error string?
---@field cleanup_error string?

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

---@param request AssMeasureRequest
---@param raw AssMeasureRawBounds?
---@param err string?
---@param kind AssMeasureErrorKind?
---@return AssMeasureResult
function M.result(request, raw, err, kind)
    ---@type AssMeasureResult
    local result = {
        name = request.name, res_x = request.res_x, res_y = request.res_y,
        status = kind or 'ok', error = err,
    }
    if not raw then
        return result
    end
    if next(raw) == nil then
        result.status = 'empty'
        return result
    end
    ---@cast raw AssMeasureBounds
    if not finite(raw.x0) or not finite(raw.y0) or not finite(raw.x1) or not finite(raw.y1)
        or raw.x1 < raw.x0 or raw.y1 < raw.y0 then
        result.status = 'error'
        result.error = 'host returned invalid compute_bounds'
        return result
    end
    result.bounds = {
        left = raw.x0, top = raw.y0, right = raw.x1, bottom = raw.y1,
        width = raw.x1 - raw.x0, height = raw.y1 - raw.y0,
    }
    if result.bounds.width == 0 or result.bounds.height == 0 then
        result.status = 'empty'
    end
    return result
end

return M
