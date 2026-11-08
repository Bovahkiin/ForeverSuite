local _,FS=...
local T,H=FS.Tools,FS.HUD
local M=T:Module('MinimapButtons','minimapButtons','Addon Buttons','One themed tray for addon minimap buttons. Original button clicks and tooltips remain owned by their addons.',
    {columns=6,iconSize=30,spacing=4,showNames=true,excluded={}}, {'ADDON_LOADED','PLAYER_ENTERING_WORLD','PLAYER_REGEN_DISABLED'})
M.collected={}
M.options={{key='columns',label='Tray columns',values={4,6,8}},{key='iconSize',label='Icon size',values={24,30,36}},
    {key='spacing',label='Icon spacing',values={2,4,8}},{key='showNames',label='Show names in the button list'}}
local blocked={MiniMapTracking=true,MiniMapTrackingButton=true,MinimapZoomIn=true,MinimapZoomOut=true,MiniMapMailFrame=true,
    MiniMapWorldMapButton=true,GameTimeFrame=true,QueueStatusMinimapButton=true,MinimapBackdrop=true,Minimap=true,
    MinimapCluster=true,ExpansionLandingPageMinimapButton=true,TimeManagerClockButton=true,MiniMapInstanceDifficulty=true}
function M:Normalize()
    local d=self:Data(); if type(d.excluded)~='table' then d.excluded={} end
    for key,value in pairs(d.excluded) do if type(key)~='string' or value~=true then d.excluded[key]=nil end end
end
function M:Candidate(button,registered)
    if not button or button==self.button or button==self.tray or (button.IsForbidden and button:IsForbidden()) then return end
    if button.IsProtected and button:IsProtected() then return end
    if not button.GetObjectType or (button:GetObjectType()~='Button' and button:GetObjectType()~='CheckButton') then return end
    local name=T:Text(button:GetName()); if name=='' or blocked[name] then return end
    if name:match('^Blizzard_') or button.pinTemplate or button.dataProvider or button.uiMapID or button.unit then return end
    -- Only addon naming conventions, never arbitrary native minimap children.
    if not registered and button~=FS.minimapButton and not name:match('^LibDBIcon10_') and not name:lower():find('minimapbutton',1,true)
        and not name:lower():find('minimapicon',1,true) and not name:match('^DBM.*[Bb]utton$') and not name:match('^Pawn.*[Bb]utton$') then return end
    return name
end
function M:Restore(button)
    local s=self.collected[button]; if not s then return end
    if InCombatLockdown() then self.pending=true; return end
    if button.IsProtected and button:IsProtected() then self.pending=true; return end
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
    local b=CreateFrame('Button','ForeverSuiteAddonButtonsToggle',UIParent,'BackdropTemplate'); self.button=b
    H:Skin(b); b:SetSize(32,32); b:SetPoint('TOPRIGHT',Minimap,'TOPLEFT',-5,0)
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
    b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetPoint('TOPLEFT',4,-4); b.icon:SetPoint('BOTTOMRIGHT',-4,4); b.icon:SetTexture('Interface\\Icons\\INV_Misc_EngGizmos_17')
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
    self:Scan(); self:AnchorTray(); if self.tray then self.tray:SetShown(not self.tray:IsShown()) end
end
function M:FindButtons()
    local found={}; self.registered={}; local visited={}
    local function scan(parent,depth)
        if not parent or visited[parent] or depth>3 or (parent.IsForbidden and parent:IsForbidden()) then return end
        visited[parent]=true
        if parent.GetChildren then for _,b in ipairs({parent:GetChildren()}) do
            local n=self:Candidate(b); if n then found[b]=n
            elseif b~=self.tray and b~=self.button and not (b.IsProtected and b:IsProtected()) then scan(b,depth+1) end
        end end
    end
    for _,key in ipairs({'Minimap','MinimapBackdrop','MinimapCluster'}) do
        local parent=_G[key]
        scan(parent,0)
    end
    if type(LibStub)=='table' or type(LibStub)=='function' then
        local ok,lib=pcall(function() return LibStub('LibDBIcon-1.0',true) end)
        if ok and lib and lib.GetButtonList and lib.GetMinimapButton then
            local names=T:Call(lib.GetButtonList,lib)
            if type(names)=='table' then for _,n in ipairs(names) do local b=T:Call(lib.GetMinimapButton,lib,n); local name=self:Candidate(b,true); if name then found[b]=name; self.registered[b]=true end end end
        end
    end
    return found
end
function M:Scan()
    if InCombatLockdown() then self.pending=true; return end
    self:CreateTray(); if not self.tray then return end
    if not FS:IsModuleEnabled(self.name) then
        local list={}; for b in pairs(self.collected) do list[#list+1]=b end
        for _,b in ipairs(list) do self:Restore(b) end
        self.tray:Hide(); self.button:Hide(); return
    end
    self.button:Show(); local d=self:Data()
    if self:OtherCollector() then self.tray:Hide(); self.status='Another collector is active. Click the tray button to choose one.'; return end
    for b,name in pairs(self:FindButtons()) do
        local parent=b:GetParent()
        local nested=parent
        for _=1,5 do if not nested or nested==Minimap or nested==MinimapBackdrop or nested==MinimapCluster then break end; nested=nested.GetParent and nested:GetParent() end
        if not d.excluded[name] and b:IsShown() and not self.collected[b] and (nested==Minimap or nested==MinimapBackdrop or nested==MinimapCluster or self.registered[b]) then
            local width,height,scale=b:GetWidth(),b:GetHeight(),b:GetScale()
            if T:Number(width) and T:Number(height) and T:Number(scale) then
                self.collected[b]={name=name,parent=b:GetParent(),points=H:SavePoints(b),width=width,height=height,scale=scale,strata=b:GetFrameStrata(),level=b:GetFrameLevel()}
                b:SetParent(self.tray)
            end
        end
    end
    local list={}
    for b,s in pairs(self.collected) do
        if d.excluded[s.name] then self:Restore(b)
        elseif not (b.IsProtected and b:IsProtected()) then list[#list+1]={button=b,name=s.name} end
    end
    table.sort(list,function(a,b) return a.name<b.name end)
    local count=0
    for _,entry in ipairs(list) do
        local b=entry.button
        if b:IsShown() then
            b:ClearAllPoints(); b:SetScale(1); b:SetSize(d.iconSize,d.iconSize)
            b:SetPoint('TOPLEFT',self.tray,'TOPLEFT',10+(count%d.columns)*(d.iconSize+d.spacing),-10-math.floor(count/d.columns)*(d.iconSize+d.spacing))
            b:SetFrameStrata('DIALOG'); b:SetFrameLevel(self.tray:GetFrameLevel()+2); count=count+1
        end
    end
    self.tray:SetSize(20+math.max(1,math.min(count,d.columns))*(d.iconSize+d.spacing)-d.spacing,
        20+math.max(1,math.ceil(count/d.columns))*(d.iconSize+d.spacing)-d.spacing)
    self.count=count
    self:AnchorTray()
end
function M:Build()
    self.rows={}; local found=self:FindButtons()
    for b,s in pairs(self.collected) do found[b]=s.name end
    for b,name in pairs(found) do self.rows[#self.rows+1]={id=name,name=name,button=b,text=(self:Data().showNames and name:gsub('^LibDBIcon10_','') or 'Addon button')..(self.collected[b] and ' | In tray' or ' | Not collected')} end
    table.sort(self.rows,function(a,b) return a.name<b.name end)
    self.status='Use the minimap tray button. Select a listed icon to include or exclude it. Protected game buttons are left untouched.'
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
