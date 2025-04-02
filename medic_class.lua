local PlayerClass = require "player_class"
local MedicClass = require "class".createClass(PlayerClass)

function MedicClass:init(x, y, anims, spawnBulletCallback)
    -- Call the parent init method
    PlayerClass.init(self, x, y, anims, spawnBulletCallback)
    
    -- Medic-specific properties
    self.className = "Medic"
    self.hp, self.maxHP = 175, 175  -- More HP for sustain
    self.speed = 190  -- Slightly slower than base
    self.healAmount = 5  -- Amount healed per second
    self.healRadius = 100  -- Distance at which healing works
    self.specialAbilityCooldown = 15
    self.specialAbilityDuration = 5
    
    -- Override animations with medic-specific ones if available
    -- For now, we'll use the standard ones but this could be customized
end

-- Medic special ability: Area Heal
function MedicClass:useSpecialAbility()
    self.specialAbilityActive = true
    self.specialAbilityTimer = 0
    -- Boosted healing during ability will be handled in update
end

function MedicClass:update(dt, map, input)
    -- Call parent update to handle base behavior
    PlayerClass.update(self, dt, map, input)
    
    -- Apply constant healing to nearby players
    local game = _G.currentGame  -- Assuming game is stored globally
    if game then
        -- Get all players
        for _, player in ipairs(game.players) do
            -- Skip self
            if player ~= self then
                -- Check if player is within heal radius
                local dx = player.x - self.x
                local dy = player.y - self.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= self.healRadius then
                    -- Apply healing based on distance (more healing closer)
                    local healFactor = 1 - (distance / self.healRadius) * 0.5
                    local healRate = self.healAmount * (self.specialAbilityActive and 3 or 1) * healFactor
                    player.hp = math.min(player.hp + healRate * dt, player.maxHP)
                end
            end
        end
        
        -- During special ability, also heal self
        if self.specialAbilityActive then
            self.hp = math.min(self.hp + self.healAmount * 2 * dt, self.maxHP)
        end
    end
end

return MedicClass 