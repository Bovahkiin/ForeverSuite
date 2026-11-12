local _,FS=...
local T=FS.Tools
local observationLimit=2000
local A=T:Module("AuctionHouse","auctionHouse","Auction House","Save prices from loaded auction results and keep a shopping list. Enter an item ID to add it. Purchases stay in the auction window.",{record=true,prices={},shopping={},shoppingOnly=false,hideSatisfied=false,showDates=true,countBank=true,sort="Name"},{"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","AUCTION_ITEM_LIST_UPDATE","AUCTION_HOUSE_BROWSE_RESULTS_UPDATED","AUCTION_HOUSE_BROWSE_RESULTS_ADDED","COMMODITY_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_UPDATED"})
A.options={{key="record",label="Record prices from loaded results"},{key="shoppingOnly",label="Shopping list only"},{key="hideSatisfied",label="Hide completed shopping goals"},{key="showDates",label="Show price observation date"},{key="countBank",label="Include bank stock in shopping goals"},{key="sort",label="Sort overview",values={"Name","Lowest price","Newest"}}}
function A:Scope() return (T:Call(GetRealmName) or "Realm")..":"..(T:Call(UnitFactionGroup,"player") or "Faction") end
function A:Prices()
    local all=self:Data().prices; local scope=self:Scope(); all[scope]=all[scope] or {}; return all[scope]
end
local function itemID(id)
    return T:Number(id) and id>0 and id<=100000000 and id%1==0
end
local function prune(prices)
    local count=0
    for _ in pairs(prices) do count=count+1 end
    if count>observationLimit then FS.Extensions:Trim(prices,observationLimit) end
end
function A:Normalize()
    local db=self:Data()
    for scope,prices in pairs(db.prices) do
        if type(scope)~="string" or type(prices)~="table" then
            db.prices[scope]=nil
        else
            for id,row in pairs(prices) do
                if not itemID(id) or type(row)~="table" or not T:Number(row.price) or row.price<=0
                    or (row.kind~="lowest listing" and row.kind~="per item") then prices[id]=nil
                elseif not T:Number(row.time) or row.time<0 then row.time=0 end
            end
            prune(prices)
        end
    end
    for id,count in pairs(db.shopping) do
        if not itemID(id) or not T:Number(count) or count<1 or count>100000 or count%1~=0 then db.shopping[id]=nil end
    end
end
local function remember(scan,id,price,kind,stamp)
    if not itemID(id) or not T:Number(price) or price<=0 then return end
    local row=scan[id]
    if not row then scan[id]={price=price,kind=kind,time=stamp}
    elseif price<row.price then row.price=price end
end
function A:StoreScan(scan)
    if not next(scan) then return end
    local prices=self:Prices()
    for id,row in pairs(scan) do prices[id]=row end
    prune(prices)
end
function A:Scan()
    if not self.open or not self:Data().record then return end
    local scan,API,stamp={},C_AuctionHouse,time and time() or 0
    if API and API.GetBrowseResults then
        for _,row in ipairs(T:Call(API.GetBrowseResults) or {}) do
            if type(row)=="table" and type(row.itemKey)=="table" then remember(scan,row.itemKey.itemID,row.minPrice,"lowest listing",stamp) end
        end
    elseif GetNumAuctionItems then
        for i=1,(T:Call(GetNumAuctionItems,"list") or 0) do
            local _,_,count,_,_,_,_,_,_,buyout=T:Call(GetAuctionItemInfo,"list",i)
            local link=T:Call(GetAuctionItemLink,"list",i); local id=FS.modules.Vendor:ItemID(link)
            if T:Number(count) and count>0 and T:Number(buyout) then remember(scan,id,buyout/count,"per item",stamp) end
        end
    end
    self:StoreScan(scan)
    self.status="Saved prices from the loaded page only. Browse more results in the auction window to record them."
end
function A:Event(event,key)
    if event=="AUCTION_HOUSE_SHOW" then self.open=true
    elseif event=="AUCTION_HOUSE_CLOSED" then self.open=false
    elseif not self.open or not self:Data().record then return
    elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" and C_AuctionHouse then
        local scan,stamp={},time and time() or 0
        for i=1,(T:Call(C_AuctionHouse.GetNumCommoditySearchResults,key) or 0) do
            local row=T:Call(C_AuctionHouse.GetCommoditySearchResultInfo,key,i)
            if type(row)=="table" then remember(scan,key,row.unitPrice,"per item",stamp) end
        end
        self:StoreScan(scan)
    elseif event=="ITEM_SEARCH_RESULTS_UPDATED" and C_AuctionHouse and type(key)=="table" then
        local scan,stamp={},time and time() or 0
        for i=1,(T:Call(C_AuctionHouse.GetNumItemSearchResults,key) or 0) do
            local row=T:Call(C_AuctionHouse.GetItemSearchResultInfo,key,i)
            if type(row)=="table" and T:Number(row.quantity) and row.quantity>0 and T:Number(row.buyoutAmount) then
                remember(scan,key.itemID,row.buyoutAmount/row.quantity,"per item",stamp)
            end
        end
        self:StoreScan(scan)
    else self:Scan() end
