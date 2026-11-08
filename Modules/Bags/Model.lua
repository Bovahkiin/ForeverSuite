local _, FS = ...
local B, V = FS.modules.Bags, FS.modules.Vendor
function B:Category(item)
    if FS.db.bags.favorites[item.id] then return "Favorites" end
    if item.quest then return "Quest Items" end
    if (item.sellCount or 0) > 0 then return "Junk" end
    local override = FS.db.bags.categoryOverrides[item.id]
    if override then return override end
    local classes = { [0] = "Consumables", [1] = "Bags", [2] = "Gear", [3] = "Gems",
        [4] = "Gear", [5] = "Materials", [6] = "Ammo", [7] = "Materials",
        [8] = "Enhancements", [9] = "Recipes", [10] = "Currency", [11] = "Bags",
        [12] = "Quest Items", [13] = "Keys", [14] = "Other", [15] = "Other",
        [16] = "Glyphs", [17] = "Pets", [18] = "Currency", [19] = "Professions", [20] = "Housing" }
    if item.classID == 15 then
        local misc = { [1] = "Materials", [2] = "Pets", [3] = "Holiday", [5] = "Mounts", [6] = "Enhancements" }
        return misc[item.subclassID] or "Other"
    end
    if item.classID == 0 and (item.subclassID == 6 or item.subclassID == 15) then return "Enhancements" end
    return classes[item.classID] or "Other"
end
function B:Matches(item)
    local category = FS.db.bags.category
    if category ~= "All" and category ~= self:Category(item) then return false end
    local text = string.lower(item.name .. " " .. item.id .. " " .. (item.itemType or "") .. " " .. (item.subType or ""))
    return string.find(text, string.lower(self.search or ""), 1, true) ~= nil
