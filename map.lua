local class = require "class"
local Map = class.createClass()
function Map:init(w, h, t)
    self.width = w
    self.height = h
    self.tileSize = t
    self.data = {}
    for y = 1, h do
        self.data[y] = {}
        for x = 1, w do
            self.data[y][x] = (x == 1 or x == w or y == 1 or y == h) and 1 or 0
        end
    end
end
function Map:draw()
    for y = 1, self.height do
        for x = 1, self.width do
            local tx, ty = (x - 1) * self.tileSize, (y - 1) * self.tileSize
            local c = self.data[y][x] == 1 and {0.5, 0.5, 0.5} or {0.2, 0.2, 0.2}
            love.graphics.setColor(c)
            love.graphics.rectangle("fill", tx, ty, self.tileSize, self.tileSize)
        end
    end
    love.graphics.setColor(1, 1, 1)
end
function Map:checkCollision(x, y, w, h)
    local ts = self.tileSize
    local sx = math.floor(x / ts) + 1
    local ex = math.floor((x + w - 1) / ts) + 1
    local sy = math.floor(y / ts) + 1
    local ey = math.floor((y + h - 1) / ts) + 1
    for j = sy, ey do
        for i = sx, ex do
            if self.data[j] and self.data[j][i] == 1 then return true end
        end
    end
end
return Map
