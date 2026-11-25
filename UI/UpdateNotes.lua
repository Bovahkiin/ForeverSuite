local _,FS=...
FS.patchNotes={
    {version="1.0.14",lines={
        "Loot Feed: items, money, currencies, reputation and skill-ups in your ForeverSuite theme.",
        "Type /fs lootfeed to preview; drag the header or use Move Frames to position it.",
        "Open History or Settings from the feed header. Matching chat messages can optionally be hidden.",
        "Choose item counts, value providers, quality, duration, size and stacking direction.",
        "The feed stops updating when empty and keeps only a bounded session history.",
        "The vendor ForeverSuite button now sits outside the merchant window's clipped content.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
