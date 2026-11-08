local _,FS=...
local T=FS.Tools
local A=T:Module("AuctionHouse","auctionHouse","Auction House","Save prices from loaded auction results and keep a shopping list. Enter an item ID to add it. Purchases stay in the auction window.",{record=true,prices={},shopping={},shoppingOnly=false,hideSatisfied=false,showDates=true,countBank=true,sort="Name"},{"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","AUCTION_ITEM_LIST_UPDATE","AUCTION_HOUSE_BROWSE_RESULTS_UPDATED","AUCTION_HOUSE_BROWSE_RESULTS_ADDED","COMMODITY_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_UPDATED"})
A.options={{key="record",label="Record prices from loaded results"},{key="shoppingOnly",label="Shopping list only"},{key="hideSatisfied",label="Hide completed shopping goals"},{key="showDates",label="Show price observation date"},{key="countBank",label="Include bank stock in shopping goals"},{key="sort",label="Sort overview",values={"Name","Lowest price","Newest"}}}
function A:Scope() return (T:Call(GetRealmName) or "Realm")..":"..(T:Call(UnitFactionGroup,"player") or "Faction") end
function A:Prices()
    local all=self:Data().prices; local scope=self:Scope(); all[scope]=all[scope] or {}; return all[scope]
end
function A:Remember(id,price,kind)
    if not T:Number(id) or not T:Number(price) or price<=0 then return end
    local row=self.scan[id]; if not row or price<row.price then self.scan[id]={price=price,kind=kind,time=time and time() or 0} end
end
function A:Scan()
    if not self.open or not self:Data().record then return end
    self.scan={}; local API=C_AuctionHouse
    if API and API.GetBrowseResults then
        for _,row in ipairs(T:Call(API.GetBrowseResults) or {}) do if row.itemKey then self:Remember(row.itemKey.itemID,row.minPrice,"lowest listing") end end
    elseif GetNumAuctionItems then
        for i=1,(T:Call(GetNumAuctionItems,"list") or 0) do
            local _,_,count,_,_,_,_,_,_,buyout=T:Call(GetAuctionItemInfo,"list",i)
            local link=T:Call(GetAuctionItemLink,"list",i); local id=FS.modules.Vendor:ItemID(link)
            if T:Number(count) and count>0 and T:Number(buyout) then self:Remember(id,buyout/count,"per item") end
        end
    end
    for id,row in pairs(self.scan) do self:Prices()[id]=row end
    self.status="Saved prices from the loaded page only. Browse more results in the auction window to record them."
end
function A:Event(event,key)
    if event=="AUCTION_HOUSE_SHOW" then self.open=true
    elseif event=="AUCTION_HOUSE_CLOSED" then self.open=false
    elseif not self.open or not self:Data().record then return
    elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" and C_AuctionHouse then
        self.scan={}
        for i=1,(T:Call(C_AuctionHouse.GetNumCommoditySearchResults,key) or 0) do local r=T:Call(C_AuctionHouse.GetCommoditySearchResultInfo,key,i); if r then self:Remember(key,r.unitPrice,"per item") end end
        for id,row in pairs(self.scan) do self:Prices()[id]=row end
    elseif event=="ITEM_SEARCH_RESULTS_UPDATED" and C_AuctionHouse and type(key)=="table" then
        self.scan={}
        for i=1,(T:Call(C_AuctionHouse.GetNumItemSearchResults,key) or 0) do local r=T:Call(C_AuctionHouse.GetItemSearchResultInfo,key,i); if r and T:Number(r.quantity) and r.quantity>0 and T:Number(r.buyoutAmount) then self:Remember(key.itemID,r.buyoutAmount/r.quantity,"per item") end end
        for id,row in pairs(self.scan) do self:Prices()[id]=row end
    else self:Scan() end
end
function A:Build()
    self.rows={}; local prices=self:Prices(); local included={}
    for id,count in pairs(self:Data().shopping) do
        local price=prices[id]; local name,link=T:Call(C_Item.GetItemInfo,id); included[id]=true
        local held=T:Call(C_Item.GetItemCount,id,self:Data().countBank) or T:Call(GetItemCount,id,self:Data().countBank) or 0
        if not self:Data().hideSatisfied or count>held then self.rows[#self.rows+1]={id=id,link=link,price=price and price.price or math.huge,time=price and price.time or 0,text="[Shopping] "..(name or "Item "..id).." | Need "..math.max(0,count-held).." | "..(price and FS.modules.Vendor:Money(price.price).." "..price.kind or "No saved price")} end
    end
    for id,price in pairs(prices) do if not self:Data().shoppingOnly and not included[id] then local name,link=T:Call(C_Item.GetItemInfo,id); self.rows[#self.rows+1]={id=id,link=link,price=price.price,time=price.time,text=(name or "Item "..id).." | "..FS.modules.Vendor:Money(price.price).." "..price.kind..(self:Data().showDates and (" | "..(date and date("%d %b %H:%M",price.time) or tostring(price.time))) or "")} end end
    table.sort(self.rows,function(a,b)
        if self:Data().sort=="Lowest price" and a.price~=b.price then return a.price<b.price end
        if self:Data().sort=="Newest" and a.time~=b.time then return a.time>b.time end
        return a.text<b.text
    end)
    self.status="Saved prices belong to "..self:Scope()..". Prices are past observations, not live guarantees. Enter: itemID quantity."
end
A.actions={{label="Add",run=function(self,text) local id,count=text:match("^(%d+)%s*(%d*)$"); id,count=tonumber(id),tonumber(count) or 1; if id and id>0 and count>0 and count<=100000 then self:Data().shopping[id]=count end end},{label="Remove",run=function(self) if self.selected then self:Data().shopping[self.selected.id]=nil end end},{label="Scan",run=function(self) self:Scan() end}}
