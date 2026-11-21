local addonName, FS = ...
FS.name = addonName
FS.version = "1.0.8"
FS.icon = "Interface\\AddOns\\ForeverSuite\\Assets\\Icon-FS.tga"
FS.logo = "Interface\\AddOns\\ForeverSuite\\Assets\\Logo-wordmark.tga"
FS.emblem = "Interface\\AddOns\\ForeverSuite\\Assets\\Logo-transparent.tga"
FS.locales = {}
FS.modules = {}
FS.moduleOrder = {}
_G.ForeverSuite = FS

function FS:RegisterModule(name, module)
    assert(type(name) == "string" and type(module) == "table", "Invalid module")
    assert(not self.modules[name], "Module already registered: " .. name)
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = name
end

-- Iterate modules in registration (.toc load) order. Unlike pairs(), the order
-- is the same on every login, so initialization never depends on hash order.
function FS:EachModule()
    local order, index = self.moduleOrder, 0
    return function()
        index = index + 1
        local name = order[index]
        if name then return name, self.modules[name] end
    end
end

-- A module with a settings key keeps its enabled flag in that table
-- (db[module.key].enabled). Modules without one use the shared db.modules list.
function FS:IsModuleEnabled(name)
    local module = self.modules[name]
    local data = module and module.key and self.db[module.key]
    if data then return data.enabled ~= false end
    return self.db.modules[name] ~= false
end

function FS:SetModuleEnabled(name, enabled)
    local module = self.modules[name]
    if not module then return end
    local data = module.key and self.db[module.key]
    if data then data.enabled = enabled == true
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
    for _, module in self:EachModule() do
        if module.Initialize then module:Initialize() end
    end
    if self.WindowManager then self.WindowManager:Install(); self.WindowManager:UpdateExperience() end
    if self.Themes then self.Themes:Refresh() end
    if self.Extensions then self.Extensions:Initialize() end
    if self.Typography then self.Typography:Apply() end
    if self.Compatibility then self.Compatibility:Initialize() end
    if self.db.welcome then self:Print(string.format(self.L.LOADED, self.version)) end
end
