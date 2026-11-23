local _,FS=...
local T,H=FS.Tools,FS.HUD
local M=T:Module('MinimapButtons','minimapButtons','Addon Buttons','One themed tray for addon minimap buttons. Original button clicks and tooltips remain owned by their addons.',
    {columns=6,iconSize=30,spacing=4,showNames=true,excluded={}}, {'ADDON_LOADED','PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_REGEN_DISABLED'})
M.collected={}
M.options={{key='columns',label='Tray columns',values={4,6,8}},{key='iconSize',label='Icon size',values={24,30,36}},
    {key='spacing',label='Icon spacing',values={2,4,8}},{key='showNames',label='Show names in the button list'}}
local blocked={MiniMapTracking=true,MiniMapTrackingButton=true,MinimapZoomIn=true,MinimapZoomOut=true,MiniMapMailFrame=true,
    MiniMapWorldMapButton=true,AddonCompartmentFrame=true,GameTimeFrame=true,QueueStatusMinimapButton=true,MinimapBackdrop=true,Minimap=true,
    MinimapCluster=true,ExpansionLandingPageMinimapButton=true,TimeManagerClockButton=true,MiniMapInstanceDifficulty=true}
function M:Normalize()
    local d=self:Data(); if type(d.excluded)~='table' then d.excluded={} end
    for key,value in pairs(d.excluded) do if type(key)~='string' or value~=true then d.excluded[key]=nil end end
end
local function onMinimap(frame)
    return frame and (frame==Minimap or frame==MinimapBackdrop or frame==MinimapCluster
        or (MinimapCluster and frame==MinimapCluster.MinimapContainer))
end

local function safeFrame(frame)
    if not H:Safe(frame) then return false end
    local kind=type(frame)
    return (kind=="table" or kind=="userdata") and not T:Call(frame.IsForbidden,frame)
end

local function addonTexture(button)
    local function source(region)
        if not safeFrame(region) then return end
        local texture=T:Text(T:Call(region.GetTexture,region))
        local addon=texture:lower():match("^interface[\\/]addons[\\/]([^\\/]+)[\\/]")
        if addon and not addon:match("^blizzard_") then return addon..":"..texture:lower() end
    end
    local texture=source(button.icon or button.Icon) or source(T:Call(button.GetNormalTexture,button))
    if texture then return texture end
    if button.GetRegions then
        for _,region in ipairs({button:GetRegions()}) do
            texture=source(region)
            if texture then return texture end
        end
    end
end

local function launcherKey(name)
    local label=name:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t","")
    return label:lower():gsub("^libdbicon10_",""):gsub("[%p%s]",""):gsub("minimapbutton$",""):gsub("minimapicon$","")
end

function M:Candidate(button,registered)
    if not safeFrame(button) or button==self.button or button==self.tray or T:Call(button.IsProtected,button) then return end
    local kind=T:Call(button.GetObjectType,button)
    if kind~="Button" and kind~="CheckButton" then return end
    local name=T:Text(T:Call(button.GetName,button))
    if blocked[name] or name:match("^Blizzard_") or button==AddonCompartmentFrame
        or button==GameTimeFrame or button==MiniMapTrackingButton
        or button==(MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button)
        or button.pinTemplate or button.dataProvider or button.uiMapID or button.unit then return end
    local lower=name:lower()
    if name~="" and (registered or button==FS.minimapButton or name:match("^LibDBIcon10_")
        or lower:find("minimapbutton",1,true) or lower:find("minimapicon",1,true)) then return name end
    -- Custom launchers without predictable names must provide addon artwork and an action.
    if T:Call(button.GetScript,button,"OnClick") or T:Call(button.GetScript,button,"OnMouseUp") then
        local source=addonTexture(button)
        if source then return name~="" and name or source end
    end
