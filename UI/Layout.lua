local _, FS = ...
local L={targets={},handles={}}; FS.Layout=L
function L:QueueApply(id)
    self.queued=self.queued or {}
    if self.queued[id] then return end; self.queued[id]=true
    C_Timer.After(0,function() self.queued[id]=nil; self:Apply(id) end)
end
function L:Register(id,frame,title)
    if FS.modules.ActionBars and FS.modules.ActionBars:IsNativeBar(id) then return end
    if not frame or (self.targets[id] and self.targets[id].frame==frame) then return end
    self.targets[id]={frame=frame,title=title or id,points=FS.HUD:SavePoints(frame),scale=frame:GetScale()}
    frame:HookScript("OnShow",function() self:QueueApply(id) end)
    hooksecurefunc(frame,"SetPoint",function() if not self.applying then self:QueueApply(id) end end)
    if id=="Minimap" then hooksecurefunc(frame,"SetScale",function() if not self.applying then self:QueueApply(id) end end) end
    self:Apply(id)
end
function L:Apply(id)
    if self.applying or InCombatLockdown() or not FS.db then return end
    if FS.modules.ActionBars and FS.modules.ActionBars:IsNativeBar(id) then return end
    local target=self.targets[id]; local saved=FS.db.layout.frames[id]
    if not target or not saved then return end
    if (id=="MainMenu" or id=="BagsBar" or id:find("Bar")) and not FS:IsModuleEnabled("ActionBars") then return end
    local f=target.frame
    local scale=saved.scale or 1
    local parent=f:GetParent() or UIParent
    local ratio=parent:GetEffectiveScale()*scale/UIParent:GetEffectiveScale()
    local halfWidth=math.min(UIParent:GetWidth()/2,f:GetWidth()*ratio/2)
    local halfHeight=math.min(UIParent:GetHeight()/2,f:GetHeight()*ratio/2)
    -- The client can report a temporary smaller viewport during startup.
    -- Constrain the visual only; restoring must never rewrite saved positions.
    local centerX=math.max(-UIParent:GetWidth()/2+halfWidth,math.min(UIParent:GetWidth()/2-halfWidth,saved.x))
    local centerY=math.max(halfHeight,math.min(UIParent:GetHeight()-halfHeight,saved.y))
    -- Saved centers are UIParent units. SetPoint offsets use the scaled
    -- frame's units, so convert them before anchoring the resized frame.
    local offsetX,offsetY=centerX/ratio,centerY/ratio
    local point,relative,anchor,x,y=f:GetPoint()
    if f:GetNumPoints()==1 and point=="CENTER" and relative==UIParent and anchor=="BOTTOM" and x==offsetX and y==offsetY and f:GetScale()==scale then return end
    self.applying=true
    f:SetScale(scale); f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"BOTTOM",offsetX,offsetY)
    self.applying=false
end
function L:ConstrainSaved(id)
    local target=self.targets[id]; local saved=FS.db.layout.frames[id]
    if not target or not saved then return end
    local f=target.frame; local parent=f:GetParent() or UIParent
    local ratio=parent:GetEffectiveScale()*(saved.scale or 1)/UIParent:GetEffectiveScale()
    local halfWidth=math.min(UIParent:GetWidth()/2,f:GetWidth()*ratio/2)
    local halfHeight=math.min(UIParent:GetHeight()/2,f:GetHeight()*ratio/2)
    saved.x=math.max(-UIParent:GetWidth()/2+halfWidth,math.min(UIParent:GetWidth()/2-halfWidth,saved.x))
    saved.y=math.max(halfHeight,math.min(UIParent:GetHeight()-halfHeight,saved.y))
