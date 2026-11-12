local _,FS=...
local T=FS.Tools
local L=T:Module("Loot","loot","Loot","Customize loot history, filters and the roll helper. Display filters never change what you pick up; Need, Greed and Pass stay manual.",
    {fast=false,styleWindow=true,recordHistory=true,history={},historyLimit=100,historySource="Everyone",showHistory=true,historyQuality="All",showTime=false,newestFirst=true,showRolls=true,rollSort="Ending soon",showRollCount=true,showRollTime=true,autoOpenRolls=false},
    {"LOOT_OPENED","CHAT_MSG_LOOT","START_LOOT_ROLL","CANCEL_LOOT_ROLL","GET_ITEM_INFO_RECEIVED"})
L.options={{key="fast",label="Fast loot"},{key="styleWindow",label="Style loot window"},
    {key="recordHistory",label="Record loot history"},{key="historyLimit",label="History limit",values={25,50,100,200,500}},
    {key="historySource",label="Record loot from",values={"Everyone","You"}},{key="showHistory",label="Show loot history"},
    {key="historyQuality",label="History quality",values={"All","Common+","Uncommon+","Rare+","Epic+"}},{key="showTime",label="History timestamps"},
    {key="newestFirst",label="Newest history first"},{key="showRolls",label="Show active rolls"},
    {key="rollSort",label="Sort active rolls",values={"Ending soon","Name"}},{key="showRollCount",label="Roll item quantities"},
    {key="showRollTime",label="Roll time remaining"},{key="autoOpenRolls",label="Open helper for new rolls"}}
L.rolls={}; L.qualities={All=-1,["Common+"]=1,["Uncommon+"]=2,["Rare+"]=3,["Epic+"]=4}
local ownLootFormats={"LOOT_ITEM_SELF","LOOT_ITEM_SELF_MULTIPLE","LOOT_ITEM_PUSHED_SELF","LOOT_ITEM_PUSHED_SELF_MULTIPLE","LOOT_ITEM_CREATED_SELF","LOOT_ITEM_CREATED_SELF_MULTIPLE"}
function L:Normalize()
    local history=self:Data().history
    for i=#history,1,-1 do if type(history[i])~="table" or T:Text(history[i].text)=="" then table.remove(history,i) end end
    while #history>self:Data().historyLimit do table.remove(history) end
end
function L:OwnMessage(message,includeCrafted)
    for _,key in ipairs(ownLootFormats) do
        local format=T:Text(_G[key]); local prefix=format:match("^(.-)%%")
        if prefix and #prefix>0 and message:sub(1,#prefix)==prefix then
            return includeCrafted~=false or not key:find("CREATED",1,true)
        end
    end
    return message:find("^You receive ")~=nil or (includeCrafted~=false and message:find("^You create ")~=nil)
end
function L:ForgetRoll(id)
    self.rolls[id]=nil; if self.selected and self.selected.roll==id then self.selected=nil end
end
function L:ExpireRolls(now)
    for id,roll in pairs(self.rolls) do
        if now>=roll.expires then self:ForgetRoll(id) end
    end
end
function L:Event(event,a,b)
    if event=="CHAT_MSG_LOOT" then
        local data=self:Data(); if not data.recordHistory or T:Text(a)=="" or data.historySource=="You" and not self:OwnMessage(a) then return end
        local history=data.history; table.insert(history,1,{text=a,time=T:Call(time) or 0,link=a:match("(|Hitem:.-|h.-|h)")})
        while #history>data.historyLimit do table.remove(history) end
    elseif event=="LOOT_OPENED" and self:Data().fast and not InCombatLockdown() and not (IsShiftKeyDown and IsShiftKeyDown()) then
        for i=(T:Call(GetNumLootItems) or 0),1,-1 do T:Call(LootSlot,i) end
    elseif event=="START_LOOT_ROLL" and T:Number(a) then
        local now=GetTime()
        self:ExpireRolls(now)
        self.rolls[a]={id=a,expires=now+(T:Number(b) and b>0 and b/1000 or 60)}
        if self:Data().showRolls and self:Data().autoOpenRolls and not InCombatLockdown() then self:ShowWindow() end
    elseif event=="CANCEL_LOOT_ROLL" and T:Number(a) then self:ForgetRoll(a) end
