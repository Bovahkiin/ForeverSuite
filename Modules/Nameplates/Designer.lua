local _,FS=...
local N,H=FS.modules.Nameplates,FS.HUD
N.parts={{"name","Name"},{"healthText","Health text"},{"level","Level"},{"threat","Threat text"},{"cast","Cast bar"},{"auras","Aura icons"}}
function N:SetDesignOption(option,value)
    if InCombatLockdown() then FS:Print("Leave combat to edit nameplates."); return false end
    if option.min then
        value=FS.modules.Vendor:ValidNumber(tonumber(value),option.min,option.max)
        if not value then return false end
        if option.step>=1 then value=math.floor(value+.5) else value=math.floor(value*100+.5)/100 end
    elseif option.values then
        local valid=false; for _,choice in ipairs(option.values) do if choice==value then valid=true; break end end
        if not valid then return false end
    elseif type(value)~="boolean" then return false end
    FS.db.nameplates[option.key]=value; self:SettingsChanged(); return true
end
function N:MovePart(key,x,y)
    if InCombatLockdown() or not FS.db.nameplates.positions[key] or not FS.Tools:Number(x) or not FS.Tools:Number(y) then return false end
    local p=FS.db.nameplates.positions[key]; x=math.floor(math.max(-300,math.min(300,x))+.5); y=math.floor(math.max(-300,math.min(300,y))+.5)
    if p.x~=x or p.y~=y then p.x,p.y=x,y; self:SettingsChanged() end
    return true
end
function N:StopPartDrag()
    if self.dragPart then self.dragPart.drag=nil; self.dragPart=nil end
end
function N:UpdatePreview()
    local editor=self.editor; if not editor or not editor:IsShown() then return end
    local f,db=editor.preview,FS.db.nameplates; self:StyleCanvas(f,db)
    f.name:SetText("ForeverSuite Training Target"); f.level:SetText("60"); f.value:SetText(self:HealthText(7200,10000,db))
    f.threat:SetText(db.showThreat and "You have aggro" or ""); f.threat:SetTextColor(1,.3,.2)
    f.health:SetMinMaxValues(0,10000); f.health:SetValue(7200); f.health:SetStatusBarColor(unpack(self.colors[db.enemyColor]))
    local border=self.colors[db.targetHighlight and db.targetColor or db.borderColor]
    f:SetBackdropBorderColor(border[1],border[2],border[3],db.borderColor=="None" and not db.targetHighlight and 0 or 1)
    f:SetScale(math.min(db.scale*db.targetScale,(editor.stage:GetWidth()-60)/(db.width+50),(editor.stage:GetHeight()-50)/(db.height+90)))
    f.cast:SetMinMaxValues(0,2); f.cast:SetValue(1.2); f.cast.label:SetText("Frostbolt"); f.cast:SetStatusBarColor(unpack(self.colors[db.castColor])); f.cast:SetShown(db.showCast)
    f.cast.icon:SetTexture(135846); f.cast.icon:SetShown(db.castIcon); f.cast.time:SetText(db.castTime and "1.2s" or "")
    for i,cell in ipairs(f.auras) do
        cell:SetShown(db.debuffs and i<=db.auraCount); cell.icon:SetTexture(i%2==0 and 135991 or 136208)
        cell.cooldown:SetShown(db.auraCountdown); if db.auraCountdown then cell.cooldown:SetCooldown(GetTime(),20) end
    end
    f:Show()
    local regions={name=f.name,healthText=f.value,level=f.level,threat=f.threat,cast=f.cast,auras=f.auraAnchor}
    local shown={name=db.showName,healthText=db.showHealth,level=db.showLevel,threat=db.showThreat,cast=db.showCast,auras=db.debuffs}
    for key,handle in pairs(editor.handles) do
        handle:ClearAllPoints(); handle:SetAllPoints(regions[key]); handle:SetShown(shown[key]); handle:SetBackdropColor(.12,.72,.86,.04)
        handle:SetBackdropBorderColor(key==self.selectedPart and .95 or .12,key==self.selectedPart and .68 or .72,key==self.selectedPart and .24 or .86,.65)
    end
    for key,b in pairs(editor.partButtons) do b:SetBackdropBorderColor(key==self.selectedPart and .95 or .12,key==self.selectedPart and .68 or .72,key==self.selectedPart and .24 or .86,1) end
    local p=db.positions[self.selectedPart or "name"]
    for _,axis in ipairs({"x","y"}) do if not editor[axis]:HasFocus() then editor[axis]:SetText(tostring(p[axis])) end end
    for _,cell in ipairs(editor.optionCells) do
        local option=cell.option
        if option then
            local value=db[option.key]
            if cell.input then if not cell.input:HasFocus() then cell.input:SetText(tostring(value)) end
            else cell:SetText(option.label..": "..(option.values and tostring(value) or value and "On" or "Off")) end
        end
    end
