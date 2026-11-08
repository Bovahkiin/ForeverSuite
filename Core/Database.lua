local _, FS = ...
FS.defaults = {
    schemaVersion = 3,
    language = "enUS",
    welcome = true,
    patchLog = { showOnLoad = true },
    setup = { completed = false, dismissed = false },
    minimap = { show = true, angle = 225 },
    window = { x = 0, y = 0 },
    modules = {},
    profiles = { current = "Default", saved = {} },
    bags = { enabled = true, replaceNative = true, scale = 0.85, width = 820, height = 500, viewMode = "categories", showRecent = true, customCategories = {}, sort = "category", category = "All", showEmpty = false, showCooldowns = true, showNewLoot = true, uiVersion = 1, openAtMerchant = true, x = 0, y = 0, categoryOverrides = {}, favorites = { [6948] = true } },
    gear = { enabled = true, showButton = true, warn = true, warningPercent = 25, x = 0, y = 0 },
    unitFrames = { enabled = true, scale = 1, x = 0, y = 200, player = { x = -430, y = 224 }, target = { x = 430, y = 224 }, focus = { x = 430, y = 330 }, pet = { x = -430, y = 150 }, showPet = true, party = { x = -660, y = 540 }, raid = { x = -500, y = 570 }, showFocus = true, showParty = true, showRaid = true },
    actionBars = { enabled = true, menu = true, style = "Minimal", scale = 1, x = 0, y = 200 },
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
    if self.firstInstallation==nil then self.firstInstallation=type(ForeverSuiteDB)~="table" or next(ForeverSuiteDB)==nil end
    if type(ForeverSuiteDB) ~= "table" then ForeverSuiteDB = {} end
    -- Only an explicit saved choice may skip onboarding; partial settings are not completion.
    if type(ForeverSuiteDB.setup)~="table" then ForeverSuiteDB.setup={completed=false,dismissed=false} end
    local social=ForeverSuiteDB.social
    if type(social)=="table" then
        if type(ForeverSuiteDB.chat)~="table" then ForeverSuiteDB.chat={enabled=social.enabled,timestamps=social.timestamps} end
        if type(ForeverSuiteDB.guild)~="table" then ForeverSuiteDB.guild={enabled=social.enabled,onlineOnly=social.onlineOnly} end
    end
    local simplifyBags = type(ForeverSuiteDB.bags) == "table" and ForeverSuiteDB.bags.uiVersion ~= 1
    self:ApplyDefaults(ForeverSuiteDB, self.defaults)
    self.db = ForeverSuiteDB
    if self.Typography then self.Typography:Normalize() end
    if simplifyBags then self.db.bags.showEmpty = false end
    self.db.bags.uiVersion = 1
    self.db.language = "enUS"
    self.db.schemaVersion = 3
    if self.modules.Bags then self.modules.Bags:NormalizeSettings() end
    if self.modules.Vendor then self.modules.Vendor:NormalizeSettings() end
    if self.modules.Gear then self.modules.Gear:NormalizeSettings() end
    if self.Layout then self.Layout:Normalize() end
    for _, name in ipairs({ "UnitFrames", "ActionBars", "Nameplates" }) do
        if self.modules[name] then self.modules[name]:NormalizeSettings() end
    end
    for name,module in pairs(self.modules) do
        if name~="UnitFrames" and name~="ActionBars" and name~="Nameplates" and module.key and module.NormalizeSettings then module:NormalizeSettings() end
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
    for _,module in pairs(self.modules) do if module.SettingsChanged then module:SettingsChanged() end end
    if self.Typography then self.Typography:Apply() end
    if self.Themes then self.Themes:Refresh() end
    self:Print(self.L.RESET_DONE)
end
