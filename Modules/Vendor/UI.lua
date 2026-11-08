local _, FS = ...
local V = FS.modules.Vendor
local WHITE = "Interface\\Buttons\\WHITE8X8"
local function skin(frame)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.035, 0.045, 0.065, 0.98); frame:SetBackdropBorderColor(0.3, 0.24, 0.12, 1)
end
local hints = {
    ["Sell junk"] = "Sell only the items allowed by your rules. Protected items and saved quantities stay in your bags.",
    ["Repair gear"] = "Repair your equipment using the chosen funds and spending limit.",
    ["Buy supplies"] = "Buy missing shopping-list items within your budget.",
    ["Never sell"] = "Protect every copy of this item from junk sales.",
}

local function label(parent, text, x, y, width, font)
    local value = parent:CreateFontString(nil, "OVERLAY", font or "ForeverSuiteFontSmall")
    value:SetPoint("TOPLEFT", x, y)
    value:SetWidth(width)
    value:SetJustifyH("LEFT")
    value:SetText(text)
    FS:ApplyFont(value)
    return value
end

local function button(parent, text, x, y, width, action)
    local value = CreateFrame("Button", nil, parent, "BackdropTemplate")
    value:SetSize(width, 26); value:SetPoint("TOPLEFT", x, y); skin(value)
    value:SetBackdropColor(0.08, 0.1, 0.13, 1)
    local caption = value:CreateFontString(nil, "OVERLAY", "ForeverSuiteFontSmall")
    caption:SetPoint("CENTER"); value:SetFontString(caption); value:SetText(text)
    FS:ApplyFont(caption)
    value:SetScript("OnClick", action)
    value:SetScript("OnEnter", function(control)
        control:SetBackdropBorderColor(0.95, 0.68, 0.24, 1)
        if hints[text] then GameTooltip:SetOwner(control, "ANCHOR_RIGHT"); GameTooltip:AddLine(text); GameTooltip:AddLine(hints[text], 1, 1, 1, true); GameTooltip:Show() end
    end)
    value:SetScript("OnLeave", function(control) control:SetBackdropBorderColor(0.3, 0.24, 0.12, 1); GameTooltip:Hide() end)
    return value
end

