local class = require "class"
local NetworkedEntity = class.createClass()
function NetworkedEntity:init(x, y, r, hp)
    self.x = x
    self.y = y
    self.radius = r
    self.hp = hp or 100
    self.maxHP = hp or 100
end
function NetworkedEntity:applyDamage(d)
    self.hp = math.max(0, self.hp - d)
end
function NetworkedEntity:isDead()
    return self.hp <= 0
end
function NetworkedEntity:toSnapshot()
    return {x = self.x, y = self.y, hp = self.hp, maxHP = self.maxHP}
end
return NetworkedEntity
