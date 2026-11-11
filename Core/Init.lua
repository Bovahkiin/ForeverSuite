local addonName, FS = ...
FS.name = addonName
FS.version = "0.9.9"
FS.icon = "Interface\\AddOns\\ForeverSuite\\Assets\\Icon-FS.tga"
FS.logo = "Interface\\AddOns\\ForeverSuite\\Assets\\Logo-wordmark.tga"
FS.emblem = "Interface\\AddOns\\ForeverSuite\\Assets\\Logo-transparent.tga"
FS.locales = {}
FS.modules = {}
_G.ForeverSuite = FS

function FS:RegisterModule(name, module)
    assert(type(name) == "string" and type(module) == "table", "Invalid module")
    assert(not self.modules[name], "Module already registered: " .. name)
    self.modules[name] = module
end

function FS:IsModuleEnabled(name)
    if name == "Vendor" then return self.db.vendor.enabled end
    if name == "Bags" then return self.db.bags.enabled end
    if name == "Gear" then return self.db.gear.enabled end
    local keys = { UnitFrames = "unitFrames", ActionBars = "actionBars", Nameplates = "nameplates", Character = "character" }
    if keys[name] then return self.db[keys[name]].enabled end
    local module=self.modules[name]
    if module and module.key and self.db[module.key] then return self.db[module.key].enabled~=false end
    return self.db.modules[name] ~= false
end

function FS:SetModuleEnabled(name, enabled)
    local module = self.modules[name]
    if not module then return end
    if name == "Vendor" then
        self.db.vendor.enabled = enabled == true
    elseif name == "Bags" then self.db.bags.enabled = enabled == true
    elseif name == "Gear" then self.db.gear.enabled = enabled == true
    elseif module.key and self.db[module.key] then self.db[module.key].enabled = enabled == true
    else self.db.modules[name] = enabled == true end
    -- Reflect the saved choice before module work can defer or raise an error.
    if self.PaintModuleCard then self:PaintModuleCard(name) end
    if name~="Bags" and module.SettingsChanged then module:SettingsChanged() end
    if not enabled and module.window and not InCombatLockdown() then module.window:Hide() end
    self:RefreshConfig()
    if self.Style then self.Style:Refresh() end
    if self.Extensions and self.Extensions.UpdateFilters then self.Extensions:UpdateFilters() end
    if self.Extensions and self.Extensions.SyncEvents then self.Extensions:SyncEvents() end
end

function FS:Initialize()
    if self.initialized then return end
    self:RefreshClient()
    self:InitializeDatabase()
    if self.Extensions then self.Extensions:Normalize() end
    self:SelectLocale()
    self:CreateMinimapButton()
    self.initialized = true
    for _, module in pairs(self.modules) do
        if module.Initialize then module:Initialize() end
    end
    if self.WindowManager then self.WindowManager:Install(); self.WindowManager:UpdateExperience() end
    if self.Themes then self.Themes:Refresh() end
    if self.Extensions then self.Extensions:Initialize() end
    if self.Typography then self.Typography:Apply() end
    if self.Compatibility then self.Compatibility:Initialize() end
    if self.db.welcome then self:Print(string.format(self.L.LOADED, self.version)) end
end
