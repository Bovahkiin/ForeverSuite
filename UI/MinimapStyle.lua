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
function S:MinimapHeaderIcon(button,kind)
    local icon=CreateFrame("Frame",nil,button); icon.fsSuiteStyle=true; icon.ignoreInLayout=true; icon:EnableMouse(false)
    icon:SetSize(14,14); icon.ink={}
    if kind=="addons" then icon:SetPoint("LEFT",button,"LEFT",3,0) else icon:SetPoint("CENTER") end
    if not icon.CreateLine then
        icon.texture=icon:CreateTexture(nil,"ARTWORK"); icon.texture:SetAllPoints(); icon.texture.fsSuiteStyle=true
        FS:SetMenuIcon(icon.texture,kind=="tracking" and "Map" or kind=="calendar" and "Cooldowns" or "Grid")
        return icon
    end
    local function path(points)
        for i=2,#points do
            local a,b=points[i-1],points[i]; local line=icon:CreateLine(nil,"ARTWORK")
            line.fsSuiteStyle=true; line.ignoreInLayout=true; line:SetThickness(1.4)
            line:SetStartPoint("CENTER",a[1],a[2]); line:SetEndPoint("CENTER",b[1],b[2]); icon.ink[#icon.ink+1]=line
        end
    end
    local function dot(x,y)
        local t=icon:CreateTexture(nil,"ARTWORK"); t.fsSuiteStyle=true; t.ignoreInLayout=true; t:SetSize(2,2); t:SetPoint("CENTER",x,y); icon.ink[#icon.ink+1]=t
    end
    if kind=="tracking" then
        path({{-5,1},{-4,4},{-1,5},{2,4},{3,1},{2,-2},{-1,-3},{-4,-2},{-5,1}}); path({{2,-2},{6,-6}})
    elseif kind=="calendar" then
        path({{-6,-5},{6,-5},{6,5},{-6,5},{-6,-5}}); path({{-6,2},{6,2}})
        path({{-3,4},{-3,7}}); path({{3,4},{3,7}})
        for _,x in ipairs({-3,0,3}) do dot(x,-1); dot(x,-4) end
    else for _,x in ipairs({-4,0,4}) do for _,y in ipairs({-4,0,4}) do dot(x,y) end end end
    return icon
end
function S:MinimapHeaderControls(enabled)
    if not FS.initialized or not FS.db or InCombatLockdown() or self.headerControlsApplying or not self.minimap or not FS.NativeWindows then return end
    self.headerControlsApplying=true
    self.headerButtons=self.headerButtons or setmetatable({},{__mode="k"})
    local tracking=MinimapCluster and MinimapCluster.Tracking
    local trackingButton=tracking and tracking.Button or MiniMapTrackingButton or (MiniMapTracking and (MiniMapTracking.Button or MiniMapTracking))
    local definitions={{trackingButton,"tracking",24},{GameTimeFrame,"calendar",24},{AddonCompartmentFrame,"addons",38}}
    local used={}; local x=4; local dark=FS.db.map.minimapStyle=="Dark Fantasy"
    for _,definition in ipairs(definitions) do
        local button,kind,width=definition[1],definition[2],definition[3]
        if button and type(button.GetScale)=="function" and not T:Call(button.IsForbidden,button) then
            used[button]=true
            local state=self.headerButtons[button]
            if enabled and not state then
                state={scale=button:GetScale(),level=button:GetFrameLevel(),ignore=button.ignoreInLayout,icon=self:MinimapHeaderIcon(button,kind)}
                self.headerButtons[button]=state
            end
            if state then
                if enabled then
                    if not self.minimapControls then
                        self.minimapControls=CreateFrame("Frame",nil,self.minimap,"BackdropTemplate")
                        self.minimapControls.fsSuiteStyle=true; self.minimapControls.ignoreInLayout=true
                        FS.HUD:Skin(self.minimapControls,true); self.minimapControls:EnableMouse(false)
                    end
                    local bar=self.minimapControls
                    if bar:GetParent()~=self.minimap then bar:SetParent(self.minimap) end
                    bar:SetHeight(28)
                    bar:SetFrameLevel(self.minimap:GetFrameLevel()+25)
                    FS.NativeWindows:Surface(bar,true); self:MinimapPanel(bar,dark)
                    button.ignoreInLayout=true
                    FS.NativeWindows:Geometry(button,true,function(b)
                        b:ClearAllPoints(); b:SetPoint("TOPLEFT",bar,"TOPLEFT",x,-2); b:SetSize(width,24)
                    end)
                    local parent=button:GetParent() or UIParent
                    button:SetScale(bar:GetEffectiveScale()/parent:GetEffectiveScale())
                    button:SetFrameLevel(bar:GetFrameLevel()+1)
                    FS.NativeWindows:Control(button,true)
                    local plate=FS.NativeWindows.controls[button].plate; plate:SetFrameLevel(button:GetFrameLevel()-1); self:MinimapPanel(plate,dark)
                    state.icon:SetFrameLevel(button:GetFrameLevel()+1); state.icon:Show()
                    local r,g,b=FS.Themes:Accent(); if dark then r,g,b=.84,.73,.52 end
                    for _,ink in ipairs(state.icon.ink) do ink:SetColorTexture(r,g,b,1) end
                    if kind=="addons" and button.Text then FS.NativeWindows:Geometry(button.Text,true,function(text)
                        text:ClearAllPoints(); text:SetPoint("RIGHT",button,"RIGHT",-3,0); text:SetSize(16,16)
                    end) end
                    x=x+width+4
                end
                state.active=enabled
                for _,key in ipairs({"StateTexture","AddTexture"}) do self:IconArt(button[key],enabled) end
            end
        end
    end
    for button,state in pairs(self.headerButtons) do
        if not enabled or not used[button] then
            state.active=false; state.icon:Hide(); button.ignoreInLayout=state.ignore
            FS.NativeWindows:Geometry(button,false,function() end)
            if button.Text then FS.NativeWindows:Geometry(button.Text,false,function() end) end
            button:SetScale(state.scale); button:SetFrameLevel(state.level)
            FS.NativeWindows:Control(button,false)
            for _,key in ipairs({"StateTexture","AddTexture"}) do self:IconArt(button[key],false) end
        end
    end
    local background=tracking and tracking.Background
    if self.headerTrackingBackground~=background then self:IconArt(self.headerTrackingBackground,false); self.headerTrackingBackground=background end
    self:IconArt(background,enabled and trackingButton~=nil)
    if self.minimapControls then
        local bar=self.minimapControls; bar:SetWidth(math.max(32,x)); bar:SetShown(enabled and x>4)
        local ratio=bar:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local top=T:Call(self.minimap.GetTop,self.minimap); local left=T:Call(self.minimap.GetLeft,self.minimap)
        bar:ClearAllPoints()
        if T:Number(top) and UIParent:GetHeight()-top*ratio>=32*ratio then
            bar:SetPoint("BOTTOMRIGHT",self.minimap,"TOPRIGHT",0,2)
        elseif not T:Number(left) or left>=bar:GetWidth()+8 then
            bar:SetPoint("TOPRIGHT",self.minimap,"TOPLEFT",-6,0)
        else bar:SetPoint("TOPRIGHT",Minimap,"BOTTOMRIGHT",0,-36) end
    end
    self.headerControlsApplying=nil
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
        Minimap:HookScript("OnSizeChanged",function() S:PositionMinimapRim(); S:MinimapHeaderControls(FS:IsModuleEnabled("Map")) end)
        hooksecurefunc(Minimap,"SetScale",function() S:MinimapHeaderControls(FS:IsModuleEnabled("Map")) end)
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
    self:MinimapHeaderControls(enabled)
    if self.minimap and self.minimap.zone then
        if square then self.minimap.zone:SetTextColor(.91,.85,.73,1)
        elseif FS.Themes:Current()==10 then self.minimap.zone:SetTextColor(.16,.12,.08,1)
        else self.minimap.zone:SetTextColor(.9,.94,1,1) end
    end
end
