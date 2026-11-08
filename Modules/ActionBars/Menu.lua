local _, FS = ...
local A,H = FS.modules.ActionBars,FS.HUD
A.menuButtons = {}; A.menuArt = {}
local entries = {
    {"CharacterMicroButton","Character"},{"ProfessionMicroButton","Professions"},{"PlayerSpellsMicroButton","Spells"},
    {"SpellbookMicroButton","Spells"},{"TalentMicroButton","Talents"},{"AchievementMicroButton","Achievements"},
    {"LegacyMicroButton","Legacy"},{"QuestLogMicroButton","Quests"},{"HousingMicroButton","Housing"},
    {"GuildMicroButton","Guild"},{"SocialsMicroButton","Social"},{"LFDMicroButton","Groups"},{"PvPMicroButton","PVP"},
    {"CollectionsMicroButton","Collections"},{"EJMicroButton","Guide"},{"WorldMapMicroButton","Map"},
    {"StoreMicroButton","Store"},{"HelpMicroButton","Help"},{"MainMenuMicroButton","Menu"},
}
function A:QueueMenuWork(saved,art)
    if art then saved.artDirty=true else saved.layoutDirty=true end
    if self.menuWorkPending then return end
    self.menuWorkPending=true
    C_Timer.After(0,function()
        self.menuWorkPending=false
        if InCombatLockdown() then self.pending=true; return end
        if not self.active or not FS.db.actionBars.menu then return end
        for _,state in pairs(self.menuButtons) do
            if state.layoutDirty then state.layoutDirty=nil; self:EnforceMenuLayout(state) end
            if state.artDirty then state.artDirty=nil; self:HideMenuArt(state) end
        end
    end)
end
function A:EnforceMenuLayout(saved)
    if saved.settingLayout or not self.active or not FS.db.actionBars.menu or saved.slot==nil then return end
    if InCombatLockdown() then self.pending=true; return end
    saved.settingLayout=true
    local b=saved.proxy
    b:SetParent(self.menuRoot); b:SetScale(1); b:SetSize(36,36)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT",self.menuRoot,"TOPLEFT",saved.slot*41,0)
    saved.settingLayout=false
end
function A:HideMenuArt(saved)
    saved.settingArt=true
    for region in pairs(saved.art) do region:SetAlpha(0) end
    saved.settingArt=false
