local Position = require('position')
local messagebus = require('messagebus')

local ChessGame = {
    isWhiteActive = true
}

function ChessGame:findMoveInList(t, k)
    assert(t)
    if not k then return false end
    for _, v in ipairs(t) do
        if k[1] == v[1] and k[2] == v[2] then
            return true
        end
    end
    return false
end

function ChessGame:squareIndexToName(square)
    local rank = 10 - math.floor(square / 10)
    if rank < 1 or rank > 8 then return "-" end
    local file = square % 10
    return string.char(96 + file) .. rank
end

function ChessGame:getFen()
    local pos = self.pos
    local board = pos.board
    board = board:gsub("\n", "/"):gsub(" ", ""):sub(3, #board - 2)
        :gsub("%.%.%.%.%.%.%.%.", "8")
        :gsub("%.%.%.%.%.%.%.", "7")
        :gsub("%.%.%.%.%.%.", "6")
        :gsub("%.%.%.%.%.", "5")
        :gsub("%.%.%.%.", "4")
        :gsub("%.%.%.", "3")
        :gsub("%.%.", "2")
        :gsub("%.", "1")
    local activeColor = self.isWhiteActive and "w" or "b"
    local castleConfig = (pos.wc[1] and "K" or "") .. (pos.wc[2] and "Q" or "")
        .. (pos.bc[1] and "k" or "") .. (pos.bc[2] and "q" or "")
    castleConfig = castleConfig == "" and "-" or castleConfig
    local enPassant = self:squareIndexToName(pos.ep)
    local fen = board .. " " .. activeColor .. " " .. castleConfig .. " " .. enPassant .. " 0 1"
    return fen
end

function ChessGame:emptySquares(board)
    local _, count = string.gsub(board, "%.", "")
    return count
end

function ChessGame:isWhitePiece(squareText)
    local square = Position:parse(squareText)
    local pieceLetter = Position:pieceAt(self.pos.board, square)
    return pieceLetter == string.upper(pieceLetter)
end

function ChessGame:reverseMove(e)
    local rows = { 8, 7, 6, 5, 4, 3, 2, 1 }
    local cols = { a = "h", b = "g", c = "f", d = "e", e = "d", f = "c", g = "b", h = "a" }
    local reverseRow = function(square) return cols[Position:pieceAt(square, 1)] ..
            rows[tonumber(Position:pieceAt(square, 2))]
    end
    return { from = reverseRow(e.from), to = reverseRow(e.to) }
end

function ChessGame:doMove(move)
    local pos = self.pos
    local emptyBefore = self:emptySquares(pos.board)
    pos = pos:move(move)
    local emptyAfter = self:emptySquares(pos.board)
    local fx = emptyAfter == emptyBefore and "move" or "takes"
    messagebus:publish("soundfx", { name = fx })
    return pos:rotate()
end

function ChessGame:legalMovesForPiece(from)
    local pieceMoves = {}
    local dest = Position:parse(from)
    local rotateInput = function()
        dest = 121 - dest
        self.pos = self.pos:rotate()
    end
    local rotateOutput = function()
        self.pos = self.pos:rotate()
        for i, pieceMove in ipairs(pieceMoves) do
            pieceMoves[i] = { 121 - pieceMove[1], 121 - pieceMove[2] }
        end
    end
    if not self.isWhiteActive then rotateInput() end
    local p = Position:pieceAt(self.pos.board, dest)
    if Position:isWhite(p) then
        for _, move in ipairs(self.pos:generateMoves()) do
            if move[1] == dest then pieceMoves[#pieceMoves + 1] = move end
        end
    end
    if not self.isWhiteActive then rotateOutput() end
    return pieceMoves
end

function ChessGame:chessmove(e)
    local move = { Position:parse(e:sub(1, 2)), Position:parse(e:sub(3, 4)) }
    local rotateInput = function()
        move = { 121 - move[1], 121 - move[2] }
        self.pos = self.pos:rotate()
    end
    local rotateOutput = function()
        self.pos = self.pos:rotate()
    end
    local setOtherPlayerAsActive = function()
        self.isWhiteActive = not self.isWhiteActive
    end
    local tryMove = function()
        if move[1] and move[2] and self:findMoveInList(self.pos:generateMoves(), move) then
            self.pos = self:doMove(move)
            return true
        end
        return false
    end
    if not self.isWhiteActive then rotateInput() end
    local legalMove = tryMove()
    if not self.isWhiteActive then rotateOutput() end
    if legalMove then setOtherPlayerAsActive() end
    return true
end

function ChessGame:reset()
    self.pos = Position:new(Position.initial, { true, true }, { true, true }, 0, 0)
end

ChessGame:reset()


return ChessGame
