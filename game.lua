local Map = require "map"
local Animation = require "animation"
local Player = require "player"
local Enemy = require "enemy"
local Crystal = require "crystal"
local Bullet = require "bullet"
local NetworkManager = require "network_manager"
local config = require "config"
local AssaultClass = require "assault_class"
local MedicClass = require "medic_class"

local Game = {
    state = "menu", wave = 1, maxWave = 20,
    players = {}, enemies = {}, bullets = {}, enemyBullets = {},
    centralCrystal = nil, coop = false, networkRole = nil,
    localPlayerIndex = 1, networkUpdateTimer = 0, networkUpdateInterval = 0.005,
    map = nil, playerImage = nil, weaponImage = nil, animations = nil, remoteInputs = {},
    menu = nil,
    backgroundNoise = {}, backgroundTime = 0, backgroundColors = {}
}

function Game:collectSnapshots(list)
    local r = {}
    for _, i in ipairs(list) do table.insert(r, i:toSnapshot()) end
    return r
end

function Game:init(args)
    _G.currentGame = self  -- Store a global reference to the current game for easier access
    math.randomseed(os.time())
    self.map = Map:new(25, 19, 32)
    love.window.setMode(self.map.width * self.map.tileSize, self.map.height * self.map.tileSize)
    self.playerImage = love.graphics.newImage("player.png")
    self.weaponImage = love.graphics.newImage("weapon.png")
    self:loadAnimations()
    self.menu = require("menu"):init(self)
    self:initPlayers()
    self.centralCrystal = Crystal:new((self.map.width / 2 - 0.5) * self.map.tileSize, (self.map.height / 2 - 0.5) * self.map.tileSize)
    self.enemies, self.bullets, self.enemyBullets = {}, {}, {}
    self.wave = 1
    self.paused = false
    self.messageTimer = 0
    self.message = ""
    self.particles = {}
    
    -- Initialize background with static properties instead of animation
    self.backgroundTime = 0
    
    -- Initialize background colors
    self:updateBackgroundColors()  -- Set initial colors based on game state
    self:generateBackgroundNoise()
    
    self:spawnWave(self.wave)
end

function Game:loadAnimations()
    self.animations = {
        base = {},
        assault = {},
        medic = {}
    }
    
    -- Load base player image
    self.playerImage = love.graphics.newImage("player.png")
    
    -- We'll assume we have player images for each class, but fall back to the base one if not
    local assaultImagePath = "assault.png"
    local medicImagePath = "medic.png"
    
    -- Try to load class-specific images, fall back to base player image if not found
    local assaultImage = love.filesystem.getInfo(assaultImagePath) and love.graphics.newImage(assaultImagePath) or self.playerImage
    local medicImage = love.filesystem.getInfo(medicImagePath) and love.graphics.newImage(medicImagePath) or self.playerImage
    
    local fw, fh, nf = 32, 64, 3  -- Frame width, height, number of frames
    
    -- Function to create animation for a specific image and row offset
    local function makeAnim(image, off)
        local q = {}
        for i = 0, nf - 1 do
            table.insert(q, love.graphics.newQuad(i * fw, off, fw, fh, image:getDimensions()))
        end
        return Animation:new(image, q, 0.15)
    end
    
    -- Create base animations
    self.animations.base.down = makeAnim(self.playerImage, 0)
    self.animations.base.left = makeAnim(self.playerImage, fh)
    self.animations.base.right = makeAnim(self.playerImage, fh * 2)
    self.animations.base.up = makeAnim(self.playerImage, fh * 3)
    
    -- Create assault animations
    self.animations.assault.down = makeAnim(assaultImage, 0)
    self.animations.assault.left = makeAnim(assaultImage, fh)
    self.animations.assault.right = makeAnim(assaultImage, fh * 2)
    self.animations.assault.up = makeAnim(assaultImage, fh * 3)
    
    -- Create medic animations
    self.animations.medic.down = makeAnim(medicImage, 0)
    self.animations.medic.left = makeAnim(medicImage, fh)
    self.animations.medic.right = makeAnim(medicImage, fh * 2)
    self.animations.medic.up = makeAnim(medicImage, fh * 3)