end
function M:Restore(button)
    local s=self.collected[button]; if not s then return end
    if InCombatLockdown() then self.pending=true; return end
    if not safeFrame(button) or T:Call(button.IsProtected,button) then self.pending=true; return end
    button:SetParent(s.parent); button:SetScale(s.scale); button:SetSize(s.width,s.height)
    button:SetFrameStrata(s.strata); button:SetFrameLevel(s.level); H:RestorePoints(button,s.points)
    self.collected[button]=nil
    if button==FS.minimapButton then FS:UpdateMinimapButton() end
end
function M:CreateTray()
    if self.tray or not Minimap then return end
    local f=CreateFrame('Frame','ForeverSuiteAddonButtonTray',UIParent,'BackdropTemplate'); self.tray=f
    f.fsFontModule=self.name; H:Skin(f); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:Hide()
    self.parking=CreateFrame('Frame',nil,UIParent); self.parking:Hide()
    local b=CreateFrame('Button','ForeverSuiteAddonButtonsToggle',UIParent,'BackdropTemplate'); self.button=b
    b:SetSize(32,32); b:SetPoint('TOPRIGHT',Minimap,'TOPLEFT',-5,0)
    b:SetFrameStrata('MEDIUM'); b:SetClampedToScreen(true); b:SetMovable(true); b:RegisterForDrag('LeftButton')
    b:SetScript('OnDragStart',function()
        if InCombatLockdown() then return end
        self.dragging=true; b.fsDirectDragging=true; b:StartMoving(); GameTooltip:Hide()
    end)
    b:SetScript('OnDragStop',function()
        if not self.dragging then return end
        b:StopMovingOrSizing(); self.dragging=nil; b.fsDirectDragging=nil; self.suppressClick=true
        FS.Layout:Save('AddonButtons',b,b:GetScale(),true); self:AnchorTray()
        if FS.modules.Profiles then FS.modules.Profiles:PersistCurrent() end
        C_Timer.After(0,function() self.suppressClick=nil end)
    end)
    b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetAllPoints(); FS:SetMenuIcon(b.icon, "MinimapButtons")
    b:SetScript('OnClick',function() if InCombatLockdown() or self.dragging or self.suppressClick then return end; self:ToggleTray() end)
    b:SetScript('OnEnter',function() GameTooltip:SetOwner(b,'ANCHOR_LEFT'); GameTooltip:AddLine('ForeverSuite - Addon Buttons'); GameTooltip:AddLine('Click to open. Drag to move. Also available in Move Frames.',1,1,1,true); GameTooltip:Show() end)
    b:SetScript('OnLeave',function() GameTooltip:Hide() end)
    FS.Layout:Register('AddonButtons',b,'Addon Buttons')
    self:AnchorTray()
end
function M:AnchorTray()
    if not self.tray or not self.button or InCombatLockdown() then return end
    local x,y=T:Call(self.button.GetCenter,self.button)
    local scale=self.button:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local right=T:Number(x) and x*scale>UIParent:GetWidth()/2
    local below=not T:Number(y) or y*scale>UIParent:GetHeight()/2
    local side=right and 'RIGHT' or 'LEFT'
    self.tray:ClearAllPoints()
    self.tray:SetPoint((below and 'TOP' or 'BOTTOM')..side,self.button,(below and 'BOTTOM' or 'TOP')..side,0,below and -8 or 8)
end
function M:OtherCollector()
    for _,name in ipairs({'MinimapButtonButton','MBB'}) do
        if T:Call(C_AddOns and C_AddOns.IsAddOnLoaded,name)==true then return name end
    end
end
function M:ChooseCollector(useSuite)
    if InCombatLockdown() then return false end
    if not useSuite then FS:SetModuleEnabled(self.name,false); if self.conflict then self.conflict:Hide() end; return true end
    local name=self:OtherCollector()
    if not name then if self.conflict then self.conflict:Hide() end; self:Scan(); return true end
    local character=T:Call(UnitName,'player')
    if type(character)~='string' or not C_AddOns or type(C_AddOns.DisableAddOn)~='function' then return false end
    local ok=pcall(C_AddOns.DisableAddOn,name,character)
    if not ok or (C_AddOns.GetAddOnEnableState and T:Call(C_AddOns.GetAddOnEnableState,name,character)~=0) then return false end
    if self.conflict then self.conflict:Hide() end
    if FS.modules.Profiles then FS.modules.Profiles:PersistCurrent() end
    if type(ReloadUI)=='function' then ReloadUI() end
    return true
