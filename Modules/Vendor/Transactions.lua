local _, FS = ...
local V = FS.modules.Vendor

function V:StopTransactions(message)
    self.generation = self.generation + 1
    -- An issued operation remains in flight even after its continuation is cancelled.
    -- Keep the transaction lock until it settles, so Stop cannot cause a duplicate sale.
    local pending = self.pending
    if not pending then self.busy = false
    elseif pending.check() or pending.timedOut then
        pending.finished = true
        if pending.timedOut and pending.visit then pending.visit.unconfirmed = true end
        self.pending = nil
        self.busy = false
    elseif not pending.detached then
        pending.detached = true
        local attempts = 0
        local function reconcile()
            if pending.finished then return end
            attempts = attempts + 1
            local confirmed = pending.check()
            if confirmed or attempts >= 30 then
                pending.finished = true
                if not confirmed and pending.visit then pending.visit.unconfirmed = true end
                if self.pending == pending then self.pending = nil; self.busy = false end
                self:QueueRefresh()
            else self:After(0.15, reconcile) end
        end
        self:After(0.15, reconcile)
    end
    self.repairConfirmation = nil
    if message then self.status = message end
end

function V:WaitFor(check, done, description)
    local generation = self.generation
    local attempts = 0
    local pending = { check = check, visit = self.visit }
    self.pending = pending
    local function poll()
        if generation ~= self.generation then return end
        if check() then
            pending.finished = true
            self.pending = nil
            self:Refresh()
            done()
            return
        end
        attempts = attempts + 1
        if attempts >= 30 or not self:CanTransact() then
            pending.timedOut = attempts >= 30
            self:StopTransactions(description .. " was not confirmed. Nothing else was attempted.")
            self:Refresh()
            return
        end
        self:After(0.15, poll)
    end
    self:After(0.15, poll)
end

function V:StartVisitAutomation()
    local db = self:Settings()
    local function restock()
        if db.autoRestock then self:StartRestock() end
    end
    local function repair()
        if db.autoRepair then self:TryRepair(false, restock) else restock() end
    end
    if db.mode ~= "manual" then self:StartSelling(nil, repair) else repair() end
end

function V:StartSelling(oneItem, finished, reviewed)
    if self.busy or not self:CanTransact() then return end
    self.busy = true
    self.status = "Selling eligible items..."
    local generation = self.generation
    local sales = 0
    local function nextSale()
        if generation ~= self.generation then return end
        if not self:CanTransact() then self:StopTransactions("Selling paused. Visit a merchant outside combat with an empty cursor."); self:Refresh(); return end
        local plan = self:BuildPlan()
        local item
        if oneItem then item=self:AvailableSale(oneItem) else item=plan.sale[1] end
        if reviewed then
            local approved = reviewed[sales + 1]
            item = approved and self:AvailableSale(approved) or nil
            if approved and (not item or item.count ~= approved.count or item.sellCount ~= approved.sellCount or item.price ~= approved.price) then
                self:StopTransactions("The reviewed inventory changed. Review your junk again."); self:Refresh(); return
            end
        end
        if oneItem and sales > 0 then item = nil end
        if not item then
            self.busy = false
            self.status = "Sale finished. " .. sales .. " stacks processed."
            self:Refresh()
            if finished then finished() end
            return
        end
        if item.sellCount < item.count then
            local bag, slot = self:FindEmptySlot()
            if not bag then self:StopTransactions("A normal bag slot is needed to split reserved stock. Free one slot and try again."); self:Refresh(); return end
            if not C_Container.SplitContainerItem or not C_Container.PickupContainerItem then
                self:StopTransactions("Stack splitting is unavailable in this client."); self:Refresh(); return
            end
            local quantity = item.sellCount
            C_Container.SplitContainerItem(item.bag, item.slot, quantity)
            if not CursorHasItem() then self:StopTransactions("The stack could not be split."); self:Refresh(); return end
            -- Never sell a cursor item directly: stage it in a normal bag slot first.
            C_Container.PickupContainerItem(bag, slot)
            if CursorHasItem() then
                ClearCursor()
                self:StopTransactions("The split stack could not be placed in a bag."); self:Refresh(); return
            end
            self:WaitFor(function()
                local split = self:ReadItem(bag, slot)
                local source = self:ReadItem(item.bag, item.slot)
                return split and not split.locked and split.id == item.id and split.count == quantity
                    and source and not source.locked and source.id == item.id and source.count == item.count - quantity
            end, function()
                local split = self:ReadItem(bag,slot)
                if split then
                    split.manualSale=item.manualSale; split.manualLimit=item.manualLimit
                    split=self:AvailableSale(split)
                end
                if not split or split.sellCount ~= quantity then
                    self:StopTransactions("Rules or inventory changed after splitting. Review the plan."); self:Refresh(); return
                end
                split.staged = true
                self:IssueSale(split, function() sales = sales + 1; nextSale() end)
            end, "Stack split")
        else
            self:IssueSale(item, function() sales = sales + 1; nextSale() end)
        end
    end
    nextSale()
