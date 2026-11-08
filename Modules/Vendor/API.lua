local _, FS = ...
local V = FS.modules.Vendor

function V:IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function V:Money(copper)
    copper = math.floor(self:ValidNumber(copper, 0, 100000000000) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%dg %ds %dc", gold, silver, copper % 100)
end

function V:ItemID(text)
    if self:IsSecret(text) then return nil end
    local id = tonumber(text) or tonumber(string.match(tostring(text or ""), "item:(%d+)"))
    if self:ValidNumber(id, 1, 100000000) and id == math.floor(id) then return id end
end

function V:BagLimit()
    return NUM_TOTAL_BAG_FRAMES or NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

function V:CanTransact()
    return self.merchantOpen and self:Settings().enabled and MerchantFrame and MerchantFrame:IsShown()
        and not InCombatLockdown() and not CursorHasItem() and not InRepairMode()
        and (not SpellIsTargeting or not SpellIsTargeting())
end

function V:ItemName(id)
    local name, link = C_Item.GetItemInfo(id)
    if not self:IsSecret(name) and name then return name, link end
    self:RequestItemData(id)
    return "Item #" .. id
end

function V:RequestItemData(id)
    self.requestedItems = self.requestedItems or {}
    if not self.requestedItems[id] and C_Item.RequestLoadItemDataByID then
        self.requestedItems[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
end

function V:ReadItem(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil end
    for _, key in ipairs({ "itemID", "stackCount", "isLocked", "hasLoot", "hasNoValue", "hyperlink", "quality", "iconFileID" }) do
        if self:IsSecret(info[key]) then return nil, true end
    end
    if not self:ValidNumber(info.itemID, 1, 100000000) or not self:ValidNumber(info.stackCount, 1, 100000) then return nil, true end
    local name, link, quality, _, _, itemType, subType, maxStack, _, icon, price, classID, subclassID = C_Item.GetItemInfo(info.hyperlink or info.itemID)
    local item = {
        bag = bag, slot = slot, id = info.itemID, count = info.stackCount,
        link = info.hyperlink, icon = info.iconFileID, locked = info.isLocked,
        lootable = info.hasLoot, noValue = info.hasNoValue,
    }
    if self:IsSecret(name) or self:IsSecret(price) or self:IsSecret(quality) or self:IsSecret(classID)
        or self:IsSecret(maxStack) or self:IsSecret(icon) or self:IsSecret(link) or not name or not price or quality == nil then
        item.name = "Item #" .. item.id
        item.pending = true
        self:RequestItemData(item.id)
        return item
    end
    item.name, item.link, item.quality = name, link or item.link, quality
    item.price, item.maxStack, item.classID = price, maxStack or 1, classID
    item.subclassID = not self:IsSecret(subclassID) and subclassID or nil
    item.itemType = not self:IsSecret(itemType) and itemType or nil
    item.subType = not self:IsSecret(subType) and subType or nil
    item.icon = icon or item.icon
    local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
    if quest then
        if self:IsSecret(quest.isQuestItem) or self:IsSecret(quest.questID) then item.pending = true
        else item.quest = quest.isQuestItem or quest.questID ~= nil end
    else item.pending = true end
    if classID == 12 then item.quest = true end
    if C_Container.GetContainerItemEquipmentSetInfo then
        local inSet = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
        if self:IsSecret(inSet) then item.pending = true else item.inSet = inSet end
    end
    if C_Container.GetContainerItemPurchaseInfo then
        local purchase = C_Container.GetContainerItemPurchaseInfo(bag, slot, false)
        if purchase then
            if self:IsSecret(purchase.refundSeconds) then item.pending = true
            else item.refundable = (purchase.refundSeconds or 0) > 0 end
        end
    end
    if ItemLocation and C_Item.GetItemGUID then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        local guid = C_Item.GetItemGUID(location)
        if not self:IsSecret(guid) then item.guid = guid end
    end
    return item
end

function V:Snapshot()
    local items, totals, unknown = {}, {}, 0
    for bag = 0, self:BagLimit() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item, unreadable = self:ReadItem(bag, slot)
            if unreadable then unknown = unknown + 1 end
            if item then
                items[#items + 1] = item
                totals[item.id] = (totals[item.id] or 0) + item.count
            end
        end
    end
    return items, totals, unknown
end

function V:CountItem(id)
    local _, totals = self:Snapshot()
    return totals[id] or 0
end

function V:FindEmptySlot()
    -- A normal bag accepts every item; special-purpose bags do not.
    for bag = 0, self:BagLimit() do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 and (family == 0 or bag == 0) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if not C_Container.GetContainerItemInfo(bag, slot) then return bag, slot end
            end
        end
    end
end

function V:MerchantItem(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then return C_MerchantFrame.GetItemInfo(index) end
    -- Compatibility fallback for beta builds before the table-returning API.
    if GetMerchantItemInfo then
        local name, texture, price, count, available, usable, extended = GetMerchantItemInfo(index)
        if name then return { name = name, texture = texture, price = price, stackCount = count,
            numAvailable = available, isPurchasable = true, isUsable = usable, hasExtendedCost = extended } end
    end
end

function V:BuybackList()
    local items = {}
    if not self.merchantOpen then return items end
    for index = 1, GetNumBuybackItems() do
        local name, icon, price, count = GetBuybackItemInfo(index)
        local link = GetBuybackItemLink(index)
        if name and not self:IsSecret(price) and not self:IsSecret(link) then
            items[#items + 1] = { index = index, name = name, icon = icon, price = price, count = count, link = link }
        end
    end
    return items
end
