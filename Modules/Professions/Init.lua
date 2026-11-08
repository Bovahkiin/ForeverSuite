local _,FS=...
local T=FS.Tools
local P=T:Module("Professions","professions","Professions","Browse recipes from your open profession. Select a recipe to see its materials. Crafting stays in the game's profession window.",{craftableOnly=false,showCounts=true,sort="Original",missingOnly=false},{"TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRADE_SKILL_CLOSE","CRAFT_SHOW","CRAFT_UPDATE"})
P.options={{key="craftableOnly",label="Only show craftable recipes"},{key="showCounts",label="Show craftable quantity"},{key="sort",label="Recipe order",values={"Original","Name","Craftable"}},{key="missingOnly",label="Only show missing materials"}}
function P:Build()
    self.rows={}; local API=C_TradeSkillUI
    local enumerate=API and (API.GetAllRecipeIDs or API.GetFilteredRecipeIDs)
    if enumerate and API.GetRecipeInfo then
        for _,id in ipairs(T:Call(enumerate) or {}) do
            local info=T:Call(API.GetRecipeInfo,id)
            local count=info and (T:Call(API.GetCraftableCount,id) or info.numAvailable) or 0
            if info and T:Text(info.name)~="" and FS.HUD:Safe(info.learned) and info.learned and (not self:Data().craftableOnly or (T:Number(count) and count>0)) then
                self.rows[#self.rows+1]={id=id,name=info.name,count=T:Number(count) and count or 0,text=info.name..(self:Data().showCounts and (" | Craftable: "..(T:Number(count) and count or 0)) or ""),modern=true}
            end
        end
    else
        for i=1,(T:Call(GetNumTradeSkills) or 0) do
            local name,kind,count=T:Call(GetTradeSkillInfo,i)
            if name and kind~="header" and (not self:Data().craftableOnly or (count or 0)>0) then self.rows[#self.rows+1]={index=i,name=name,count=count or 0,text=name..(self:Data().showCounts and (" | Craftable: "..(count or 0)) or ""),link=T:Call(GetTradeSkillItemLink,i)} end
        end
        for i=1,(T:Call(GetNumCrafts) or 0) do
            local name,sub,kind,count=T:Call(GetCraftInfo,i)
            if name and kind~="header" and (not self:Data().craftableOnly or (count or 0)>0) then self.rows[#self.rows+1]={index=i,craft=true,name=name,count=count or 0,text=name..(self:Data().showCounts and (" | Craftable: "..(count or 0)) or ""),link=T:Call(GetCraftItemLink,i)} end
        end
    end
    if self:Data().sort~="Original" then table.sort(self.rows,function(a,b)
        if self:Data().sort=="Craftable" and a.count~=b.count then return a.count>b.count end
        return a.name<b.name
    end) end
    if self.materials then
        self.rows={}; for _,row in ipairs(self.materials) do if not self:Data().missingOnly or (row.owned or 0)<(row.required or 0) then self.rows[#self.rows+1]=row end end
    end
    self.status=self.materials and "Materials for selected recipe. Back returns to recipes." or "Open a profession in the game to load its recipes. Select a recipe to see materials."
    if not GetNumTradeSkills and not GetNumCrafts and not enumerate then self.status="Recipe enumeration is not exposed by this client's supported profession API." end
end
function P:OnSelect(row)
    if not row or row.material then return end
    local rows={}
    if row.modern then
        local schema=T:Call(C_TradeSkillUI.GetRecipeSchematic,row.id,false)
        for _,slot in ipairs(schema and schema.reagentSlotSchematics or {}) do
            for _,reagent in ipairs(slot.reagents or {}) do
                local name,link=T:Call(C_Item.GetItemInfo,reagent.itemID)
                local owned=T:Call(C_Item.GetItemCount,reagent.itemID,true) or T:Call(GetItemCount,reagent.itemID,true) or 0
                rows[#rows+1]={material=true,link=link,required=slot.quantityRequired or 0,owned=owned,text=(#slot.reagents>1 and "[Choose one] " or "")..(name or "Item "..reagent.itemID).." | Need "..(slot.quantityRequired or 0)..", have "..owned}
            end
        end
    else
        local getCount=row.craft and GetCraftNumReagents or GetTradeSkillNumReagents
        local getInfo=row.craft and GetCraftReagentInfo or GetTradeSkillReagentInfo
        local getLink=row.craft and GetCraftReagentItemLink or GetTradeSkillReagentItemLink
        for i=1,(T:Call(getCount,row.index) or 0) do
            local name,_,required,owned=T:Call(getInfo,row.index,i)
            if name then rows[#rows+1]={material=true,link=T:Call(getLink,row.index,i),required=required or 0,owned=owned or 0,text=name.." | Need "..(required or 0)..", have "..(owned or 0)} end
        end
    end
    self.materials=rows; self.page=1; self:Refresh()
end
function P:Event(event) if event=="TRADE_SKILL_CLOSE" or event=="TRADE_SKILL_SHOW" or event=="CRAFT_SHOW" then self.materials=nil end end
P.actions={{label="Back",run=function(self) self.materials=nil; self.page=1 end},{label="Materials",run=function(self) self:OnSelect(self.selected) end}}
