local _,FS=...
local U,H=FS.modules.UnitFrames,FS.HUD
local moods={
    [1]={atlas="UI-PetMad",title="Unhappy",note="Feed your pet suitable food to improve its happiness."},
    [2]={atlas="UI-PetNeutral",title="Content",note="Feeding can improve your pet's happiness."},
    [3]={atlas="UI-PetHappiness",title="Happy",note="Your pet is happy. It does not need more food right now."},
}
function U:CreatePetHappiness(f)
    local badge=CreateFrame("Frame",nil,f); f.happiness=badge
    badge:SetSize(22,22); badge:SetPoint("BOTTOMRIGHT",f.portrait,"BOTTOMRIGHT",2,-2)
    badge:SetFrameLevel(f:GetFrameLevel()+4); badge:EnableMouse(true)
    if badge.SetMouseClickEnabled then badge:SetMouseClickEnabled(false) end
    badge.icon=badge:CreateTexture(nil,"OVERLAY"); badge.icon:SetAllPoints()
    badge:SetScript("OnEnter",function(b) self:PetHappinessTooltip(b) end)
    badge:SetScript("OnLeave",function() GameTooltip:Hide() end)
    badge:Hide()
end
function U:RefreshPetHappiness()
    local badge=self.frames.pet and self.frames.pet.happiness; if not badge then return end
    local get=C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness
    local happiness,damage=FS.Tools:Call(get)
    local _,hunter=FS.Tools:Call(HasPetUI)
    if not UnitExists("pet") or (HasPetUI and (not H:Safe(hunter) or not hunter))
        or not H:Safe(happiness) or type(happiness)~="number" or not moods[happiness] then
        badge.mood=nil; badge.damage=nil; badge:Hide(); return
    end
    badge.mood=happiness; badge.damage=FS.Tools:Number(damage) and damage or nil
    badge.icon:SetAtlas(moods[happiness].atlas); badge:Show()
