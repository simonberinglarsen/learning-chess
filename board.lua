local messagebus = require('messagebus')
local display = require('display')
local colors = require('colors')
local board = {}

local squareSize = 70
local pieceSpriteSize = 60
local letterToPieceMap = { r = 3, n = 5, b = 4, q = 2, k = 1, p = 6, R = 9, N = 11, B = 10, Q = 8, K = 7, P = 12 }

function board:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:constructor()
    return o
end

function board:constructor()
    self.piecesView = nil
    messagebus:subscribe(self, "mousemove", function(e) self:mousemove(e) end)
    messagebus:subscribe(self, "mousepressed", function(e) self:mousepressed(e) end)
    messagebus:subscribe(self, "mousereleased", function(e) self:mousereleased(e) end)

end

function board:destructor()
    if self.piecesView then
        display.remove(self.piecesView)
    end
    self.piecesView = nil
    messagebus.unsubscribe(self);
end

function board:newChessBoard(g)
    local c = { colors.lightSquare, colors.darkSquare }
    for x = 0, 7 do
        for y = 0, 7 do
            local c1 = c[(x + y) % 2 + 1]
            local r = display.newRect(g, x * squareSize, y * squareSize, squareSize, squareSize)
            r.fill = { c1[1], c1[2], c1[3] }
        end
    end
end

function board:newPos(g, fen)
    if self.piecesView then
        display.remove(self.piecesView)
    end
    self.piecesView = display.newGroup(g, "piecesview")
    local state = {}
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
                    local margin = (squareSize - pieceSpriteSize) / 2
                    local white = pieceCode > 6
                    local spriteY = 0
                    if white then spriteY = 1 end
                    local spriteX = (pieceCode - 1) % 6
                    local piece = display.newImage(self.piecesView, "chess.png", spriteX * pieceSpriteSize,
                        spriteY * pieceSpriteSize, pieceSpriteSize, pieceSpriteSize)
                    piece.x = squareSize * column + margin
                    piece.y = squareSize * row + margin
                    column = column + 1
                end
            end
        elseif row == 8 then
            state.activeColor = fenRow
            local c = display.newCirc(self.piecesView, squareSize * 8.5, squareSize / 2, pieceSpriteSize / 4)
            if fenRow == "w" then
                c.fill = colors.lightSquare
                c.y = c.y + squareSize * 7
            else
                c.fill = colors.darkSquare
            end
        elseif row == 9 then
            state.castling = fenRow
        elseif row == 10 then
            state.enPassant = fenRow
        elseif row == 11 then
            state.halfMoves = fenRow
        elseif row == 12 then
            state.fullMoves = fenRow
        end

        row = row + 1
    end
    local stateDescription = ""
    stateDescription = stateDescription .. "state.activeColor = " .. state.activeColor .. "\n"
    stateDescription = stateDescription .. "state.castling = " .. state.castling .. "\n"
    stateDescription = stateDescription .. "state.enPassant = " .. state.enPassant .. "\n"
    stateDescription = stateDescription .. "state.halfMoves = " .. state.halfMoves .. "\n"
    stateDescription = stateDescription .. "state.fullMoves = " .. state.fullMoves .. "\n"
    display.newText(self.piecesView, stateDescription, squareSize * 8.5, squareSize * 1)
    self.label = display.newText(self.piecesView, "??", squareSize * 8.5, squareSize * 3)
    self.mousepressLabel = display.newText(self.piecesView, "??", squareSize * 8.5, squareSize * 4)
    return state
end

function board:mousemove(e)
    self.label.str = e.x .. ", " .. e.y
end

function board:mousepressed(e)
    self.mousepressLabel.str = e.x .. ", " .. e.y
end

function board:mousereleased(e)
    self.mousepressLabel.str = e.x .. ", " .. e.y
end

return board
