local class = require "class"
local Animation = class.createClass()
function Animation:init(img, quads, d)
    self.image = img
    self.quads = quads
    self.frameDuration = d or 0.1
    self.timer = 0
    self.frame = 1
end
function Animation:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.frameDuration then
        self.timer = self.timer - self.frameDuration
        self.frame = (self.frame % #self.quads) + 1
    end
end
function Animation:clone()
    local c = Animation:new(self.image, self.quads, self.frameDuration)
    c.frame = self.frame
    c.timer = self.timer
    return c
end
function Animation:draw(x, y)
    love.graphics.draw(self.image, self.quads[self.frame], x, y)
end
return Animation
