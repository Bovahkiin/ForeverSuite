local _, FS = ...
local B, V, W = FS.modules.Bags, FS.modules.Vendor, FS.Widgets
local PAGE_SIZE = 132
local categoryNames = { All = "All items", Favorites = "Favorites", Gear = "Equipment", Consumables = "Consumables", Materials = "Crafting", ["Quest Items"] = "Quest items", Junk = "Ready to sell", Other = "Other", Stock = "Shopping list" }
for _, name in ipairs(B.assignable) do if not categoryNames[name] then categoryNames[name] = name end end
categoryNames.Recipes = "Recipes & books"; categoryNames.Enhancements = "Item upgrades"
categoryNames.Professions = "Profession tools"
B.categoryNames = categoryNames
local hints = {
    ["Organize"] = "Show all items in their automatic categories. New items are organized for you.",
    ["Filter items"] = "Show one type of item, such as equipment or crafting materials.",
    ["More options"] = "Change item order, show empty spaces, or view buyback and history.",
    ["Settings"] = "Choose how your bag opens and how junk is highlighted.",
    ["Sell as junk"] = "Allow this item to be sold as junk. Quest items, protected items and saved quantities stay safe.",
    ["Never sell"] = "Protect every copy of this item from ForeverSuite sales.",
    ["Reset item rules"] = "Remove this item's junk rule, Never sell protection and saved quantities.",
    ["Use item"] = "Use or equip this item. You can also right-click it when away from a merchant.",
    ["Sell item"] = "Sell this item without marking it as junk. Never sell protection and saved quantities still apply.",
    ["More item options"] = "Choose a category or set how many copies to keep and buy from merchants.",
    ["Sell junk"] = "Sell all items in Ready to sell. Never sell items and saved quantities stay in your bags.",
    ["Repair gear"] = "Repair damaged equipment using your repair settings and spending limit.",
    ["Buy supplies"] = "Buy missing items from this merchant using your shopping list and budget.",
    ["Save quantities"] = "Always keep reserves copies from sale. Buy up to is your desired total, not an extra amount to buy.",
}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local function skin(frame, r, g, b)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(r or 0.035, g or 0.045, b or 0.065, 0.98)
    frame:SetBackdropBorderColor(0.16, 0.22, 0.29, 1)
end
local function label(parent, text, x, y, width)
    local f = W:Label(parent, "ForeverSuiteFontSmall")
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width or 250); f:SetJustifyH("LEFT"); f:SetText(text)
    return f
