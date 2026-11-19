local _,FS=...
FS.patchNotes={
    {version="1.0.8",lines={
        "Minimap frames follow your selected theme.",
        "Choose a square, Diablo-inspired Dark Fantasy minimap in Map settings.",
        "Switching minimap styles restores Forever terrain correctly, including rotation changes.",
        "Cleaner Guild & Communities panels, member rows and navigation tabs.",
        "Supported windows prepare their appearance before opening.",
        "New README and in-game previews, with support and bug reports on Discord.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
