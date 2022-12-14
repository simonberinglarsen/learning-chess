local squares = require('squares')
local messagebus = require('messagebus')
local chessgame = require('chessgame')
local display = require('display')
local colors = require('colors')
local board = {}

local boardSize = 600

-- calculated variables
local squareSize = boardSize / 8
local pieceSpriteSize = 60
local pieceSize = squareSize * 0.857
local pieceScale = pieceSize / pieceSpriteSize

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
    messagebus:subscribe(self, "mousereleased", function(e) self:mousereleased() end)
    self:newChessBoard()
end

function board:destroy()
    display.remove(self.view)
    messagebus.unsubscribe(self);
end

function board:newChessBoard()
    local g = self.squareView
    for _, s in ipairs(squares:getAll()) do
        local x, y = (s.file - 1) * squareSize, (8 - s.rank) * squareSize
        local color = s.isLight and colors.lightSquare or colors.darkSquare
        self:newSquareRect(g, x, y, color)
        self:newTargetIndicator(g, x, y, s)
    end
end

function board:newSquareRect(g, x, y, col)
    local r = display.newRect(g, x, y, squareSize, squareSize)
    r.anchorX = 0
    r.anchorY = 0
    r.fill = { col[1], col[2], col[3], col[4] }
end

function board:newTargetIndicator(g, x, y, s)
    local circ = display.newCirc(g, x + 0.5 * squareSize, y + 0.5 * squareSize, squareSize / 6)
    local col = colors.darkerSquare
    circ.fill = { col[1], col[2], col[3], 0.75 }
    circ.isVisible = false
    circ.tag = s.name
end

function board:setPosition(fen)
    if self.piecesView then
        display.remove(self.piecesView)
    end
    self.pieces = {}
    self.piecesView = display.newGroup(self.view, "piecesview")
    self:newSelectionIndicator()
    local state = self:newStateFromFen(fen)
    self:dumpBoardState(state)
end

function board:newSelectionIndicator()
    local circ = display.newCirc(self.piecesView, 0, 0, pieceSize)
    circ.fill = { 0, 0, 0, 0.25 }
    circ.isVisible = false
    self.selectionIndicator = circ
end

function board:newStateFromFen(fen)
    local state = {}
    local line = 0
    for fenWord in string.gmatch(fen, "([^/ ]+)") do
        if line < 8 then
            self:addPiecesFromFenWord(fenWord, line)
        elseif line == 8 then
            state.activeColor = fenWord
            self:newActiveColorIndicator(fenWord)
        elseif line == 9 then
            state.castling = fenWord
        elseif line == 10 then
            state.enPassant = fenWord
        elseif line == 11 then
            state.halfMoves = fenWord
        elseif line == 12 then
            state.fullMoves = fenWord
        end

        line = line + 1
    end
    return state
end

function board:newActiveColorIndicator(fenWord)
    local c = display.newCirc(self.piecesView, squareSize * 8.5, squareSize / 2, pieceSize / 4)
    if fenWord == "w" then
        c.fill = colors.lightSquare
        c.y = c.y + squareSize * 7
    else
        c.fill = colors.darkSquare
    end
end

function board:addPiecesFromFenWord(fenWord, rank)
    local file = 0
    for fenWordIndex = 1, #fenWord do
        local ch = fenWord:sub(fenWordIndex, fenWordIndex)
        local emptySquares = tonumber(ch, 10)
        if emptySquares then
            file = file + emptySquares
        else
            self:newPiece(ch, file, rank)
            file = file + 1
        end
    end
end