end
function B:BuildView(sharedPlan)
    local plan = sharedPlan or V:BuildPlan()
    local view = { plan = plan, rows = {}, free = 0, capacity = 0, unknown = 0 }
    for bag = 0, V:BagLimit() do
        local size = C_Container.GetContainerNumSlots(bag)
        view.capacity = view.capacity + size
        for slot = 1, size do
            local key = bag .. ":" .. slot
            if not plan.bySlot[key] then
                local raw = C_Container.GetContainerItemInfo(bag, slot)
                if raw then view.unknown = view.unknown + 1
                else
                    view.free = view.free + 1
                    if FS.db.bags.showEmpty and FS.db.bags.category == "All" and self.search == "" then
                        view.rows[#view.rows + 1] = { bag = bag, slot = slot, empty = true, name = "Empty slot" }
                    end
                end
            end
        end
    end
    if FS.db.bags.category == "Stock" then
        for id, rule in pairs(V:Settings().rules) do
            local held = plan.totals[id] or 0
            if rule.keep > 0 or rule.target > 0 then
                local name = V:ItemName(id)
                if string.find(string.lower(name .. " " .. id), string.lower(self.search), 1, true) then
                    view.rows[#view.rows + 1] = { id = id, name = name, stock = true, count = held,
                        reserve = math.max(rule.keep, rule.target), target = rule.target, missing = math.max(0, rule.target - held) }
                end
            end
        end
    else
        for _, item in ipairs(plan.items) do
            if self:Matches(item) then view.rows[#view.rows + 1] = item end
        end
    end
    local sort = FS.db.bags.sort
    table.sort(view.rows, function(a, b)
        if a.empty ~= b.empty then return not a.empty end
        if not a.empty and not a.stock and self:Category(a) ~= self:Category(b) then
            local order = {}; for i, name in ipairs(self.categories) do order[name] = i end
            return order[self:Category(a)] < order[self:Category(b)]
        end
        if sort == "value" and (a.price or 0) * (a.count or 0) ~= (b.price or 0) * (b.count or 0) then
            return (a.price or 0) * (a.count or 0) > (b.price or 0) * (b.count or 0)
        end
        if sort ~= "bag" and a.name ~= b.name then return string.lower(a.name) < string.lower(b.name) end
        if a.stock then return a.id < b.id end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return view
end
function B:CurrentItem()
    local selected = self.selected
    if not selected or selected.empty or selected.stock then return nil end
    local item = V:ReadItem(selected.bag, selected.slot)
    if not item or item.id ~= selected.id or item.link ~= selected.link or (selected.guid and item.guid ~= selected.guid) then return nil end
    return item
end
function B:Guard()
    if InCombatLockdown() then self.status = "Item actions are unavailable in combat."; return false end
    if V.busy or V.pending then self.status = "Wait for the vendor transaction to finish."; return false end
    if InRepairMode() or (SpellIsTargeting and SpellIsTargeting()) then self.status = "Finish the current targeting action first."; return false end
    return true
end
function B:ItemForUse(row)
    if InCombatLockdown() then return end
    if not row or row.empty or row.stock or CursorHasItem() or V.busy or V.pending
        or InRepairMode() or SpellIsTargeting() or (MerchantFrame and MerchantFrame:IsShown()) then return end
    local current = V:ReadItem(row.bag, row.slot)
    if not current or current.locked or current.id ~= row.id or current.link ~= row.link
        or (row.guid and row.guid ~= current.guid) then return end
    return current
end
function B:IsEquipment(item)
    local isEquippable = C_Item and C_Item.IsEquippableItem or IsEquippableItem
    return item and isEquippable and isEquippable(item.link)
end
function B:EquipBagItem(row)
    local current = self:ItemForUse(row)
    if not self:IsEquipment(current) then return end
    -- Use the exact container slot so the client owns equipping and bind prompts.
    -- Never confirm binding or pick a different copy by item name.
    C_Container.UseContainerItem(current.bag, current.slot)
end
function B:BindItemUse(control, row, suffix)
    if InCombatLockdown() then return end
    control:SetAttribute("type" .. suffix, nil); control:SetAttribute("item" .. suffix, nil)
    local current = self:ItemForUse(row)
    if not current or self:IsEquipment(current) then return end
    control:SetAttribute("item" .. suffix, current.bag .. " " .. current.slot)
    control:SetAttribute("type" .. suffix, "item")
end
function B:Action(action, row)
    if not self:Guard() then self:Refresh(); return end
    self.selected = row or self.selected
    local item = self:CurrentItem()
    if action == "pickup" and self.selected and self.selected.empty then
        local s = self.selected
        if CursorHasItem() and not C_Container.GetContainerItemInfo(s.bag, s.slot) then C_Container.PickupContainerItem(s.bag, s.slot) end
    elseif item and not item.locked then
        if action == "pickup" then C_Container.PickupContainerItem(item.bag, item.slot)
        elseif action == "use" and not CursorHasItem() then
            if MerchantFrame and MerchantFrame:IsShown() then
                self.status = "Use Sell Selected at a vendor to preserve your rules."
            else self.status = "Use the item button or right-click the item to use it." end
        elseif action == "sell" then
            local eligible,reason = V:AvailableSale(item,true)
            if eligible and V:CanTransact() then self.status=nil; V:StartSelling(eligible)
            else self.status = reason or "Visit a merchant with an empty cursor to sell this item." end
        end
    else self.status = "The item moved, is locked, or its data is unavailable. Select it again." end
    V:QueueRefresh(); self:Refresh()
end
function B:Mark(kind)
    local item = self:CurrentItem()
    local id = item and item.id or (self.selected and self.selected.stock and self.selected.id)
    if not id then self.status = "Select a current item first."; self:Refresh(); return end
    local db, rule = V:Settings(), V:Settings().rules[id]
    if kind == "keep" then V:KeepItem(id)
    elseif kind == "junk" then
        db.alwaysKeep[id] = nil
        V:SetRule(id, true, rule and rule.keep or 0, rule and rule.target or 0)
        self.status = db.mode == "auto" and "Custom junk saved. Select Manual or Custom Rules in Vendor to apply it." or "Junk rule saved; protections and stock reserves still apply."
    elseif kind == "clear" then db.alwaysKeep[id] = nil; db.rules[id] = nil; V:SettingsChanged() end
    self:Refresh()
end
function B:SaveStock(keep, target)
    local s = self.selected
    local item = self:CurrentItem()
    local id = item and item.id or (s and s.stock and s.id)
    keep, target = tonumber(keep), tonumber(target)
    if not id or not V:ValidNumber(keep, 0, 100000) or not V:ValidNumber(target, 0, 100000) then
        self.status = "Select an item and enter quantities from 0 to 100000."
    else
        local rule = V:Settings().rules[id]
        V:SetRule(id, rule and rule.junk or false, math.floor(keep), math.floor(target))
        self.status = "Stock rule saved. Target also reserves items from sale."
    end
    self:Refresh()
end
function B:SortBags()
    -- Organize the displayed inventory ourselves. Native SortBags cannot define
    -- our categories, and physical slot changes were hidden by the old view sort.
    FS.db.bags.sort = "category"
    FS.db.bags.category = "All"
    FS.db.bags.viewMode = "categories"
    self.search, self.page = "", 1
    if self.window then self.window.search:SetText("") end
    self.status = "Organized into categories. New items sort automatically."
    self:Refresh()
end

function B:ToggleFavorite()
    if InCombatLockdown() then return end
    local item = self:CurrentItem()
    local id = item and item.id or (self.selected and self.selected.stock and self.selected.id)
    if not id then return end
    FS.db.bags.favorites[id] = not FS.db.bags.favorites[id]
    self.page = 1; self:Refresh()
end

function B:AssignCategory(name)
    local item = self:CurrentItem()
    local id = item and item.id or (self.selected and self.selected.stock and self.selected.id)
    if not id then self.status = "Select an item first."; self:Refresh(); return end
    local allowed = name == "Automatic"
    for _, category in ipairs(self.assignable) do
        if name == category then allowed = true end
    end
    if not allowed then return end
    FS.db.bags.categoryOverrides[id] = name ~= "Automatic" and name or nil
    self.status = "Category saved for every copy of this item. Quest and junk rules take priority."
    self:Refresh()
end

function B:RecentRows(view)
    local rows = {}
    for _, row in ipairs(view.rows) do
        if not row.empty and not row.stock and self.recentItems and self.recentItems[row.id]
            and GetTime() - self.recentItems[row.id] < 600 then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b)
        local at, bt = self.recentItems[a.id], self.recentItems[b.id]
        if at ~= bt then return at > bt end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return rows
end
function B:Layout(view)
    local db = FS.db.bags
    local width = db.width or 820
    local metrics=self.textLayout or {}
    if metrics.width~=width or metrics.height~=db.height then metrics={} end
    local columns = math.max(1, math.floor((metrics.contentWidth or (width - 224)) / 44))
    local headerHeight=metrics.headerHeight or 26
    local merchant = V.merchantOpen and MerchantFrame and MerchantFrame:IsShown() and V:Settings().enabled
    local limit = math.max(headerHeight+38, (metrics.viewportHeight or db.height or 500) - (metrics.contentTop or 100) - (metrics.footerReserve or 120) - (merchant and 40 or 0))
    local pages = { { cells = {}, headers = {}, placeholders = {}, height = 0 } }
    local page, y = pages[1], 0
    local groups, order = {}, {}
    local function add(name, row)
        if not groups[name] then groups[name] = {}; order[#order + 1] = name end
        if row then groups[name][#groups[name] + 1] = row end
    end
    local mode = db.category == "All" and db.viewMode or "categories"
    local recent = self:RecentRows(view)
    if mode == "recent" then
        add("Recent")
        for _, row in ipairs(recent) do add("Recent", row) end
    else
        if mode == "categories" and db.category == "All" and db.showRecent and #recent > 0 then
            add("Recent")
            for i = 1, math.min(columns, #recent) do add("Recent", recent[i]) end
        end
        if mode == "categories" and (db.category == "All" or db.category == "Favorites") then add("Favorites") end
        for _, row in ipairs(view.rows) do
            local name = row.empty and "Free Slots" or row.stock and "Stock" or self:Category(row)
            if mode == "onebag" then name = "OneBag"
            elseif mode == "multibag" then name = "Bag " .. tostring(row.bag or 0) end
            add(name, row)
        end
    end
    if mode == "multibag" then table.sort(order, function(a, b) return tonumber(a:match("%d+")) < tonumber(b:match("%d+")) end) end
    local function nextPage()
        page = { cells = {}, headers = {}, placeholders = {}, height = 0 }
        pages[#pages + 1] = page; y = 0
    end
    for _, name in ipairs(order) do
        local rows = groups[name]
        local collapsed = self.collapsed and self.collapsed[name]
        local title = name == "Recent" and "Recent items - quick view" or name == "OneBag" and "All items"
            or name == "Free Slots" and "Empty spaces" or (self.categoryNames and self.categoryNames[name]) or name
        local function header()
            page.headers[#page.headers + 1] = { text = (collapsed and "+ " or "- ") .. title .. " (" .. #rows .. ")", category = name, y = y }
            y = y + headerHeight; page.height = math.max(page.height, y)
        end
        if y + (collapsed and headerHeight or headerHeight+38) > limit then nextPage() end
        header()
        if not collapsed then
            local col = 0
            for _, row in ipairs(rows) do
                if col == columns then y = y + 44; col = 0 end
                if y + 38 > limit or #page.cells >= 132 then nextPage(); header(); col = 0 end
                page.cells[#page.cells + 1] = { row = row, x = col * 44, y = y, recent = name == "Recent" }
                col = col + 1; page.height = math.max(page.height, y + 38)
            end
            -- Decorative spaces complete the row; these never represent real bag slots.
            if #rows > 0 then
                for i = col, columns - 1 do page.placeholders[#page.placeholders + 1] = { x = i * 44, y = y } end
                y = y + 50
            else y = y + 8 end
        else y = y + 8 end
    end
    return pages
end


function B:NewItemKey(item)
    return item.guid or (item.bag .. ":" .. item.slot .. ":" .. item.id)
end
function B:ScanNewItems()
    if not FS.db or not FS:IsModuleEnabled("Bags") then return end
    self.newItems = self.newItems or {}
    local present, totals = {}, {}
    self.recentItems = self.recentItems or {}
    for bag = 0, V:BagLimit() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = V:ReadItem(bag, slot)
            if item then
                local key = self:NewItemKey(item); present[key] = true
                totals[item.id] = (totals[item.id] or 0) + item.count
                local isNew = C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot)
                if not V:IsSecret(isNew) and isNew then
                    if not self.newItems[key] then self.recentItems[item.id] = GetTime() end
                    self.newItems[key] = true
                end
            end
        end
    end
    for key in pairs(self.newItems) do if not present[key] then self.newItems[key] = nil end end
    for id, count in pairs(totals) do
        if self.previousTotals and count > (self.previousTotals[id] or 0) then self.recentItems[id] = GetTime() end
    end
    for id, time in pairs(self.recentItems) do
        if not totals[id] or GetTime() - time >= 600 then self.recentItems[id] = nil end
    end
    self.previousTotals = totals
end
function B:IsNewLoot(item)
    if not FS.db.bags.showNewLoot or not item or item.empty or item.stock then return false end
    return self.newItems and self.newItems[self:NewItemKey(item)] == true
end
function B:ReviewNewItem(item)
    if not item or item.empty or item.stock or InCombatLockdown() then return end
    local current = V:ReadItem(item.bag, item.slot)
    if not current or current.id ~= item.id or (item.guid and current.guid ~= item.guid) then return end
    if self.newItems then self.newItems[self:NewItemKey(current)] = nil end
    if C_NewItems and C_NewItems.RemoveNewItem then C_NewItems.RemoveNewItem(item.bag, item.slot) end
end
function B:UpdateCellExtras(cell, item)
    cell.cooldown:Hide(); cell.newLoot:Hide()
    if not item or item.empty or item.stock then return end
    cell.newLoot:SetShown(self:IsNewLoot(item))
    if FS.db.bags.showCooldowns and C_Container.GetContainerItemCooldown then
        local start, duration, enabled = C_Container.GetContainerItemCooldown(item.bag, item.slot)
        if not V:IsSecret(start) and not V:IsSecret(duration) and not V:IsSecret(enabled)
            and enabled == 1 and V:ValidNumber(start, 0, 10000000000)
            and V:ValidNumber(duration, 0, 1000000000) and duration > 0
            and start + duration > GetTime() then
            cell.cooldown:SetCooldown(start, duration); cell.cooldown:Show()
        end
    end
end
