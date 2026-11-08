local _,FS=...
local C={nameplates={},waypoints={},snoozed={}}; FS.Compatibility=C
FS.defaults.compatibility={characters={}}
local function call(fn,...) if type(fn)=="function" then local ok,a,b,c=pcall(fn,...); if ok then return a,b,c end end end
function C:Character()
    return (call(UnitName,"player") or "Player").." - "..(call(GetRealmName) or "Realm")
end
function C:Data()
    local all=FS.db.compatibility.characters; local key=self:Character()
    if type(all[key])~="table" then all[key]={seen={}} end
    local data=all[key]; if type(data.seen)~="table" then data.seen={} end
    for _,category in ipairs({"waypoints","nameplates"}) do
        if data[category] and data[category]~="ForeverSuite" and not self:Known(category,data[category]) then data[category]=nil end
        if type(data.seen[category])~="table" then data.seen[category]={} end
    end
    return data
end
function C:Installed(name)
    if C_AddOns and C_AddOns.DoesAddOnExist then return call(C_AddOns.DoesAddOnExist,name)==true end
    return C_AddOns and call(C_AddOns.GetAddOnInfo,name)~=nil or false
end
function C:Loaded(name) return C_AddOns and call(C_AddOns.IsAddOnLoaded,name)==true or false end
function C:Enabled(name)
    local state=C_AddOns and call(C_AddOns.GetAddOnEnableState,name,call(UnitName,"player"))
    return type(state)=="number" and state>0 or state==nil and self:Loaded(name)
end
function C:Known(category,id)
    for _,p in ipairs(self[category]) do if p.id==id then return p end end
