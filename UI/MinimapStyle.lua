local _,FS=...
local S,T=FS.Style,FS.Tools
local root="Interface\\AddOns\\ForeverSuite\\Assets\\Minimap\\"
local roundMask="ui-hud-minimap-frame-generic-mask"

local function defaultMask()
    -- Forever's Camelot minimap uses an atlas and has no GetMaskTexture API.
    -- Restoring the old Textures\\MinimapMask file can hide the terrain entirely.
    if (FS.client and FS.client.isForever) or T:Call(C_Texture and C_Texture.GetAtlasInfo,roundMask) then return roundMask end
    return "Textures\\MinimapMask"
end

local function setMask(state,mask)
    state.settingMask=true
    state.owner:SetMaskTexture(mask)
    state.settingMask=false
    state.appliedMask=mask
end

function S:IsSquareMinimap()
    return self.minimapFace and self.minimapFace.square==true or false
end

function S:MinimapPanel(panel,dark)
    if not panel then return end
    if not panel.fsMinimapFantasyFill and dark then
        local fill=panel:CreateTexture(nil,"BORDER")
        fill.fsSuiteStyle=true; fill.ignoreInLayout=true
        fill:SetPoint("TOPLEFT",1,-1); fill:SetPoint("BOTTOMRIGHT",-1,1)
        fill:SetColorTexture(.035,.029,.031,.98)
        panel.fsMinimapFantasyFill=fill
        local edge=panel:CreateTexture(nil,"ARTWORK")
        edge.fsSuiteStyle=true; edge.ignoreInLayout=true
        edge:SetPoint("BOTTOMLEFT",2,1); edge:SetPoint("BOTTOMRIGHT",-2,1); edge:SetHeight(1)
        edge:SetColorTexture(.48,.13,.15,.85); panel.fsMinimapFantasyEdge=edge
    end
    if panel.fsMinimapFantasyFill then
        panel.fsMinimapFantasyFill:SetShown(dark)
        panel.fsMinimapFantasyEdge:SetShown(dark)
    end
    local r,g,b=FS.Themes:Accent()
    panel:SetBackdropBorderColor(dark and .4 or r,dark and .32 or g,dark and .25 or b,.8)
end

function S:PositionMinimapRim()
    local r=self.mapRim; if not r or not Minimap then return end
    local width,height=Minimap:GetWidth(),Minimap:GetHeight()
    local x=T:Number(width) and width*.03 or 6
    local y=T:Number(height) and height*.03 or 6
    if r.fsOwner==Minimap and r.fsInsetX==x and r.fsInsetY==y then return end
    r.fsOwner=Minimap; r.fsInsetX=x; r.fsInsetY=y
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-x,y)
    r:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",x,-y)
end

function S:ApplyMinimapFrame(enabled)
    if not Minimap or InCombatLockdown() then return end
    local state=self.minimapFace
    if not state or state.owner~=Minimap then
        if state and state.square and state.owner.SetMaskTexture then setMask(state,state.mask) end
        local mask=T:Call(Minimap.GetMaskTexture,Minimap)
        if not ((type(mask)=="string" and mask~="") or (T:Number(mask) and mask>0)) then mask=defaultMask() end
        state={owner=Minimap,mask=mask}; self.minimapFace=state
        if Minimap.SetMaskTexture then
            hooksecurefunc(Minimap,"SetMaskTexture",function(_,asset)
                if not state.settingMask then state.mask=asset; state.appliedMask=nil end
            end)
        end
        Minimap:HookScript("OnSizeChanged",function() S:PositionMinimapRim() end)
    end
    if MinimapCluster and type(MinimapCluster.UpdateMinimapConfig)=="function" and not MinimapCluster.fsSuiteMaskHook then
        MinimapCluster.fsSuiteMaskHook=true
        hooksecurefunc(MinimapCluster,"UpdateMinimapConfig",function()
            if FS.initialized then
                if InCombatLockdown() then FS.modules.Map.pending=true else S:Minimap() end
            end
        end)
    end
    if not self.minimapShapeHook then
        self.minimapShapeHook=true
        local previous=GetMinimapShape
        GetMinimapShape=function()
            if S:IsSquareMinimap() then return "SQUARE" end
            return T:Call(previous) or "ROUND"
        end
    end
    local square=enabled and FS.db.map.minimapStyle=="Dark Fantasy"
    if not Minimap.SetMaskTexture then square=false end
    local squareMask="Interface\\Buttons\\WHITE8X8"
    if state.square~=square or (square and state.appliedMask~=squareMask) then
        if square then setMask(state,squareMask)
        elseif state.square then setMask(state,state.mask) end
        state.square=square
        if FS.minimapButton and FS.minimapButton:GetParent()==Minimap then FS:UpdateMinimapButton() end
    end
    if not self.mapRim then
        self.mapRim=Minimap:CreateTexture(nil,"OVERLAY")
        self.mapRim.fsSuiteStyle=true; self.mapRim.ignoreInLayout=true
    end
    local asset=root..(square and "Dark-Fantasy.tga" or string.format("%02d-Round.tga",FS.Themes:Current() or 0))
    if self.mapRim.fsAsset~=asset then self.mapRim:SetTexture(asset); self.mapRim.fsAsset=asset end
    self:PositionMinimapRim(); self.mapRim:SetShown(enabled)
    self:MinimapPanel(self.minimap,square)
    self:MinimapPanel(FS.modules.Map.coordinateFrame,square)
    if self.minimap and self.minimap.zone then
        if square then self.minimap.zone:SetTextColor(.91,.85,.73,1)
        elseif FS.Themes:Current()==10 then self.minimap.zone:SetTextColor(.16,.12,.08,1)
        else self.minimap.zone:SetTextColor(.9,.94,1,1) end
    end
end
