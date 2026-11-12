local _, FS = ...
local L={targets={},handles={}}; FS.Layout=L
function L:Placements()
    return self.draft or FS.db.layout.frames
end
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
    local target=self.targets[id]; local saved=self:Placements()[id]
    if not target or not saved then return end
    if (id=="MainMenu" or id=="BagsBar" or id:find("Bar")) and not FS:IsModuleEnabled("ActionBars") then return end
    local f=target.frame
    if f.fsDirectDragging then return end
    if id=="ControlCenter" and f==FS.window and FS.LayoutConfigText then FS:LayoutConfigText(); return end
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
    self:RememberPreview(id)
    self.applying=true
    f:SetScale(scale); f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"BOTTOM",offsetX,offsetY)
    self.applying=false
    if id=="Unit:player" then FS.modules.UnitFrames:ApplyPetDefault() end
end
function L:ConstrainSaved(id)
    local target=self.targets[id]; local saved=self:Placements()[id]
    if not target or not saved then return end
    local f=target.frame; local parent=f:GetParent() or UIParent
    local ratio=parent:GetEffectiveScale()*(saved.scale or 1)/UIParent:GetEffectiveScale()
    local halfWidth=math.min(UIParent:GetWidth()/2,f:GetWidth()*ratio/2)
    local halfHeight=math.min(UIParent:GetHeight()/2,f:GetHeight()*ratio/2)
    saved.x=math.max(-UIParent:GetWidth()/2+halfWidth,math.min(UIParent:GetWidth()/2-halfWidth,saved.x))
    saved.y=math.max(halfHeight,math.min(UIParent:GetHeight()-halfHeight,saved.y))
end
function L:ApplyAll()
    for id in pairs(self.targets) do self:Apply(id) end
    FS.modules.UnitFrames:ApplyPetDefault()
