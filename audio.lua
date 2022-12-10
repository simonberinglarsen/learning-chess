local messagebus = require('messagebus')

local audio = {}
local sounds = {}
local soundIndex = {}

function audio.loadSound(name, file, type)
    if sounds[name] == nil then
        sounds[name] = {}
        soundIndex[name] = 0
    end
    local list = sounds[name]
    list[#list + 1] = love.audio.newSource(file, type)
end

function audio:soundfx(name)
    local list = sounds[name]
    if list == nil then return end
    local newIndex = (soundIndex[name] + 1) % #list
    soundIndex[name] = newIndex
    local sound = list[newIndex + 1]
    if sound:isPlaying() then
        sound:stop()
    end
    sound:play()
end

messagebus:subscribe(audio, "soundfx", function(e) audio:soundfx(e.name) end)


return audio
