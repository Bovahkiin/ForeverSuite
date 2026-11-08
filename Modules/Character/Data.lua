local _,FS=...
local C,H=FS.modules.Character,FS.HUD
C.slotLabels={[0]="Ammo",[1]="Head",[2]="Neck",[3]="Shoulders",[4]="Shirt",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",[9]="Wrists",[10]="Hands",[11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",[15]="Back",[16]="Main hand",[17]="Off hand",[18]="Ranged",[19]="Tabard"}
C.slotNames={[0]="AmmoSlot",[1]="HeadSlot",[2]="NeckSlot",[3]="ShoulderSlot",[4]="ShirtSlot",[5]="ChestSlot",[6]="WaistSlot",[7]="LegsSlot",[8]="FeetSlot",[9]="WristSlot",[10]="HandsSlot",[11]="Finger0Slot",[12]="Finger1Slot",[13]="Trinket0Slot",[14]="Trinket1Slot",[15]="BackSlot",[16]="MainHandSlot",[17]="SecondaryHandSlot",[18]="RangedSlot",[19]="TabardSlot"}
function C:EmptySlotIcon(slot)
    local api=C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo or GetInventorySlotInfo
    if api then
        local ok,_,texture=pcall(api,self.slotNames[slot])
        if ok and texture then return texture end
    end
    local kind=({[0]="Ammo",[11]="Finger",[12]="Finger",[13]="Trinket",[14]="Trinket"})[slot] or (self.slotNames[slot] or "HeadSlot"):gsub("Slot$","")
    return "Interface\\PaperDoll\\UI-PaperDoll-Slot-"..kind
end
local function call(fn,...)
    if not fn then return end
    local ok,a,b,c,d=pcall(fn,...); if ok then return a,b,c,d end
end
local function value(n,percent)
    if not H:Safe(n) or type(n)~="number" then return "--" end
    return percent and string.format("%.1f%%",n) or H:Number(n)
