local _,FS=...
local N,H=FS.modules.Nameplates,FS.HUD
N.colors={Cyan={.12,.72,.86},Gold={.95,.68,.24},Red={.85,.12,.16},Green={.18,.75,.45},Blue={.22,.52,1},Purple={.65,.45,.95},Pink={.91,.39,.78},Orange={1,.46,.17},White={.9,.94,1},Gray={.45,.5,.55},None={0,0,0}}
N.colorNames={"Cyan","Gold","Red","Green","Blue","Purple","Pink","Orange","White","Gray"}
N.designDefaults={width=190,height=22,fontSize=13,valueFontSize=11,castHeight=16,auraSize=17,auraCount=4,auraSpacing=3,
    showName=true,showLevel=true,showHealth=true,showThreat=true,showCast=true,castIcon=false,castTime=false,
    debuffs=true,auraType="Debuffs",onlyMine=false,auraCountdown=true,classColors=true,threatColors=false,
    enemyColor="Red",friendlyColor="Green",borderColor="Cyan",targetColor="Gold",castColor="Cyan",targetHighlight=true,
    targetScale=1,otherOpacity=1,outline=true,healthFormat="Value + percent",nameAlign="CENTER",healthAlign="RIGHT",
    positions={name={x=0,y=17},healthText={x=4,y=-2},level={x=4,y=-3},threat={x=0,y=32},cast={x=0,y=-4},auras={x=0,y=-45}}}
for key,value in pairs(N.designDefaults) do FS.defaults.nameplates[key]=value end
N.designGroups={
    {name="Bars",options={{key="width",label="Health width",min=80,max=360,step=10},{key="height",label="Health height",min=8,max=50,step=2},
        {key="scale",label="Overall size",min=.6,max=1.4,step=.05},{key="targetScale",label="Target size multiplier",min=1,max=1.5,step=.05},
        {key="otherOpacity",label="Other plates opacity",min=.2,max=1,step=.1},{key="showCast",label="Show cast bar"},
        {key="castHeight",label="Cast height",min=8,max=32,step=2},{key="castIcon",label="Cast spell icon"},
        {key="castTime",label="Cast time remaining"},{key="showHealth",label="Show health text"}}},
    {name="Text",options={{key="showName",label="Show name"},{key="fontSize",label="Name font size",min=8,max=24,step=1},
        {key="valueFontSize",label="Detail font size",min=8,max=20,step=1},{key="outline",label="Text outline"},
        {key="showLevel",label="Show level"},{key="showThreat",label="Show threat text"},
        {key="healthFormat",label="Health format",values={"Value + percent","Percent","Value","Current / maximum"}},
        {key="nameAlign",label="Name alignment",values={"CENTER","LEFT","RIGHT"}},{key="healthAlign",label="Health alignment",values={"RIGHT","CENTER","LEFT"}}}},
    {name="Colors",options={{key="classColors",label="Player class colors"},{key="threatColors",label="Enemy threat colors"},
        {key="enemyColor",label="Enemy color",values=N.colorNames},{key="friendlyColor",label="Friendly color",values=N.colorNames},
        {key="borderColor",label="Border color",values={"Cyan","Gold","Red","Green","Blue","Purple","Pink","Orange","White","Gray","None"}},
        {key="targetColor",label="Target outline color",values=N.colorNames},{key="targetHighlight",label="Highlight your target"},{key="castColor",label="Cast color",values=N.colorNames}}},
    {name="Auras",options={{key="debuffs",label="Show aura icons"},{key="auraType",label="Aura type",values={"Debuffs","Buffs"}},
        {key="onlyMine",label="Only your auras"},{key="auraCount",label="Maximum icons",min=1,max=8,step=1},
        {key="auraSize",label="Icon size",min=12,max=36,step=1},{key="auraSpacing",label="Icon spacing",min=0,max=12,step=1},{key="auraCountdown",label="Aura cooldown display"}}},
}
function N:CopyDesign(value)
    if type(value)~="table" then return value end
    local result={}; for key,item in pairs(value) do result[key]=self:CopyDesign(item) end; return result
