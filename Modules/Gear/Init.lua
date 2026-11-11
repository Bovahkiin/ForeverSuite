local _, FS = ...
local G = { slotNames = { "Head", "Neck", "Shoulders", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrists", "Hands", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" } }
FS:RegisterModule("Gear", G)
function G:NormalizeSettings()
    local db, V = FS.db.gear, FS.modules.Vendor
    db.warningPercent = V:ValidNumber(db.warningPercent, 1, 100) or 25
    for _, key in ipairs({ "x", "y" }) do db[key] = V:ValidNumber(db[key], -10000, 10000) or 0 end
end
function G:Snapshot()
    local result = { items = {}, current = 0, maximum = 0, equipped = 0, damaged = 0, broken = 0, lowest = nil, itemLevelTotal=0, itemLevelCount=0 }
    local V = FS.modules.Vendor
    for slot, label in ipairs(self.slotNames) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        if V:IsSecret(link) then link = nil end
        if V:IsSecret(icon) then icon = nil end
        if V:IsSecret(id) then id = nil end
        local row = { slot = slot, label = label, link = link, icon = icon, equipped = link ~= nil or id ~= nil or icon ~= nil }
        if row.equipped then
            result.equipped = result.equipped + 1
            local name
            if (link or id) and C_Item and C_Item.GetItemInfo then name = C_Item.GetItemInfo(link or id) end
            row.name = not V:IsSecret(name) and name or nil
            local level
            if link or id then
                if C_Item and C_Item.GetDetailedItemLevelInfo then level=FS.Tools:Call(C_Item.GetDetailedItemLevelInfo,link or id) end
                if level==nil and C_Item and C_Item.GetItemInfo then level=select(4,FS.Tools:Call(C_Item.GetItemInfo,link or id)) end
            end
            if FS.Tools:Number(level) and level>0 then
                row.itemLevel=level
                if slot~=4 and slot~=19 then result.itemLevelTotal=result.itemLevelTotal+level; result.itemLevelCount=result.itemLevelCount+1 end
            end
            local current, maximum
            if GetInventoryItemDurability then current, maximum = GetInventoryItemDurability(slot) end
            if not V:IsSecret(current) and not V:IsSecret(maximum) and V:ValidNumber(maximum, 1, 1000000)
                and V:ValidNumber(current, 0, maximum) then
                row.current, row.maximum = current, maximum
                row.percent = current / maximum * 100
                result.current, result.maximum = result.current + current, result.maximum + maximum
                result.lowest = math.min(result.lowest or 100, row.percent)
                if current < maximum then result.damaged = result.damaged + 1 end
                if current == 0 then result.broken = result.broken + 1 end
            end
        end
        result.items[#result.items + 1] = row
    end
    result.percent = result.maximum > 0 and result.current / result.maximum * 100 or nil
    result.averageItemLevel=result.itemLevelCount>0 and result.itemLevelTotal/result.itemLevelCount or nil
    return result
end
function G:Initialize()
    self:NormalizeSettings()
    local frame = CreateFrame("Frame"); self.events = frame
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_DURABILITY", "UPDATE_INVENTORY_ALERTS", "GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "PLAYER_REGEN_ENABLED" }) do FS:RegisterClientEvent(frame,event) end
    frame:SetScript("OnEvent", function() self:Refresh() end)
    self:CreateIndicator(); self:Refresh()
end
function G:Refresh()
    if not FS.db then return end
    local enabled = FS:IsModuleEnabled("Gear")
    if self.indicator then self.indicator:SetShown(enabled and FS.db.gear.showButton) end
    if not enabled then if self.window then self.window:Hide() end; return end
    self.data = self:Snapshot()
    local lowest = self.data.lowest
    if not lowest or lowest > FS.db.gear.warningPercent then self.warned = false
    elseif FS.db.gear.warn and not self.warned and not InCombatLockdown() then
        FS:Print("Gear durability is low (" .. math.floor(lowest) .. "% on your most damaged item). Visit a repair merchant.")
        self.warned = true
        if FS.Extensions then FS.Extensions:Alert('Low durability') end
    end
    if self.indicator then
        self.indicator:SetText("Gear: " .. (self.data.percent and (math.floor(self.data.percent) .. "%") or "--"))
        self.indicator:SetBackdropBorderColor(self.data.broken > 0 and 1 or 0.55, self.data.broken > 0 and 0.2 or 0.4, self.data.broken > 0 and 0.2 or 0.9, 1)
    end
    self:RefreshWindow(); self:RefreshSettings()
end
function G:SettingsChanged()
    self:NormalizeSettings(); self:Refresh(); FS:RefreshConfig()
end
function G:ShowWindow()
    if not FS:IsModuleEnabled("Gear") then return end
    FS:CloseSettingsScreens()
    if FS.window then FS.window:Hide() end
    for name, module in pairs(FS.modules) do
        if name ~= "Gear" and module.window and not InCombatLockdown() then module.window:Hide() end
    end
    self:CreateWindow():Show(); self:Refresh()
end
function G:ToggleWindow()
    if self.window and self.window:IsShown() then self.window:Hide() else self:ShowWindow() end
end