end
function C:Register(category,provider)
    assert((category=="waypoints" or category=="nameplates") and type(provider.id)=="string")
    assert(not self:Known(category,provider.id)); self[category][#self[category]+1]=provider
end
function C:Candidates(category)
    local out={{id="ForeverSuite",label="ForeverSuite",active=category=="waypoints" and FS.db.map.navigation or category=="nameplates" and FS.db.nameplates.enabled}}
    for _,p in ipairs(self[category]) do
        local installed,active=false,false
        for _,name in ipairs(p.addons) do
            installed=installed or self:Installed(name); active=active or self:Enabled(name)
        end
        if installed and (category=="nameplates" or active) then out[#out+1]={id=p.id,label=p.label,active=active,provider=p} end
    end
    if category=="nameplates" and C_AddOns and C_AddOns.GetAddOnDependencies then
        local dependencies={}
        for _,p in ipairs(out) do if p.provider and p.active then for _,name in ipairs(p.provider.addons) do
            if self:Installed(name) then
                local deps={pcall(C_AddOns.GetAddOnDependencies,name)}
                if deps[1] then for i=2,#deps do if type(deps[i])=="string" then dependencies[deps[i]]=true end end end
            end
        end end end
        for _,p in ipairs(out) do if p.provider and p.active then
            local independent=false
            for _,name in ipairs(p.provider.addons) do if self:Enabled(name) and not dependencies[name] then independent=true end end
            if not independent then p.active=false; p.dependency=true end
        end end
    end
    return out
end
function C:Ready(provider) return provider and call(provider.ready)==true end
local function rxp()
    if not LibStub then return end
    local ok,ace=pcall(function() return LibStub("AceAddon-3.0",true) end)
    local addon=ok and ace and call(ace.GetAddon,ace,"RXPGuides",true)
    if addon and addon.settings and type(addon.settings.profile)=="table" then return addon end
end
C:Register("waypoints",{id="RXPGuides",label="RestedXP",addons={"RXPGuides"},
    ready=function() local addon=rxp(); return addon~=nil and type(addon.DrawArrow)=="function" and addon.arrowFrame~=nil end,
    enabled=function() local addon=rxp(); return addon and not addon.settings.profile.disableArrow end,
    set=function(enabled)
        local addon=rxp(); if not addon then return false end
        addon.settings.profile.disableArrow=not enabled
        local frame=addon.arrowFrame
        if frame and not (frame.IsProtected and frame:IsProtected()) then
            if not enabled then frame:Hide()
            elseif frame.IsFeatureEnabled then frame:SetShown(frame.IsFeatureEnabled()) end
        end
        call(addon.DrawArrow,frame); return true
    end})
C:Register("waypoints",{id="Zygor",label="Zygor",addons={"ZygorGuidesViewer","ZygorGuidesViewerClassic"},
    ready=function() local z=ZygorGuidesViewer; return z and z.db and type(z.db.profile)=="table" and type(z.db.profile.arrowshow)=="boolean" and z.Pointer and type(z.Pointer.UpdateArrowVisibility)=="function" end,
    enabled=function() return ZygorGuidesViewer.db.profile.arrowshow~=false end,
    set=function(enabled)
        local z=ZygorGuidesViewer
        if not C:Known("waypoints","Zygor").ready() then return false end
        z.db.profile.arrowshow=enabled; z.Pointer:UpdateArrowVisibility(); return true
    end})
C:Register("waypoints",{id="TomTom",label="TomTom",addons={"TomTom"},
    ready=function() return TomTom and TomTom.db and type(TomTom.db.profile)=="table" and type(TomTom.db.profile.arrow)=="table" and type(TomTom.db.profile.arrow.enable)=="boolean" and type(TomTom.ShowHideCrazyArrow)=="function" end,
    enabled=function() return TomTom.db.profile.arrow.enable~=false end,
    set=function(enabled)
        if not C:Known("waypoints","TomTom").ready() then return false end
        TomTom.db.profile.arrow.enable=enabled; TomTom:ShowHideCrazyArrow(); return true
    end})
for _,p in ipairs({
    {id="Plater",label="Plater",addons={"Plater"}},
    {id="Platynator",label="Platynator",addons={"Platynator"}},
    {id="Kui",label="Kui Nameplates",addons={"Kui_Nameplates","Kui_Nameplates_Core"},enableAll=true},
    {id="ThreatPlates",label="Threat Plates",addons={"TidyPlates_ThreatPlates","ThreatPlates"}},
    {id="TidyPlates",label="Tidy Plates",addons={"TidyPlates"}},
    {id="NeatPlates",label="NeatPlates",addons={"NeatPlates"}},
}) do C:Register("nameplates",p) end
function C:MarkSeen(category)
    local seen={}; for _,p in ipairs(self:Candidates(category)) do seen[p.id]=true end
    self:Data().seen[category]=seen; self.snoozed[category]=nil
end
function C:ApplyWaypoints(id,remember,fallback)
    if InCombatLockdown() then return false,"Leave combat to change navigation systems." end
    local selected=id~="ForeverSuite" and self:Known("waypoints",id)
    if id~="ForeverSuite" and not self:Ready(selected) then return false,"This navigation addon is not ready or its arrow API is unsupported." end
    -- Verify every running competing adapter before changing anything.
    for _,p in ipairs(self:Candidates("waypoints")) do
        if p.provider and p.active and not self:Ready(p.provider) then return false,p.label.." is not ready. Try again after it finishes loading." end
    end
    local changed={}
    for _,p in ipairs(self:Candidates("waypoints")) do
        if p.provider and self:Ready(p.provider) then
            changed[#changed+1]={provider=p.provider,enabled=call(p.provider.enabled)~=false}
            local ok,result=pcall(p.provider.set,p.id==id)
            if not ok or result==false then
                for i=#changed,1,-1 do pcall(changed[i].provider.set,changed[i].enabled) end
                return false,"Could not change "..p.label.." navigation. The previous choice was kept."
            end
        end
    end
    if id~="ForeverSuite" then FS.db.map.navigation=false
    elseif remember or fallback then FS.db.map.navigation=true end
    if id=="ForeverSuite" and remember then FS.db.modules.Map=true; FS.db.map.enabled=true end
    FS.modules.Map:UpdateNavigation()
    if remember then self:Data().waypoints=id; self:MarkSeen("waypoints") end
    return true
end
function C:ApplyNameplates(id)
    if InCombatLockdown() then return false,"Leave combat to change nameplate systems." end
    if not (C_AddOns and C_AddOns.EnableAddOn and C_AddOns.DisableAddOn and C_AddOns.GetAddOnEnableState) then return false,"This client cannot switch addon enablement." end
    local selected=id~="ForeverSuite" and self:Known("nameplates",id)
    if id~="ForeverSuite" and not selected then return false,"Unknown nameplate system." end
    local allow={}; local selectedAddon
    if selected then
        for _,name in ipairs(selected.addons) do if self:Installed(name) then
            if selected.enableAll then allow[name]=true end
            if not selectedAddon or self:Enabled(name) then selectedAddon=name end
        end end
        if not selectedAddon then return false,"This nameplate addon is no longer installed." end
        allow[selectedAddon]=true
        local function dependencies(name,depth)
            if depth>6 or not C_AddOns.GetAddOnDependencies then return end
            local result={pcall(C_AddOns.GetAddOnDependencies,name)}
            if result[1] then for i=2,#result do local dep=result[i]; if type(dep)=="string" and not allow[dep] then allow[dep]=true; dependencies(dep,depth+1) end end end
        end
        for name in pairs(allow) do dependencies(name,0) end
    end
    local character=call(UnitName,"player")
    if type(character)~="string" or character=="" then return false,"Your character is not ready yet." end
    local plan,previous={},{ }
    for _,p in ipairs(self.nameplates) do for _,name in ipairs(p.addons) do
        if self:Installed(name) then plan[name]=allow[name]==true end
    end end
    for name in pairs(allow) do if not name:match("^Blizzard_") then plan[name]=true end end
    for name in pairs(plan) do previous[name]=self:Enabled(name) end
    for name,enabled in pairs(plan) do
        local fn=enabled and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn
        local ok=pcall(fn,name,character)
        if not ok or self:Enabled(name)~=enabled then
            for saved,value in pairs(previous) do pcall(value and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn,saved,character) end
            return false,"Could not switch the nameplate addons. Your UI was not reloaded."
        end
    end
    FS.db.nameplates.enabled=id=="ForeverSuite"
    self:Data().nameplates=id; self:MarkSeen("nameplates")
    -- External addon lifecycle changes take effect cleanly after the button's reload.
    return true
end
function C:NeedsChoice(category)
    if self.snoozed[category] then return false end
    local data=self:Data(); local seen=data.seen[category] or {}; local external=0
    for _,p in ipairs(self:Candidates(category)) do
        if p.id~="ForeverSuite" and p.active then
            external=external+1
            if not data[category] or not seen[p.id] then return true end
        end
    end
    if category=="nameplates" and (external>1 or external>0 and (FS.db.nameplates.enabled or data.nameplates=="ForeverSuite")) then return true end
    return false
end
function C:Scan()
    if not FS.initialized or InCombatLockdown() then return end
    self.waiting=false
    local data=self:Data()
    if data.waypoints then
        local p=self:Known("waypoints",data.waypoints)
        if data.waypoints=="ForeverSuite" then self:ApplyWaypoints(data.waypoints,false)
        elseif p then
            local available=false; for _,name in ipairs(p.addons) do available=available or self:Enabled(name) end
            if not available then self:ApplyWaypoints("ForeverSuite",false,true)
            elseif self:Ready(p) then self:ApplyWaypoints(data.waypoints,false) end
        end
    end
    if data.nameplates and data.nameplates~="ForeverSuite" then
        local enable=false
        if not enable then
            local p=self:Known("nameplates",data.nameplates); local available=false
            if p then for _,name in ipairs(p.addons) do available=available or self:Enabled(name) end end
            enable=not available
        end
        if FS.db.nameplates.enabled~=enable then FS.db.nameplates.enabled=enable; FS.modules.Nameplates:SettingsChanged() end
    end
    if self.window and self.window:IsShown() then return end
    if FS.Installer:NeedsSetup() or FS.Installer.window and FS.Installer.window:IsShown()
        or FS.window and FS.window:IsShown() or FS.aboutWindow and FS.aboutWindow:IsShown()
        or FS.Typography.window and FS.Typography.window:IsShown() then
        self.waiting=self:NeedsChoice("waypoints") or self:NeedsChoice("nameplates"); return
    end
    for _,category in ipairs({"waypoints","nameplates"}) do if self:NeedsChoice(category) then self:Show(category,true); return end end
end
function C:Show(category,automatic)
    if InCombatLockdown() then FS:Print("Leave combat to choose addon systems."); return end
    self.category=category or self.category or "waypoints"
    if not self.window then
        local H=FS.HUD; local f=CreateFrame("Frame","ForeverSuiteAddonChoices",UIParent,"BackdropTemplate"); self.window=f
        H:Skin(f); f:SetPoint("CENTER"); f:SetSize(660,440); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetClampedToScreen(true)
        f.title=H:Label(f,"ADDON SYSTEMS",22,-20,610)
        f.nav=H:Button(f,"Waypoints",22,-55,300,function() self:Show("waypoints") end)
        f.plates=H:Button(f,"Nameplates",338,-55,300,function() self:Show("nameplates") end)
        f.help=H:Label(f,"",22,-102,610); f.rows={}
        f.status=H:Label(f,"",22,-280,610)
        f.apply=H:Button(f,"Apply",22,-365,300,function()
            local ok,message
            if self.category=="waypoints" then ok,message=self:ApplyWaypoints(self.selected,true)
            else ok,message=self:ApplyNameplates(self.selected) end
            if not ok then f.status:SetText(message); return end
            FS.Extensions.skipUndo=true
            f:Hide(); if self.category=="nameplates" then ReloadUI() else self:Scan() end
        end)
        f.later=H:Button(f,"Choose later",338,-365,300,function() self.snoozed[self.category]=true; f:Hide(); self:Scan() end)
        UISpecialFrames[#UISpecialFrames+1]="ForeverSuiteAddonChoices"
        f:SetScript("OnHide",function() if not self.applying then self.snoozed[self.category]=true end end)
    end
    local f=self.window; self.selected=self:Data()[self.category] or "ForeverSuite"
    local candidates=self:Candidates(self.category)
    local found=false; for _,p in ipairs(candidates) do if p.id==self.selected then found=true end end; if not found then self.selected="ForeverSuite" end
    f.help:SetText(self.category=="waypoints" and "Choose one navigation arrow. Your guides remain available. The choice is remembered for this character." or "Choose one nameplate system. Other listed nameplate addons are disabled for this character after a UI reload. Their saved settings are kept.")
    local y=20+FS.HUD:TextHeight(f.title,610,2)+14
    for i,b in ipairs({f.nav,f.plates}) do b:ClearAllPoints(); b:SetPoint("TOPLEFT",i==1 and 22 or 338,-y); FS.HUD:FitButton(b,2,32) end
    y=y+math.max(f.nav:GetHeight(),f.plates:GetHeight())+16
    f.help:ClearAllPoints(); f.help:SetPoint("TOPLEFT",22,-y)
    y=y+FS.HUD:TextHeight(f.help,610,5)+18
    local function labels()
        for i,p in ipairs(candidates) do f.rows[i]:SetText((self.selected==p.id and "[x] " or "")..p.label) end
    end
    for i,p in ipairs(candidates) do
        if not f.rows[i] then f.rows[i]=FS.HUD:Button(f,"",22,0,616,function() end) end
        local row=f.rows[i]; row:SetScript("OnClick",function() self.selected=p.id; labels() end)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",22,-y); row:Show(); FS.HUD:FitButton(row,2,32); y=y+row:GetHeight()+8
    end
    for i=#candidates+1,#f.rows do f.rows[i]:Hide() end
    labels(); f.status:SetText(automatic and "More than one system was detected. Nothing changes until you apply your choice." or "Your saved choice can be changed here at any time.")
    f.status:ClearAllPoints(); f.status:SetPoint("TOPLEFT",22,-y); y=y+FS.HUD:TextHeight(f.status,610,4)+16
    f.apply:SetText(self.category=="nameplates" and "Apply and reload UI" or "Apply waypoint choice")
    for i,b in ipairs({f.apply,f.later}) do b:ClearAllPoints(); b:SetPoint("TOPLEFT",i==1 and 22 or 338,-y); FS.HUD:FitButton(b,3,32) end
    f:SetHeight(y+math.max(f.apply:GetHeight(),f.later:GetHeight())+22)
    f:SetScale(math.min(1,(UIParent:GetWidth()-24)/660,(UIParent:GetHeight()-24)/f:GetHeight()))
    if not automatic and FS.window then FS.window:Hide() end
    f:Show()
end
function C:Initialize()
    if self.events then return end
    self.events=CreateFrame("Frame"); local queued=false
    local function queue()
        if queued then return end; queued=true
        C_Timer.After(1,function() queued=false; self:Scan() end)
    end
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","ADDON_LOADED","PLAYER_REGEN_ENABLED"}) do FS:RegisterClientEvent(self.events,event) end
    self.events:SetScript("OnEvent",queue); queue()
    local elapsed=0
    self.events:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt; if elapsed<1 then return end; elapsed=0
        if self.waiting and not InCombatLockdown() then self:Scan() end
    end)
end
