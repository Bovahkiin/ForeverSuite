local _,FS=...
local F={regions=setmetatable({},{__mode="k"}),roots=setmetatable({},{__mode="k"})}; FS.Typography=F
local moduleRootKeys={"settings","window","root","tracker","navigator","coordinateFrame","indicator","editor","menuRoot","clock","bar"}
local defaults={family="Default",scale=1,weight="Default",outline="Default",shadow="Default",size=0}
FS.defaults.typography={global=defaults,modules={},scope="All modules"}
F.families={Default=FS.font,["Arial Narrow"]=FS.font,["Friz Quadrata"]="Fonts\\FRIZQT__.TTF",["Morpheus"]="Fonts\\MORPHEUS.TTF",["Skurri"]="Fonts\\SKURRI.TTF",["Arial Bold"]="Interface\\AddOns\\ForeverSuite\\Assets\\Arial-Bold.ttf"}
F.options={{key="family",label="Font",values={"Default","Arial Narrow","Friz Quadrata","Morpheus","Skurri","Arial Bold"}},
    {key="scale",label="Text size multiplier",values={.8,.9,1,1.1,1.2,1.3,1.4,1.5}},
    {key="size",label="Fixed size (0 = original sizes)",values={0,10,12,14,16,18,20,22,24}},
    {key="weight",label="Weight",values={"Default","Normal","Bold"}},
    {key="outline",label="Outline",values={"Default","None","Thin","Thick"}},
    {key="shadow",label="Shadow",values={"Default","Off","On"}}}
local function copy(t) local result={}; for k,v in pairs(t) do result[k]=type(v)=="table" and copy(v) or v end; return result end
function F:Normalize()
    local db=FS.db.typography; FS:ApplyDefaults(db,FS.defaults.typography)
    local function normalize(style)
        FS:ApplyDefaults(style,defaults)
        for _,o in ipairs(self.options) do local ok=false; for _,v in ipairs(o.values) do if style[o.key]==v then ok=true; break end end; if not ok then style[o.key]=defaults[o.key] end end
    end
    normalize(db.global)
    for name,style in pairs(db.modules) do if not FS.modules[name] or type(style)~="table" then db.modules[name]=nil else normalize(style) end end
    if db.scope~="All modules" and not FS.modules[db.scope] then db.scope="All modules" end
end
function F:Owner(region)
    local frame=region
    for _=1,16 do
        if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
        if frame.fsFontModule then return frame.fsFontModule end
        for _,d in ipairs(FS.NativeWindows and FS.NativeWindows.definitions or {}) do if frame==_G[d[1]] then frame.fsFontModule=d[2]; return d[2] end end
        if frame==CharacterFrame then return "Character" end
        local name=frame.GetName and frame:GetName() or ""; if type(name)~="string" then name="" end
        if name:match("^ChatFrame%d") then return "Chat" end
        for moduleName,module in pairs(FS.modules) do
            for _,key in ipairs(moduleRootKeys) do if module[key]==frame then frame.fsFontModule=moduleName; return moduleName end end
            if module.frames then for _,unit in pairs(module.frames) do if unit==frame then frame.fsFontModule=moduleName; return moduleName end end end
            if module.custom then for _,saved in pairs(module.custom) do if type(saved)=="table" and saved.canvas==frame then frame.fsFontModule=moduleName; return moduleName end end end
        end
        frame=frame.GetParent and frame:GetParent()
    end
    return "Core"
end
function FS:StyleFont(region,size,flags)
    if not self.db or not self.db.typography or (region.IsForbidden and region:IsForbidden()) then return end
    if not F.appliedData and not F.pending then F.appliedData=copy(self.db.typography) end
    local state=F.regions[region]
    if not state then
        local path,oldSize,oldFlags=region:GetFont()
        state={size=oldSize or 12,flags=oldFlags or "",path=self.font,shadow=region.GetShadowOffset and {region:GetShadowOffset()} or {0,0}}
        if path==F.families["Arial Bold"] then state.path=path end
        F.regions[region]=state
    end
    if size then state.size=size end; if flags~=nil then state.flags=flags end; state.active=true
    local owner=F:Owner(region); local data=F.pending and (F.appliedData or FS.defaults.typography) or self.db.typography; local style=data.modules[owner] or data.global
    local path=style.family=="Default" and state.path or F.families[style.family]
    if style.weight=="Bold" then path=F.families["Arial Bold"] elseif style.weight=="Normal" and path==F.families["Arial Bold"] then path=self.font end
    local outline=style.outline=="Default" and state.flags or style.outline=="Thin" and "OUTLINE" or style.outline=="Thick" and "THICKOUTLINE" or ""
    local fontSize=math.max(8,math.min(36,(style.size>0 and style.size or state.size)*style.scale))
    local oldPath,oldSize,oldOutline=region:GetFont()
    if not state.applied or oldPath~=path or oldSize~=fontSize or (oldOutline or "")~=outline then region:SetFont(path,fontSize,outline) end
    state.applied=true
    if region.SetShadowOffset then
        if style.shadow=="Default" then region:SetShadowOffset(unpack(state.shadow)) else region:SetShadowOffset(style.shadow=="On" and 1 or 0,style.shadow=="On" and -1 or 0) end
    end
