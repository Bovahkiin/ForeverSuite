local _,FS=...
local C={name="Character",key="character",alpha={},fonts={},skins={},tabs={},nativeTabs={},controls={}}; FS:RegisterModule(C.name,C)
local H=FS.HUD
C.pages={
    {name="Character",frame="PaperDollFrame",icon="Character"},
    {name="Reputation",frame="ReputationFrame",icon="Reputation"},
    {name="Skills",frame="SkillsFrame",icon="Skills"},
    {name="Player vs. Player",frame="PVPRankFrame",icon="PVP"},
    {name="Currency",frame="TokenFrame",icon="Currency"},
    {name="Statistics",frame="StatisticsFrame",icon="Statistics"},
}
function C:NormalizeSettings() end
function C:HideArt(region)
    if not region or not region.GetAlpha then return end
    if self.alpha[region]==nil then self.alpha[region]=region:GetAlpha() end
    if not self.alphaHooks then self.alphaHooks={} end
    if not self.alphaHooks[region] then
        self.alphaHooks[region]=true; local setting=false
        hooksecurefunc(region,"SetAlpha",function(r)
            if FS:IsModuleEnabled(self.name) and not setting then setting=true; r:SetAlpha(0); setting=false end
        end)
    end
    region:SetAlpha(0)
end
function C:Font(region)
    if not region or not region.SetFont or not region.GetFont then return end
    if not self.fonts[region] then self.fonts[region]={region:GetFont()} end
    region.fsFontModule="Character"; FS:ApplyFont(region)
end
function C:SkinControl(b)
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture","GetCheckedTexture"}) do
        local region=b[method] and b[method](b)
        if region and region~=b.icon and region~=b.Icon then self:HideArt(region) end
    end
    local skin=self.controls[b]
    if not skin then
        skin=CreateFrame("Frame",nil,b,"BackdropTemplate"); skin.fsCharacterSkin=true; H:Skin(skin); skin:SetAllPoints(); skin:EnableMouse(false)
        skin:SetFrameLevel(math.max(0,b:GetFrameLevel()-1)); self.controls[b]=skin
        local name=b.GetName and b:GetName() or ""
        local glyph=name:find("ZoomIn") and "+" or name:find("ZoomOut") and "-" or name:find("RotateLeft") and "<" or name:find("RotateRight") and ">" or name:find("Reset") and "R" or name:find("Close") and "X"
        if glyph then skin.caption=FS.Widgets:Label(skin); skin.caption:SetPoint("CENTER"); skin.caption:SetText(glyph) end
    end
    skin:Show(); if skin.caption then skin.caption:Show() end
end
function C:SkinTree(frame,depth)
    if not frame or frame.fsCharacterSkin or (frame.IsForbidden and frame:IsForbidden()) then return end
    depth=depth or 0; if depth>12 then return end
    local kind=frame.GetObjectType and frame:GetObjectType()
    if kind=="Button" or kind=="CheckButton" then self:SkinControl(frame) end
    if frame.GetRegions then
        for _,region in ipairs({frame:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType()=="FontString" then self:Font(region)
            elseif region.GetDrawLayer then
                local layer=region:GetDrawLayer()
                local icon=region==frame.icon or region==frame.Icon or region==frame.Portrait
                local name=region.GetName and region:GetName()
                if name and name:find("Icon") then icon=true end
                local bar=frame.GetObjectType and frame:GetObjectType()=="StatusBar"
                if not icon and not bar and (layer=="BACKGROUND" or layer=="BORDER" or (name and (name:find("Background") or name:find("Border")))) then self:HideArt(region) end
            end
        end
    end
    self:Font(frame.Label); self:Font(frame.Value); self:Font(frame.Text)
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do self:SkinTree(child,depth+1) end end
end
function C:SettingsChanged() self:Apply(); self:RefreshSettings() end
function C:Initialize()
    self.events=CreateFrame("Frame")
    for _,e in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_EQUIPMENT_CHANGED","UNIT_STATS","UNIT_RESISTANCES","UNIT_INVENTORY_CHANGED","EQUIPMENT_SETS_CHANGED","KNOWN_TITLES_UPDATE","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_PET","UNIT_NAME_UPDATE","UNIT_MODEL_CHANGED","UNIT_PORTRAIT_UPDATE","UNIT_PET_EXPERIENCE","UNIT_HAPPINESS","PET_UI_UPDATE","PET_STATS_UPDATE"}) do FS:RegisterClientEvent(self.events,e) end
    self.events:SetScript("OnEvent",function(_,event,unit)
        if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED" then self:InstallHooks(); self:Apply()
        elseif self.root and self.root:IsShown() and FS:IsModuleEnabled(self.name) then
            if event=="UNIT_PET" or event=="UNIT_MODEL_CHANGED" or event=="UNIT_PORTRAIT_UPDATE" or event=="PLAYER_EQUIPMENT_CHANGED" or (event=="UNIT_INVENTORY_CHANGED" and unit=="player") then self.modelUnit=nil end
            self:RefreshCharacter()
        end
    end)
    self:InstallHooks(); self:Apply()
end
function C:CreateSettings(host)
    local f=CreateFrame("Frame",nil,host,"BackdropTemplate"); H:Skin(f); self.settings=f
    f:SetSize(892,420); f:SetPoint("TOPLEFT",24,FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel()+30); f:EnableMouse(true)
    H:Button(f,"Back to Control Center",20,-12,220,function() f:Hide() end)
    H:Label(f,"Character Info settings",260,-20,600)
    H:Label(f,"A custom Character window with six illustrated tabs. Equipment slots, stats, titles, equipment sets and an active-pet page with experience and happiness.",20,-70,850)
    H:Button(f,"Move Frames",20,-130,400,function() FS.Layout:Start() end)
    H:Label(f,"Use the Character menu button or your normal Character shortcut to open it.\n\nCharacter, Reputation, Skills, Player vs. Player, Currency and Statistics all share the ForeverSuite style.",20,-190,850)
    f:Hide(); return f
end
function C:RefreshSettings() end
