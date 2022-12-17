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
local Position = {
    initial = initial
}

function Position:isWhite(piece) return whitePieces:find(piece, 1, true) and true or false end

function Position:isBlack(piece) return blackPieces:find(piece, 1, true) and true or false end

function Position:pieceAt(board, i) return board:sub(i, i) end

local function replaceAt(s, i, p) return s:sub(1, i - 1) .. p .. s:sub(i + 1) end

local function swapcase(s)
    for i = 1, #s do s = replaceAt(s, i, swapCaseMap[s:sub(i, i)]) end
    return s
end

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
        if d == N * 2 and (src < A2 or self:pieceAt(self.board, src + N) ~= '.') then return true end
        return false
    end
    local friendlyCapture = function(t) return self:isWhite(t) end
    local castles = function()
        if src == A1 and targetPiece == 'K' and self.wc[1] then addMove({ dest, dest - 2 }) return true end
        if src == H1 and targetPiece == 'K' and self.wc[2] then addMove({ dest, dest + 2 }) return true end
        return false
    end
    local slidingPiece = function() return not (isPawn or isKnight or isKing) end
    local isCapture = function() return self:isBlack(targetPiece) end
    for _, direction in ipairs(directions[p]) do
        dest = src
        while true do
            dest = dest + direction
            targetPiece = self:pieceAt(self.board, dest)
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
        local p = self:pieceAt(self.board, from)
        if self:isWhite(p) and directions[p] then
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
    local p, q = self:pieceAt(self.board, i), self:pieceAt(self.board, j)

    -- Copy variables and reset ep and kp
    local board = self.board
    local wc, bc, ep, kp = self.wc, self.bc, 1, 1
    -- Actual move
    board = replaceAt(board, j, self:pieceAt(board, i))
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
    local q = self:pieceAt(self.board, j)
    if q == 'k' then return true end
    -- Castling check detection
    if j == self.kp then return true end
    return false
end

function Position:parse(c)
    if not c then return nil end
    local p, v = c:sub(1, 1), c:sub(2, 2)
    if not (p and v and tonumber(v)) then return nil end
    local fil, rank = string.byte(p) - string.byte('a'), tonumber(v)
    return A1 + fil - 10 * (rank - 1)
end

return Position
