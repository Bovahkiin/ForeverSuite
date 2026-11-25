local _,FS=...
local F,T=FS.modules.LootFeed,FS.Tools
local function number(value) if T:Number(value) then return value end end
local function nonnegative(value) return T:Number(value) and value>=0 and value or nil end
local function validPrice(value) return T:Number(value) and value>0 and value<100000000000 and value or nil end
function F:ItemValue(entry)
    local source=self:Data().prices
    if source=="None" then return end
    if source=="Automatic" or source=="ForeverSuite AH" then
        local A=FS.modules.AuctionHouse
        local row=FS:IsModuleEnabled("AuctionHouse") and A:Prices()[entry.id]
        if row and row.kind=="per item" and validPrice(row.price) then return row.price,"AH",A:PriceAge(row.time) end
        if source~="Automatic" then return end
    end
    if source=="Automatic" or source=="Auctionator" then
        local api=Auctionator and Auctionator.API and Auctionator.API.v1
        local price=validPrice(T:Call(api and api.GetAuctionPriceByItemID,"ForeverSuite",entry.id))
        if price then return price,"Auctionator","cached unit estimate" end
        if source~="Automatic" then return end
    end
    if source=="Automatic" or source=="TSM market" then
        local item=T:Call(TSM_API and TSM_API.ToItemString,entry.link)
        local price=T:Text(item)~="" and validPrice(T:Call(TSM_API and TSM_API.GetCustomPriceValue,"DBMarket",item))
        if price then return price,"TSM market","DBMarket unit estimate" end
        if source~="Automatic" then return end
    end
    if source=="Automatic" or source=="Vendor" then
        local price=validPrice(select(11,T:Call(C_Item and C_Item.GetItemInfo or GetItemInfo,entry.link)))
        if price then return price,"Vendor","unit sell value" end
    end
end
function F:Faction(name)
    local api=C_Reputation
    if not self.factions then
        self.factions={}
        local count=T:Call(api and api.GetNumFactions or GetNumFactions)
        if T:Number(count) then for i=1,math.min(count,500) do
            local data=T:Call(api and api.GetFactionDataByIndex,i)
            if type(data)~="table" then
                local label,_,reaction,low,high,current,_,_,header,_,hasRep,_,_,id=T:Call(GetFactionInfo,i)
                if T:Text(label)~="" and (not header or hasRep) then data={name=label,reaction=reaction,currentReactionThreshold=low,nextReactionThreshold=high,currentStanding=current,factionID=id} end
            end
            if type(data)=="table" and T:Text(data.name)~="" then self.factions[data.name]=data end
        end end
    end
    local data=self.factions[name]
    if not data then return end
    local id=number(data.factionID)
    return id and T:Call(api and api.GetFactionDataByID,id) or data
end
function F:Skill(name)
    if not self.skillInfo then
        self.skillInfo={}
        if GetProfessions and GetProfessionInfo then
            for _,index in pairs({T:Call(GetProfessions)}) do if T:Number(index) then
                local label,icon,rank,maximum=T:Call(GetProfessionInfo,index)
                if T:Text(label)~="" then self.skillInfo[label]={rank=rank,maximum=maximum,icon=icon} end
            end end
        end
        local count=T:Call(GetNumSkillLines)
        if T:Number(count) then for i=1,math.min(count,256) do
            local label,header,_,rank,_,_,maximum=T:Call(GetSkillLineInfo,i)
            if T:Text(label)~="" and not header and not self.skillInfo[label] then self.skillInfo[label]={rank=rank,maximum=maximum} end
        end end
    end
    return self.skillInfo[name]
