local _, FS = ...
local V = { providers = {}, trackedButtons = {}, generation = 0 }
FS:RegisterModule("Vendor", V)
V.modes = { "manual", "auto", "custom" }
V.modeNames = { manual = "Manual", auto = "Auto Junk", custom = "Custom Rules" }

function V:Settings()
    return FS.db.vendor
end

function V:NormalizeSettings()
    local db = self:Settings()
    if not self.modeNames[db.mode] then db.mode = "manual" end
    if db.repairSource ~= "personal" and db.repairSource ~= "guild" and db.repairSource ~= "guildFirst" then
        db.repairSource = "personal"
    end
    for _, key in ipairs({ "repairLimit", "restockBudget", "moneyReserve" }) do
        db[key] = self:ValidNumber(db[key], 0, 10000000000) or FS.defaults.vendor[key]
    end
    db.glow.intensity = self:ValidNumber(db.glow.intensity, 0.1, 1) or 0.8
    if db.glow.color ~= "green" and db.glow.color ~= "gold" and db.glow.color ~= "cyan" then db.glow.color = "green" end
    for id, rule in pairs(db.rules) do
        if type(id) ~= "number" or not self:ValidNumber(id, 1, 100000000) or id ~= math.floor(id) or type(rule) ~= "table" then
            db.rules[id] = nil
        else
            rule.junk = rule.junk == true
            rule.keep = math.floor(self:ValidNumber(rule.keep, 0, 100000) or 0)
            rule.target = math.floor(self:ValidNumber(rule.target, 0, 100000) or 0)
        end
    end
    for id, value in pairs(db.alwaysKeep) do
        if type(id) ~= "number" or not self:ValidNumber(id, 1, 100000000) or id ~= math.floor(id) or value ~= true then db.alwaysKeep[id] = nil end
    end
    local history = {}
    for _, entry in ipairs(db.history) do
        if type(entry) == "table" and type(entry.date) == "string" and type(entry.text) == "string" then
            history[#history + 1] = entry
            if #history == 20 then break end
        end
    end
    db.history = history
end

function V:ValidNumber(value, minimum, maximum)
    if self:IsSecret(value) or type(value) ~= "number" or value ~= value then return nil end
    if value < minimum or value > maximum then return nil end
    return value
end

function V:After(delay, callback)
    C_Timer.After(delay, callback)
end

function V:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:NormalizeSettings()
    local frame = CreateFrame("Frame")
    self.events = frame
    for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED",
        "ITEM_LOCK_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_MONEY", "ADDON_LOADED" }) do
        FS:RegisterClientEvent(frame,event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then self:OpenMerchant()
        elseif event == "MERCHANT_CLOSED" then self:CloseMerchant()
        elseif event == "PLAYER_REGEN_ENABLED" or event == "ADDON_LOADED" then
            self:InstallBagHooks()
            self:QueueRefresh()
        else self:QueueRefresh() end
    end)
    self:InstallBagHooks()
    self:QueueRefresh()
end

function V:QueueRefresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    self:After(0.1, function()
        self.refreshQueued = false
        self:Refresh()
    end)
end

function V:Refresh()
    if not FS.db then return end
    self.plan = self:BuildPlan()
    self:RefreshHighlights()
    if self.window and self.window:IsShown() then self:RefreshWindow() end
    local bags = FS.modules.Bags
    if bags and bags.window and bags.window:IsShown() then bags:Refresh(self.plan) end
    if FS.modules.Gear then FS.modules.Gear:Refresh() end
    if self.RefreshSaleReview then self:RefreshSaleReview() end
    if FS.window and FS.window:IsShown() then FS:RefreshConfig() end
end

function V:SettingsChanged()
    self:StopTransactions("Settings changed. Review the updated plan before continuing.")
    self:NormalizeSettings()
    self:Refresh()
end

function V:SetMode(mode)
    self:Settings().mode = mode
    self:SettingsChanged()
end

