local _, FS = ...
local B = { page = 1, search = "",
    categories = { "All", "Favorites", "Gear", "Consumables", "Ammo", "Materials", "Bags", "Gems", "Enhancements", "Recipes", "Quest Items", "Keys", "Pets", "Mounts", "Glyphs", "Currency", "Professions", "Housing", "Holiday", "Junk", "Other", "Stock" },
    assignable = { "Gear", "Consumables", "Ammo", "Materials", "Bags", "Gems", "Enhancements", "Recipes", "Quest Items", "Keys", "Pets", "Mounts", "Glyphs", "Currency", "Professions", "Housing", "Holiday", "Other" },
    sorts = { "category", "name", "value", "bag" } }
FS:RegisterModule("Bags", B)
function B:NormalizeSettings()
    local db = FS.db.bags
    if not self.baseCategories then
        self.baseCategories, self.baseAssignable = {}, {}
        for i, name in ipairs(self.categories) do self.baseCategories[i] = name end
        for i, name in ipairs(self.assignable) do self.baseAssignable[i] = name end
    end
    self.categories, self.assignable = {}, {}
    local used = {}
    for i, name in ipairs(self.baseCategories) do
        self.categories[i] = name; used[name:lower()] = true
        if self.categoryNames and self.categoryNames[name] then used[self.categoryNames[name]:lower()] = true end
    end
    for _, name in ipairs({ "Recent", "Recent Items", "Free Slots", "OneBag", "MultiBag" }) do used[name:lower()] = true end
    for i, name in ipairs(self.baseAssignable) do self.assignable[i] = name end
    local custom = {}
    if type(db.customCategories) == "table" then
        for _, name in ipairs(db.customCategories) do
            if type(name) == "string" then name = name:match("^%s*(.-)%s*$") end
            if #custom < 12 and type(name) == "string" and #name > 0 and #name <= 24
                and not name:find("[%c|]") and not used[name:lower()] then
                custom[#custom + 1] = name; used[name:lower()] = true
                self.categories[#self.categories + 1] = name; self.assignable[#self.assignable + 1] = name
            end
        end
    end
    db.customCategories = custom
    if db.viewMode ~= "categories" and db.viewMode ~= "onebag" and db.viewMode ~= "multibag" and db.viewMode ~= "recent" then db.viewMode = "categories" end
    if type(db.showRecent) ~= "boolean" then db.showRecent = true end
    if not FS.modules.Vendor:ValidNumber(db.width, 660, 1100) then db.width = 820 end
    if not FS.modules.Vendor:ValidNumber(db.height, 420, 780) then db.height = 500 end
    if not FS.modules.Vendor:ValidNumber(db.scale, 0.7, 1.15) then db.scale = 0.85 end
    db.favorites = type(db.favorites) == "table" and db.favorites or { [6948] = true }
    for id, value in pairs(db.favorites) do
        if type(id) ~= "number" or not FS.modules.Vendor:ValidNumber(id, 1, 100000000)
            or id ~= math.floor(id) or type(value) ~= "boolean" then db.favorites[id] = nil end
    end
    local valid = false
    for _, value in ipairs(self.categories) do if db.category == value then valid = true end end
    if not valid then db.category = "All" end
    valid = false
    for _, value in ipairs(self.sorts) do if db.sort == value then valid = true end end
    if not valid then db.sort = "category" end
    db.categoryOverrides = type(db.categoryOverrides) == "table" and db.categoryOverrides or {}
    for id, name in pairs(db.categoryOverrides) do
        local allowed = false
        for _, category in ipairs(self.assignable) do
            if name == category then allowed = true end
        end
        if type(id) ~= "number" or not FS.modules.Vendor:ValidNumber(id, 1, 100000000)
            or id ~= math.floor(id) or not allowed then db.categoryOverrides[id] = nil end
    end
    for _, key in ipairs({ "x", "y" }) do
        if not FS.modules.Vendor:ValidNumber(db[key], -10000, 10000) then db[key] = 0 end
    end
end
function B:Initialize()
    self:NormalizeSettings()
    self:InstallNativeHooks()
    local frame = CreateFrame("Frame")
    self.events = frame
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN" }) do FS:RegisterClientEvent(frame,event) end
    frame:SetScript("OnEvent", function(_, event)
        if event=="ADDON_LOADED" then self:InstallNativeHooks(); return end
        if event=="BAG_UPDATE_COOLDOWN" or event=="SPELL_UPDATE_COOLDOWN" then
            if not InCombatLockdown() and self.window and self.window:IsShown() then for _,cell in ipairs(self.window.cells) do self:UpdateCellExtras(cell,cell.row) end end
            return
        end
        if event == "ADDON_LOADED" or event == "PLAYER_REGEN_ENABLED" then self:InstallNativeHooks() end
        if event == "BAG_UPDATE_DELAYED" then self:ScanNewItems() end
        self:Refresh()
    end)
    self:ScanNewItems()
end
function B:ToggleWindow()
    if InCombatLockdown() then return end
    if not FS:IsModuleEnabled("Bags") then FS:Print("Bags is disabled. Enable it in /fs."); return end
    local frame = self:CreateWindow()
    if frame:IsShown() then frame:Hide() else self:ShowWindow() end
end
function B:ShowWindow()
    if InCombatLockdown() then return end
    if not FS:IsModuleEnabled("Bags") then return end
    FS:CloseSettingsScreens()
    if FS.window then FS.window:Hide() end
    if FS.modules.Vendor.window then FS.modules.Vendor.window:Hide() end
    if FS.modules.Gear and FS.modules.Gear.window then FS.modules.Gear.window:Hide() end
    self:CreateWindow():Show()
    self:Refresh()
end

-- Keep the client's secure bag functions intact; redirect their completed UI action.
function B:QueueNativeAction(action)
    if self.redirecting or not FS.db or not FS.db.bags.replaceNative or not FS:IsModuleEnabled("Bags") then return end
    if InCombatLockdown() then
        return
    end
    -- The last completed API is the outermost request (OpenBackpack can
    -- internally call ToggleBackpack). Its intent must win over inner calls.
    self.nativeIntent = action
    if self.nativeQueued then return end
    self.nativeQueued = true
    C_Timer.After(0, function()
        self.nativeQueued = false
        local intent = self.nativeIntent; self.nativeIntent = nil
        if not FS.db.bags.replaceNative or not FS:IsModuleEnabled("Bags") or InCombatLockdown() then return end
        if ContainerFrame_AllowedToOpenBags and not ContainerFrame_AllowedToOpenBags() then return end
        local shown = self.window and self.window:IsShown()
        if intent == "close" or intent == "toggle" and shown then
            if self.window then self.window:Hide() end
        else self:ShowWindow() end
    end)
end
function B:SuppressNativeFrame(container)
    local id = container.GetBagID and container:GetBagID() or container.GetID and container:GetID()
    if container ~= ContainerFrameCombinedBags and (type(id) ~= "number" or id < 0 or id > FS.modules.Vendor:BagLimit()) then return end
    if InCombatLockdown() then return end
    if self.redirecting or not FS.db or not FS.db.bags.replaceNative or not FS:IsModuleEnabled("Bags") then return end
    -- Hide during Show itself, before painting, rather than reopening and
    -- hiding the client's frames repeatedly from a delayed callback.
    self:ScanNewItems()
    self.redirecting = true; container:Hide(); self.redirecting = false
    if not self.window or not self.window:IsShown() then self:QueueNativeAction("open") end
end
function B:InstallNativeHooks()
    if not hooksecurefunc or InCombatLockdown() then return end
    self.nativeHooks = self.nativeHooks or {}
    for name, kind in pairs({ ToggleAllBags = "toggle", ToggleBackpack = "toggle", ToggleBag = "toggle",
        OpenAllBags = "open", OpenBackpack = "open", OpenBag = "open", CloseBag = "close", CloseAllBags = "close", CloseBackpack = "close" }) do
        if type(_G[name]) == "function" and not self.nativeHooks[name] then
            self.nativeHooks[name] = true
            local action, apiName = kind, name
            hooksecurefunc(name, function(bag)
                -- Owned close requests can be rejected by the native UI. A successful
                -- request also calls CloseBackpack, which supplies the close action.
                if apiName == "CloseAllBags" and bag ~= nil then return end
                if (apiName == "ToggleBag" or apiName == "OpenBag" or apiName == "CloseBag")
                    and (type(bag) ~= "number" or bag < 0 or bag > FS.modules.Vendor:BagLimit()) then return end
                self:QueueNativeAction(action)
            end)
        end
    end
    local function track(frame)
        if frame and frame.HookScript and not frame.fsBagsRedirect then
            frame.fsBagsRedirect = true
            frame:HookScript("OnShow", function(container) self:SuppressNativeFrame(container) end)
            if frame:IsShown() then self:SuppressNativeFrame(frame) end
        end
    end
    track(ContainerFrameCombinedBags)
    for i = 1, (NUM_CONTAINER_FRAMES or FS.modules.Vendor:BagLimit() + 1) do track(_G["ContainerFrame" .. i]) end
end
