local class = require "class"
local Bullet = class.createClass()
function Bullet:init(x, y, dx, dy, r, d)
    self.x = x
    self.y = y
    self.dx = dx
    self.dy = dy
    self.radius = r
    self.damage = d
    self.dead = false
end
function Bullet:update(dt, map)
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt
    if self.x < 0 or self.x > map.width * map.tileSize or self.y < 0 or self.y > map.height * map.tileSize then
        self.dead = true
    end
end
function Bullet:toSnapshot()
    return {x = self.x, y = self.y, dx = self.dx, dy = self.dy, radius = self.radius, damage = self.damage, ownerIndex = self.ownerIndex}
end
function Bullet:draw()
    if self.isEnemyBullet then
        -- Enemy bullets glow and are more noticeable
        love.graphics.setColor(1, 0.3, 0.3, 0.5)
        love.graphics.circle("fill", self.x, self.y, self.radius * 2)
        
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", self.x, self.y, self.radius)
        
        -- Add a trail effect
        love.graphics.setColor(1, 0.5, 0, 0.3)
        love.graphics.line(self.x, self.y, self.x - self.dx * 0.05, self.y - self.dy * 0.05)
    else
        -- Player bullets
        love.graphics.setColor(0.3, 1, 0.3, 0.5)
        love.graphics.circle("fill", self.x, self.y, self.radius * 1.5)
        
        love.graphics.setColor(0, 1, 0)
        love.graphics.circle("fill", self.x, self.y, self.radius)
    end
    
    love.graphics.setColor(1, 1, 1)
end
return Bullet