end
function A:CreateMenuProxy(native, name)
    local saved = self.menuButtons[native]; if saved then return saved end
    local b=native
    saved={proxy=b,parent=native:GetParent(),scale=native:GetScale(),alpha=native:GetAlpha(),mouse=native:IsMouseEnabled(),width=native:GetWidth(),height=native:GetHeight(),points=H:SavePoints(native),art={}}
    self.menuButtons[native]=saved
    saved.border=CreateFrame("Frame",nil,b,"BackdropTemplate"); H:Skin(saved.border)
    saved.border.ignoreInLayout=true
    saved.border:SetAllPoints(); saved.border:SetFrameLevel(math.max(0,b:GetFrameLevel()-1)); saved.border:EnableMouse(false)
    for _,region in ipairs({b:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType()=="Texture" then
            saved.art[region]=region:GetAlpha()
            hooksecurefunc(region,"SetAlpha",function()
                if self.active and FS.db.actionBars.menu and not saved.settingArt then
                    self:QueueMenuWork(saved,true)
                end
            end)
        end
    end
    local icon=b:CreateTexture(nil,"OVERLAY"); icon:SetSize(30,30); icon:SetPoint("CENTER"); FS:SetMenuIcon(icon,name); saved.icon=icon
    icon.ignoreInLayout=true
    for _,method in ipairs({"SetPoint","SetSize","SetWidth","SetHeight","SetScale","SetParent"}) do
        hooksecurefunc(native,method,function()
            if not saved.settingLayout and not self.applying and self.active and FS.db.actionBars.menu then self:QueueMenuWork(saved) end
        end)
    end
    saved.animation = FS:ClickEffect(b)
    b:HookScript("OnEnter", function()
        if not self.active or not FS.db.actionBars.menu then return end
        self:HideMenuArt(saved)
        saved.border:SetBackdropBorderColor(0.95,0.68,0.24,1); GameTooltip:SetOwner(b,"ANCHOR_BOTTOM")
        GameTooltip:AddLine(native.tooltipText or name)
        if not native:IsEnabled() and native.disabledTooltip then GameTooltip:AddLine(native.disabledTooltip,1,0.5,0.3,true) end
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave",function()
        if not self.active or not FS.db.actionBars.menu then return end
        self:HideMenuArt(saved); saved.border:SetBackdropBorderColor(0.12,0.72,0.86,0.85); GameTooltip:Hide()
    end)
    b:HookScript("OnMouseDown",function() if self.active and FS.db.actionBars.menu then self:HideMenuArt(saved) end end)
    b:HookScript("OnMouseUp",function() if self.active and FS.db.actionBars.menu then self:HideMenuArt(saved) end end)
    saved.notice = b:CreateTexture(nil,"OVERLAY"); saved.notice:SetSize(5,5); saved.notice:SetPoint("TOPRIGHT",-2,-2)
    saved.notice.ignoreInLayout=true
    saved.notice:SetColorTexture(0.95,0.68,0.24,1); saved.notice:Hide()
    local elapsed=0
    b:HookScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta; if elapsed<0.2 then return end; elapsed=0
        if not self.active or not FS.db.actionBars.menu then saved.notice:Hide(); return end
        icon:SetDesaturated(not native:IsEnabled())
        saved.notice:SetShown((native.HasNotification and native:HasNotification()) or (native.IsPulsing and native:IsPulsing()) or false)
    end)
    -- Skin the real hardware-click target; never synthesize a click on a restricted native button.
    return saved
end
function A:ApplyMenu()
    if InCombatLockdown() then self.pending=true; return end
    local enabled=self.active and FS.db.actionBars.menu
    -- Forever exposes separate Spellbook and Talent buttons; its combined
    -- PlayerSpells button must not add a second route to the same panels.
    local combined=SpellbookMicroButton and TalentMicroButton and PlayerSpellsMicroButton
    if combined then
        if not self.combinedOriginal then self.combinedOriginal={alpha=combined:GetAlpha(),mouse=combined:IsMouseEnabled()} end
        combined:SetAlpha(enabled and 0 or self.combinedOriginal.alpha)
        combined:EnableMouse(not enabled and self.combinedOriginal.mouse or false)
    end
    if not self.menuRoot then
        self.menuRoot=CreateFrame("Frame","ForeverSuiteMainMenu",UIParent,"SecureHandlerStateTemplate")
        self.menuRoot:SetSize(780,36); self.menuRoot:SetPoint("TOPLEFT",UIParent,"TOPLEFT",16,-16)
    end
    if MicroMenu then
        for _,key in ipairs({"BorderArt","BackgroundArt","Background"}) do
            local region=MicroMenu[key]
            if region then
                if self.menuArt[region]==nil then self.menuArt[region]=region:GetAlpha() end
                region:SetAlpha(enabled and 0 or self.menuArt[region])
            end
        end
    end
    local position=0
    for _,entry in ipairs(entries) do
        local native=_G[entry[1]]
        if native and native~=combined and not (native.IsForbidden and native:IsForbidden()) then
            local saved=self:CreateMenuProxy(native,entry[2]); local b=saved.proxy
            if enabled then
                saved.slot=position; self:EnforceMenuLayout(saved)
                native:SetAlpha(1); native:EnableMouse(true)
                self:HideMenuArt(saved)
                saved.icon:Show(); saved.border:Show()
                b:ClearAllPoints(); b:SetPoint("TOPLEFT",self.menuRoot,"TOPLEFT",position*41,0)
                -- b is the native button, not a proxy: never rewrite its
                -- secure visibility/enabled state even to the same value.
                if native:IsShown() then position=position+1 end
            else
                saved.slot=nil; native:SetParent(saved.parent); native:SetScale(saved.scale)
                native:SetAlpha(saved.alpha); native:EnableMouse(saved.mouse); native:SetSize(saved.width,saved.height)
                H:RestorePoints(native,saved.points)
                for region,alpha in pairs(saved.art) do region:SetAlpha(alpha) end
                saved.icon:Hide(); saved.border:Hide(); saved.notice:Hide()
            end
        end
    end
    if enabled then self.menuRoot:SetWidth(math.max(36,position*41-5)) end
end
function A:ApplyBagBar()
    if InCombatLockdown() then self.pending=true; return end
    local bar=BagsBar or MainMenuBarBagButtons
    if not bar then return end
    local saved=self:Remember(bar)
    if self.active then bar:ClearAllPoints(); bar:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-16,16); bar:SetScale(1)
    else H:RestorePoints(bar,saved.points); bar:SetScale(saved.scale) end
    for _,key in ipairs({"BorderArt","BackgroundArt","Background","EndCaps","NineSlice"}) do
        local region=bar[key]
        if region then
            if saved.art[region]==nil then saved.art[region]=region:GetAlpha() end
            region:SetAlpha(self.active and 0 or saved.art[region])
        end
    end
    local function skinDividers()
        for _,key in ipairs({"HorizontalDividersPool","VerticalDividersPool"}) do
            local pool=bar[key]
            if pool and pool.EnumerateActive then
                for divider in pool:EnumerateActive() do
                    if saved.art[divider]==nil then saved.art[divider]=divider:GetAlpha() end
                    divider:SetAlpha(self.active and 0 or saved.art[divider])
                end
            end
        end
    end
    if bar.UpdateDividers and not saved.dividerHook then
        saved.dividerHook=true; hooksecurefunc(bar,"UpdateDividers",function()
            if saved.dividersPending then return end; saved.dividersPending=true
            C_Timer.After(0,function() saved.dividersPending=false; if not InCombatLockdown() then skinDividers() else self.pending=true end end)
        end)
    end
    skinDividers()
    self:AnchorGearIndicator()
    self.bagSkins=self.bagSkins or {}
    local buttons={}; local seen={}
    local function add(b) if b and not seen[b] then seen[b]=true; buttons[#buttons+1]=b end end
    for _,name in ipairs({"MainMenuBarBackpackButton","CharacterBag0Slot","CharacterBag1Slot","CharacterBag2Slot","CharacterBag3Slot","CharacterReagentBag0Slot","KeyRingButton","BagBarExpandToggle"}) do add(_G[name]) end
    if MainMenuBarBagManager and MainMenuBarBagManager.EnumerateBagButtons then
        for _,b in MainMenuBarBagManager:EnumerateBagButtons() do add(b) end
    end
    for _,b in ipairs(buttons) do
        if b then
            local skin=self.bagSkins[b]
            if not skin then
                skin={regions={},fonts={}}; self.bagSkins[b]=skin
                skin.border=self:CreateDecoration(b)
                skin.border.ignoreInLayout=true
                skin.border:SetAllPoints(b); skin.border:SetFrameLevel(math.max(0,b:GetFrameLevel()-1)); skin.border:EnableMouse(false)
                for _,key in ipairs({"NormalTexture","SlotArt","SlotBackground","Border","IconBorder","Background","BorderArt","BackgroundArt"}) do
                    local r=b[key]; if r then skin.regions[r]=r:GetAlpha() end
                end
                local normal=b.GetNormalTexture and b:GetNormalTexture(); if normal then skin.regions[normal]=normal:GetAlpha() end
            end
            if b.GetRegions then
                for _,r in ipairs({b:GetRegions()}) do
                    local layer=r.GetDrawLayer and r:GetDrawLayer()
                    if r~=b.icon and r~=b.Icon and r.GetObjectType and r:GetObjectType()=="Texture" and (layer=="BACKGROUND" or layer=="BORDER") then
                        if skin.regions[r]==nil then skin.regions[r]=r:GetAlpha() end
                    end
                end
            end
            self:SetDecorationShown(skin.border,self.active)
            self:StyleTile(skin.border,FS.db.actionBars.style,false)
            for _,key in ipairs({"Count","HotKey"}) do
                local text=b[key]
                if text and text.GetFont then
                    if not skin.fonts[text] then skin.fonts[text]={text:GetFont()} end
                    if self.active then text.fsFontModule="ActionBars"; FS:ApplyFont(text)
                    else local font=skin.fonts[text]; FS:ReleaseFont(text); if font[1] then text:SetFont(unpack(font)) end end
                end
            end
            for r,alpha in pairs(skin.regions) do r:SetAlpha(self.active and 0 or alpha) end
            -- Do not replace or crop the original bag icon.
        end
    end
end

function A:AnchorGearIndicator()
    local G=FS.modules.Gear; local bar=BagsBar or MainMenuBarBagButtons
    if G and G.indicator and bar and not FS.db.layout.frames.GearButton then
        G.indicator:ClearAllPoints(); G.indicator:SetPoint("RIGHT",bar,"LEFT",-10,0)
    end
end
