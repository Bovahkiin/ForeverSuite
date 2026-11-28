local _,FS=...
local W={native={},xpNative={},openingFrames={}}; FS.WindowManager=W
local names={"SpellBookFrame","PlayerSpellsFrame","QuestLogFrame","ProfessionsBookFrame","ProfessionsFrame","TradeSkillFrame","CraftFrame","FriendsFrame","ContactsFrame","AchievementFrame","CollectionsJournal","WardrobeFrame","CommunitiesFrame","GuildFrame","EncounterJournal","WorldMapFrame"}
function W:UsesSuiteStyle(name)
    if not FS.NativeWindows or not FS.initialized or not FS.db or (FS.db.extras and FS.db.extras.nativeWindows==false) then return false end
    if FS.Layout:IsExternallyManaged(name) then return false end
    for _,definition in ipairs(FS.NativeWindows.definitions) do
        if definition[1]==name then
            local module=FS.modules[definition[2]]
            return FS:IsModuleEnabled(definition[2]) and (not definition[5] or module:Data()[definition[5]])
        end
    end
    return false
end
function W:RememberGuildPlacement(frame)
    local state=self.native[frame]
    if not state or not state.guild or not frame:IsShown() then return end
    state.guildPoints=FS.HUD:SavePoints(frame); state.guildScale=frame:GetScale()
end
function W:StabilizeGuild(frame)
    local state=self.native[frame]
    if not state or not state.guild or state.placing or state.preparing or FS.Layout.applying or frame.fsDirectDragging
        or not frame:IsShown() or InCombatLockdown() or not self:UsesSuiteStyle(state.name) then return false end
    if FS.Layout:Placements()[state.name] then
        FS.Layout:Apply(state.name); self:RememberGuildPlacement(frame); return true
    end
    if not state.guildPoints then return false end
    local points=FS.HUD:SavePoints(frame); local same=#points==#state.guildPoints and frame:GetScale()==state.guildScale
    if same then for i,point in ipairs(points) do
        for j=1,5 do if point[j]~=state.guildPoints[i][j] then same=false; break end end
        if not same then break end
    end end
    if same then return true end
    state.placing=true
    frame:SetScale(state.guildScale); FS.HUD:RestorePoints(frame,state.guildPoints)
    state.placing=nil
    return true
end
function W:PrepareOpen(frame,finish)
    if InCombatLockdown() or self.openingFrames[frame] or (frame.IsForbidden and frame:IsForbidden()) then return false end
    local alpha=frame:GetAlpha()
    if not FS.Tools:Number(alpha) then return false end
    self.openingFrames[frame]=true
    frame:SetAlpha(0)
    -- Keep both the first show and the following native panel-position pass
    -- invisible. Reveal after styling and the saved mover position agree.
    C_Timer.After(0,function()
        local ok,err=true
        if frame:IsShown() and not InCombatLockdown() then ok,err=pcall(finish) end
        local function reveal()
            self.openingFrames[frame]=nil
            local current=frame:GetAlpha()
            if FS.Tools:Number(current) and current==0 then frame:SetAlpha(alpha) end
        end
        if ok then C_Timer.After(0,function()
            local placed,message=true
            if frame:IsShown() and not InCombatLockdown() then placed,message=pcall(finish) end
            reveal(); if not placed then error(message,0) end
        end) else reveal() end
        if not ok then error(err,0) end
    end)
    return true
end
function W:QueueNativeShown(frame,name)
    local state=self.native[frame]
    if not state or state.placing or self.opening or self.openingFrames[frame] then return end
    self.pendingNative={frame=frame,name=name}
    if self.nativeWorkPending then return end; self.nativeWorkPending=true
    C_Timer.After(0,function()
        self.nativeWorkPending=false
        local pending=self.pendingNative; self.pendingNative=nil
        if pending and pending.frame:IsShown() then self:NativeShown(pending.frame,pending.name) end
    end)
