local messagebus = require('messagebus')

local sunfish = {
    isWhiteActive = true
}
-- Mate value must be greater than 8*queen + 2*(rook+knight+bishop)
-- King value is set to twice this value such that if the opponent is
-- 8 queens up, but we got the king, we still exceed MATE_VALUE.
local MATE_VALUE = 30000

-- Our board is represented as a 120 character string. The padding allows for
-- fast detection of moves that don't stay within the board.
local A1, H1, A8, H8 = 91, 98, 21, 28
local initial =
'         \n' .. --   0 -  9
    '         \n' .. --  10 - 19
    ' rnbqkbnr\n' .. --  20 - 29
    ' pppppppp\n' .. --  30 - 39
    ' ........\n' .. --  40 - 49
    ' ........\n' .. --  50 - 59
    ' ........\n' .. --  60 - 69
    ' ........\n' .. --  70 - 79
    ' PPPPPPPP\n' .. --  80 - 89
    ' RNBQKBNR\n' .. --  90 - 99
    '         \n' .. -- 100 -109
    '          ' -- 110 -119

-------------------------------------------------------------------------------
-- Move and evaluation tables
-------------------------------------------------------------------------------
local N, E, S, W = -10, 1, 10, -1
local directions = {
    P = { N, 2 * N, N + W, N + E },
    N = { 2 * N + E, N + 2 * E, S + 2 * E, 2 * S + E, 2 * S + W, S + 2 * W, N + 2 * W, 2 * N + W },
    B = { N + E, S + E, S + W, N + W },
    R = { N, E, S, W },
    Q = { N, E, S, W, N + E, S + E, S + W, N + W },
    K = { N, E, S, W, N + E, S + E, S + W, N + W }
}

local pst = {
    P = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 198, 198, 198, 198, 198, 198, 198, 198, 0,
        0, 178, 198, 198, 198, 198, 198, 198, 178, 0,
        0, 178, 198, 198, 198, 198, 198, 198, 178, 0,
        0, 178, 198, 208, 218, 218, 208, 198, 178, 0,
        0, 178, 198, 218, 238, 238, 218, 198, 178, 0,
        0, 178, 198, 208, 218, 218, 208, 198, 178, 0,
        0, 178, 198, 198, 198, 198, 198, 198, 178, 0,
        0, 198, 198, 198, 198, 198, 198, 198, 198, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    B = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 797, 824, 817, 808, 808, 817, 824, 797, 0,
        0, 814, 841, 834, 825, 825, 834, 841, 814, 0,
        0, 818, 845, 838, 829, 829, 838, 845, 818, 0,
        0, 824, 851, 844, 835, 835, 844, 851, 824, 0,
        0, 827, 854, 847, 838, 838, 847, 854, 827, 0,
        0, 826, 853, 846, 837, 837, 846, 853, 826, 0,
        0, 817, 844, 837, 828, 828, 837, 844, 817, 0,
        0, 792, 819, 812, 803, 803, 812, 819, 792, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    },
    N = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 627, 762, 786, 798, 798, 786, 762, 627, 0,
        0, 763, 798, 822, 834, 834, 822, 798, 763, 0,
        0, 817, 852, 876, 888, 888, 876, 852, 817, 0,
        0, 797, 832, 856, 868, 868, 856, 832, 797, 0,
        0, 799, 834, 858, 870, 870, 858, 834, 799, 0,
        0, 758, 793, 817, 829, 829, 817, 793, 758, 0,
        0, 739, 774, 798, 810, 810, 798, 774, 739, 0,
        0, 683, 718, 742, 754, 754, 742, 718, 683, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    R = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    Q = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    K = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 60098, 60132, 60073, 60025, 60025, 60073, 60132, 60098, 0,
        0, 60119, 60153, 60094, 60046, 60046, 60094, 60153, 60119, 0,
        0, 60146, 60180, 60121, 60073, 60073, 60121, 60180, 60146, 0,
        0, 60173, 60207, 60148, 60100, 60100, 60148, 60207, 60173, 0,
        0, 60196, 60230, 60171, 60123, 60123, 60171, 60230, 60196, 0,
        0, 60224, 60258, 60199, 60151, 60151, 60199, 60258, 60224, 0,
        0, 60287, 60321, 60262, 60214, 60214, 60262, 60321, 60287, 0,
        0, 60298, 60332, 60273, 60225, 60225, 60273, 60332, 60298, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
}

