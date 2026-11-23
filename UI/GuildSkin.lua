local _,FS=...
local N,H,S=FS.NativeWindows,FS.HUD,FS.Style
local tabs={{"ChatTab","Chat"},{"RosterTab","Guild"},{"GuildBenefitsTab","Equipment"},{"GuildInfoTab","Help"}}
local containers={"CommunitiesList","MemberList","Chat","GuildBenefitsFrame","GuildDetailsFrame","GuildInfoFrame","GuildLogFrame","GuildMemberDetailFrame","EditStreamDialog","NotificationSettingsDialog","RecruitmentDialog"}
N.guildRows=setmetatable({},{__mode="k"})
N.guildPending=setmetatable({},{__mode="k"})

-- Communities owns its pooled rows, display modes and click handlers. Only
-- known decoration is removed; unnamed native icon buttons keep their glyphs.
function N:GuildTree(frame,enabled,depth,decorative,role)
    if not frame or frame.fsSuiteStyle or (frame.IsForbidden and frame:IsForbidden()) then return end
    depth=depth or 0; if depth>14 then return end
    if enabled and not frame:IsShown() then return end
    local kind=frame.GetObjectType and frame:GetObjectType()
    if kind=="PlayerModel" or kind=="DressUpModel" or kind=="ModelScene" then return end
    if frame.GetFont then
        if kind=="ScrollingMessageFrame" then self:Font(frame,enabled) else self:NativeFont(frame,enabled) end
    end
    if kind=="Button" or kind=="CheckButton" or kind=="DropdownButton" then
        if frame.NameFrame and frame.NameFrame.Name then self:GuildRow(frame,enabled)
        elseif role or kind=="DropdownButton" or type(frame.SetupMenu)=="function" or (frame.GetText and frame:GetText()~="") then
            local dropdown=kind=="DropdownButton" or type(frame.SetupMenu)=="function"
            if dropdown then
                self:Dropdown(frame,enabled)
            else self:Control(frame,enabled,role) end
        end
    end
    for _,key in ipairs({"Background","Bg","BG","Border","Portrait","PortraitOverlay","TopFiligree","BottomFiligree","Banner","BannerBackground","BackgroundTile","HeaderBackground","HeaderBG","TopBorder","BottomBorder"}) do
        local art=frame[key]
        if art and art.GetObjectType and art:GetObjectType()=="Texture" then self:Art(art,enabled) end
    end
    for _,region in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do
        if not region.fsSuiteStyle then
            if region.GetFont then self:NativeFont(region,enabled)
            elseif region.GetObjectType and region:GetObjectType()=="Texture" and not self:IsIcon(frame,region) then
                local layer=region.GetDrawLayer and region:GetDrawLayer()
                local art=(region.GetAtlas and region:GetAtlas()) or (region.GetTexture and region:GetTexture()) or ""
                local name=((region.GetName and region:GetName() or "").." "..(type(art)=="string" and art or "")):lower()
                local ornament=name:find("filigree",1,true) or name:find("ornament",1,true) or name:find("communities-background",1,true)
                    or name:find("communities-list-bg",1,true) or name:find("guild-bg",1,true)
                if decorative or ornament or ((kind~="Button" and kind~="CheckButton" and kind~="DropdownButton") and (layer=="BACKGROUND" or layer=="BORDER")) then self:Art(region,enabled) end
            end
        end
    end
    local roles={CloseButton="X",MinimizeButton="-",MaximizeButton="+",ScrollUpButton="^",ScrollDownButton="v"}
    for _,child in ipairs(frame.GetChildren and {frame:GetChildren()} or {}) do
        local glyph; for key,value in pairs(roles) do if child==frame[key] then glyph=value; break end end
        self:GuildTree(child,enabled,depth+1,decorative or child==frame.NineSlice or child==frame.PortraitContainer or child==frame.PortraitOverlay,glyph)
    end
end

function N:QueueGuildRefresh(frame)
    if not FS:IsModuleEnabled("Guild") or not FS.modules.Guild:Data().styleWindow
        or (FS.db.extras and FS.db.extras.nativeWindows==false) then return end
    if self.guildPending[frame] then return end
    self.guildPending[frame]=true
    C_Timer.After(0,function()
        if not self.guildPending[frame] then return end
        self.guildPending[frame]=nil
        if frame:IsShown() and not InCombatLockdown() then self:Refresh(frame) end
    end)
