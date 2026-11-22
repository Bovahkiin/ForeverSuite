local _, FS = ...

-- Saved-data schema ----------------------------------------------------------
-- A "store" is one saved table with its own version number. ForeverSuiteDB is
-- the store named "db"; other saved tables (for example the DataHub) register
-- their own with FS:RegisterMigrationStore. FS.schemaVersion is the version this
-- build writes to the database. Data saved before versioned migrations existed
-- counts as the store's baseline version (3 for the database).
-- To change the shape of a store's data: raise its version by one and register
-- a migration for that number with FS:RegisterMigration. Each migration runs
-- once, in order, on the raw saved table before defaults are applied. If one
-- fails, the data is restored, the old version stays stamped and the failure is
-- listed by /fs errors.
FS.schemaVersion = 3
FS.migrationStores = {}
local MAX_BACKUPS = 5
local NOT_IN_BACKUP = { profiles = true, patchLog = true, setup = true, compatibility = true }

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = deepCopy(item) end
    return out
end

-- Registers a store and returns its migration list. `owner[field]` holds the
-- version this build writes. `backup(data, before, from, target)` is optional and
-- runs after a successful upgrade to keep the pre-upgrade data somewhere safe.
function FS:RegisterMigrationStore(name, owner, field, baseline, label, backup)
    assert(type(name) == "string" and not self.migrationStores[name], "Migration store already registered: " .. tostring(name))
    assert(type(owner) == "table" and type(field) == "string" and type(baseline) == "number", "Invalid migration store: " .. name)
    local store = { name = name, owner = owner, field = field, baseline = baseline, label = label or name, backup = backup, migrations = {} }
    self.migrationStores[name] = store
    return store.migrations
end

local function storeFor(self, name)
    local store = self.migrationStores[name or "db"]
    assert(store, "Unknown migration store: " .. tostring(name))
    return store
end

function FS:RegisterMigration(version, name, run, storeName)
    local store = storeFor(self, storeName)
    assert(type(version) == "number" and version % 1 == 0 and version > store.baseline, "Migration version must be a whole number above " .. store.baseline)
    assert(type(run) == "function", "Migration needs a function: " .. tostring(version))
    assert(not store.migrations[version], "Migration already registered: " .. version)
    store.migrations[version] = { name = name or ("version " .. version), run = run }
end

-- The database keeps its pre-upgrade data as a profile backup so it can be restored.
local function backupIntoProfiles(data, before, from, target)
    local profiles = data.profiles
    if type(profiles) ~= "table" then return end
    if type(profiles.backups) ~= "table" then profiles.backups = {} end
    local snapshot = {}
    for key, value in pairs(before) do
        if not NOT_IN_BACKUP[key] then snapshot[key] = value end
    end
    table.insert(profiles.backups, 1, {
        name = type(profiles.current) == "string" and profiles.current or "Default",
        data = snapshot,
        reason = "Before settings upgrade (version " .. from .. " to " .. target .. ")",
        time = time and time() or 0,
    })
    while #profiles.backups > MAX_BACKUPS do table.remove(profiles.backups) end
end

FS.migrations = FS:RegisterMigrationStore("db", FS, "schemaVersion", 3, "Settings", backupIntoProfiles)