end
function U:PetHappinessTooltip(badge)
    self:RefreshPetHappiness(); local mood=badge.mood and moods[badge.mood]; if not mood then return end
    GameTooltip:SetOwner(badge,"ANCHOR_RIGHT")
    GameTooltip:AddLine(_G["PET_HAPPINESS"..badge.mood] or mood.title)
    GameTooltip:AddLine(mood.note,1,1,1,true)
    if badge.damage then GameTooltip:AddLine("Pet damage: "..H:Number(badge.damage).."%",1,1,1) end
    local get=C_PetInfo and C_PetInfo.GetPetFoodTypes or GetPetFoodTypes
    local diet=FS.Tools:Call(get); local names={}
    if type(diet)=="table" then for _,food in ipairs(diet) do
        if H:Safe(food) and type(food)=="string" then names[#names+1]=food end
    end end
    if #names>0 then GameTooltip:AddLine("Diet: "..table.concat(names,", "),1,1,1,true) end
    GameTooltip:Show()
end
function U:ApplyPetDefault()
    if InCombatLockdown() or not FS.db then return end
    local pet,player=self.frames.pet,self.frames.player
    local position=FS.db.unitFrames.pet
    -- A saved mover placement (including its scale) always wins. Keep legacy
    -- hand-positioned pets too; only the original default follows the player.
    if not pet or not player or FS.db.layout.frames["Unit:pet"] or position.x~=-430 or position.y~=150 then return end
    local scale=player:GetScale()*.75
    pet:SetScale(scale)
    local point,relative,anchor,x,y=pet:GetPoint()
    if pet:GetNumPoints()~=1 or point~="TOPLEFT" or relative~=player or anchor~="BOTTOMLEFT" or x~=0 or y~=-36 then
        pet:ClearAllPoints(); pet:SetPoint("TOPLEFT",player,"BOTTOMLEFT",0,-36)
    end
end
function U:CreateGroup(kind,count)
    self.groups=self.groups or {}
    if self.groups[kind] then return end
    local header=CreateFrame("Frame","ForeverSuite"..kind.."Group",UIParent,"SecureHandlerStateTemplate"); self.groups[kind]=header
    header:SetSize(kind=="party" and 180 or 552,kind=="party" and 256 or 272)
    for i=1,count do
        local unit=kind..i; local f=self:CreateUnit(unit); f:SetParent(header); f.portrait:SetAlpha(0)
        local raid=kind=="raid"; local width=raid and 108 or 176
        f:SetSize(width,raid and 32 or 50)
        f.health:ClearAllPoints(); f.health:SetPoint("TOPLEFT",4,-4); f.health:SetSize(width-8,raid and 23 or 34)
        f.name:SetWidth(width-16); f.value:SetWidth(width-16); FS:ApplyFont(f.name,raid and 10 or 12); FS:ApplyFont(f.value,raid and 9 or 11)
        f.name:ClearAllPoints(); f.name:SetPoint("TOPLEFT",4,-2); f.value:ClearAllPoints(); f.value:SetPoint("BOTTOMRIGHT",-4,1)
        f.power:ClearAllPoints(); f.power:SetPoint("TOPLEFT",4,raid and -28 or -40); f.power:SetSize(width-8,raid and 2 or 6)
        f.cast:SetSize(width,10); f.cast.label:SetWidth(width-10); FS:ApplyFont(f.cast.label,9)
    end
end
local oldNormalize=U.NormalizeSettings
function U:NormalizeSettings()
    oldNormalize(self)
    local db=FS.db.unitFrames; local V=FS.modules.Vendor
    for _,unit in ipairs({"focus","pet","party","raid"}) do
        db[unit].x=V:ValidNumber(db[unit].x,-10000,10000) or 0; db[unit].y=V:ValidNumber(db[unit].y,0,2000) or 400
    end
end
function U:SettingsChanged()
    self:NormalizeSettings()
    if InCombatLockdown() then self.pending=true; self:RefreshSettings(); return end
    self.active=FS:IsModuleEnabled(self.name); self.pending=false
    if not self.frames.player then self:CreateUnit("player"); self:CreateUnit("target") end
    if not self.frames.focus then self:CreateUnit("focus") end
    if not self.frames.pet then self:CreateUnit("pet") end
    self:CreateGroup("party",4); self:CreateGroup("raid",40)
    local db=FS.db.unitFrames
    for unit,f in pairs(self.frames) do
        local kind=unit:match("^(party)") or unit:match("^(raid)")
        UnregisterUnitWatch(f); f:ClearAllPoints()
        if kind then
            local i=tonumber(unit:match("(%d+)$"))-1
            f:SetPoint("TOPLEFT",self.groups[kind],"TOPLEFT",kind=="raid" and (i%5)*112 or 0,kind=="raid" and -math.floor(i/5)*34 or -i*64)
            f:SetScale(1)
        else f:SetPoint("CENTER",UIParent,"BOTTOM",db[unit].x,db[unit].y); f:SetScale(db.scale) end
        local enabled=self.active and (unit~="pet" or db.showPet) and (unit~="focus" or db.showFocus) and (kind~="party" or db.showParty) and (kind~="raid" or db.showRaid)
        if enabled then RegisterUnitWatch(f); self:RefreshUnit(unit) else f:Hide() end
    end
    for kind,header in pairs(self.groups) do
        header:ClearAllPoints(); header:SetPoint("CENTER",UIParent,"BOTTOM",db[kind].x,db[kind].y); header:SetScale(db.scale)
        local enabled=self.active and (kind=="party" and db.showParty or kind=="raid" and db.showRaid)
        if enabled then RegisterStateDriver(header,"visibility",kind=="party" and "[group:raid] hide; [group:party] show; hide" or "[group:raid] show; hide")
        else if UnregisterStateDriver then UnregisterStateDriver(header,"visibility") end; header:Hide() end
    end
    self:ApplyPetDefault()
    self:Native(self.active); self:RefreshSettings(); FS.Layout:Collect(); FS.Layout:ApplyAll()
end
local oldNative=U.Native
function U:Native(enabled)
    oldNative(self,enabled)
    local db=FS.db.unitFrames
    for _,entry in ipairs({{"PetFrame","showPet"},{"FocusFrame","showFocus"},{"PartyFrame","showParty"},{"PartyMemberFrame1","showParty"},{"PartyMemberFrame2","showParty"},{"PartyMemberFrame3","showParty"},{"PartyMemberFrame4","showParty"},{"CompactPartyFrame","showParty"},{"CompactRaidFrameContainer","showRaid"}}) do
        local f=_G[entry[1]]
        if f and not (f.IsForbidden and f:IsForbidden()) then
            if not self.originals[f] then
                self.originals[f]={alpha=f:GetAlpha(),mouse=f:IsMouseEnabled()}
                local key=entry[2]
                hooksecurefunc(f,"SetAlpha",function(frame)
                    if self.active and FS.db.unitFrames[key] and not self.settingAlpha then self.settingAlpha=true; frame:SetAlpha(0); self.settingAlpha=false end
                end)
            end
            local hide=enabled and db[entry[2]]; self.settingAlpha=true; f:SetAlpha(hide and 0 or self.originals[f].alpha); self.settingAlpha=false
            FS.modules.Character:NativeMouse(f,hide)
        end
    end
end
local oldRefresh=U.RefreshUnit
function U:RefreshUnit(unit)
    oldRefresh(self,unit)
    if unit:match("^raid") and self.frames[unit] then self.frames[unit].cast:Hide() end
end
local oldInitialize=U.Initialize
function U:Initialize()
    oldInitialize(self)
    FS:RegisterClientEvent(self.events,"GROUP_ROSTER_UPDATE"); FS:RegisterClientEvent(self.events,"PLAYER_FOCUS_CHANGED")
    FS:RegisterClientEvent(self.events,"UNIT_HAPPINESS"); FS:RegisterClientEvent(self.events,"PET_UI_UPDATE")
    local original=self.events:GetScript("OnEvent")
    self.events:SetScript("OnEvent",function(frame,event,unit)
        if event=="UNIT_HAPPINESS" or event=="PET_UI_UPDATE" then self:RefreshPetHappiness()
        elseif event=="UNIT_PET" and unit=="player" then self:RefreshUnit("pet"); self:RefreshPetHappiness()
        elseif event=="GROUP_ROSTER_UPDATE" then self:SettingsChanged()
        elseif unit and self.frames[unit] then self:RefreshUnit(unit)
        elseif event=="PLAYER_FOCUS_CHANGED" then self:RefreshUnit("focus")
        else original(frame,event,unit) end
    end)
end
local oldSettings=U.CreateSettings
function U:CreateSettings(host)
    local f=oldSettings(self,host)
    f.groupInfo=H:Label(f,"Player, pet, target, focus, party and raid. Use Move Frames to place or resize a whole group.",20,-285,850)
    f.reset:SetScript("OnClick",function()
        local db=FS.db.unitFrames; db.scale=1
        for _,unit in ipairs({"player","target","pet","focus","party","raid"}) do
            local defaults=FS.defaults.unitFrames[unit]; db[unit]={x=defaults.x,y=defaults.y}
            FS.db.layout.frames[(unit=="party" or unit=="raid") and "UnitGroup:"..unit or "Unit:"..unit]=nil
        end
        self:SettingsChanged()
    end)
    f.focus=H:Button(f,"",20,-235,260,function() FS.db.unitFrames.showFocus=not FS.db.unitFrames.showFocus; self:SettingsChanged() end)
    f.party=H:Button(f,"",310,-235,260,function() FS.db.unitFrames.showParty=not FS.db.unitFrames.showParty; self:SettingsChanged() end)
    f.raid=H:Button(f,"",600,-235,250,function() FS.db.unitFrames.showRaid=not FS.db.unitFrames.showRaid; self:SettingsChanged() end)
    f.pet=H:Button(f,"",20,-325,260,function() FS.db.unitFrames.showPet=not FS.db.unitFrames.showPet; self:SettingsChanged() end)
    self:RefreshSettings(); return f
end
local oldSettingsRefresh=U.RefreshSettings
function U:RefreshSettings()
    oldSettingsRefresh(self)
    local f=self.settings; if not f or not f.focus then return end
    for _,entry in ipairs({{"pet","showPet","Pet"},{"focus","showFocus","Focus"},{"party","showParty","Party"},{"raid","showRaid","Raid"}}) do f[entry[1]]:SetText(entry[3]..": "..(FS.db.unitFrames[entry[2]] and "On" or "Off")) end
end