end
function W:NativeShown(frame,name)
    if not FS.initialized or self.opening or InCombatLockdown() then return end
    self.opening=true; FS:CloseOtherWindows(frame)
    -- Keep native spellbook hardware actions intact while clearing the top-left menu.
    if (name=="SpellBookFrame" or name=="PlayerSpellsFrame") and FS:IsModuleEnabled("ActionBars") and FS.db.actionBars.menu then
        local state=self.native[frame]
        if not state.points then state.points=FS.HUD:SavePoints(frame) end
        if not FS.db.layout.frames[name] then
            state.placing=true; frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",24,-76); state.placing=false
        end
    end
    self.opening=false
end
function W:Install()
    if InCombatLockdown() then return end
    for _,name in ipairs(names) do
        local frame=_G[name]
        local parent=frame and frame.GetParent and frame:GetParent(); local nested=false
        while parent do if self.native[parent] then nested=true; break end; parent=parent.GetParent and parent:GetParent() end
        if frame and not nested and not self.native[frame] and not (frame.IsForbidden and frame:IsForbidden()) then
            local state={name=name,guild=name=="CommunitiesFrame" or name=="GuildFrame"}; self.native[frame]=state
            frame:HookScript("OnShow",function(f)
                if state.guild and self:UsesSuiteStyle(name) and not InCombatLockdown() then
                    state.preparing=true
                    local ok,err=pcall(function()
                        self:NativeShown(f,name)
                        local skin=FS.NativeWindows.windows[f]
                        if not skin or not skin.enabled then FS.NativeWindows:Refresh(f) end
                        FS.Layout:Apply(name)
                    end)
                    state.preparing=nil
                    if not ok then error(err,0) end
                    self:RememberGuildPlacement(f)
                    return
                end
                if self:UsesSuiteStyle(name) and not InCombatLockdown() then self:NativeShown(f,name) end
                if self:UsesSuiteStyle(name)
                    and self:PrepareOpen(f,function()
                        self:NativeShown(f,name)
                        FS.NativeWindows:Refresh(f)
                        FS.Layout:Apply(name)
                    end) then return end
                self:QueueNativeShown(f,name)
            end)
            if state.guild then
                frame:HookScript("OnHide",function() state.guildPoints=nil; state.guildScale=nil end)
                for _,method in ipairs({"SetPoint","SetScale"}) do
                    hooksecurefunc(frame,method,function(f) self:StabilizeGuild(f) end)
                end
            end
            if name=="SpellBookFrame" or name=="PlayerSpellsFrame" then
                hooksecurefunc(frame,"SetPoint",function(f)
                    if not state.placing and not self.opening and f:IsShown() then self:QueueNativeShown(f,name) end
                end)
            end
        end
    end
end
function W:HideNativeWindows(keep,contextHost)
    if InCombatLockdown() then return end
    for frame in pairs(self.native) do
        if frame~=keep and frame~=contextHost and not (FS.Context and FS.Context:IsHostFamily(frame,contextHost)) and frame:IsShown() then
            if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        end
    end
end
local function experiencePulse(parent,layer,duration)
    local texture=parent:CreateTexture(nil,layer)
    local group=texture:CreateAnimationGroup()
    local fade=group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(duration)
    group:SetScript("OnFinished",function() texture:Hide() end)
    texture:Hide()
    return texture,group
end
function W:PaintExperience()
    local f=self.experience; if not f then return end
    local theme=FS.Themes
    local r,g,b=theme:Color(.12,.72,.86,1)
    f.bar:SetStatusBarColor(r,g,b,1)
    f.bg:SetColorTexture(theme:Color(.05,.07,.1,.95,.14))
    f.trim:SetColorTexture(r,g,b,.45)
    if theme:Current() then f.rested:SetStatusBarColor(.26+r*.45,.26+g*.45,.26+b*.45,.55)
    else f.rested:SetStatusBarColor(.55,.35,.95,.6) end
    local lightR,lightG,lightB=.58+r*.42,.58+g*.42,.58+b*.42
    if f.glow.SetGradient and CreateColor then
        f.glow:SetColorTexture(1,1,1,1)
        f.glow:SetGradient("HORIZONTAL",CreateColor(r,g,b,0),CreateColor(lightR,lightG,lightB,.95))
    else f.glow:SetColorTexture(lightR,lightG,lightB,.75) end
    f.gain:SetColorTexture(lightR,lightG,lightB,.85)
    f.levelFlash:SetColorTexture(lightR,lightG,lightB,.9)
    for _,mark in ipairs(f.marks) do mark:SetColorTexture(lightR,lightG,lightB,1) end
