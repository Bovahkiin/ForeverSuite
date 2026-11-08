local _, FS = ...
function FS:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffForeverSuite:|r " .. tostring(message))
    end
end

function FS:ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            self:ApplyDefaults(target[key], value)
        elseif type(target[key]) ~= type(value) then
            target[key] = value
        end
    end
end