end

function V:IssueSale(item, done)
    local current = self:AvailableSale(item)
    if not self:CanTransact() or not current or current.sellCount ~= current.count then
        self:StopTransactions("Inventory or protection changed. Review the plan."); self:Refresh(); return
    end
    if CanSellItems and not CanSellItems() then self:StopTransactions("This merchant is not accepting sales."); self:Refresh(); return end
    local before = GetMoney()
    local visit = self.visit
    local expected = current.price * current.count
    local counted = false
    C_Container.UseContainerItem(current.bag, current.slot)
    self:WaitFor(function()
        if counted then return true end
        local remaining = self:ReadItem(current.bag, current.slot)
        local removed = not remaining or remaining.id ~= current.id or (current.guid and remaining.guid ~= current.guid)
        local earned = GetMoney() - before
        if removed and earned >= expected then
            counted = true
            if visit then
                visit.sold = visit.sold + expected
                visit.transactions = visit.transactions + 1
                if not remaining and not item.staged then visit.freed = visit.freed + 1 end
            end
            return true
        end
        return false
    end, done, "Sale")
end

function V:RepairQuote()
    if not self.merchantOpen or not CanMerchantRepair or not CanMerchantRepair() then return nil, "This merchant cannot repair." end
    local cost, needed = GetRepairAllCost()
    if not self:ValidNumber(cost, 0, 10000000000) or not needed or cost <= 0 then return nil, "No repairs needed." end
    local db = self:Settings()
    local source = db.repairSource
    local guildAvailable = false
    local guildBalance = 0
    if source ~= "personal" and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair()
        and GetGuildBankWithdrawMoney and GetGuildBankMoney then
        local allowance = GetGuildBankWithdrawMoney()
        local money = GetGuildBankMoney()
        if not self:IsSecret(allowance) and self:ValidNumber(money, 0, 100000000000) then
            guildBalance = money
            guildAvailable = (allowance == -1 or (self:ValidNumber(allowance, 0, 100000000000) and allowance >= cost)) and money >= cost
        end
    end
    local guild = source ~= "personal" and guildAvailable
    if source == "guild" and not guild then return nil, "Guild repairs unavailable or allowance too low." end
    if not guild and GetMoney() - cost < db.moneyReserve then return nil, "Not enough money above your reserve." end
    return { cost = cost, guild = guild, source = guild and "guild" or "personal",
        guildMoney = guild and guildBalance or 0 }
end

function V:TryRepair(confirmed, finished)
    if self.busy or not self:CanTransact() then return end
    local quote, reason = self:RepairQuote()
    if not quote then self.status = reason; self:Refresh(); if finished then finished() end; return end
    local db = self:Settings()
    if db.repairLimit > 0 and quote.cost > db.repairLimit then
        if not db.confirmRepair then
            self.status = "Repair exceeds your limit: " .. self:Money(quote.cost)
            self:Refresh(); if finished then finished() end; return
        end
        if not confirmed or not self.repairConfirmation or self.repairConfirmation.cost ~= quote.cost
            or self.repairConfirmation.source ~= quote.source then
            self.repairConfirmation = quote
            self.status = "Repair costs " .. self:Money(quote.cost) .. ". Click Confirm Repair to approve this visit."
            self.tab = "Overview"
            local bags = FS.modules.Bags
            local gear = FS.modules.Gear
            if not (bags and bags.window and bags.window:IsShown())
                and not (gear and gear.window and gear.window:IsShown()) then self:ShowWindow(true) end
            self:Refresh()
            return
        end
    end
    self.repairConfirmation = nil
    self.busy = true
    self.status = "Repairing with " .. quote.source .. " funds..."
    local before = GetMoney()
    local visit = self.visit
    local counted = false
    RepairAllItems(quote.guild)
    self:WaitFor(function()
        if counted then return true end
        local remaining, needed = GetRepairAllCost()
        local bankMoney = quote.guild and GetGuildBankMoney and GetGuildBankMoney()
        local guildConfirmed = quote.guild and self:ValidNumber(bankMoney, 0, 100000000000) and quote.guildMoney - bankMoney >= quote.cost
        local repairConfirmed = self.merchantOpen and self:ValidNumber(remaining, 0, 10000000000) and (not needed or remaining == 0)
        if (repairConfirmed or guildConfirmed) and (quote.guild or before - GetMoney() >= quote.cost) then
            counted = true
            if visit then
                local key = quote.guild and "guildRepair" or "personalRepair"
                visit[key] = visit[key] + quote.cost
                visit.transactions = visit.transactions + 1
            end
            return true
        end
        return false
    end, function()
        self.busy = false
        self.status = "Repair completed using " .. quote.source .. " funds."
        self:Refresh()
        if finished then finished() end
    end, "Repair")
