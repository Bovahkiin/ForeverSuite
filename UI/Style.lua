local _,FS=...
local S={plates={},native={}}; FS.Style=S
local H=FS.HUD
function S:Plate(owner,kind)
    -- ResizeLayoutMixin measures visible children AND regions. Decorative
    -- frames extend outside the native bounds and must never resize their owner.
    if not owner or not owner.GetFrameLevel or (owner.IsForbidden and owner:IsForbidden()) then return end
    local f=self.plates[owner]
    if not f then
        local bars=FS.modules.ActionBars
        local nativeBar=bars and (bars:IsNativeBar(owner.GetName and owner:GetName()) or owner==BagsBar or owner==MainMenuBarBagButtons)
        f=nativeBar and bars:CreateDecoration(owner) or CreateFrame("Frame",nil,owner,"BackdropTemplate"); f.fsSuiteStyle=true; f.ignoreInLayout=true; self.plates[owner]=f
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",owner,"TOPLEFT",-5,5); f:SetPoint("BOTTOMRIGHT",owner,"BOTTOMRIGHT",5,-5)
        f:SetFrameLevel(math.max(0,owner:GetFrameLevel()-1)); f:EnableMouse(false)
        if not nativeBar then H:Skin(f,true); f:SetBackdropColor(.018,.027,.038,.9); f:SetBackdropBorderColor(.12,.45,.54,.7) end
        f.gold=f:CreateTexture(nil,"ARTWORK"); f.gold:SetColorTexture(.95,.68,.24,.8)
        f.gold:SetSize(24,2); f.gold:SetPoint("TOPLEFT",3,-2)
        f.cyan=f:CreateTexture(nil,"ARTWORK"); f.cyan:SetColorTexture(.12,.72,.86,.65)
        f.cyan:SetHeight(1); f.cyan:SetPoint("BOTTOMLEFT",4,2); f.cyan:SetPoint("BOTTOMRIGHT",-4,2)
    end
    return f
end
function S:Feedback(button)
    -- Native action-button mouse scripts can enter protected visibility updates.
    -- Keep their complete input path client-owned; decorative skins need no hooks.
    local bars=FS.modules.ActionBars
    if button and ((bars and bars.buttons[button]) or (button.IsProtected and button:IsProtected())) then return end
    if not button or button.fsSuiteFeedback then return end
    button.fsSuiteFeedback=true
    local flash=button:CreateTexture(nil,"OVERLAY"); flash.fsSuiteStyle=true; flash.ignoreInLayout=true; flash:SetAllPoints(); flash:SetColorTexture(.12,.72,.86,.22); flash:Hide()
    local group=flash:CreateAnimationGroup(); local a=group:CreateAnimation("Alpha"); a:SetFromAlpha(.25); a:SetToAlpha(0); a:SetDuration(.2)
    group:SetScript("OnFinished",function() flash:Hide() end)
    button:HookScript("PostClick",function() if FS:IsModuleEnabled("ActionBars") then flash:Show(); group:Stop(); group:Play() end end)
    button:HookScript("OnEnter",function() if FS:IsModuleEnabled("ActionBars") then flash:SetAlpha(.13); flash:Show() end end)
    button:HookScript("OnLeave",function() flash:Hide() end)
end
function S:Bars()
    local A=FS.modules.ActionBars; local enabled=FS:IsModuleEnabled("ActionBars")
    for _,name in ipairs({"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarLeft","MultiBarRight","StanceBar","PetActionBar"}) do
        local bar=_G[name]; if bar then self:Plate(bar):SetShown(enabled) end
    end
    if not MainActionBar and MainMenuBar then self:Plate(MainMenuBar):SetShown(enabled) end
    if A.menuRoot then self:Plate(A.menuRoot):SetShown(enabled and FS.db.actionBars.menu) end
    for b,state in pairs(A.buttons) do
        self:Feedback(b)
    end
    if A.ApplyAppearance then A:ApplyAppearance() end
    for b in pairs(A.bagSkins or {}) do self:Feedback(b) end
    local bag=BagsBar or MainMenuBarBagButtons
    if bag then
        local plate=self:Plate(bag); A:StyleTray(plate,FS.db.actionBars.style,enabled)
        local gear=FS.modules.Gear.indicator
        plate:ClearAllPoints(); plate:SetPoint("BOTTOMRIGHT",bag,"BOTTOMRIGHT",5,-5)
        plate:SetPoint("TOPLEFT",bag,"TOPLEFT",-5,5)
        if gear then
            H:Skin(gear); gear:SetBackdropBorderColor(.95,.68,.24,.65)
            local text=gear.GetFontString and gear:GetFontString(); if text then text:SetTextColor(.9,.94,1,1); FS:ApplyFont(text,12) end
        end
    end
