local chessgame = require('chessgame')
local squares = require('squares')
local testdata = require('unittest-data')

local unittest = {
    errors = {}
}
function unittest:generateUnittests()
    for _, move in ipairs(testdata.testLegaMovesForPiece) do
        local from = move:sub(1, 2)
        local to   = move:sub(3, 4)
        chessgame:chessmove(from .. to)
        print("{")
        print('move = "' .. move .. '", legalMoves = {')

        for _, square in ipairs(squares:getAll()) do
            local moves = chessgame:legalMovesForPiece(square.name)
            if #moves > 0 then
                for _, move in ipairs(moves) do
                    print('"' ..
                        chessgame:squareIndexToName(move[1] - 1) .. chessgame:squareIndexToName(move[2] - 1) .. '",')
                end
            end
        end
        print("}")
        print("},")
    end
    return 0
end

function unittest:testLegaMovesForPiece()
    local errors = self.errors
    for _, test in ipairs(testdata.testLegaMovesForPiece) do
        local i = 1
        local move = test.move
        local legalMoves = test.legalMoves
        local from = move:sub(1, 2)
        local to = move:sub(3, 4)
        chessgame:chessmove(from .. to)
        for _, square in ipairs(squares:getAll()) do
            local moves = chessgame:legalMovesForPiece(square.name)
            if #moves > 0 then
                for _, move in ipairs(moves) do
                    local moveString = chessgame:squareIndexToName(move[1] - 1) ..
                        chessgame:squareIndexToName(move[2] - 1)
                    if moveString ~= legalMoves[i] then
                        errors[#errors + 1] = "ERROR!"
                    end
                    i = i + 1
                end
            end
        end
    end
end

function unittest:run()
    self.errors = {}
    local errors = self.errors

    self:testLegaMovesForPiece()

    if #errors == 0 then
        chessgame:reset()
    end

    return #errors
end

return unittest
