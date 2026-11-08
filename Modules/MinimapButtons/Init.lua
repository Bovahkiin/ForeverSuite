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
function M:Candidate(button)
    if not button or button==self.button or button==self.tray or (button.IsForbidden and button:IsForbidden()) then return end
    if button.IsProtected and button:IsProtected() then return end
    if not button.GetObjectType or button:GetObjectType()~='Button' then return end
    local name=T:Text(button:GetName()); if name=='' or blocked[name] then return end
    -- Only addon naming conventions, never arbitrary native minimap children.
    if button~=FS.minimapButton and not name:match('^LibDBIcon10_') and not name:lower():find('minimapbutton',1,true)
        and not name:lower():find('minimapicon',1,true) then return end
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
    f:SetPoint('TOPRIGHT',Minimap,'BOTTOMRIGHT',0,-12); f:Hide()
    local b=CreateFrame('Button','ForeverSuiteAddonButtonsToggle',Minimap,'BackdropTemplate'); self.button=b
    H:Skin(b); b:SetSize(32,32); b:SetPoint('TOPRIGHT',Minimap,'TOPLEFT',-5,0)
    b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetPoint('TOPLEFT',4,-4); b.icon:SetPoint('BOTTOMRIGHT',-4,4); b.icon:SetTexture('Interface\\Icons\\INV_Misc_EngGizmos_17')
    b:SetScript('OnClick',function() if InCombatLockdown() then return end; self:Scan(); f:SetShown(not f:IsShown()) end)
    b:SetScript('OnEnter',function() GameTooltip:SetOwner(b,'ANCHOR_LEFT'); GameTooltip:AddLine('ForeverSuite - Addon Buttons'); GameTooltip:AddLine('Click to open or close the addon tray.',1,1,1); GameTooltip:Show() end)
    b:SetScript('OnLeave',function() GameTooltip:Hide() end)
    FS.Layout:Register('AddonButtons',b,'Addon Buttons')
end
function M:FindButtons()
    local found={}
    for _,key in ipairs({'Minimap','MinimapBackdrop','MinimapCluster'}) do
        local parent=_G[key]
        if parent and parent.GetChildren then for _,b in ipairs({parent:GetChildren()}) do local n=self:Candidate(b); if n then found[b]=n end end end
    end
    if type(LibStub)=='table' or type(LibStub)=='function' then
        local ok,lib=pcall(function() return LibStub('LibDBIcon-1.0',true) end)
        if ok and lib and lib.GetButtonList and lib.GetMinimapButton then
            local names=T:Call(lib.GetButtonList,lib)
            if type(names)=='table' then for _,n in ipairs(names) do local b=T:Call(lib.GetMinimapButton,lib,n); local name=self:Candidate(b); if name then found[b]=name end end end
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
    for b,name in pairs(self:FindButtons()) do
        local parent=b:GetParent()
        if not d.excluded[name] and b:IsShown() and not self.collected[b] and (parent==Minimap or parent==MinimapBackdrop or parent==MinimapCluster) then
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
end
function M:Build()
    self.rows={}; local found=self:FindButtons()
    for b,s in pairs(self.collected) do found[b]=s.name end
    for b,name in pairs(found) do self.rows[#self.rows+1]={id=name,name=name,button=b,text=(self:Data().showNames and name:gsub('^LibDBIcon10_','') or 'Addon button')..(self:Data().excluded[name] and ' | On minimap' or ' | In tray')} end
    table.sort(self.rows,function(a,b) return a.name<b.name end)
    self.status='Use the minimap tray button. Select a listed icon to include or exclude it. Protected game buttons are left untouched.'
end
M.actions={{label='Tray',run=function(self) self:Scan(); if self.tray then self.tray:SetShown(not self.tray:IsShown()) end end},
    {label='Include / Exclude',run=function(self) if self.selected then local d=self:Data(); d.excluded[self.selected.name]=not d.excluded[self.selected.name] or nil; self:SettingsChanged() end end},
    {label='Rescan',run=function(self) self:Scan() end}}
function M:Apply() self:Scan() end
function M:StopCapture() self:Scan() end
function M:Event(event)
    if event=='PLAYER_REGEN_DISABLED' then if self.tray then self.tray:Hide() end; return end
    if self.scanQueued then return end; self.scanQueued=true
    C_Timer.After(.5,function() self.scanQueued=nil; self:Scan() end)
end
local render=M.Render
function M:Render() render(self); if self.window then self.window.input:Hide() end end
