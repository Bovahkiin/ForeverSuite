local _,FS=...
FS.patchNotes={
    {version="1.0.9",lines={
        "DataHub keeps character records separate from your UI profiles.",
        "Existing Character stock records are imported once; the original data is preserved.",
        "Character identity and level update at login, level-up and logout.",
        "Versioned upgrades and backups protect your saved settings and character records.",
        "Newer or failed data formats are preserved, and unsafe profile loads are blocked.",
        "Module enable states and settings initialization are more consistent.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