end
function N:NormalizeDesign()
    local db=FS.db.nameplates; FS:ApplyDefaults(db,self.designDefaults)
    for _,group in ipairs(self.designGroups) do for _,option in ipairs(group.options) do
        local value=db[option.key]
        if option.min then
            value=FS.modules.Vendor:ValidNumber(value,option.min,option.max)
            db[option.key]=value or FS.defaults.nameplates[option.key]
            if option.step>=1 then db[option.key]=math.floor(db[option.key]+.5) end
        elseif option.values then
            local valid=false; for _,choice in ipairs(option.values) do if value==choice then valid=true; break end end
            if not valid then db[option.key]=FS.defaults.nameplates[option.key] end
        elseif type(value)~="boolean" then db[option.key]=self.designDefaults[option.key] end
    end end
    for key,position in pairs(self.designDefaults.positions) do
        for _,axis in ipairs({"x","y"}) do db.positions[key][axis]=FS.modules.Vendor:ValidNumber(db.positions[key][axis],-300,300) or position[axis] end
    end
    if self.designData~=db then self.designData=db; self.appliedDesign=self:CopyDesign(db); self.appearancePending=false; self.combatDesign=nil end
end
function N:Design()
    if self.appearancePending then
        if not self.combatDesign then self.combatDesign=self:CopyDesign(self.appliedDesign or FS.defaults.nameplates) end
        return self.combatDesign
    end
    return FS.db.nameplates
end
function N:HealthText(current,maximum,db)
    if not H:Safe(current) or not H:Safe(maximum) or type(current)~="number" or type(maximum)~="number" or maximum<=0 then return "" end
    local percent=math.floor(current/maximum*100+.5).."%"
    if db.healthFormat=="Percent" then return percent end
    if db.healthFormat=="Value" then return H:Number(current) end
    if db.healthFormat=="Current / maximum" then return H:Number(current).." / "..H:Number(maximum) end
    return H:Number(current).." | "..percent
end
function N:CreateExtras(f)
    f.auraAnchor=CreateFrame("Frame",nil,f); f.auraAnchor:EnableMouse(false)
    f.cast.icon=f.cast:CreateTexture(nil,"ARTWORK"); f.cast.icon:Hide()
    f.cast.time=H:Label(f.cast,"",0,0,48); f.cast.time:SetJustifyH("RIGHT")
    f.cast:HookScript("OnUpdate",function(bar)
        if not bar.fsShowTime or not bar.fsEnd then bar.time:SetText(""); return end
        bar.time:SetText(string.format("%.1fs",math.max(0,bar.fsEnd/1000-GetTime())))
    end)
end
function N:PartPoint(region,owner,key,relative,db)
    local p=db.positions[key]; region:ClearAllPoints(); region:SetPoint("TOPLEFT",owner,relative or "TOPLEFT",p.x,p.y)