end
-- Only move our own menu, never the game's meter or protected action bars.
function L:AvoidMeterOverlap()
    if self.active then return end
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
    f.toolbar=toolbar; toolbar:SetSize(760,65); toolbar:SetPoint("TOP",0,-20); toolbar:EnableMouse(true)
    f.toolbarHint=H:Label(toolbar,"MOVE FRAMES  |  Drag handles to move. Drag the corner arrow to resize.",12,-9,736)
    f.save=H:Button(toolbar,"Save",12,-30,132,function() self:SaveChanges(false) end)
    f.done=H:Button(toolbar,"Save & close",154,-30,132,function() self:SaveChanges(true) end)
    f.snap=H:Button(toolbar,"",296,-30,142,function() self.draftSnap=not self.draftSnap; self:UpdateToolbar() end)
    f.reset=H:Button(toolbar,"Reset positions",448,-30,142,function() self:Reset() end)
    f.close=H:Button(toolbar,"Cancel",600,-30,148,function()
        self:Stop(); FS:ShowConfig()
    end)
    f.selection=H:Label(toolbar,"Click a handle for alignment tools.",12,-80,736)
    f.center=H:Button(toolbar,"Center selected frame",12,-110,234,function() self:AlignSelected("center") end)
    f.below=H:Button(toolbar,"Below player frame",262,-110,234,function() self:AlignSelected("below") end)
    f.restore=H:Button(toolbar,"Restore this frame",512,-110,234,function() self:AlignSelected("restore") end)
    f.sameHeight=H:Button(toolbar,"Align to same height",12,-150,352,function() self:AlignSelected("height") end)
    f.leftEdges=H:Button(toolbar,"Align left edges",388,-150,352,function() self:AlignSelected("left") end)
    f:Hide(); UISpecialFrames[#UISpecialFrames+1]="ForeverSuiteMoveFrames"
    f:SetScript("OnHide",function() if self.active then self:Stop() end end)
end
function L:UpdateToolbar()
    local f=self.overlay; if not f then return end
    f.snap:SetText("Snap to grid: "..(self.draftSnap and "On" or "Off"))
    local y=FS.HUD:TextHeight(f.toolbarHint,736,2)+18; local height=0
    for _,b in ipairs({f.save,f.done,f.snap,f.reset,f.close}) do
        local point={b:GetPoint()}; b:ClearAllPoints(); b:SetPoint("TOPLEFT",point[4] or point[2],-y)
        height=math.max(height,FS.HUD:FitButton(b,3))
    end
    y=y+height+14
    f.selection:ClearAllPoints(); f.selection:SetPoint("TOPLEFT",12,-y)
    y=y+FS.HUD:TextHeight(f.selection,736,2)+10
    height=0
    for i,b in ipairs({f.center,f.below,f.restore}) do
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",12+(i-1)*250,-y)
        b:SetEnabled(self.selected~=nil)
        height=math.max(height,FS.HUD:FitButton(b,2))
    end
    y=y+height+8; height=0
    local canAlign=self.selected and self.reference and self.selected~=self.reference
    for i,b in ipairs({f.sameHeight,f.leftEdges}) do
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",12+(i-1)*376,-y)
        b:SetEnabled(not not canAlign)
        height=math.max(height,FS.HUD:FitButton(b,2))
    end
    f.toolbar:SetHeight(y+height+12)
    f.toolbar:SetScale(math.min(1,(UIParent:GetWidth()-24)/760,(UIParent:GetHeight()-40)/f.toolbar:GetHeight()))
end
function L:Select(id,asReference)
    if not self.active or not self.targets[id] then return end
    if asReference then
        self.reference=self.reference~=id and id or nil
    else
        self.selected=id
    end
    local selected=self.selected and self.targets[self.selected].title or "Left-click a frame"
    local reference=self.reference and self.targets[self.reference].title or "Right-click another frame"
    self.overlay.selection:SetText("Selected: "..selected.."   |   Reference: "..reference)
    for key,handle in pairs(self.handles) do
        if key==self.selected then handle:SetBackdropBorderColor(.95,.68,.24,1)
        elseif key==self.reference then handle:SetBackdropBorderColor(.63,.88,.35,1)
        else handle:SetBackdropBorderColor(.12,.72,.86,1) end
    end
    self:UpdateToolbar()
end
function L:RestoreTarget(id)
    local target=self.targets[id]
    if not target then return end
    self:RememberPreview(id)
    self.applying=true
    FS.HUD:RestorePoints(target.frame,target.points)
    target.frame:SetScale(target.scale)
    self.applying=false
    if id=="Unit:pet" or id=="Unit:player" then FS.modules.UnitFrames:ApplyPetDefault() end
end
function L:AlignSelected(action)
    if not self.active or not self.selected or not FS.modules.Profiles:Allowed() then return false end
    local id=self.selected
    local target=self.targets[id]
    local f=target.frame
    if action=="restore" then
        self.draft[id]=nil
        self:RestoreTarget(id)
    else
        local usesReference=action=="height" or action=="left"
        local anchor=action=="below" and self.targets["Unit:player"] or usesReference and self.targets[self.reference]
        if action=="below" and (not anchor or id=="Unit:player") then
            FS:Print("Choose another frame to place below the player frame."); return false
        end
        if usesReference and (not anchor or anchor==target) then return false end
        local x,y=f:GetCenter()
        local ratio=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        if not FS.Tools:Number(x) or not FS.Tools:Number(y) then return false end
        local placement={x=0,y=y*ratio,scale=f:GetScale()}
        if anchor then
            local px,py=anchor.frame:GetCenter()
            if not FS.Tools:Number(px) or not FS.Tools:Number(py) then return false end
            local anchorRatio=anchor.frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
            local anchorX=px*anchorRatio-UIParent:GetWidth()/2
            if action=="height" then
                placement.x=x*ratio-UIParent:GetWidth()/2
                placement.y=py*anchorRatio
            elseif action=="left" then
                placement.x=anchorX-anchor.frame:GetWidth()*anchorRatio/2+f:GetWidth()*ratio/2
            else
                placement.x=anchorX
                placement.y=py*anchorRatio-anchor.frame:GetHeight()*anchorRatio/2-f:GetHeight()*ratio/2-10
            end
        end
        self.draft[id]=placement
        self:ConstrainSaved(id); self:Apply(id)
    end
    local handle=self.handles[id]
    handle:ClearAllPoints(); handle:SetPoint("CENTER",f,"CENTER")
    handle.caption:SetText(target.title.."  "..math.floor(f:GetScale()*100+.5).."%")
    return true
end
function L:Checkpoint()
    self.draft={}
    for id,v in pairs(FS.db.layout.frames) do self.draft[id]={x=v.x,y=v.y,scale=v.scale} end
    self.draftSnap=FS.db.layout.snap
    self.beforeVisual={}
end
function L:RememberPreview(id)
    if not self.draft or self.beforeVisual[id] then return end
    local frame=self.targets[id].frame
    self.beforeVisual[id]={frame=frame,points=FS.HUD:SavePoints(frame),scale=frame:GetScale()}
end
local function stopHandleUpdates(handle)
    handle:SetScript("OnUpdate",nil)
    handle.resize:SetScript("OnUpdate",nil)
end
function L:SaveChanges(close)
    if not self.active then return false end
    if InCombatLockdown() or FS.modules.Vendor.busy then FS:Print("Leave combat and finish vendor actions before saving the layout."); return false end
    for id,h in pairs(self.handles) do
        if h.resizeStart then self:Resize(id,h); h.resizeStart=nil end
        if h.dragging then h.dragging=false; h:StopMovingOrSizing(); self:Save(id,h) end
        stopHandleUpdates(h)
    end
    FS.db.layout.frames=self.draft
    FS.db.layout.snap=self.draftSnap
    FS.modules.Profiles:PersistCurrent(); self:Checkpoint()
    FS:Print("Layout saved to profile "..FS.db.profiles.current..".")
    self.overlay.toolbarHint:SetText("Saved to profile: "..FS.db.profiles.current..". Cancel reverts changes made after this save.")
    self:UpdateToolbar()
    if close then self:Stop(); FS:ShowConfig() end
    return true
end
function L:Save(id,handle,scale,dragging)
    if InCombatLockdown() then return end
    local f=self.targets[id].frame
    local x,y=handle:GetCenter(); local ux=UIParent:GetCenter(); local ratio=handle:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if not x or not y or not ux then return end
    x,y=x*ratio-ux,y*ratio
    local snap=FS.db.layout.snap
    if self.active then snap=self.draftSnap end
    if snap and not dragging then
        local centerY=UIParent:GetHeight()/2
        x=math.floor(x/32+0.5)*32; y=centerY+math.floor((y-centerY)/32+0.5)*32
    end
    local positions=self:Placements()
    scale=scale or f:GetScale()
    local current=positions[id]
    if dragging and current and current.x==x and current.y==y and current.scale==scale then return end
    positions[id]={x=x,y=y,scale=scale}
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
    if start.lastScale==scale then return end
    start.lastScale=scale
    self.draft[id]={x=start.centerX,y=start.centerY,scale=scale}
    self:ConstrainSaved(id)
    self:Apply(id)
    handle.caption:SetText(self.targets[id].title.."  "..math.floor(scale*100+.5).."%")
end
function L:Start()
    if InCombatLockdown() then FS:Print("Leave combat to move frames."); return end
    if self.active then self:Stop(); return end
    self:RestorePreview()
    self:CreateGrid(); self:Collect()
    self:Checkpoint()
    self.selected=nil; self.reference=nil
    self.overlay.selection:SetText("Left-click a frame to select it. Right-click another frame as a reference.")
    FS:CloseSettingsScreens()
    if FS.window then FS.window:Hide() end
    self.active=true; self.overlay.toolbarHint:SetText("LAYOUT STUDIO  |  Drag to move or resize. Save to keep the preview."); self.overlay:Show(); self:UpdateToolbar()
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
            local function resizeUpdate() self:Resize(id,h) end
            local function begin()
                if not self.active or InCombatLockdown() or h.resizeStart then return end
                self:Save(id,h,nil,true)
                local placement=self.draft[id]; if not placement then return end
                local x,y=GetCursorPosition(); h.resizeStart={x=x,y=y,scale=target.frame:GetScale(),centerX=placement.x,centerY=placement.y}
                h.resize:SetScript("OnUpdate",resizeUpdate)
            end
            local function finish()
                self:Resize(id,h); h.resizeStart=nil
                h.resize:SetScript("OnUpdate",nil)
            end
            h.resize:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then begin() end end)
            h.resize:SetScript("OnDragStart",begin)
            h.resize:SetScript("OnMouseUp",finish); h.resize:SetScript("OnDragStop",finish)
            h.resize:SetScript("OnEnter",function(b) GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine("Drag to resize"); GameTooltip:AddLine("Outward: larger. Inward: smaller."); GameTooltip:Show() end)
            h.resize:SetScript("OnLeave",function() GameTooltip:Hide() end)
            local function dragUpdate(frame)
                if frame.dragging and self.active and not InCombatLockdown() then self:Save(id,frame,nil,true) end
            end
            h:SetScript("OnDragStart",function(frame)
                self:Select(id)
                if not InCombatLockdown() then
                    frame.dragging=true; frame:StartMoving()
                    frame:SetScript("OnUpdate",dragUpdate)
                end
            end)
            h:SetScript("OnMouseDown",function(_,button) self:Select(id,button=="RightButton") end)
            h:SetScript("OnDragStop",function(frame)
                if not frame.dragging then return end
                frame.dragging=false; frame:SetScript("OnUpdate",nil); frame:StopMovingOrSizing(); self:Save(id,frame)
            end)
            h:SetScript("OnMouseWheel",function(frame,delta)
                local scale=math.max(0.6,math.min(1.4,target.frame:GetScale()+delta*0.05)); self:Save(id,frame,scale)
            end)
        end
        h:ClearAllPoints(); h:SetPoint("CENTER",target.frame,"CENTER")
        -- Hidden windows and the target frame still have movable handles.
        h.caption:SetText(target.title.."  "..math.floor(target.frame:GetScale()*100+.5).."%")
        h:SetBackdropBorderColor(.12,.72,.86,1)
        h:Show()
    end
