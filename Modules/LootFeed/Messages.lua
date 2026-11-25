local _,FS=...
local F,T=FS.modules.LootFeed,FS.Tools
local cache={}
local function literal(value) return (value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")) end
-- Match client-localized format strings, including positional arguments.
local function pattern(format)
    if cache[format] then return cache[format][1],cache[format][2] end
    local out,args,at,nextIndex={}, {},1,1
    while at<=#format do
        local first,last,slot,kind=format:find("%%(%d+)%$([sd])",at)
        local plainFirst,plainLast,plainKind=format:find("%%([sd])",at)
        if plainFirst and (not first or plainFirst<first) then first,last,slot,kind=plainFirst,plainLast,nextIndex,plainKind; nextIndex=nextIndex+1 end
        if not first then out[#out+1]=literal(format:sub(at)); break end
        out[#out+1]=literal(format:sub(at,first-1)); out[#out+1]=kind=="d" and "([%d%.,]+)" or "(.-)"
        args[#args+1]={index=tonumber(slot),kind=kind}; at=last+1
    end
    local result=table.concat(out); cache[format]={result,args}; return result,args
end
function F:Match(format,message,fragment)
    if T:Text(format)=="" or T:Text(message)=="" then return end
    local p,args=pattern(format); local values={message:match(fragment and p or "^"..p.."$")}
    if #values==0 then return end
    local result={}
    for i,arg in ipairs(args) do
        local value=values[i]
        if arg.kind=="d" then value=tonumber(((value or ""):gsub("[^%d]",""))) end
        result[arg.index]=value
    end
    return result
end
local ownItems={
    {"LOOT_ITEM_SELF_MULTIPLE","You receive loot: %sx%d."}, {"LOOT_ITEM_SELF","You receive loot: %s."},
    {"LOOT_ITEM_PUSHED_SELF_MULTIPLE","You receive item: %sx%d."}, {"LOOT_ITEM_PUSHED_SELF","You receive item: %s."},
    {"LOOT_ITEM_CREATED_SELF_MULTIPLE","You create: %sx%d.",true}, {"LOOT_ITEM_CREATED_SELF","You create: %s.",true},
}
local currencies={{"CURRENCY_GAINED_MULTIPLE","You receive currency: %sx%d."},{"CURRENCY_GAINED","You receive currency: %s."},
    {"CURRENCY_GAINED_MULTIPLE_BONUS"},{"CURRENCY_GAINED_BONUS"}}
local reputation={{"FACTION_STANDING_INCREASED","Reputation with %s increased by %d."},{"FACTION_STANDING_INCREASED_BONUS"},
    {"FACTION_STANDING_INCREASED_ACCOUNT_WIDE"},{"FACTION_STANDING_INCREASED_ACH_BONUS"}}
local function matching(definitions,message)
    for _,definition in ipairs(definitions) do
        local format=T:Text(_G[definition[1]])
        if format=="" then format=definition[2] end
        local value=F:Match(format,message)
        if value then return value,definition end
    end
end
local function positive(value) return T:Number(value) and value>0 and value<=100000000 end
function F:Parse(event,message)
    message=T:Text(message); if message=="" or #message>2048 then return end
    local data=self:Data(); local value,definition
    if event=="CHAT_MSG_LOOT" and data.items then
        value,definition=matching(ownItems,message)
        if not value or definition[3] and not data.crafted then return end
        local link=T:Text(value[1]):match("(|Hitem:.-|h.-|h)")
        local id=link and tonumber(link:match("item:(%d+)")); local quantity=value[2] or 1
        if not id or not positive(quantity) then return end
        return {kind="item",id=id,link=link,name=link:match("|h%[(.-)%]|h") or ("Item "..id),quantity=quantity,key="item:"..link,message=message}
    elseif event=="CHAT_MSG_CURRENCY" and data.currencies then
        value=matching(currencies,message); if not value then return end
        local link=T:Text(value[1]):match("(|Hcurrency:.-|h.-|h)")
        local id=link and tonumber(link:match("currency:(%d+)")); local quantity=value[2] or 1
        if not id or not positive(quantity) then return end
        return {kind="currency",id=id,link=link,name=link:match("|h%[(.-)%]|h") or ("Currency "..id),quantity=quantity,key="currency:"..id,message=message}
    elseif event=="CHAT_MSG_COMBAT_FACTION_CHANGE" and data.reputation then
        value=matching(reputation,message)
        if value and T:Text(value[1])~="" and positive(value[2]) then
            return {kind="reputation",name=value[1]:sub(1,160),quantity=value[2],key="reputation:"..value[1],message=message}
        end
    elseif event=="CHAT_MSG_SKILL" and data.skills then
        value=self:Match(SKILL_RANK_UP or "Your skill in %s has increased to %d.",message)
        if value and T:Text(value[1])~="" and positive(value[2]) then
            return {kind="skill",name=value[1]:sub(1,160),rank=value[2],quantity=1,key="skill:"..value[1],message=message}
        end
    elseif event=="CHAT_MSG_MONEY" and data.money then
        value=matching({{"YOU_LOOT_MONEY","You loot %s."},{"LOOT_MONEY_SPLIT","Your share of the loot is %s."},{"YOU_LOOT_MONEY_GUILD"},{"LOOT_MONEY_SPLIT_GUILD"}},message)
        if not value then return end
        local quantity=0
        for _,coin in ipairs({{GOLD_AMOUNT or "%d Gold",10000},{SILVER_AMOUNT or "%d Silver",100},{COPPER_AMOUNT or "%d Copper",1}}) do
            local amount=self:Match(coin[1],value[1],true); if amount and positive(amount[1]) then quantity=quantity+amount[1]*coin[2] end
        end
        if positive(quantity) then return {kind="money",name="Money looted",quantity=quantity,key="money",icon=133784,message=message} end
    end
end
F.chatEvents={"CHAT_MSG_LOOT","CHAT_MSG_MONEY","CHAT_MSG_CURRENCY","CHAT_MSG_COMBAT_FACTION_CHANGE","CHAT_MSG_SKILL"}
function F:ChatFilters(enable)
    local api=ChatFrameUtil
    local add,remove=api and api.AddMessageEventFilter or ChatFrame_AddMessageEventFilter,api and api.RemoveMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    enable=enable and self:Ready() and type(add)=="function" and type(remove)=="function"
    if self.filterAdd and (not enable or self.filterAdd~=add or self.filterRemove~=remove) then
        for _,event in ipairs(self.chatEvents) do pcall(self.filterRemove,event,self.chatFilter) end
        self.filterAdd=nil; self.filterRemove=nil
    end
    if not enable or self.filterAdd then return end
    self.chatFilter=self.chatFilter or function(_,event,message)
        if not F:Ready() or not F:Data().hideChat or not UIParent:IsShown() then return false end
        local supported=FS.client.frameEvents[F.events]
        if not supported or not supported[event] then return false end
        local entry=F:Parse(event,message)
        return entry~=nil and F:Eligible(entry)==true and F:HasRoom(entry) or false
    end
    for _,event in ipairs(self.chatEvents) do pcall(add,event,self.chatFilter) end
    self.filterAdd=add; self.filterRemove=remove
end
function F:Eligible(entry)
    if entry.kind~="item" then return true end
    local minimum=FS.modules.Loot.qualities[self:Data().quality] or -1
    if minimum<0 then return true end
    local _,_,quality=T:Call(C_Item and C_Item.GetItemInfo or GetItemInfo,entry.link)
    if not T:Number(quality) then return nil end
    return quality>=minimum
end