end
function L:ApplyAll() for id in pairs(self.targets) do self:Apply(id) end end
-- Only move our own menu, never the game's meter or protected action bars.
function L:AvoidMeterOverlap()
    if self.active or self.applying or InCombatLockdown() or not FS.db or not FS:IsModuleEnabled("ActionBars") or not FS.db.actionBars.menu then return end
    local menu=FS.modules.ActionBars.menuRoot
    if not menu or not menu:IsShown() then return end
    local function bounds(f)
        if not f or not f.GetRect or not f:IsShown() or (f.IsForbidden and f:IsForbidden()) then return end
        local x,y,w,h=FS.Tools:Call(f.GetRect,f)
        if not FS.Tools:Number(x) or not FS.Tools:Number(y) or not FS.Tools:Number(w) or not FS.Tools:Number(h) or w<=0 or h<=0 then return end
        local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        return x*scale,y*scale,w*scale,h*scale
    end
    local x,y,w,h=bounds(menu); if not x then return end
    local seen,meters={},{}
    local function add(f) if f and not seen[f] then seen[f]=true; meters[#meters+1]=f end end
    if DamageMeter and DamageMeter.ForEachSessionWindow and DamageMeter.windowDataList then DamageMeter:ForEachSessionWindow(add) end
    for i=1,5 do add(_G["DamageMeterSessionWindow"..i]) end
    if #meters==0 then add(DamageMeter) end
    local changed=false
    for _,meter in ipairs(meters) do
        local mx,my,mw,mh=bounds(meter)
        if mx and mh<UIParent:GetHeight()/2 and x<mx+mw+12 and x+w>mx-12 and y<my+mh+12 and y+h>my-12 then
            local below=my-12-h
            if below>=8 then y=below
            else x=math.min(UIParent:GetWidth()-w-8,mx+mw+12) end
            changed=true
        end
    end
    if changed then
        FS.db.layout.frames.MainMenu={x=x+w/2-UIParent:GetWidth()/2,y=y+h/2,scale=menu:GetScale()}
        self:Apply("MainMenu")
    end
end
function L:Collect()
    local U,A=FS.modules.UnitFrames,FS.modules.ActionBars
    for _,unit in ipairs({"player","target","focus","pet"}) do self:Register("Unit:"..unit,U.frames[unit],unit=="player" and "Player" or unit=="target" and "Target" or unit=="pet" and "Pet" or "Focus") end
    for kind,header in pairs(U.groups or {}) do self:Register("UnitGroup:"..kind,header,kind=="party" and "Party" or "Raid") end
    for _,name in ipairs({"MainActionBar","MainMenuBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarLeft","MultiBarRight","StanceBar","PetActionBar","BagsBar"}) do
        if not (name=="MainMenuBar" and MainActionBar) then self:Register(name,_G[name],name) end
    end
    local minimap=MinimapCluster and MinimapCluster.SetScale and MinimapCluster or Minimap
    self:Register("Minimap",minimap,"Minimap")
    self:Register("MainMenu",A.menuRoot,"Main Menu")
    self:Register("CharacterInfo",CharacterFrame,"Character Info")
    self:Register("ControlCenter",FS.window,"Control Center")
    self:Register("Bags",FS.modules.Bags.window,"Inventory")
    self:Register("Gear",FS.modules.Gear.window,"Gear Overview")
    self:Register("GearButton",FS.modules.Gear.indicator,"Gear Button")
    self:Register("Vendor",FS.modules.Vendor.window,"Vendor & Junk")
    self:Register("JunkReview",FS.modules.Vendor.saleReview,"Junk Review")
end
function L:UpdateGrid()
    local f=self.overlay; if not f then return end
    f.gridLines=f.gridLines or {}
    local count=0
    for _,axis in ipairs({"vertical","horizontal"}) do
        local half=(axis=="vertical" and UIParent:GetWidth() or UIParent:GetHeight())/2
        for step=-math.floor(half/32),math.floor(half/32) do
            if step~=0 then
                count=count+1
                local line=f.gridLines[count]
                if not line then line=f:CreateTexture(nil,"BACKGROUND"); f.gridLines[count]=line; line:SetColorTexture(.12,.72,.86,.16) end
                line:ClearAllPoints(); line:SetSize(1,1)
                if axis=="vertical" then
                    line:SetPoint("TOP",f,"TOP",step*32,0); line:SetPoint("BOTTOM",f,"BOTTOM",step*32,0)
                else
                    line:SetPoint("LEFT",f,"LEFT",0,step*32); line:SetPoint("RIGHT",f,"RIGHT",0,step*32)
                end
                line:Show()
            end
        end
    end
    for i=count+1,#f.gridLines do f.gridLines[i]:Hide() end
end
function L:CreateGrid()
    if self.overlay then self:UpdateGrid(); return end
    local H=FS.HUD; local f=CreateFrame("Frame","ForeverSuiteMoveFrames",UIParent,"BackdropTemplate"); self.overlay=f
    f:SetAllPoints(); f:SetFrameStrata("DIALOG"); f:EnableMouse(false)
    self:UpdateGrid(); f:SetScript("OnSizeChanged",function() L:UpdateGrid() end)
    f.centerVertical=f:CreateTexture(nil,"ARTWORK")
    f.centerVertical:SetColorTexture(0.12,0.72,0.86,0.8)
    f.centerVertical:SetWidth(3)
    f.centerVertical:SetPoint("TOP",f,"TOP",0,0)
    f.centerVertical:SetPoint("BOTTOM",f,"BOTTOM",0,0)
    f.centerHorizontal=f:CreateTexture(nil,"ARTWORK")
    f.centerHorizontal:SetColorTexture(0.12,0.72,0.86,0.8)
    f.centerHorizontal:SetHeight(3)
    f.centerHorizontal:SetPoint("LEFT",f,"LEFT",0,0)
    f.centerHorizontal:SetPoint("RIGHT",f,"RIGHT",0,0)
    local toolbar=CreateFrame("Frame",nil,f,"BackdropTemplate"); H:Skin(toolbar)
    toolbar:SetSize(610,65); toolbar:SetPoint("TOP",0,-20); toolbar:EnableMouse(true)
    H:Label(toolbar,"MOVE FRAMES  |  Drag handles to move. Drag the corner arrow to resize.",12,-9,586)
    f.done=H:Button(toolbar,"Done",12,-30,140,function() self:Stop(); FS:ShowConfig() end)
    f.snap=H:Button(toolbar,"",162,-30,140,function() FS.db.layout.snap=not FS.db.layout.snap; self:UpdateToolbar() end)
    f.reset=H:Button(toolbar,"Reset positions",312,-30,140,function() self:Reset() end)
    f.close=H:Button(toolbar,"Cancel",462,-30,136,function()
        FS.db.layout.frames=self.before; self:Stop()
        self.applying=true
        for id,state in pairs(self.beforeVisual) do
            local frame=self.targets[id].frame; H:RestorePoints(frame,state.points); frame:SetScale(state.scale)
        end
        self.applying=false; self:ApplyAll(); FS.modules.Nameplates:SettingsChanged(); FS:ShowConfig()
    end)
    f:Hide(); UISpecialFrames[#UISpecialFrames+1]="ForeverSuiteMoveFrames"
    f:SetScript("OnHide",function() if self.active then self:Stop() end end)
end
function L:UpdateToolbar() self.overlay.snap:SetText("Snap to grid: "..(FS.db.layout.snap and "On" or "Off")) end
function L:Save(id,handle,scale,dragging)
    if InCombatLockdown() then return end
    local f=self.targets[id].frame
    local x,y=handle:GetCenter(); local ux=UIParent:GetCenter(); local ratio=handle:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if not x or not y or not ux then return end
    x,y=x*ratio-ux,y*ratio
    if FS.db.layout.snap and not dragging then
        local centerY=UIParent:GetHeight()/2
        x=math.floor(x/32+0.5)*32; y=centerY+math.floor((y-centerY)/32+0.5)*32
    end
    FS.db.layout.frames[id]={x=x,y=y,scale=scale or f:GetScale()}
    self:ConstrainSaved(id)
    self:Apply(id)
    if not dragging then handle:ClearAllPoints(); handle:SetPoint("CENTER",f,"CENTER") end
end
function L:Resize(id,handle)
    local start=handle.resizeStart
    if InCombatLockdown() then self:Stop(); return end
    if not start or not self.active then return end
    local x,y=GetCursorPosition(); local uiScale=UIParent:GetEffectiveScale()
    local delta=((x-start.x)-(y-start.y))/uiScale
    local scale=math.max(.6,math.min(1.4,start.scale+delta/200))
    FS.db.layout.frames[id]={x=start.centerX,y=start.centerY,scale=scale}
    self:ConstrainSaved(id)
    self:Apply(id)
    handle.caption:SetText(self.targets[id].title.."  "..math.floor(scale*100+.5).."%")
end
function L:Start()
    if InCombatLockdown() then FS:Print("Leave combat to move frames."); return end
    if self.active then self:Stop(); return end
    self:CreateGrid(); self:Collect()
    self.before={}; for id,v in pairs(FS.db.layout.frames) do self.before[id]={x=v.x,y=v.y,scale=v.scale} end
    self.beforeVisual={}; for id,target in pairs(self.targets) do self.beforeVisual[id]={points=FS.HUD:SavePoints(target.frame),scale=target.frame:GetScale()} end
    if FS.window then FS.window:Hide() end
    self.active=true; self.overlay:Show(); self:UpdateToolbar()
    for id,target in pairs(self.targets) do
        local h=self.handles[id]
        if not h then
            h=CreateFrame("Frame",nil,self.overlay,"BackdropTemplate"); FS.HUD:Skin(h); self.handles[id]=h
            h:SetSize(160,36); h:SetMovable(true); h:EnableMouse(true); h:EnableMouseWheel(true); h:RegisterForDrag("LeftButton"); h:SetClampedToScreen(true)
            h.caption=FS.HUD:Label(h,target.title,8,-10,124)
            h.resize=CreateFrame("Button",nil,h,"BackdropTemplate"); FS.HUD:Skin(h.resize)
            h.resize:SetSize(24,24); h.resize:SetPoint("BOTTOMRIGHT",h,"BOTTOMRIGHT",-2,2)
            h.resize:SetFrameLevel(h:GetFrameLevel()+2); h.resize:EnableMouse(true); h.resize:RegisterForDrag("LeftButton")
            local arrow=FS.Widgets:Label(h.resize); arrow:SetPoint("CENTER"); arrow:SetText("+/-")
            local function begin()
                if not self.active or InCombatLockdown() or h.resizeStart then return end
                self:Save(id,h,nil,true)
                local placement=FS.db.layout.frames[id]; if not placement then return end
                local x,y=GetCursorPosition(); h.resizeStart={x=x,y=y,scale=target.frame:GetScale(),centerX=placement.x,centerY=placement.y}
            end
            local function finish() self:Resize(id,h); h.resizeStart=nil end
            h.resize:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then begin() end end)
            h.resize:SetScript("OnDragStart",begin)
            h.resize:SetScript("OnMouseUp",finish); h.resize:SetScript("OnDragStop",finish)
            h.resize:SetScript("OnUpdate",function() self:Resize(id,h) end)
            h.resize:SetScript("OnEnter",function(b) GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine("Drag to resize"); GameTooltip:AddLine("Outward: larger. Inward: smaller."); GameTooltip:Show() end)
            h.resize:SetScript("OnLeave",function() GameTooltip:Hide() end)
            h:SetScript("OnDragStart",function(frame)
                if not InCombatLockdown() then frame.dragging=true; frame:StartMoving() end
            end)
            h:SetScript("OnUpdate",function(frame)
                if frame.dragging and self.active and not InCombatLockdown() then self:Save(id,frame,nil,true) end
            end)
            h:SetScript("OnDragStop",function(frame)
                frame.dragging=false; frame:StopMovingOrSizing(); self:Save(id,frame)
            end)
            h:SetScript("OnMouseWheel",function(frame,delta)
                local scale=math.max(0.6,math.min(1.4,target.frame:GetScale()+delta*0.05)); self:Save(id,frame,scale)
            end)
        end
        h:ClearAllPoints(); h:SetPoint("CENTER",target.frame,"CENTER")
        -- Hidden windows and the target frame still have movable handles.
        h.caption:SetText(target.title.."  "..math.floor(target.frame:GetScale()*100+.5).."%")
        h:Show()
    end
end
function L:Stop()
    self.active=false
    for _,h in pairs(self.handles) do h.dragging=false; h.resizeStart=nil; h:StopMovingOrSizing(); h:Hide() end
    if self.overlay then self.overlay:Hide() end
end
function L:Reset()
    if InCombatLockdown() then return end
    FS.db.layout.frames={}
    self.applying=true
    for _,target in pairs(self.targets) do FS.HUD:RestorePoints(target.frame,target.points); target.frame:SetScale(target.scale) end
    self.applying=false
    FS.modules.UnitFrames:SettingsChanged(); FS.modules.ActionBars:SettingsChanged()
    FS.modules.Nameplates:SettingsChanged()
    if CharacterFrame and FS.modules.Character then FS.modules.Character:SettingsChanged() end
    self:Stop(); self:Start()
end
function L:Normalize()
    local V=FS.modules.Vendor
    for id,p in pairs(FS.db.layout.frames) do
        if type(p)~="table" or not V:ValidNumber(p.x,-10000,10000) or not V:ValidNumber(p.y,0,10000) then FS.db.layout.frames[id]=nil
        else p.scale=V:ValidNumber(p.scale,0.6,1.4) or 1 end
    end
end
local events=CreateFrame("Frame")
FS:RegisterClientEvent(events,"PLAYER_REGEN_DISABLED"); FS:RegisterClientEvent(events,"PLAYER_REGEN_ENABLED")
FS:RegisterClientEvent(events,"PLAYER_ENTERING_WORLD")
FS:RegisterClientEvent(events,"DISPLAY_SIZE_CHANGED"); FS:RegisterClientEvent(events,"UI_SCALE_CHANGED")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then L:Stop()
    elseif event=="PLAYER_ENTERING_WORLD" or event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED" then
        if not L.viewportPending then
            L.viewportPending=true; C_Timer.After(0,function() L.viewportPending=false; L:ApplyAll() end)
        end
    else L:ApplyAll() end
end)