end
function S:Units()
    for _,f in pairs(FS.modules.UnitFrames.frames) do
        if not f.fsPortraitRim then
            local rim=CreateFrame("Frame",nil,f,"BackdropTemplate"); rim.ignoreInLayout=true; rim.fsThemeBorderOnly=true; rim.fsThemeTransparent=true; f.fsPortraitRim=rim; H:Skin(rim); rim:EnableMouse(false)
            rim:SetPoint("TOPLEFT",f.portrait,"TOPLEFT",-1,1); rim:SetPoint("BOTTOMRIGHT",f.portrait,"BOTTOMRIGHT",1,-1)
            rim:SetFrameLevel(f:GetFrameLevel()+1); rim:SetBackdropColor(0,0,0,0); rim:SetBackdropBorderColor(.95,.68,.24,.7)
            f.health.sheen=f.health:CreateTexture(nil,"OVERLAY"); f.health.sheen:SetColorTexture(1,1,1,.06)
            f.health.sheen:SetPoint("TOPLEFT"); f.health.sheen:SetPoint("TOPRIGHT"); f.health.sheen:SetHeight(10)
        end
        f:SetBackdropColor(.018,.027,.038,.96); f:SetBackdropBorderColor(.12,.55,.65,.8)
        FS:ApplyFont(f.name,12,"OUTLINE"); FS:ApplyFont(f.value,12,"OUTLINE")
        if f.level then FS:ApplyFont(f.level,12,"OUTLINE"); FS.modules.UnitFrames:LayoutLevel(f) end
    end
end
function S:Minimap()
    if not Minimap then return end
    local enabled=FS:IsModuleEnabled("Map")
    if not self.minimap then
        local f=CreateFrame("Frame",nil,Minimap,"BackdropTemplate"); f.ignoreInLayout=true; self.minimap=f; f.fsFontModule="Map"; H:Skin(f); f:EnableMouse(false)
        f:SetHeight(24); f:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-4,28); f:SetPoint("TOPRIGHT",Minimap,"TOPRIGHT",4,28)
        f.zone=H:Label(f,"",8,-5,100); f.zone:SetPoint("RIGHT",f,"RIGHT",-8,0); f.zone:SetHeight(16); f.zone:SetJustifyH("CENTER"); f.zone:SetFont("Interface\\AddOns\\ForeverSuite\\Assets\\Arial-Bold.ttf",12,"")
        FS.Typography.regions[f.zone].path="Interface\\AddOns\\ForeverSuite\\Assets\\Arial-Bold.ttf"; FS:ApplyFont(f.zone,12,"")
        f.time=H:Label(f,"",0,-5,40); f.time:SetPoint("TOPRIGHT",-4,-5); f.time:SetJustifyH("RIGHT")
        f:SetBackdropColor(.018,.027,.038,.92); f:SetBackdropBorderColor(.95,.68,.24,.6)
    end
    self:CoordinateDuplicates(enabled and FS.db.map.coordinates)
    self.minimap:SetShown(enabled)
    self.minimap.zone:SetText(FS.Tools:Call(GetMinimapZoneText) or FS.Tools:Call(GetSubZoneText) or "Map")
    self.minimap.time:Hide()
    self:UpdateClock()
    for _,name in ipairs({"MinimapBorder","MinimapBorderTop","MinimapZoneTextButton","MinimapCompassTexture","MinimapCompassTextureUnderlay","MinimapZoneText","TimeManagerClockButton"}) do
        local r=_G[name]
        if r and r.SetAlpha then self:NativeRegion(r,enabled) end
    end
    if MinimapCluster then
        for _,key in ipairs({"BorderTop","ZoneTextButton"}) do local r=MinimapCluster[key]; if r then self:NativeRegion(r,enabled) end end
    end
    if not self.mapRim then
        local r=Minimap:CreateTexture(nil,"OVERLAY"); r.ignoreInLayout=true; self.mapRim=r
        r:SetTexture("Interface\\AddOns\\ForeverSuite\\Assets\\Minimap-Rim.tga"); r:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-3,3); r:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",3,-3)
    end
    self.mapRim:SetShown(enabled)
