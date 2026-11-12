local addonName, FS = ...
local events = CreateFrame("Frame")
FS.events = events
FS:RegisterClientEvent(events,"ADDON_LOADED")
FS:RegisterClientEvent(events,"PLAYER_LOGIN")
FS:RegisterClientEvent(events,"PLAYER_ENTERING_WORLD")
FS:RegisterClientEvent(events,"PLAYER_REGEN_ENABLED")
FS:RegisterClientEvent(events,"PLAYER_LOGOUT")
FS:RegisterClientEvent(events,"ADDON_ACTION_BLOCKED")
FS:RegisterClientEvent(events,"ADDON_ACTION_FORBIDDEN")
-- Login may already have fired when an addon is enabled or loaded on demand.
-- Wait until other login handlers finish, and keep the request pending in combat.
function FS:QueueStartup()
    if self.startupHandled or self.startupQueued then return end
    self.startupPending=true; self.startupQueued=true
    C_Timer.After(.75,function()
        self.startupQueued=false
        if not self.startupPending or self.startupHandled or InCombatLockdown() then return end
        self:Initialize()
        self:CreateMinimapButton(); self:UpdateMinimapButton()
        local installer=self.Installer
        if installer.window and installer.window:IsShown() or self.installerReturn then
            self.startupPending=false; self.startupHandled=true; return
        end
        if installer:NeedsSetup() then
            if not installer:Show() then return end
        elseif self.db.patchLog.showOnLoad then self:ShowPatchLog() end
        self.startupPending=false; self.startupHandled=true
    end)
end

events:SetScript("OnEvent", function(self, event, name, action)
    if event=="PLAYER_LOGOUT" then
        FS.startupPending=false
        if FS.Extensions then FS.Extensions:FinishGathering('Logged out') end
        if FS.initialized and FS.modules.Profiles then FS.modules.Profiles:PersistCurrent() end
        return
    end
    if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then
        FS.runtimeErrors=FS.runtimeErrors or {}
        if #FS.runtimeErrors>=10 then table.remove(FS.runtimeErrors,1) end
        FS.runtimeErrors[#FS.runtimeErrors+1]=event.." | "..tostring(name).." | "..tostring(action).." | combat="..tostring(InCombatLockdown())
        if name==addonName and type(debugstack)=="function" then
            FS.lastBlockedStack=debugstack(2,10,0)
        end
        return
    end
    if event == "ADDON_LOADED" and name == addonName then
        FS:Initialize()
        self:UnregisterEvent("ADDON_LOADED")
        if IsLoggedIn and IsLoggedIn() then FS:QueueStartup() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        FS:QueueStartup()
    elseif event == "PLAYER_REGEN_ENABLED" and FS.startupPending then
        FS:QueueStartup()
    end
end)
