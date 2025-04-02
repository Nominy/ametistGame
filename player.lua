local NetworkedEntity = require "networked_entity"
local Animation = require "animation"
local util = require "util"
local config = require "config"
local Player = require "class".createClass(NetworkedEntity)
function Player:init(x, y, anims, spawnBulletCallback)
    NetworkedEntity.init(self, x, y, 20, 150)
    self.speed = 200
    self.hp, self.maxHP = 150, 150
    self.weaponTier = 1
    self.credit = 0
    self.fireTimer = 0
    self.animations = {
        down = anims.down:clone(),
        left = anims.left:clone(),
        right = anims.right:clone(),
        up = anims.up:clone()
    }
    self.direction = "down"
    self.currentAnim = self.animations.down
    self.spawnBulletCallback = spawnBulletCallback
end
function Player:update(dt, map, input)
    local dx, dy = 0, 0
    local actions = {
        {key = "up",    dx = 0,  dy = -1, anim = self.animations.up,    dir = "up"},
        {key = "down",  dx = 0,  dy = 1,  anim = self.animations.down,  dir = "down"},
        {key = "left",  dx = -1, dy = 0,  anim = self.animations.left,  dir = "left"},
        {key = "right", dx = 1,  dy = 0,  anim = self.animations.right, dir = "right"}
    }
    for _, a in ipairs(actions) do
        if input[a.key] then
            dx = dx + a.dx * self.speed * dt
            dy = dy + a.dy * self.speed * dt
            self.direction = a.dir
            self.currentAnim = a.anim
        end
    end
    if dx ~= 0 or dy ~= 0 then self.currentAnim:update(dt) end
    self.x, self.y = util.moveWithCollision(self.x, self.y, dx, dy, {width = 32, height = 64, offsetX = 0, offsetY = 0}, map)
    if input.shoot then
        self.fireTimer = self.fireTimer + dt
        local t = config.weaponTiers[self.weaponTier]
        if self.fireTimer >= 1 / t.fireRate then
            self.fireTimer = self.fireTimer - 1 / t.fireRate
            self:spawnBullet(input.mouseX, input.mouseY)
        end
    else
        self.fireTimer = 0
    end
end
function Player:spawnBullet(tx, ty)
    local cx, cy = self.x + 16, self.y + 32
    local a = math.atan2(ty - cy, tx - cx)
    local t = config.weaponTiers[self.weaponTier]
    local n, sp = t.multishot, t.totalSpread
    for i = 1, n do
        local ang = n == 1 and a or a + math.rad(-sp / 2 + (i - 1) * (sp / (n - 1)))
        local bs = t.speed
        local md = 20
        local bx, by = cx + math.cos(ang) * md, cy + math.sin(ang) * md
        local bullet = require "bullet":new(bx, by, math.cos(ang) * bs, math.sin(ang) * bs, 4, t.damage)
        bullet.ownerIndex = self.id
        self.spawnBulletCallback(bullet)
    end
end
-- Add this function if it doesn't exist, or modify it if it does
function Player:toSnapshot()
    local s = NetworkedEntity.toSnapshot(self)
    s.direction = self.direction
    s.animFrame = self.currentAnim.frame
    s.animTimer = self.currentAnim.timer
    s.credit = self.credit
    s.weaponTier = self.weaponTier  -- Make sure weaponTier is included
    return s
end
return Player