end
local function button(parent, text, x, y, width, callback, secure)
    local f = CreateFrame("Button", nil, parent, secure and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate")
    f:SetSize(width, 26); f:SetPoint("TOPLEFT", x, y); skin(f, 0.08, 0.11, 0.15)
    local caption = f:CreateFontString(nil, "OVERLAY", "ForeverSuiteFontSmall")
    caption:SetPoint("CENTER"); f:SetFontString(caption); f:SetText(text); f.caption = caption
    FS:ApplyFont(caption)
    if secure then f:RegisterForClicks("AnyUp", "AnyDown"); f:SetAttribute("useOnKeyDown", false)
    else f:SetScript("OnClick", callback) end
    f.help = hints[text]
    f:SetScript("OnEnter", function(b)
        b:SetBackdropBorderColor(0.2, 0.75, 0.9, 1)
        if b.help then GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:AddLine(b:GetText()); GameTooltip:AddLine(b.help, 1, 1, 1, true); GameTooltip:Show() end
    end)
    f:SetScript("OnLeave", function(b) b:SetBackdropBorderColor(0.16, 0.22, 0.29, 1); if b.help then GameTooltip:Hide() end end)
    return f
end
local function edit(parent, x, y, width)
    local f = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    skin(f, 0.025, 0.03, 0.045); f:SetFontObject("ForeverSuiteFontSmall"); f:SetTextInsets(8, 8, 0, 0)
    FS:ApplyFont(f,12)
    f:SetSize(width, 24); f:SetPoint("TOPLEFT", x, y); f:SetAutoFocus(false)
    f:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    return f
end
function B:CreateWindow()
    if self.window then return self.window end
    local f = CreateFrame("Frame", "ForeverSuiteBagsWindow", UIParent, "SecureHandlerStateTemplate,BackdropTemplate")
    self.window = f
    f:HookScript("OnShow",function(frame) FS:CloseOtherWindows(frame) end)
    f:SetAttribute("_onstate-combat", "if newstate == 'combat' then self:Hide() end")
    if RegisterStateDriver then RegisterStateDriver(f, "combat", "[combat] combat; peace") end
    f:SetSize(FS.db.bags.width, FS.db.bags.height)
    if FS.db.bags.x ~= 0 or FS.db.bags.y ~= 0 then f:SetPoint("CENTER", UIParent, "CENTER", FS.db.bags.x, FS.db.bags.y)
    else f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -30, 90) end
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    skin(f)
    local accent = f:CreateTexture(nil, "ARTWORK"); accent:SetColorTexture(0.12, 0.72, 0.86, 1)
    accent:SetHeight(2); accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local x, y = frame:GetCenter(); local ux, uy = UIParent:GetCenter()
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y and ux and uy then FS.db.bags.x, FS.db.bags.y = x - ux / ratio, y - uy / ratio end
    end)
    f:SetScript("OnHide", function(frame)
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing(); GameTooltip:Hide()
        self.selected = nil; self.itemOptions = false
        frame.itemPanel:Hide(); frame.filterMenu:Hide()
        if frame.options then frame.options:Hide() end
        if frame.tools then frame.tools:Hide() end
    end)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -1, -1)
    local logo = f:CreateTexture(nil, "ARTWORK"); logo:SetTexture(FS.icon)
    logo:SetSize(26, 26); logo:SetPoint("TOPLEFT", 10, -8)
    f.title = label(f, "INVENTORY", 44, -16, 300)
    f.back = button(f, "Control Center", 360, -9, 160, function() FS:ShowConfig() end)
    f.back.help = "Back to Control Center: change module settings or switch modules on and off."
    f.search = edit(f, 12, -43, 270)
    f.search.placeholder = label(f.search, "Search items...", 8, -5, 250)
    f.search.placeholder:SetTextColor(0.55, 0.65, 0.72)
    f.search:SetScript("OnTextChanged", function(box)
        self.search = box:GetText(); box.placeholder:SetShown(self.search == "" and not box:HasFocus())
        self.page = 1; self:Refresh()
    end)
    f.search:SetScript("OnEditFocusGained", function(box) box.placeholder:Hide() end)
    f.search:SetScript("OnEditFocusLost", function(box) box.placeholder:SetShown(box:GetText() == "") end)
    f.search.help = "Find an item by name, type or item ID."
    f.organize = button(f, "Organize", 292, -42, 78, function() self:SortBags() end)
    f.filter = button(f, "Filter", 378, -42, 76, function()
        f.filterMenu:SetShown(not f.filterMenu:IsShown()); if f.options then f.options:Hide() end
    end)
    f.filter.help = hints["Filter items"]
    f.more = button(f, "More options", 462, -42, 86, function()
        if not f.options then self:CreateOptions() end
        f.options:SetShown(not f.options:IsShown()); f.filterMenu:Hide(); self:RefreshOptions()
    end)
    f.filterMenu = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.filterMenu:SetSize(480, 24 + math.ceil(#self.categories / 2) * 34); f.filterMenu:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -12, 8); f.filterMenu:SetClampedToScreen(true)
    f.filterMenu:SetFrameLevel(f:GetFrameLevel() + 30); f.filterMenu:EnableMouse(true); skin(f.filterMenu)
    f.categories = {}
    for i, category in ipairs(self.categories) do
        local name = category
        f.categories[i] = button(f.filterMenu, categoryNames[name], 12 + ((i - 1) % 2) * 234, -12 - math.floor((i - 1) / 2) * 34, 216, function()
            FS.db.bags.category = name; self.page = 1; self.selected = nil; self.itemOptions = false
            f.filterMenu:Hide(); self:Refresh()
        end)
    end
    f.filterMenu:Hide()
    f.categoryHint = label(f, "", 12, -76, 536)
    f.headers = {}
    for i = 1, 48 do
        local header = button(f, "", 12, -100, 536, function(control)
            if not control.category then return end
            self.collapsed = self.collapsed or {}; self.collapsed[control.category] = not self.collapsed[control.category]
            self.selected = nil
            self.page = 1; self:Refresh()
        end)
        header.caption:ClearAllPoints(); header.caption:SetPoint("LEFT", 8, 0); header.caption:SetWidth(516); header.caption:SetJustifyH("LEFT"); header.caption:SetTextColor(0.25, 0.82, 0.94)
        header:SetHeight(20); header.help = "Click to collapse or expand this category."
        f.headers[i] = header
    end
    f.cells = {}
    for i = 1, PAGE_SIZE do
        local cell = CreateFrame("Button", nil, f, "SecureActionButtonTemplate,BackdropTemplate")
        cell:SetAttribute("useOnKeyDown", false)
        cell:SetSize(38, 38)
        skin(cell, 0.025, 0.035, 0.05)
        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        cell:RegisterForClicks("AnyUp", "AnyDown"); cell:RegisterForDrag("LeftButton")
        cell.icon = cell:CreateTexture(nil, "ARTWORK"); cell.icon:SetSize(34, 34); cell.icon:SetPoint("TOPLEFT", 2, -2)
        cell.count = label(cell, "", 0, -24, 36); cell.count:SetJustifyH("RIGHT")
        cell.marker = label(cell, "", 2, -2, 34)
        cell.cooldown = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
        cell.cooldown:SetAllPoints(cell.icon); cell.cooldown:EnableMouse(false); cell.cooldown:Hide()
        cell.newLoot = label(cell, "NEW", 2, -12, 34); cell.newLoot:SetTextColor(0.25, 0.85, 1); cell.newLoot:Hide()
        cell:SetScript("PreClick", function(c) self:BindItemUse(c, c.row, "2") end)
        cell:HookScript("OnClick", function(c, mouse, down)
            if down or InCombatLockdown() then return end
            if not c.row then return end
            if mouse=="LeftButton" and self:TargetBagItem(c.row) then return end
            self.selected = c.row; self.status = nil; self.itemOptions = false
            local rule = c.row.id and V:Settings().rules[c.row.id]
            f.keep:SetText(tostring(rule and rule.keep or 0)); f.target:SetText(tostring(rule and rule.target or 0))
            if CursorHasItem() then self:Action("pickup", c.row)
            elseif mouse == "RightButton" and not c.row.empty and not c.row.stock then
                if MerchantFrame and MerchantFrame:IsShown() then self:Action("sell", c.row)
                else self:EquipBagItem(c.row); self:Refresh() end
            else
                self:Refresh()
            end
        end)
        cell:SetScript("OnDragStart", function(c) if c.row and not c.row.stock then self:Action("pickup", c.row) end end)
        cell:SetScript("OnReceiveDrag", function(c) if c.row and not c.row.stock then self:Action("pickup", c.row) end end)
        cell:SetScript("OnEnter", function(c)
            local row = c.row; if not row then return end
            local wasNew = self:IsNewLoot(row)
            if wasNew then self:ReviewNewItem(row); c.newLoot:Hide() end
            GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
            if row.link then GameTooltip:SetHyperlink(row.link) else GameTooltip:AddLine(row.name) end
            if wasNew then GameTooltip:AddLine("New item", 0.25, 0.85, 1) end
            if row.id and FS.db.bags.favorites[row.id] then GameTooltip:AddLine("Favorite", 0.25, 0.82, 0.94) end
            if row.id and V:Settings().alwaysKeep[row.id] then GameTooltip:AddLine("Always Keep", 0.3, 0.8, 1)
            elseif row.reason then GameTooltip:AddLine(row.reason, 1, 0.85, 0.3) end
            if row.stock then GameTooltip:AddLine("Held " .. row.count .. " | Reserved " .. row.reserve .. " | Missing " .. row.missing) end
            if not row.empty and not row.stock then
                GameTooltip:AddLine("Left-click for item options.", 0.7, 0.85, 1)
                GameTooltip:AddLine(MerchantFrame and MerchantFrame:IsShown() and "Right-click to sell the allowed amount." or "Right-click to use this item.", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.cells[i] = cell
    end
    f.itemPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.itemPanel:SetSize(320, 434); f.itemPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -8, 0)
    f.itemPanel:SetFrameLevel(f:GetFrameLevel() + 20); f.itemPanel:SetClampedToScreen(true); f.itemPanel:EnableMouse(true); skin(f.itemPanel)
    label(f.itemPanel, "ITEM OPTIONS", 12, -14, 200)
    button(f.itemPanel, "Close", 238, -8, 70, function() self.selected = nil; self:Refresh() end)
    f.detail = label(f.itemPanel, "", 12, -44, 295); f.detail:SetHeight(95); f.detail:SetJustifyV("TOP")
    f.basic = {}
    f.basic[1] = button(f.itemPanel, "Sell as junk", 12, -150, 140, function() self:Mark("junk") end)
    f.basic[2] = button(f.itemPanel, "Never sell", 167, -150, 140, function() self:Mark("keep") end)
    f.use = button(f.itemPanel, "Use item", 12, -187, 295, nil, true)
    f.use:SetScript("PreClick", function(control) self:BindItemUse(control, self.selected, "1") end)
    f.use:HookScript("OnClick", function(_, mouse, down)
        if not down and mouse == "LeftButton" then self:EquipBagItem(self.selected) end
    end)
    f.sell = button(f.itemPanel, "Sell item", 12, -187, 295, function() self:Action("sell") end)
    f.itemMore = button(f.itemPanel, "More item options", 12, -224, 295, function() self.itemOptions = not self.itemOptions; self:Refresh() end)
    f.advanced = {}
    f.advanced[1] = button(f.itemPanel, "Reset item rules", 12, -263, 140, function() self:Mark("clear") end)
    f.advanced[2] = button(f.itemPanel, "Move item", 167, -263, 140, function() self:Action("pickup") end)
    f.advanced[3] = label(f.itemPanel, "Always keep", 12, -305, 140)
    f.advanced[4] = label(f.itemPanel, "Buy up to", 167, -305, 140)
    f.keep = edit(f.itemPanel, 17, -325, 130); f.keep:SetText("0")
    f.target = edit(f.itemPanel, 172, -325, 130); f.target:SetText("0")
    f.advanced[5], f.advanced[6] = f.keep, f.target
    f.advanced[7] = button(f.itemPanel, "Save quantities", 12, -362, 295, function() self:SaveStock(f.keep:GetText(), f.target:GetText()) end)
    f.assign = button(f.itemPanel, "", 12, -396, 295, function()
        local choices = { "Automatic" }; for _, name in ipairs(self.assignable) do choices[#choices + 1] = name end
        local id = self.selected and self.selected.id
        local current = id and FS.db.bags.categoryOverrides[id] or "Automatic"
        for i, name in ipairs(choices) do if name == current then self:AssignCategory(choices[i % #choices + 1]); break end end
    end)
    f.assign.help = "Click to choose a category for every copy of this item. Automatic uses the item's type."
    f.advanced[8] = f.assign
    f.favorite = button(f.itemPanel, "", 12, -434, 295, function() self:ToggleFavorite() end)
    f.favorite.help = "Show every copy of this item in Favorites at the top of your inventory."
    f.itemPanel:Hide()
    f.noResults = label(f, "", 12, -120, 536)
    f.merchantButtons = {}
    f.merchantButtons[1] = button(f, "Sell junk", 12, -150, 138, function() self:VendorAction("sell") end)
    f.repair = button(f, "Repair gear", 158, -150, 138, function() self:VendorAction("repair") end)
    f.merchantButtons[2] = f.repair
    f.merchantButtons[3] = button(f, "Buy supplies", 304, -150, 138, function() self:VendorAction("restock") end)
    f.stop = button(f, "Stop", 450, -150, 98, function() V:StopTransactions("Stopped from Bags."); self:Refresh() end)
    f.vendorInfo = label(f, "", 12, -185, 536)
    f.previous = button(f, "Previous", 12, -150, 100, function() self.page = math.max(1, self.page - 1); self:Refresh() end)
    f.pages = label(f, "", 125, -155, 260)
    f.next = button(f, "Next", 448, -150, 100, function() self.page = self.page + 1; self:Refresh() end)
    f.summary = label(f, "", 12, -190, 310)
    f.money = label(f, "", 330, -190, 218); f.money:SetJustifyH("RIGHT")
    f.status = label(f, "", 12, -213, 536); f.status:SetHeight(32)
    UISpecialFrames[#UISpecialFrames + 1] = "ForeverSuiteBagsWindow"
    self:CreateSidebar(f)
    f:Hide(); if FS.Layout then FS.Layout:Register("Bags",f,"Inventory") end; return f
end
function B:Refresh(sharedPlan)
    if InCombatLockdown() then return end
    local f = self.window; if not f or not f:IsShown() then return end
    self:NormalizeSettings()
    local view = self:BuildView(sharedPlan); self.view = view
    local plan = view.plan
    f.noResults:SetShown(#view.rows == 0)
    f.noResults:SetText(self.search ~= "" and "No items found. Try a different name." or FS.db.bags.category == "Stock"
        and "No shopping goals yet. Select an item and open More item options to add one."
        or FS.db.bags.category == "All" and "Your bags are empty." or "No items in this category.")
    local merchant = V.merchantOpen and MerchantFrame and MerchantFrame:IsShown() and V:Settings().enabled
    f.summary:SetText(view.free .. " free bag spaces")
    f.filter:SetText(FS.db.bags.category == "All" and "Filter" or "Filtered")
    f.categoryHint:SetText(FS.db.bags.category == "All" and "Items are grouped automatically." or ("Showing: " .. (categoryNames[FS.db.bags.category] or FS.db.bags.category)))
    for i, c in ipairs(self.categories) do if f.categories[i] then f.categories[i]:SetText(categoryNames[c] or c) end end
    self:RefreshSidebar(view)
    self:RefreshOptions()
    local layouts = self:Layout(view)
    local pages = #layouts; self.page = math.max(1, math.min(self.page, pages))
    local layout = layouts[self.page]
    local width, height = FS.db.bags.width, FS.db.bags.height
    local metrics=self.textLayout or {}
    height=metrics.viewportHeight or height
    f:SetSize(width, height)
    local contentX, contentWidth = metrics.contentX or 212, metrics.contentWidth or width-224
    local contentTop=metrics.contentTop or 100
    local function place(control, x, y) control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y) end
    local footer = height - 42
    place(f.previous, contentX, height - 76); place(f.pages, contentX + 108, height - 71); place(f.next, width - 112, height - 76)
    place(f.summary, 12, footer + 7); f.summary:SetWidth(188)
    place(f.money, width - 246, footer + 7)
    if merchant then
        local vendorY = height - 144
        local buttonWidth = math.floor((contentWidth - 100) / 3) - 8
        for i, control in ipairs(f.merchantButtons) do place(control, contentX + (i - 1) * (buttonWidth + 8), vendorY); control:SetWidth(buttonWidth) end
        place(f.stop, width - 100, vendorY); f.stop:SetWidth(88)
        place(f.vendorInfo, contentX, vendorY + 31); f.vendorInfo:SetWidth(contentWidth)
    end
    place(f.status, contentX, height - 109); f.status:SetWidth(contentWidth); f.status:SetShown(not merchant)
    f:SetScale(math.max(0.5, math.min(FS.db.bags.scale, (UIParent:GetWidth() - 32) / width, (UIParent:GetHeight() - 32) / height)))
    for i, texture in ipairs(f.placeholders) do
        local entry = layout.placeholders[i]
        if entry then texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", contentX + entry.x, -contentTop - entry.y); texture:Show() else texture:Hide() end
    end
    f.money:SetText(V:Money(GetMoney()))
    for i, header in ipairs(f.headers) do
        local entry = layout.headers[i]
        if entry then header:ClearAllPoints(); header:SetPoint("TOPLEFT", contentX, -contentTop - entry.y); header:SetWidth(contentWidth); header:SetHeight((metrics.headerHeight or 26)-6); header.caption:SetWidth(contentWidth - 20); header.category = entry.category; header:SetText(entry.text); header:Show()
        else header:Hide() end
    end
    f.noResults:ClearAllPoints(); f.noResults:SetPoint("TOPLEFT", contentX, -contentTop-30); f.noResults:SetWidth(contentWidth)
    if FS.db.bags.viewMode == "recent" and FS.db.bags.category == "All" then
        f.noResults:SetShown(#self:RecentRows(view) == 0); f.noResults:SetText("Newly received items appear here for 10 minutes.")
    end
    f.pages:SetText("Page " .. self.page .. " of " .. pages)
    f.pages:SetShown(pages > 1); f.previous:SetShown(pages > 1); f.next:SetShown(pages > 1)
    if metrics.large then
        local H=FS.HUD; local size=metrics.fontSize; local navWidth=math.max(100,size*5+20)
        for _,b in ipairs({f.previous,f.next}) do b:SetWidth(navWidth); H:TextHeight(b.caption,navWidth-16,1); b:SetHeight(size+16) end
        local navY=height-size*2-38
        place(f.previous,contentX,navY); place(f.next,width-navWidth-12,navY)
        place(f.pages,contentX+navWidth+10,navY+4); H:TextHeight(f.pages,math.max(40,contentWidth-2*navWidth-20),2)
        place(f.summary,12,height-size-16); H:TextHeight(f.summary,width*.5-24,1)
        place(f.money,width*.5,height-size-16); H:TextHeight(f.money,width*.5-24,1)
        place(f.status,contentX,navY-size-14); H:TextHeight(f.status,contentWidth,1)
    else f.previous:SetHeight(26); f.next:SetHeight(26) end
    for i, cell in ipairs(f.cells) do
        local entry = layout.cells[i]; local row = entry and entry.row; cell.row = row
        self:BindItemUse(cell, row, "2"); self:UpdateCellExtras(cell, row)
        if entry then cell:ClearAllPoints(); cell:SetPoint("TOPLEFT", contentX + entry.x, -contentTop - entry.y) end
        if row then
            local selected = self.selected and ((row.stock and self.selected.stock and row.id == self.selected.id)
                or (row.bag and row.bag == self.selected.bag and row.slot == self.selected.slot))
            cell:SetBackdropBorderColor(selected and 0.2 or 0.35, selected and 0.8 or 0.35, selected and 1 or 0.35)
            cell.icon:SetTexture(row.icon or (row.stock and 134400 or nil)); cell.count:SetText(row.count and row.count > 1 and row.count or "")
            local keep = row.id and V:Settings().alwaysKeep[row.id]
            cell.marker:SetText(row.empty and "" or row.stock and ("+" .. row.missing) or keep and "K" or (row.sellCount or 0) > 0 and "$" or "")
            V:ApplyGlow(cell, row.stock and nil or row.empty and nil or row)
            cell:Show()
        else V:ApplyGlow(cell, nil); cell:Hide() end
    end
    f.repair:SetText(V.repairConfirmation and "Confirm Repair" or "Repair gear")
    local restock = V:RestockPlan()
    local quote = V:RepairQuote()
    f.vendorInfo:SetText(merchant and (V.status or self.status or ("Junk worth " .. V:Money(plan.value) .. " | Review before selling.")) or "")
    f.vendorInfo:SetShown(merchant)
    for _, control in ipairs(f.merchantButtons) do control:SetShown(merchant) end
    f.stop:SetShown(merchant and V.busy)
    f.merchantButtons[1]:SetEnabled(plan.units > 0 and not V.busy)
    f.repair:SetEnabled(quote ~= nil and not V.busy)
    f.merchantButtons[3]:SetEnabled(#restock.items > 0 and not V.busy)
    self:RefreshSettings()
    self:RefreshTools()
    local s = self.selected
    local current = self:CurrentItem()
    if s and not s.empty and not s.stock and not current then self.selected = nil; s = nil end
    local selected = s and s.id ~= nil
    self:BindItemUse(f.use, s, "1")
    f.favorite:SetShown(selected)
    f.favorite:SetText(selected and FS.db.bags.favorites[s.id] and "Remove favorite" or "Add to Favorites")
    f.favorite:ClearAllPoints(); f.favorite:SetPoint("TOPLEFT", 12, selected and (self.itemOptions or s.stock) and -434 or -264)
    f.itemPanel:SetShown(selected)
    f.itemPanel:SetHeight(selected and (self.itemOptions or s.stock) and 470 or 302)
    for _, control in ipairs(f.basic) do control:SetShown(selected and not s.stock) end
    f.use:SetShown(selected and not s.stock and not merchant)
    f.sell:SetShown(selected and not s.stock and merchant)
    f.itemMore:SetShown(selected)
    local advanced = selected and (self.itemOptions or s.stock)
    for _, control in ipairs(f.advanced) do control:SetShown(advanced) end
    local assigned = s and s.id and FS.db.bags.categoryOverrides[s.id] or "Automatic"
    f.assign:SetText("Category: " .. (categoryNames[assigned] or assigned))
    if selected then
        local rule = V:Settings().rules[s.id]
        local held = plan.totals[s.id] or 0
        local planned = current and plan.bySlot[current.bag .. ":" .. current.slot]
        local state = "Not marked for sale."
        if V:Settings().alwaysKeep[s.id] then state = "Never sold by ForeverSuite."
        elseif planned and planned.protection then state = "Protected: " .. planned.protection
        elseif planned and planned.sellCount > 0 then state = "Can sell " .. planned.sellCount .. " from this stack."
        elseif planned and planned.junk then state = "Kept for your saved quantity." end
        if merchant and current and not (planned and planned.protection) then
            local eligible=V:AvailableSale(current,true)
            if eligible then state="Sell item: "..eligible.sellCount.." from this stack. No junk marking needed." end
        end
        f.detail:SetText(s.name .. "\nYou have " .. held .. " in your bags.\n\n" .. (s.stock and ("Buy " .. math.max(0, (rule and rule.target or 0) - held) .. " more to reach your shopping goal.") or self.status or (V.busy and V.status) or state))
    else f.detail:SetText("Click an item to see what you can do.\n\nDrag items to move them.") end
    f.status:SetText(self.status or (InCombatLockdown() and "You can browse your bags during combat. Item actions are paused." or ""))

end

function B:VendorAction(action)
    self.status = nil
    if not self:Guard() or not V:CanTransact() then
        self.status = self.status or "Visit a merchant with an empty cursor first."; self:Refresh(); return
    end
    self.status = nil
    if action == "sell" then V:ReviewSales()
    elseif action == "restock" then V:StartRestock()
    elseif action == "repair" then V:TryRepair(V.repairConfirmation ~= nil) end
    self:Refresh()
end

function B:CreateSettings(host)
    host = host or self.window
    local f = CreateFrame("Frame", nil, host, "BackdropTemplate")
    host.settings = f; f.module = "Bags"; f.advanced = false
    f:SetSize(892, 420); f:SetPoint("TOPLEFT", 24, FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel() + 30)
    f:EnableMouse(true); skin(f)
    f.title = label(f, "", 260, -20, 490)
    f.back = button(f, host == FS.window and "Back to Control Center" or "Back to bags", 20, -12, 220, function() f:Hide() end)
    f.description = label(f, "", 20, -55, 850)
    f.highlightHeading = label(f, "Junk highlights", 20, -75, 850)
    f.openingHeading = label(f, "Bag opening and display", 20, -210, 850)
    f.mode = button(f, "", 20, -105, 400, function()
        V:SetMode(({ manual = "auto", auto = "custom", custom = "manual" })[V:Settings().mode])
    end)
    f.mode.help = "Manual: click Sell junk yourself. Auto gray junk: sell eligible gray items at merchants. Custom junk: also use your own junk rules."
    f.modeHint = label(f, "Choose how junk is sold. Hover for an explanation of each mode.", 450, -112, 420)
    f.source = button(f, "", 310, -55, 270, function()
        V:Settings().repairSource = ({ personal = "guild", guild = "guildFirst", guildFirst = "personal" })[V:Settings().repairSource]; V:SettingsChanged()
    end)
    f.source.help = "Choose personal money, guild money only, or guild money with a personal fallback."
    f.color = button(f, "", 600, -55, 270, function()
        V:Settings().glow.color = ({ green = "gold", gold = "cyan", cyan = "green" })[V:Settings().glow.color]; V:SettingsChanged()
    end)
    f.toggles = {}
    local choices = {
        { "includeGray", "Sell gray junk", "Gray-quality items are marked as junk when they are safe to sell." },
        { "protectRare", "Protect valuable gear", "Rare and higher-quality items cannot be sold as junk." },
        { "autoRepair", "Repair automatically", "Repair at merchants within your chosen spending limit." },
        { "autoRestock", "Buy supplies automatically", "Buy missing shopping-list items within your budget." },
        { "confirmRepair", "Confirm expensive repairs", "Ask before repairs that exceed your repair limit." },
        { "report", "Show sale reports", "Show a short report after each merchant visit." },
        { "showPanel", "Show Vendor window", "Open Vendor if the Bags window is not set to open." },
        { "glow.enabled", "Highlight junk", "Items that can be sold get a colored border." },
        { "glow.pulse", "Animate the highlight", "Make the junk border pulse gently." },
        { "bags.openAtMerchant", "Open bags at merchants", "Your bag opens when you speak to a merchant." },
        { "bags.replaceNative", "Use ForeverSuite bags", "Your usual bag key opens the skinned bag with automatic categories." },
        { "bags.showCooldowns", "Show item cooldowns", "Show remaining cooldowns on Hearthstone, potions and other usable items." },
        { "bags.showNewLoot", "Mark new loot", "New items show NEW until you hover over them. Moving an item does not make it new." },
        { "bags.showEmpty", "Show empty spaces", "Show unused bag spaces so you can drop items into them." },
    }
    for _, choice in ipairs(choices) do
        local key, title = choice[1], choice[2]
        local control = button(f, "", 20, -100, 400, function()
            local db, field = V:Settings(), key
            if string.sub(key, 1, 5) == "glow." then db, field = db.glow, string.sub(key, 6)
            elseif string.sub(key, 1, 5) == "bags." then db, field = FS.db.bags, string.sub(key, 6) end
            db[field] = not db[field]; V:SettingsChanged()
        end)
        control.help = choice[3]
        local explanation = label(f, choice[3], 20, -135, 400); explanation:SetHeight(28)
        f.toggles[#f.toggles + 1] = { control = control, key = key, text = title, explanation = explanation }
    end
    f.fields, f.fieldLabels = {}, {}
    for i, data in ipairs({ { "repairLimit", "Repair limit in gold (0 = no limit)" }, { "restockBudget", "Shopping budget in gold" }, { "moneyReserve", "Gold to keep in your pocket" } }) do
        local x = 20 + (i - 1) * 290
        f.fieldLabels[data[1]] = label(f, data[2], x, -255, 270)
        f.fields[data[1]] = edit(f, x, -278, 270)
    end
    f.intensityLabel = label(f, "Highlight brightness (0.1 - 1)", 20, -255, 270)
    f.intensity = edit(f, 20, -278, 270)
    f.save = button(f, "Save advanced settings", 310, -335, 560, function()
        local values = {}
        if f.module == "Vendor" then
            for key, box in pairs(f.fields) do
                local amount = V:ValidNumber(tonumber(box:GetText()), 0, 1000000)
                if not amount then f.feedback:SetText("Enter a gold amount from 0 to 1000000."); return end
                values[key] = math.floor(amount * 10000 + 0.5)
            end
        end
        local intensity = f.module == "Bags" and V:ValidNumber(tonumber(f.intensity:GetText()), 0.1, 1) or V:Settings().glow.intensity
        if not intensity then f.feedback:SetText("Brightness must be between 0.1 and 1."); return end
        for key, amount in pairs(values) do V:Settings()[key] = amount end
        V:Settings().glow.intensity = intensity; V:SettingsChanged()
        f.feedback:SetText("Settings saved.")
    end)
    f.more = button(f, "Advanced settings", 20, -335, 270, function()
        f.advanced = not f.advanced; self:RefreshSettings(false, f)
    end)
    f.feedback = label(f, "", 20, -391, 850)
    f:Hide(); self:RefreshSettings(true, f); return f
end

function B:RefreshSettings(force, panel)
    local f = panel or (self.window and self.window.settings)
    if not f or (not force and not f:IsShown()) then return end
    local db, advanced, vendor = V:Settings(), f.advanced, f.module == "Vendor"
    f:SetBackdropBorderColor(vendor and 0.75 or 0.12, vendor and 0.53 or 0.72, vendor and 0.2 or 0.86, 1)
    f.title:SetText(vendor and "Vendor settings" or "Bag settings")
    f.description:SetText(advanced and "Advanced options. Hover over a button for help." or vendor
        and "Choose what you sell and whether to repair or buy supplies automatically."
        or "Your items organize automatically. Choose how your bag looks and opens.")
    f.description:SetShown(not advanced)
    f.mode:SetText("Junk selling: " .. ({ manual = "Manual", auto = "Auto gray junk", custom = "Custom junk" })[db.mode])
    f.mode:SetShown(vendor); f.mode:ClearAllPoints(); f.mode:SetPoint("TOPLEFT", 20, advanced and -55 or -105); f.mode:SetWidth(advanced and 270 or 400)
    f.modeHint:SetShown(vendor and not advanced)
    f.source:SetText("Repair money: " .. ({ personal = "Personal", guild = "Guild only", guildFirst = "Guild first" })[db.repairSource]); f.source:SetShown(vendor and advanced)
    f.color:SetText("Highlight color: " .. db.glow.color); f.color:SetShown(not vendor and advanced)
    f.highlightHeading:SetShown(advanced and not vendor)
    f.openingHeading:SetShown(advanced and not vendor)
    if advanced and not vendor then
        f.color:ClearAllPoints(); f.color:SetPoint("TOPLEFT", 20, -136)
        f.intensityLabel:ClearAllPoints(); f.intensityLabel:SetPoint("TOPLEFT", 310, -140)
        f.intensity:ClearAllPoints(); f.intensity:SetPoint("TOPLEFT", 310, -166)
    end
    local basic = vendor and { includeGray = true, protectRare = true, autoRepair = true, autoRestock = true }
        or { ["bags.openAtMerchant"] = true, ["bags.replaceNative"] = true, ["bags.showEmpty"] = true, ["glow.enabled"] = true }
    local index = 0
    for _, entry in ipairs(f.toggles) do
        local value = db[entry.key]
        local bagOption = string.sub(entry.key, 1, 5) == "bags." or string.sub(entry.key, 1, 5) == "glow."
        if string.sub(entry.key, 1, 5) == "glow." then value = db.glow[string.sub(entry.key, 6)]
        elseif string.sub(entry.key, 1, 5) == "bags." then value = FS.db.bags[string.sub(entry.key, 6)] end
        local show = advanced and (vendor ~= bagOption) or not advanced and basic[entry.key]
        entry.control:SetShown(show); entry.explanation:SetShown(show and not advanced)
        entry.control:SetText(entry.text .. ": " .. (value and "On" or "Off"))
        if show then
            index = index + 1
            local x = advanced and (20 + ((index - 1) % 3) * 290) or (20 + ((index - 1) % 2) * 430)
            local y = advanced and (-100 - math.floor((index - 1) / 3) * 36) or ((vendor and -155 or -105) - math.floor((index - 1) / 2) * 76)
            if advanced and not vendor then
                local positions = {
                    ["glow.enabled"] = {20, -100}, ["glow.pulse"] = {310, -100},
                    ["bags.openAtMerchant"] = {20, -236}, ["bags.replaceNative"] = {310, -236},
                    ["bags.showEmpty"] = {600, -236},
                    ["bags.showCooldowns"] = {20, -272}, ["bags.showNewLoot"] = {310, -272},
                }
                local position = positions[entry.key]
                if position then x, y = position[1], position[2] end
            end
            entry.control:ClearAllPoints(); entry.control:SetPoint("TOPLEFT", x, y); entry.control:SetWidth(advanced and 270 or 400)
            entry.explanation:ClearAllPoints(); entry.explanation:SetPoint("TOPLEFT", x, y - 35)
        end
    end
    for key, box in pairs(f.fields) do box:SetShown(advanced and vendor); f.fieldLabels[key]:SetShown(advanced and vendor) end
    f.intensity:SetShown(advanced and not vendor); f.intensityLabel:SetShown(advanced and not vendor)
    f.save:SetShown(advanced)
    f.more:SetText(advanced and "Back to simple settings" or "Advanced settings")
    if force then
        for key, box in pairs(f.fields) do box:SetText(tostring(db[key] / 10000)) end
        f.intensity:SetText(tostring(db.glow.intensity)); f.feedback:SetText("Changes are saved automatically. Advanced text fields use the Save button.")
    end
    if f.fsSettingsBound then FS:ThemeSettings(f,f.fsSettingsName) end
end

function B:ShowTools()
    local f = self.window.tools
    if not f then
        f = CreateFrame("Frame", nil, self.window, "BackdropTemplate")
        self.window.tools = f
        f:SetSize(536, 420); f:SetPoint("BOTTOMLEFT", self.window, "BOTTOMLEFT", 12, 34); f:SetClampedToScreen(true); f:SetFrameLevel(self.window:GetFrameLevel() + 30)
        f:EnableMouse(true); skin(f); f.tab = "Buyback"; f.page = 1
        label(f, "INVENTORY TOOLS", 12, -20, 320)
        button(f, "Back to bags", 374, -12, 150, function() f:Hide() end)
        button(f, "Buyback", 20, -50, 150, function() f.tab = "Buyback"; f.page = 1; self:RefreshTools() end)
        button(f, "History", 180, -50, 150, function() f.tab = "History"; f.page = 1; self:RefreshTools() end)
        f.rows = {}
        for i = 1, 7 do
            local row = { text = label(f, "", 12, -88 - (i - 1) * 41, 362) }
            row.text:SetHeight(38); row.text:SetJustifyV("TOP")
            row.buy = button(f, "Buy Back", 384, -88 - (i - 1) * 41, 140, function()
                if row.item and self:Guard() and V:CanTransact() then self.status = nil; V:BuyBack(row.item)
                else self.status = "Visit a merchant to buy this item back."; self:Refresh() end
            end)
            f.rows[i] = row
        end
        button(f, "Previous", 20, -377, 150, function() f.page = math.max(1, f.page - 1); self:RefreshTools() end)
        f.pages = label(f, "", 184, -385, 185)
        button(f, "Next", 374, -377, 150, function() f.page = f.page + 1; self:RefreshTools() end)
    end
    if self.window.settings then self.window.settings:Hide() end
    f:Show(); self:RefreshTools()
end
function B:RefreshTools()
    local f = self.window and self.window.tools
    if not f or not f:IsShown() then return end
    local entries = f.tab == "Buyback" and V:BuybackList() or V:Settings().history
    local pages = math.max(1, math.ceil(#entries / 7)); f.page = math.min(f.page, pages)
    f.pages:SetText(f.tab .. " | Page " .. f.page .. " / " .. pages)
    for i, row in ipairs(f.rows) do
        local entry = entries[(f.page - 1) * 7 + i]; row.item = nil
        row.buy:Hide()
        if entry then
            if f.tab == "Buyback" then
                row.text:SetText(entry.name .. " x" .. entry.count .. " | " .. V:Money(entry.price))
                row.item = entry; row.buy:Show()
            else row.text:SetText(entry.date .. " | " .. entry.text) end
            row.text:Show()
        elseif i == 1 and #entries == 0 then
            row.text:SetText(f.tab == "Buyback" and "No buyback items available. Visit a merchant after a sale." or "No completed visits yet."); row.text:Show()
        else row.text:Hide() end
    end
end

function B:CreateOptions()
    local f = self.window
    local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.options = panel
    panel:SetSize(380, 334); panel:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -12, 8); panel:SetClampedToScreen(true)
    panel:SetFrameLevel(f:GetFrameLevel() + 30); panel:EnableMouse(true); skin(panel)
    label(panel, "More bag options", 20, -18, 340)
    f.sort = button(panel, "", 20, -50, 340, function()
        for i, value in ipairs(self.sorts) do if value == FS.db.bags.sort then FS.db.bags.sort = self.sorts[i % #self.sorts + 1]; break end end
        self.page = 1; self:Refresh()
    end)
    f.sort.help = "Click to change the order inside each category. Items always stay grouped by type."
    f.empty = button(panel, "", 20, -88, 340, function()
        FS.db.bags.showEmpty = not FS.db.bags.showEmpty; self.page = 1; self:Refresh()
    end)
    f.empty.help = "Show empty spaces if you want to drag items to a specific place. Free space is always counted at the top."
    button(panel, "Shopping list", 20, -126, 340, function()
        FS.db.bags.category = "Stock"; self.page = 1; self.selected = nil; panel:Hide(); self:Refresh()
    end).help = "See saved supply goals and how many items you still need to buy."
    button(panel, "Buyback & history", 20, -164, 340, function() panel:Hide(); self:ShowTools() end).help = "Buy back an item at a merchant or read your completed merchant visits."
    button(panel, "Settings", 20, -202, 340, function() FS:ConfigureModule("Bags") end)
    f.size = button(panel, "", 20, -240, 340, function()
        local sizes = { 0.7, 0.85, 1, 1.15 }
        local current = FS.db.bags.scale
        local nextSize = sizes[1]
        for _, value in ipairs(sizes) do if value > current + 0.001 then nextSize = value; break end end
        FS.db.bags.scale = nextSize; self:Refresh()
    end)
    f.size.help = "Click to choose 70%, 85%, 100% or 115%. The size is saved after reload."
    button(panel, "Reset position", 20, -278, 340, function()
        FS.db.bags.x, FS.db.bags.y = 0, 0
        f:ClearAllPoints(); f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -30, 90)
    end).help = "Return your inventory to the bottom-right corner. Drag its title bar to move it."
    panel:Hide(); self:RefreshOptions()
end
function B:RefreshOptions()
    local f = self.window
    if not f or not f.options then return end
    local names = { category = "Automatic", name = "Name", value = "Vendor value", bag = "Bag position" }
    f.sort:SetText("Item order: " .. names[FS.db.bags.sort])
    f.size:SetText("Inventory size: " .. math.floor(FS.db.bags.scale * 100 + 0.5) .. "%")
    f.empty:SetText(FS.db.bags.showEmpty and "Hide empty spaces" or "Show empty spaces")
end