function V:SetRule(id, junk, keep, target)
    if not self:ValidNumber(id, 1, 100000000) or id ~= math.floor(id) then return false end
    self:Settings().rules[id] = { junk = junk == true, keep = math.floor(keep or 0), target = math.floor(target or 0) }
    self:SettingsChanged()
    return true
end

function V:KeepItem(id)
    self:Settings().alwaysKeep[id] = true
    self:SettingsChanged()
end

-- Providers return a reason to keep every copy, or nil plus a quantity to reserve.
-- A provider error fails closed. Future Bags/Gear/Professions modules can use this API.
function V:RegisterProtectionProvider(name, callback)
    assert(type(name) == "string" and type(callback) == "function", "Invalid protection provider")
    self.providers[name] = callback
    self:QueueRefresh()
end

function V:UnregisterProtectionProvider(name)
    self.providers[name] = nil
    self:QueueRefresh()
end

function V:OpenMerchant()
    self:CloseMerchant()
    self.merchantOpen = true
    self.visit = { sold = 0, personalRepair = 0, guildRepair = 0, restocked = 0, boughtBack = 0, freed = 0, transactions = 0 }
    local generation = self.generation
    self:After(0.25, function()
        if generation ~= self.generation or not self.merchantOpen or not MerchantFrame:IsShown()
            or InCombatLockdown() or CursorHasItem() then return end
        self:Refresh()
        local db = self:Settings()
        if db.enabled then self:NotifyLowStock() end
        if db.enabled and db.mode == "auto" then
            self:StartVisitAutomation()
            return
        end
        local bags = FS.modules.Bags
        if bags and FS:IsModuleEnabled("Bags") and FS.db.bags.openAtMerchant then bags:ShowWindow()
        elseif db.enabled and db.showPanel then self:ShowWindow(true) end
        if db.enabled then self:StartVisitAutomation() end
    end)
end

function V:NotifyLowStock()
    local extensions=FS.Extensions
    if not extensions then return end
    local options=extensions:AlertOptions('Low stock')
    if options.history==false and not options.popup and options.sound=='Silent' then return end
    local targets={}
    for id,rule in pairs(self:Settings().rules) do
        if rule.target>0 then targets[id]=rule.target end
    end
    if not next(targets) then return end
    local _,totals,unknown=self:Snapshot()
    if unknown~=0 then return end
    local missing=0
    for id,target in pairs(targets) do
        if (totals[id] or 0)<target then missing=missing+1 end
    end
    if missing>0 then
        extensions:Alert('Low stock',false,missing..' stock goals below target at merchant arrival.')
    end
end

function V:CloseMerchant()
    if self.saleReview then self.saleReview:Hide() end
    local pending = self.pending
    self:StopTransactions()
    self.merchantOpen = false
    if self.visit then
        local visit = self.visit
        local function recordVisit()
            if pending and not pending.finished then self:After(0.15, recordVisit); return end
            if visit.transactions > 0 or visit.unconfirmed then
                local text = self:VisitSummary(visit)
                if self:Settings().report then FS:Print(text) end
                local history = self:Settings().history
                table.insert(history, 1, { text = text, date = date("%Y-%m-%d %H:%M") })
                while #history > 20 do table.remove(history) end
                self:QueueRefresh()
            end
        end
        recordVisit()
        self.visit = nil
    end
    if self.window and self.autoOpened then self.window:Hide() end
    self.autoOpened = false
    self:QueueRefresh()
end

function V:VisitSummary(visit)
    local net = visit.sold - visit.personalRepair - visit.restocked - visit.boughtBack
    return "Sold: " .. self:Money(visit.sold) .. " | Repairs: " .. self:Money(visit.personalRepair)
        .. " (guild: " .. self:Money(visit.guildRepair) .. ") | Restocked: " .. self:Money(visit.restocked)
        .. " | Buy back: " .. self:Money(visit.boughtBack) .. " | Net: " .. (net < 0 and "-" or "+")
        .. self:Money(math.abs(net)) .. " | Freed by sales: " .. visit.freed .. " slots"
        .. (visit.unconfirmed and " | An unconfirmed action is excluded from these totals." or "")
end