-------------------------------------------------------------------------------
-- Chess logic
-------------------------------------------------------------------------------
local function isspace(s)
    if s == ' ' or s == '\n' then
        return true
    else
        return false
    end
end

local special = '. \n'

local function isupper(s)
    if special:find(s) then return false end
    return s:upper() == s
end

local function islower(s)
    if special:find(s) then return false end
    return s:lower() == s
end

-- super inefficient
local function swapcase(s)
    local s2 = ''
    for i = 1, #s do
        local c = s:sub(i, i)
        if islower(c) then
            s2 = s2 .. c:upper()
        else
            s2 = s2 .. c:lower()
        end
    end
    return s2
end

local Position = {}

function Position.new(board, score, wc, bc, ep, kp)
    --[[  A state of a chess game
      board -- a 120 char representation of the board
      score -- the board evaluation
      wc -- the castling rights
      bc -- the opponent castling rights
      ep - the en passant square
      kp - the king passant square
   ]] --
    local self = {}
    self.board = board
    self.score = score
    self.wc = wc
    self.bc = bc
    self.ep = ep
    self.kp = kp
    for k, v in pairs(Position) do self[k] = v end
    return self
end

function Position:genMoves()
    local moves = {}
    -- For each of our pieces, iterate through each possible 'ray' of moves,
    -- as defined in the 'directions' map. The rays are broken e.g. by
    -- captures or immediately in case of pieces such as knights.
    for i = 0, #self.board - 1 do
        local p = self.board:sub(i + 1, i + 1)
        if isupper(p) and directions[p] then
            for _, d in ipairs(directions[p]) do
                local limit = (i + d) + (10000) * d -- fake limit
                for j = i + d, limit, d do
                    local q = self.board:sub(j + 1, j + 1)
                    -- Stay inside the board
                    if isspace(self.board:sub(j + 1, j + 1)) then break; end
                    -- Castling
                    if i == A1 and q == 'K' and self.wc[1] then
                        table.insert(moves, { j, j - 2 })
                    end
                    if i == H1 and q == 'K' and self.wc[2] then
                        table.insert(moves, { j, j + 2 })
                    end
                    -- print(p, q, i, d, j)
                    -- No friendly captures
                    if isupper(q) then break; end
                    -- Special pawn stuff
                    if p == 'P' and (d == N + W or d == N + E) and q == '.' and j ~= self.ep and j ~= self.kp then
                        break;
                    end
                    if p == 'P' and (d == N or d == 2 * N) and q ~= '.' then
                        break;
                    end
                    if p == 'P' and d == 2 * N and (i < A1 + N or self.board:sub(i + N + 1, i + N + 1) ~= '.') then
                        break;
                    end
                    -- Move it
                    table.insert(moves, { i, j })
                    -- print(i, j)
                    -- Stop crawlers from sliding
                    if p == 'P' or p == 'N' or p == 'K' then break; end
                    -- No sliding after captures
                    if islower(q) then break; end
                end
            end
        end
    end
    return moves
end

function Position:isLegal(move)
    local pos = self:move(move)
    local moves = pos:genMoves()
    for i = 1, #moves do
        if math.abs(pos:value(moves[i])) >= MATE_VALUE then
            return false
        end
    end
    return true
end

