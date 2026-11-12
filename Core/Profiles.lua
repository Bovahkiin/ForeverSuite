local _,FS=...
local P={name="Profiles"}; FS:RegisterModule(P.name,P)
local function copy(v)
    if type(v)~="table" then return v end
    local out={}; for k,value in pairs(v) do out[k]=copy(value) end; return out
end
function P:Allowed()
    if InCombatLockdown() then FS:Print("Leave combat to change profiles."); return false end
    if FS.modules.Vendor and FS.modules.Vendor.busy then FS:Print("Stop the current vendor action before changing profiles."); return false end
    return true
end
function P:Snapshot()
    local out={}; for k,v in pairs(FS.db) do if k~="profiles" and k~="patchLog" and k~="setup" and k~="compatibility" then out[k]=copy(v) end end; return out
end
function P:PersistCurrent()
    if not FS.db or not FS.db.profiles then return end
    local manager=FS.db.profiles
    if type(manager.current)=="string" and type(manager.saved)=="table" then
        manager.saved[manager.current]=self:Snapshot()
    end
end
function P:Names()
    local names={}; for name in pairs(FS.db.profiles.saved) do names[#names+1]=name end; table.sort(names); return names
end
function P:Save(name)
    if not self:Allowed() then return false end
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    if name=="" or #name>32 then FS:Print("Enter a profile name between 1 and 32 characters."); return false end
    if self.Backup and FS.db.profiles.saved[name] then self:Backup(name,FS.db.profiles.saved[name],"Before save") end
    FS.db.profiles.saved[name]=self:Snapshot(); FS.db.profiles.current=name; self:RefreshSettings(); return true
end
function P:Load(name)
    if not self:Allowed() or not FS.db.profiles.saved[name] then return false end
    if FS.Extensions then FS.Extensions:FinishGathering('Profile changed') end
    if FS.Layout.active then FS.Layout:Stop() end
    local manager=FS.db.profiles; local selected=copy(manager.saved[name])
    local currentSnapshot=self:Snapshot()
    if self.Backup then self:Backup(manager.current,currentSnapshot,"Before profile switch") end
    manager.saved[manager.current]=currentSnapshot; manager.saved[name]=copy(selected)
    local preference=copy(FS.db.patchLog); local setup=copy(FS.db.setup); local data=selected; data.profiles=manager; data.profiles.current=name; data.patchLog=preference; data.setup=setup
    data.compatibility=copy(FS.db.compatibility)
    local oldLayout=FS.db.layout.frames
    ForeverSuiteDB=data; FS:InitializeDatabase()
    if FS.Extensions then FS.Extensions:Normalize(); FS.Extensions:Refresh(); if FS.Extensions.workbench then FS.Extensions.workbench.selected=nil end end
    FS.Layout.applying=true
    for id in pairs(oldLayout) do
        local target=FS.Layout.targets[id]
        if target and not FS.db.layout.frames[id] then FS.HUD:RestorePoints(target.frame,target.points); target.frame:SetScale(target.scale) end
    end
    FS.Layout.applying=false
    if FS.Themes then FS.Themes:Refresh() end
    for _,module in pairs(FS.modules) do if module.SettingsChanged and module~=self then module:SettingsChanged() end end
    FS.modules.Bags:Refresh(); FS:UpdateMinimapButton(); FS.Layout:ApplyAll(); FS:RefreshConfig(); self:RefreshSettings(); if FS.Typography then FS.Typography:Apply() end
    if FS.Compatibility then FS.Compatibility:Scan() end
    return true
end
function P:NormalizeSettings()
    local db=FS.db.profiles
    if type(db.current)~="string" or db.current=="" then db.current="Default" end
    for name,data in pairs(db.saved) do if type(name)~="string" or type(data)~="table" then db.saved[name]=nil end end
end
function P:SettingsChanged()
    self:NormalizeSettings()
    if not FS.db.profiles.saved[FS.db.profiles.current] then FS.db.profiles.saved[FS.db.profiles.current]=self:Snapshot() end
    self:RefreshSettings()
end
function P:Initialize()
    self:NormalizeSettings()
    if not FS.db.profiles.saved[FS.db.profiles.current] then FS.db.profiles.saved[FS.db.profiles.current]=self:Snapshot() end
end
function P:Cycle()
    local names=self:Names(); local index=1
    for i,name in ipairs(names) do if name==self.selected then index=i%#names+1; break end end
    self.selected=names[index] or FS.db.profiles.current; self:RefreshSettings()
end
function P:CreateBar(host)
    if self.bar then return self.bar end
    local H=FS.HUD; local f=CreateFrame("Frame",nil,host,"BackdropTemplate"); self.bar=f
    H:Skin(f); f:SetSize(892,68); f:SetPoint("TOPLEFT",24,-88); f:SetFrameLevel(host:GetFrameLevel()+5)
    f:SetBackdropColor(.035,.05,.075,1); f:SetBackdropBorderColor(.4,.65,.9,.85)
    f.heading=H:Label(f,"PROFILES",14,-14,180); f.heading:SetTextColor(.4,.65,.9)
    f.current=H:Label(f,"",150,-12,360)
    f.name=FS.Tools:Edit(f,150,-34,230)
    f.name:SetMaxLetters(32)
    local function save()
        local name=f.name:GetText():match("^%s*(.-)%s*$")
        if name=="" then name=FS.db.profiles.current end
        if self:Save(name) then self.selected=name; f.name:SetText(""); f.name:ClearFocus(); self:RefreshSettings() end
    end
    f.name:SetScript("OnEnterPressed",save)
    f.save=H:Button(f,"Save",390,-34,114,save)
    f.choice=H:Button(f,"",526,-34,222,function() self:Cycle() end)
    f.choice:SetScript("OnEnter",function(b) GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.selected or FS.db.profiles.current); GameTooltip:AddLine("Click to choose a saved profile. Use loads it.",.8,.9,1,true); GameTooltip:Show() end)
    f.choice:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.use=H:Button(f,"Use",764,-34,114,function() self:Load(self.selected) end)
    self:SettingsChanged(); return f
