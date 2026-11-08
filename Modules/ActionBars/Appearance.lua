local _,FS=...
local A,H=FS.modules.ActionBars,FS.HUD
A.styles={"Minimal","Floating","Compact dock","Gold & cyan"}
A.art={Minimal="Minimal",Floating="Floating",["Compact dock"]="Dock",["Gold & cyan"]="Gold"}
local path="Interface\\AddOns\\ForeverSuite\\Assets\\ActionBars\\"
function A:StyleTile(tile,style,background)
    tile.ignoreInLayout=true
    if FS.Themes:Current() then
        if tile.styleTexture then tile.styleTexture:Hide() end
        FS.Themes:Register(tile,"Button"); return
    end
    local themed=FS.Themes.frames[tile]; if themed and themed.parts then for _,p in ipairs(themed.parts) do p:Hide() end end
    if not tile.styleTexture then
        tile:SetBackdrop(nil)
        tile.styleTexture=tile:CreateTexture(nil,"BACKGROUND"); tile.styleTexture.ignoreInLayout=true; tile.styleTexture:SetAllPoints()
    end
    if tile.fsTileStyle~=style then
        tile.styleTexture:SetTexture(path.."Tile-"..(self.art[style] or "Minimal")..".tga")
        tile.fsTileStyle=style
    end
    tile.styleTexture:Show()
end
function A:StyleTray(plate,style,enabled)
    plate.ignoreInLayout=true
    local theme=FS.Themes:Current()
    if theme then
        if plate.styleTexture then plate.styleTexture:Hide() end
        FS.Themes:Register(plate,"Panel")
        self:SetDecorationShown(plate,enabled and theme~=3 and theme~=5 and theme~=8 and theme~=10)
        plate.gold:Hide(); plate.cyan:Hide(); return
    end
    local themed=FS.Themes.frames[plate]; if themed and themed.parts then for _,p in ipairs(themed.parts) do p:Hide() end end
    if not plate.styleTexture then
        plate:SetBackdrop(nil)
        plate.styleTexture=plate:CreateTexture(nil,"BACKGROUND"); plate.styleTexture.ignoreInLayout=true; plate.styleTexture:SetAllPoints()
    end
    if plate.fsTrayStyle~=style then
        plate.styleTexture:SetTexture(path.."Tray-"..(style=="Compact dock" and "Dock" or "Minimal")..".tga")
        plate.fsTrayStyle=style
    end
    local vertical=plate:GetHeight()>plate:GetWidth()
    if plate.fsTrayVertical~=vertical then
        if vertical then plate.styleTexture:SetTexCoord(0,1,1,1,0,0,1,0)
        else plate.styleTexture:SetTexCoord(0,1,0,1) end
        plate.fsTrayVertical=vertical
    end
    self:SetDecorationShown(plate,enabled and style~="Floating" and style~="Gold & cyan")
    plate.styleTexture:Show()
    plate.gold:Hide(); plate.cyan:Hide()
end
function A:StyleIcon(icon,owner,style,enabled,state)
    if not icon then return end
    if not enabled then
        if state and state.iconStyle then H:RestorePoints(icon,state.iconPoints); state.iconStyle=nil end
        return
    end
    local inset=style=="Gold & cyan" and 6 or style=="Floating" and 4 or style=="Compact dock" and 3 or 2
    -- Texture anchors are decorative; native secure button geometry stays intact.
    if not state or state.iconStyle~=style then
        icon:ClearAllPoints(); icon:SetPoint("TOPLEFT",owner,"TOPLEFT",inset,-inset)
        icon:SetPoint("BOTTOMRIGHT",owner,"BOTTOMRIGHT",-inset,style=="Gold & cyan" and inset+2 or inset)
        if state then state.iconStyle=style end
    end
    icon:SetTexCoord(.07,.93,.07,.93)
end
function A:ApplyAppearance()
    if not FS.Style or not FS.db or InCombatLockdown() then return end
    local enabled=FS:IsModuleEnabled("ActionBars"); local style=FS.db.actionBars.style
    for _,name in ipairs({"MainActionBar","MainMenuBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarLeft","MultiBarRight","StanceBar","PetActionBar"}) do
        local bar=_G[name]; if bar and not (name=="MainMenuBar" and MainActionBar) then self:StyleTray(FS.Style:Plate(bar),style,enabled) end
    end
    for _,state in pairs(self.buttons) do
        for _,tile in ipairs({state.border,state.slot}) do
            self:StyleTile(tile,style,tile==state.slot)
            local inset=style=="Floating" and 2 or 0
            if tile.fsInset~=inset then
                tile:ClearAllPoints(); tile:SetPoint("TOPLEFT",state.button or tile:GetParent(),"TOPLEFT",inset,-inset)
                tile:SetPoint("BOTTOMRIGHT",state.button or tile:GetParent(),"BOTTOMRIGHT",-inset,inset); tile.fsInset=inset
            end
        end
        self:StyleIcon(state.icon,state.button,style,enabled,state)
    end
    for _,state in pairs(self.bagSkins or {}) do self:StyleTile(state.border,style,false) end
    local bags=BagsBar or MainMenuBarBagButtons
    if bags then self:StyleTray(FS.Style:Plate(bags),style,enabled) end
end