end
function M:ShowCollectorChoice()
    if InCombatLockdown() or not FS:IsModuleEnabled(self.name) or not self:OtherCollector() then return end
    if not self.conflict then
        local f=CreateFrame('Frame','ForeverSuiteCollectorChoice',UIParent,'BackdropTemplate'); self.conflict=f
        f.fsFontModule=self.name; H:Skin(f); f:SetSize(620,220); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true); f:EnableMouse(true)
        f.title=H:Label(f,'Choose your minimap button collector',20,-16,580)
        f.message=H:Label(f,'Another collector is already managing addon buttons. Use ForeverSuite to disable that collector for this character and reload the UI, or keep the other collector.',20,-58,580)
        f.suite=H:Button(f,'Use ForeverSuite + reload',20,-155,280,function() if not self:ChooseCollector(true) then f.message:SetText('Could not switch. Leave combat and try again.'); end end)
        f.other=H:Button(f,'Keep the other collector',320,-155,280,function() self:ChooseCollector(false) end)
        function f:LayoutText()
            local top=28+H:TextHeight(self.title,580,2)
            self.message:ClearAllPoints(); self.message:SetPoint('TOPLEFT',20,-top)
            local y=top+H:TextHeight(self.message,580,6)+18
            self.suite:ClearAllPoints(); self.suite:SetPoint('TOPLEFT',20,-y)
            self.other:ClearAllPoints(); self.other:SetPoint('TOPLEFT',320,-y)
            local height=math.max(H:FitButton(self.suite,3),H:FitButton(self.other,3))
            self:SetHeight(y+height+20); self:SetScale(math.min(1,(UIParent:GetWidth()-32)/620,(UIParent:GetHeight()-32)/self:GetHeight()))
        end
    end
    self.conflict:LayoutText(); self.conflict:Show()
end
function M:ToggleTray()
    if self:OtherCollector() then self:ShowCollectorChoice(); return end
    self:CreateTray(); if not self.tray then return end
    if self.tray:IsShown() then self.tray:Hide(); return end
    self.tray:Show(); self:Scan()
end
local function library(name)
    if type(LibStub)~="table" and type(LibStub)~="function" then return end
    local ok,lib=pcall(function() return LibStub(name,true) end)
    if ok and type(lib)=="table" then return lib end
end

local function brokerData(data)
    return H:Safe(data) and type(data)=="table" and type(data.OnClick)=="function"
end

function M:WatchLauncherRegistrations(lib,event)
    if not lib or type(lib.RegisterCallback)~="function" then return end
    self.watchedLibraries=self.watchedLibraries or setmetatable({},{__mode="k"})
    local watched=self.watchedLibraries[lib]
    if not watched then watched={}; self.watchedLibraries[lib]=watched end
    if watched[event] then return end
    local ok=pcall(lib.RegisterCallback,self,event,function()
        if FS:IsModuleEnabled(self.name) then self:Event("LAUNCHER_REGISTERED") end
    end)
    if ok then watched[event]=true end
end

