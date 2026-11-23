local _,FS=...
local T=FS.Tools
local P=T:Module("Professions","professions","Professions","Browse the open profession's recipes, find skill-ups and compare recorded Auction House prices. Select a recipe to see its materials.",{craftableOnly=false,showCounts=true,sort="Original",missingOnly=false,countAltStock=false,expandSubrecipes=false},{"TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRADE_SKILL_CLOSE","CRAFT_SHOW","CRAFT_UPDATE","BAG_UPDATE_DELAYED","SKILL_LINES_CHANGED"})
P.options={{key="craftableOnly",label="Only show craftable recipes"},{key="showCounts",label="Show craftable quantity"},{key="sort",label="Recipe order",values={"Original","Name","Craftable"}},{key="missingOnly",label="Only show missing materials"},{key="countAltStock",label="Count last seen alt stock for shopping"},{key="expandSubrecipes",label="Expand learned intermediate recipes"}}
local recipeViews={"Recipes","Skill-ups","Market","Recipe book","Level routes"}
local difficultyLabels={[0]="Orange",[1]="Yellow",[2]="Green"}
local legacyDifficulty={optimal=0,medium=1,easy=2}
local function whole(value)
    return T:Number(value) and value>0 and value%1==0
end
function P:UnitPrice(prices,id)
    local observation=prices[id]
    if observation and observation.kind=="per item" and T:Number(observation.price) and observation.price>0 then
        return observation.price
    end
end
local function money(amount)
    return FS.modules.Vendor:Money(math.abs(amount))
end
function P:RecipeValue(row,prices)
    local cost,output,copies=0,nil,nil
    local function add(id,quantity)
        if not whole(id) or not whole(quantity) then return false end
        local price=self:UnitPrice(prices,id)
        if not price then return false end
        cost=cost+price*quantity
        return cost<=100000000000
    end
    if row.modern then
        local api=C_TradeSkillUI
        local schema=T:Call(api and api.GetRecipeSchematic,row.id,false)
        if type(schema)~="table" or type(schema.reagentSlotSchematics)~="table" then return end
        if T:Number(schema.recipeType) and schema.recipeType~=1 and schema.recipeType~=3 then return end
        for _,slot in ipairs(schema.reagentSlotSchematics) do
            if slot.required~=false then
                local reagent=type(slot.reagents)=="table" and #slot.reagents==1 and slot.reagents[1]
                if not reagent or not add(reagent.itemID,slot.quantityRequired) then return end
            end
        end
        output,copies=schema.outputItemID,schema.quantityMin
    else
        local getCount=row.craft and GetCraftNumReagents or GetTradeSkillNumReagents
        local getInfo=row.craft and GetCraftReagentInfo or GetTradeSkillReagentInfo
        local getLink=row.craft and GetCraftReagentItemLink or GetTradeSkillReagentItemLink
        local count=T:Call(getCount,row.index)
        if not T:Number(count) or count<0 then return end
        for i=1,count do
            local _,_,quantity=T:Call(getInfo,row.index,i)
            local id=FS.modules.Vendor:ItemID(T:Call(getLink,row.index,i))
            if not add(id,quantity) then return end
        end
        output=FS.modules.Vendor:ItemID(row.link)
        if not row.craft then copies=T:Call(GetTradeSkillNumMade,row.index) end
    end
    local sale=whole(output) and whole(copies) and self:UnitPrice(prices,output)
    local margin=sale and sale*copies<=100000000000 and sale*copies-cost or nil
    return cost,margin
