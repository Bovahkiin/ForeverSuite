local _, FS = ...
local G, V = FS.modules.Gear, FS.modules.Vendor
local WHITE = "Interface\\Buttons\\WHITE8X8"
local function skin(f)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0.035, 0.045, 0.065, 0.98); f:SetBackdropBorderColor(0.45, 0.32, 0.7, 1)
end
local function label(parent, text, x, y, width)
    local f = FS.Widgets:Label(parent, "ForeverSuiteFontSmall")
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent, text, x, y, width, callback)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate"); skin(f)
    f:SetSize(width, 28); f:SetPoint("TOPLEFT", x, y)
    local caption = f:CreateFontString(nil, "OVERLAY", "ForeverSuiteFontSmall"); caption:SetPoint("CENTER"); f:SetFontString(caption); f:SetText(text)
    FS:ApplyFont(caption)
    f:SetScript("OnClick", callback)
    f:SetScript("OnEnter", function(b) b:SetBackdropBorderColor(0.75, 0.6, 1, 1) end)
    f:SetScript("OnLeave", function(b) b:SetBackdropBorderColor(0.45, 0.32, 0.7, 1) end)
    return f
end
function G:CreateIndicator()
    if self.indicator then return end
    local f = button(UIParent, "Gear: --", 0, 0, 150, function() self:ToggleWindow() end)
    f:ClearAllPoints()
    local bar=BagsBar or MainMenuBarBagButtons
    if bar then f:SetPoint("RIGHT",bar,"LEFT",-10,0)
    else f:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-310,16) end
    f:HookScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT"); GameTooltip:AddLine("Gear & Durability")
        GameTooltip:AddLine("Click to inspect your equipment and repair status.", 1, 1, 1, true); GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self.indicator = f
    if FS.Layout then FS.Layout:Register("GearButton",f,"Gear Button") end
