local PlayerClass = require "player_class"
local AssaultClass = require "class".createClass(PlayerClass)

function AssaultClass:init(x, y, anims, spawnBulletCallback)
    -- Call the parent init method
    PlayerClass.init(self, x, y, anims, spawnBulletCallback)
    
    -- Assault-specific properties
    self.className = "Assault"
    self.speed = 220  -- Slightly faster than base
    self.hp, self.maxHP = 125, 125  -- Less HP but more firepower
    self.specialAbilityCooldown = 10
    self.specialAbilityDuration = 5
    
    -- Override animations with assault-specific ones if available
    -- For now, we'll use the standard ones but this could be customized
end

-- Assault special ability: Rapid Fire
function AssaultClass:useSpecialAbility()
    self.specialAbilityActive = true
    self.specialAbilityTimer = 0
    -- Store original weapon tier to restore later
    self._originalWeaponTier = self.weaponTier
    -- Temporarily boost weapon tier during ability
    self.weaponTier = math.min(self.weaponTier + 1, #require("config").weaponTiers)
end

function AssaultClass:update(dt, map, input)
    -- Call parent update to handle base behavior
    PlayerClass.update(self, dt, map, input)
    
    -- Special ability finished - restore original weapon tier
    if not self.specialAbilityActive and self._originalWeaponTier then
        self.weaponTier = self._originalWeaponTier
        self._originalWeaponTier = nil
    end
end

return AssaultClass 