end
function N:EditorGroup(index)
    if not self.editor then return end
    self.editorGroup=index; local f=self.editor
    for _,cell in ipairs(f.optionCells or {}) do cell:Hide() end
    f.optionCells={}
    f.groupCells=f.groupCells or {}
    local cells=f.groupCells[index]
    if not cells then
        cells={}; f.groupCells[index]=cells
        for i,option in ipairs(self.designGroups[index].options) do
            local x,y=16+(i-1)%2*472,-394-math.floor((i-1)/2)*36
            local cell=H:Button(f,"",x,y,452,function(_,mouse)
                if option.min then return end
                local value=FS.db.nameplates[option.key]
                if option.values then
                    local current=1; for j,choice in ipairs(option.values) do if value==choice then current=j; break end end
                    value=option.values[(current-1+(mouse=="RightButton" and -1 or 1))%#option.values+1]
                else value=not value end
                self:SetDesignOption(option,value)
            end)
            cell.option=option; cells[#cells+1]=cell; cell:RegisterForClicks("LeftButtonUp","RightButtonUp")
            if option.min then
                H:Label(cell,option.label,8,-6,286)
                cell.input=FS.Tools:Edit(cell,338,0,72); cell.input:SetHeight(30)
                local function submit(input)
                    if not self:SetDesignOption(option,input:GetText()) then f.message:SetText("Enter a value from "..option.min.." to "..option.max..".") end
                    input:ClearFocus(); input:SetText(tostring(FS.db.nameplates[option.key]))
                end
                cell.input:SetScript("OnEnterPressed",submit)
                cell.input:SetScript("OnEditFocusLost",function(input) if input:GetText()~=tostring(FS.db.nameplates[option.key]) then submit(input) end end)
                cell.input:SetScript("OnEscapePressed",function(input) input:SetText(tostring(FS.db.nameplates[option.key])); input:ClearFocus() end)
                H:Button(cell,"-",306,0,28,function() self:SetDesignOption(option,math.max(option.min,FS.db.nameplates[option.key]-option.step)) end)
                H:Button(cell,"+",414,0,28,function() self:SetDesignOption(option,math.min(option.max,FS.db.nameplates[option.key]+option.step)) end)
            end
        end
    end
    for _,cell in ipairs(cells) do cell:Show(); f.optionCells[#f.optionCells+1]=cell end
    for i,button in ipairs(f.groupButtons or {}) do button:SetBackdropBorderColor(i==index and .95 or .12,i==index and .68 or .72,i==index and .24 or .86,1) end
    self:UpdatePreview()
end
function N:CreateDesigner()
    if self.editor then return self.editor end
    local f=CreateFrame("Frame","ForeverSuiteNameplateDesigner",UIParent,"BackdropTemplate"); self.editor=f; self.window=f; H:Skin(f)
    f:SetSize(960,650); f:SetPoint("CENTER"); f:SetScale(math.min(1,(UIParent:GetWidth()-32)/960,(UIParent:GetHeight()-32)/650)); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
    H:Label(f,"FOREVERSUITE / NAMEPLATE DESIGNER",20,-18,650)
    H:Button(f,"Back to settings",742,-12,198,function() f:Hide(); FS:ConfigureModule(self.name) end)
    H:Label(f,"Drag the outlined parts. Enter numbers or use +/- below; changes save automatically.",20,-55,918)
    f.stage=CreateFrame("Frame",nil,f,"BackdropTemplate"); H:Skin(f.stage); f.stage:SetSize(696,260); f.stage:SetPoint("TOPLEFT",244,-84); f.stage:SetBackdropColor(.025,.045,.06,.96); f.stage:SetClipsChildren(true)
    H:Label(f.stage,"Example target - preview fits this panel",12,-10,660)
    f.preview=self:CreateCanvas(f.stage); f.preview:SetPoint("CENTER",f.stage,"CENTER",0,0); f.preview.cast:SetScript("OnUpdate",nil)
    f.partButtons={}; f.handles={}; self.selectedPart="name"
    for i,entry in ipairs(self.parts) do
        local key,label=entry[1],entry[2]
        f.partButtons[key]=H:Button(f,label,16,-84-(i-1)*31,208,function() self.selectedPart=key; self:UpdatePreview() end)
        local handle=CreateFrame("Frame",nil,f.preview,"BackdropTemplate"); H:Skin(handle); handle:SetFrameLevel(f.preview:GetFrameLevel()+20); handle:EnableMouse(true); handle:RegisterForDrag("LeftButton"); f.handles[key]=handle
        handle:SetScript("OnMouseDown",function() self.selectedPart=key; self:UpdatePreview() end)
        handle:SetScript("OnDragStart",function(h)
            if InCombatLockdown() or not GetCursorPosition then return end
            local x,y=GetCursorPosition(); if not FS.Tools:Number(x) or not FS.Tools:Number(y) then return end
            self.selectedPart=key; local p=FS.db.nameplates.positions[key]
            h.drag={x=x,y=y,px=p.x,py=p.y,scale=f.preview:GetEffectiveScale()}; self.dragPart=h; self:UpdatePreview()
        end)
        handle:SetScript("OnUpdate",function(h)
            local drag=h.drag; if not drag then return end
            if InCombatLockdown() then self:StopPartDrag(); return end
            local x,y=GetCursorPosition()
            if FS.Tools:Number(x) and FS.Tools:Number(y) and drag.scale>0 then self:MovePart(key,drag.px+(x-drag.x)/drag.scale,drag.py+(y-drag.y)/drag.scale) end
        end)
        handle:SetScript("OnDragStop",function() self:StopPartDrag(); self:UpdatePreview() end)
    end
    H:Label(f,"Position X",16,-280,98); H:Label(f,"Position Y",126,-280,98)
    for i,axis in ipairs({"x","y"}) do
        local input=FS.Tools:Edit(f,16+(i-1)*110,-300,98); f[axis]=input
        local function submit(b)
            local value=tonumber(b:GetText()); local p=FS.db.nameplates.positions[self.selectedPart]
            if not FS.Tools:Number(value) or value<-300 or value>300 or not self:MovePart(self.selectedPart,axis=="x" and value or p.x,axis=="y" and value or p.y) then f.message:SetText("Positions must be between -300 and 300.") end
            b:ClearFocus(); b:SetText(tostring(p[axis]))
        end
        input:SetScript("OnEnterPressed",submit); input:SetScript("OnEditFocusLost",function(b) if b:GetText()~=tostring(FS.db.nameplates.positions[self.selectedPart][axis]) then submit(b) end end)
        input:SetScript("OnEscapePressed",function(b) b:SetText(tostring(FS.db.nameplates.positions[self.selectedPart][axis])); b:ClearFocus() end)
    end
    f.groupButtons={}; for i,group in ipairs(self.designGroups) do f.groupButtons[i]=H:Button(f,group.name,16+(i-1)*158,-352,148,function() self:EditorGroup(i) end) end
    H:Button(f,"Reset selected position",662,-352,278,function() local p=self.designDefaults.positions[self.selectedPart]; self:MovePart(self.selectedPart,p.x,p.y) end)
    f.message=H:Label(f,"Saved automatically. Visibility and V stay in the game's control.",16,-582,920)
    local presets={"ForeverSuite","Compact","Large","Minimal"}
    for i,name in ipairs(presets) do H:Button(f,name,16+(i-1)*138,-610,128,function() self:ApplyPreset(name) end) end
    H:Button(f,"Save current profile",584,-610,216,function() local P=FS.modules.Profiles; if P:Save(FS.db.profiles.current) then f.message:SetText("Current profile updated.") end end)
    H:Button(f,"Close",812,-610,128,function() f:Hide() end)
    f:SetScript("OnHide",function() self:StopPartDrag(); GameTooltip:Hide() end)
    UISpecialFrames[#UISpecialFrames+1]=f:GetName(); f:Hide(); self:EditorGroup(1); return f
end
function N:ShowWindow()
    if InCombatLockdown() then FS:Print("Leave combat to open the nameplate designer."); return end
    self:NormalizeSettings(); local f=self:CreateDesigner(); FS:CloseOtherWindows(f); f:Show(); self:UpdatePreview()
end
function N:CreateSettings(host)
    local f=CreateFrame("Frame",nil,host,"BackdropTemplate"); H:Skin(f); self.settings=f
    f:SetSize(892,420); f:SetPoint("TOPLEFT",24,FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel()+30); f:EnableMouse(true)
    H:Button(f,"Back to Control Center",20,-12,220,function() f:Hide() end); H:Label(f,"Nameplate settings",260,-20,590)
    H:Label(f,"Design your plates with a live sample: drag parts, change text, bars, colors and auras.",20,-70,850)
    f.size=H:Button(f,"",20,-110,400,function() local db=FS.db.nameplates; db.scale=db.scale>=1.4 and .6 or math.floor((db.scale+.1)*10+.5)/10; self:SettingsChanged() end)
    for i,entry in ipairs({{"enemies","Enemies"},{"friendlyPlayers","Friendly players"},{"friendlyNPCs","Friendly NPCs"}}) do
        local key=entry[1]; f[key]=H:Button(f,"",i==1 and 450 or i==2 and 20 or 450,i==1 and -110 or -160,400,function() FS.db.nameplates[key]=not FS.db.nameplates[key]; self:SettingsChanged() end)
    end
    f.status=H:Label(f,"",20,-230,850); f.status:SetHeight(60)
    f.designer=H:Button(f,"Open nameplate designer",20,-330,830,function() self:ShowWindow() end)
    H:Label(f,"Designs are included in Profiles. Nameplates follow their units and stay outside Move Frames.",20,-380,850)
    self:RefreshSettings(); f:Hide(); return f
end
function N:RefreshSettings()
    local f=self.settings
    if f and f.size then
        local db=FS.db.nameplates; f.size:SetText("Size: "..math.floor(db.scale*100+.5).."% (click to change)")
        for _,entry in ipairs({{"enemies","Enemies"},{"friendlyPlayers","Friendly players"},{"friendlyNPCs","Friendly NPCs"}}) do f[entry[1]]:SetText(entry[2]..": "..(db[entry[1]] and "On" or "Off")) end
        f.status:SetText(self.appearancePending and "Appearance changes apply when combat ends." or "Use the designer for sizes, fonts, colors, target emphasis and movable parts.\nNative nameplate targeting remains available.")
    end
    self:UpdatePreview()
end
