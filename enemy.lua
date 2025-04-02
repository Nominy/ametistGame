local NetworkedEntity = require "networked_entity"
local util = require "util"
local Enemy = require "class".createClass(NetworkedEntity)

function Enemy:init(x, y, r, speed, hp, damage, t, spawnBulletCallback)
    NetworkedEntity.init(self, x, y, r, hp)
    self.maxHp = hp
    self.speed = speed
    self.damage = damage
    self.type = t
    self.attackTimer = 0
    self.attackCooldown = t == "melee" and 1.0 or (t == "ranged" and 2.0 or 0)
    self.attackRange = t == "melee" and 40 or (t == "ranged" and 300 or 60)
    self.spawnBulletCallback = spawnBulletCallback
end

function Enemy:update(dt, map, targets)
    local nearestTarget, nearestDist = targets[1], math.huge
    for _, tar in ipairs(targets) do
        local d = math.sqrt((tar.x - self.x)^2 + (tar.y - self.y)^2)
        if d < nearestDist then
            nearestDist = d
            nearestTarget = tar
        end
    end
    local tx = nearestTarget.x + (nearestTarget.radius or 16)
    local ty = nearestTarget.y + (nearestTarget.radius or 32)
    local a = math.atan2(ty - self.y, tx - self.x)
    local dx, dy = math.cos(a) * self.speed * dt, math.sin(a) * self.speed * dt
    self.x, self.y = util.moveWithCollision(self.x, self.y, dx, dy, {width = self.radius * 2, height = self.radius * 2, offsetX = self.radius, offsetY = self.radius}, map)
    if nearestDist <= self.attackRange then
        self.attackTimer = self.attackTimer + dt
        if self.attackTimer >= self.attackCooldown then
            self.attackTimer = 0
            if self.type == "melee" then
                nearestTarget:applyDamage(self.damage)
            elseif self.type == "ranged" then
                self:shootAt(tx, ty)
            elseif self.type == "explosive" and nearestDist <= 60 then
                self:explode(targets)
            end
        end
    end
end

function Enemy:shootAt(tx, ty)
    local a = math.atan2(ty - self.y, tx - self.x)
    local bullet = require("bullet"):new(self.x, self.y, math.cos(a) * 200, math.sin(a) * 200, 4, self.damage)
    bullet.isEnemyBullet = true
    if self.spawnBulletCallback then
        self.spawnBulletCallback(bullet)
    end
end

function Enemy:explode(targets)
    local explosionRadius = 100
    for _, p in ipairs(targets) do
        local d = math.sqrt((p.x - self.x)^2 + (p.y - self.y)^2)
        if d <= explosionRadius then
            local dmg = self.damage * (1 - d / explosionRadius)
            p:applyDamage(dmg)
        end
    end
    self.hp = 0
end

function Enemy:draw()
    -- Draw attack range indicator as a translucent circle
    love.graphics.setColor(0.3, 0.3, 0.8, 0.2)
    love.graphics.circle("fill", self.x, self.y, self.attackRange)
    
    -- Draw attack range outline
    love.graphics.setColor(0.4, 0.4, 0.9, 0.5)
    love.graphics.circle("line", self.x, self.y, self.attackRange)
    
    -- Draw cooldown indicator as an arc that fills up
    local cooldownPercentage = self.attackTimer / self.attackCooldown
    if cooldownPercentage < 1 then
        love.graphics.setColor(1, 1, 0, 0.7)
        love.graphics.arc("fill", self.x, self.y, self.radius + 5, 0, cooldownPercentage * math.pi * 2)
    end
    
    -- Set enemy color based on type
    if self.type == "melee" then 
        love.graphics.setColor(1, 0.5, 0)
    elseif self.type == "ranged" then 
        love.graphics.setColor(0.5, 0, 1)
    else -- explosive
        love.graphics.setColor(1, 0, 0)
    end
    
    -- Draw the enemy body
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    -- Draw outline
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    -- Draw damage indicator
    love.graphics.setColor(1, 0, 0, 0.9)
    local dmgText = tostring(self.damage)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(dmgText)
    local textHeight = font:getHeight()
    
    -- Draw damage value with a small background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", self.x - textWidth/2 - 2, self.y - self.radius - textHeight - 5, textWidth + 4, textHeight)
    love.graphics.setColor(1, 0, 0, 0.9)
    love.graphics.print(dmgText, self.x - textWidth/2, self.y - self.radius - textHeight - 5)
    
    -- Draw enemy type icon/indicator
    if self.type == "melee" then
        -- Sword-like icon for melee
        love.graphics.setColor(1, 0.7, 0)
        love.graphics.line(self.x - 5, self.y, self.x + 5, self.y)
        love.graphics.line(self.x, self.y - 5, self.x, self.y + 5)
    elseif self.type == "ranged" then
        -- Target-like icon for ranged
        love.graphics.setColor(0.7, 0, 1)
        love.graphics.circle("line", self.x, self.y, self.radius - 4)
        love.graphics.circle("line", self.x, self.y, self.radius - 8)
    elseif self.type == "explosive" then
        -- Bomb-like icon for explosive
        love.graphics.setColor(1, 0.3, 0)
        love.graphics.circle("line", self.x, self.y, self.radius - 4)
        love.graphics.line(self.x, self.y - self.radius + 2, self.x, self.y - self.radius + 8)
    end
    
    -- Draw health bar
    local healthPercentage = self.hp / self.maxHp
    local healthBarWidth = self.radius * 2
    local healthBarHeight = 4
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", self.x - healthBarWidth/2, self.y + self.radius + 5, healthBarWidth, healthBarHeight)
    
    if healthPercentage > 0.6 then
        love.graphics.setColor(0, 1, 0, 0.8)  -- Green for high health
    elseif healthPercentage > 0.3 then
        love.graphics.setColor(1, 1, 0, 0.8)  -- Yellow for medium health
    else
        love.graphics.setColor(1, 0, 0, 0.8)  -- Red for low health
    end
    
    love.graphics.rectangle("fill", self.x - healthBarWidth/2, self.y + self.radius + 5, 
                          healthBarWidth * healthPercentage, healthBarHeight)
                          
    love.graphics.setColor(1, 1, 1)  -- Reset color
end

function Enemy:toSnapshot()
    local s = NetworkedEntity.toSnapshot(self)
    s.health = s.hp
    s.hp = nil
    s.maxHp = self.maxHp  -- Add maxHp to the snapshot
    s.type = self.type
    s.attackTimer = self.attackTimer
    s.attackCooldown = self.attackCooldown
    s.attackRange = self.attackRange
    s.speed = self.speed
    s.damage = self.damage
    return s
end

return Enemy