end
function F:Context(entry,prices)
    local detail={}; entry.progress=nil; entry.maximum=nil
    if entry.kind=="item" then
        local name,_,quality,_,_,_,_,_,_,icon=T:Call(C_Item and C_Item.GetItemInfo or GetItemInfo,entry.link)
        if T:Text(name)~="" then entry.name=name end
        entry.quality=number(quality); entry.icon=number(icon) or (T:Text(icon)~="" and icon) or entry.icon
        if self:Data().owned then
            local count=T:Call(C_Item and C_Item.GetItemCount or GetItemCount,entry.id,false,false,false)
            if nonnegative(count) then entry.owned=count; detail[#detail+1]="Owned "..count end
        else entry.owned=nil end
        if prices then entry.price,entry.provider,entry.priceNote=self:ItemValue(entry) end
        if entry.price then
            local total=entry.price*entry.quantity
            detail[#detail+1]=entry.provider.." "..(total<=100000000000 and FS.modules.Vendor:Money(total) or "total unavailable")
        end
    elseif entry.kind=="currency" then
        entry.current=nil; entry.weekly=nil; entry.weeklyMax=nil
        local data=T:Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,entry.id)
        if type(data)~="table" and GetCurrencyInfo then
            local name,quantity,icon,_,_,maximum=T:Call(GetCurrencyInfo,entry.id)
            data={name=name,quantity=quantity,iconFileID=icon,maxQuantity=maximum}
        end
        if type(data)=="table" then
            if T:Text(data.name)~="" then entry.name=data.name end
            entry.icon=number(data.iconFileID); entry.current=nonnegative(data.quantity)
            local maximum=number(data.maxQuantity)
            entry.weekly=nonnegative(data.quantityEarnedThisWeek); entry.weeklyMax=nonnegative(data.maxWeeklyQuantity)
            if entry.current then
                detail[#detail+1]=maximum and maximum>0 and entry.current.." / "..maximum or "Total "..entry.current
                if maximum and maximum>0 then entry.progress=entry.current; entry.maximum=maximum end
            end
        end
    elseif entry.kind=="reputation" then
        local data=self:Faction(entry.name)
        if type(data)=="table" then
            local low,high,current=number(data.currentReactionThreshold),number(data.nextReactionThreshold),number(data.currentStanding)
            local reaction=number(data.reaction)
            entry.standing=reaction and T:Text(_G["FACTION_STANDING_LABEL"..reaction]) or ""
            if entry.standing~="" then detail[#detail+1]=entry.standing end
            if low and high and current and high>low then
                entry.progress=math.max(0,current-low); entry.maximum=high-low
                detail[#detail+1]=entry.progress.." / "..entry.maximum
            end
        end
    elseif entry.kind=="skill" then
        local data=self:Skill(entry.name); local maximum=data and number(data.maximum)
        entry.icon=data and number(data.icon)
        detail[#detail+1]="Skill increased"
        if maximum and maximum>0 then entry.progress=entry.rank; entry.maximum=maximum; detail[#detail+1]=entry.rank.." / "..maximum end
    elseif entry.kind=="money" then
        local total=T:Call(GetMoney)
        if nonnegative(total) then detail[#detail+1]="Total "..FS.modules.Vendor:Money(total) end
    end
    entry.detail=table.concat(detail,"  |  ")
end
function F:RefreshContext(kind)
    if not self:Ready() then return end
    for _,entry in ipairs(self.entries) do if entry.kind==kind then self:Context(entry); self:Paint(entry) end end
end
function F:LoadedItem(id,success)
    if not T:Number(id) or not self:Ready() then return end
    for i=#self.pending,1,-1 do
        local entry=self.pending[i]
        if entry.id==id or GetTime()-entry.received>5 then
            table.remove(self.pending,i)
            if entry.id==id and success~=false and GetTime()-entry.received<=5 and self:Eligible(entry)==true then self:Receive(entry) end
        end
    end
    if success~=false then
        for _,entry in ipairs(self.entries) do if entry.kind=="item" and entry.id==id then self:Context(entry,true); self:Paint(entry) end end
    end
end
function F:Amount(entry)
    if entry.kind=="skill" then return "Rank "..entry.rank end
    if entry.kind=="money" then return "+"..FS.modules.Vendor:Money(entry.quantity) end
    return (entry.kind=="item" and "x" or "+")..entry.quantity
end
function F:Tooltip(row)
    local entry=row.entry; if not entry then return end
    GameTooltip:SetOwner(row,"ANCHOR_LEFT")
    if entry.link then T:Call(GameTooltip.SetHyperlink,GameTooltip,entry.link)
    else GameTooltip:AddLine(entry.name,1,1,1) end
    GameTooltip:AddLine(self:Amount(entry),.9,.85,.6)
    if entry.detail~="" then GameTooltip:AddLine(entry.detail,.75,.85,.9,true) end
    if entry.price then
        GameTooltip:AddLine(entry.provider.." per item: "..FS.modules.Vendor:Money(entry.price),.9,.8,.5)
        GameTooltip:AddLine((entry.priceNote or "Estimate")..". Before auction fees; sale value may differ.",.65,.7,.75,true)
    end
    if entry.weekly and entry.weeklyMax and entry.weeklyMax>0 then GameTooltip:AddLine("Weekly: "..entry.weekly.." / "..entry.weeklyMax,.75,.85,.9) end
    if entry.message then GameTooltip:AddLine(entry.message,.6,.65,.7,true) end
    GameTooltip:AddLine("Right-click to dismiss. Drag the header to move.",.5,.65,.7,true); GameTooltip:Show()
end
