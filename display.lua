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

function display.basicProps(x, y, w, h, type)
    return {
        x = x,
        y = y,
        w = w,
        h = h,
        type = type,
        isVisible = true,
        anchorX = 0.5,
        anchorY = 0.5,
        scaleX = 1,
        scaleY = 1,
    }
end

function display.newCirc(g, x, y, r, s)
    local circ = display.basicProps(x, y, r, r, entityTypeCirc)
    circ.radius = r
    circ.segments = s
    circ.fill = { 1, 1, 1 }
    circ.anchorX = 0
    circ.anchorY = 0
    display.insert(g, circ)
    return circ
end

function display.newText(g, str, x, y)
    local text = display.basicProps(x, y, nil, nil, entityTypeText)
    text.str = str
    text.fill = { 1, 1, 1 }
    display.insert(g, text)
    return text
end

function display.newRect(g, x, y, w, h)
    local rect = display.basicProps(x, y, w, h, entityTypeRect)
    rect.fill = { 1, 1, 1 }
    display.insert(g, rect)
    return rect
end

function display.newImage(g, filename, x, y, w, h)
    if display.images[filename] == nil then
        display.images[filename] = love.graphics.newImage(filename)
    end
    local sheet = display.images[filename]
    local img = display.basicProps(0, 0, w, h, entityTypeImage)
    img.quad = love.graphics.newQuad(x, y, w, h, sheet)
    img.sheet = sheet
    img.fill = { 1, 1, 1 }
    display.insert(g, img)
    return img
end

function display.newGroup(g, name)
    local group = display.basicProps(0, 0, nil, nil, entityTypeGroup)
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
        if e.isVisible then
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
end

function display.getAnchorPos(e)
    if e.w and e.h then
        return { x = e.x - e.w * e.scaleX * e.anchorX, y = e.y - e.h * e.scaleY * e.anchorY }
    else
        return { x = e.x, y = e.y }
    end
end

function display.setColor(color)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
end

function display.renderRect(e)
    local color = e.fill
    display.setColor(color)
    local pos = display.getAnchorPos(e)
    love.graphics.rectangle("fill", pos.x, pos.y, e.w, e.h)
end

function display.renderCirc(e)
    local color = e.fill
    display.setColor(color)
    local pos = display.getAnchorPos(e)
    love.graphics.circle("fill", pos.x, pos.y, e.w * e.scaleX, e.segments)
end

function display.renderImage(e)
    local color = e.fill
    display.setColor(color)
    local pos = display.getAnchorPos(e)
    love.graphics.draw(e.sheet, e.quad, pos.x, pos.y, 0, e.scaleX, e.scaleY)
end

function display.renderText(e)
    local color = e.fill
    display.setColor(color)
    local pos = display.getAnchorPos(e)
    love.graphics.print(e.str, pos.x, pos.y)
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

function display.toFront(e)
    if e.parent == nil then return end
    local g = e.parent
    display.remove(e)
    display.insert(g, e)
end

display.root = display.newGroup(nil, "root")

return display