end
function P:Build()
    self.rows={}; local API=C_TradeSkillUI; local db=self:Data()
    local enumerate=API and (API.GetAllRecipeIDs or API.GetFilteredRecipeIDs)
    local view=self.recipeView or 1
    if view==5 then self:BuildLevelRoutes(); return end
    local references=view==4 and not self.materials and self:RecipeReferences()
    local prices=(view==2 or view==3) and not self.materials and FS.modules.AuctionHouse:Prices()
    local function addRecipe(row)
        if view==2 and row.difficulty==nil then return end
        if view~=4 and db.craftableOnly and row.count<=0 then return end
        local caption=row.name
        if view==4 then
            local base=row.learned==false and "Unlearned" or "Learned"
            caption="["..base.."] "..caption
            local source=row.modern and T:Text(T:Call(API.GetRecipeSourceText,row.id))
            if (not source or source=="") and row.modern and references then
                source=self:KnownRecipeSource(references[row.id])
            end
            if source and source~="" then row.detailLine=source; row.searchText=caption.." "..source end
        elseif db.showCounts then
            caption=caption.." | Craftable: "..row.count
        end
        if view==2 then caption=caption.." | "..difficultyLabels[row.difficulty] end
        if prices then
            row.cost,row.margin=self:RecipeValue(row,prices)
            if row.cost~=nil then
                row.detailLine="Cost "..money(row.cost).." per craft"
                caption=caption.." | "..row.detailLine
            elseif view==3 then
                caption=caption.." | Price unavailable"
            end
            if view==3 and row.margin~=nil then
                local margin=(row.margin<0 and "-" or "+")..money(row.margin)
                caption=row.name.." | "..margin.." before fees"
                row.detailLine=row.detailLine.." | "..margin.." before fees"
            end
        end
        row.text=caption
        self.rows[#self.rows+1]=row
    end
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
            if type(info)=="table" and T:Text(info.name)~="" and FS.HUD:Safe(info.learned) and (info.learned or view==4) then
                local count=T:Call(API.GetCraftableCount,id) or info.numAvailable
                count=T:Number(count) and count or 0
                local difficulty=info.relativeDifficulty
                if not T:Number(difficulty) or not difficultyLabels[difficulty]
                    or not FS.HUD:Safe(info.canSkillUp) or info.canSkillUp==false
                    or not FS.HUD:Safe(info.disabled) or info.disabled==true then difficulty=nil end
                addRecipe({id=id,name=info.name,count=count,learned=info.learned==true,
                    difficulty=difficulty,modern=true})
            end
        end
    else
        for i=1,(T:Call(GetNumTradeSkills) or 0) do
            local name,kind,count=T:Call(GetTradeSkillInfo,i)
            if name and kind~="header" then
                addRecipe({id="trade:"..i,index=i,name=name,count=T:Number(count) and count or 0,
                    difficulty=legacyDifficulty[kind],link=T:Call(GetTradeSkillItemLink,i)})
            end
        end
        for i=1,(T:Call(GetNumCrafts) or 0) do
            local name,sub,kind,count=T:Call(GetCraftInfo,i)
            if name and kind~="header" then
                addRecipe({id="craft:"..i,index=i,craft=true,name=name,count=T:Number(count) and count or 0,
                    difficulty=legacyDifficulty[kind],link=T:Call(GetCraftItemLink,i)})
            end
        end
    end
    if not self.materials and (view~=1 or db.sort~="Original") then table.sort(self.rows,function(a,b)
        if view==2 then
            if a.difficulty~=b.difficulty then return a.difficulty<b.difficulty end
            if (a.count>0)~=(b.count>0) then return a.count>0 end
            if a.cost~=b.cost then return (a.cost or math.huge)<(b.cost or math.huge) end
        elseif view==3 then
            if a.margin~=b.margin then return (a.margin or -math.huge)>(b.margin or -math.huge) end
        end
        if db.sort=="Craftable" and a.count~=b.count then return a.count>b.count end
        if a.name~=b.name then return a.name<b.name end
        return tostring(a.id)<tostring(b.id)
    end) end
    self.status=self.materials and ("Materials for "..(self.quantity or 1).." crafts. Enter a quantity, then click Materials. Shopping list adds missing fixed reagents.") or "Open a profession in the game to load its recipes. Select a recipe to see materials."
    if self.materials and db.expandSubrecipes then
        if self.expanded then
            self.status="Intermediate crafts are listed in order. Shopping list adds the remaining materials."
        else
            self.status="Intermediate planning is unavailable for this recipe. Showing direct materials."
        end
    end
    if self.materials and self.planRecipe and self.planRecipe.detailLine then
        self.status=self.planRecipe.detailLine..". "..self.status
    elseif not self.materials and view==2 then
        local best=self.rows[1]
        self.status=best and ("Try "..best.name.." first. Ordered by skill-up color, craftable stock, then known material cost.")
            or "Open a profession with learned recipes that can still give skill-ups."
    elseif not self.materials and view==3 then
        self.status="Estimates per craft use saved unit prices, minimum output and exclude auction fees. Browse Buy results for missing prices."
    elseif not self.materials and view==4 then
        self.status="Search recipes exposed by the open profession. Select one for its materials and any source reported by the game."
    end
    if not GetNumTradeSkills and not GetNumCrafts and not enumerate then self.status="Recipe enumeration is not exposed by this client's supported profession API." end
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
function P:OnSelect(row,quantity,deferRefresh)
    if not deferRefresh and self.planRecipe~=row then self.contextFollowSelection=nil end
    if self.recipeView==5 then
        if row and row.profession then self:ShowLevelRoute(row.profession,"") end
        return
    end
    if not row or row.material then return end
    if not self.materials and self.window then
        self.recipeSearch=self.window.search:GetText()
        self.window.search:SetText("")
    end
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
    self.page=1
    if not deferRefresh then self:Refresh() end
end
function P:ClearPlan(returnToResults)
    self.contextFollowSelection=nil
    local search=self.recipeSearch
    self.materials=nil; self.expanded=nil; self.planRecipe=nil; self.quantity=nil; self.selected=nil; self.page=1
    self.recipeSearch=nil
    if self.window and returnToResults and search then self.window.search:SetText(search) end
end
function P:AddPlanToShopping(materials)
    if not materials and (not self.materials or not self.planRecipe) then self.status="Select a recipe first."; return end
    local db=FS.modules.AuctionHouse:Data()
    if not materials and self.expanded then
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
    for _,row in ipairs(materials or self.materials) do
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
    if event=="TRADE_SKILL_CLOSE" or event=="TRADE_SKILL_SHOW" or event=="TRADE_SKILL_DATA_SOURCE_CHANGED" or event=="CRAFT_SHOW" then
        self:ClearPlan()
    elseif event=="BAG_UPDATE_DELAYED" and self.planRecipe and self.window and self.window:IsShown() then
        self:OnSelect(self.planRecipe,self.quantity,true)
    end
end
function P:RefreshOnTick() return false end
local render=P.Render
function P:Render()
    if self.window then
        local buttons=self.window.actionButtons
        buttons[2]:SetText(self.recipeView==5 and "Plan range" or "Materials")
        buttons[4]:SetText("View: "..recipeViews[self.recipeView or 1])
    end
    render(self)
end
P.actions={
    {label="Back",run=function(self)
        if self.recipeView==5 then
            self.levelRoute=nil; self.selected=nil; self.page=1
            self.window.search:SetText("")
        else
            self:ClearPlan(true)
        end
    end},
    {label="Materials",run=function(self,text)
        if self.recipeView==5 then return self:ShowLevelRoute(self.levelRoute and self.levelRoute.profession,text) end
        local row=self.materials and self.planRecipe or self.selected
        if not row then self.status="Select a recipe first."; return end
        local quantity=text=="" and (self.quantity or 1) or tonumber(text)
        if not T:Number(quantity) or quantity<1 or quantity>1000 or quantity%1~=0 then
            self.status="Enter a whole quantity from 1 to 1000."; return
        end
        self:OnSelect(row,quantity)
    end},
    {label="Shopping list",run=function(self)
        if self.recipeView==5 then
            local route=self.levelRoute
            if not route or #route.materials==0 then self.status="Choose a crafting route with material estimates first."; return end
            self:AddPlanToShopping(route.materials)
        else
            self:AddPlanToShopping()
        end
    end},
    {label="View",run=function(self)
        self.recipeView=(self.recipeView or 1)%#recipeViews+1
        self:ClearPlan()
        self.levelRoute=nil
        self.window.search:SetText("")
    end},
}
