local M = {}
function M.createClass(base)
    local c = {}
    c.__index = c
    function c:new(...)
        local o = setmetatable({}, self)
        if o.init then o:init(...) end
        return o
    end
    if base then setmetatable(c, {__index = base}) end
    return c
end
return M
