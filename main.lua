local audio = require('audio')
local colors = require('colors')
local board = require('board')
local display = require('display')
local messagebus = require('messagebus')



function love.load()
    local board = board:new()
    local col = colors.background
    love.graphics.setBackgroundColor(col[1], col[2], col[3], 1)
    board:newChessBoard(display.newGroup(display.root, "board"))
    local g = display.newGroup(display.root, "pieces")
    board:newPos(g, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    board:newPos(g, "3K4/R7/p4k1p/r2P3P/2B5/6p1/PNP3N1/4Qb2 w - - 0 1")
    board:newPos(g, "8/6NQ/1p6/2R2P2/1ppkPK2/1P5Q/r1P3pp/8 w - - 0 1")
    audio.loadSound("move", "assets/audio/move1.mp3", "static")
    audio.loadSound("move", "assets/audio/move2.mp3", "static")
    audio.loadSound("move", "assets/audio/move3.mp3", "static")
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