end
function L:Stop()
    if not self.active then return end
    self.active=false
    self.draft=nil
    for _,h in pairs(self.handles) do
        h.dragging=false; h.resizeStart=nil; stopHandleUpdates(h); h:StopMovingOrSizing(); h:Hide()
    end
    if self.overlay then self.overlay:Hide() end
    if not InCombatLockdown() then self:RestorePreview() end
end
function L:RestorePreview()
    if not self.beforeVisual or self.active then return end
    self.applying=true
    for id,state in pairs(self.beforeVisual) do
        local target=self.targets[id]
        if target and target.frame==state.frame then
            FS.HUD:RestorePoints(state.frame,state.points)
            state.frame:SetScale(state.scale)
        end
    end
    self.applying=false
    self.beforeVisual=nil
    self:ApplyAll()
    return true
end
function L:Reset()
    if InCombatLockdown() or not self.active then return end
    self.draft={}
    self.applying=true
    for id,target in pairs(self.targets) do
        self:RememberPreview(id)
        FS.HUD:RestorePoints(target.frame,target.points); target.frame:SetScale(target.scale)
    end
    self.applying=false
    FS.modules.UnitFrames:SettingsChanged(); FS.modules.ActionBars:SettingsChanged()
    FS.modules.Nameplates:SettingsChanged()
    if CharacterFrame and FS.modules.Character then FS.modules.Character:SettingsChanged() end
    for id,handle in pairs(self.handles) do
        local target=self.targets[id]
        handle.dragging=false; handle.resizeStart=nil; stopHandleUpdates(handle); handle:StopMovingOrSizing()
        handle:ClearAllPoints(); handle:SetPoint("CENTER",target.frame,"CENTER")
        handle.caption:SetText(target.title.."  "..math.floor(target.frame:GetScale()*100+.5).."%")
    end
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
    elseif not L:RestorePreview() then L:ApplyAll() end
end)