local function edit(parent, x, y, width, text)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    skin(box); box:SetFontObject("ForeverSuiteFontSmall"); box:SetTextInsets(8, 8, 0, 0)
    FS:ApplyFont(box,12)
    box:SetSize(width, 24)
    box:SetPoint("TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetText(text or "")
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

local function checkbox(parent, text, x, y, action)
    local value = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    value:SetPoint("TOPLEFT", x, y)
    value.label = label(parent, text, x + 34, y - 8, 295)
    value:SetScript("OnClick", function(self) action(self:GetChecked() and true or false) end)
    return value
end

function V:CreateWindow()
    if self.window then return self.window end
    local frame = CreateFrame("Frame", "ForeverSuiteVendorWindow", UIParent, "BackdropTemplate")
    self.window = frame
    frame:HookScript("OnShow",function(frame) FS:CloseOtherWindows(frame) end)
    frame:SetSize(760, 610)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function(self) self:StopMovingOrSizing(); if V.glowWindow then V.glowWindow:Hide() end end)
    skin(frame)
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 760, (UIParent:GetHeight() - 32) / 610))
    local accent = frame:CreateTexture(nil, "ARTWORK"); accent:SetColorTexture(0.95, 0.68, 0.24, 1)
    accent:SetHeight(2); accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    frame.back = button(frame, "Back to Control Center", 530, -17, 190, function() FS:ShowConfig() end)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local logo = frame:CreateTexture(nil, "ARTWORK"); logo:SetTexture(FS.icon)
    logo:SetSize(30, 30); logo:SetPoint("TOPLEFT", 22, -13)
    label(frame, "ForeverSuite | Vendor & Junk", 62, -20, 450, "ForeverSuiteFontLarge")
    label(frame, "Review your junk before selling. Your protected items stay safe.", 22, -45, 690)
    frame.tabs = {}
    for i, name in ipairs({ "Overview", "Rules", "Supplies", "Settings", "Buy Back", "History" }) do
        frame.tabs[name] = button(frame, ({ Overview = "Junk", Rules = "Item rules", Supplies = "Shopping list", ["Buy Back"] = "Buyback" })[name] or name, 20 + (i - 1) * 120, -70, 114, function() if name == "Settings" then FS:ConfigureModule("Vendor"); return end; self.tab = name; self.page = 1; self:RefreshWindow() end)
    end
    frame.summary = label(frame, "", 22, -108, 712, "ForeverSuiteFontNormal")
    frame.summary:SetHeight(42)
    frame.status = label(frame, "", 22, -548, 712)
    frame.status:SetHeight(36)
    frame.footer = label(frame, "", 22, -586, 700)
    frame.pages = {}
    for _, name in ipairs({ "Overview", "Rules", "Supplies", "Settings", "Buy Back", "History" }) do
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 20, -156)
        page:SetSize(720, 384)
        page:Hide()
        frame.pages[name] = page
    end
    self.tab, self.page = "Overview", 1
    self:CreateOverview(frame.pages.Overview)
    self:CreateRulesEditor(frame.pages.Rules)
    self:CreateSupplies(frame.pages.Supplies)
    self:CreateSettings(frame.pages.Settings)
    self:CreateBuyback(frame.pages["Buy Back"])
    self:CreateHistory(frame.pages.History)
    UISpecialFrames[#UISpecialFrames + 1] = "ForeverSuiteVendorWindow"
    frame:Hide()
    if FS.Layout then FS.Layout:Register("Vendor",frame,"Vendor & Junk") end
    return frame
end

function V:ToggleWindow()
    if not FS:IsModuleEnabled("Vendor") then return end
    local frame = self:CreateWindow()
    if frame:IsShown() then frame:Hide(); self.autoOpened = false else self:ShowWindow(false) end
end

function V:ShowWindow(automatic)
    if not FS:IsModuleEnabled("Vendor") then return end
    if FS.window then FS.window:Hide() end
    if FS.modules.Bags.window and not InCombatLockdown() then FS.modules.Bags.window:Hide() end
    if FS.modules.Gear and FS.modules.Gear.window then FS.modules.Gear.window:Hide() end
    local frame = self:CreateWindow()
    if automatic and not frame:IsShown() then
        self.autoOpened = true
        frame:ClearAllPoints()
        if MerchantFrame then frame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 8, 0) else frame:SetPoint("CENTER") end
    elseif not automatic then self.autoOpened = false end
    frame:Show()
    self:Refresh()
end

function V:CreateRows(parent, count, startY)
    parent.rows = {}
    for index = 1, count do
        local row = CreateFrame("Frame", nil, parent, "BackdropTemplate"); skin(row)
        row:SetSize(700, 38)
        row:SetPoint("TOPLEFT", 0, startY - (index - 1) * 40)
        row.icon = CreateFrame("Button", nil, row)
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 2, 0)
        row.texture = row.icon:CreateTexture(nil, "ARTWORK")
        row.texture:SetAllPoints()
        row.name = label(row, "", 42, -2, 370, "ForeverSuiteFontSmall")
        row.reason = label(row, "", 42, -19, 370)
        row.reason:SetTextColor(0.7, 0.7, 0.7)
        row.action = button(row, "", 420, -5, 130, function() if row.onAction then row.onAction() end end)
        row.keep = button(row, "Never sell", 556, -5, 130, function() if row.item then self:KeepItem(row.item.id) end end)
        row.icon:SetScript("OnEnter", function(icon)
            if not row.item then return end
            GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
            if row.item.link then GameTooltip:SetHyperlink(row.item.link) else GameTooltip:AddLine(row.item.name or ("Item #" .. row.item.id)) end
            GameTooltip:AddLine("ForeverSuite: " .. (row.item.reason or ""), 0.3, 1, 0.7, true)
            if row.item.sellCount and row.item.sellCount > 0 and row.item.sellCount < row.item.count then
                GameTooltip:AddLine("Partial stack: use ForeverSuite Sell to preserve reserved stock.", 1, 0.65, 0.15, true)
            end
            GameTooltip:Show()
        end)
        row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
        parent.rows[index] = row
    end
    parent.previous = button(parent, "Previous", 0, -345, 96, function() self.page = math.max(1, self.page - 1); self:RefreshWindow() end)
    parent.next = button(parent, "Next", 102, -345, 96, function() self.page = self.page + 1; self:RefreshWindow() end)
    parent.pageLabel = label(parent, "", 218, -353, 460)