function M:FindButtons()
    local found,launchers,visited,occupied={},{},{},{}
    local function scan(parent,depth)
        if not safeFrame(parent) or visited[parent] or depth>4 or parent==self.tray or parent==self.button
            or parent==self.parking or parent==AddonCompartmentFrame or parent.pinTemplate or parent.dataProvider
            or parent.uiMapID or parent.unit then return end
        visited[parent]=true
        if not parent.GetChildren then return end
        for _,button in ipairs({parent:GetChildren()}) do
            local name=self:Candidate(button)
            if name then found[button]=name else scan(button,depth+1) end
        end
    end
    scan(Minimap,0); scan(MinimapBackdrop,0); scan(MinimapCluster,0)
    -- Also inspect wrappers attached to the minimap by an anchor instead of parentage.
    if UIParent and UIParent.GetChildren then
        for _,frame in ipairs({UIParent:GetChildren()}) do
            if safeFrame(frame) and frame.GetNumPoints then
                local count=T:Call(frame.GetNumPoints,frame)
                for index=1,T:Number(count) and count or 0 do
                    local _,anchor=T:Call(frame.GetPoint,frame,index)
                    if onMinimap(anchor) then
                        local name=self:Candidate(frame)
                        if name then found[frame]=name else scan(frame,0) end
                        break
                    end
                end
            end
        end
    end

    local linkedBrokers={}
    local function addBroker(name,data,button,registeredName)
        if not brokerData(data) then return false end
        local key=launcherKey(name)
        if key=="" then return false end
        local title=T:Text(data.label)
        if title=="" then title=name end
        local candidate=button and self:Candidate(button,true)
        if button then found[button]=nil end
        occupied[key]=true
        occupied[launcherKey(title)]=true
        linkedBrokers[data]=true
        launchers[key]={name=registeredName,title=title,icon=data.icon,coords=data.iconCoords,
            broker=data,original=candidate and button or nil}
        return true
    end

    local icons,brokers=library("LibDBIcon-1.0"),library("LibDataBroker-1.1")
    self:WatchLauncherRegistrations(icons,"LibDBIcon_IconCreated")
    self:WatchLauncherRegistrations(brokers,"LibDataBroker_DataObjectCreated")
    local names=icons and T:Call(icons.GetButtonList,icons)
    if type(names)=="table" then
        for _,name in ipairs(names) do
            if type(name)=="string" and name~="" then
                local button=T:Call(icons.GetMinimapButton,icons,name)
                local data=safeFrame(button) and button.dataObject
                if not brokerData(data) and brokers then data=T:Call(brokers.GetDataObjectByName,brokers,name) end
                if not addBroker(name,data,button,"LibDBIcon10_"..name) then
                    local candidate=self:Candidate(button,true)
                    if candidate then found[button]=candidate end
                end
            end
        end
    end

    -- A compatible addon can expose its broker frame without using this copy of LibDBIcon.
    local discovered={}
    for button,name in pairs(found) do discovered[button]=name end
    for button,state in pairs(self.collected) do
        if not discovered[button] and safeFrame(button) then discovered[button]=state.name end
    end
    for button,name in pairs(discovered) do
        local brokerName=name:match("^LibDBIcon10_(.+)$")
        if brokerName and brokerData(button.dataObject) then
            addBroker(brokerName,button.dataObject,button,name)
        elseif self.collected[button] or T:Call(button.IsShown,button) then
            occupied[launcherKey(name)]=true
        end
    end

    if brokers then
        local iterate,state,first=T:Call(brokers.DataObjectIterator,brokers)
        if type(iterate)=="function" then
            for name,data in iterate,state,first do
                if type(name)=="string" and brokerData(data) and not linkedBrokers[data]
                    and (data.type=="launcher" or data.type=="data source")
                    and not occupied[launcherKey(name)] and not occupied[launcherKey(T:Text(data.label))] then
                    addBroker(name,data,nil,"LibDataBroker:"..name)
                end
            end
        end
    end

    local compartment=AddonCompartmentFrame
    local registered=safeFrame(compartment) and compartment.registeredAddons
    if H:Safe(registered) and type(registered)=="table" then
        for _,entry in ipairs(registered) do
            if H:Safe(entry) and type(entry)=="table" and type(entry.func)=="function" then
                local title=T:Text(entry.text)
                local key=launcherKey(title)
                if key~="" and not occupied[key] and not launchers[key] then
                    launchers[key]={name="Compartment:"..key,title=title,icon=entry.icon,compartment=entry}
                end
            end
        end
    end
    return found,launchers
end