function board:newPiece(ch, file, rank)
    local letterToPieceMap = { r = 3, n = 5, b = 4, q = 2, k = 1, p = 6, R = 9, N = 11, B = 10, Q = 8, K = 7, P = 12 }
    local pieceCode = letterToPieceMap[ch]
    local white = pieceCode > 6
    local spriteY = 0
    if white then spriteY = 1 end
    local spriteX = (pieceCode - 1) % 6
    local piece = display.newImage(self.piecesView, "assets/gfx/chess.png", spriteX * pieceSpriteSize,
        spriteY * pieceSpriteSize, pieceSpriteSize, pieceSpriteSize)
    self.pieces[#self.pieces + 1] = piece
    piece.squareIndex = file + rank * 8 + 1
    piece.scaleX = pieceScale
    piece.scaleY = pieceScale
    self:setOriginalPiecePosition(piece)
end

function board:dumpBoardState(state)
    local stateDescription = ""
    stateDescription = stateDescription .. "state.activeColor = " .. state.activeColor .. "\n"
    stateDescription = stateDescription .. "state.castling = " .. state.castling .. "\n"
    stateDescription = stateDescription .. "state.enPassant = " .. state.enPassant .. "\n"
    stateDescription = stateDescription .. "state.halfMoves = " .. state.halfMoves .. "\n"
    stateDescription = stateDescription .. "state.fullMoves = " .. state.fullMoves .. "\n"
    display.newText(self.piecesView, stateDescription, squareSize * 8.5, squareSize * 1)
end

function board:setOriginalPiecePosition(piece)
    local s = squares:getByIndex(piece.squareIndex)
    piece.x = squareSize * (s.file - 0.5)
    piece.y = squareSize * (8.5 - s.rank)
end

function board:tryMove(piece)
    local from = squares:getByIndex(piece.squareIndex).name
    local to = squares:getByIndex(math.floor(piece.x / squareSize) + math.floor(piece.y / squareSize) * 8 + 1).name
    chessgame:chessmove(from .. to)
    self:setPosition(chessgame:getFen())
end

function board:getTargetSquares(piece)
    local squareNames = {}
    local squareName = squares:getByIndex(piece.squareIndex).name
    for _, move in ipairs(chessgame:legalMovesForPiece(squareName)) do
        squareNames[#squareNames + 1] = chessgame:squareIndexToName(move[2] - 1)
    end
    return squareNames
end

function board:getSquareRect(squareName)
    for _, child in ipairs(self.squareView.children) do
        if child.tag == squareName then return child end
    end
    return nil
end

function board:deselectPiece(piece) self:changePieceSelection(piece, false) end

function board:selectPiece(piece) self:changePieceSelection(piece, true) end

function board:changePieceSelection(piece, selected)
    piece.selected = selected
    self.selectionIndicator.isVisible = selected
    self:updateSelectionPos(piece)
    for _, squareName in ipairs(self:getTargetSquares(piece)) do
        local rect = self:getSquareRect(squareName)
        rect.isVisible = selected
        local piece = self:getPieceBySquareIndex(squares:getByName(squareName).index)
        if piece then
            rect.scaleX = 3
        else
            rect.scaleX = 1
        end

    end
end

function board:updateSelectionPos(piece)
    self.selectionIndicator.x = (math.floor(piece.x / squareSize) + 0.5) * squareSize
    self.selectionIndicator.y = (math.floor(piece.y / squareSize) + 0.5) * squareSize
end

function board:mousemove(e)
    local outOfBounds = e.x < 0 or e.x > 8 * squareSize or e.y < 0 or e.y > 8 * squareSize
    local piece = self:getSelectedPiece()
    if piece == nil then return end
    if outOfBounds then
        self:deselectPiece(piece)
        self:setOriginalPiecePosition(piece)
        piece.scaleX = pieceScale
        piece.scaleY = pieceScale
    else
        piece.x = e.x
        piece.y = e.y
        piece.scaleX = pieceScale * 1.5
        piece.scaleY = pieceScale * 1.5
        display.toFront(piece)
        self:updateSelectionPos(piece)
    end
end

function board:getPieceBySquareIndex(squareIndex)
    for _, piece in ipairs(self.pieces) do
        if piece.squareIndex == squareIndex then
            return piece
        end
    end
    return nil
end

function board:mousepressed(e)
    local rank = math.floor(e.y / squareSize)
    local file = math.floor(e.x / squareSize)
    local squareIndex = rank * 8 + file + 1
    local piece = self:getPieceBySquareIndex(squareIndex)
    if piece then self:selectPiece(piece) end
end

function board:getSelectedPiece()
    for _, piece in ipairs(self.pieces) do
        if piece.selected then return piece end
    end
    return nil
end

function board:mousereleased()
    local piece = self:getSelectedPiece()
    if piece then
        self:deselectPiece(piece)
        self:tryMove(piece)
    end
end

function board:mouseleave()
    self:mousereleased()
end

return board