end
function P:LayoutBar(top)
    local f=self.bar; if not f then return end
    local function size(r) local _,n=r:GetFont(); return n or 14 end
    local line=math.max(size(f.heading),size(f.current))+6
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",24,-top)
    f.heading:SetHeight(line); f.heading:SetWidth(180)
    f.current:ClearAllPoints(); f.current:SetPoint("TOPLEFT",210,-12); f.current:SetWidth(660); f.current:SetHeight(line)
    if f.current.SetMaxLines then f.current:SetMaxLines(1) end
    local y=12+line+8; local row=math.max(30,size(f.name)+12)
    for _,b in ipairs({f.save,f.choice,f.use}) do local t=b.fsLabel or b.GetFontString and b:GetFontString(); if t then row=math.max(row,size(t)+12) end end
    for _,entry in ipairs({{f.name,14,200},{f.save,224,180},{f.choice,414,260},{f.use,684,194}}) do
        local b=entry[1]; b:ClearAllPoints(); b:SetPoint("TOPLEFT",entry[2],-y); b:SetSize(entry[3],row)
        local t=b.fsLabel or b.GetFontString and b:GetFontString(); if t then t:SetWidth(entry[3]-12); t:SetHeight(row-6); if t.SetMaxLines then t:SetMaxLines(1) end end
    end
    f:SetHeight(y+row+10)
end
function P:CreateSettings(host)
    local H=FS.HUD; local f=CreateFrame("Frame",nil,host,"BackdropTemplate"); self.settings=f; H:Skin(f)
    f:SetSize(892,420); f:SetPoint("TOPLEFT",24,FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel()+30); f:EnableMouse(true)
    H:Button(f,"Back to Control Center",20,-12,220,function() f:Hide() end)
    f.current=H:Label(f,"",260,-20,590)
    H:Label(f,"Save your layout, enabled modules and item rules as a named profile. Switching keeps the latest changes in your previous profile.",20,-70,850)
    f.name=CreateFrame("EditBox",nil,f,"BackdropTemplate"); H:Skin(f.name); f.name:SetSize(400,30); f.name:SetPoint("TOPLEFT",20,-125); f.name:SetAutoFocus(false); f.name:SetFont(FS.font,14,""); f.name:SetText("")
    H:Button(f,"Save as profile",450,-125,400,function() self:Save(f.name:GetText()) end)
    f.choice=H:Button(f,"",20,-190,400,function() self:Cycle() end)
    H:Button(f,"Use selected profile",450,-190,400,function() self:Load(self.selected) end)
    H:Label(f,"Profiles are stored in SavedVariables. Changes to a profile are kept automatically when you switch away. Patch-log startup preferences stay shared.",20,-270,850)
    self:RefreshSettings(); f:Hide(); return f
end
function P:RefreshSettings()
    if not FS.db.profiles.saved[FS.db.profiles.current] then FS.db.profiles.saved[FS.db.profiles.current]=self:Snapshot() end
    if not self.selected or not FS.db.profiles.saved[self.selected] then self.selected=FS.db.profiles.current end
    for _,f in ipairs({self.bar or false,self.settings or false}) do if f then
        f.current:SetText("Current profile: "..FS.db.profiles.current); f.choice:SetText("Choose: "..self.selected)
    end end
end
