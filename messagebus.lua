local messagebus = {
    callbacks = {},
}

function messagebus:subscribe(subscriber, eventName, callback)
    local list

    local callbacks = messagebus.callbacks
    if callbacks[eventName] == nil then
        callbacks[eventName] = {}
    end
    list = callbacks[eventName]
    list[#list + 1] = { callback = callback, subscriber = subscriber }
end

function messagebus:publish(eventName, options)
    local callbacks = self.callbacks[eventName]
    if callbacks == nil then return end
    for i = 1, #callbacks do
        callbacks[i].callback(options)
    end
end

function messagebus:unsubscribe(subscriber)
    local callbacks = self.callbacks
    for i = #callbacks, 1, -1 do
        local q = callbacks[i]
        if q.subscriber == subscriber then
            table.remove(callbacks, i)
        end
    end
end

return messagebus
