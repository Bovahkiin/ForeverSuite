local _, FS = ...

-- Saved-data schema ----------------------------------------------------------
-- FS.schemaVersion is the version this build writes. Data saved before
-- versioned migrations existed counts as version 3 (BASELINE_SCHEMA).
-- To change the shape of saved data: raise FS.schemaVersion by one and register
-- a migration for that number with FS:RegisterMigration. Each migration runs
-- once, in order, on the raw saved table before defaults are applied. If one
-- fails, the data is restored, the old version stays stamped and the failure is
-- listed by /fs errors.
FS.schemaVersion = 3
FS.migrations = {}
local BASELINE_SCHEMA = 3
local MAX_BACKUPS = 5
local NOT_IN_BACKUP = { profiles = true, patchLog = true, setup = true, compatibility = true }

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = deepCopy(item) end
    return out
end

function FS:RegisterMigration(version, name, run)
    assert(type(version) == "number" and version % 1 == 0 and version > BASELINE_SCHEMA, "Migration version must be a whole number above " .. BASELINE_SCHEMA)
    assert(type(run) == "function", "Migration needs a function: " .. tostring(version))
    assert(not self.migrations[version], "Migration already registered: " .. version)
    self.migrations[version] = { name = name or ("version " .. version), run = run }
end

-- Upgrades one saved-settings table (the database, a profile or an import) to
-- `target`. Returns true plus the list of versions that ran, "newer" plus the
-- stored version when the data comes from a newer build (left untouched), or
-- false plus a failure description after restoring the data.
function FS:MigrateData(data, target)
    target = target or self.schemaVersion
    local stored = tonumber(data.schemaVersion)
    if stored and stored > target then return "newer", stored end
    local from = math.max(stored or BASELINE_SCHEMA, BASELINE_SCHEMA)
    local pending = {}
    for version = from + 1, target do
        if self.migrations[version] then pending[#pending + 1] = version end
    end
    if #pending > 0 then
        local before = deepCopy(data)
        for _, version in ipairs(pending) do
            local migration = self.migrations[version]
            local ok, err = pcall(migration.run, data)
            if not ok then
                for key in pairs(data) do data[key] = nil end
                for key, value in pairs(before) do data[key] = value end
                return false, { version = version, name = migration.name, message = tostring(err) }
            end
        end
        -- Keep the pre-upgrade data as a profile backup so it can be restored.
        local profiles = data.profiles
        if type(profiles) == "table" then
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
    end
    data.schemaVersion = target
    return true, pending
end

function FS:ReportMigrationFailure(info)
    self.migrationFailure = info
    local line = "Settings upgrade to version " .. info.version .. " (" .. tostring(info.name) .. ") failed and was rolled back: " .. info.message
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
    -- Only an explicit saved choice may skip onboarding; partial settings are not completion.
    if type(ForeverSuiteDB.setup)~="table" then ForeverSuiteDB.setup={completed=false,dismissed=false} end
    if firstRun then
        ForeverSuiteDB.setup.welcomePending=true
    end
    local social=ForeverSuiteDB.social
    if type(social)=="table" then
        if type(ForeverSuiteDB.chat)~="table" then ForeverSuiteDB.chat={enabled=social.enabled,timestamps=social.timestamps} end
        if type(ForeverSuiteDB.guild)~="table" then ForeverSuiteDB.guild={enabled=social.enabled,onlineOnly=social.onlineOnly} end
    end
    -- The two repairs above are older than versioned migrations and detect their
    -- own need; versioned migrations start after them.
    if not fresh then
        local result, info = self:MigrateData(ForeverSuiteDB)
        if result == false then self:ReportMigrationFailure(info)
        elseif result == "newer" then
            self.newerData = info
            self:Print("Your saved settings come from a newer ForeverSuite (data version " .. info .. ") and were left unchanged. Update the addon to keep using them safely.")
        end
    end
    local simplifyBags = type(ForeverSuiteDB.bags) == "table" and ForeverSuiteDB.bags.uiVersion ~= 1
    self:ApplyDefaults(ForeverSuiteDB, self.defaults)
    self.db = ForeverSuiteDB
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
