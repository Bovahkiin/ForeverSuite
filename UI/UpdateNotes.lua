local _,FS=...
FS.patchNotes={
    {version="1.0.10",lines={
        "Talent Advisor: choose a guide build, compare talents and plan your next point.",
        "73 guide variants cover all nine classes. Open All Tools or type /fs talents.",
        "Open Talent Advisor from the game Talents screen and follow highlighted planned talents.",
        "Edit builds, mark flexible choices and share build codes with your community.",
        "Link Gear Advisor's Auto scale or save a build profile with optional layout.",
        "Train all is now beside Train at class, pet and profession trainers.",
        "Review the total coin cost before training. Closing the trainer stops the batch.",
        "Nameplates now distinguish hostile (red), neutral (yellow) and friendly (green) NPCs.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
