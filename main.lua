local audio = require('audio')
local colors = require('colors')
local board = require('board')
local display = require('display')
local messagebus = require('messagebus')

function love.load()
    audio.loadSound("move", "assets/audio/move1.mp3", "static")
    audio.loadSound("move", "assets/audio/move2.mp3", "static")
    audio.loadSound("move", "assets/audio/move3.mp3", "static")
    audio.loadSound("move", "assets/audio/move4.mp3", "static")
    audio.loadSound("move", "assets/audio/move5.mp3", "static")
    audio.loadSound("takes", "assets/audio/takes1.mp3", "static")
    audio.loadSound("takes", "assets/audio/takes2.mp3", "static")
    audio.loadSound("takes", "assets/audio/takes3.mp3", "static")
    audio.loadSound("takes", "assets/audio/takes4.mp3", "static")
    local board = board:new(display.root)
    local col = colors.background
    love.graphics.setBackgroundColor(col[1], col[2], col[3], 1)
    board:setPosition("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

end

function love.draw()
    display.render()
end

function love.mousemoved(x, y, dx, dy)
    messagebus:publish("mousemove", { x = x, y = y, dx = dx, dy = dy })
end

function love.mousepressed(x, y, button)
    if button == 1 then
        messagebus:publish("mousepressed", { x = x, y = y })
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        messagebus:publish("mousereleased", { x = x, y = y })
    end
end

function love.mousefocus(f)
    if not f then
        messagebus:publish("mouseleave")
    else
        messagebus:publish("mouseenter")
    end
end

-- run unit tests
local unittest = require('unittest')
local errors = unittest:run()
print("errors = " .. errors)
