local _,FS=...
local C,T,H=FS.modules.Character,FS.Tools,FS.HUD
local moods={[1]={'Unhappy','UI-PetMad'},[2]={'Content','UI-PetNeutral'},[3]={'Happy','UI-PetHappiness'}}
local function number(n) return T:Number(n) and H:Number(n) or '--' end
function C:HasActivePet()
    if T:Call(UnitExists,'pet')~=true then return false end
    if HasPetUI and T:Call(HasPetUI)~=true then return false end
    return true
end
function C:PetMood()
    local _,hunter=T:Call(HasPetUI)
    if hunter~=true then return end
    local mood,damage=T:Call(C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness)
    if not T:Number(mood) or not moods[mood] then return end
    return moods[mood],damage
end
function C:PetStats()
    if not self:HasActivePet() then return {{text='No active pet. Summon your pet to see its details.'}} end
    local rows={}
    local function add(label,value) rows[#rows+1]={text=label..':  '..value} end
    add('Name',T:Text(T:Call(UnitName,'pet')))
    local family=T:Text(T:Call(UnitCreatureFamily,'pet')); if family~='' then add('Family',family) end
    add('Level',number(T:Call(UnitLevel,'pet')))
    add('Health',number(T:Call(UnitHealth,'pet'))..' / '..number(T:Call(UnitHealthMax,'pet')))
    add('Power',number(T:Call(UnitPower,'pet'))..' / '..number(T:Call(UnitPowerMax,'pet')))
    local _,armor=T:Call(UnitArmor,'pet'); add('Armor',number(armor))
    local low,high=T:Call(UnitDamage,'pet'); if T:Number(low) and T:Number(high) then add('Damage',number(low)..' - '..number(high)) end
    local speed=T:Call(UnitAttackSpeed,'pet'); if T:Number(speed) then add('Attack speed',string.format('%.2fs',speed)) end
    local exp,needed=T:Call(GetPetExperience)
    if T:Number(exp) and T:Number(needed) and needed>0 then add('Experience',number(exp)..' / '..number(needed)) end
    local mood,damage=self:PetMood()
    if mood then add('Happiness',mood[1]); if T:Number(damage) then add('Damage modifier',number(damage)..'%') end end
    local _,hunter=T:Call(HasPetUI)
    if hunter then
        local loyalty=T:Text(T:Call(C_PetInfo and C_PetInfo.GetPetLoyalty or GetPetLoyalty))
        if loyalty~='' then add('Loyalty',loyalty) end
        local total,used=T:Call(C_PetInfo and C_PetInfo.GetPetTrainingPoints or GetPetTrainingPoints)
        if T:Number(total) and T:Number(used) then add('Training points available',number(math.max(0,total-used))) end
        local diet=T:Call(C_PetInfo and C_PetInfo.GetPetFoodTypes or GetPetFoodTypes); local names={}
        if type(diet)=='table' then for _,food in ipairs(diet) do if H:Safe(food) and type(food)=='string' then names[#names+1]=food end end end
        if #names>0 then add('Diet',table.concat(names,', ')) end
    end
    return rows
end
function C:RotateModel(amount)
    if not self.model or not self.model.SetFacing then return end
    self.modelFacing=self.modelFacing or {}; local unit=self.modelUnit or 'player'
    self.modelFacing[unit]=(self.modelFacing[unit] or 0)+amount
    self.model:SetFacing(self.modelFacing[unit])
end
function C:CreatePetExtras()
    if self.petXP then return end
    local bar=CreateFrame('StatusBar',nil,self.character,'BackdropTemplate'); self.petXP=bar
    H:Skin(bar); bar:SetSize(270,24); bar:SetPoint('TOPLEFT',78,-382); bar:SetStatusBarTexture(H.texture); bar:SetStatusBarColor(.4,.65,1); bar:EnableMouse(true)
    bar.text=H:Label(bar,'',4,-3,262); bar.text:SetJustifyH('CENTER'); bar:Hide()
    bar:SetScript('OnEnter',function(b)
        if not b.current or not b.maximum then return end
        GameTooltip:SetOwner(b,'ANCHOR_RIGHT'); GameTooltip:AddLine('Pet experience'); GameTooltip:AddLine(number(b.current)..' / '..number(b.maximum),1,1,1); GameTooltip:Show()
    end)
    bar:SetScript('OnLeave',function() GameTooltip:Hide() end)
    local badge=CreateFrame('Frame',nil,self.character); self.petMood=badge
    badge:SetSize(26,26); badge:SetPoint('TOPRIGHT',-12,-12); badge.icon=badge:CreateTexture(nil,'OVERLAY'); badge.icon:SetAllPoints(); badge:EnableMouse(true); badge:Hide()
    badge:SetScript('OnEnter',function(b)
        local mood,damage=self:PetMood(); if not mood then return end
        GameTooltip:SetOwner(b,'ANCHOR_RIGHT'); GameTooltip:AddLine(mood[1]); GameTooltip:AddLine('Feed suitable food if your pet is not happy.',1,1,1,true)
        if T:Number(damage) then GameTooltip:AddLine('Pet damage: '..number(damage)..'%',1,1,1) end
        GameTooltip:Show()
    end)
    badge:SetScript('OnLeave',function() GameTooltip:Hide() end)
end
function C:RefreshPetView()
    local active=self:HasActivePet(); local mode=self.sideMode or 1
    if not active and mode==4 and not InCombatLockdown() then self.sideMode=1; self.listPage=1; mode=1 end
    local pet=mode==4
    if not InCombatLockdown() then
        self.sideTabs[4]:SetShown(active)
        for _,slot in pairs(self.slots) do slot:SetShown(not pet) end
    end
    local unit=pet and 'pet' or 'player'
    if pet and not active then
        if self.model.ClearModel then self.model:ClearModel() end; self.modelUnit=nil
    elseif self.modelUnit~=unit then
        self.model:SetUnit(unit); self.modelUnit=unit
        if self.model.SetFacing then self.model:SetFacing(self.modelFacing and self.modelFacing[unit] or 0) end
    end
    if not self.petXP and InCombatLockdown() then return end
    self:CreatePetExtras()
    if not pet or not active then self.petXP:Hide(); self.petMood:Hide(); return end
    local exp,needed=T:Call(GetPetExperience)
    if T:Number(exp) and T:Number(needed) and exp>=0 and needed>0 then
        self.petXP.current=exp; self.petXP.maximum=needed
        self.petXP:SetMinMaxValues(0,needed); self.petXP:SetValue(math.min(exp,needed))
        self.petXP.text:SetText('Experience: '..math.floor(math.min(exp/needed,1)*100+.5)..'%'); self.petXP:Show()
    else self.petXP:Hide(); self.petXP.current=nil; self.petXP.maximum=nil end
    local mood=self:PetMood()
    if mood then self.petMood.icon:SetAtlas(mood[2]); self.petMood:Show() else self.petMood:Hide() end
end