end
local function observedPrice(observation,showDate)
    if not observation then return "No observed price" end
    local stamp=""
    if showDate and observation.time and observation.time>0 then
        local formatted=T:Call(date,"%d %b %H:%M",observation.time)
        if formatted then stamp=" ("..formatted..")" end
    end
    return "Observed "..FS.modules.Vendor:Money(observation.price).." "..observation.kind..stamp
end
function A:ShoppingQuantity(id,target)
    local bank=self:Data().countBank
    local held=T:Call(C_Item and C_Item.GetItemCount,id,bank) or T:Call(GetItemCount,id,bank)
    if T:Number(held) and held>=0 then return held,math.max(0,target-held) end
end
function A:Build()
    self.rows={}; local prices=self:Prices(); local included={}; local db=self:Data()
    local itemInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
    for id,count in pairs(db.shopping) do
        local price=prices[id]; local name,link=T:Call(itemInfo,id); included[id]=true
        local held,missing=self:ShoppingQuantity(id,count)
        local known=held~=nil
        if not db.hideSatisfied or not known or count>held then
            local quantity=known and ("Have "..held.."/"..count.." | Need "..missing) or ("Stock unknown | Goal "..count)
            self.rows[#self.rows+1]={id=id,link=link,price=price and price.price or math.huge,time=price and price.time or 0,
                text="[Shopping] "..(name or "Item "..id).." | "..quantity.." | "..observedPrice(price,db.showDates)}
        end
    end
    for id,price in pairs(prices) do
        if not db.shoppingOnly and not included[id] then
            local name,link=T:Call(itemInfo,id)
            self.rows[#self.rows+1]={id=id,link=link,price=price.price,time=price.time,
                text=(name or "Item "..id).." | "..observedPrice(price,db.showDates)}
        end
    end
    table.sort(self.rows,function(a,b)
        if db.sort=="Lowest price" and a.price~=b.price then return a.price<b.price end
        if db.sort=="Newest" and a.time~=b.time then return a.time>b.time end
        return a.text<b.text
    end)
    self.status="Prices are past observations for "..self:Scope()..". Enter itemID quantity to add a goal, or select a row and click Find item."
end
function A:FindItem()
    local function unavailable(message)
        self.status=message
        return false
    end
    if InCombatLockdown() then return unavailable("Leave combat before searching the auction house.") end
    local selected=self.selected
    if not selected or not T:Number(selected.id) then return unavailable("Select an item first.") end
    local frame=AuctionHouseFrame
    if not self.open then return unavailable("Speak to an auctioneer and open the Buy tab first.") end
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or not frame:IsShown() then
        return unavailable("The game's auction search is unavailable here.")
    end
    local search=frame.SearchBar
    if not search or type(search.SetSearchText)~="function" or type(search.StartSearch)~="function" then
        return unavailable("This auction window does not expose the supported search controls.")
    end
    if not search:IsVisible() then return unavailable("Open the Buy tab before using Find item.") end
    local ready=C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady
    if ready and T:Call(ready)~=true then return unavailable("Auction House is busy. Try again in a moment.") end
    local name=T:Text(T:Call(C_Item and C_Item.GetItemInfo or GetItemInfo,selected.id))
    if name=="" then return unavailable("Item name is still loading. Try again in a moment.") end
    local ok=pcall(function()
        search:SetSearchText(name)
        search:StartSearch()
    end)
    if not ok then return unavailable("Search could not start. Use the Buy tab to search for "..name..".") end
    if self.window then self.window:Hide() end
    return true
end
A.actions={
    {label="Add",run=function(self,text) local id,count=text:match("^(%d+)%s*(%d*)$"); id,count=tonumber(id),tonumber(count) or 1; if itemID(id) and count>0 and count<=100000 then self:Data().shopping[id]=count end end},
    {label="Remove",run=function(self) if self.selected then self:Data().shopping[self.selected.id]=nil end end},
    {label="Scan",run=function(self) self:Scan() end},
    {label="Find item",run=function(self) self:FindItem() end},
}