end
function C:Stats()
    local out={}
    local function add(name,n,percent) out[#out+1]={text=name..":  "..value(n,percent)} end
    add("Health",call(UnitHealthMax,"player")); add("Power",call(UnitPowerMax,"player"))
    for i,name in ipairs({"Strength","Agility","Stamina","Intellect","Spirit"}) do local base,effective=call(UnitStat,"player",i); add(name,H:Safe(effective) and type(effective)=="number" and effective or base) end
    local base,armor=call(UnitArmor,"player"); add("Armor",H:Safe(armor) and type(armor)=="number" and armor or base)
    add("Melee critical",call(GetCritChance),true); add("Ranged critical",call(GetRangedCritChance),true)
    add("Dodge",call(GetDodgeChance),true); add("Parry",call(GetParryChance),true); add("Block",call(GetBlockChance),true)
    local minimum,maximum=call(UnitDamage,"player"); out[#out+1]={text="Main hand:  "..value(minimum).." - "..value(maximum)}
    return out
end
function C:Titles()
    local out={{text="No title",id=-1}}
    local count=call(GetNumTitles) or 0
    for i=1,count do if call(IsTitleKnown,i) then
        local name=call(GetTitleName,i)
        if type(name)=="string" then out[#out+1]={text=name:gsub("%%s",UnitName("player") or ""),id=i} end
    end end
    return out
end
function C:EquipmentSets()
    local api=C_EquipmentSet; local out={}
    for _,id in ipairs((api and call(api.GetEquipmentSetIDs)) or {}) do
        local name,icon,_,equipped=call(api.GetEquipmentSetInfo,id)
        if name then out[#out+1]={text=name..(equipped and " (equipped)" or ""),name=name,id=id,icon=icon} end
    end
    return out
end
function C:CreateSet()
    if InCombatLockdown() then FS:Print("Leave combat to save equipment."); return end
    local api=C_EquipmentSet; local name=self.setName:GetText():match("^%s*(.-)%s*$")
    if name=="" then self.sideHeading:SetText("Enter a name for your new set."); return end
    if not api or not api.CreateEquipmentSet then self.sideHeading:SetText("Equipment sets are unavailable."); return end
    for _,entry in ipairs(self:EquipmentSets()) do if entry.name==name then self.sideHeading:SetText("That name already exists. Choose another."); return end end
    if api.ClearIgnoredSlotsForSave then api.ClearIgnoredSlotsForSave() end
    api.CreateEquipmentSet(name,134400); self.setName:SetText(""); self:RefreshCharacter()
end
function C:DeleteSet()
    if InCombatLockdown() then FS:Print("Leave combat to change equipment sets."); return end
    if not self.selectedSet or not C_EquipmentSet or not C_EquipmentSet.DeleteEquipmentSet then return end
    if self.confirmAction~=self.selectedSet then self.confirmAction=self.selectedSet; self.delete:SetText("Confirm delete"); return end
    C_EquipmentSet.DeleteEquipmentSet(self.selectedSet); self.selectedSet=nil; self.confirmAction=nil; self:RefreshCharacter()
end
function C:RefreshCharacter()
    if not self.root then return end
    self:RefreshPetView()
    self.root.title:SetText(UnitName("player") or "Character")
    local level=call(UnitLevel,"player"); local class=call(UnitClass,"player")
    self.root.level:SetText((level and H:Safe(level) and "Level "..tostring(level).."  " or "")..(H:Safe(class) and class or ""))
    for slot,b in pairs(self.slots) do
        local icon=call(GetInventoryItemTexture,"player",slot); b.icon:SetTexCoord(0,1,0,1)
        if icon then b.icon:SetTexture(icon); b.icon:SetDesaturated(false); b.icon:SetAlpha(1)
        else b.icon:SetTexture(self:EmptySlotIcon(slot)); b.icon:SetDesaturated(true); b.icon:SetAlpha(.65) end
        b.empty:SetText("")
        local count=call(GetInventoryItemCount,"player",slot)
        b.count:SetText(H:Safe(count) and type(count)=="number" and count>1 and tostring(count) or "")
        b.cooldown:Hide()
        local start,duration=call(GetInventoryItemCooldown,"player",slot)
        if H:Safe(start) and H:Safe(duration) and type(start)=="number" and type(duration)=="number" and duration>0 then b.cooldown:SetCooldown(start,duration); b.cooldown:Show() end
    end
    local mode=self.sideMode or 1
    local entries=mode==1 and self:Stats() or mode==2 and self:EquipmentSets() or mode==4 and self:PetStats() or self:Titles()
    self:LayoutText()
    local perPage=self.rowsPerPage or 9
    local pages=math.max(1,math.ceil(#entries/perPage)); self.listPage=math.min(pages,self.listPage or 1)
    self.sideHeading:SetText(mode==1 and "Character Stats" or mode==2 and (#entries==0 and "No saved equipment sets yet." or "Select a set, then Equip set.") or mode==4 and 'Pet details' or "Choose your character title.")
    for i,b in ipairs(self.rows) do
        local entry=i<=perPage and entries[(self.listPage-1)*perPage+i] or nil; b:SetShown(entry~=nil); b:SetText(entry and entry.text or "")
        b:SetScript('OnEnter',function() if entry then GameTooltip:SetOwner(b,'ANCHOR_RIGHT'); GameTooltip:AddLine(entry.text,1,1,1,true); GameTooltip:Show() end end)
        b:SetScript('OnLeave',function() GameTooltip:Hide() end)
        b:SetScript("OnClick",function()
            if not entry then return end
            if InCombatLockdown() then FS:Print("Leave combat to change character settings."); return end
            if mode==2 then self.selectedSet=entry.id; self.confirmAction=nil; self:RefreshCharacter()
            elseif mode==3 and SetCurrentTitle then SetCurrentTitle(entry.id); self:RefreshCharacter() end
        end)
        local selected=entry and (mode==2 and entry.id==self.selectedSet or mode==3 and entry.id==call(GetCurrentTitle))
        b:SetBackdropBorderColor(selected and .95 or .12,selected and .68 or .72,selected and .24 or .86,1)
    end
    self.prev:SetEnabled(self.listPage>1); self.next:SetEnabled(self.listPage<pages)
    self.pageLabel:SetText("Page "..self.listPage.." / "..pages); self.pageLabel:SetShown(mode~=2)
    self.setName:SetShown(mode==2); self.createSet:SetShown(mode==2); if not InCombatLockdown() then self.equip:SetShown(mode==2) end; self.delete:SetShown(mode==2)
    if not InCombatLockdown() then
        local selected
        for _,entry in ipairs(entries) do if mode==2 and entry.id==self.selectedSet then selected=entry end end
        self.equip:SetAttribute("equipmentset",selected and selected.name or nil); self.equip:SetEnabled(selected~=nil)
        self.delete:SetEnabled(selected~=nil and C_EquipmentSet and C_EquipmentSet.DeleteEquipmentSet~=nil)
    end
    self.delete:SetText(self.confirmAction and "Confirm delete" or "Delete set")
    for i,b in ipairs(self.sideTabs) do b:SetBackdropBorderColor(i==mode and .95 or .12,i==mode and .68 or .72,i==mode and .24 or .86,1) end
end
