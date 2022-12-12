local squares = require('squares')
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
    self.squareView = display.newGroup(self.view, "squares")
    self.pieces = {}
    messagebus:subscribe(self, "mousemove", function(e) self:mousemove(e) end)
    messagebus:subscribe(self, "mouseleave", function() self:mouseleave() end)
    messagebus:subscribe(self, "mousepressed", function(e) self:mousepressed(e) end)
    messagebus:subscribe(self, "mousereleased", function(e) self:mousereleased(e) end)

    self:newChessBoard()
end

function board:destructor()
    if self.piecesView then
        display.remove(self.piecesView)
    end
    self.piecesView = nil
    messagebus.unsubscribe(self);
end

function board:newChessBoard()
    local g = self.squareView
    local c = { colors.lightSquare, colors.darkSquare, colors.darkerSquare }
    local allSquares = squares:getAll()
    for i = 1, #allSquares do
        local s = allSquares[i]
        local x, y = s.file - 1, 8 - s.rank
        local c1 = c[(x + y) % 2 + 1]

        local r = display.newRect(g, x * squareSize, y * squareSize, squareSize, squareSize)
        r.anchorX = 0
        r.anchorY = 0
        r.fill = { c1[1], c1[2], c1[3] }

        local circ = display.newCirc(g, (x + 0.5) * squareSize, (y + 0.5) * squareSize, squareSize / 6)
        c1 = c[3]
        circ.fill = { c1[1], c1[2], c1[3], 0.75 }
        circ.isVisible = false
        circ.tag = s.name
    end

end

function board:newPos(fen)
    if self.piecesView then
        display.remove(self.piecesView)
    end
    self.pieces = {}
    self.piecesView = display.newGroup(self.view, "piecesview")
    local state = {}
    local line = 0
    local circ = display.newCirc(self.piecesView, 0, 0, pieceSpriteSize)
    circ.fill = { 0, 0, 0, 0.25 }
    circ.isVisible = false
    self.selectionCirc = circ
    for fenRow in string.gmatch(fen, "([^/ ]+)") do
        if line < 8 then
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
                    piece.squareIndex = column + line * 8 + 1
                    self:setOriginalPiecePosition(piece)
                    column = column + 1
                end
            end
        elseif line == 8 then
            state.activeColor = fenRow
            local c = display.newCirc(self.piecesView, squareSize * 8.5, squareSize / 2, pieceSpriteSize / 4)
            if fenRow == "w" then
                c.fill = colors.lightSquare
                c.y = c.y + squareSize * 7
            else
                c.fill = colors.darkSquare
            end
        elseif line == 9 then
            state.castling = fenRow
        elseif line == 10 then
            state.enPassant = fenRow
        elseif line == 11 then
            state.halfMoves = fenRow
        elseif line == 12 then
            state.fullMoves = fenRow
        end

        line = line + 1
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
    local s = squares:getByIndex(piece.squareIndex)
    piece.x = squareSize * (s.file - 0.5)
    piece.y = squareSize * (8.5 - s.rank)
end

function board:getSquareName(file, rank)
    return string.char(96 + file) .. rank
end

function board:getMove(piece)
    local from = squares:getByIndex(piece.squareIndex).name
    local to = squares:getByIndex(math.floor(piece.x / squareSize) + math.floor(piece.y / squareSize) * 8 + 1).name
    sunfish:chessmove({ from = from, to = to })
    self:newPos(sunfish:getFen())
end

function board:selectPiece(piece, selected)
    piece.selected = selected
    self.selectionCirc.isVisible = selected
    self:updateSelectionPos(piece)
    if selected then
        -- show possible moves
        local children = self.squareView.children
        local sn = squares:getByIndex(piece.squareIndex).name
        local moves = sunfish:legalMovesForPiece(sn)
        for i = 1, #moves do
            local move = sunfish:squareToText(moves[i][2])
            for j = 1, #children do
                local child = children[j]
                if child.tag == move then
                    child.isVisible = true
                end
            end
        end
    end
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
    local rank = math.floor(e.y / squareSize)
    local file = math.floor(e.x / squareSize)
    local squareIndex = rank * 8 + file + 1
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
    local children = self.squareView.children
    for j = 1, #children do
        local child = children[j]
        if child.tag ~= nil then
            child.isVisible = false
        end
    end
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