end

function V:FillRows(parent, entries, callback)
    local pages = math.max(1, math.ceil(#entries / #parent.rows))
    self.page = math.min(self.page or 1, pages)
    for index, row in ipairs(parent.rows) do
        local entry = entries[(self.page - 1) * #parent.rows + index]
        row.item, row.onAction = entry, nil
        if entry then
            row:Show()
            row.texture:SetTexture(entry.icon or 134400)
            row.keep:Hide()
            row.keep:SetEnabled(true)
            row.action:Hide()
            self:ApplyGlow(row.icon, entry)
            callback(row, entry)
        else row:Hide(); self:ApplyGlow(row.icon, nil) end
    end
    parent.previous:SetEnabled(self.page > 1)
    parent.next:SetEnabled(self.page < pages)
    parent.pageLabel:SetText("Page " .. self.page .. " of " .. pages)
    parent.previous:SetShown(pages > 1); parent.next:SetShown(pages > 1); parent.pageLabel:SetShown(pages > 1)
end

function V:CreateOverview(parent)
    parent.sell = button(parent, "Sell junk", 0, 0, 130, function() self:ReviewSales() end)
    parent.repair = button(parent, "Repair gear", 136, 0, 140, function()
        self:TryRepair(self.repairConfirmation ~= nil, function() if self:Settings().autoRestock then self:StartRestock() end end)
    end)
    parent.restock = button(parent, "Buy supplies", 282, 0, 120, function() self:StartRestock() end)
    parent.stop = button(parent, "Stop", 408, 0, 95, function() self:StopTransactions("Stopped. Issued transactions may already have completed."); self:Refresh() end)
    parent.filter = button(parent, "Show All Items", 509, 0, 177, function() self.showAll = not self.showAll; self.page = 1; self:RefreshWindow() end)
    parent.hint = label(parent, "Colored items can be sold. A number on the border means only that amount will be sold.", 0, -35, 700)
    parent.empty = label(parent, "Nothing ready to sell. Mark unwanted items as junk in your bags.", 0, -90, 700)
    self:CreateRows(parent, 7, -60)
end

function V:CreateRulesEditor(parent)
    label(parent, "Enter an item ID, paste a link or drop an item here. Rules apply to that item ID.", 0, 0, 700)
    parent.id = edit(parent, 6, -26, 310)
    parent.id:SetScript("OnReceiveDrag", function(box)
        local kind, id, link = GetCursorInfo()
        if kind == "item" then box:SetText(link or tostring(id)); ClearCursor() end
    end)
    button(parent, "Load Rule", 330, -26, 120, function()
        local id = self:ItemID(parent.id:GetText())
        if not id then self.status = "Enter a valid item ID or item link."; self:RefreshWindow(); return end
        local rule = self:Settings().rules[id] or { keep = 0, target = 0 }
        parent.keep:SetText(tostring(rule.keep)); parent.target:SetText(tostring(rule.target))
        self.status = self:ItemName(id); self:RefreshWindow()
    end)
    label(parent, "Keep at least", 0, -62, 115)
    parent.keep = edit(parent, 122, -56, 72, "0")
    label(parent, "Restock to", 216, -62, 100)
    parent.target = edit(parent, 318, -56, 72, "0")
    label(parent, "The larger of Keep and Restock is reserved. Never sell below that quantity.", 0, -87, 700)
    local function save(junk)
        local id = self:ItemID(parent.id:GetText())
        local keep = self:ValidNumber(tonumber(parent.keep:GetText()), 0, 100000)
        local target = self:ValidNumber(tonumber(parent.target:GetText()), 0, 100000)
        if not id or not keep or not target or keep ~= math.floor(keep) or target ~= math.floor(target) then
            self.status = "Enter a valid item ID and whole quantities from 0 to 100000."; self:RefreshWindow(); return
        end
        self:SetRule(id, junk, keep, target)
        self.status = "Saved " .. self:ItemName(id) .. (junk and " as custom junk." or " as stock only.")
        self:RefreshWindow()
    end
    button(parent, "Save as Junk", 0, -112, 132, function() save(true) end)
    button(parent, "Save Stock Only", 138, -112, 145, function() save(false) end)
    button(parent, "Always Keep", 289, -112, 125, function()
        local id = self:ItemID(parent.id:GetText()); if id then self:KeepItem(id) end
    end)
    button(parent, "Remove Rule", 420, -112, 126, function()
        local id = self:ItemID(parent.id:GetText())
        if id then self:Settings().rules[id] = nil; self:SettingsChanged() end
    end)
    button(parent, "Remove Keep", 552, -112, 132, function()
        local id = self:ItemID(parent.id:GetText())
        if id then self:Settings().alwaysKeep[id] = nil; self:SettingsChanged() end
    end)
    label(parent, "Always Keep and item protection override custom junk. Auto Junk ignores custom junk rules.", 0, -147, 700)
    self:CreateRows(parent, 4, -175)
end

function V:CreateSupplies(parent)
    label(parent, "Set Restock to in Rules. Purchases use only gold and never exceed your budget or target.", 0, 0, 700)
    label(parent, "Targets use carried bags only. Merchant bundles may leave a small shortfall.", 0, -20, 700)
    parent.restock = button(parent, "Restock Now", 0, -43, 145, function() self:StartRestock() end)
    self:CreateRows(parent, 6, -90)
end

function V:CreateSettings(parent)
    parent.checks = {}
    local function check(key, text, x, y)
        parent.checks[key] = checkbox(parent, text, x, y, function(value)
            self:Settings()[key] = value; self:SettingsChanged()
        end)
    end
    check("enabled", "Enable Vendor module", 0, 0)
    check("showPanel", "Open panel at merchants", 354, 0)
    parent.mode = button(parent, "", 6, -43, 320, function()
        local current = self:Settings().mode
        for index, mode in ipairs(self.modes) do if mode == current then self:SetMode(self.modes[index % #self.modes + 1]); break end end
    end)
    check("includeGray", "Include gray items", 0, -78)
    check("protectRare", "Protect rare and higher quality", 354, -78)
    check("autoRepair", "Repair automatically", 0, -112)
    check("confirmRepair", "Confirm repairs above limit", 354, -112)
    check("autoRestock", "Restock automatically", 0, -146)
    check("report", "Print visit report", 354, -146)
    parent.source = button(parent, "", 6, -185, 320, function()
        local nextSource = { personal = "guild", guild = "guildFirst", guildFirst = "personal" }
        self:Settings().repairSource = nextSource[self:Settings().repairSource]; self:SettingsChanged()
    end)
    parent.money = {}
    for index, data in ipairs({ { "repairLimit", "Repair limit (gold; 0 = unlimited)", 0, -228 },
        { "restockBudget", "Restock budget per visit (gold)", 354, -228 }, { "moneyReserve", "Keep this much gold", 0, -287 } }) do
        label(parent, data[2], data[3] + 6, data[4], 330)
        parent.money[data[1]] = edit(parent, data[3] + 12, data[4] - 22, 145)
    end
    button(parent, "Save Budgets", 366, -309, 175, function()
        local values = {}
        for key, box in pairs(parent.money) do
            local gold = self:ValidNumber(tonumber(box:GetText()), 0, 1000000)
            if not gold then self.status = "Enter gold amounts from 0 to 1000000 using a decimal point."; self:RefreshWindow(); return end
            values[key] = math.floor(gold * 10000 + 0.5)
        end
        for key, value in pairs(values) do self:Settings()[key] = value end
        self:SettingsChanged(); self.status = "Budgets saved."; self:RefreshWindow()
    end)
    label(parent, "Guild first falls back to personal funds. Changes take effect for the next automatic visit.", 6, -353, 695)
end

function V:CreateBuyback(parent)
    label(parent, "Only items still in this merchant's buyback list can be recovered. There is no unlimited undo.", 0, 0, 700)
    label(parent, "Buy back consumes gold. Always Keep an item before recovering it to avoid future auto-sales.", 0, -20, 700)
    self:CreateRows(parent, 7, -58)
end

function V:CreateHistory(parent)
    parent.text = label(parent, "", 0, 0, 700)
    parent.text:SetHeight(330)
    parent.text:SetJustifyV("TOP")
    button(parent, "Previous", 0, -345, 96, function() self.page = math.max(1, self.page - 1); self:RefreshWindow() end)
    button(parent, "Next", 102, -345, 96, function() self.page = self.page + 1; self:RefreshWindow() end)
end

function V:CreateGlowControls(parent)
    -- Separate window keeps the rule list readable while leaving effects easy to configure.
    local frame = CreateFrame("Frame", "ForeverSuiteGlowWindow", UIParent, "BackdropTemplate")
    self.glowWindow = frame
    frame:SetSize(390, 260)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    skin(frame)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    label(frame, "Junk Highlight Effect", 22, -20, 330, "ForeverSuiteFontLarge")
    frame.enabled = checkbox(frame, "Highlight eligible junk", 15, -54, function(value) self:Settings().glow.enabled = value; self:SettingsChanged() end)
    frame.pulse = checkbox(frame, "Pulse effect", 15, -90, function(value) self:Settings().glow.pulse = value; self:SettingsChanged() end)
    frame.color = button(frame, "", 22, -132, 155, function()
        local nextColor = { green = "gold", gold = "cyan", cyan = "green" }
        self:Settings().glow.color = nextColor[self:Settings().glow.color]; self:SettingsChanged()
    end)
    label(frame, "Intensity (0.1 - 1)", 195, -137, 165)
    frame.intensity = edit(frame, 202, -161, 75)
    button(frame, "Save", 287, -161, 75, function()
        local value = self:ValidNumber(tonumber(frame.intensity:GetText()), 0.1, 1)
        if value then self:Settings().glow.intensity = value; self:SettingsChanged() end
    end)
    label(frame, "Amber always marks a partial stack. The number is the quantity eligible for sale.", 22, -211, 340)
    UISpecialFrames[#UISpecialFrames + 1] = "ForeverSuiteGlowWindow"
    frame:Hide()
    button(parent, "Highlight Effect...", 484, -26, 200, function()
        frame.enabled:SetChecked(self:Settings().glow.enabled)
        frame.pulse:SetChecked(self:Settings().glow.pulse)
        frame.color:SetText("Color: " .. self:Settings().glow.color)
        frame.intensity:SetText(tostring(self:Settings().glow.intensity))
        frame:Show()
    end)
end

function V:RefreshWindow()
    if not self.window or not self.plan then return end
    local frame, db, plan = self.window, self:Settings(), self.plan
    for name, page in pairs(frame.pages) do page:SetShown(name == self.tab) end
    for name, tab in pairs(frame.tabs) do tab:SetEnabled(name ~= self.tab) end
    local quote = self:RepairQuote()
    frame.summary:SetText("Junk worth " .. self:Money(plan.value) .. "  |  " .. plan.units .. " items ready to sell")
    frame.status:SetText(self.status or "")
    frame.footer:SetText(self.merchantOpen and "Your item protections and saved quantities apply to every sale." or "Visit a merchant to sell junk, repair gear or buy supplies.")
    local canAct = self:CanTransact() and not self.busy
    if self.tab == "Overview" then
        local page = frame.pages.Overview
        page.sell:SetEnabled(canAct and #plan.sale > 0)
        page.repair:SetEnabled(canAct and quote ~= nil)
        page.repair:SetText(self.repairConfirmation and "Confirm Repair" or "Repair gear")
        page.repair:SetShown(self.merchantOpen); page.restock:SetShown(self.merchantOpen); page.stop:SetShown(self.busy)
        page.empty:SetShown((self.showAll and #plan.items or #plan.sale) == 0)
        page.restock:SetEnabled(canAct)
        page.stop:SetEnabled(self.busy or self.repairConfirmation ~= nil)
        page.filter:SetText(self.showAll and "Show Eligible Only" or "Show All Items")
        self:FillRows(page, self.showAll and plan.items or plan.sale, function(row, item)
            row.name:SetText((item.link or item.name) .. " x" .. item.count)
            row.reason:SetText(item.reason .. (item.sellCount > 0 and (" | " .. self:Money(item.price * item.sellCount)) or ""))
            row.keep:Show()
            row.action:Show()
            row.action:SetText(item.sellCount > 0 and ("Sell " .. item.sellCount) or "Mark as Junk")
            row.action:SetEnabled(item.sellCount <= 0 or canAct)
            row.onAction = function()
                if item.sellCount > 0 then self:StartSelling(item)
                else
                    local rule = db.rules[item.id] or { keep = 0, target = 0 }
                    self:SetRule(item.id, true, rule.keep, rule.target)
                end
            end
        end)
    elseif self.tab == "Rules" then
        local page = frame.pages.Rules
        if not self.glowWindow then self:CreateGlowControls(page) end
        local ids, entries = {}, {}
        for id in pairs(db.rules) do ids[id] = true end
        for id in pairs(db.alwaysKeep) do ids[id] = true end
        for id in pairs(ids) do
            local rule = db.rules[id] or { keep = 0, target = 0 }
            local name, link = self:ItemName(id)
            entries[#entries + 1] = { id = id, name = name, link = link, reason = (db.alwaysKeep[id] and "Always Keep | " or "")
                .. (rule.junk and "Junk" or "Stock only") .. " | Keep " .. rule.keep .. " | Restock " .. rule.target }
        end
        table.sort(entries, function(a, b) return a.id < b.id end)
        self:FillRows(page, entries, function(row, entry)
            row.name:SetText(entry.id .. " | " .. (entry.link or entry.name))
            row.reason:SetText(entry.reason)
            row.action:Show(); row.action:SetText("Edit"); row.action:SetEnabled(true)
            row.onAction = function()
                local rule = db.rules[entry.id] or { keep = 0, target = 0 }
                page.id:SetText(tostring(entry.id)); page.keep:SetText(tostring(rule.keep)); page.target:SetText(tostring(rule.target))
            end
        end)
    elseif self.tab == "Supplies" then
        local page = frame.pages.Supplies
        page.restock:SetEnabled(canAct)
        local entries = self:RestockPlan().items
        if not self.merchantOpen then
            entries = {}
            for id, rule in pairs(db.rules) do
                if rule.target > 0 then entries[#entries + 1] = { id = id, name = self:ItemName(id), missing = math.max(0, rule.target - (plan.totals[id] or 0)), count = 0, reason = "Visit a merchant to check availability" } end
            end
            table.sort(entries, function(a, b) return a.id < b.id end)
        end
        self:FillRows(page, entries, function(row, entry)
            row.name:SetText(entry.name .. " | Missing " .. entry.missing .. " | Buy now " .. entry.count)
            row.reason:SetText(entry.reason .. (entry.cost and (" | " .. self:Money(entry.cost)) or ""))
        end)
    elseif self.tab == "Settings" then
        local page = frame.pages.Settings
        for key, check in pairs(page.checks) do check:SetChecked(db[key]) end
        page.mode:SetText("Selling mode: " .. self.modeNames[db.mode] .. " (click to change)")
        local sources = { personal = "Personal", guild = "Guild only", guildFirst = "Guild first, then personal" }
        page.source:SetText("Repair funds: " .. sources[db.repairSource])
        for key, box in pairs(page.money) do if not box:HasFocus() then box:SetText(tostring(db[key] / 10000)) end end
    elseif self.tab == "Buy Back" then
        self:FillRows(frame.pages["Buy Back"], self:BuybackList(), function(row, entry)
            row.name:SetText((entry.link or entry.name) .. " x" .. entry.count)
            row.reason:SetText("Buy back: " .. self:Money(entry.price))
            row.keep:Show(); entry.id = self:ItemID(entry.link)
            row.keep:SetEnabled(entry.id ~= nil)
            row.action:Show(); row.action:SetText("Buy Back"); row.action:SetEnabled(canAct)
            row.onAction = function() self:BuyBack(entry) end
        end)
    elseif self.tab == "History" then
        local texts = {}
        local pages = math.max(1, math.ceil(#db.history / 5))
        self.page = math.min(self.page, pages)
        for index = (self.page - 1) * 5 + 1, math.min(self.page * 5, #db.history) do
            local entry = db.history[index]
            texts[#texts + 1] = entry.date .. "\n" .. entry.text
        end
        frame.pages.History.text:SetText(#texts > 0 and table.concat(texts, "\n\n") or "No completed vendor visits yet.")
    end
    if self.glowWindow and self.glowWindow:IsShown() then
        self.glowWindow.enabled:SetChecked(db.glow.enabled)
        self.glowWindow.pulse:SetChecked(db.glow.pulse)
        self.glowWindow.color:SetText("Color: " .. db.glow.color)
    end
end


function V:SaleFingerprint(plan)
    local rows = {}
    for _, item in ipairs(plan.sale) do
        rows[#rows + 1] = table.concat({ item.bag, item.slot, item.id, item.guid or item.link or "", item.count, item.sellCount, item.price }, ":")
    end
    return table.concat(rows, "|")
end
function V:ReviewSales()
    if self.busy or not self:CanTransact() then return end
    local f = self.saleReview
    if not f then
        f = CreateFrame("Frame", "ForeverSuiteSaleReview", UIParent, "BackdropTemplate"); self.saleReview = f
        f:HookScript("OnShow",function()
            local bags=FS.modules.Bags.window
            f.returnTo=bags and bags:IsShown() and bags or self.window and self.window:IsShown() and self.window or nil
            FS:CloseOtherWindows(f)
        end)
        f:HookScript("OnHide",function()
            local previous=f.returnTo; f.returnTo=nil
            if previous and not FS.closingOtherWindows then previous:Show() end
        end)
        skin(f); f:SetSize(530, 480); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
        f:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 530, (UIParent:GetHeight() - 32) / 480))
        f:EnableMouse(true); f:SetFrameLevel(100)
        label(f, "REVIEW JUNK SALE", 18, -18, 490, "ForeverSuiteFontLarge")
        f.summary = label(f, "", 18, -52, 494); f.summary:SetHeight(40)
        label(f, "Only the quantities listed below will be sold.", 18, -98, 494)
        f.rows = {}
        for i = 1, 7 do
            local row = { text = label(f, "", 58, -132 - (i - 1) * 32, 444) }
            row.text:SetHeight(28)
            row.icon = f:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(26, 26); row.icon:SetPoint("TOPLEFT", 18, -128 - (i - 1) * 32)
            f.rows[i] = row
        end
        f.previous = button(f, "Previous", 18, -359, 110, function() f.page = math.max(1, f.page - 1); self:RefreshSaleReview() end)
        f.pages = label(f, "", 148, -367, 220)
        f.next = button(f, "Next", 402, -359, 110, function() f.page = f.page + 1; self:RefreshSaleReview() end)
        f.message = label(f, "", 18, -400, 494); f.message:SetHeight(32)
        f.cancel = button(f, "Cancel", 18, -442, 160, function() f:Hide() end)
        f.confirm = button(f, "Sell listed junk", 192, -442, 320, function() self:ConfirmSaleReview() end)
        UISpecialFrames[#UISpecialFrames + 1] = "ForeverSuiteSaleReview"
        f:Hide()
    end
    f.page = 1; f.fingerprint = self:SaleFingerprint(self:BuildPlan()); f.feedback = nil
    if FS.Layout then FS.Layout:Register("JunkReview",f,"Junk Review") end
    f:Show(); self:RefreshSaleReview()
end
function V:RefreshSaleReview()
    local f = self.saleReview; if not f or not f:IsShown() then return end
    if not self:Settings().enabled or not self.merchantOpen then f:Hide(); return end
    local plan = self:BuildPlan()
    local pages = math.max(1, math.ceil(#plan.sale / 7)); f.page = math.min(f.page, pages)
    f.summary:SetText(plan.units .. " items  |  " .. plan.slots .. " spaces freed\nExpected earnings: " .. self:Money(plan.value))
    for i, row in ipairs(f.rows) do
        local item = plan.sale[(f.page - 1) * 7 + i]
        row.icon:SetTexture(item and item.icon or nil)
        row.text:SetText(item and (item.name .. " x" .. item.sellCount .. "  |  " .. self:Money(item.price * item.sellCount)) or i == 1 and #plan.sale == 0 and "Nothing is ready to sell." or "")
    end
    f.pages:SetText("Page " .. f.page .. " of " .. pages)
    f.previous:SetShown(pages > 1); f.next:SetShown(pages > 1); f.pages:SetShown(pages > 1)
    f.confirm:SetEnabled(plan.units > 0 and self:CanTransact() and not self.busy)
    f.message:SetText(f.feedback or "Protected items and saved quantities stay in your bags.")
end
function V:ConfirmSaleReview()
    local f = self.saleReview
    if not f or not f:IsShown() or self.busy or not self:CanTransact() then return end
    local plan = self:BuildPlan(); local fingerprint = self:SaleFingerprint(plan)
    if fingerprint ~= f.fingerprint then
        f.fingerprint = fingerprint; f.feedback = "Your bags or rules changed. Review the updated list and click Sell again."
        self:RefreshSaleReview(); return
    end
    if plan.units == 0 then return end
    f:Hide(); self:StartSelling(nil, nil, plan.sale)
end
