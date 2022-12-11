local messagebus = require('messagebus')
local sunfish = require('sunfish')
local display = require('display')
local colors = require('colors')
local board = {}

local squareSize = 70
local pieceSpriteSize = 60
local letterToPieceMap = { r = 3, n = 5, b = 4, q = 2, k = 1, p = 6, R = 9, N = 11, B = 10, Q = 8, K = 7, P = 12 }

function board:new(g)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:constructor(g)
    return o
end

function board:constructor(g)
    self.view = display.newGroup()
    display.insert(g, self.view)
    self.piecesView = nil
    self.pieces = {}
    messagebus:subscribe(self, "mousemove", function(e) self:mousemove(e) end)
    messagebus:subscribe(self, "mouseleave", function() self:mouseleave() end)
    messagebus:subscribe(self, "mousepressed", function(e) self:mousepressed(e) end)
    messagebus:subscribe(self, "mousereleased", function(e) self:mousereleased(e) end)

    board:newChessBoard(display.newGroup(self.view, "board"))
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
            r.anchorX = 0
            r.anchorY = 0
            r.fill = { c1[1], c1[2], c1[3] }
        end
    end
end

function board:newPos(fen)
    if self.piecesView then
        display.remove(self.piecesView)
    end
    self.pieces = {}
    self.piecesView = display.newGroup(self.view, "piecesview")
    local state = {}
    local row = 0
    local circ = display.newCirc(self.piecesView, 0, 0, pieceSpriteSize)
    circ.fill = { 0, 0, 0, 0.25 }
    circ.isVisible = false
    self.selectionCirc = circ
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
                    local white = pieceCode > 6
                    local spriteY = 0
                    if white then spriteY = 1 end
                    local spriteX = (pieceCode - 1) % 6
                    local piece = display.newImage(self.piecesView, "assets/gfx/chess.png", spriteX * pieceSpriteSize,
                        spriteY * pieceSpriteSize, pieceSpriteSize, pieceSpriteSize)
                    self.pieces[#self.pieces + 1] = piece
                    piece.squareIndex = column + row * 8
                    self:setOriginalPiecePosition(piece)
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
    return state
end

function board:setOriginalPiecePosition(piece)
    local column = math.floor(piece.squareIndex % 8)
    local row = math.floor(piece.squareIndex / 8)
    local newx, newy = squareSize * (column + 0.5), squareSize * (row + 0.5)
    piece.x = newx
    piece.y = newy
end

function board:getMove(piece)
    local columnMap = "abcdefgh"
    local rowMap = "87654321"
    local fromCol = math.floor(piece.squareIndex % 8) + 1
    local fromRow = math.floor(piece.squareIndex / 8) + 1
    local from = columnMap:sub(fromCol, fromCol) .. rowMap:sub(fromRow, fromRow)
    local toCol = math.floor(piece.x / squareSize) + 1
    local toRow = math.floor(piece.y / squareSize) + 1
    local to = columnMap:sub(toCol, toCol) .. rowMap:sub(toRow, toRow)
    sunfish:chessmove({ from = from, to = to })
    self:newPos(sunfish:getFen())
end

function board:selectPiece(piece, selected)
    piece.selected = selected
    self.selectionCirc.isVisible = selected
    self:updateSelectionPos(piece)
end

function board:updateSelectionPos(piece)
    self.selectionCirc.x = (math.floor(piece.x / squareSize) + 0.5) * squareSize
    self.selectionCirc.y = (math.floor(piece.y / squareSize) + 0.5) * squareSize
end

function board:mousemove(e)
    local pieces = self.pieces
    local outOfBounds = e.x < 0 or e.x > 8 * squareSize or e.y < 0 or e.y > 8 * squareSize
    for i = 1, #pieces do
        local piece = pieces[i]
        if piece.selected then
            if outOfBounds then
                self:selectPiece(piece, false)
                self:setOriginalPiecePosition(piece)
            else
                piece.x = e.x
                piece.y = e.y
                piece.scaleX = 1.5
                piece.scaleY = 1.5
                display.toFront(piece)
                self:updateSelectionPos(piece)
            end
        end
    end
end

function board:mousepressed(e)
    local row = math.floor(e.y / squareSize)
    local column = math.floor(e.x / squareSize)
    local squareIndex = row * 8 + column
    local pieces = self.pieces
    for i = 1, #pieces do
        local piece = pieces[i]
        if piece.squareIndex == squareIndex then
            self:selectPiece(piece, true)
        end
    end
end

function board:mousereleased(e)
    local pieces = self.pieces
    for i = 1, #pieces do
        local piece = pieces[i]
        if piece.selected then
            self:selectPiece(piece, false)
            self:getMove(piece)
        end
    end
end

function board:mouseleave()
    self:mousereleased()
end

return board
