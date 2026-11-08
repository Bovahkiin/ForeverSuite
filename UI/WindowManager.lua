local _,FS=...
local W={native={},xpNative={}}; FS.WindowManager=W
local names={"SpellBookFrame","PlayerSpellsFrame","QuestLogFrame","ProfessionsBookFrame","ProfessionsFrame","TradeSkillFrame","CraftFrame","FriendsFrame","ContactsFrame","AchievementFrame","CollectionsJournal","WardrobeFrame","CommunitiesFrame","GuildFrame","EncounterJournal","WorldMapFrame"}
function W:QueueNativeShown(frame,name)
    local state=self.native[frame]
    if not state or state.placing or self.opening then return end
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
            local state={name=name}; self.native[frame]=state
            frame:HookScript("OnShow",function(f) self:QueueNativeShown(f,name) end)
            if name=="SpellBookFrame" or name=="PlayerSpellsFrame" then
                hooksecurefunc(frame,"SetPoint",function(f)
                    if not state.placing and not self.opening and f:IsShown() then self:QueueNativeShown(f,name) end
                end)
            end
        end
    end
end
function W:HideNativeWindows(keep)
    if InCombatLockdown() then return end
    for frame in pairs(self.native) do
        if frame~=keep and frame:IsShown() then
            if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        end
    end
end
function W:UpdateExperience()
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
        f.bar=CreateFrame("StatusBar",nil,f); f.bar:SetSize(500,5); f.bar:SetPoint("BOTTOM"); f.bar:SetStatusBarTexture(H.texture); f.bar:SetStatusBarColor(.12,.72,.86)
        f.bg=f.bar:CreateTexture(nil,"BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(.05,.07,.1,.95)
        f.rested=CreateFrame("StatusBar",nil,f); f.rested:SetPoint("BOTTOM"); f.rested:SetSize(500,5); f.rested:SetStatusBarTexture(H.texture); f.rested:SetStatusBarColor(.55,.35,.95,.6)
        f.rested:SetFrameLevel(f.bar:GetFrameLevel()+1); f.rested:EnableMouse(false)
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
    if valid then
        local width=(MainActionBar or MainMenuBar) and (MainActionBar or MainMenuBar):GetWidth() or 500
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
        f.text:SetText("XP  "..math.floor(xp/maximum*100).."%"); f.tooltip=xp.." / "..maximum.." | "..(maximum-xp).." to next level"..(rested>0 and " | Rested: "..rested or "")
    end
    if not enabled and not InCombatLockdown() then
        for frame,state in pairs(self.native) do if state.points then state.placing=true; FS.HUD:RestorePoints(frame,state.points); state.placing=false end end
    end
end
W.events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","UPDATE_EXHAUSTION"}) do FS:RegisterClientEvent(W.events,event) end
W.events:SetScript("OnEvent",function() if FS.initialized then W:Install(); W:UpdateExperience() end end)