end

function V:RestockPlan()
    local plan = { items = {}, cost = 0, units = 0 }
    if not self.merchantOpen then return plan end
    local db = self:Settings()
    local _, totals, unknown = self:Snapshot()
    local ids = {}
    for id, rule in pairs(db.rules) do if rule.target > 0 then ids[#ids + 1] = id end end
    table.sort(ids)
    local budget = math.max(0, math.min(db.restockBudget - (self.visit and self.visit.restocked or 0), GetMoney() - db.moneyReserve))
    for _, id in ipairs(ids) do
        local missing = math.max(0, db.rules[id].target - (totals[id] or 0))
        if missing > 0 then
            local row = { id = id, name = self:ItemName(id), count = 0, missing = missing, reason = "Not sold by this merchant" }
            for index = 1, GetMerchantNumItems() do
                if GetMerchantItemID(index) == id then
                    local info = self:MerchantItem(index)
                    if unknown > 0 then row.reason = "Inventory data unavailable; purchase paused"
                    elseif info and not self:IsSecret(info.price) and not self:IsSecret(info.stackCount)
                        and not self:IsSecret(info.numAvailable) and not self:IsSecret(info.hasExtendedCost)
                        and not self:IsSecret(info.isPurchasable) and info.isPurchasable and not info.hasExtendedCost
                        and info.price > 0 and info.stackCount > 0 then
                        local bundle = info.stackCount
                        -- Purchase complete vendor bundles without exceeding the configured target.
                        local quantity = math.floor(missing / bundle) * bundle
                        if info.numAvailable >= 0 then quantity = math.min(quantity, math.floor(info.numAvailable / bundle) * bundle) end
                        quantity = math.min(quantity, math.floor(budget / info.price) * bundle)
                        local maxStack = GetMerchantItemMaxStack(index) or bundle
                        quantity = math.min(quantity, math.floor(maxStack / bundle) * bundle)
                        row.index, row.bundle, row.unitPrice = index, bundle, info.price / bundle
                        row.count = math.max(0, quantity)
                        row.cost = (row.count / bundle) * info.price
                        row.reason = row.count > 0 and "Ready to restock" or "Budget, stock or bundle size prevents purchase"
                        budget = budget - row.cost
                        plan.cost = plan.cost + row.cost
                        plan.units = plan.units + row.count
                    else row.reason = "Currency/token cost or unavailable item" end
                    break
                end
            end
            plan.items[#plan.items + 1] = row
        end
    end
    return plan
end

function V:StartRestock()
    if self.busy or not self:CanTransact() then return end
    self.busy = true
    self.status = "Restocking configured supplies..."
    local generation = self.generation
    local function nextPurchase()
        if generation ~= self.generation then return end
        if not self:CanTransact() then self:StopTransactions("Restocking paused."); self:Refresh(); return end
        local row
        for _, item in ipairs(self:RestockPlan().items) do if item.count > 0 then row = item; break end end
        if not row then self.busy = false; self.status = "Restock finished. See Supplies for missing stock."; self:Refresh(); return end
        local beforeCount, beforeMoney = self:CountItem(row.id), GetMoney()
        local visit = self.visit
        local counted = false
        BuyMerchantItem(row.index, row.count)
        self:WaitFor(function()
            if counted then return true end
            local added = self:CountItem(row.id) - beforeCount
            local spent = beforeMoney - GetMoney()
            if added >= row.count and spent >= row.cost then
                counted = true
                if visit then
                    visit.restocked = visit.restocked + row.cost
                    visit.transactions = visit.transactions + 1
                end
                return true
            end
            return false
        end, nextPurchase, "Restock purchase")
    end
    nextPurchase()
end

function V:BuyBack(row)
    if self.busy or not self:CanTransact() then return end
    local current
    for _, item in ipairs(self:BuybackList()) do
        if item.index == row.index and item.link == row.link and item.count == row.count and item.price == row.price then current = item end
    end
    if not current then self.status = "This item is no longer available for buy back."; self:Refresh(); return end
    if GetMoney() - current.price < self:Settings().moneyReserve then self.status = "Buy back would exceed your money reserve."; self:Refresh(); return end
    local id = self:ItemID(current.link)
    if not id then return end
    self.busy = true
    local before, money = self:CountItem(id), GetMoney()
    local visit = self.visit
    local counted = false
    BuybackItem(current.index)
    self:WaitFor(function()
        if counted then return true end
        if self:CountItem(id) >= before + current.count and money - GetMoney() >= current.price then
            counted = true
            if visit then
                visit.boughtBack = visit.boughtBack + current.price
                visit.transactions = visit.transactions + 1
            end
            return true
        end
        return false
    end, function() self.busy = false; self.status = "Item bought back."; self:Refresh() end, "Buy back")
end
