local messagebus = require('messagebus')

local sunfish = {
    isWhiteActive = true
}

-- Our board is represented as a 120 character string. The padding allows for
-- fast detection of moves that don't stay within the board.
local whitePieces = "RNBQKP"
local blackPieces = "rnbqkp"
local swapCaseMap = {
    r = "R", n = "N", b = "B", q = "Q", k = "K", p = "P",
    R = "r", N = "n", B = "b", Q = "q", K = "k", P = "p",
    ["."] = ".", [" "] = " ", ["\n"] = "\n",
}
local initial =
'         \n' .. ------   1 -  10
    '         \n' .. --  11 -  20
    ' rnbqkbnr\n' .. --  21 -  30
    ' pppppppp\n' .. --  31 -  40
    ' ........\n' .. --  41 -  50
    ' ........\n' .. --  51 -  60
    ' ........\n' .. --  61 -  70
    ' ........\n' .. --  71 -  80
    ' PPPPPPPP\n' .. --  81 -  90
    ' RNBQKBNR\n' .. --  91 - 100
    '         \n' .. -- 101 - 110
    '          ' ------ 111 - 120

-------------------------------------------------------------------------------
-- Move and evaluation tables
-------------------------------------------------------------------------------
local N, E, S, W = -10, 1, 10, -1
local A1, H1, A8, H8 = 92, 99, 22, 29
local A2 = A1 + N
local directions = {
    P = { N, 2 * N, N + W, N + E },
    N = { 2 * N + E, N + 2 * E, S + 2 * E, 2 * S + E, 2 * S + W, S + 2 * W, N + 2 * W, 2 * N + W },
    B = { N + E, S + E, S + W, N + W },
    R = { N, E, S, W },
    Q = { N, E, S, W, N + E, S + E, S + W, N + W },
    K = { N, E, S, W, N + E, S + E, S + W, N + W }
}

-------------------------------------------------------------------------------
-- Chess logic
-------------------------------------------------------------------------------
local function isWhite(piece) return whitePieces:find(piece, 1, true) and true or false end

local function isBlack(piece) return blackPieces:find(piece, 1, true) and true or false end

local function pieceAt(board, i) return board:sub(i, i) end

local function replaceAt(s, i, p) return s:sub(1, i - 1) .. p .. s:sub(i + 1) end

local function swapcase(s)
    for i = 1, #s do s = replaceAt(s, i, swapCaseMap[s:sub(i, i)]) end
    return s
end

local Position = {}

function Position:new(board, wc, bc, ep, kp)
    --[[  A state of a chess game
      board -- a 120 char representation of the board
      wc -- the castling rights
      bc -- the opponent castling rights
      ep - the en passant square
      kp - the king passant square
   ]] --
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.board = board
    o.wc = wc
    o.bc = bc
    o.ep = ep
    o.kp = kp
    return o
end

