local _,FS=...
FS.patchNotes={
    {version="1.0.13",lines={
        "Fixes the Lua error after login or /reload in version 1.0.12.",
        "Minimap styling now waits until saved settings and addon initialization are ready.",
        "Your existing settings and profiles are preserved.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
