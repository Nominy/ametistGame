local util = {}
function util.moveWithCollision(x, y, dx, dy, rect, map)
    local nx = x + dx
    if map:checkCollision(nx - rect.offsetX, y - rect.offsetY, rect.width, rect.height) then nx = x end
    local ny = y + dy
    if map:checkCollision(nx - rect.offsetX, ny - rect.offsetY, rect.width, rect.height) then ny = y end
    return nx, ny
end
function util.distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end
return util
