local _,FS=...
local N={name="Nameplates",key="nameplates",custom={},nativeStates={}}; FS:RegisterModule(N.name,N)
local H=FS.HUD
local threatLabels={[1]="Threat rising",[2]="Losing threat",[3]="You have aggro"}
function N:Release(saved)
    saved.canvas:Hide(); saved.unit=nil
    local state=self.nativeStates[saved.native]
    if state and state.hidden then
        state.hidden=false
        if not (saved.native.IsForbidden and saved.native:IsForbidden()) then saved.native:SetAlpha(state.alpha) end
    end
end
function N:HideNative(native)
    local state=self.nativeStates[native]
    if not state then
        state={alpha=native:GetAlpha()}; self.nativeStates[native]=state
        hooksecurefunc(native,"SetAlpha",function(frame)
            if state.hidden and not state.setting then state.setting=true; frame:SetAlpha(0); state.setting=false end
        end)
    end
    state.hidden=true; local alpha=native:GetAlpha(); if H:Safe(alpha) and alpha~=0 then native:SetAlpha(0) end
end
function N:NormalizeSettings()
    local db=FS.db.nameplates
    db.scale=FS.modules.Vendor:ValidNumber(db.scale,0.6,1.4) or 1
    for _,key in ipairs({"enemies","friendlyPlayers","friendlyNPCs"}) do
        if type(db[key])~="boolean" then db[key]=key=="enemies" end
    end
    if self.NormalizeDesign then self:NormalizeDesign() end
    FS.db.layout.frames.NameplatePreview=nil
end
function N:Visible(unit)
    local enemy=UnitCanAttack("player",unit)
    if not H:Safe(enemy) then return true end
    if enemy then return FS.db.nameplates.enemies and (not GetCVar or GetCVar("nameplateShowEnemies")~="0") end
    if GetCVar and GetCVar("nameplateShowFriends")=="0" then return false end
    local player=UnitIsPlayer(unit)
    if not H:Safe(player) then return true end
    return player and FS.db.nameplates.friendlyPlayers or (not player and FS.db.nameplates.friendlyNPCs)
end
function N:ApplyVisibility()
    if InCombatLockdown() then self.visibilityPending=true; return end
    if not GetCVar or not SetCVar then return end
    self.visibilityPending=false; self.applyingCVars=true
    local db=FS.db.nameplates
    local values={nameplateShowEnemies=db.enemies,nameplateShowFriends=db.friendlyPlayers or db.friendlyNPCs,nameplateShowFriendlyPlayers=db.friendlyPlayers,nameplateShowFriendlyNPCs=db.friendlyNPCs}
    self.originalCVars=self.originalCVars or {}
    for key,enabled in pairs(values) do
        local current=GetCVar(key)
        if current~=nil then
            if self.originalCVars[key]==nil then self.originalCVars[key]=current end
            local desired=FS:IsModuleEnabled(self.name) and (enabled and "1" or "0") or self.originalCVars[key]
            if current~=desired then SetCVar(key,desired) end
        end
    end
    self.applyingCVars=false
end
function N:RefreshPlates()
    local plates=FS.Tools:Call(C_NamePlate and C_NamePlate.GetNamePlates)
    if H:Safe(plates) and type(plates)=="table" then
        for _,plate in ipairs(plates) do self:Update(plate,plate.namePlateUnitToken) end
    end
end
function N:QueuePlateRefresh()
    if self.plateRefreshQueued then return end
    self.plateRefreshQueued=true
    C_Timer.After(0,function() self.plateRefreshQueued=false; self:RefreshPlates() end)
end
function N:CreateCanvas(parent,anchor)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); f.fsSecretAnchor=true; H:Skin(f,true)
    f.ignoreInLayout=true
    f:SetSize(190,22); f:SetPoint("CENTER",anchor or parent,"CENTER"); f:EnableMouse(false)
    f.health=CreateFrame("StatusBar",nil,f); f.health:SetSize(186,18); f.health:SetPoint("TOPLEFT",2,-2); f.health:SetStatusBarTexture(H.texture)
    f.name=H:Label(f,"",0,17,190); FS:ApplyFont(f.name,13,"OUTLINE"); f.name:SetJustifyH("CENTER")
    f.value=H:Label(f.health,"",4,-2,176); FS:ApplyFont(f.value,11,"OUTLINE"); f.value:SetJustifyH("RIGHT")
    f.level=H:Label(f,"",194,-3,28); FS:ApplyFont(f.level,12,"OUTLINE")
    f.threat=H:Label(f,"",0,32,190); FS:ApplyFont(f.threat,10,"OUTLINE"); f.threat:SetJustifyH("CENTER")
    FS.modules.UnitFrames:CreateCast(f); f.cast:SetSize(190,16); f.cast.label:SetWidth(180)
    if self.CreateExtras then self:CreateExtras(f) end
    return f
