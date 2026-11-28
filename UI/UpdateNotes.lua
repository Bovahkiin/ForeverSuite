local _,FS=...
FS.patchNotes={
    {version="1.0.15",lines={
        "Choose from five Bags and Bank layouts in Guided Setup or the inventory toolbar. Satchels is the default.",
        "Your theme now colors both minimap shapes, shared window borders and the XP bar. The XP bar lights up on gains and pulses on level-up.",
        "The ForeverSuite launcher has its own space beside or above vendor and trainer windows.",
        "Control Center has smaller pinned cards. Hover an Open button to see what the tool does.",
        "Continue playing shows shortcuts to your waypoint queue, selected talent build and shopping goals.",
        "Use /fs perf Busy city to capture CPU, memory and FPS. Use /fs perf to review your measurements.",
        "The Inbox has one Mail tools menu and readable tabs.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
