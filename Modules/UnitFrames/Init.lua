local _, FS = ...
local U = { name = "UnitFrames", key = "unitFrames", frames = {}, originals = {} }; FS:RegisterModule(U.name, U)
local H = FS.HUD
function U:NormalizeSettings()
    H:Normalize(FS.db.unitFrames)
    local db = FS.db.unitFrames
    for _, unit in ipairs({ "player", "target" }) do
        db[unit].x = FS.modules.Vendor:ValidNumber(db[unit].x, -10000, 10000) or (unit == "player" and -430 or 430)
        db[unit].y = FS.modules.Vendor:ValidNumber(db[unit].y, 0, 2000) or 224
    end
end
function U:CreateUnit(unit)
    local f = CreateFrame("Button", "ForeverSuiteUnit" .. unit, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    self.frames[unit] = f; H:Skin(f); f:SetSize(270, 54); f:SetClampedToScreen(true)
    f:SetAttribute("unit", unit); f:SetAttribute("type1", "target"); f:SetAttribute("type2", "togglemenu")
    f:SetAttribute("*type1", "target"); f:RegisterForClicks("AnyUp")
    f.portrait = f:CreateTexture(nil, "ARTWORK"); f.portrait:SetSize(46, 46)
    local right = unit == "target"; f.portrait:SetPoint(right and "TOPRIGHT" or "TOPLEFT", right and -4 or 4, -4)
    local x = right and 4 or 54
    f.health = CreateFrame("StatusBar", nil, f); f.health:SetSize(212, 37); f.health:SetPoint("TOPLEFT", x, -4); f.health:SetStatusBarTexture(H.texture)
    local bg = f.health:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.10, 0.12, 0.16, 1)
    f.name = H:Label(f.health, "", 5, -5, 202); f.name:SetHeight(14)
    if unit=="player" or unit=="target" or unit=="focus" or unit=="pet" then
        f.level=H:Label(f.health,"",0,0,32); f.level:ClearAllPoints(); f.level:SetPoint("TOPRIGHT",f.health,"TOPRIGHT",-5,-5)
        f.level:SetJustifyH("RIGHT"); f.level:SetTextColor(.98,.85,.45,1); FS:ApplyFont(f.level,12,"OUTLINE")
        if f.name.SetMaxLines then f.name:SetMaxLines(1); f.level:SetMaxLines(1) end
        self:LayoutLevel(f)
    end
    f.powerValue=H:Label(f.health,"",5,-21,76); FS:ApplyFont(f.powerValue,10,"OUTLINE")
    f.value = H:Label(f.health, "", 5, -21, 202); f.value:SetJustifyH("RIGHT")
    f.power = CreateFrame("StatusBar", nil, f); f.power:SetSize(212, 7); f.power:SetPoint("TOPLEFT", x, -43); f.power:SetStatusBarTexture(H.texture)
    f.powerBG = f.power:CreateTexture(nil, "BACKGROUND"); f.powerBG:SetAllPoints(); f.powerBG:SetColorTexture(0.1, 0.12, 0.16, 1)
    f:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetUnit(unit); GameTooltip:Show() end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if unit=="pet" then self:CreatePetHappiness(f) end
    -- Existence/visibility is controlled by secure code even when targets change in combat.
    self:CreateCast(f); RegisterUnitWatch(f); return f
end
function U:LayoutLevel(f)
    if not f.level then return end
    local _,size=f.level:GetFont(); size=size or 12
    local width=math.max(32,size*2.2)
    f.level:SetSize(width,size+3); f.name:SetWidth(math.max(40,f.health:GetWidth()-width-18))
    f.levelGeneration=FS.fontGeneration
end
function U:RefreshUnit(unit)
    local f = self.frames[unit]; if not f or not UnitExists(unit) then return end
    f.name:SetText(UnitName(unit))
    if f.level then
        local level=UnitLevel and UnitLevel(unit)
        f.level:SetText(H:Safe(level) and type(level)=="number" and level>0 and tostring(level) or "??")
        if f.levelGeneration~=FS.fontGeneration then self:LayoutLevel(f) end
    end
    local current, maximum = UnitHealth(unit), UnitHealthMax(unit)
    f.health:SetMinMaxValues(0, maximum); f.health:SetValue(current)
    if H:Safe(current) and H:Safe(maximum) and type(current) == "number" and type(maximum) == "number" and maximum > 0 then
        local dead = UnitIsDeadOrGhost(unit)
        f.value:SetText(H:Safe(dead) and dead and "Dead" or (H:Number(current) .. " | " .. math.floor(current / maximum * 100 + 0.5) .. "%"))
    else f.value:SetText("") end
    f.health:SetStatusBarColor(H:Color(unit))
    local index, token = UnitPowerType(unit)
    local c = H:Safe(token) and PowerBarColor and PowerBarColor[token] or nil
    f.power:SetStatusBarColor(c and c.r or 0.15, c and c.g or 0.5, c and c.b or 0.9)
    local power, powerMax=UnitPower(unit),UnitPowerMax(unit)
    f.power:SetMinMaxValues(0,powerMax); f.power:SetValue(power)
    if H:Safe(power) and H:Safe(powerMax) and type(power)=="number" and type(powerMax)=="number" then
        f.powerValue:SetText(H:Number(power).." / "..H:Number(powerMax))
    else f.powerValue:SetText("") end
    if SetPortraitTexture then SetPortraitTexture(f.portrait, unit) end
    if unit=="pet" then self:RefreshPetHappiness() end
    self:RefreshCast(unit)