end
function N:CreateAuras(f)
    f.auras={}
    for i=1,8 do
        local cell=CreateFrame("Frame",nil,f,"BackdropTemplate"); H:Skin(cell,true); cell:EnableMouse(false)
        cell:SetSize(17,17); cell:SetPoint("TOPLEFT",(i-1)*20,-45)
        cell.icon=cell:CreateTexture(nil,"ARTWORK"); cell.icon:SetAllPoints(); cell.cooldown=CreateFrame("Cooldown",nil,cell,"CooldownFrameTemplate")
        cell.cooldown:SetAllPoints(); cell.cooldown:EnableMouse(false); cell:Hide(); f.auras[i]=cell
    end
end
function N:LayoutCanvas(f,anchor,design)
    if f.fsAnchor~=anchor then f:ClearAllPoints(); f:SetPoint("CENTER",anchor,"CENTER",0,0); f.fsAnchor=anchor end
    if self.StyleCanvas then self:StyleCanvas(f,design or self:Design()) else f:SetScale(FS.db.nameplates.scale) end
end
function N:Update(plate,unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local native=plate.UnitFrame
    if not native or (native.IsForbidden and native:IsForbidden()) then return end
    local saved=self.custom[plate]
    if not FS:IsModuleEnabled(self.name) then
        if saved then self:Release(saved) end
        return
    end
    unit=unit or plate.namePlateUnitToken or native.unit or native.displayedUnit
    if not unit or not UnitExists(unit) then if saved then self:Release(saved) end; return end
    local anchor=(native.HealthBarsContainer and native.HealthBarsContainer.healthBar) or native.healthBar or native
    if not saved then
        saved={canvas=self:CreateCanvas(plate,anchor),native=native}; self.custom[plate]=saved
        plate:HookScript("OnShow",function() self:QueuePlateRefresh() end)
        plate:HookScript("OnHide",function() saved.canvas:Hide() end)
    elseif saved.native~=native then
        self:Release(saved); saved.native=native
    end
    saved.unit=unit; local f=saved.canvas
    local design=self.UnitDesign and self:UnitDesign(unit) or self:Design()
    self:HideNative(native); self:LayoutCanvas(f,anchor,design)
    if not self:Visible(unit) then f:Hide(); return end
    f.name:SetText(UnitName(unit))
    local target=UnitIsUnit and UnitIsUnit(unit,"target")
    local selected=H:Safe(target) and target==true
    local threat=UnitThreatSituation and UnitThreatSituation("player",unit)
    if not H:Safe(threat) then threat=nil end
    f.threat:SetText(threatLabels[threat] or ""); f.threat:SetTextColor(1,threat==3 and .3 or .75,.2)
    local health,maximum=UnitHealth(unit),UnitHealthMax(unit)
    f.health:SetMinMaxValues(0,maximum); f.health:SetValue(health)
    if H:Safe(health) and H:Safe(maximum) and type(health)=="number" and type(maximum)=="number" and maximum>0 then
        f.value:SetText(self:HealthText(health,maximum,design))
    else f.value:SetText("") end
    local level=UnitLevel and UnitLevel(unit)
    f.level:SetText(H:Safe(level) and type(level)=="number" and (level<0 and "??" or tostring(level)) or "")
    FS.modules.UnitFrames:RefreshCast(unit,f)
    local db=design; self:Paint(f,unit,selected,threat,db); self:CastAppearance(f,unit,db)
    local auraAccess=true
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        auraAccess=FS.Tools:Call(C_Secrets.ShouldAurasBeSecret)==false
    end
    local filter=db.auraType=="Buffs" and "HELPFUL" or "HARMFUL"
    if db.onlyMine then filter=filter.."|PLAYER" end
    local readAuras=auraAccess and db.debuffs and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for i=1,f.auras and #f.auras or (readAuras and db.auraCount or 0) do
        local aura
        if readAuras and i<=db.auraCount then
            aura=FS.Tools:Call(readAuras,unit,i,filter)
        end
        if not H:Safe(aura) or type(aura)~="table" then aura=nil end
        if aura and not f.auras then self:CreateAuras(f); self:StyleAuras(f,db) end
        local cell=f.auras and f.auras[i]
        if aura then
            cell.icon:SetTexture(aura.icon); if not cell:IsShown() then cell:Show() end
            local d,e=aura.duration,aura.expirationTime
            if db.auraCountdown and H:Safe(d) and H:Safe(e) and type(d)=="number" and type(e)=="number" and d>0 then
                if cell.duration~=d or cell.expiration~=e then
                    cell.cooldown:SetCooldown(e-d,d); cell.duration,cell.expiration=d,e
                end
                if not cell.cooldown:IsShown() then cell.cooldown:Show() end
            else cell.cooldown:Hide(); cell.duration,cell.expiration=nil,nil end
        elseif cell then
            if cell:IsShown() then cell:Hide() end
            if cell.cooldown:IsShown() then cell.cooldown:Hide() end
            cell.duration,cell.expiration=nil,nil
        end
    end
    f:Show()
end
function N:SettingsChanged()
    self:NormalizeSettings(); self:ApplyVisibility()
    if InCombatLockdown() then
        self.appearancePending=true; self:RefreshSettings()
        if not FS:IsModuleEnabled(self.name) then for _,saved in pairs(self.custom) do self:Release(saved) end end
        return
    end
    self.appearancePending=false; self.combatDesign=nil; self.appliedDesign=self:CopyDesign(FS.db.nameplates)
    self:RefreshSettings()
    self:RefreshPlates()
    if self.UpdatePreview then self:UpdatePreview() end
    if not FS:IsModuleEnabled(self.name) then
        for _,saved in pairs(self.custom) do
            self:Release(saved)
        end
    end
end
function N:Initialize()
    self.events=CreateFrame("Frame")
    FS:RegisterClientEvent(self.events,"UNIT_THREAT_SITUATION_UPDATE"); FS:RegisterClientEvent(self.events,"UNIT_THREAT_LIST_UPDATE")
    for _,e in ipairs({"CVAR_UPDATE","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE","UNIT_FACTION","UNIT_AURA","UNIT_SPELLCAST_START","UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_UPDATE","UNIT_SPELLCAST_CHANNEL_STOP","PLAYER_TARGET_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED"}) do FS:RegisterClientEvent(self.events,e) end
    self.events:SetScript("OnEvent",function(_,event,unit)
        if event=="CVAR_UPDATE" then
            local name=type(unit)=="string" and unit:lower() or ""
            if not self.applyingCVars and name:find("nameplate",1,true) then
                if name=="nameplateshowenemies" and GetCVar then FS.db.nameplates.enemies=GetCVar("nameplateShowEnemies")=="1" end
                for key in pairs(self.originalCVars or {}) do
                    if key:lower()==name and GetCVar then self.originalCVars[key]=GetCVar(key) end
                end
                self:RefreshSettings(); self:QueuePlateRefresh()
            end
        elseif event=="PLAYER_ENTERING_WORLD" then self:SettingsChanged()
        elseif event=="PLAYER_REGEN_ENABLED" then
            if self.visibilityPending or self.appearancePending then self:SettingsChanged() else self:RefreshPlates() end
        elseif event=="UNIT_THREAT_SITUATION_UPDATE" or event=="UNIT_THREAT_LIST_UPDATE" then
            for plate,saved in pairs(self.custom) do if saved.unit then self:Update(plate,saved.unit) end end
        elseif event=="NAME_PLATE_UNIT_REMOVED" then
            if H:Safe(unit) and type(unit)=="string" then
                for _,saved in pairs(self.custom) do if saved.unit==unit then self:Release(saved) end end
            end
        elseif H:Safe(unit) and type(unit)=="string" then
            -- UNIT_* also fires for targettarget/pettarget. Those tokens are
            -- rejected by GetNamePlateForUnit; only resolve documented units.
            if unit=="target" or unit=="focus" or unit:match("^nameplate%d+$") then
                self:Update(FS.Tools:Call(C_NamePlate and C_NamePlate.GetNamePlateForUnit,unit),unit)
            end
        else self:RefreshPlates() end
    end)
    self:SettingsChanged()
end