end

function Game:initPlayers()
    self.players = {}
    local spawnBullet = function(bullet) table.insert(self.bullets, bullet) end
    if not self.coop then
        self.localPlayerIndex = 1
        table.insert(self.players, AssaultClass:new((self.map.width / 2 - 0.5) * self.map.tileSize,
                                               (self.map.height / 2 - 0.5) * self.map.tileSize,
                                               self.animations.assault, spawnBullet))
    else
        if self.networkRole == "host" then
            self.localPlayerIndex = 1
            table.insert(self.players, AssaultClass:new((self.map.width / 2 - 0.5) * self.map.tileSize,
                                                   (self.map.height / 2 - 0.5) * self.map.tileSize,
                                                   self.animations.assault, spawnBullet))
            table.insert(self.players, MedicClass:new((self.map.width / 2 - 0.5) * self.map.tileSize + 50,
                                                   (self.map.height / 2 - 0.5) * self.map.tileSize,
                                                   self.animations.medic, spawnBullet))
        else
            self.localPlayerIndex = 2
            table.insert(self.players, AssaultClass:new((self.map.width / 2 - 0.5) * self.map.tileSize,
                                                   (self.map.height / 2 - 0.5) * self.map.tileSize - 50,
                                                   self.animations.assault, spawnBullet))
            table.insert(self.players, MedicClass:new((self.map.width / 2 - 0.5) * self.map.tileSize,
                                                   (self.map.height / 2 - 0.5) * self.map.tileSize,
                                                   self.animations.medic, spawnBullet))
        end
    end
    for i, p in ipairs(self.players) do p.id = i end
end