function Position:genLegalMoves()
    local moves = self:genMoves()
    local legalMoves = {}
    for i = 1, #moves do
        local move = moves[i]
        if self:isLegal(move) then
            legalMoves[#legalMoves + 1] = move
        end
    end
    return legalMoves
end

function Position:rotate()
    return self.new(
        swapcase(self.board:reverse()), -self.score,
        self.bc, self.wc, 119 - self.ep, 119 - self.kp)
end

function Position:move(move)
    assert(move) -- move is zero-indexed
    local i, j = move[1], move[2]
    local p, q = self.board:sub(i + 1, i + 1), self.board:sub(j + 1, j + 1)
    local function put(board, i, p)
        return board:sub(1, i - 1) .. p .. board:sub(i + 1)
    end

    -- Copy variables and reset ep and kp
    local board = self.board
    local wc, bc, ep, kp = self.wc, self.bc, 0, 0
    local score = self.score + self:value(move)
    -- Actual move
    board = put(board, j + 1, board:sub(i + 1, i + 1))
    board = put(board, i + 1, '.')
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
            board = put(board, j < i and A1 + 1 or H1 + 1, '.')
            board = put(board, kp + 1, 'R')
        end
    end
    -- Special pawn stuff
    if p == 'P' then
        if A8 <= j and j <= H8 then
            board = put(board, j + 1, 'Q')
        end
        if j - i == 2 * N then
            ep = i + N
        end
        if ((j - i) == N + W or (j - i) == N + E) and q == '.' then
            board = put(board, j + S + 1, '.')
        end
    end
    -- We rotate the returned position, so it's ready for the next player
    return self.new(board, score, wc, bc, ep, kp):rotate()
end

function Position:value(move)
    local i, j = move[1], move[2]
    local p, q = self.board:sub(i + 1, i + 1), self.board:sub(j + 1, j + 1)
    -- Actual move
    local score = pst[p][j + 1] - pst[p][i + 1]
    -- Capture
    if islower(q) then
        score = score + pst[q:upper()][j + 1]
    end
    -- Castling check detection
    if math.abs(j - self.kp) < 2 then
        score = score + pst['K'][j + 1]
    end
    -- Castling
    if p == 'K' and math.abs(i - j) == 2 then
        score = score + pst['R'][math.floor((i + j) / 2) + 1]
        score = score - pst['R'][j < i and A1 + 1 or H1 + 1]
    end
    -- Special pawn stuff
    if p == 'P' then
        if A8 <= j and j <= H8 then
            score = score + pst['Q'][j + 1] - pst['P'][j + 1]
        end
        if j == self.ep then
            score = score + pst['P'][j + S + 1]
        end
    end
    return score
end

local function parse(c)
    if not c then return nil end
    local p, v = c:sub(1, 1), c:sub(2, 2)
    if not (p and v and tonumber(v)) then return nil end
    local fil, rank = string.byte(p) - string.byte('a'), tonumber(v) - 1
    return A1 + fil - 10 * rank
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

function sunfish:printboard(pos)
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
    messagebus:publish("printboard", { fen = board .. " " .. activeColor .. " KQkq - 0 1" })
end

function sunfish:emptySquares(board)
    local _, count = string.gsub(board, "%.", "")
    return count
end

function sunfish:isWhitePiece(squareText)
    local square = parse(squareText) + 1
    local pieceLetter = self.pos.board:sub(square, square)
    return pieceLetter == string.upper(pieceLetter)
end

function sunfish:reverseMove(e)
    local rows = { 8, 7, 6, 5, 4, 3, 2, 1 }
    local cols = { a = "h", b = "g", c = "f", d = "e", e = "d", f = "c", g = "b", h = "a" }
    local reverseRow = function(square) return cols[square:sub(1, 1)] .. rows[tonumber(square:sub(2, 2))] end
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

function sunfish:chessmove(e)
    local isWhitePieceMoved = self:isWhitePiece(e.from)
    if isWhitePieceMoved ~= self.isWhiteActive then
        self:printboard(self.pos)
        return
    end
    if not isWhitePieceMoved then
        e = self:reverseMove(e)
        self.pos = self.pos:rotate()
    end
    local move = { parse(e.from), parse(e.to) }
    if move[1] and move[2] and findMoveInList(self.pos:genLegalMoves(), move) then
        self.pos = self:doMove(move)
        self.isWhiteActive = not self.isWhiteActive
    end
    if not isWhitePieceMoved then self.pos = self.pos:rotate() end
    self:printboard(self.pos)
end

sunfish.pos = Position.new(initial, 0, { true, true }, { true, true }, 0, 0)
messagebus:subscribe(sunfish, "chessmove", function(e) sunfish:chessmove(e) end)

return sunfish
