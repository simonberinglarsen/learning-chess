local display = require('display')

local colors = {
    darkSquare = { 8 / 15, 10 / 15, 6 / 15 },
    lightSquare = { 15 / 15, 15 / 15, 13 / 15 },
    background = { 2 / 15, 2 / 15, 2 / 15 }
}

local squareSize = 70
local piecesView


function newChessBoard(g)
    local c = { colors.lightSquare, colors.darkSquare }
    for x = 0, 7 do
        for y = 0, 7 do
            local c1 = c[(x + y) % 2 + 1]
            local r = display.newRect(g, x * squareSize, y * squareSize, squareSize, squareSize)
            r.fill = { c1[1], c1[2], c1[3] }
        end
    end
end

function newPieces(g, fen)
    if piecesView then
        display.remove(piecesView)
    end
    piecesView = display.newGroup(g, "piecesview")
    local letterToPieceMap = { r = 3, n = 5, b = 4, q = 2, k = 1, p = 6, R = 9, N = 11, B = 10, Q = 8, K = 7, P = 12 }
    local row = 0
    for fenRow in string.gmatch(fen, "([^/ ]+)") do
        if row < 8 then
            local column = 0
            for fenRowIndex = 1, #fenRow do
                local ch = fenRow:sub(fenRowIndex, fenRowIndex)
                local emptySquares = tonumber(ch, 10)
                if emptySquares then
                    column = column + emptySquares
                else
                    local pieceCode = letterToPieceMap[ch]
                    local margin = (squareSize - 60) / 2
                    local white = pieceCode > 6
                    local spriteY = 0
                    if white then spriteY = 1 end
                    local spriteX = (pieceCode - 1) % 6
                    local piece = display.newImage(piecesView, "chess.png", spriteX * 60, spriteY * 60, 60, 60)
                    piece.x = squareSize * column + margin
                    piece.y = squareSize * row + margin
                    column = column + 1
                end
            end

        end
        row = row + 1
    end
end

function love.load()
    local col = colors.background
    love.graphics.setBackgroundColor(col[1], col[2], col[3], 1)
    local g
    g = display.newGroup(display.root, "board")
    newChessBoard(g)
    g = display.newGroup(display.root, "pieces")
    newPieces(g, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
end

function love.draw()
    display.render()
end
