local Menu = {}

function Menu:init(game)
    self.game = game
    self.buttons = {
        {text = "Single Player", action = function() game.state = "playing" game.coop = false game:init() end},
        {text = "Host Coop Game", action = function() game.state = "playing" game.coop = true game.networkRole = "host" game:init() end},
        {text = "Join Coop Game", action = function() game.state = "playing" game.coop = true game.networkRole = "client" game:init() end}
    }
    self.font = love.graphics.newFont(24)
    self.titleFont = love.graphics.newFont(36)
    
    -- Create procedural background
    self.background = love.graphics.newCanvas(game.map.width * game.map.tileSize, game.map.height * game.map.tileSize)
    love.graphics.setCanvas(self.background)
    
    -- Generate Perlin noise background
    local seed = math.random(10000)
    for x = 0, game.map.width * game.map.tileSize, 10 do
        for y = 0, game.map.height * game.map.tileSize, 10 do
            local n = love.math.noise(x * 0.01 + seed, y * 0.01 + seed)
            local r = 0.1 + n * 0.2
            local g = 0.1 + n * 0.3
            local b = 0.2 + n * 0.4
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x, y, 10, 10)
        end
    end
    
    love.graphics.setCanvas()
    
    self.buttonWidth = 300
    self.buttonHeight = 50
    self.buttonSpacing = 20
    
    -- Initialize animation properties
    self.animationTime = 0
    self.hoverButton = nil
    self.buttonScales = {}
    self.buttonAlphas = {}
    
    -- Set initial animation values for each button
    for i=1, #self.buttons do
        self.buttonScales[i] = 1.0
        self.buttonAlphas[i] = 0.8
    end
    
    return self
end

function Menu:update(dt)
    -- Update animation time
    self.animationTime = self.animationTime + dt
    
    -- Update button animations
    for i=1, #self.buttons do
        -- If this is the hovered button, increase scale and alpha
        if self.hoverButton == i then
            self.buttonScales[i] = math.min(1.1, self.buttonScales[i] + dt * 4)
            self.buttonAlphas[i] = math.min(1.0, self.buttonAlphas[i] + dt * 4)
        else
            -- Otherwise, return to normal
            self.buttonScales[i] = math.max(1.0, self.buttonScales[i] - dt * 4)
            self.buttonAlphas[i] = math.max(0.8, self.buttonAlphas[i] - dt * 4)
        end
    end
end

function Menu:draw()
    -- Draw background
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.background, 0, 0, 0, 
        self.game.map.width * self.game.map.tileSize / self.background:getWidth(),
        self.game.map.height * self.game.map.tileSize / self.background:getHeight())
    
    -- Draw animated title with subtle bounce effect
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 1, 1)
    local titleY = 100 + math.sin(self.animationTime * 2) * 5
    love.graphics.printf("DEFENSE GAME", 0, titleY, self.game.map.width * self.game.map.tileSize, "center")
    
    -- Draw buttons
    love.graphics.setFont(self.font)
    local totalHeight = (#self.buttons * self.buttonHeight) + ((#self.buttons - 1) * self.buttonSpacing)
    local startY = (self.game.map.height * self.game.map.tileSize - totalHeight) / 2
    
    for i, button in ipairs(self.buttons) do
        local x = (self.game.map.width * self.game.map.tileSize - self.buttonWidth) / 2
        local y = startY + (i - 1) * (self.buttonHeight + self.buttonSpacing)
        
        -- Calculate scaled dimensions and position
        local scale = self.buttonScales[i]
        local scaledWidth = self.buttonWidth * scale
        local scaledHeight = self.buttonHeight * scale
        local scaledX = x - (scaledWidth - self.buttonWidth) / 2
        local scaledY = y - (scaledHeight - self.buttonHeight) / 2
        
        -- Button background with animation
        love.graphics.setColor(0.2, 0.2, 0.2, self.buttonAlphas[i])
        love.graphics.rectangle("fill", scaledX, scaledY, scaledWidth, scaledHeight, 10)
        
        -- Button border with pulsing effect for hovered button
        if self.hoverButton == i then
            local pulseIntensity = 0.5 + math.sin(self.animationTime * 5) * 0.5
            love.graphics.setColor(0.8, 0.8, 1.0, pulseIntensity)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", scaledX, scaledY, scaledWidth, scaledHeight, 10)
        love.graphics.setLineWidth(1) -- Reset line width
        
        -- Button text
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(button.text, scaledX, scaledY + scaledHeight / 2 - self.font:getHeight() / 2, scaledWidth, "center")
    end
end

function Menu:keypressed(key)
    if key == "return" then
        self.buttons[1].action()
    elseif key == "h" then
        self.buttons[2].action()
    elseif key == "j" then
        self.buttons[3].action()
    end
end

function Menu:mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        for i, _ in ipairs(self.buttons) do
            if self:isMouseOverButton(i, x, y) then
                self.buttons[i].action()
                return
            end
        end
    end
end

function Menu:mousemoved(x, y)
    self.hoverButton = nil
    for i, _ in ipairs(self.buttons) do
        if self:isMouseOverButton(i, x, y) then
            self.hoverButton = i
            break
        end
    end
end

function Menu:isMouseOverButton(buttonIndex, x, y)
    local totalHeight = (#self.buttons * self.buttonHeight) + ((#self.buttons - 1) * self.buttonSpacing)
    local startY = (self.game.map.height * self.game.map.tileSize - totalHeight) / 2
    
    local buttonX = (self.game.map.width * self.game.map.tileSize - self.buttonWidth) / 2
    local buttonY = startY + (buttonIndex - 1) * (self.buttonHeight + self.buttonSpacing)
    
    -- Use the scaled dimensions for hit detection
    local scale = self.buttonScales[buttonIndex]
    local scaledWidth = self.buttonWidth * scale
    local scaledHeight = self.buttonHeight * scale
    local scaledX = buttonX - (scaledWidth - self.buttonWidth) / 2
    local scaledY = buttonY - (scaledHeight - self.buttonHeight) / 2
    
    return x >= scaledX and x <= scaledX + scaledWidth and
           y >= scaledY and y <= scaledY + scaledHeight
end

return Menu