end
local function setExperienceSegment(texture,bar,start,finish,height)
    texture:ClearAllPoints(); texture:SetPoint("LEFT",bar,"LEFT",start,0)
    texture:SetSize(math.max(1,finish-start),height)
end
function W:AnimateExperience(f,xp,maximum,width,level)
    local progress=math.min(1,math.max(0,xp/maximum))
    local edge=progress*width
    setExperienceSegment(f.glow,f.bar,math.max(0,edge-(12+progress*36)),edge,3+progress*5)
    f.glow:SetAlpha(.35+progress*.65); f.glow:SetShown(edge>=1)
    for i,mark in ipairs(f.marks) do
        mark:ClearAllPoints(); mark:SetPoint("CENTER",f.bar,"LEFT",width*i/4,0)
        mark:SetAlpha(progress>=i/4 and .9 or .3)
    end
    local leveled=level and f.lastLevel and level>f.lastLevel
    local earned=not leveled and f.lastMaximum==maximum and f.lastXP and xp>f.lastXP
    if leveled then
        f.gainPulse:Stop(); f.gain:Hide()
        f.levelPulse:Stop(); f.levelFlash:Show(); f.levelPulse:Play()
    elseif earned then
        setExperienceSegment(f.gain,f.bar,f.lastXP/maximum*width,edge,7)
        f.gainPulse:Stop(); f.gain:Show(); f.gainPulse:Play()
    end
    f.lastXP,f.lastMaximum=xp,maximum
    -- The level-up event can report the new level before UnitLevel catches up.
    if leveled or not f.lastLevel then f.lastLevel=level end
