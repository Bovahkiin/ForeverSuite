local _,FS=...
local T=FS.Tools
local F=T:Module("LootFeed","lootFeed","Loot Feed",
    "Your loot, money, currencies, reputation and skill-ups in a compact ForeverSuite feed. Hover for details. Drag its header or use Move Frames to position it.",
    {items=true,money=true,currencies=true,reputation=true,skills=true,crafted=true,hideChat=false,
     quality="All",owned=true,prices="Automatic",duration=6,visible=5,width=360,textSize=13,
     growth="Down",interactive=true,showInCombat=true,merge=true,masque=false},
    {"CHAT_MSG_LOOT","CHAT_MSG_MONEY","CHAT_MSG_CURRENCY","CHAT_MSG_COMBAT_FACTION_CHANGE","CHAT_MSG_SKILL",
     "GET_ITEM_INFO_RECEIVED","BAG_UPDATE_DELAYED","CURRENCY_DISPLAY_UPDATE","UPDATE_FACTION",
     "SKILL_LINES_CHANGED","PLAYER_REGEN_DISABLED","ADDON_LOADED","PLAYER_ENTERING_WORLD","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"})
F.options={
    {key="items",label="Items"},{key="money",label="Money looted"},
    {key="currencies",label="Currencies"},{key="reputation",label="Reputation gains"},{key="skills",label="Profession skill-ups"},
    {key="crafted",label="Include crafted items"},
    {key="hideChat",label="Hide matching chat messages",help="Only hides recognized messages that this feed can display. Party loot, unknown messages, filtered qualities and overflow remain in chat. Other chat settings stay unchanged."},
    {key="quality",label="Minimum item quality",values={"All","Common+","Uncommon+","Rare+","Epic+"}},
    {key="owned",label="Show character item count"},
    {key="prices",label="Item value",values={"Automatic","ForeverSuite AH","Auctionator","TSM market","Vendor","None"},help="Automatic tries cached ForeverSuite unit prices, Auctionator, TSM DBMarket, then vendor value. Values are labeled estimates, not guaranteed sale prices. Never starts a scan."},
    {key="duration",label="Display duration",values={4,6,8,12},format=function(v) return v.."s" end},
    {key="visible",label="Visible entries",values={3,5,7}},
    {key="width",label="Feed width",values={300,360,420}},
    {key="textSize",label="Text size",values={11,13,15,17}},
    {key="growth",label="Stack direction",values={"Down","Up"}},
    {key="interactive",label="Hover details and item links"},
    {key="showInCombat",label="Show in combat"},
    {key="merge",label="Combine repeated gains"},
    {key="masque",label="Use Masque for item icons",help="Optional. Only the item icons use Masque; the feed keeps ForeverSuite's frame, colors and typography."},
}
F.settingsHint="Use Preview feed to try it. No idle background updates. Feed history is limited to this session; the existing Loot module keeps its own history."
F.openLabel="Preview feed"; F.settingsAction=function(self) self:Preview() end
F.entries={}; F.queue={}; F.history={}; F.pending={}
F.limits={queue=40,history=60,pending=20,rows=7}
function F:Ready()
    return FS.initialized and FS.db and FS:IsModuleEnabled(self.name)
        and (self:Data().showInCombat or not InCombatLockdown())
end
function F:Clear()
    for _,row in ipairs(self.pool or {}) do if row.entry then row.entry.row=nil end; row.entry=nil; row.hovered=nil; row:Hide() end
    self.entries={}; self.queue={}; self.pending={}
    if self.feed then self.feed:SetScript("OnUpdate",nil); self.feed:Hide() end
    self.hovered=nil; self.previewing=nil; self.elapsed=0
end
function F:StopCapture() self:Clear(); self:ChatFilters(false) end
function F:Apply()
    self:ChatFilters(self:Data().hideChat)
    if not self:Ready() then self:Clear(); return end
    -- Changing filters or profiles must not leave old categories hidden in chat.
    self:Clear()
    self.factions=nil; self.skillInfo=nil
    if self.feed then self:LayoutFeed(); self:SkinIcons() end
end
function F:Event(event,...)
    if event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED" then
        if self.feed then self:LayoutFeed(); FS.Layout:Apply("LootFeed") end
    elseif event=="ADDON_LOADED" then
        self:ChatFilters(self:Data().hideChat)
        if self.feed then self:SkinIcons() end
    elseif event=="PLAYER_REGEN_DISABLED" and not self:Data().showInCombat then self:Clear()
    elseif event=="PLAYER_ENTERING_WORLD" then self.factions=nil; self.skillInfo=nil; self.pending={}
    elseif event=="UPDATE_FACTION" then self.factions=nil; self:RefreshContext("reputation")
    elseif event=="SKILL_LINES_CHANGED" then self.skillInfo=nil; self:RefreshContext("skill")
    elseif event=="BAG_UPDATE_DELAYED" then self:RefreshContext("item")
    elseif event=="CURRENCY_DISPLAY_UPDATE" then self:RefreshContext("currency")
    elseif event=="GET_ITEM_INFO_RECEIVED" then self:LoadedItem(...)
    elseif event:sub(1,9)=="CHAT_MSG_" and self:Ready() then
        local message=...
        local entry=self:Parse(event,message)
        if entry then self:Receive(entry) end
    end
end
function F:Build()
    self.rows={}
    for _,entry in ipairs(self.history) do
        self.rows[#self.rows+1]={text=entry.name.." | "..self:Amount(entry)..(entry.detail~="" and " | "..entry.detail or ""),link=entry.link}
    end
    self.status="This session only. Hover the feed for details; right-click an entry to dismiss it."
end
F.actions={{label="Preview feed",run=function(self) self:Preview() end},
    {label="Clear feed",run=function(self) self:Clear() end},
    {label="Feed settings",run=function() FS.Beginner:ShowModule("LootFeed") end}}