end
function U:Native(enabled)
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "PlayerCastingBarFrame", "CastingBarFrame" }) do
        local f = _G[name]
        if f and not (f.IsForbidden and f:IsForbidden()) then
            local original = self.originals[f]
            if not original then
                original = { alpha = f:GetAlpha(), mouse = f:IsMouseEnabled() }; self.originals[f] = original
                hooksecurefunc(f, "SetAlpha", function(frame)
                    if self.active and not self.settingAlpha then self.settingAlpha = true; frame:SetAlpha(0); self.settingAlpha = false end
                end)
            end
            self.settingAlpha = true; f:SetAlpha(enabled and 0 or original.alpha); self.settingAlpha = false
            if enabled then f:EnableMouse(false) else f:EnableMouse(original.mouse) end
        end
    end
end
function U:SettingsChanged()
    self:NormalizeSettings()
    if InCombatLockdown() then self.pending = true; self:RefreshSettings(); return end
    self.pending = false; self.active = FS:IsModuleEnabled(self.name)
    if not self.active then self:ToggleMovers(false) end
    if not self.frames.player then self:CreateUnit("player"); self:CreateUnit("target") end
    local db = FS.db.unitFrames
    for unit, f in pairs(self.frames) do
        UnregisterUnitWatch(f); f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "BOTTOM", db[unit].x, db[unit].y); f:SetScale(db.scale)
        if self.active then RegisterUnitWatch(f); self:RefreshUnit(unit) else f:Hide() end
    end
    self:Native(self.active); self:RefreshSettings()
    if FS.Layout then FS.Layout:Collect(); FS.Layout:ApplyAll() end
end
function U:Initialize()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_TARGET_CHANGED", "PLAYER_LEVEL_UP", "UNIT_LEVEL", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_PET", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do FS:RegisterClientEvent(self.events,event) end
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do FS:RegisterClientEvent(self.events,event) end
    self.events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_DISABLED" then self:ToggleMovers(false)
        elseif event == "PLAYER_REGEN_ENABLED" then if self.pending then self:SettingsChanged() end
        elseif event == "PLAYER_ENTERING_WORLD" or (event == "ADDON_LOADED" and unit=="Blizzard_UnitFrame") then self:SettingsChanged()
        elseif self.active then
            if unit == "player" or unit == "target" then self:RefreshUnit(unit) else self:RefreshUnit("player"); self:RefreshUnit("target") end
        end
    end)
    self:SettingsChanged()
end
function U:CreateSettings(host)
    local f = H:Settings(self, host, "Unit frame settings", "Compact player and target frames. Players use class colors; enemy creatures use red health bars.")
    f.reset:SetScript("OnClick", function()
        FS.db.unitFrames.scale = 1; FS.db.unitFrames.player = { x = -430, y = 224 }; FS.db.unitFrames.target = { x = 430, y = 224 }; self:SettingsChanged()
    end)
    return f
end
function U:RefreshSettings() H:RefreshSettings(self) end
function U:ToggleMovers(show)
    self.moving = show == nil and not self.moving or show
    if self.moving and (InCombatLockdown() or not self.active) then self.moving = false; FS:Print("Enable Unit Frames and leave combat to move them.") end
    for unit, target in pairs(self.frames) do
        self.movers = self.movers or {}
        if self.moving and not self.movers[unit] then
            self.movers[unit] = H:Mover(self, target, unit == "player" and "Move player frame" or "Move target frame", function(x, y)
                FS.db.unitFrames[unit].x, FS.db.unitFrames[unit].y = x, y
            end)
        end
        local mover = self.movers[unit]
        if mover then mover:StopMovingOrSizing(); mover:ClearAllPoints(); mover:SetPoint("CENTER", target, "CENTER"); mover:SetShown(self.moving) end
    end
end
