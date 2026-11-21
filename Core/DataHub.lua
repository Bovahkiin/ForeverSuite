local _, FS = ...

-- DataHub --------------------------------------------------------------------
-- A local, versioned, account-wide record of every character the player has
-- recorded. It lives in its own SavedVariable (ForeverSuiteHub) so it never
-- travels with profiles or exports.
--
-- Version 1 replaces ForeverSuiteStock. The old table is imported once and then
-- left untouched, so the import can be checked and an older addon still works.
--
-- hub = {
--     schemaVersion = 1,
--     legacy = { imported = true, count = n, time = t },
--     characters = { ["Name-Realm"] = {
--         name, realm,
--         level, class, faction, lastSeen,    -- refreshed automatically (RecordIdentity)
--         time,                               -- last update of any recorded section
--         bags = { counts = { [itemId] = n }, time },
--         gear = { items, level, lowest, time },
--         professions = { items, time },
--     } },
-- }
-- Optional fields can be added to a character without raising the version; a
-- version bump is only needed when existing data has to be rewritten.
local H = { schemaVersion = 1, limit = 50 }
FS.Hub = H

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

-- Keep the data from before a hub upgrade in one backup slot inside the hub.
local function keepBackup(data, before, from, target)
    before.backup = nil
    data.backup = { from = from, target = target, time = time and time() or 0, data = before }
end

FS:RegisterMigrationStore("hub", H, "schemaVersion", 1, "Character data", keepBackup)

function H:Data()
    if type(ForeverSuiteHub) ~= "table" then ForeverSuiteHub = {} end
    if type(ForeverSuiteHub.characters) ~= "table" then ForeverSuiteHub.characters = {} end
    return ForeverSuiteHub
end

function H:Characters()
    return self:Data().characters
end

-- False while the hub is held back because it came from a newer addon version or
-- an upgrade failed. Reading still works; recording waits for the next load.
function H:Writable()
    return not self.locked
end

-- The key ("Name-Realm") is the source of truth for name and realm. Realm names
-- can contain hyphens, character names cannot, so split on the first one.
function H:Identify(record, key)
    local name, realm = tostring(key):match("^([^-]+)%-(.+)$")
    record.name = name or tostring(key)
    record.realm = realm
    return record
end

-- Keeps the characters seen or recorded most recently. A character that was only
-- seen (no recorded sections) still counts as recent through lastSeen.
function H:Trim()
    local map, count = self:Characters(), 0
    for _ in pairs(map) do
        count = count + 1
        if count > self.limit then break end
    end
    if count <= self.limit then return end
    local ranked = {}
    for key, record in pairs(map) do
        local seen = 0
        if type(record) == "table" then seen = math.max(tonumber(record.lastSeen) or 0, tonumber(record.time) or 0) end
        ranked[#ranked + 1] = { key = key, seen = seen }
    end
    table.sort(ranked, function(a, b)
        if a.seen ~= b.seen then return a.seen > b.seen end
        return tostring(a.key) < tostring(b.key)
    end)
    for index = self.limit + 1, #ranked do map[ranked[index].key] = nil end
end

-- True when at least one character has recorded sections (bags, gear or
-- professions), as opposed to only being seen.
function H:HasRecords()
    for _, record in pairs(self:Characters()) do
        if type(record) == "table" and tonumber(record.time) then return true end
    end
    return false
end

-- Refreshes level, class, faction and last-seen time for the logged-in character.
-- Cheap enough to run at login, on level-up and at logout. Unreadable values
-- never overwrite what is already stored. `levelHint` is the new level reported by
-- PLAYER_LEVEL_UP, which UnitLevel can lag behind.
function H:RecordIdentity(levelHint)
    if self.locked then return false end
    local E, T = FS.Extensions, FS.Tools
    local key = E and E:CharacterKey()
    if not key then return false end
    local level = T:Call(UnitLevel, "player")
    local _, classFile = T:Call(UnitClass, "player")
    local faction = T:Call(UnitFactionGroup, "player")
    if T:Number(levelHint) and (not T:Number(level) or levelHint > level) then level = levelHint end
    local records = self:Characters()
    local record = type(records[key]) == "table" and records[key] or {}
    self:Identify(record, key)
    if T:Number(level) and level >= 1 and level <= 200 and level % 1 == 0 then record.level = level end
    classFile = T:Text(classFile)
    if classFile:match("^%u+$") then record.class = classFile end
    faction = T:Text(faction)
    if #faction <= 20 and faction:match("^%a+$") then record.faction = faction end
    record.lastSeen = time and time() or record.lastSeen
    records[key] = record
    self:Trim()
    return true
end

local function convertLegacy(key, old)
    local record = H:Identify({ time = tonumber(old.time) or 0 }, key)
    if type(old.counts) == "table" then
        record.bags = { counts = copy(old.counts), time = tonumber(old.bagTime) or tonumber(old.time) or 0 }
    end
    if type(old.professions) == "table" then record.professions = copy(old.professions) end
    if type(old.gear) == "table" then record.gear = copy(old.gear) end
    return record
end

-- Copies every character from ForeverSuiteStock once. The old table is only read.
function H:ImportLegacy()
    if self.locked then return 0 end
    local hub = self:Data()
    if type(hub.legacy) == "table" and hub.legacy.imported then return 0 end
    local count = 0
    if type(ForeverSuiteStock) == "table" then
        for key, old in pairs(ForeverSuiteStock) do
            if type(key) == "string" and type(old) == "table" and hub.characters[key] == nil then
                hub.characters[key] = convertLegacy(key, old)
                count = count + 1
            end
        end
    end
    hub.legacy = { imported = true, count = count, time = time and time() or 0 }
    return count
end

function H:Initialize()
    self.locked = nil
    local fresh = type(ForeverSuiteHub) ~= "table" or next(ForeverSuiteHub) == nil
    if type(ForeverSuiteHub) ~= "table" then ForeverSuiteHub = {} end
    if fresh then
        ForeverSuiteHub.schemaVersion = self.schemaVersion
    else
        local result, info = FS:MigrateData(ForeverSuiteHub, nil, "hub")
        if result == false then
            FS:ReportMigrationFailure(info)
            self.locked = true
        elseif result == "newer" then
            self.locked = true
            FS:Print("Your saved character data comes from a newer ForeverSuite (data version " .. info .. ") and is read-only until you update the addon.")
        end
    end
    self:Data()
    self:ImportLegacy()
end
