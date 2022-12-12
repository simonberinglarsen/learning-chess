local squares = {
    list = {}, -- master data
    byName = {}, -- a8 to h1
    byIndex = {}, -- 1 to 64
}

for i = 1, 64 do
    local list = squares.list
    local file = (i - 1) % 8 + 1
    local rank = 8 - math.floor((i - 1) / 8)
    list[#list + 1] = {
        name = string.char(96 + file) .. rank,
        file = file,
        rank = rank,
        index = (file - 1) + 8 * (8 - rank) + 1,
        isDark = (file + rank) % 2 == 0,
        isLight = (file + rank) % 2 == 1,
    }
    local s = list[#list]
    squares.byName[s.name] = s
    squares.byIndex[s.index] = s
end

function squares:getAll()
    return self.list
end

function squares:getByName(name)
    return self.byName[name]
end

function squares:getByIndex(index)
    return self.byIndex[index]
end

function squares:getRotatedByName(name)
    local s = self.byName[name]
    return self.byIndex[65 - s.index]
end

function squares:getRotatedByIndex(index)
    return self.byIndex[65 - index]
end

function squares:print(s)
    print("name = " .. s.name)
    print("file = " .. s.file)
    print("rank = " .. s.rank)
    print("index = " .. s.index)
    print("isDark = " .. tostring(s.isDark))
    print("isLight = " .. tostring(s.isLight))
end

return squares