end
function W:UpdateExperience(levelUp)
    if not FS.db then return end
    local A,T,H=FS.modules.ActionBars,FS.Tools,FS.HUD
    local enabled=FS:IsModuleEnabled("ActionBars")
    if not InCombatLockdown() then
        for _,name in ipairs({"StatusTrackingBarManager","MainMenuExpBar","MainMenuBarMaxLevelBar","ReputationWatchBar"}) do
            local native=_G[name]
            if native and not (native.IsForbidden and native:IsForbidden()) then
                local state=self.xpNative[native]
                if not state then
                    state={alpha=native:GetAlpha()}; self.xpNative[native]=state
                    hooksecurefunc(native,"SetAlpha",function(f)
                        if state.hidden and not state.setting then state.setting=true; f:SetAlpha(0); state.setting=false end
                    end)
                end
                state.hidden=enabled; state.setting=true; native:SetAlpha(enabled and 0 or state.alpha); state.setting=false
                FS.modules.Character:NativeMouse(native,enabled)
            end
        end
    end
    if not self.experience then
        local f=CreateFrame("Frame","ForeverSuiteExperience",UIParent); self.experience=f; f.fsFontModule="QoL"
        f:SetSize(500,20); f:SetPoint("BOTTOM",UIParent,"BOTTOM",FS.db.actionBars.x,FS.db.actionBars.y-22)
        f.bar=CreateFrame("StatusBar",nil,f); f.bar:SetSize(500,7); f.bar:SetPoint("BOTTOM"); f.bar:SetStatusBarTexture(H.texture)
        f.bg=f.bar:CreateTexture(nil,"BACKGROUND"); f.bg:SetAllPoints()
        f.rested=CreateFrame("StatusBar",nil,f); f.rested:SetPoint("BOTTOM"); f.rested:SetSize(500,7); f.rested:SetStatusBarTexture(H.texture)
        f.rested:SetFrameLevel(f.bar:GetFrameLevel()+1); f.rested:EnableMouse(false)
        local fx=CreateFrame("Frame",nil,f); fx:SetAllPoints(f.bar); fx:SetFrameLevel(f.rested:GetFrameLevel()+1); fx:EnableMouse(false)
        f.trim=fx:CreateTexture(nil,"BORDER"); f.trim:SetPoint("BOTTOMLEFT"); f.trim:SetPoint("BOTTOMRIGHT"); f.trim:SetHeight(1)
        f.glow=fx:CreateTexture(nil,"ARTWORK"); f.glow:Hide()
        f.marks={}
        for i=1,3 do local mark=fx:CreateTexture(nil,"OVERLAY"); mark:SetSize(1,5); f.marks[i]=mark end
        f.gain,f.gainPulse=experiencePulse(fx,"ARTWORK",.65)
        f.levelFlash,f.levelPulse=experiencePulse(fx,"OVERLAY",1.15)
        f.levelFlash:SetPoint("TOPLEFT",fx,"TOPLEFT",0,2); f.levelFlash:SetPoint("BOTTOMRIGHT",fx,"BOTTOMRIGHT",0,-2)
        self:PaintExperience()
        f.text=H:Label(f,"",0,-1,500); f.text:SetJustifyH("CENTER")
        f.text:Hide()
        f:EnableMouse(true); f:SetScript("OnEnter",function() f.text:Show()
            GameTooltip:SetOwner(f,"ANCHOR_TOP"); GameTooltip:AddLine("Experience"); GameTooltip:AddLine(f.tooltip or "",1,1,1); GameTooltip:Show()
        end); f:SetScript("OnLeave",function() f.text:Hide(); GameTooltip:Hide() end)
        FS.Layout:Register("ExperienceBar",f,"Experience")
    end
    local f=self.experience; local xp,maximum=T:Call(UnitXP,"player"),T:Call(UnitXPMax,"player")
    local valid=T:Number(xp) and T:Number(maximum) and maximum>0
    f:SetShown(enabled and valid)
    if enabled and valid then
        local width=(MainActionBar or MainMenuBar) and (MainActionBar or MainMenuBar):GetWidth() or 500
        if not T:Number(width) or width<=0 then width=500 end
        f:SetWidth(width); f.bar:SetWidth(width); f.rested:SetWidth(width); f.text:SetWidth(width)
        if not InCombatLockdown() and not FS.db.layout.frames.ExperienceBar then
            f:ClearAllPoints()
            local bar=MainActionBar or MainMenuBar
            if bar then f:SetPoint("TOP",bar,"BOTTOM",0,-6) else f:SetPoint("BOTTOM",UIParent,"BOTTOM",FS.db.actionBars.x,FS.db.actionBars.y-22) end
            f:SetScale(bar and bar:GetEffectiveScale()/UIParent:GetEffectiveScale() or FS.db.actionBars.scale)
        end
        f.bar:SetMinMaxValues(0,maximum); f.bar:SetValue(xp)
        local rested=T:Call(GetXPExhaustion); rested=T:Number(rested) and math.max(0,rested) or 0
        local segment=math.max(0,math.min(rested,maximum-xp))/maximum*width
        f.rested:ClearAllPoints(); f.rested:SetPoint("LEFT",f.bar,"LEFT",xp/maximum*width,0); f.rested:SetWidth(math.max(1,segment))
        f.rested:SetMinMaxValues(0,1); f.rested:SetValue(1); f.rested:SetShown(segment>0)
        local level=T:Number(levelUp) and levelUp or T:Call(UnitLevel,"player")
        self:AnimateExperience(f,xp,maximum,width,T:Number(level) and level or nil)
        f.text:SetText("XP  "..math.floor(xp/maximum*100).."%"); f.tooltip=xp.." / "..maximum.." | "..(maximum-xp).." to next level"..(rested>0 and " | Rested: "..rested or "")
    else
        f.lastXP,f.lastMaximum,f.lastLevel=nil,nil,nil
        f.gainPulse:Stop(); f.gain:Hide(); f.levelPulse:Stop(); f.levelFlash:Hide()
    end
    if not enabled and not InCombatLockdown() then
        for frame,state in pairs(self.native) do if state.points then state.placing=true; FS.HUD:RestorePoints(frame,state.points); state.placing=false end end
    end
end
W.events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","UPDATE_EXHAUSTION"}) do FS:RegisterClientEvent(W.events,event) end
W.events:SetScript("OnEvent",function(_,event,arg)
    if FS.initialized then W:Install(); W:UpdateExperience(event=="PLAYER_LEVEL_UP" and arg or nil) end
end)