end
function S:CoordinateDuplicates(hidden)
    self.coordinateDuplicates=self.coordinateDuplicates or {}
    local function remember(region)
        if not region or self.coordinateDuplicates[region] then return end
        local state={alpha=region:GetAlpha(),hidden=false}; self.coordinateDuplicates[region]=state
        hooksecurefunc(region,"SetAlpha",function(r)
            if state.hidden and not state.setting then state.setting=true; r:SetAlpha(0); state.setting=false end
        end)
    end
    remember(_G._EBS_CoordFrame)
    local function scan(frame,depth)
        if not frame or depth>2 or frame==FS.modules.Map.coordinateFrame or frame.fsSuiteStyle then return end
        for _,region in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do
            if region.GetObjectType and region:GetObjectType()=="FontString" and region.GetText then
                local text=region:GetText()
                if H:Safe(text) and type(text)=="string" and text:match("^%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*$") then remember(region) end
            end
        end
        if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do scan(child,depth+1) end end
    end
    scan(Minimap,0)
    for region,state in pairs(self.coordinateDuplicates) do
        state.hidden=hidden; state.setting=true; region:SetAlpha(hidden and 0 or state.alpha); state.setting=false
    end
end
function S:UpdateClock()
    if not FS.initialized or not FS.db or (not self.clock and InCombatLockdown()) then return end
    local localTime=FS.Tools:Call(date,"*t"); local hour,minute
    if type(localTime)=="table" then hour,minute=localTime.hour,localTime.min end
    self:Clock(hour,minute,FS:IsModuleEnabled("Map"))
end
function S:Clock(hour,minute,enabled)
    if not self.clock then
        local f=CreateFrame("Frame","ForeverSuiteClock",UIParent,"BackdropTemplate"); self.clock=f; f.fsFontModule="QoL"
        H:Skin(f); f:SetSize(72,28); f:SetPoint("BOTTOM",UIParent,"BOTTOM",0,12)
        f:SetBackdropColor(.018,.027,.038,.95); f:SetBackdropBorderColor(.12,.72,.86,.8); f:EnableMouse(false)
        f.text=FS.Widgets:Label(f); f.text:SetPoint("CENTER"); FS:ApplyFont(f.text,16,"OUTLINE"); f.text:SetTextColor(.95,.97,1,1)
        f.accent=f:CreateTexture(nil,"ARTWORK"); f.accent:SetColorTexture(.95,.68,.24,.85); f.accent:SetSize(16,2); f.accent:SetPoint("TOP",0,-1)
        FS.Layout:Register("Clock",f,"Clock")
    end
    self.clock.text:SetText(hour and minute and string.format("%02d:%02d",hour,minute) or "--:--")
    self.clock:SetShown(enabled)
end
function S:NativeRegion(region,hidden)
    local state=self.native[region]
    if not state then state={}; self.native[region]=state end
    if state.alpha==nil then state.alpha=region:GetAlpha() end
    region:SetAlpha(hidden and 0 or state.alpha)
