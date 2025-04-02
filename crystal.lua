local NetworkedEntity = require "networked_entity"
local Crystal = require "class".createClass(NetworkedEntity)
function Crystal:init(x, y)
    NetworkedEntity.init(self, x, y, 20, 250)
    self.pulseTimer = 0
    self.pulseSpeed = 1.5
    self.pulseAmount = 0.2
    self.shieldRadius = self.radius * 1.5
    self.shieldOpacity = 0.3
end

function Crystal:update(dt)
    -- Update pulse effect
    self.pulseTimer = self.pulseTimer + dt * self.pulseSpeed
    if self.pulseTimer > math.pi * 2 then
        self.pulseTimer = self.pulseTimer - math.pi * 2
    end
end

function Crystal:draw()
    -- Calculate pulse effect
    local pulse = math.sin(self.pulseTimer) * self.pulseAmount
    local currentRadius = self.radius * (1 + pulse * 0.1)
    
    -- Draw protective shield aura
    love.graphics.setColor(0.4, 0.4, 1, self.shieldOpacity * (0.7 + pulse * 0.3))
    love.graphics.circle("fill", self.x, self.y, self.shieldRadius * (1 + pulse * 0.05))
    
    -- Draw crystal core with gradient effect
    local gradient = 0.2 + pulse * 0.1
    love.graphics.setColor(gradient, gradient, 1)
    love.graphics.circle("fill", self.x, self.y, currentRadius)
    
    -- Draw crystal outline
    love.graphics.setColor(0.7, 0.7, 1, 0.8)
    love.graphics.circle("line", self.x, self.y, currentRadius)
    
    -- Draw inner details
    love.graphics.setColor(0.8, 0.8, 1, 0.7)
    love.graphics.line(self.x - currentRadius * 0.7, self.y, self.x + currentRadius * 0.7, self.y)
    love.graphics.line(self.x, self.y - currentRadius * 0.7, self.x, self.y + currentRadius * 0.7)
    
    -- Draw health bar background
    local healthBarWidth = self.radius * 2.5
    local healthBarHeight = 6
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", self.x - healthBarWidth/2, self.y - self.radius - 15, healthBarWidth, healthBarHeight)
    
    -- Draw health bar
    local healthPercentage = self.hp / self.maxHP
    if healthPercentage > 0.6 then
        love.graphics.setColor(0, 1, 0.3, 0.8)  -- Green for high health
    elseif healthPercentage > 0.3 then
        love.graphics.setColor(1, 1, 0, 0.8)  -- Yellow for medium health
    else
        love.graphics.setColor(1, 0.3, 0, 0.8)  -- Red-orange for low health
    end
    
    love.graphics.rectangle("fill", self.x - healthBarWidth/2, self.y - self.radius - 15, 
                          healthBarWidth * healthPercentage, healthBarHeight)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end
return Crystal