end
function FS:ReleaseFont(region) if F.regions[region] then local state=F.regions[region]; state.active=false; if region.SetShadowOffset then region:SetShadowOffset(unpack(state.shadow)) end end end
local function discoverRoot(self,frame,owner)
    if not frame or type(frame.GetRegions)~="function" or (frame.IsForbidden and frame:IsForbidden()) then return end
    frame.fsFontModule=owner
    if not self.roots[frame] then self.roots[frame]=true; FS:FontTree(frame) end
end
function F:Discover()
    discoverRoot(self,FS.window,"Core")
    discoverRoot(self,FS.aboutWindow,"Core")
    discoverRoot(self,self.window,"Core")
    for name,module in pairs(FS.modules) do
        for _,key in ipairs(moduleRootKeys) do discoverRoot(self,module[key],name) end
        if module.frames then for _,frame in pairs(module.frames) do discoverRoot(self,frame,name) end end
        if module.custom then
            for _,saved in pairs(module.custom) do
                if type(saved)=="table" then discoverRoot(self,saved.canvas,name) end
            end
        end
    end
end
function F:Apply()
    self:Normalize()
    if InCombatLockdown() then self.pending=true; return end
    self.pending=false; self.appliedData=copy(FS.db.typography); self:Discover()
    FS.fontGeneration=(FS.fontGeneration or 0)+1
    for region,state in pairs(self.regions) do if state.active then FS:ApplyFont(region) end end
    if FS.LayoutConfigText then FS:LayoutConfigText() end
    if FS.Layout and FS.Layout.overlay then FS.Layout:UpdateToolbar() end
    if FS.aboutWindow and FS.aboutWindow.LayoutText then FS.aboutWindow:LayoutText() end
    for _,module in pairs(FS.modules) do
        if module.settings and module.settings.LayoutText then module.settings:LayoutText() end
        if module.window and module.window.LayoutText then module.window:LayoutText() end
    end
    if FS:IsModuleEnabled("Character") and FS.modules.Character and FS.modules.Character.root then FS.modules.Character:RefreshCharacter() end
    if FS.modules.Bags and FS.modules.Bags.window and FS.modules.Bags.window:IsShown() then FS.modules.Bags:Refresh() end
    if FS.modules.Quests and FS.modules.Quests.tracker then FS.modules.Quests:UpdateTracker() end
    if FS.window then
        if FS.window.settings and FS.window.settings.fsSettingsName then FS:ThemeSettings(FS.window.settings,FS.window.settings.fsSettingsName) end
        for name,module in pairs(FS.modules) do if module.settings and module.settings.fsSettingsName then FS:ThemeSettings(module.settings,name) end end
    end
    if FS.NativeWindows then FS.NativeWindows:Refresh() end
    if FS.Installer and FS.Installer.window and FS.Installer.window:IsShown() then FS.Installer:Refresh() end
    local units=FS.modules.UnitFrames
    if units then for _,frame in pairs(units.frames) do units:LayoutLevel(frame) end end
    -- Save text edits into the active profile immediately, including edits from search.
    local manager=FS.db.profiles
    if manager and manager.saved and manager.saved[manager.current] then manager.saved[manager.current].typography=copy(FS.db.typography) end
    self:Refresh()