end
function N:StyleCanvas(f,db)
    local parts={}
    for _,key in ipairs({"width","height","scale","fontSize","valueFontSize","outline","showName","showLevel","showHealth","showThreat","nameAlign","healthAlign","castHeight","castTime","auraCount","auraSize","auraSpacing","auraCountdown"}) do parts[#parts+1]=tostring(db[key]) end
    for _,key in ipairs({"name","healthText","level","threat","cast","auras"}) do parts[#parts+1]=db.positions[key].x; parts[#parts+1]=db.positions[key].y end
    local signature=table.concat(parts,":"); if f.fsStyleSignature==signature then return end; f.fsStyleSignature=signature
    f:SetSize(db.width,db.height); f:SetScale(db.scale)
    f.health:ClearAllPoints(); f.health:SetPoint("TOPLEFT",2,-2); f.health:SetSize(db.width-4,db.height-4)
    f.name:SetSize(db.width,db.fontSize+4); self:PartPoint(f.name,f,"name",nil,db); FS:ApplyFont(f.name,db.fontSize,db.outline and "OUTLINE" or ""); f.name:SetJustifyH(db.nameAlign); f.name:SetShown(db.showName)
    f.value:SetSize(db.width-12,db.valueFontSize+4); self:PartPoint(f.value,f.health,"healthText",nil,db); f.value:SetJustifyH(db.healthAlign); f.value:SetShown(db.showHealth)
    f.level:SetSize(38,db.valueFontSize+4); self:PartPoint(f.level,f,"level","TOPRIGHT",db); f.level:SetShown(db.showLevel)
    f.threat:SetSize(db.width,db.valueFontSize+4); self:PartPoint(f.threat,f,"threat",nil,db); f.threat:SetShown(db.showThreat)
    for _,label in ipairs({f.value,f.level,f.threat,f.cast.label,f.cast.time}) do FS:ApplyFont(label,db.valueFontSize,db.outline and "OUTLINE" or "") end
    self:PartPoint(f.cast,f,"cast","BOTTOMLEFT",db); f.cast:SetSize(db.width,db.castHeight)
    f.cast.label:SetWidth(db.width-(db.castTime and 58 or 10)); f.cast.label:SetHeight(db.castHeight-2)
    f.cast.time:ClearAllPoints(); f.cast.time:SetPoint("RIGHT",-4,0); f.cast.time:SetHeight(db.castHeight); f.cast.time:SetShown(db.castTime)
    f.cast.icon:SetSize(db.castHeight,db.castHeight); f.cast.icon:ClearAllPoints(); f.cast.icon:SetPoint("RIGHT",f.cast,"LEFT",-3,0)
    self:PartPoint(f.auraAnchor,f,"auras",nil,db); f.auraAnchor:SetSize(db.auraCount*(db.auraSize+db.auraSpacing)-db.auraSpacing,db.auraSize)
    for i,cell in ipairs(f.auras or {}) do
        cell:ClearAllPoints(); cell:SetPoint("TOPLEFT",f.auraAnchor,"TOPLEFT",(i-1)*(db.auraSize+db.auraSpacing),0); cell:SetSize(db.auraSize,db.auraSize)
        if cell.cooldown.SetHideCountdownNumbers then cell.cooldown:SetHideCountdownNumbers(not db.auraCountdown) end
    end
end
function N:HealthColor(unit,threat,db)
    local enemy=UnitCanAttack("player",unit)
    if db.threatColors and H:Safe(enemy) and enemy and type(threat)=="number" and threat>0 then
        return unpack(self.colors[threat==3 and "Red" or threat==2 and "Orange" or "Gold"])
    end
    local player=UnitIsPlayer(unit)
    if db.classColors and H:Safe(player) and player then return H:Color(unit) end
    return unpack(self.colors[H:Safe(enemy) and enemy and db.enemyColor or db.friendlyColor])
end
function N:Paint(f,unit,selected,threat,db)
    f.health:SetStatusBarColor(self:HealthColor(unit,threat,db))
    local color=self.colors[selected and db.targetHighlight and db.targetColor or db.borderColor]
    f:SetBackdropBorderColor(color[1],color[2],color[3],db.borderColor=="None" and not (selected and db.targetHighlight) and 0 or 1)
    f:SetScale(db.scale*(selected and db.targetScale or 1)); f:SetAlpha((selected or not UnitExists("target")) and 1 or db.otherOpacity)
end
function N:CastAppearance(f,unit,db)
    local bar=f.cast; bar.fsShowTime=db.castTime; bar.fsEnd=nil; bar.icon:Hide(); bar.time:SetText("")
    if not db.showCast then bar:Hide(); return end
    if not bar:IsShown() then return end
    local name,_,icon,_,ending,_,_,locked=FS.Tools:Call(UnitCastingInfo,unit)
    if not name then name,_,icon,_,ending,_,locked=FS.Tools:Call(UnitChannelInfo,unit) end
    local color=self.colors[locked and "Gray" or db.castColor]; bar:SetStatusBarColor(unpack(color))
    if H:Safe(icon) and icon and db.castIcon then bar.icon:SetTexture(icon); bar.icon:Show() end
    if H:Safe(ending) and type(ending)=="number" then bar.fsEnd=ending end
end
function N:ApplyPreset(name)
    if InCombatLockdown() then FS:Print("Leave combat to change the nameplate design."); return end
    local db=FS.db.nameplates
    for key,value in pairs(self.designDefaults) do db[key]=self:CopyDesign(value) end
    db.scale=1
    if name=="Compact" then db.width=150; db.height=16; db.fontSize=11; db.valueFontSize=9; db.castHeight=12; db.auraSize=14; db.healthFormat="Percent"
    elseif name=="Large" then db.width=240; db.height=30; db.fontSize=16; db.valueFontSize=13; db.castHeight=22; db.auraSize=24; db.auraSpacing=4; db.positions.auras.y=-62
    elseif name=="Minimal" then db.height=12; db.fontSize=12; db.showLevel=false; db.showHealth=false; db.showThreat=false; db.debuffs=false; db.castHeight=12 end
    self:SettingsChanged()
end
