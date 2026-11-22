local _,FS=...
FS.patchNotes={
    {version="1.0.11",lines={
        "Alt Tracker: see your characters, levels, gear, professions and recorded bags in one place.",
        "Search by name, realm or class, sort your alts and record the current character.",
        "Open Alt Tracker from All Tools; your existing Character stock pins still work.",
        "Auction House: use Scan all at an auctioneer to save buyout prices for item tooltips.",
        "Enchanters can see an approximate disenchant material-value range using scanned prices.",
        "A gold ! on nameplates marks needed quest enemies and item droppers reported by the game.",
        "Toggle quest markers in Nameplates > Open nameplate designer > Text.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
