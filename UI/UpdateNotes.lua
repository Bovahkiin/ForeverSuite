local _,FS=...
FS.patchNotes={
    {version="1.0.12",lines={
        "Screen tools: open related actions directly from Character, crafting, map, guild and other game windows.",
        "Attached tools keep their source window open and use compact five-row lists.",
        "Middle-click an equipment slot for its Gear Planner; use item planning menus in bags and bank.",
        "Crafting tools use the selected recipe and the shared Auction House shopping list.",
        "Right-click a quest heading for navigation tools or the addon tray button to manage icons.",
        "Spellbook tools can track the spell you last hovered without entering a spell ID.",
        "Clear Bag tools and Chat tools menus; Talent Advisor sits beside ForeverSuite in the title bar.",
        "Guild opens without a delayed fade and keeps its position when switching tabs. Member tools sits below it.",
        "Map shortcuts sit below the window, or at the bottom left on a maximized map.",
        "Continuous themed backgrounds replace black insets. Professions has one page background with a watermark.",
        "Fixes the self-anchor error when saving a directly dragged tool window.",
    }},
}
function FS:ShowUpdateNotesOnLogin()
    local seen=self.db.patchLog
    if not seen.showOnLoad or seen.lastSeenVersion==self.version then return false end
    if not self:ShowPatchLog(false,true) then return false end
    seen.lastSeenVersion=self.version
    return true
end
