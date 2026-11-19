local _,FS=...
local N,H,S=FS.NativeWindows,FS.HUD,FS.Style
local tabs={{"ChatTab","Chat"},{"RosterTab","Guild"},{"GuildBenefitsTab","Equipment"},{"GuildInfoTab","Help"}}
local containers={"CommunitiesList","MemberList","Chat","GuildBenefitsFrame","GuildDetailsFrame","GuildInfoFrame","GuildLogFrame"}
local decorationKeys={"TopFiligree","BottomFiligree","Banner","BannerBackground","BackgroundTile","HeaderBackground","HeaderBG","TopBorder","BottomBorder"}
N.guildRows=setmetatable({},{__mode="k"})
N.guildPending=setmetatable({},{__mode="k"})

function N:QueueGuildRefresh(frame)
    if self.guildPending[frame] then return end
    self.guildPending[frame]=true
    C_Timer.After(0,function()
        self.guildPending[frame]=nil
        if frame:IsShown() and not InCombatLockdown() then self:Refresh(frame) end
    end)
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
        if FS.Themes:Current()==10 then plate:SetBackdropColor(.8,.71,.54,.97)
        else plate:SetBackdropColor(.025,.035,.048,.96) end
        plate:SetBackdropBorderColor(r*.5,g*.5,b*.5,.65)
    end
    local function visit(node,depth)
        if not node or depth>10 or node.fsSuiteStyle or (node.IsForbidden and node:IsForbidden()) then return end
        local kind=node.GetObjectType and node:GetObjectType()
        if kind=="PlayerModel" or kind=="DressUpModel" or kind=="ModelScene" then return end
        if kind=="ScrollingMessageFrame" then self:Font(node,enabled) end
        if (kind=="Button" or kind=="CheckButton") and node.NameFrame and node.NameFrame.Name then self:GuildRow(node,enabled) end
        for _,key in ipairs(decorationKeys) do
            local texture=node[key]
            if texture and texture.GetObjectType and texture:GetObjectType()=="Texture" then self:Art(texture,enabled) end
        end
        for _,texture in ipairs(node.GetRegions and {node:GetRegions()} or {}) do
            if texture.GetObjectType and texture:GetObjectType()=="Texture" and not texture.fsSuiteStyle and not self:IsIcon(node,texture) then
                local art=(texture.GetAtlas and texture:GetAtlas()) or (texture.GetTexture and texture:GetTexture()) or ""
                local name=(texture.GetName and texture:GetName() or "").." "..(type(art)=="string" and art or "")
                name=name:lower()
                if name:find("filigree",1,true) or name:find("ornament",1,true) or name:find("communities-background",1,true)
                    or name:find("communities-list-bg",1,true) or name:find("guild-bg",1,true) then self:Art(texture,enabled) end
            end
        end
        for _,child in ipairs(node.GetChildren and {node:GetChildren()} or {}) do visit(child,depth+1) end
    end
    visit(frame,0)
    for _,key in ipairs(containers) do panel(frame[key]) end
    panel(frame.ChatEditBox)
    for i,entry in ipairs(tabs) do
        local tab=frame[entry[1]]
        if tab and not (tab.IsForbidden and tab:IsForbidden()) then
            self:Geometry(tab,enabled,function(button)
                button:ClearAllPoints(); button:SetPoint("TOPLEFT",frame,"TOPRIGHT",6,-40-(i-1)*42); button:SetSize(34,34)
            end)
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
    if not frame.fsGuildStyleHooks then
        frame.fsGuildStyleHooks=true
        for _,method in ipairs({"SetDisplayMode","UpdateCommunitiesList"}) do
            if type(frame[method])=="function" then hooksecurefunc(frame,method,function() N:QueueGuildRefresh(frame) end) end
        end
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