-- Upgrades one saved table (the database, a profile, an import or another store)
-- to `target`, which defaults to the version this build writes. Returns true plus
-- the list of versions that ran, "newer" plus the stored version when the data
-- comes from a newer build (left untouched), or false plus a failure description
-- after restoring the data.
function FS:MigrateData(data, target, storeName)
    local store = storeFor(self, storeName)
    target = target or store.owner[store.field]
    local stored = tonumber(data.schemaVersion)
    if stored and stored > target then return "newer", stored end
    local from = math.max(stored or store.baseline, store.baseline)
    local pending = {}
    for version = from + 1, target do
        if store.migrations[version] then pending[#pending + 1] = version end
    end
    if #pending > 0 then
        local before = deepCopy(data)
        for _, version in ipairs(pending) do
            local migration = store.migrations[version]
            local ok, err = pcall(migration.run, data)
            if not ok then
                for key in pairs(data) do data[key] = nil end
                for key, value in pairs(before) do data[key] = value end
                return false, { store = store.name, label = store.label, version = version, name = migration.name, message = tostring(err) }
            end
        end
        if store.backup then store.backup(data, before, from, target) end
    end
    data.schemaVersion = target
    return true, pending
end

function FS:ReportMigrationFailure(info)
    self.migrationFailure = info
    local line = (info.label or "Settings") .. " upgrade to version " .. info.version .. " (" .. tostring(info.name) .. ") failed and was rolled back: " .. info.message
    self.runtimeErrors = self.runtimeErrors or {}
    if #self.runtimeErrors >= 10 then table.remove(self.runtimeErrors, 1) end
    self.runtimeErrors[#self.runtimeErrors + 1] = line
    self:Print(line)
end

FS.defaults = {
    schemaVersion = FS.schemaVersion,
    language = "enUS",
    welcome = true,
    patchLog = { showOnLoad = true, lastSeenVersion = "" },
    setup = { completed = false, dismissed = false },
    minimap = { show = true, angle = 225 },
    window = { x = 0, y = 0, pinnedTools = {bags=true, map=true, gear=true, mail=true} },
    modules = {},
    profiles = { current = "Default", saved = {} },
    bags = { enabled = true, replaceNative = true, scale = 0.85, width = 820, height = 500, viewMode = "categories", showRecent = true, customCategories = {}, sort = "category", category = "All", showEmpty = false, showCooldowns = true, showNewLoot = true, uiVersion = 1, openAtMerchant = true, x = 0, y = 0, categoryOverrides = {}, favorites = { [6948] = true } },
    gear = { enabled = true, showButton = true, warn = true, warningPercent = 25, x = 0, y = 0 },
    unitFrames = { enabled = true, scale = 1, x = 0, y = 200, player = { x = -430, y = 224 }, target = { x = 430, y = 224 }, focus = { x = 430, y = 330 }, pet = { x = -430, y = 150 }, showPet = true, party = { x = -660, y = 540 }, raid = { x = -500, y = 570 }, showFocus = true, showParty = true, showRaid = true },
    actionBars = { enabled = true, menu = true, style = "Minimal", scale = 1, x = 0, y = 200, mouseover = false, fade = 100 },
    nameplates = { enabled = true, scale = 1, enemies = true, friendlyPlayers = false, friendlyNPCs = false },
    character = { enabled = true },
    layout = { snap = true, frames = {} },
    vendor = {
        enabled = true, mode = "manual", includeGray = true,
        showPanel = true, report = true, protectRare = true,
        autoRepair = false, repairSource = "personal",
        repairLimit = 50000, confirmRepair = true,
        autoRestock = false, restockBudget = 10000, moneyReserve = 0,
        glow = { enabled = true, pulse = true, color = "green", intensity = 0.8 },
        rules = {}, alwaysKeep = {}, history = {},
    },
}

function FS:InitializeDatabase()
    local fresh=type(ForeverSuiteDB)~="table" or next(ForeverSuiteDB)==nil
    local firstRun=self.firstInstallation==nil and fresh
    if self.firstInstallation==nil then self.firstInstallation=fresh end
    if type(ForeverSuiteDB) ~= "table" then ForeverSuiteDB = {} end
    local data=ForeverSuiteDB
    self.databaseReadOnly=nil; self.newerData=nil
    if not fresh then
        local result, info = self:MigrateData(data)
        if result == false then
            self:ReportMigrationFailure(info)
            self.databaseReadOnly=true; data=deepCopy(data)
        elseif result == "newer" then
            self.newerData=info; self.databaseReadOnly=true; data=deepCopy(data)
            self:Print("Your saved settings come from a newer ForeverSuite (data version " .. info .. "). They are preserved; this session uses a temporary copy. Update the addon before saving profile changes.")
        end
    end
    -- Only an explicit saved choice may skip onboarding; partial settings are not completion.
    if type(data.setup)~="table" then data.setup={completed=false,dismissed=false} end
    if firstRun then
        data.setup.welcomePending=true
    end
    local social=data.social
    if type(social)=="table" then
        if type(data.chat)~="table" then data.chat={enabled=social.enabled,timestamps=social.timestamps} end
        if type(data.guild)~="table" then data.guild={enabled=social.enabled,onlineOnly=social.onlineOnly} end
    end
    local simplifyBags = type(data.bags) == "table" and data.bags.uiVersion ~= 1
    self:ApplyDefaults(data, self.defaults)
    self.db = data
    if self.Typography then self.Typography:Normalize() end
    if simplifyBags then self.db.bags.showEmpty = false end
    self.db.bags.uiVersion = 1
    self.db.language = "enUS"
    -- Some modules must be normalized before others, so run those first and
    -- skip them in the general pass below.
    local normalized = {}
    local function normalize(name)
        local module = self.modules[name]
        if module and not normalized[name] then normalized[name] = true; module:NormalizeSettings() end
    end
    normalize("Bags"); normalize("Vendor"); normalize("Gear")
    if self.Layout then self.Layout:Normalize() end
    for _, name in ipairs({ "UnitFrames", "ActionBars", "Nameplates" }) do normalize(name) end
    for name, module in self:EachModule() do
        if module.key and module.NormalizeSettings and not normalized[name] then
            normalized[name] = true; module:NormalizeSettings()
        end
    end
    if self.db.minimap.angle ~= self.db.minimap.angle or math.abs(self.db.minimap.angle) == math.huge then
        self.db.minimap.angle = 225
    end
    for _, key in ipairs({ "x", "y" }) do
        local value = self.db.window[key]
        if value ~= value or math.abs(value) > 10000 then self.db.window[key] = 0 end
    end
end

function FS:ResetDatabase()
    if InCombatLockdown() then self:Print("Leave combat to reset settings."); return end
    if self.modules.Vendor and self.modules.Vendor.busy then self:Print("Stop the vendor action before resetting settings."); return end
    ForeverSuiteDB = {}
    self:InitializeDatabase()
    self:SelectLocale()
    if self.window then
        self.window:ClearAllPoints()
        self.window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    self:RefreshConfig()
    self:UpdateMinimapButton()
    for _,module in self:EachModule() do if module.SettingsChanged then module:SettingsChanged() end end
    if self.Typography then self.Typography:Apply() end
    if self.Themes then self.Themes:Refresh() end
    self:Print(self.L.RESET_DONE)
end