function M:LauncherButton(key,entry)
    self.launcherButtons=self.launcherButtons or {}
    local button=self.launcherButtons[key]
    if not button then
        button=CreateFrame("Button",nil,self.tray)
        button:RegisterForClicks("AnyUp")
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        button.icon=button:CreateTexture(nil,"ARTWORK")
        button.icon:SetPoint("TOPLEFT",3,-3); button.icon:SetPoint("BOTTOMRIGHT",-3,3)
        button:SetScript("OnClick",function(b,mouse)
            local info=b.launcher
            if not info or InCombatLockdown() then return end
            if info.broker then T:Call(info.broker.OnClick,b,mouse)
            else T:Call(info.compartment.func,nil,{buttonName=mouse},b) end
        end)
        button:SetScript("OnEnter",function(b)
            local info=b.launcher; if not info then return end
            GameTooltip:SetOwner(b,"ANCHOR_BOTTOM")
            if info.compartment and type(info.compartment.funcOnEnter)=="function" then
                T:Call(info.compartment.funcOnEnter,b)
            elseif info.broker and type(info.broker.OnTooltipShow)=="function" then
                T:Call(info.broker.OnTooltipShow,GameTooltip)
            elseif info.broker and type(info.broker.OnEnter)=="function" then
                T:Call(info.broker.OnEnter,b)
            else GameTooltip:AddLine(info.title) end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function(b)
            local info=b.launcher
            if info and info.compartment then T:Call(info.compartment.funcOnLeave,b)
            elseif info and info.broker then T:Call(info.broker.OnLeave,b) end
            GameTooltip:Hide()
        end)
        self.launcherButtons[key]=button
    end
    button.launcher=entry
    button.dataObject=entry.broker
    local icon=entry.icon
    if H:Safe(icon) and (type(icon)=="string" or T:Number(icon)) then
        FS:ClearMenuIcon(button.icon)
        button.icon:SetTexCoord(0,1,0,1)
        if T:Call(C_Texture and C_Texture.GetAtlasInfo,icon) then button.icon:SetAtlas(icon)
        else
            button.icon:SetTexture(icon)
            local coords=entry.coords
            if H:Safe(coords) and type(coords)=="table"
                and T:Number(coords[1]) and T:Number(coords[2]) and T:Number(coords[3]) and T:Number(coords[4]) then
                button.icon:SetTexCoord(unpack(coords,1,4))
            end
        end
    else FS:SetMenuIcon(button.icon,"MinimapButtons") end
    button:Show()
    return button
end
function M:Remember(button,name)
    local saved=self.collected[button]
    if saved then return saved end
    local width,height,scale=button:GetWidth(),button:GetHeight(),button:GetScale()
    if not T:Number(width) or not T:Number(height) or not T:Number(scale) then return end
    saved={name=name,parent=button:GetParent(),points=H:SavePoints(button),width=width,height=height,scale=scale,
        strata=button:GetFrameStrata(),level=button:GetFrameLevel()}
    self.collected[button]=saved
    return saved
end

