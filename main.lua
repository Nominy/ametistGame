local Game = require "game"
local NetworkManager = require "network_manager"

function love.load()
    Game:init()
end

function love.update(dt)
    if not NetworkManager.isHost and Game.coop and Game.state=="playing" then
        local i = Game:getLocalInput()
        NetworkManager:send({type="playerInput", index=Game.localPlayerIndex, input=i})
    end
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(k)
    Game:keypressed(k)
end

function love.mousepressed(x, y, button)
    Game:mousepressed(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    Game:mousemoved(x, y, dx, dy)
end
