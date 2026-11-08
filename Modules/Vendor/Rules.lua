local _, FS = ...
local V = FS.modules.Vendor

function V:Protection(item)
    if item.pending then return "Item data not ready" end
    if item.quest then return "Quest item" end
    if item.lootable then return "Contains loot" end
    if item.inSet then return "Saved equipment set" end
    if item.refundable then return "Refundable purchase" end
    if self:Settings().alwaysKeep[item.id] then return "Always Keep" end
    if self:Settings().protectRare and item.quality >= 3 then return "Rare or higher quality protected" end
    if item.noValue or item.price <= 0 then return "No vendor value" end
    for name, provider in pairs(self.providers) do
        local ok, reason = pcall(provider, item)
        if not ok then return "Protection unavailable: " .. name end
        if reason then return tostring(reason) end
    end
end

function V:Reserve(item)
    local rule = self:Settings().rules[item.id]
    local reserve = rule and math.max(rule.keep, rule.target) or 0
    for _, provider in pairs(self.providers) do
        local ok, _, quantity = pcall(provider, item)
        if ok then reserve = math.max(reserve, self:ValidNumber(quantity, 0, 100000) or 0) end
    end
    return reserve
end

function V:IsJunk(item)
    local db = self:Settings()
    if item.quality == 0 and db.includeGray then return true, "Gray quality" end
    local rule = db.rules[item.id]
    if db.mode ~= "auto" and rule and rule.junk then return true, "Custom junk rule" end
    return false, "No matching junk rule"
end

function V:BuildPlan()
    local items, totals = self:Snapshot()
    local plan = { items = items, totals = totals, sale = {}, value = 0, slots = 0, units = 0, bySlot = {}, reserves = {} }
    local sellableTotals = {}
    -- Protected stacks already satisfy a reserve. Only eligible quantities may be removed.
    for _, item in ipairs(items) do
        item.protection = self:Protection(item)
        item.junk, item.ruleReason = self:IsJunk(item)
        plan.reserves[item.id] = math.max(plan.reserves[item.id] or 0, self:Reserve(item))
        if not item.protection and item.junk and not item.locked then
            sellableTotals[item.id] = (sellableTotals[item.id] or 0) + item.count
        end
    end
    local remaining = {}
    for id, total in pairs(totals) do
        remaining[id] = math.min(sellableTotals[id] or 0, math.max(0, total - (plan.reserves[id] or 0)))
    end
    -- Small stacks first frees more slots, with stable bag/slot ordering as a tiebreaker.
    table.sort(items, function(a, b)
        if a.count ~= b.count then return a.count < b.count end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    for _, item in ipairs(items) do
        item.sellCount = 0
        if item.protection then item.reason = item.protection
        elseif item.locked then item.reason = "Item locked"
        elseif not item.junk then item.reason = item.ruleReason
        else
            item.sellCount = math.min(item.count, remaining[item.id] or 0)
            remaining[item.id] = (remaining[item.id] or 0) - item.sellCount
            if item.sellCount == 0 then item.reason = "Reserved stock: " .. (plan.reserves[item.id] or 0)
            elseif item.sellCount < item.count then item.reason = "Sell " .. item.sellCount .. "; keep " .. (item.count - item.sellCount)
            else item.reason = item.ruleReason end
        end
        if item.sellCount > 0 then
            plan.sale[#plan.sale + 1] = item
            plan.value = plan.value + item.price * item.sellCount
            plan.units = plan.units + item.sellCount
            if item.sellCount == item.count then plan.slots = plan.slots + 1 end
        end
        plan.bySlot[item.bag .. ":" .. item.slot] = item
    end
    return plan
end

function V:AvailableSale(item,manual)
    local plan = self:BuildPlan()
    local current = plan.bySlot[item.bag .. ":" .. item.slot]
    if not current or current.id ~= item.id or current.link ~= item.link then return nil,"This item moved. Select it again." end
    if item.guid and current.guid ~= item.guid then return nil,"This item moved. Select it again." end
    if manual or item.manualSale then
        if current.protection then return nil,current.protection end
        if current.locked then return nil,"Item locked" end
        current.sellCount=math.min(current.count,math.max(0,(plan.totals[current.id] or 0)-(plan.reserves[current.id] or 0)),item.manualLimit or current.count)
        if current.sellCount<=0 then return nil,"Kept for your saved quantity." end
        current.manualSale=true; current.manualLimit=current.sellCount
    end
    if current.sellCount <= 0 then return nil,current.reason or "Kept for your saved quantity." end
    return current
end
