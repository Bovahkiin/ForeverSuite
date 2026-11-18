local _,FS=...
FS.patchNotes={
    {version="1.0.7",lines={
        "Improved Installer with a four-step setup.",
        "Improved Action Bars with mouseover, opacity and quick keybind mode.",
        "New right-click Minimap Button Options.",
        "New Layout Presets for compact screens, PvP, questing and immersion.",
        "Pin shortcuts from All Tools and switch between Settings, Modules and Profiles.",
        "Start the ForeverSuite Tour on first login or go straight to Guided Setup.",
        "Compact tool windows, clear empty states and tool-specific settings.",
        "Less background styling, font scanning and quest tracker layout work.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
