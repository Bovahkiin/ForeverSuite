local _, FS = ...
local A = { name = "ActionBars", key = "actionBars", originals = {}, buttons = {}, movers = {} }; FS:RegisterModule(A.name, A)
local H = FS.HUD
local names = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar" }
local function syncDecoration(f,state)
    if not state.wanted then
        if f:IsShown() then f:Hide() end
        return
    end
    local owner=state.visibility
    local visible
    if owner.IsVisible then visible=owner:IsVisible() else visible=owner:IsShown() end
    if H:Safe(visible) then
        local shown=not not visible
        if f:IsShown()~=shown then f:SetShown(shown) end
    end
    local alpha=owner.GetEffectiveAlpha and owner:GetEffectiveAlpha() or owner:GetAlpha()
    if H:Safe(alpha) and f:GetAlpha()~=alpha then f:SetAlpha(alpha) end
    local level=math.max(0,state.anchor:GetFrameLevel()-1)
    if state.visibility~=state.anchor then level=math.max(level,state.visibility:GetFrameLevel()) end
    if f:GetFrameLevel()~=level then f:SetFrameLevel(level) end
    local strata=state.anchor.GetFrameStrata and state.anchor:GetFrameStrata() or "MEDIUM"
    if not f.GetFrameStrata or f:GetFrameStrata()~=strata then f:SetFrameStrata(strata) end
end
function A:CreateDecoration(anchor, visibility)
    -- Siblings under UIParent never enter a native bar's layout/child lists.
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    f.fsSuiteStyle=true; f.ignoreInLayout=true; f.fsActionDecoration=true
    f:SetBackdrop(nil); f:EnableMouse(false); f:Hide()
    f:SetAllPoints(anchor)
    self.decorations=self.decorations or {}
    self.decorations[f]={anchor=anchor,visibility=visibility or anchor,wanted=false}
    if not self.decorationDriver then
        self.decorationDriver=CreateFrame("Frame",nil,UIParent)
        local elapsed=0
        self.decorationDriver:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt; if elapsed<.05 then return end; elapsed=0; self:SyncDecorations()
        end)
        self.decorationDriver:Hide()
    end
    return f
end
function A:SetDecorationShown(f,shown)
    local state=f and self.decorations and self.decorations[f]
    if state then
        local wanted=shown==true
        if state.wanted~=wanted then
            state.wanted=wanted
            self.wantedDecorations=(self.wantedDecorations or 0)+(wanted and 1 or -1)
            local enabled=self.wantedDecorations>0
            if self.decorationDriver:IsShown()~=enabled then self.decorationDriver:SetShown(enabled) end
        end
        syncDecoration(f,state)
    elseif f then f:SetShown(shown) end
end
function A:SyncDecorations()
    for f,state in pairs(self.decorations or {}) do syncDecoration(f,state) end
end
function A:NormalizeSettings()
    H:Normalize(FS.db.actionBars)
    local valid=false; for _,name in ipairs(self.styles or {"Minimal"}) do if FS.db.actionBars.style==name then valid=true end end
    if not valid then FS.db.actionBars.style="Minimal" end
end
-- Native bars belong to the client's secure layout manager. Never write its
-- runtime systemInfo, flags, anchors or methods from addon code.
function A:IsNativeBar(id)
    if id=="MainMenuBar" then return true end
    for _,name in ipairs(names) do if id==name then return true end end
    return false
end
function A:Remember(bar,name)
    if not self.originals[bar] then self.originals[bar]={art={},points=H:SavePoints(bar),scale=bar:GetScale()} end
    return self.originals[bar]
end
function A:OpenNativeLayout()
    if InCombatLockdown() then FS:Print("Leave combat to edit action bars."); return end
    if EditModeManagerFrame and ShowUIPanel then FS:CloseSettingsScreens(); ShowUIPanel(EditModeManagerFrame)
    else FS:Print("Set action bar position and size in the game's interface settings.") end
end
function A:SkinButton(b, enabled, bar)
    if InCombatLockdown() then self.pending=true; return end
    if not self.buttons[b] then
        local icon = b.icon or b.Icon or (b:GetName() and _G[b:GetName() .. "Icon"])
        local normal = b.GetNormalTexture and b:GetNormalTexture()
        local s = { button=b, icon = icon, normal = normal, alpha = normal and normal:GetAlpha(), art = {}, fonts={} }
        for _,key in ipairs({"HotKey","Count","Name"}) do
            local region=b[key]; if region and region.GetFont then s.fonts[region]={region:GetFont()} end
        end
        for _,key in ipairs({ "SlotArt", "SlotBackground", "Border" }) do
            local region=b[key]; if region then s.art[region]=region:GetAlpha() end
        end
        if icon and icon.GetTexCoord then s.coords = { icon:GetTexCoord() }; s.iconPoints=H:SavePoints(icon) end
        local border = self:CreateDecoration(b)
        border.fsSuiteStyle=true; border.ignoreInLayout=true
        border:ClearAllPoints(); border:SetPoint("TOPLEFT",b,"TOPLEFT",-1,1); border:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",1,-1)
        border:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1)); border:EnableMouse(false)
        s.border = border; self.buttons[b] = s
    end
    local s = self.buttons[b]; self:SetDecorationShown(s.border,enabled)
    if bar and not s.slot then
        -- Empty secure buttons can be hidden by the native grid policy. Their
        -- sibling slot follows the bar's visibility without joining its layout or
        -- forcing protected buttons to show or changing their visibility state.
        local slot=self:CreateDecoration(b,bar)
        slot:SetPoint("TOPLEFT",b,"TOPLEFT",-1,1); slot:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",1,-1)
        slot:SetFrameLevel(math.max(bar:GetFrameLevel(),b:GetFrameLevel()-1)); slot:EnableMouse(false)
        s.slot=slot
    end
    if s.slot then self:SetDecorationShown(s.slot,enabled) end
    if self.StyleTile then self:StyleTile(s.border,FS.db.actionBars.style,false); if s.slot then self:StyleTile(s.slot,FS.db.actionBars.style,true) end end
    if s.normal then s.normal:SetAlpha(enabled and 0 or s.alpha) end
    for region,alpha in pairs(s.art) do region:SetAlpha(enabled and 0 or alpha) end
    for region,font in pairs(s.fonts) do
        if enabled then region.fsFontModule="ActionBars"; FS:ApplyFont(region) elseif font[1] then FS:ReleaseFont(region); region:SetFont(unpack(font)) end
    end
    if s.icon then
        if enabled then s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        elseif s.coords then s.icon:SetTexCoord(unpack(s.coords)) end
    end
    if self.StyleIcon then self:StyleIcon(s.icon,b,FS.db.actionBars.style,enabled,s) end