function M:Scan()
    if InCombatLockdown() then self.pending=true; return end
    self:CreateTray(); if not self.tray then return end
    for _,button in pairs(self.launcherButtons or {}) do button.launcher=nil; button.dataObject=nil; button:Hide() end
    local enabled=FS:IsModuleEnabled(self.name)
    local other=enabled and self:OtherCollector()
    self.button:SetShown(enabled)
    if not enabled or other then
        local list={}; for button in pairs(self.collected) do list[#list+1]=button end
        for _,button in ipairs(list) do self:Restore(button) end
        self.tray:Hide()
        if other then self.status='Another collector is active. Click the tray button to choose one.' end
        return
    end

    local data=self:Data()
    local found,launchers=self:FindButtons()
    local list,parked={},{}

    for key,entry in pairs(launchers) do
        if not data.excluded[entry.name] then
            local button=self:LauncherButton(key,entry)
            list[#list+1]={button=button,name=entry.name}
            -- A tray-owned launcher keeps its icon visible even when the library
            -- fades its own frame, applies fixed strata, or resets its anchors.
            local original=entry.original
            if original and (self.collected[original] or T:Call(original.IsShown,original)) then
                local saved=self:Remember(original,entry.name)
                if saved then
                    if original:GetParent()~=self.parking then T:Call(original.SetParent,original,self.parking) end
                    if original:GetParent()==self.parking then saved.parked=true; parked[original]=true
                    else self.collected[original]=nil end
                end
            end
        end
    end

    for button,name in pairs(found) do
        if not data.excluded[name] and button:IsShown() and not self.collected[button] and self:Remember(button,name) then
            button:SetParent(self.tray)
        end
    end
    for button,saved in pairs(self.collected) do
        if not parked[button] then
            if data.excluded[saved.name] or saved.parked then self:Restore(button)
            elseif safeFrame(button) and not T:Call(button.IsProtected,button) and button:IsShown() then
                list[#list+1]={button=button,name=saved.name}
            end
        end
    end

    table.sort(list,function(a,b) return a.name:lower()<b.name:lower() end)
    local step=data.iconSize+data.spacing
    for index,entry in ipairs(list) do
        local button,position=entry.button,index-1
        if button:GetParent()~=self.tray then button:SetParent(self.tray) end
        button:ClearAllPoints(); button:SetScale(1); button:SetSize(data.iconSize,data.iconSize)
        button:SetPoint('TOPLEFT',self.tray,'TOPLEFT',10+(position%data.columns)*step,-10-math.floor(position/data.columns)*step)
        button:SetFrameStrata('DIALOG'); button:SetFrameLevel(self.tray:GetFrameLevel()+2)
    end
    local count=#list
    self.tray:SetSize(20+math.max(1,math.min(count,data.columns))*step-data.spacing,
        20+math.max(1,math.ceil(count/data.columns))*step-data.spacing)
    self.count=count
    self:AnchorTray()
end

function M:Build()
    self.rows={}; local found,launchers=self:FindButtons()
    local data=self:Data()
    for b,s in pairs(self.collected) do if not s.parked then found[b]=s.name end end
    for b,name in pairs(found) do self.rows[#self.rows+1]={id=name,name=name,button=b,text=(data.showNames and name:gsub('^LibDBIcon10_','') or 'Addon button')..(self.collected[b] and ' | In tray' or ' | Not collected')} end
    for _,entry in pairs(launchers) do
        self.rows[#self.rows+1]={id=entry.name,name=entry.name,
            text=(data.showNames and entry.title or 'Addon button')..(data.excluded[entry.name] and ' | Excluded' or ' | In tray')}
    end
    table.sort(self.rows,function(a,b) return a.name<b.name end)
    self.status='Use the minimap tray button. Select a listed icon to include or exclude it. Includes minimap, broker and game AddOns-menu launchers.'
    if self:OtherCollector() then self.status='Another collector already owns your icons. Click Tray to choose ForeverSuite or keep that collector.' end
end
M.actions={{label='Tray',run=function(self) self:ToggleTray() end},
    {label='Include / Exclude',run=function(self) if self.selected then local d=self:Data(); d.excluded[self.selected.name]=not d.excluded[self.selected.name] or nil; self:SettingsChanged() end end},
    {label='Rescan',run=function(self) self:Scan() end}}
function M:Apply() self:Scan() end
function M:StopCapture() self:Scan(); if self.conflict then self.conflict:Hide() end end
function M:Event(event)
    if event=='PLAYER_REGEN_DISABLED' then
        if self.tray then self.tray:Hide() end
        if self.dragging then self.button:StopMovingOrSizing(); self.dragging=nil; self.button.fsDirectDragging=nil end
        return
    end
    if self.scanQueued then return end; self.scanQueued=true
    C_Timer.After(.5,function()
        self.scanQueued=nil; self:Scan()
        if self:OtherCollector() and not self.prompted and not (FS.Installer and FS.Installer.window and FS.Installer.window:IsShown()) then self:ShowCollectorChoice(); self.prompted=true end
    end)
end
local render=M.Render
function M:Render() render(self); if self.window then self.window.input:Hide() end end