end
function F:Scopes()
    local result={"All modules"}; for name in pairs(FS.modules) do result[#result+1]=name end; table.sort(result,function(a,b) if a==b then return false elseif a=="All modules" then return true elseif b=="All modules" then return false else return a<b end end); return result
end
function F:Data()
    if self.scope=="All modules" then return FS.db.typography.global end
    return FS.db.typography.modules[self.scope] or FS.db.typography.global
end
function F:Edit(key)
    if InCombatLockdown() then FS:Print("Leave combat to change typography."); return end
    local db=FS.db.typography
    if self.scope~="All modules" and not db.modules[self.scope] then db.modules[self.scope]=copy(db.global) end
    local style=self:Data()
    for _,option in ipairs(self.options) do if option.key==key then
        for i,value in ipairs(option.values) do if style[key]==value then style[key]=option.values[i%#option.values+1]; break end end
    end end
    self:Apply()
end
function F:Refresh()
    local f=self.window; if not f then return end
    f.scope:SetText(self.scope)
    local style=self:Data()
    for _,option in ipairs(self.options) do f.optionButtons[option.key]:SetText(option.label..": "..tostring(style[option.key])) end
    f.reset:SetText(self.scope=="All modules" and "Reset global text settings" or "Follow global text settings")
    f.preview.fsFontModule=self.scope=="All modules" and "Core" or self.scope
    FS:ApplyFont(f.preview,16,"")
    f.status:SetText(self.pending and "Changes apply after combat." or self.scope~="All modules" and not FS.db.typography.modules[self.scope] and "This module follows the global settings." or ("Saved automatically in profile: "..FS.db.profiles.current..". Bold uses the included Arial Bold font."))
    if f.LayoutText then f:LayoutText() end
end
function F:Show()
    if InCombatLockdown() then FS:Print("Leave combat to edit typography."); return end
    self:Normalize(); self.scope=self.scope or FS.db.typography.scope or "All modules"; FS.db.typography.scope=self.scope
    if not self.window then
        local H=FS.HUD; local f=CreateFrame("Frame","ForeverSuiteTypography",UIParent,"BackdropTemplate"); self.window=f; H:Skin(f)
        f:SetSize(740,430); f:SetPoint("CENTER"); f:SetScale(math.min(1,(UIParent:GetWidth()-32)/740,(UIParent:GetHeight()-32)/430)); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetClampedToScreen(true)
        f.heading=H:Label(f,"FOREVERSUITE / TEXT & FONTS",20,-18,650)
        local function cycle(delta) local names=self:Scopes(); local index=1; for i,name in ipairs(names) do if name==self.scope then index=i end end; self.scope=names[(index-1+delta)%#names+1]; FS.db.typography.scope=self.scope; self:Refresh() end
        f.previous=H:Button(f,"<",20,-55,40,function() cycle(-1) end); f.scope=H:Button(f,"All modules",70,-55,600,function() cycle(1) end); f.next=H:Button(f,">",680,-55,40,function() cycle(1) end)
        f.optionButtons={}
        for i,option in ipairs(self.options) do f.optionButtons[option.key]=H:Button(f,"",20+(i-1)%2*360,-105-math.floor((i-1)/2)*45,340,function() self:Edit(option.key) end) end
        f.preview=H:Label(f,"ForeverSuite - AaBb 123 / Quest objectives",20,-250,700); f.preview:SetHeight(50)
        f.status=H:Label(f,"",20,-315,700); f.status:SetHeight(40)
        f.reset=H:Button(f,"Use global / reset global",20,-380,320,function() if InCombatLockdown() then return end; if self.scope=="All modules" then FS.db.typography.global=copy(defaults) else FS.db.typography.modules[self.scope]=nil end; self:Apply() end)
        f.control=H:Button(f,"Control Center",355,-380,205,function() f:Hide(); FS:ShowConfig() end); f.close=H:Button(f,"Close",575,-380,145,function() f:Hide() end)
        function f:LayoutText()
            local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
            local y=18+H:TextHeight(self.heading,650,2)+14
            local height=math.max(H:FitButton(self.previous,1),H:FitButton(self.scope,2),H:FitButton(self.next,1))
            at(self.previous,20,y); at(self.scope,70,y); at(self.next,680,y); y=y+height+20
            local rowHeight=30
            for _,option in ipairs(F.options) do rowHeight=math.max(rowHeight,H:FitButton(self.optionButtons[option.key],3)) end
            for i,option in ipairs(F.options) do at(self.optionButtons[option.key],20+(i-1)%2*360,y+math.floor((i-1)/2)*(rowHeight+12)) end
            y=y+3*(rowHeight+12)+8; at(self.preview,20,y); y=y+H:TextHeight(self.preview,700,3)+16
            at(self.status,20,y); y=y+H:TextHeight(self.status,700,3)+20
            local footer=0
            for i,b in ipairs({self.reset,self.control,self.close}) do at(b,({20,355,575})[i],y); footer=math.max(footer,H:FitButton(b,3)) end
            self:SetHeight(math.max(430,y+footer+20))
            self:SetScale(math.min(1,(UIParent:GetWidth()-32)/740,(UIParent:GetHeight()-32)/self:GetHeight()))
        end
        UISpecialFrames[#UISpecialFrames+1]=f:GetName(); f:Hide()
    end
    FS:CloseOtherWindows(self.window); self.window:Show(); self:Apply()
end
F.events=CreateFrame("Frame"); FS:RegisterClientEvent(F.events,"PLAYER_REGEN_ENABLED")
F.events:SetScript("OnEvent",function() if F.pending then F:Apply() end end)
local elapsed=0
F.events:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt; if elapsed<.5 or not FS.db then return end; elapsed=0; if not InCombatLockdown() then F:Discover() end end)
