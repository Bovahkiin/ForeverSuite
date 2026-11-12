local _,FS=...
local T=FS.Tools
local P=T:Module("Professions","professions","Professions","Browse recipes from your open profession. Select a recipe to see its materials. Crafting stays in the game's profession window.",{craftableOnly=false,showCounts=true,sort="Original",missingOnly=false,countAltStock=false,expandSubrecipes=false},{"TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRADE_SKILL_CLOSE","CRAFT_SHOW","CRAFT_UPDATE"})
P.options={{key="craftableOnly",label="Only show craftable recipes"},{key="showCounts",label="Show craftable quantity"},{key="sort",label="Recipe order",values={"Original","Name","Craftable"}},{key="missingOnly",label="Only show missing materials"},{key="countAltStock",label="Count last seen alt stock for shopping"},{key="expandSubrecipes",label="Expand learned intermediate recipes"}}
function P:Build()
    self.rows={}; local API=C_TradeSkillUI; local db=self:Data()
    local enumerate=API and (API.GetAllRecipeIDs or API.GetFilteredRecipeIDs)
    if self.materials then
        for _,row in ipairs(self.expanded and self.expanded.rows or self.materials) do
            local owned=T:Number(row.owned) and row.owned or 0
            if not db.missingOnly or owned<(row.required or 0) then
                self.rows[#self.rows+1]=row
            end
        end
    elseif enumerate and API.GetRecipeInfo then
        for _,id in ipairs(T:Call(enumerate) or {}) do
            local info=T:Call(API.GetRecipeInfo,id)
            if type(info)=="table" and T:Text(info.name)~="" and FS.HUD:Safe(info.learned) and info.learned then
                local count=T:Call(API.GetCraftableCount,id) or info.numAvailable
                count=T:Number(count) and count or 0
                if not db.craftableOnly or count>0 then
                    self.rows[#self.rows+1]={id=id,name=info.name,count=count,text=info.name..(db.showCounts and (" | Craftable: "..count) or ""),modern=true}
                end
            end
        end
    else
        for i=1,(T:Call(GetNumTradeSkills) or 0) do
            local name,kind,count=T:Call(GetTradeSkillInfo,i)
            if name and kind~="header" and (not db.craftableOnly or (count or 0)>0) then self.rows[#self.rows+1]={index=i,name=name,count=count or 0,text=name..(db.showCounts and (" | Craftable: "..(count or 0)) or ""),link=T:Call(GetTradeSkillItemLink,i)} end
        end
        for i=1,(T:Call(GetNumCrafts) or 0) do
            local name,sub,kind,count=T:Call(GetCraftInfo,i)
            if name and kind~="header" and (not db.craftableOnly or (count or 0)>0) then self.rows[#self.rows+1]={index=i,craft=true,name=name,count=count or 0,text=name..(db.showCounts and (" | Craftable: "..(count or 0)) or ""),link=T:Call(GetCraftItemLink,i)} end
        end
    end
    if not self.materials and db.sort~="Original" then table.sort(self.rows,function(a,b)
        if db.sort=="Craftable" and a.count~=b.count then return a.count>b.count end
        return a.name<b.name
    end) end
    self.status=self.materials and ("Materials for "..(self.quantity or 1).." crafts. Enter a quantity, then click Materials. Shopping list adds missing fixed reagents.") or "Open a profession in the game to load its recipes. Select a recipe to see materials."
    if self.materials and db.expandSubrecipes then
        if self.expanded then
            self.status="Intermediate crafts are listed in order. Shopping list adds the remaining materials."
        else
            self.status="Intermediate planning is unavailable for this recipe. Showing direct materials."
        end
    end
    if not GetNumTradeSkills and not GetNumCrafts and not enumerate then self.status="Recipe enumeration is not exposed by this client's supported profession API." end
end
local function whole(value)
    return T:Number(value) and value>0 and value%1==0
end
local function ownedItem(id,bank)
    return T:Call(C_Item and C_Item.GetItemCount,id,bank) or T:Call(GetItemCount,id,bank)
end
function P:ExpandPlan(root,materials)
    local api=C_TradeSkillUI
    local enumerate=api and (api.GetAllRecipeIDs or api.GetFilteredRecipeIDs)
    if not root.modern or not enumerate or not api.GetRecipeSchematic then return end
    local recipes={}
    for _,id in ipairs(T:Call(enumerate) or {}) do
        local info=T:Call(api.GetRecipeInfo,id)
        if id~=root.id and type(info)=="table" and FS.HUD:Safe(info.learned) and info.learned then
            local schema=T:Call(api.GetRecipeSchematic,id,false)
            if schema and whole(schema.outputItemID) and whole(schema.quantityMin) and type(schema.reagentSlotSchematics)=="table" then
                local inputs={}
                for _,slot in ipairs(schema.reagentSlotSchematics) do
                    if slot.required~=false then
                        local reagent=slot.reagents and #slot.reagents==1 and slot.reagents[1]
                        if not reagent or not whole(reagent.itemID) or not whole(slot.quantityRequired) then inputs=nil; break end
                        inputs[#inputs+1]={id=reagent.itemID,count=slot.quantityRequired}
                    end
                end
                if inputs and #inputs>0 then
                    local item=schema.outputItemID
                    if recipes[item]==nil then
                        recipes[item]={yield=schema.quantityMin,inputs=inputs,name=T:Text(info.name)}
                    else recipes[item]=false end
                end
            end
        end
    end
    local db=FS.modules.AuctionHouse:Data()
    local result={rows={},goals={},missing={},skipped=false}
    local stock,owned,active={},{},{}
    local steps=0
    local function requireItem(id,count,depth)
        steps=steps+1
        if steps>500 or count>100000 or depth>16 then return false end
        if stock[id]==nil then
            local amount=ownedItem(id,db.countBank)
            if not T:Number(amount) or amount<0 then return false end
            owned[id]=amount
            stock[id]=amount+(self:Data().countAltStock and FS.Extensions:ObservedStock(id,true) or 0)
        end
        local used=math.min(stock[id],count)
        stock[id]=stock[id]-used; count=count-used
        if count==0 then return true end
        local recipe=recipes[id]
        if active[id] then return false end
        if not recipe then
            result.missing[id]=(result.missing[id] or 0)+count
            return true
        end
        active[id]=true
        local crafts=math.ceil(count/recipe.yield)
        for _,input in ipairs(recipe.inputs) do
            if not requireItem(input.id,input.count*crafts,depth+1) then return false end
        end
        active[id]=nil
        stock[id]=stock[id]+crafts*recipe.yield-count
        local name=recipe.name~="" and recipe.name or ("Item "..id)
        result.rows[#result.rows+1]={material=true,required=crafts,owned=0,text="Craft "..crafts.." x "..name}
        return true
    end
    for _,row in ipairs(materials) do
        if row.choice or row.optional or not whole(row.id) then
            result.skipped=true
            result.rows[#result.rows+1]=row
        elseif whole(row.required) and not requireItem(row.id,row.required,0) then return end
    end
    local ids={}
    for id in pairs(result.missing) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local count=result.missing[id]
        local goal=owned[id]+count
        if goal>100000 then return end
        local name,link=T:Call(C_Item and C_Item.GetItemInfo,id)
        result.goals[id]=goal
        result.rows[#result.rows+1]={material=true,link=link,required=count,owned=0,
            text="Still need "..count.." x "..(T:Text(name)~="" and name or ("Item "..id))}
    end
    if #result.rows==0 then
        result.rows[1]={material=true,required=1,owned=0,text="All required materials are available."}
    end
    return result
end
function P:OnSelect(row,quantity)
    if not row or row.material then return end
    self.planRecipe=row
    self.quantity=quantity or 1
    local rows={}
    local function add(name,link,id,required,owned,choice,optional)
        local need=(T:Number(required) and required or 0)*self.quantity
        local observed=id and FS.Extensions:ObservedStock(id) or 0
        rows[#rows+1]={material=true,link=link,id=id,required=need,owned=owned,choice=choice,optional=optional,
            text=(optional and "[Optional] " or choice and "[Choose one] " or "")..name.." | Need "..need..
                (T:Number(owned) and ", have "..owned or ", stock unknown")..
                (observed>0 and " | Alts last seen: "..observed or "")}
    end
    if row.modern then
        local schema=T:Call(C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic,row.id,false)
        local itemInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
        for _,slot in ipairs(schema and schema.reagentSlotSchematics or {}) do
            for _,reagent in ipairs(slot.reagents or {}) do
                if whole(reagent.itemID) then
                    local name,link=T:Call(itemInfo,reagent.itemID)
                    add(name or "Item "..reagent.itemID,link,reagent.itemID,slot.quantityRequired,
                        ownedItem(reagent.itemID,true),#slot.reagents>1,slot.required==false)
                else
                    add("Unknown reagent",nil,nil,slot.quantityRequired,nil,#slot.reagents>1,slot.required==false)
                end
            end
        end
    else
        local getCount=row.craft and GetCraftNumReagents or GetTradeSkillNumReagents
        local getInfo=row.craft and GetCraftReagentInfo or GetTradeSkillReagentInfo
        local getLink=row.craft and GetCraftReagentItemLink or GetTradeSkillReagentItemLink
        for i=1,(T:Call(getCount,row.index) or 0) do
            local name,_,required,owned=T:Call(getInfo,row.index,i)
            if name then
                local link=T:Call(getLink,row.index,i)
                add(name,link,FS.modules.Vendor:ItemID(link),required,owned)
            end
        end
    end
    self.materials=rows
    self.expanded=self:Data().expandSubrecipes and self:ExpandPlan(row,rows) or nil
    self.page=1; self:Refresh()
end
function P:ClearPlan()
    self.materials=nil; self.expanded=nil; self.planRecipe=nil; self.quantity=nil; self.selected=nil; self.page=1
end
function P:AddPlanToShopping()
    if not self.materials or not self.planRecipe then self.status="Select a recipe first."; return end
    local db=FS.modules.AuctionHouse:Data()
    if self.expanded then
        local count=0
        for id,goal in pairs(self.expanded.goals) do
            db.shopping[id]=math.max(db.shopping[id] or 0,goal)
            count=count+1
        end
        self.status=("Shopping list: %d reagent goals covered."):format(count)..
            (self.expanded.skipped and " Some reagents need manual review." or "")
        return
    end
    local totals, skipped={},false
    for _,row in ipairs(self.materials) do
        if row.choice or row.optional or not row.id then skipped=true
        elseif row.required>0 then totals[row.id]=(totals[row.id] or 0)+row.required end
    end
    local count,usedAltStock=0,false
    for id,total in pairs(totals) do
        local owned=ownedItem(id,db.countBank)
        if not T:Number(owned) then skipped=true
        else
            local goal=total
            if self:Data().countAltStock and owned<total then
                local credit=math.min(total-owned,FS.Extensions:ObservedStock(id,true))
                goal=total-credit
                usedAltStock=usedAltStock or credit>0
            end
            if goal>100000 then skipped=true
            elseif owned<goal then
                db.shopping[id]=math.max(db.shopping[id] or 0,goal)
                count=count+1
            end
        end
    end
    self.status=("Shopping list: %d reagent goals covered."):format(count)..
        (usedAltStock and " Includes last seen alt bags; transfer materials before crafting." or "")..
        (skipped and " Some reagents need manual review." or "")
end
function P:Event(event)
    if event=="TRADE_SKILL_CLOSE" or event=="TRADE_SKILL_SHOW" or event=="CRAFT_SHOW" then self:ClearPlan() end
end
P.actions={
    {label="Back",run=function(self) self:ClearPlan() end},
    {label="Materials",run=function(self,text)
        local row=self.materials and self.planRecipe or self.selected
        if not row then self.status="Select a recipe first."; return end
        local quantity=text=="" and (self.quantity or 1) or tonumber(text)
        if not T:Number(quantity) or quantity<1 or quantity>1000 or quantity%1~=0 then
            self.status="Enter a whole quantity from 1 to 1000."; return
        end
        self:OnSelect(row,quantity)
    end},
    {label="Shopping list",run=function(self) self:AddPlanToShopping() end},
}