end
function N:GuildModeChanged(frame)
    if not frame:IsShown() or InCombatLockdown() or not FS:IsModuleEnabled("Guild") or not FS.modules.Guild:Data().styleWindow
        or (FS.db.extras and FS.db.extras.nativeWindows==false) then return end
    self.guildPending[frame]=nil
    if FS.WindowManager then FS.WindowManager:StabilizeGuild(frame) end
    self:Refresh(frame)
end

function N:GuildRow(row,enabled)
    local state=self.guildRows[row]
    if not state and enabled then
        state={}; self.guildRows[row]=state
        state.fill=row:CreateTexture(nil,"BACKGROUND")
        state.fill.fsSuiteStyle=true; state.fill.ignoreInLayout=true; state.fill:SetAllPoints()
        state.fill:SetColorTexture(.06,.08,.10,.4)
        state.hover=row:CreateTexture(nil,"HIGHLIGHT")
        state.hover.fsSuiteStyle=true; state.hover.ignoreInLayout=true; state.hover:SetAllPoints()
    end
    if not state then return end
    self.plainControls[row]=enabled and true or nil
    if self.controls[row] then self:Control(row,false) end
    state.fill:SetShown(enabled); state.hover:SetShown(enabled)
    local r,g,b=FS.Themes:Accent(); state.hover:SetColorTexture(r,g,b,.15)
end

function N:Guild(frame,enabled)
    local r,g,b=FS.Themes:Accent()
    local function panel(node)
        if not node or not node.GetFrameLevel or (node.IsForbidden and node:IsForbidden()) then return end
        local plate=S:Plate(node); plate:ClearAllPoints(); plate:SetAllPoints(node)
        plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
        self:Surface(plate,enabled)
        if not node.fsGuildPanelHook then
            node.fsGuildPanelHook=true
            node:HookScript("OnShow",function() N:QueueGuildRefresh(frame) end)
        end
    end
    for _,key in ipairs(containers) do panel(frame[key]) end
    panel(frame.ChatEditBox)
    for i,entry in ipairs(tabs) do
        local tab=frame[entry[1]]
        if tab and not (tab.IsForbidden and tab:IsForbidden()) then
            -- Keep the client's tab chain, spacing and display-mode geometry.
            self:Geometry(tab,false,function() end)
            self:Control(tab,enabled)
            if not tab.fsGuildIcon then
                tab.fsGuildIcon=tab:CreateTexture(nil,"OVERLAY")
                tab.fsGuildIcon.fsSuiteStyle=true; tab.fsGuildIcon.ignoreInLayout=true
                tab.fsGuildIcon:SetPoint("CENTER"); tab.fsGuildIcon:SetSize(26,26)
            end
            FS:SetMenuIcon(tab.fsGuildIcon,entry[2]); tab.fsGuildIcon:SetShown(enabled)
            for _,key in ipairs({"Icon","icon","IconTexture"}) do self:Art(tab[key],enabled) end
        end
    end
    if frame.GuildMemberDetailFrame and enabled then frame.GuildMemberDetailFrame:SetClampedToScreen(true) end
    if not frame.fsGuildStyleHooks then
        frame.fsGuildStyleHooks=true
        if type(frame.SetDisplayMode)=="function" then hooksecurefunc(frame,"SetDisplayMode",function() N:GuildModeChanged(frame) end) end
        if type(frame.UpdateCommunitiesList)=="function" then hooksecurefunc(frame,"UpdateCommunitiesList",function() N:QueueGuildRefresh(frame) end) end
    end
end

local events=CreateFrame("Frame"); N.guildEvents=events
for _,event in ipairs({"GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE"}) do FS:RegisterClientEvent(events,event) end
events:SetScript("OnEvent",function()
    if not FS.initialized or InCombatLockdown() or not FS:IsModuleEnabled("Guild") then return end
    for _,name in ipairs({"CommunitiesFrame","GuildFrame"}) do
        local frame=_G[name]
        if frame and frame:IsShown() then N:QueueGuildRefresh(frame) end
    end
end)
