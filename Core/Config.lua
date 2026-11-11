local _, FS = ...
function FS:SelectLocale()
    self.db.language = "enUS"
    self.L = self.locales.enUS
end

SLASH_FOREVERSUITE1 = "/fs"
SlashCmdList.FOREVERSUITE = function(message)
    if type(message)=="string" and message:lower():match("^%s*tools%s*$") then if FS.initialized then FS.modules.Workbench:ShowWindow() end; return end
    if type(message)=="string" and message:lower():match("^%s*undo%s*$") then if FS.initialized then FS.Extensions:Undo() end; return end
    if type(message)=="string" and message:lower():match("^%s*audit%s*$") then if FS.initialized then FS.modules.Workbench:Choose('Maintenance') end; return end
    if type(message)=="string" and message:lower():match("^%s*status%s*$") then FS:PrintClientStatus(); return end
    if not FS.initialized then return end
    if type(message)=="string" and message:lower():match("^%s*help%s*$") then FS.Beginner:ShowRecovery(); return end
    if type(message)=="string" and message:lower():match("^%s*tour%s*$") then FS.Beginner:ShowTour(); return end
    if type(message)=="string" and message:lower():match("^%s*addons%s*$") then FS.Compatibility:Show(); return end
    if type(message)=="string" and message:lower():match("^%s*errors%s*$") then
        if not FS.runtimeErrors or #FS.runtimeErrors==0 then FS:Print("No blocked addon actions recorded this session.") end
        for _,line in ipairs(FS.runtimeErrors or {}) do FS:Print(line) end
        if FS.lastBlockedStack then FS:Print("Last blocked action stack:\n"..FS.lastBlockedStack) end
    elseif type(message)=="string" and message:lower():match("^%s*setup%s*$") then FS.Installer:Show() else FS:ShowConfig() end
end
