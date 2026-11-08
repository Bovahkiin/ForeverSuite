local _,FS=...
local T={frames=setmetatable({},{__mode="k"}),fonts=setmetatable({},{__mode="k"})}; FS.Themes=T
T.names={"Celestial Forge","Titanium Signal","Obsidian Arcana","Verdant Relic","Glacial Prism","Royal Aether","Runestone","Astral Glass","Ember Bastion","Cartographer"}
FS.defaults.appearance={theme="Legacy"}
local path="Interface\\AddOns\\ForeverSuite\\Assets\\Themes\\"
function T:Index(name)
    for i,value in ipairs(self.names) do if value==name then return i end end
end
function T:Current() return FS.db and FS.db.appearance and self:Index(FS.db.appearance.theme) end
function T:Accent()
    local colors={{.12,.8,.94},{.25,.8,1},{.72,.42,1},{.4,.9,.5},{.48,.9,1},{.8,.58,1},{.95,.7,.32},{.4,.82,1},{1,.48,.18},{.35,.24,.12}}
    return unpack(colors[self:Current() or 1])
end
function T:Asset(index,kind) return path..string.format("%02d",index).."-"..kind..".tga" end
function T:Normalize()
    FS:ApplyDefaults(FS.db.appearance,FS.defaults.appearance)
    if FS.db.appearance.theme~="Legacy" and not self:Index(FS.db.appearance.theme) then FS.db.appearance.theme="Legacy" end
end
function T:Size(frame,state)
    local width,height=frame:GetWidth(),frame:GetHeight()
    if not FS.HUD:Safe(width) or not FS.HUD:Safe(height) then return end
    local corner=math.max(3,math.min(state.kind=="Button" and 10 or 18,width/3,height/3))
    if state.corner==corner then return end; state.corner=corner
    for _,i in ipairs({1,3,7,9}) do state.parts[i]:SetSize(corner,corner) end
    for _,i in ipairs({2,8}) do state.parts[i]:SetHeight(corner) end
    for _,i in ipairs({4,6}) do state.parts[i]:SetWidth(corner) end
end
function T:Register(frame,kind,previewIndex)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame.fsThemeBorderOnly then return end
    local state=self.frames[frame]
    if not state then state={kind=kind or "Panel"}; self.frames[frame]=state end
    if kind then state.kind=kind end
    local index=previewIndex or self:Current()
    if index and not state.parts then
        state.parts={}
        -- Fixed corner geometry and stretched middle strips keep the rendered
        -- Blender bevels intact at every window aspect ratio. No native anchors.
        for row=0,2 do for col=0,2 do
            local p=frame:CreateTexture(nil,"BACKGROUND",nil,1); p.ignoreInLayout=true; p.fsSuiteStyle=true
            local uv={0,.18,.82,1}; p:SetTexCoord(uv[col+1],uv[col+2],uv[row+1],uv[row+2]); state.parts[#state.parts+1]=p
        end end
        local p=state.parts
        p[1]:SetPoint("TOPLEFT"); p[3]:SetPoint("TOPRIGHT"); p[7]:SetPoint("BOTTOMLEFT"); p[9]:SetPoint("BOTTOMRIGHT")
        p[2]:SetPoint("TOPLEFT",p[1],"TOPRIGHT"); p[2]:SetPoint("TOPRIGHT",p[3],"TOPLEFT")
        p[8]:SetPoint("BOTTOMLEFT",p[7],"BOTTOMRIGHT"); p[8]:SetPoint("BOTTOMRIGHT",p[9],"BOTTOMLEFT")
        p[4]:SetPoint("TOPLEFT",p[1],"BOTTOMLEFT"); p[4]:SetPoint("BOTTOMLEFT",p[7],"TOPLEFT")
        p[6]:SetPoint("TOPRIGHT",p[3],"BOTTOMRIGHT"); p[6]:SetPoint("BOTTOMRIGHT",p[9],"TOPRIGHT")
        p[5]:SetPoint("TOPLEFT",p[1],"BOTTOMRIGHT"); p[5]:SetPoint("BOTTOMRIGHT",p[9],"TOPLEFT")
        frame:HookScript("OnSizeChanged",function() T:Size(frame,state) end)
    end
    if state.parts then
        self:Size(frame,state)
        for _,p in ipairs(state.parts) do
            p:SetShown(index~=nil)
            if index then p:SetTexture(self:Asset(index,state.kind)) end
        end
    end
    if state.kind=="Button" and frame.GetNormalTexture then
        local normal=frame:GetNormalTexture()
        if normal then
            if state.normalAlpha==nil then state.normalAlpha=normal:GetAlpha() end
            normal:SetAlpha(index and 0 or state.normalAlpha)
        end
    end
end
function T:ReleaseFont(region)
    local state=self.fonts[region]
    if state then region:SetTextColor(unpack(state)); self.fonts[region]=nil end
end
function T:Font(region)
    if not region or not region.SetTextColor then return end
    local state=self.fonts[region]
    if not state then
        if self:Current()~=10 then return end
        state=region.GetTextColor and {region:GetTextColor()} or {.9,.94,1,1}
        for i=1,3 do if not FS.HUD:Safe(state[i]) or type(state[i])~="number" then return end end
        self.fonts[region]=state
    end
    if self:Current()==10 then region:SetTextColor(state[1]*.18,state[2]*.18,state[3]*.18,state[4] or 1)
    else region:SetTextColor(unpack(state)); self.fonts[region]=nil end
end
function T:Refresh()
    if not FS.db or InCombatLockdown() then self.pending=true; return false end
    self.pending=false; self:Normalize()
    for frame,state in pairs(self.frames) do
        self:Register(frame,state.kind)
        for _,region in ipairs({frame:GetRegions()}) do if region.GetFont then self:Font(region) end end
    end
    for region in pairs(self.fonts) do self:Font(region) end
    if FS.modules.ActionBars.ApplyAppearance then FS.modules.ActionBars:ApplyAppearance() end
    if FS.Style then FS.Style:Refresh() end
    return true
end
function T:Set(name)
    if name~="Legacy" and not self:Index(name) then return false end
    if InCombatLockdown() or FS.modules.Vendor.busy then return false end
    FS.db.appearance.theme=name; return self:Refresh()
end
local events=CreateFrame("Frame"); T.events=events; FS:RegisterClientEvent(events,"PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function() if T.pending then T:Refresh() end end)