end
function S:NativeFonts(frame,enabled,depth,fontSize,flags)
    if not frame or frame.fsSuiteStyle or (frame.IsForbidden and frame:IsForbidden()) then return end
    depth=depth or 0; if depth>10 then return end
    local regions=frame.GetRegions and {frame:GetRegions()} or {}
    if frame.GetFont then regions[#regions+1]=frame end
    for _,r in ipairs(regions) do
        if r.GetFont then
            local state=self.native[r]; if not state then state={}; self.native[r]=state end
            if not state.font then state.font={r:GetFont()} end
            if enabled then FS:ApplyFont(r,fontSize,flags) elseif state.font and state.font[1] then FS:ReleaseFont(r); r:SetFont(unpack(state.font)) end
            if enabled then FS.Themes:Font(r) else FS.Themes:ReleaseFont(r) end
        end
    end
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do self:NativeFonts(child,enabled,depth+1,fontSize,flags) end end
end
function S:Chat()
    local C=FS.modules.Chat; local enabled=FS:IsModuleEnabled("Chat"); local data=C:Data()
    local panels=enabled and data.styleWindow; local tabs=enabled and data.styleTabs; local inputs=enabled and data.styleInput
    local color=C.colors[data.borderColor]; local flags=data.outline and "OUTLINE" or ""
    local function paint(plate)
        plate:SetBackdropColor(.018,.027,.038,data.backgroundOpacity)
        plate:SetBackdropBorderColor(color[1],color[2],color[3],data.borderColor=="None" and 0 or .8)
    end
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local f=_G["ChatFrame"..i]
        if f then
            local plate=self:Plate(f); plate:SetShown(panels)
            local right=self:ChatScrollBar(f,panels,color,data.backgroundOpacity)
            plate:ClearAllPoints(); plate:SetPoint("TOPLEFT",f,"TOPLEFT",-5,5); plate:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",right,-5)
            paint(plate); plate.gold:SetShown(data.borderColor~="None"); plate.cyan:SetShown(data.borderColor~="None")
            self:NativeFonts(f,enabled,nil,data.fontSize,flags); C:FrameOptions(f,enabled)
            for _,part in ipairs({"Background","ButtonFrame"}) do
                local r=f[part]; if r and r.GetAlpha and part=="Background" then self:NativeRegion(r,panels) end
            end
            self:NativeFonts(_G["ChatFrame"..i.."Tab"],enabled,nil,data.fontSize,flags); self:NativeFonts(_G["ChatFrame"..i.."EditBox"],enabled,nil,data.fontSize,flags)
            local tab=_G["ChatFrame"..i.."Tab"]; if tab then
                local plate=self:Plate(tab); plate:ClearAllPoints(); plate:SetAllPoints(tab); plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(tabs)
                paint(plate)
                for _,r in ipairs({tab:GetRegions()}) do
                    if r.GetObjectType and r:GetObjectType()=="Texture" then self:NativeRegion(r,tabs) end
                end
            end
            local edit=_G["ChatFrame"..i.."EditBox"]; if edit then
                local plate=self:Plate(edit); plate:ClearAllPoints(); plate:SetAllPoints(edit); plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(inputs)
                paint(plate)
                for _,r in ipairs({edit:GetRegions()}) do if r.GetObjectType and r:GetObjectType()=="Texture" then self:NativeRegion(r,inputs) end end
                for _,key in ipairs({"Left","Middle","Right","FocusLeft","FocusMid","FocusRight"}) do
                    local r=edit[key] or _G["ChatFrame"..i.."EditBox"..key]; if r then self:NativeRegion(r,inputs) end
                end
            end
        end
    end
    self:ChatButtons(enabled and data.styleButtons,color,data.backgroundOpacity)
end
function S:ChatButtonIcon(button,kind)
    local f=CreateFrame("Frame",nil,button); f.fsSuiteStyle=true; f.ignoreInLayout=true; f:EnableMouse(false)
    f.ink={}
    local size=kind=="Social" and 20 or 24
    f:SetSize(size,size); f:SetPoint("CENTER",0,kind=="Social" and 5 or 0); f:SetFrameLevel(button:GetFrameLevel()+1)
    if kind=="Social" or not f.CreateLine then
        local t=f:CreateTexture(nil,"ARTWORK"); t.fsSuiteStyle=true; t.ignoreInLayout=true; t:SetAllPoints(); FS:SetMenuIcon(t,kind=="Social" and "Social" or kind=="Speaker" and "Groups" or "Quests")
        f.texture=t; return f
    end
    local function path(points,r,g,b)
        for i=2,#points do
            local a,z=points[i-1],points[i]; local line=f:CreateLine(nil,"ARTWORK"); line.fsSuiteStyle=true; line.ignoreInLayout=true
            line:SetThickness(1.5); line:SetColorTexture(r,g,b,1); line:SetStartPoint("CENTER",a[1],a[2]); line:SetEndPoint("CENTER",z[1],z[2])
            f.ink[#f.ink+1]=line
        end
    end
    if kind=="Speaker" then
        path({{-9,-3},{-5,-3},{-1,-7},{-1,7},{-5,3},{-9,3},{-9,-3}},.95,.68,.24)
        path({{2,-4},{4,-1},{4,1},{2,4}},.12,.72,.86)
        path({{5,-8},{8,-4},{9,0},{8,4},{5,8}},.12,.72,.86)
    else
        path({{-9,-6},{-4,-6},{-7,-10},{1,-6},{9,-6},{9,7},{-9,7},{-9,-6}},.95,.68,.24)
        for _,x in ipairs({-4,0,4}) do local dot=f:CreateTexture(nil,"ARTWORK"); dot.fsSuiteStyle=true; dot.ignoreInLayout=true; dot:SetSize(2,2); dot:SetPoint("CENTER",x,0); dot:SetColorTexture(.12,.72,.86,1); f.ink[#f.ink+1]=dot end
    end
    return f
end
function S:ChatButtons(enabled,color,opacity)
    if InCombatLockdown() or not FS.NativeWindows then return end
    local N=FS.NativeWindows; self.chatButtons=self.chatButtons or {}
    for _,definition in ipairs({{"QuickJoinToastButton","Social"},{"ChatFrameChannelButton","Speaker"},{"ChatFrameMenuButton","Chat"}}) do
        local button=_G[definition[1]]
        if button and not (button.IsForbidden and button:IsForbidden()) then
            local state=self.chatButtons[button]
            if enabled or state then
                if not state then state={icon=self:ChatButtonIcon(button,definition[2])}; self.chatButtons[button]=state end
                N:Control(button,enabled)
                local control=N.controls[button]; control.plate:SetBackdropColor(.018,.027,.038,opacity)
                FS.Themes:Register(control.plate,"Button")
                local ir,ig,ib=FS.Themes:Accent()
                for _,ink in ipairs(state.icon.ink or {}) do ink:SetColorTexture(ir,ig,ib,1) end
                local usable=not button.IsEnabled or button:IsEnabled()
                if not usable then control.plate:SetBackdropBorderColor(.22,.28,.32,.6)
                else control.plate:SetBackdropBorderColor(color[1],color[2],color[3],color==FS.modules.Chat.colors.None and 0 or .8) end
                state.icon:SetShown(enabled); state.icon:SetAlpha(usable and 1 or .35)
                for _,region in ipairs(button:GetRegions()) do
                    if not region.fsSuiteStyle then
                        if region:GetObjectType()=="Texture" then N:Art(region,enabled)
                        elseif region:GetObjectType()=="FontString" then N:Font(region,enabled) end
                    end
                end
                for _,key in ipairs({"Icon","icon","FriendIcon","NormalTexture","PushedTexture","HighlightTexture","DisabledTexture","Background","Border"}) do
                    local r=button[key]; if r and r.GetObjectType and r:GetObjectType()=="Texture" then N:Art(r,enabled) end
                end
                -- Only decorative frame pieces are traversed; Quick Join toasts and menus keep their content.
                local function border(frame,depth)
                    if not frame or depth>2 or frame.fsSuiteStyle or (frame.IsForbidden and frame:IsForbidden()) then return end
                    for _,r in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do if r:GetObjectType()=="Texture" and not r.fsSuiteStyle then N:Art(r,enabled) end end
                    for _,child in ipairs(frame.GetChildren and {frame:GetChildren()} or {}) do border(child,depth+1) end
                end
                border(button.NineSlice,0)
            end
        end
    end
end
function S:ChatScrollBar(frame,enabled,color,opacity)
    local N=FS.NativeWindows; local name=frame:GetName() or ""
    local bar=frame.ScrollBar or frame.scrollBar or _G[name.."ScrollBar"]
    local bottom=frame.ScrollToBottomButton or _G[name.."ScrollToBottomButton"]
    local right=5
    local function include(control)
        if not enabled or not control then return end
        local edge=FS.Tools:Call(control.GetRight,control); local textEdge=FS.Tools:Call(frame.GetRight,frame)
        if H:Safe(edge) and H:Safe(textEdge) and type(edge)=="number" and type(textEdge)=="number" then right=math.max(right,edge-textEdge+5)
        elseif control==bar then right=math.max(right,control:GetWidth()+8) end
    end
    local function paint(plate,thumb)
        plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
        local c=color; if thumb and color==FS.modules.Chat.colors.None then c=FS.modules.Chat.colors.Cyan end
        plate:SetBackdropColor(thumb and c[1] or .018,thumb and c[2] or .027,thumb and c[3] or .038,thumb and .9 or opacity)
        plate:SetBackdropBorderColor(c[1],c[2],c[3],color==FS.modules.Chat.colors.None and not thumb and 0 or .8)
    end
    local function arrow(button,glyph)
        if not button or not N or (button.IsForbidden and button:IsForbidden()) then return end
        N:Tree(button,enabled,button,0,false,glyph)
        local state=N.controls[button]; if state then paint(state.plate); if state.glyph then FS:ApplyFont(state.glyph,12) end end
        include(button)
    end
    local function strip(f,depth)
        if depth>4 or f.fsSuiteStyle or (f.IsForbidden and f:IsForbidden()) then return end
        for _,r in ipairs(f.GetRegions and {f:GetRegions()} or {}) do if r:GetObjectType()=="Texture" and not r.fsSuiteStyle then N:Art(r,enabled) end end
        for _,child in ipairs(f.GetChildren and {f:GetChildren()} or {}) do strip(child,depth+1) end
    end
    if bar and N and not (bar.IsForbidden and bar:IsForbidden()) then
        N:Tree(bar,enabled,bar)
        strip(bar,0)
        local track=bar.Track; if not track or not track.GetFrameLevel then track=bar end
        local plate=self:Plate(track); plate:ClearAllPoints(); plate:SetAllPoints(track); paint(plate)
        arrow(bar.Back or bar.ScrollUpButton or _G[name.."ScrollBarScrollUpButton"],"^")
        arrow(bar.Forward or bar.ScrollDownButton or _G[name.."ScrollBarScrollDownButton"],"v")
        local thumb=(bar.Track and bar.Track.Thumb) or bar.Thumb or (bar.GetThumbTexture and bar:GetThumbTexture())
        if thumb and not (thumb.IsForbidden and thumb:IsForbidden()) then
            local kind=thumb:GetObjectType()
            if kind=="Texture" then
                N:Art(thumb,enabled)
                if not thumb.fsChatThumb then
                    local fill=bar:CreateTexture(nil,"OVERLAY"); fill.fsSuiteStyle=true; fill.ignoreInLayout=true; thumb.fsChatThumb=fill; fill:SetAllPoints(thumb)
                end
                local c=color==FS.modules.Chat.colors.None and FS.modules.Chat.colors.Cyan or color
                thumb.fsChatThumb:SetColorTexture(c[1],c[2],c[3],.9); thumb.fsChatThumb:SetShown(enabled and thumb:IsShown())
            else
                strip(thumb,0)
                local p=self:Plate(thumb); p:ClearAllPoints(); p:SetAllPoints(thumb); paint(p,true)
            end
        end
        include(bar)
    end
    arrow(bottom,"v")
    return right
end
function S:NativeControl(button,enabled)
    if not button or not button.GetNormalTexture then return end
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture"}) do
        local r=button[method] and button[method](button); if r then self:NativeRegion(r,enabled) end
    end
    local plate=self:Plate(button)
    plate:ClearAllPoints(); plate:SetAllPoints(button); plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
end
function S:MeterHeader(frame,enabled)
    if not frame.Header then return end
    if not frame.fsMeterHeader then
        local bg=frame:CreateTexture(nil,"BACKGROUND"); bg.ignoreInLayout=true; bg.fsSuiteStyle=true; frame.fsMeterHeader=bg
        bg:SetAllPoints(frame.Header); bg:SetColorTexture(.025,.045,.06,.98)
    end
    self:NativeRegion(frame.Header,enabled); frame.fsMeterHeader:SetShown(enabled)
    for key,glyph in pairs({DamageMeterTypeDropdown="v",MinimizeButton="-",SettingsDropdown="Menu",SessionDropdown=""}) do
        local b=frame[key]
        if b then
            self:NativeControl(b,enabled)
            if not b.fsMeterGlyph and glyph~="" then
                if glyph=="Menu" then
                    b.fsMeterGlyph=b:CreateTexture(nil,"OVERLAY"); b.fsMeterGlyph:SetSize(16,16); b.fsMeterGlyph:SetPoint("CENTER"); FS:SetMenuIcon(b.fsMeterGlyph,"Menu")
                else
                    b.fsMeterGlyph=FS.Widgets:Label(b); b.fsMeterGlyph:SetPoint("CENTER"); b.fsMeterGlyph:SetText(glyph)
                end
            end
            if b.fsMeterGlyph then b.fsMeterGlyph.ignoreInLayout=true; b.fsMeterGlyph.fsSuiteStyle=true; b.fsMeterGlyph:SetShown(enabled) end
            for _,r in ipairs({b:GetRegions()}) do
                if r~=b.fsMeterGlyph and r.GetObjectType and r:GetObjectType()=="Texture" then self:NativeRegion(r,enabled) end
            end
        end
    end
end
function S:MeterTree(frame,enabled,depth)
    if not frame or frame.fsSuiteStyle or (frame.IsForbidden and frame:IsForbidden()) then return end
    depth=depth or 0; if depth>10 then return end
    if frame.GetObjectType and frame:GetObjectType()=="StatusBar" then
        local state=self.native[frame]
        if not state then state={}; self.native[frame]=state end
        if not state.textureRecorded then
            local r=frame:GetStatusBarTexture(); state.texture=r and r.GetTexture and r:GetTexture(); state.textureRecorded=true
        end
        if enabled then frame:SetStatusBarTexture(H.texture) elseif state.texture then frame:SetStatusBarTexture(state.texture) end
    end
    for _,key in ipairs({"Background","Border","NineSlice"}) do local r=frame[key]; if r and r.GetAlpha then self:NativeRegion(r,enabled) end end
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do self:MeterTree(child,enabled,depth+1) end end
end
function S:Meter()
    local enabled=FS:IsModuleEnabled("Combat")
    local function skin(f,id)
        if not f then return end
        f.fsFontModule="Combat"; self:Plate(f):SetShown(enabled); self:NativeFonts(f,enabled); self:MeterTree(f,enabled)
        self:MeterHeader(f,enabled)
        if id then FS.Layout:Register(id,f,"Damage Meter") end
    end
    if DamageMeter and DamageMeter.ForEachSessionWindow and DamageMeter.windowDataList then
        DamageMeter:ForEachSessionWindow(function(f) skin(f) end)
    end
    if DamageMeter then skin(DamageMeter,"DamageMeter") end
    for i=1,5 do skin(_G["DamageMeterSessionWindow"..i]) end
    skin(DamageMeterSourceWindow)
end
function S:Refresh()
    if not FS.initialized or not FS.db or InCombatLockdown() then return end
    self:Bars(); self:Units(); self:Minimap(); self:Chat(); self:Meter()
    FS.Layout:AvoidMeterOverlap()
    if FS.NativeWindows then FS.NativeWindows:Refresh() end
    if FS.WindowManager then FS.WindowManager:UpdateExperience() end
end
function S:StructureSignature(kind)
    -- Poll for newly created native windows/rows, not for a reason to rewrite
    -- every existing frame's geometry, fonts and backdrop once per second.
    local values,seen={},{}
    local function visit(f,depth)
        if not f or seen[f] or f.fsSuiteStyle or (f.IsForbidden and f:IsForbidden()) then return end
        seen[f]=true; values[#values+1]=tostring(f); values[#values+1]=tostring(f:IsShown())
        if depth>0 and f.GetChildren then for _,child in ipairs({f:GetChildren()}) do visit(child,depth-1) end end
    end
    if not kind or kind=="native" then for _,definition in ipairs(FS.NativeWindows and FS.NativeWindows.definitions or {}) do visit(_G[definition[1]],3) end end
    if not kind or kind=="chat" then for i=1,NUM_CHAT_WINDOWS or 10 do
        visit(_G["ChatFrame"..i],1); visit(_G["ChatFrame"..i.."Tab"],1); visit(_G["ChatFrame"..i.."EditBox"],1)
    end
    end
    if not kind or kind=="meter" then visit(DamageMeter,3); visit(DamageMeterSourceWindow,3)
    for i=1,5 do visit(_G["DamageMeterSessionWindow"..i],3) end end
    return table.concat(values,"|")
end
function S:Discover()
    if not FS.initialized or not FS.db or InCombatLockdown() then return end
    self.discovery=self.discovery or {}
    for _,kind in ipairs({"native","chat","meter"}) do
        local signature=self:StructureSignature(kind)
        if self.discovery[kind]~=signature then
            if kind=="native" and FS.NativeWindows then FS.NativeWindows:Refresh()
            elseif kind=="chat" then self:Chat()
            elseif kind=="meter" then self:Meter() end
            self.discovery[kind]=self:StructureSignature(kind)
        end
    end
end
local events=CreateFrame("Frame"); S.events=events
for _,event in ipairs({"PLAYER_ENTERING_WORLD","ADDON_LOADED","PLAYER_REGEN_ENABLED","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA"}) do FS:RegisterClientEvent(events,event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_ENTERING_WORLD" then S:Refresh()
    elseif event=="ZONE_CHANGED" or event=="ZONE_CHANGED_NEW_AREA" then if not InCombatLockdown() and FS.db then S:Minimap() end
    else S:Discover() end
end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt; if elapsed<1 then return end; elapsed=0
    if not FS.initialized or not FS.db then return end
    S:UpdateClock(); S:Discover(); FS.Layout:AvoidMeterOverlap()
end)
