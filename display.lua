local display = {
    root = nil,
    images = {},
    contentWidth = love.graphics.getWidth(),
    contentHeight = love.graphics.getHeight(),
}

local entityTypeGroup = 1
local entityTypeImage = 2
local entityTypeRect = 3
local entityTypeCirc = 4
local entityTypeText = 5

function display.basicProps(x, y, type)
    return {
        x = x,
        y = y,
        type = type
    }
end

function display.newCirc(g, x, y, r, s)
    local circ = display.basicProps(x, y, entityTypeCirc)
    circ.radius = r
    circ.segments = s
    circ.fill = { 1, 1, 1 }
    display.insert(g, circ)
    return circ
end

function display.newText(g, str, x, y)
    local text = display.basicProps(x, y, entityTypeText)
    text.str = str
    text.fill = { 1, 1, 1 }
    display.insert(g, text)
    return text
end

function display.newRect(g, x, y, w, h)
    local rect = display.basicProps(x, y, entityTypeRect)
    rect.width = w
    rect.height = h
    rect.fill = { 1, 1, 1 }
    display.insert(g, rect)
    return rect
end

function display.newImage(g, filename, x, y, w, h)
    if display.images[filename] == nil then
        display.images[filename] = love.graphics.newImage(filename)
    end
    local sheet = display.images[filename]
    local img = display.basicProps(0, 0, entityTypeImage)
    img.quad = love.graphics.newQuad(x, y, w, h, sheet)
    img.sheet = sheet
    img.width = w
    img.height = h
    img.fill = { 1, 1, 1 }
    display.insert(g, img)
    return img
end

function display.newGroup(g, name)
    local group = display.basicProps(0, 0, entityTypeGroup)
    group.children = {}
    group.name = name
    if g ~= nil then
        display.insert(g, group)
    end
    return group
end

function display.render()
    display.renderGroup(display.root)
end

function display.renderGroup(g)
    local children = g.children
    for i = 1, #children do
        local e = children[i]
        if e.type == entityTypeGroup then
            display.renderGroup(e)
        elseif e.type == entityTypeRect then
            display.renderRect(e)
        elseif e.type == entityTypeCirc then
            display.renderCirc(e)
        elseif e.type == entityTypeImage then
            display.renderImage(e)
        elseif e.type == entityTypeText then
            display.renderText(e)
        end
    end
end

function display.renderRect(e)
    local color = e.fill
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.rectangle("fill", e.x, e.y, e.width, e.height)
end

function display.renderCirc(e)
    local color = e.fill
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.circle("fill", e.x, e.y, e.radius, e.segments)
end

function display.renderImage(e)
    local color = e.fill
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.draw(e.sheet, e.quad, e.x, e.y)
end

function display.renderText(e)
    local color = e.fill
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.print(e.str, e.x, e.y)
end

function display.insert(g, e)
    if g == nil then return end
    display.remove(e)
    local list = g.children
    list[#list + 1] = e
    e.parent = g
end

function display.remove(e)
    if e.parent == nil then return end
    local g = e.parent
    local list = g.children
    for i = 1, #list do
        local child = list[i]
        if child == e then
            e.parent = nil
            table.remove(list, i)
            return
        end
    end
end

function display.groupToString(g, level)
    local indent = ""
    local indentCh = "-- "
    if level ~= nil and level > 0 then
        for i = 1, level do
            indent = indent .. indentCh
        end
    else
        print("START")
        level = 0
    end
    local children = g.children
    local gname = tostring(g)
    if g.name then gname = g.name end
    print(indent .. gname .. " (" .. #children .. ")")
    for i = 1, #children do
        local child = children[i]
        if child.type == entityTypeGroup then
            display.groupToString(child, level + 1)
        else
            print(indent .. indentCh .. "gfx")
        end
    end
end

display.root = display.newGroup(nil, "root")

return display