end
function G:CreateWindow()
    if self.window then return self.window end
    local f = CreateFrame("Frame", "ForeverSuiteGearWindow", UIParent, "BackdropTemplate"); self.window = f
    f:HookScript("OnShow",function() FS:CloseOtherWindows(f) end)
    skin(f); f:SetSize(600, 574); f:SetPoint("CENTER", UIParent, "CENTER", FS.db.gear.x, FS.db.gear.y)
    f:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 600, (UIParent:GetHeight() - 32) / 574))
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing(); local x, y = frame:GetCenter(); local ux, uy = UIParent:GetCenter()
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y and ux and uy then FS.db.gear.x, FS.db.gear.y = x - ux / ratio, y - uy / ratio end
    end)
    f:SetScript("OnHide", function(frame) frame:StopMovingOrSizing(); GameTooltip:Hide() end)
    local accent = f:CreateTexture(nil, "ARTWORK"); accent:SetColorTexture(0.65, 0.45, 0.95, 1)
    accent:SetHeight(2); accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
    label(f, "FOREVERSUITE / GEAR", 16, -19, 260)
    f.back = button(f, "Control Center", 398, -12, 160, function() FS:ShowConfig() end)
    f.summary = label(f, "", 16, -51, 564)
    f.summary:SetHeight(30)
    f.rows = {}
    for slot, name in ipairs(self.slotNames) do
        local x, y = 16 + ((slot - 1) % 2) * 286, -82 - math.floor((slot - 1) / 2) * 43
        local row = CreateFrame("Button", nil, f, "BackdropTemplate"); skin(row); row:SetSize(276, 39); row:SetPoint("TOPLEFT", x, y)
        row.slot = slot; row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(30, 30); row.icon:SetPoint("TOPLEFT", 4, -4)
        row.name = label(row, name, 42, -3, 228); row.name:SetHeight(16)
        row.status = label(row, "", 42, -20, 228)
        row:SetScript("OnEnter", function(b)
            local item = self.data and self.data.items[b.slot]
            if not item or not item.equipped then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            if GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player", b.slot)
            elseif item.link then GameTooltip:SetHyperlink(item.link) end
            if item.percent then GameTooltip:AddLine("Durability: " .. item.current .. "/" .. item.maximum .. " (" .. math.floor(item.percent) .. "%)", 1, 1, 1) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end); f.rows[slot] = row
    end
    f.repair = button(f, "Repair gear", 16, -520, 180, function()
        if V:CanTransact() then V:TryRepair(V.repairConfirmation ~= nil) end; self:Refresh()
    end)
    f.settings = button(f, "Settings", 406, -520, 174, function() FS:ConfigureModule("Gear") end)
    f.message = label(f, "", 16, -557, 564)
    UISpecialFrames[#UISpecialFrames + 1] = "ForeverSuiteGearWindow"
    f:Hide(); if FS.Layout then FS.Layout:Register("Gear",f,"Gear Overview") end; return f
end
function G:RefreshWindow()
    local f = self.window; if not f or not f:IsShown() or not self.data then return end
    local data = self.data
    f.summary:SetText((data.percent and ("Durability: " .. math.floor(data.percent) .. "%") or "Durability: no readable values") .. "  |  " .. data.damaged .. " damaged  |  " .. data.broken .. " broken")
    if data.averageItemLevel then f.summary:SetText(f.summary:GetText().." | Mean equipped ilvl: "..string.format("%.1f",data.averageItemLevel)) end
    for i, row in ipairs(f.rows) do
        local item = data.items[i]
        row.icon:SetTexture(item.icon); row.name:SetText(item.label .. (item.equipped and (": " .. (item.name or "Loading item...")) or ""))
        row.status:SetText(not item.equipped and "Empty" or item.percent and (math.floor(item.percent) .. "%  |  " .. item.current .. "/" .. item.maximum) or "No durability value")
        if item.itemLevel then row.status:SetText("ilvl "..item.itemLevel.." | "..row.status:GetText()) end
        local low = item.percent and item.percent <= FS.db.gear.warningPercent
        row.status:SetTextColor(low and 1 or 0.65, low and 0.35 or 0.8, low and 0.2 or 0.9)
    end
    local quote = V:RepairQuote()
    f.repair:SetText(V.repairConfirmation and "Confirm Repair" or "Repair gear")
    f.repair:SetEnabled(V:CanTransact() and quote ~= nil and not V.busy)
    f.message:SetText(V.merchantOpen and (V.status or (quote and ("Repair quote: " .. V:Money(quote.cost)) or "This merchant cannot repair your gear.")) or "Visit a repair merchant to repair your gear.")
end
function G:CreateSettings(host)
    local f = CreateFrame("Frame", nil, host, "BackdropTemplate"); host.gearSettings = f; self.settings = f
    skin(f); f:SetSize(892, 420); f:SetPoint("TOPLEFT", 24, FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel() + 30); f:EnableMouse(true)
    f.back = button(f, "Back to Control Center", 20, -12, 220, function() f:Hide() end)
    label(f, "Gear settings", 260, -20, 490)
    label(f, "Track your equipment and know when it needs repairs.", 20, -64, 850)
    f.indicator = button(f, "", 20, -110, 400, function() FS.db.gear.showButton = not FS.db.gear.showButton; self:SettingsChanged() end)
    label(f, "A small button near your bags opens the equipment overview.", 20, -147, 400)
    f.warn = button(f, "", 450, -110, 400, function() FS.db.gear.warn = not FS.db.gear.warn; self:SettingsChanged() end)
    label(f, "Show one message when equipment becomes badly damaged.", 450, -147, 400)
    f.threshold = button(f, "", 20, -200, 400, function()
        local levels = { [25] = 50, [50] = 10, [10] = 25 }; FS.db.gear.warningPercent = levels[FS.db.gear.warningPercent] or 25; self:SettingsChanged()
    end)
    label(f, "Based on your most damaged equipped item. Click to change.", 20, -237, 400)
    label(f, "Repair funds, limits and automatic repairs are configured in Vendor settings.", 20, -314, 850)
    f:Hide(); return f
end
function G:RefreshSettings()
    local f = self.settings; if not f or not f:IsShown() then return end
    f.indicator:SetText("Show gear button: " .. (FS.db.gear.showButton and "On" or "Off"))
    f.warn:SetText("Low durability warning: " .. (FS.db.gear.warn and "On" or "Off"))
    f.threshold:SetText("Warn at: " .. FS.db.gear.warningPercent .. "%")
end