end
function L:Build()
    self.rows={}; local data=self:Data(); local active=self.rows; local pending=false
    local now=GetTime()
    self:ExpireRolls(now)
    if not data.showRolls and self.selected and self.selected.roll then self.selected=nil end
    if data.showRolls then
        for id,roll in pairs(self.rolls) do
            local _,name,count,quality,_,need,greed=T:Call(GetLootRollItemInfo,id)
            if T:Text(name)~="" then
                local text="[Roll] "..name
                if data.showRollCount then text=text.." x"..(T:Number(count) and count or 1) end
                if data.showRollTime then text=text.." - "..math.ceil(roll.expires-now).."s" end
                active[#active+1]={roll=id,name=name,expires=roll.expires,need=need,greed=greed,link=T:Call(GetLootRollItemLink,id),text=text}
            end
        end
        table.sort(active,function(a,b)
            if data.rollSort=="Name" then
                local an,bn=a.name:lower(),b.name:lower()
                if an~=bn then return an<bn end
            end
            if a.expires~=b.expires then return a.expires<b.expires end
            return a.roll<b.roll
        end)
    end
    if data.showHistory then
        local history=data.history; local minimum=self.qualities[data.historyQuality]
        for i=1,#history do
            local row=history[data.newestFirst and i or #history-i+1]; local quality
            if minimum>=0 and T:Text(row.link)~="" then local _,_,q=T:Call(GetItemInfo,row.link); quality=T:Number(q) and q or nil end
            if minimum<0 or quality==nil or quality>=minimum then
                local text=row.text
                if data.showTime and T:Number(row.time) and row.time>0 then local stamp=T:Call(date,"%H:%M",row.time); if T:Text(stamp)~="" then text="["..stamp.."] "..text end end
                self.rows[#self.rows+1]={text=text,link=row.link,time=row.time,history=true}
                if minimum>=0 and quality==nil and row.link then pending=true end
            end
        end
    end
    self.status=pending and "Uncached items stay visible until their quality is available. Display filters never change pickup." or "Select a roll and choose Need, Greed or Pass. Fast loot pauses with Shift or in combat; binding confirmations remain."
    if #self.rows==0 then self.status="No loot entries match your display settings. Open Loot settings to change the history or roll view." end
end
function L:Roll(choice)
    local row=self.selected; if not row or not row.roll or not self.rolls[row.roll] then self.status="Select an active loot roll first."; return end
    if GetTime()>=self.rolls[row.roll].expires then return end
    local _,_,_,_,_,need,greed=T:Call(GetLootRollItemInfo,row.roll)
    if choice==1 and not need or choice==2 and not greed then self.status="That roll choice is not available for this item."; return end
    if type(RollOnLoot)~="function" then self.status="Loot rolling is unavailable in this client."; return end
    local ok,accepted=pcall(RollOnLoot,row.roll,choice)
    if ok and accepted~=false then self:ForgetRoll(row.roll) else self.status="The game did not accept this roll. You can still use its loot roll window." end
end
local createSettings=L.CreateSettings
function L:CreateSettings(host)
    local f=createSettings(self,host)
    f.clear=FS.HUD:Button(f,"Clear history",740,-12,132,function()
        if not self.clearUntil or GetTime()>self.clearUntil then self.clearUntil=GetTime()+5; f.clear:SetText("Confirm clear"); return end
        self:Data().history={}; self.clearUntil=nil; f.clear:SetText("Clear history")
        if self.selected and not self.selected.roll then self.selected=nil end; self:Refresh()
    end)
    f:HookScript("OnShow",function() self.clearUntil=nil; f.clear:SetText("Clear history") end)
    return f
end
L.actions={{label="Need",run=function(self) self:Roll(1) end},{label="Greed",run=function(self) self:Roll(2) end},{label="Pass",run=function(self) self:Roll(0) end}}