end
function A:ApplyBar(bar, name)
    if InCombatLockdown() then self.pending=true; return end
    local original = self:Remember(bar,name)
    for _, key in ipairs({ "EndCaps", "BorderArt", "BackgroundArt", "Background" }) do
        local region = bar[key]
        if region and region.SetAlpha then
            if original.art[region] == nil then original.art[region] = region:GetAlpha() end
            region:SetAlpha(self.active and 0 or original.art[region])
        end
    end
    local buttons = bar.actionButtons
    if buttons then for _, b in ipairs(buttons) do self:SkinButton(b, self.active,bar) end end
end
function A:SettingsChanged()
    self:NormalizeSettings()
    if InCombatLockdown() then self.pending = true; self:RefreshSettings(); return end
    self.pending = false; self.active = FS:IsModuleEnabled(self.name)
    self.dirtyBars={}
    if not self.active then self:ToggleMovers(false) end
    self.applying = true
    for _, name in ipairs(names) do
        local bar = _G[name]; if bar and not (bar.IsForbidden and bar:IsForbidden()) then self:ApplyBar(bar, name) end
    end
    if not MainActionBar and MainMenuBar then self:ApplyBar(MainMenuBar, "MainMenuBar") end
    -- Preserve every native button's handlers, attributes, bindings, cooldowns and paging.
    for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton", "StanceButton", "PetActionButton" }) do
        local root=prefix=="ActionButton" and (MainActionBar or MainMenuBar) or _G[prefix:gsub("Button$","")]
        for i = 1, 12 do local b = _G[prefix .. i]; if b then self:SkinButton(b, self.active,root) end end
    end
    if self.ApplyMenu then self:ApplyMenu() end
    if self.ApplyBagBar then self:ApplyBagBar() end
    if self.ApplyAppearance then self:ApplyAppearance() end
    self.applying = false
    if FS.Layout then
        FS.Layout:Collect()
        for _,name in ipairs(names) do FS.Layout:Apply(name) end
        for _,name in ipairs({"MainMenuBar","MainMenu","BagsBar"}) do FS.Layout:Apply(name) end
    end
    self:RefreshSettings()
    if FS.WindowManager then FS.WindowManager:UpdateExperience() end
end
function A:Initialize()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "EDIT_MODE_LAYOUTS_UPDATED" }) do FS:RegisterClientEvent(self.events,event) end
    self.events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then self:ToggleMovers(false)
        elseif event == "PLAYER_REGEN_ENABLED" then if self.pending then self:SettingsChanged() end
        elseif event == "PLAYER_ENTERING_WORLD" then self:SettingsChanged()
        elseif event == "ADDON_LOADED" then
            for _,name in ipairs(names) do local bar=_G[name]; if bar and not self.originals[bar] then self:SettingsChanged(); break end end
        elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then self:ApplyAppearance() end
    end)
    self:SettingsChanged()
end
function A:CreateSettings(host)
    local f = H:Settings(self, host, "Action bar and menu settings", "ForeverSuite skin for your normal action buttons. Extra bars are enabled in the game's action bar options.")
    f.menu = H:Button(f, "", 450, -205, 400, function() FS.db.actionBars.menu = not FS.db.actionBars.menu; self:SettingsChanged() end)
    f.appearance=H:Button(f,"",20,-285,400,function()
        if FS.Themes:Current() then FS.Installer:ShowThemes(); return end
        for i,name in ipairs(self.styles) do if FS.db.actionBars.style==name then FS.db.actionBars.style=self.styles[i%#self.styles+1]; break end end
        self:SettingsChanged()
    end)
    f.appearance.help="Choose Minimal, Floating, Compact dock or Gold & cyan. Saved in your profile."
    f.setup=H:Button(f,"Open guided setup",450,-285,400,function() FS.Installer:Show() end)
    f.scale:Hide(); f.reset:Hide()
    f.move:SetText("Game action bar layout"); f.move:SetScript("OnClick",function() self:OpenNativeLayout() end)
    H:Label(f,"Action bar position and size use the game layout to keep combat actions secure. Saved ForeverSuite bar positions are retained but not applied.",20,-265,850)
    return f
end
function A:RefreshSettings()
    H:RefreshSettings(self)
    if self.settings and self.settings.menu then self.settings.menu:SetText("Menu in top-left: " .. (FS.db.actionBars.menu and "On" or "Off")) end
    if self.settings and self.settings.appearance then self.settings.appearance:SetText(FS.Themes:Current() and ("Appearance: "..FS.db.appearance.theme) or ("Bar style: "..FS.db.actionBars.style)) end
end
function A:ToggleMovers(show)
    self.moving=false
    if self.mover then self.mover:Hide() end
    if show then self:OpenNativeLayout() end
end