function Position:addMovesForPiece(p, src, moves, allowPseudoMoves)
    local isKnight, isKing, isPawn = p == 'N', p == 'K', p == 'P'
    local dest, targetPiece
    local outsideBoard = function() return (dest < A8 or dest > H1) or dest % 10 < 2 end
    local addMove = function(move)
        if allowPseudoMoves or self:isLegal(move) then
            moves[#moves + 1] = move
        end
    end
    local invalidPawnMove = function(d)
        if not isPawn then return false end
        if (d == N + W or d == N + E) and targetPiece == '.' and dest ~= self.ep and dest ~= self.kp then return true end
        if (d == N * 2 or d == N) and targetPiece ~= '.' then return true end
        if d == N * 2 and (src < A2 or pieceAt(self.board, src + N) ~= '.') then return true end
        return false
    end
    local friendlyCapture = function(t) return isWhite(t) end
    local castles = function()
        if src == A1 and targetPiece == 'K' and self.wc[1] then addMove({ dest, dest - 2 }) return true end
        if src == H1 and targetPiece == 'K' and self.wc[2] then addMove({ dest, dest + 2 }) return true end
        return false
    end
    local slidingPiece = function() return not (isPawn or isKnight or isKing) end
    local isCapture = function() return isBlack(targetPiece) end
    for _, direction in ipairs(directions[p]) do
        dest = src
        while true do
            dest = dest + direction
            targetPiece = pieceAt(self.board, dest)
            if outsideBoard() then break end
            if castles() then break end
            if friendlyCapture(targetPiece) then break end
            if invalidPawnMove(direction) then break end
            addMove({ src, dest })
            if not slidingPiece() then break end
            if isCapture() then break end
        end
    end
end

function Position:isLegal(move)
    local pos = self:move(move)
    local moves = pos:generateMoves(true)
    for _, move in ipairs(moves) do
        if pos:takesKing(move) then return false end
    end
    return true
end

function Position:generateMoves(allowPseudoMoves)
    local moves = {}
    for from = 1, #self.board do
        local p = pieceAt(self.board, from)
        if isWhite(p) and directions[p] then
            self:addMovesForPiece(p, from, moves, allowPseudoMoves)
        end
    end
    return moves
end

function Position:rotate()
    return Position:new(swapcase(self.board:reverse()), self.bc, self.wc, 121 - self.ep, 121 - self.kp)
end

function Position:move(move)
    assert(move) -- move is zero-indexed
    local i, j = move[1], move[2]
    local p, q = pieceAt(self.board, i), pieceAt(self.board, j)

    -- Copy variables and reset ep and kp
    local board = self.board
    local wc, bc, ep, kp = self.wc, self.bc, 1, 1
    -- Actual move
    board = replaceAt(board, j, pieceAt(board, i))
    board = replaceAt(board, i, '.')
    -- Castling rights
    if i == A1 then wc = { false, wc[1] }; end
    if i == H1 then wc = { wc[1], false }; end
    if j == A8 then bc = { bc[1], false }; end
    if j == H8 then bc = { false, bc[2] }; end
    -- Castling
    if p == 'K' then
        wc = { false, false }
        if math.abs(j - i) == 2 then
            kp = math.floor((i + j) / 2)
            board = replaceAt(board, j < i and A1 or H1, '.')
            board = replaceAt(board, kp, 'R')
        end
    end
    -- Special pawn stuff
    if p == 'P' then
        if A8 <= j and j <= H8 then board = replaceAt(board, j, 'Q') end
        if j - i == 2 * N then ep = i + N end
        if ((j - i) == N + W or (j - i) == N + E) and q == '.' then board = replaceAt(board, j + S, '.') end
    end
    -- We rotate the returned position, so it's ready for the next player
    return Position:new(board, wc, bc, ep, kp):rotate()
end

function Position:takesKing(move)
    local j = move[2]
    local q = pieceAt(self.board, j)
    if q == 'k' then return true end
    -- Castling check detection
    if j == self.kp then return true end
    return false
end

local function parse(c)
    if not c then return nil end
    local p, v = c:sub(1, 1), c:sub(2, 2)
    if not (p and v and tonumber(v)) then return nil end
    local fil, rank = string.byte(p) - string.byte('a'), tonumber(v)
    return A1 + fil - 10 * (rank - 1)
end

local function findMoveInList(t, k)
    assert(t)
    if not k then return false end
    for _, v in ipairs(t) do
        if k[1] == v[1] and k[2] == v[2] then
            return true
        end
    end
    return false
end

function sunfish:squareIndexToName(square)
    local rank = 10 - math.floor(square / 10)
    if rank < 1 or rank > 8 then return "-" end
    local file = square % 10
    return string.char(96 + file) .. rank
end

function sunfish:getFen()
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

function sunfish:emptySquares(board)
    local _, count = string.gsub(board, "%.", "")
    return count
end

function sunfish:isWhitePiece(squareText)
    local square = parse(squareText)
    local pieceLetter = pieceAt(self.pos.board, square)
    return pieceLetter == string.upper(pieceLetter)
end

function sunfish:reverseMove(e)
    local rows = { 8, 7, 6, 5, 4, 3, 2, 1 }
    local cols = { a = "h", b = "g", c = "f", d = "e", e = "d", f = "c", g = "b", h = "a" }
    local reverseRow = function(square) return cols[pieceAt(square, 1)] .. rows[tonumber(pieceAt(square, 2))] end
    return { from = reverseRow(e.from), to = reverseRow(e.to) }
end

function sunfish:doMove(move)
    local pos = self.pos
    local emptyBefore = self:emptySquares(pos.board)
    pos = pos:move(move)
    local emptyAfter = self:emptySquares(pos.board)
    local fx = emptyAfter == emptyBefore and "move" or "takes"
    messagebus:publish("soundfx", { name = fx })
    return pos:rotate()
end

function sunfish:legalMovesForPiece(from)
    local pieceMoves = {}
    local dest = parse(from)
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
    local p = pieceAt(self.pos.board, dest)
    if isWhite(p) then
        for _, move in ipairs(self.pos:generateMoves()) do
            if move[1] == dest then pieceMoves[#pieceMoves + 1] = move end
        end
    end
    if not self.isWhiteActive then rotateOutput() end
    return pieceMoves
end

function sunfish:chessmove(e)
    local move = { parse(e:sub(1, 2)), parse(e:sub(3, 4)) }
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
        if move[1] and move[2] and findMoveInList(self.pos:generateMoves(), move) then
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

function sunfish:reset()
    self.pos = Position:new(initial, { true, true }, { true, true }, 0, 0)
end

sunfish:reset()


return sunfish
