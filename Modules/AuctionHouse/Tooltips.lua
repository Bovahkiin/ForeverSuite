local _,FS=...
local A,T=FS.modules.AuctionHouse,FS.Tools
-- Compact material families, independently authored from the cited guides.
-- Values are a possible-outcome RANGE, never an assumed drop-rate average.
local families={
    {15,10940,1,2,10938,1,2},
    {20,10940,2,3,10939,1,2,10978},
    {25,10940,4,6,10998,1,2,10978},
    {30,11083,1,2,11082,1,2,11084},
    {35,11083,2,5,11134,1,2,11138},
    {40,11137,1,2,11135,1,2,11139},
    {45,11137,2,5,11174,1,2,11177},
    {50,11176,1,2,11175,1,2,11178},
    {55,11176,2,5,16202,1,2,14343},
    {60,16204,1,2,16203,1,2,14344},
    {99,16204,2,5,16203,2,2,14344},
}
function A:IsEnchanter()
    if self.enchanter~=nil then return self.enchanter end
    local profession=Enum and Enum.Profession and Enum.Profession.Enchanting
    local id=profession and T:Call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionSkillLineID,profession)
    local skill=id and T:Call(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,id)
    if type(skill)=="table" and T:Number(skill.rank) then self.enchanter=skill.rank>0; return self.enchanter end
    if GetProfessions and GetProfessionInfo then
        for _,index in pairs({T:Call(GetProfessions)}) do
            if T:Number(index) then
                local _,_,rank,_,_,_,line=T:Call(GetProfessionInfo,index)
                if line==333 and T:Number(rank) and rank>0 then self.enchanter=true; return true end
            end
        end
    end
    self.enchanter=false; return false
end
function A:DisenchantValue(link,prices)
    local _,_,quality,level,_,_,_,_,equip,_,_,class,subclass,bind=T:Call(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
    if quality~=2 and quality~=3 then return end
    if (class~=2 and class~=4) or bind==4 or class==2 and subclass==20 or T:Text(equip)=="" then return end
    local actual=T:Call(C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo,link)
    if T:Number(actual) and actual>0 then level=actual end
    if not T:Number(level) or level<5 or level>99 then return nil,nil,"No material estimate for this item level" end
    local raw=T:Call(C_TooltipInfo and C_TooltipInfo.GetHyperlink,link)
    if type(raw)=="table" and type(raw.lines)=="table" then
        for _,line in ipairs(raw.lines) do
            local text=T:Text(line.leftText):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            if text==ITEM_DISENCHANT_NOT_DISENCHANTABLE or text:lower():find("cannot be disenchanted",1,true) then return end
        end
    end
    local family
    for _,row in ipairs(families) do if level<=row[1] then family=row; break end end
    local outputs
    if quality==2 then
        outputs={{family[2],family[3],family[4]},{family[5],family[6],family[7]}}
        if family[8] then outputs[#outputs+1]={family[8],1,1} end
    else
        local shard=level<=25 and 10978 or family[8]
        outputs={{shard,1,1}}
        if level>=56 then outputs[#outputs+1]={20725,1,1} end
    end
    local low,high,oldest=math.huge,0,math.huge
    for _,output in ipairs(outputs) do
        local row=prices[output[1]]
        if not row or row.kind~="per item" or not T:Number(row.price) or row.price<=0 then return nil,nil,"Scan missing enchanting material prices" end
        low=math.min(low,row.price*output[2]); high=math.max(high,row.price*output[3]); oldest=math.min(oldest,row.time or 0)
    end
    return low,high,nil,oldest
end
function A:PriceAge(stamp)
    if not T:Number(stamp) or stamp<=0 then return "date unknown" end
    local seconds=math.max(0,(time and time() or stamp)-stamp)
    if seconds<60 then return "just now" end
    if seconds<3600 then return math.floor(seconds/60).."m ago" end
    if seconds<86400 then return math.floor(seconds/3600).."h ago" end
    return math.floor(seconds/86400).."d ago"
end
function A:PriceTooltip(tooltip)
    if not FS:IsModuleEnabled(self.name) or not tooltip or not tooltip.GetItem
        or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local _,link=T:Call(tooltip.GetItem,tooltip)
    if type(link)~="string" or tooltip.fsAuctionLink==link then return end
    local db=self:Data()
    if not db.tooltips and not db.disenchant then return end
    if not tooltip.fsAuctionHook then
        tooltip.fsAuctionHook=true
        tooltip:HookScript("OnTooltipCleared",function(t) t.fsAuctionLink=nil end)
    end
    local id=FS.modules.Vendor:ItemID(link); if not id then return end
    local prices=self:Prices(); local row=prices[id]; local added=false
    if db.tooltips and row then
        tooltip:AddLine("AH "..(row.kind=="per item" and "per item: " or "lowest listing: ")..FS.modules.Vendor:Money(row.price),1,.82,0)
        tooltip:AddLine("Last observed "..self:PriceAge(row.time).." | "..self:Scope(),.65,.7,.75,true); added=true
    end
    if db.disenchant and self:IsEnchanter() then
        local low,high,reason,stamp=self:DisenchantValue(link,prices)
        if low then
            local value=FS.modules.Vendor:Money(low)..(high~=low and " - "..FS.modules.Vendor:Money(high) or "")
            tooltip:AddLine("Disenchant estimate: "..value,.55,.85,1)
            tooltip:AddLine("Approximate range; special items may differ. Before AH fees.",.65,.7,.75,true)
            tooltip:AddLine("Oldest material price: "..self:PriceAge(stamp),.65,.7,.75,true); added=true
        elseif reason then tooltip:AddLine("Disenchant: "..reason,.65,.7,.75,true); added=true end
    end
    if added then tooltip.fsAuctionLink=link end
end
function A:InstallPriceTooltips()
    if self.priceTooltipsInstalled then return end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(t) self:PriceTooltip(t) end)
    elseif GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem",function(t) self:PriceTooltip(t) end)
        if ItemRefTooltip and ItemRefTooltip:HasScript("OnTooltipSetItem") then ItemRefTooltip:HookScript("OnTooltipSetItem",function(t) self:PriceTooltip(t) end) end
    else return end
    self.priceTooltipsInstalled=true
end
