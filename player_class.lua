local Player = require "player"
local PlayerClass = require "class".createClass(Player)

function PlayerClass:init(x, y, anims, spawnBulletCallback)
    Player.init(self, x, y, anims, spawnBulletCallback)
    
    -- Base properties for all classes
    self.className = "Base"  -- Override in subclasses
    self.specialAbilityTimer = 0
    self.specialAbilityCooldown = 5  -- 5 seconds default cooldown
    self.specialAbilityActive = false
    self.specialAbilityDuration = 0
end

-- Method to be overridden by subclasses
function PlayerClass:useSpecialAbility()
    -- Base implementation, should be overridden
    print("Using base special ability")
    self.specialAbilityActive = true
    self.specialAbilityTimer = 0
end

-- Update method that adds class-specific behavior
function PlayerClass:update(dt, map, input)
    -- Call the parent update method
    Player.update(self, dt, map, input)
    
    -- Handle special ability cooldown and duration
    if self.specialAbilityActive then
        self.specialAbilityTimer = self.specialAbilityTimer + dt
        if self.specialAbilityTimer >= self.specialAbilityDuration then
            self.specialAbilityActive = false
            self.specialAbilityTimer = 0
        end
    else
        -- Update cooldown timer
        if self.specialAbilityTimer < self.specialAbilityCooldown then
            self.specialAbilityTimer = self.specialAbilityTimer + dt
        end
        
        -- Check for special ability activation
        if input.specialAbility and self.specialAbilityTimer >= self.specialAbilityCooldown then
            self:useSpecialAbility()
        end
    end
end

function PlayerClass:toSnapshot()
    local s = Player.toSnapshot(self)
    s.className = self.className
    s.specialAbilityActive = self.specialAbilityActive
    s.specialAbilityTimer = self.specialAbilityTimer
    return s
end

return PlayerClass 