function Game:spawnWave(w)
    local c = w * 2 + 2
    local types = {"melee", "ranged", "explosive"}
    local spawnEnemyBullet = function(bullet) table.insert(self.enemyBullets, bullet) end
    for _ = 1, c do
        local ex, ey = self:getRandomEdgeSpawn()
        local enemyType = types[math.random(1, #types)]
        local speed = enemyType == "explosive" and 80 or (enemyType == "ranged" and 30 or 40)
        local hp = enemyType == "explosive" and (4 + math.floor(w / 3)) or (2 + math.floor(w / 3))
        local damage = enemyType == "explosive" and 40 or (enemyType == "ranged" and 5 or 10)
        damage = damage + math.floor(w / 5)
        table.insert(self.enemies, Enemy:new(ex, ey, 10, speed + (w - 1) * 2, hp, damage, enemyType, spawnEnemyBullet))
    end
end

function Game:getRandomEdgeSpawn()
    local s = math.random(1, 4)
    local ts = self.map.tileSize
    local x, y
    if s == 1 then x, y = math.random(2, self.map.width - 1), 2
    elseif s == 2 then x, y = math.random(2, self.map.width - 1), self.map.height - 1
    elseif s == 3 then x, y = 2, math.random(2, self.map.height - 1)
    else x, y = self.map.width - 1, math.random(2, self.map.height - 1) end
    return (x - 0.5) * ts, (y - 0.5) * ts
end

function Game:sendSnapshot()
    NetworkManager:send({
        type = "snapshot",
        snapshot = {
            state = self.state,
            wave = self.wave,
            players = self:collectSnapshots(self.players),
            enemies = self:collectSnapshots(self.enemies),
            bullets = self:collectSnapshots(self.bullets),
            enemyBullets = self:collectSnapshots(self.enemyBullets),
            centralCrystal = self.centralCrystal:toSnapshot()
        }
    })
end

function Game:processNetworkMessages()
    local m = NetworkManager:receive()
    while m do
        if m.type == "playerInput" and self.coop and NetworkManager.isHost then
            self.remoteInputs[m.index] = m.input
        elseif m.type == "snapshot" and not NetworkManager.isHost then
            self:updateFromSnapshot(m.snapshot)
        elseif m.type == "upgradeWeapon" and self.coop and NetworkManager.isHost then
            -- Process weapon upgrade request from client
            local playerIndex = m.playerIndex
            if self.players[playerIndex] then
                local player = self.players[playerIndex]
                local nextTier = player.weaponTier + 1
                
                if config.weaponTiers[nextTier] and player.credit >= config.weaponTiers[nextTier].cost then
                    player.credit = player.credit - config.weaponTiers[nextTier].cost
                    player.weaponTier = nextTier
                    -- Force an immediate snapshot update to confirm the upgrade
                    self:sendSnapshot()
                end
            end
        end
        m = NetworkManager:receive()
    end
end

function Game:tryUpgradeWeapon()
    local p = self.players[self.localPlayerIndex]
    local nextTier = p.weaponTier + 1
    
    if not config.weaponTiers[nextTier] then
        self.message = "Maximum weapon tier reached!"
        self.messageTimer = 2.0
        return
    end
    
    local cost = config.weaponTiers[nextTier].cost
    if p.credit >= cost then
        if self.coop and self.networkRole == "client" then
            -- For clients, send upgrade request to host instead of upgrading locally
            NetworkManager:send({
                type = "upgradeWeapon",
                playerIndex = self.localPlayerIndex
            })

            self.message = "Weapon upgraded to tier " .. nextTier .. "!"
            self.messageTimer = 2.0
        else
            -- For host or single player, upgrade directly
            p.credit = p.credit - cost
            p.weaponTier = nextTier
            self.message = "Weapon upgraded to tier " .. nextTier .. "!"
            self.messageTimer = 2.0
            
            -- Force an immediate snapshot update after upgrading
            if self.coop then
                self:sendSnapshot()
            end
        end
    else
        self.message = "Not enough credits! Need " .. cost .. " credits."
        self.messageTimer = 2.0
    end
end

function Game:updateFromSnapshot(s)
    self.state = self.state ~= s.state and s.state or self.state
    self.wave = s.wave
    for i, sp in ipairs(s.players) do
        local p = self.players[i]
        if p then
            p.x, p.y = sp.x, sp.y
            p.hp, p.maxHP = sp.hp, sp.maxHP
            p.credit = sp.credit
            
            -- Explicitly update weapon tier if it has changed
            if sp.weaponTier and p.weaponTier ~= sp.weaponTier then
                p.weaponTier = sp.weaponTier
                -- Update any weapon-related properties if needed
            end
            
            p.direction = sp.direction
            p.currentAnim = p.animations[sp.direction]
            if p.currentAnim then
                p.currentAnim.frame = sp.animFrame
                p.currentAnim.timer = sp.animTimer
            end
        end
    end
    self.enemies = {}
    for _, se in ipairs(s.enemies) do
        local enemy = Enemy:new(se.x, se.y, 10, se.speed, se.health, se.damage, se.type, function(bullet) table.insert(self.enemyBullets, bullet) end)
        -- Make sure all enemy properties are properly synchronized
        enemy.hp = se.health  -- Explicitly set hp to match the snapshot
        enemy.maxHp = se.maxHp or se.health  -- Also sync maxHp if available
        enemy.attackTimer = se.attackTimer
        enemy.attackCooldown = se.attackCooldown
        enemy.attackRange = se.attackRange
        table.insert(self.enemies, enemy)
    end
    self.bullets = {}
    for _, sb in ipairs(s.bullets) do
        local b = Bullet:new(sb.x, sb.y, sb.dx, sb.dy, sb.radius, sb.damage)
        b.ownerIndex = sb.ownerIndex
        table.insert(self.bullets, b)
    end
    self.enemyBullets = {}
    for _, sb in ipairs(s.enemyBullets) do
        table.insert(self.enemyBullets, Bullet:new(sb.x, sb.y, sb.dx, sb.dy, sb.radius, sb.damage))
    end
    self.centralCrystal.x, self.centralCrystal.y = s.centralCrystal.x, s.centralCrystal.y
    self.centralCrystal.hp, self.centralCrystal.maxHP = s.centralCrystal.hp, s.centralCrystal.maxHP
end

local function updateBullets(list, dt, map)
    for i = #list, 1, -1 do
        local b = list[i]
        b:update(dt, map)
        if b.dead then table.remove(list, i) end
    end
end

function Game:update(dt)
    if self.state == "menu" then
        self.menu:update(dt)
        -- Update background time even in menu state
        self.backgroundTime = self.backgroundTime + dt * self.backgroundNoise.flowSpeed
    elseif self.state ~= "playing" then 
        -- Update background time in other states too
        self.backgroundTime = self.backgroundTime + dt * self.backgroundNoise.flowSpeed
        return 
    end
    if self.paused then return end
    
    -- Update background time in playing state
    self.backgroundTime = self.backgroundTime + dt * self.backgroundNoise.flowSpeed
    
    -- Update message timer
    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - dt
    end
    
    -- Update particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.life = p.life - dt
        p.x = p.x + p.dx * dt
        p.y = p.y + p.dy * dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
    
    -- Update crystal animation
    self.centralCrystal:update(dt)
    
    local inp = self:getLocalInput()
    self.players[self.localPlayerIndex]:update(dt, self.map, inp)
    for i, p in ipairs(self.players) do
        if i ~= self.localPlayerIndex then
            local r = self.remoteInputs[i] or {up=false, down=false, left=false, right=false, shoot=false, specialAbility=false, mouseX=p.x, mouseY=p.y}
            p:update(dt, self.map, r)
        end
    end
    local targets = {self.centralCrystal}
    for _, p in ipairs(self.players) do table.insert(targets, p) end
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        e:update(dt, self.map, targets)
        if e.hp <= 0 then
            -- Create death particles
            self:createDeathParticles(e.x, e.y, e.type)
            table.remove(self.enemies, i)
        end
    end
    updateBullets(self.bullets, dt, self.map)
    updateBullets(self.enemyBullets, dt, self.map)
    for i = #self.enemyBullets, 1, -1 do
        local b = self.enemyBullets[i]
        local hit = false
        for _, p in ipairs(self.players) do
            local px, py = p.x + 16, p.y + 32
            if require("util").distance(b.x, b.y, px, py) < (b.radius + 20) then
                p:applyDamage(b.damage)
                hit = true
                break
            end
        end
        if not hit then
            local d = require("util").distance(b.x, b.y, self.centralCrystal.x, self.centralCrystal.y)
            if d < (b.radius + self.centralCrystal.radius) then
                self.centralCrystal:applyDamage(b.damage)
                hit = true
            end
        end
        if hit then b.dead = true end
    end
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        for j = #self.enemies, 1, -1 do
            local e = self.enemies[j]
            if require("util").distance(b.x, b.y, e.x, e.y) < (b.radius + e.radius) then
                e.hp = e.hp - b.damage
                b.dead = true
                if e.hp <= 0 then
                    -- Create death particles before removing the enemy
                    self:createDeathParticles(e.x, e.y, e.type)
                    table.remove(self.enemies, j)
                    if b.ownerIndex then
                        local o = self.players[b.ownerIndex]
                        if o then o.credit = o.credit + 1 end
                    else
                        self.players[self.localPlayerIndex].credit = self.players[self.localPlayerIndex].credit + 1
                    end
                end
                break
            end
        end
        if b.dead then table.remove(self.bullets, i) end
    end
    if self.players[self.localPlayerIndex].hp <= 0 or self.centralCrystal.hp <= 0 then
        self.state = "gameover"
    end
    if #self.enemies == 0 then
        if self.wave < self.maxWave then
            self.wave = self.wave + 1
            self:spawnWave(self.wave)
        else
            self.state = "victory"
        end
    end
    self.networkUpdateTimer = self.networkUpdateTimer + dt
    if self.networkUpdateTimer >= self.networkUpdateInterval then
        self.networkUpdateTimer = 0
        self:sendSnapshot()
    end
    self:processNetworkMessages()
end

function Game:getLocalInput()
    local i = {up = false, down = false, left = false, right = false, shoot = false, specialAbility = false, mouseX = 0, mouseY = 0}
    if love.keyboard.isDown("w") then i.up = true end
    if love.keyboard.isDown("s") then i.down = true end
    if love.keyboard.isDown("a") then i.left = true end
    if love.keyboard.isDown("d") then i.right = true end
    if love.mouse.isDown(1) then i.shoot = true end
    if love.keyboard.isDown("space") then i.specialAbility = true end
    i.mouseX, i.mouseY = love.mouse.getPosition()
    return i
end

function Game:drawBackground()
    local w, h = self.map.width * self.map.tileSize, self.map.height * self.map.tileSize
    
    -- Dynamic cell size that changes with time for a breathing effect
    local baseCellSize = 64
    local cellSizeVariation = 8 * math.sin(self.backgroundTime * self.backgroundNoise.pulseSpeed * 0.5)
    local cellSize = baseCellSize + cellSizeVariation
    
    -- Create an animated, flowing background
    for y = 0, math.ceil(h / cellSize) do
        for x = 0, math.ceil(w / cellSize) do
            -- Use time-based noise values for flowing animation with parameters from backgroundNoise
            local flowSpeed = self.backgroundNoise.flowSpeed
            local waveAmplitude = self.backgroundNoise.waveAmplitude
            
            local noiseVal1 = love.math.noise(
                x * 0.1 + math.sin(self.backgroundTime * 0.3) * waveAmplitude,
                y * 0.1 + math.cos(self.backgroundTime * 0.2) * waveAmplitude,
                self.backgroundTime * 0.1  -- Time-based z-coordinate
            )
            
            local noiseVal2 = love.math.noise(
                x * 0.2 - math.cos(self.backgroundTime * 0.4) * waveAmplitude * 1.5,
                y * 0.2 - math.sin(self.backgroundTime * 0.5) * waveAmplitude * 1.5,
                self.backgroundTime * 0.15 + 2  -- Different time-based z-coordinate
            )
            
            -- Add wave effect based on time with configurable amplitude
            local waveEffect = math.sin(x * 0.1 + y * 0.1 + self.backgroundTime) * waveAmplitude
            
            -- Combine noise values for more complex patterns with wave effect
            local combinedNoise = (noiseVal1 * 0.6 + noiseVal2 * 0.4) + waveEffect * 0.2
            combinedNoise = math.max(0, math.min(1, combinedNoise)) -- Clamp values
            
            -- Smooth color transitions between background colors with time-based shift
            local colorShiftSpeed = self.backgroundNoise.colorShiftSpeed
            local colorShift = math.sin(self.backgroundTime * colorShiftSpeed) * 0.8
            local baseColorIndex = combinedNoise * (#self.backgroundColors - 1) + 1 + colorShift
            baseColorIndex = math.max(1, math.min(#self.backgroundColors - 0.001, baseColorIndex))
            
            local lowerIndex = math.floor(baseColorIndex)
            local upperIndex = math.min(lowerIndex + 1, #self.backgroundColors)
            local blend = baseColorIndex - lowerIndex
            
            local color1 = self.backgroundColors[lowerIndex]
            local color2 = self.backgroundColors[upperIndex]
            
            -- Pulse effect based on time with configurable speed
            local pulseSpeed = self.backgroundNoise.pulseSpeed
            local pulse = (math.sin(self.backgroundTime * pulseSpeed) * 0.15) + 1
            
            -- Interpolate between colors with time-based effects
            local r = (color1[1] * (1 - blend) + color2[1] * blend) * pulse
            local g = (color1[2] * (1 - blend) + color2[2] * blend) * pulse
            local b = (color1[3] * (1 - blend) + color2[3] * blend) * pulse
            
            -- Add dramatic highlights based on noise
            if combinedNoise > 0.6 then
                -- More intense highlights that vary with time
                r = r + 0.2 * math.sin(self.backgroundTime * 3)
                g = g + 0.2 * math.sin(self.backgroundTime * 3 + 2)
                b = b + 0.2 * math.sin(self.backgroundTime * 3 + 4)
            elseif combinedNoise > 0.4 then
                -- Add some highlights to mid-range noise values too
                r = r + 0.1 * math.sin(self.backgroundTime * 2)
                g = g + 0.1 * math.sin(self.backgroundTime * 2 + 2)
                b = b + 0.1 * math.sin(self.backgroundTime * 2 + 4)
            end
            
            -- Ensure colors are in valid range
            r = math.max(0, math.min(1, r))
            g = math.max(0, math.min(1, g))
            b = math.max(0, math.min(1, b))
            
            love.graphics.setColor(r, g, b)
            love.graphics.rectangle("fill", x * cellSize, y * cellSize, cellSize, cellSize)
        end
    end
end

function Game:updateBackgroundColors()
    -- Base colors for different game states with more dramatic variations
    local baseColors = {
        menu = {
            {0.1, 0.1, 0.5},  -- Vibrant blue
            {0.3, 0.1, 0.6},  -- Bright purple
            {0.2, 0.2, 0.5},  -- Bright muted purple
            {0.1, 0.3, 0.5},  -- Bright teal blue
            {0.05, 0.05, 0.3}  -- Deep blue
        },
        playing = {
            {0.1, 0.1, 0.5},  -- Vibrant blue
            {0.3, 0.1, 0.6},  -- Bright purple
            {0.2, 0.2, 0.5},  -- Bright muted purple
            {0.1, 0.3, 0.5},  -- Bright teal blue
            {0.05, 0.15, 0.35} -- Dark teal
        },
        gameover = {
            {0.5, 0.1, 0.1},  -- Bright red
            {0.6, 0.1, 0.1},  -- Intense red
            {0.5, 0.1, 0.3},  -- Bright red-purple
            {0.4, 0.05, 0.05}, -- Deep red
            {0.3, 0.0, 0.0}    -- Very dark red
        },
        victory = {
            {0.1, 0.5, 0.1},  -- Bright green
            {0.1, 0.6, 0.3},  -- Vibrant green
            {0.3, 0.5, 0.1},  -- Bright yellow-green
            {0.1, 0.4, 0.2},  -- Deep green
            {0.2, 0.7, 0.3}   -- Glowing green
        }
    }
    
    -- Select color palette based on game state
    local stateColors = baseColors[self.state] or baseColors.playing
    
    -- Modify colors based on wave number for playing state
    if self.state == "playing" then
        -- Increase intensity for higher waves
        local waveIntensity = math.min(self.wave / self.maxWave, 1.0)
        
        -- Add some reddish tint as waves progress
        for i, color in ipairs(stateColors) do
            local modifiedColor = {color[1], color[2], color[3]}
            modifiedColor[1] = math.min(1, color[1] + waveIntensity * 0.2)  -- Increase red
            modifiedColor[2] = math.max(0, color[2] - waveIntensity * 0.05) -- Decrease green slightly
            stateColors[i] = modifiedColor
        end
        
        -- Add an extra intense color for high waves
        if self.wave > self.maxWave / 2 then
            table.insert(stateColors, {0.3, 0.1, 0.2})  -- Intense color for high waves
        end
    end
    
    self.backgroundColors = stateColors
end

function Game:generateBackgroundNoise()
    -- Initialize noise with fixed seed for consistency
    love.math.setRandomSeed(os.time())
    
    -- Create a dynamic background noise structure with animation parameters
    self.backgroundNoise = {
        seed = love.math.random(1, 1000),
        flowSpeed = 0.5 + math.random() * 0.5,  -- Controls how fast patterns move
        waveAmplitude = 0.2 + math.random() * 0.3,  -- Controls wave height
        colorShiftSpeed = 0.2 + math.random() * 0.3,  -- Controls color transition speed
        pulseSpeed = 1.5 + math.random() * 1.0  -- Controls pulsing effect speed
    }
    
    -- Reset background time to create a fresh animation
    self.backgroundTime = math.random() * 10  -- Start at random point in animation cycle
    
    -- Set colors based on game state
    self:updateBackgroundColors()
end

function Game:draw()
    -- Only draw background if map exists
    if self.map then
        self:drawBackground()
        self.map:draw()
    end
    
    if self.state == "menu" then
        -- Check if menu exists before trying to draw it
        if not self.menu then
            -- If menu doesn't exist yet, initialize it
            local Menu = require "menu"
            self.menu = Menu:init(self)
        end
        
        self.menu:draw()
    elseif self.state == "playing" then
        -- Draw particles behind everything else
        for _, p in ipairs(self.particles or {}) do
            love.graphics.setColor(p.r, p.g, p.b, p.life / p.maxLife)
            love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife))
        end
        
        local p = self.players[self.localPlayerIndex]
        local cx, cy = p.x + 16, p.y + 32
        local mx, my = love.mouse.getPosition()
        local ang = math.atan2(my - cy, mx - cx)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.weaponImage, cx, cy, ang, 1, 1, self.weaponImage:getWidth() / 2, self.weaponImage:getHeight() / 2)
        for _, b in ipairs(self.bullets) do b:draw() end
        for _, b in ipairs(self.enemyBullets) do b:draw() end
        for _, e in ipairs(self.enemies) do e:draw() end
        for _, pl in ipairs(self.players) do
            pl.currentAnim:draw(pl.x, pl.y)
            -- Health bar background
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", pl.x, pl.y - 10, 32, 5)
            -- Health bar
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", pl.x, pl.y - 10, 32 * (pl.hp / pl.maxHP), 5)
            love.graphics.setColor(1, 1, 1)
        end
        self.centralCrystal:draw()
        
        -- UI Panel background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 5, 5, 200, 120)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", 5, 5, 200, 120)
        
        -- Draw UI
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", 10, 10, 200, 80 + (#self.players - 1) * 30)
        
        -- Draw player info
        for i, p in ipairs(self.players) do
            local y = 20 + (i - 1) * 30
            local playerClass = p.className or "Unknown"
            local hpText = string.format("%s Player %d HP: %d/%d", playerClass, i, p.hp, p.maxHP)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(hpText, 20, y)
            
            -- Draw HP bar
            love.graphics.setColor(0.5, 0, 0)
            love.graphics.rectangle("fill", 20, y + 20, 150, 5)
            love.graphics.setColor(0, 0.7, 0)
            love.graphics.rectangle("fill", 20, y + 20, 150 * (p.hp / p.maxHP), 5)
            
            -- Draw special ability cooldown if it's a player class
            if p.specialAbilityTimer ~= nil then
                local cooldownWidth = 50
                local cooldownText = ""
                
                if p.specialAbilityActive then
                    love.graphics.setColor(1, 0.7, 0)
                    local remainingTime = p.specialAbilityDuration - p.specialAbilityTimer
                    local percentage = remainingTime / p.specialAbilityDuration
                    love.graphics.rectangle("fill", 180, y, cooldownWidth * percentage, 10)
                    cooldownText = string.format("%.1fs", remainingTime)
                else
                    love.graphics.setColor(0, 0.5, 1)
                    local percentage = math.min(p.specialAbilityTimer / p.specialAbilityCooldown, 1)
                    love.graphics.rectangle("fill", 180, y, cooldownWidth * percentage, 10)
                    
                    if p.specialAbilityTimer >= p.specialAbilityCooldown then
                        cooldownText = "READY"
                    else
                        cooldownText = string.format("%.1fs", p.specialAbilityCooldown - p.specialAbilityTimer)
                    end
                end
                
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(cooldownText, 180, y + 12)
            end
        end
        
        -- Additional UI information for local player
        local localPlayer = self.players[self.localPlayerIndex]
        if localPlayer then
            -- Draw crystal and credit info
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Crystal HP: " .. self.centralCrystal.hp .. "/" .. self.centralCrystal.maxHP, 10, 20 + #self.players * 30)
            love.graphics.print("Credit: " .. localPlayer.credit, 10, 20 + #self.players * 30 + 20)
            
            -- Weapon info with upgrade cost
            love.graphics.print("Weapon Tier: " .. localPlayer.weaponTier, 10, 20 + #self.players * 30 + 40)
            
            -- Show upgrade info if available
            local nextTier = localPlayer.weaponTier + 1
            if config.weaponTiers[nextTier] then
                love.graphics.setColor(0.8, 0.8, 0.2)
                love.graphics.print("[U] Upgrade weapon (Cost: " .. config.weaponTiers[nextTier].cost .. ")", 10, 20 + #self.players * 30 + 60)
            end
        end
        
        -- Draw wave info
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Wave: " .. self.wave, 10, 20 + #self.players * 30 + 80)
        
        -- Show message if any
        if self.messageTimer > 0 then
            love.graphics.setColor(1, 1, 1, math.min(1, self.messageTimer * 2))
            love.graphics.printf(self.message, 0, self.map.height * self.map.tileSize / 4, 
                               self.map.width * self.map.tileSize, "center")
            love.graphics.setColor(1, 1, 1)
        end
        
        -- Draw pause overlay if paused
        if self.paused then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 0, 0, self.map.width * self.map.tileSize, self.map.height * self.map.tileSize)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("PAUSED", 0, self.map.height * self.map.tileSize / 2 - 40, 
                               self.map.width * self.map.tileSize, "center")
            love.graphics.printf("Press [ESC] to resume", 0, self.map.height * self.map.tileSize / 2, 
                               self.map.width * self.map.tileSize, "center")
        end
    end
end

function Game:createDeathParticles(x, y, enemyType)
    -- Create different particle effects based on enemy type
    local particleCount = 15
    local baseLife = 0.5
    local baseSize = 3
    
    -- Set colors based on enemy type
    local r, g, b = 1, 0.5, 0
    if enemyType == "ranged" then
        r, g, b = 0.5, 0, 1
    elseif enemyType == "explosive" then
        r, g, b = 1, 0, 0
        particleCount = 25  -- More particles for explosive enemies
        baseLife = 0.8
    end
    
    for i = 1, particleCount do
        local angle = math.random() * math.pi * 2
        local speed = math.random(30, 80)
        local particle = {
            x = x,
            y = y,
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed,
            life = baseLife + math.random() * 0.5,
            maxLife = baseLife + math.random() * 0.5,
            size = baseSize + math.random() * 2,
            r = r,
            g = g,
            b = b
        }
        table.insert(self.particles, particle)
    end
end

function Game:keypressed(k)
    if self.state == "menu" then
        self.menu:keypressed(k)
    elseif self.state == "playing" then
        if k == "escape" then 
            if self.paused then
                self.paused = false
            else
                self.paused = true 
            end
        elseif k == "u" and not self.paused then
            self:tryUpgradeWeapon()
        end
    elseif self.state == "gameover" or self.state == "victory" then
        if k == "return" then self.state = "menu" end
    end
end

function Game:mousepressed(x, y, button)
    if self.state == "menu" then
        self.menu:mousepressed(x, y, button)
    end
end

function Game:mousemoved(x, y, dx, dy)
    if self.state == "menu" then
        self.menu:mousemoved(x, y)
    end
end

return Game
