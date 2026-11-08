local addonName, FS = ...
local events = CreateFrame("Frame")
FS.events = events
FS:RegisterClientEvent(events,"ADDON_LOADED")
FS:RegisterClientEvent(events,"PLAYER_LOGIN")
FS:RegisterClientEvent(events,"PLAYER_LOGOUT")
FS:RegisterClientEvent(events,"ADDON_ACTION_BLOCKED")
FS:RegisterClientEvent(events,"ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(self, event, name, action)
    if event=="PLAYER_LOGOUT" then
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
    elseif event == "PLAYER_LOGIN" then
        FS:Initialize()
        FS:CreateMinimapButton()
        FS:UpdateMinimapButton()
        if FS.Installer:NeedsSetup() then FS.Installer:Show()
        elseif FS.db.patchLog.showOnLoad then FS:ShowPatchLog() end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
