local _, FS = ...
local H = {}; FS.HUD = H
H.texture = "Interface\\Buttons\\WHITE8X8"
-- Native anchors can make dimensions secret. Anchored textures need no Lua
-- width/height arithmetic, unlike BackdropTemplate's tiled edge calculation.
function H:FlatSkin(f)
    if f.fsFlatSkin then return end
    f.fsThemeBorderOnly=true
    if FS.Themes and FS.Themes.frames[f] then
        for _,part in ipairs(FS.Themes.frames[f].parts or {}) do part:Hide() end
        FS.Themes.frames[f]=nil
    end
    f:SetBackdrop(nil)
    local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg.fsSuiteStyle=true; bg.ignoreInLayout=true
    local edges={}
    for i=1,4 do
        local edge=f:CreateTexture(nil,"BORDER"); edge.fsSuiteStyle=true; edge.ignoreInLayout=true; edges[i]=edge
        if i<=2 then
            local side=i==1 and "TOP" or "BOTTOM"
            edge:SetPoint(side.."LEFT"); edge:SetPoint(side.."RIGHT"); edge:SetHeight(1)
        else
            local side=i==3 and "LEFT" or "RIGHT"
            edge:SetPoint("TOP"..side); edge:SetPoint("BOTTOM"..side); edge:SetWidth(1)
        end
    end
    f.fsFlatSkin={background=bg,edges=edges}
    f.SetBackdropColor=function(_,...) bg:SetColorTexture(...) end
    f.SetBackdropBorderColor=function(_,...) for _,edge in ipairs(edges) do edge:SetColorTexture(...) end end
end
function H:Skin(f,secretAnchors)
    if secretAnchors then self:FlatSkin(f) end
    if not f.fsHUDBackdrop then
        if not f.fsFlatSkin then f:SetBackdrop({ bgFile = self.texture, edgeFile = self.texture, edgeSize = 1 }) end
        f.fsHUDBackdrop=true
    end
    f:SetBackdropColor(0.035, 0.045, 0.065, 0.95); f:SetBackdropBorderColor(0.12, 0.72, 0.86, 0.85)
    if FS.Themes then FS.Themes:Register(f) end
end
function H:Label(f, value, x, y, width)
    local t = FS.Widgets:Label(f, "ForeverSuiteFontSmall")
    t:SetPoint("TOPLEFT", x, y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetText(value); return t
end
function H:Button(f, value, x, y, width, callback)
    local b = CreateFrame("Button", nil, f, "BackdropTemplate"); self:Skin(b)
    b:SetSize(width, 30); b:SetPoint("TOPLEFT", x, y)
    if FS.Themes then FS.Themes:Register(b,"Button") end
    local t = b:CreateFontString(nil, "OVERLAY", "ForeverSuiteFontSmall"); t:SetPoint("CENTER"); t:SetWidth(width-12); t:SetHeight(24); b:SetFontString(t)
    b.fsLabel=t; FS:ApplyFont(t); if FS.Themes then FS.Themes:Font(t) end; b:SetText(value); b:SetScript("OnClick", function(...) return FS:SettingAction(callback,...) end); return b
end
-- Measure suite-owned text without changing native or secure frame geometry.
function H:TextHeight(t,width,maximum)
    local _,size=t:GetFont(); size=size or 14
    local text=tostring(t:GetText() or "")
    local measured=t.GetUnboundedStringWidth and t:GetUnboundedStringWidth() or #text*size*.65
    local lines=0
    local _,breaks=text:gsub("\n","")
    if breaks>0 then
        for line in (text.."\n"):gmatch("(.-)\n") do lines=lines+math.max(1,math.ceil(#line*size*.65/math.max(1,width))) end
    else lines=math.max(1,math.ceil(measured/math.max(1,width))) end
    lines=math.min(maximum or 2,lines)
    t:SetWidth(width); if t.SetMaxLines then t:SetMaxLines(maximum or 2) end; t:SetHeight(lines*(size+3))
    return t:GetHeight()
end
function H:FitButton(b,maximum,minimum)
    local t=b.fsLabel or (b.GetFontString and b:GetFontString())
    if not t then return b:GetHeight() end
    local height=self:TextHeight(t,b:GetWidth()-12,maximum)
    b:SetHeight(math.max(minimum or 30,height+10)); return b:GetHeight()
end
function H:Safe(value) return not (issecretvalue and issecretvalue(value)) end
function H:Color(unit)
    local player = UnitIsPlayer(unit)
    if self:Safe(player) and player then
        local _, class = UnitClass(unit)
        if self:Safe(class) then
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then return c.r, c.g, c.b end
        end
    end
    local enemy = UnitCanAttack("player", unit)
    if self:Safe(enemy) and enemy then return 0.85, 0.12, 0.16 end
    local reaction = UnitReaction and UnitReaction(unit, "player")
    if self:Safe(reaction) and type(reaction) == "number" and reaction <= 4 then return 0.95, 0.68, 0.24 end
    return 0.18, 0.75, 0.45
end
function H:Number(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(math.floor(n))
end
function H:Normalize(db)
    local V = FS.modules.Vendor
    db.scale = V:ValidNumber(db.scale, 0.6, 1.4) or 1
    db.x = V:ValidNumber(db.x, -10000, 10000) or 0
    db.y = V:ValidNumber(db.y, 0, 2000) or 200
end
function H:Settings(module, host, title, explanation)
    local f = CreateFrame("Frame", nil, host, "BackdropTemplate"); self:Skin(f)
    f:SetSize(892, 420); f:SetPoint("TOPLEFT", 24, FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel() + 30); f:EnableMouse(true)
    module.settings = f
    self:Button(f, FS.Text.back, 20, -12, 220, function() f:Hide() end)
    self:Label(f, title, 260, -20, 600); self:Label(f, explanation, 20, -65, 850)
    f.scale = self:Button(f, "", 20, -110, 400, function()
        local db = FS.db[module.key]; db.scale = db.scale >= 1.2 and 0.8 or math.floor((db.scale + 0.1) * 10 + 0.5) / 10
        module:SettingsChanged()
    end)
    f.move = self:Button(f, "Move frames", 450, -110, 400, function()
        if InCombatLockdown() then FS:Print("Leave combat to move frames."); return end
        host:Hide(); FS.Layout:Start()
    end)
    self:Label(f, "Drag the cyan handles, then click Done. Moving is available outside combat.", 20, -155, 850)
    f.reset = self:Button(f, "Reset position and size", 20, -205, 400, function()
        local db = FS.db[module.key]; db.x, db.y, db.scale = 0, 200, 1; module:SettingsChanged()
    end)
    f.message = self:Label(f, "", 20, -345, 850)
    f:Hide(); return f
end
function H:RefreshSettings(module)
    local f = module.settings; if not f then return end
    f.scale:SetText("Size: " .. math.floor(FS.db[module.key].scale * 100 + 0.5) .. "% (click to change)")
    f.message:SetText(module.pending and "Your changes will apply when combat ends." or "Changes are saved automatically.")
end
function H:Mover(module, target, title, save)
    local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"); self:Skin(m)
    m:SetSize(250, 50); m:SetFrameStrata("DIALOG"); m:SetMovable(true); m:EnableMouse(true); m:RegisterForDrag("LeftButton"); m:SetClampedToScreen(true)
    self:Label(m, title, 8, -8, 155)
    self:Button(m, "Done", 169, -10, 72, function() module:ToggleMovers(false); FS:ConfigureModule(module.name) end)
    m:SetScript("OnDragStart", function(f) if not InCombatLockdown() then f:StartMoving() end end)
    m:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing(); if InCombatLockdown() then return end
        local x, y = f:GetCenter(); local ux = UIParent:GetCenter()
        local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y and ux then save(x * ratio - ux, y * ratio); module:SettingsChanged() end
    end)
    m:Hide(); return m
end
function H:SavePoints(frame)
    local points = {}; for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end; return points
end
function H:RestorePoints(frame, points)
    frame:ClearAllPoints(); for _, p in ipairs(points) do frame:SetPoint(unpack(p)) end
end



-- All Control Center settings share one color and form grammar. Existing
-- controls retain their scripts, checked state and edit-box contents.
function FS:FitSettingsViewport(f)
    if not f or InCombatLockdown() then return end
    -- Settings are a centered modal viewport, independent of the dashboard's
    -- position and inherited mover scale. Keep all edges inside UIParent.
    local host=f:GetParent()
    local uiScale=UIParent:GetEffectiveScale()
    local parentRatio=(host and host:GetEffectiveScale() or uiScale)/uiScale
    local width,height=f:GetWidth(),f:GetHeight()
    local desired=math.min(1,math.max(1,UIParent:GetWidth()-48)/math.max(1,width),math.max(1,UIParent:GetHeight()-48)/math.max(1,height))
    f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",0,0)
    f:SetScale(desired/math.max(.001,parentRatio))
    f:SetClampedToScreen(true); f:SetFrameStrata("DIALOG")
    f.fsViewportScale=desired
end
function FS:ThemeSettings(f,name)
    if not f or InCombatLockdown() then return end
    local H=self.HUD; local color=self.moduleCardColors[name] or {.12,.72,.86}
    f.fsSettingsName=name
    if f.fsFontModule~=name then f.fsFontModule=name; self:FontTree(f) end
    f:SetBackdropColor(.018,.027,.038,1); f:SetBackdropBorderColor(color[1],color[2],color[3],1)
    local function theme(b)
        if not b.SetBackdropBorderColor then return end
        b:SetBackdropBorderColor(color[1],color[2],color[3],1)
        if not b.fsSettingsHover then
            b.fsSettingsHover=true
            b:HookScript("PostClick",function() if f:IsShown() then FS:ThemeSettings(f,f.fsSettingsName) end end)
            b:HookScript("OnEnter",function(control) local c=FS.moduleCardColors[f.fsSettingsName] or color; control:SetBackdropBorderColor(c[1],c[2],c[3],1) end)
            b:HookScript("OnLeave",function(control) local c=FS.moduleCardColors[f.fsSettingsName] or color; control:SetBackdropBorderColor(c[1],c[2],c[3],1) end)
        end
    end
    for _,child in ipairs({f:GetChildren()}) do theme(child) end
    if f.optionPages or f.open then
        if f.LayoutText then f:LayoutText() end
        self:FitSettingsViewport(f)
        return
    end
    local function point(r) local p={r:GetPoint()}; return tonumber(p[#p-1]) or 0,-(tonumber(p[#p]) or 0) end
    local function at(r,x,y) r:ClearAllPoints(); r:SetPoint("TOPLEFT",x,-y) end
    local function font(r) return r.fsLabel or r.caption or (r.GetFontString and r:GetFontString()) end
    if not f.fsForm then
        local form={items={},labels={},footer={},heading=f.title or f.heading or f.current,description=f.description}; f.fsForm=form
        for _,r in ipairs({f:GetRegions()}) do if r.GetFont and r.GetText then local x,y=point(r); form.labels[#form.labels+1]={region=r,x=x,y=y} end end
        for _,b in ipairs({f:GetChildren()}) do
            local kind=b.GetObjectType and b:GetObjectType(); local x,y=point(b)
            if kind=="Button" or kind=="CheckButton" or kind=="EditBox" then
                local label=font(b); local value=label and tostring(label:GetText() or "") or ""
                if value:find("Back to",1,true) then form.back=b
                else form.items[#form.items+1]={control=b,x=x,y=y,label=label,edit=kind=="EditBox"} end
            end
        end
        table.sort(form.items,function(a,b) if a.y==b.y then return a.x<b.x else return a.y<b.y end end)
        for _,entry in ipairs(form.labels) do
            local r=entry.region; local value=tostring(r:GetText() or "")
            if r==form.heading or r==form.description then
                -- Explicit header references are authoritative.
            elseif entry.y<=30 and entry.x>=240 and not form.heading then form.heading=r
            elseif entry.y>=45 and entry.y<=75 and r:GetWidth()>=600 and not form.description and r~=f.highlightHeading and r~=f.openingHeading then form.description=r
            else
                local best,score
                for _,item in ipairs(form.items) do
                    local dy=entry.y-item.y; local distance=math.abs(dy)
                    if math.abs(entry.x-item.x)<25 and ((item.edit and dy>=-35 and dy<=0) or (not item.edit and dy>=25 and dy<=48)) and r:GetWidth()<600 then
                        if not score or distance<score then best,score=item,distance end
                    end
                end
                if best then best.explanation=r
                elseif r:GetWidth()>=600 and value~="Junk highlights" and value~="Bag opening and display" then form.footer[#form.footer+1]=r end
            end
        end
        -- Explicit relationships take precedence where basic and advanced
        -- controls originally occupied the same coordinates.
        for _,item in ipairs(form.items) do
            for key,box in pairs(f.fields or {}) do if item.control==box then item.explanation=f.fieldLabels and f.fieldLabels[key] end end
            if item.control==f.intensity then item.explanation=f.intensityLabel end
            for _,entry in ipairs(f.toggles or {}) do if item.control==entry.control then item.explanation=entry.explanation end end
        end
        for _,item in ipairs(form.items) do
            local explicit=false
            for _,entry in ipairs(f.toggles or {}) do if item.control==entry.control then explicit=true end end
            if item.control.help and not explicit then
                -- Hidden basic/advanced labels may share coordinates; do not
                -- infer another control's explanation over its explicit help.
                item.explanation=nil; item.help=H:Label(f,item.control.help,0,0,410)
            end
        end
    end
    local form=f.fsForm; local y=12
    local header=30
    if form.back then form.back:SetWidth(220); at(form.back,20,12); header=H:FitButton(form.back,2) end
    if form.heading then at(form.heading,260,20); header=math.max(header,H:TextHeight(form.heading,590,2)+8) end
    y=y+header+20
    if form.description then form.description:Show(); at(form.description,20,y); y=y+H:TextHeight(form.description,850,3)+22 end
    local items={}
    if f.toggles then
        local byControl={}; for _,item in ipairs(form.items) do byControl[item.control]=item end
        local function add(control) local item=control and byControl[control]; if item and control:IsShown() then items[#items+1]=item end end
        add(f.mode); add(f.source); add(f.color); add(f.intensity)
        for _,entry in ipairs(f.toggles) do add(entry.control) end
        for _,key in ipairs({"repairLimit","restockBudget","moneyReserve"}) do add(f.fields and f.fields[key]) end
        add(f.more); add(f.save)
    else for _,item in ipairs(form.items) do if item.control:IsShown() then items[#items+1]=item end end end
    -- Hide unused standalone explanations, including basic/advanced groups.
    local used={}; for _,item in ipairs(items) do if item.explanation then used[item.explanation]=true end end
    for _,entry in ipairs(form.labels) do local r=entry.region
        if r~=form.heading and r~=form.description then local footer=false; for _,v in ipairs(form.footer) do if v==r then footer=true end end; if not footer then r:SetShown(used[r] or false) end end
    end
    for _,item in ipairs(form.items) do if item.help then item.help:SetShown(item.control:IsShown()) end end
    for row=1,math.ceil(#items/2) do
        local rowHeight=0
        for col=1,2 do local item=items[(row-1)*2+col]; if item then
            local b=item.control; local x=20+(col-1)*430; b:SetWidth(410)
            local explanation=item.explanation or item.help
            local height=0
            if item.edit then
                if explanation then at(explanation,x,y); height=H:TextHeight(explanation,410,3)+8 end
                at(b,x,y+height); local _,size=b:GetFont(); b:SetHeight(math.max(30,(size or 14)+12)); height=height+b:GetHeight()
            else
                at(b,x,y); height=H:FitButton(b,3)
                if explanation then at(explanation,x,y+height+8); height=height+8+H:TextHeight(explanation,410,3) end
            end
            rowHeight=math.max(rowHeight,height)
        end end
        y=y+rowHeight+20
    end
    for _,r in ipairs(form.footer) do if r:IsShown() then at(r,20,y); y=y+H:TextHeight(r,850,5)+16 end end
    f:SetSize(892,math.max(420,y+12))
    self:FitSettingsViewport(f)
end
function FS:SettingsSignature(f)
    local host=f:GetParent()
    local values={UIParent:GetWidth(),UIParent:GetHeight(),host and host:GetEffectiveScale() or 1,UIParent:GetEffectiveScale(),f.fsSettingsName or ""}
    local function text(r)
        if r.GetText then values[#values+1]=tostring(r:GetText() or ""); values[#values+1]=tostring(r:IsShown()) end
        if r.GetFont then local path,size,flags=r:GetFont(); values[#values+1]=tostring(path)..tostring(size)..tostring(flags) end
    end
    for _,r in ipairs({f:GetRegions()}) do text(r) end
    for _,b in ipairs({f:GetChildren()}) do text(b); values[#values+1]=tostring(b:IsShown()); if b.fsLabel then text(b.fsLabel) end end
    return table.concat(values,"|")
end
function FS:BindSettings(f,name)
    if not f then return end
    -- Each settings page is an independent screen with an explicit return path.
    if f:GetParent() ~= UIParent then f:SetParent(UIParent) end
    f.fsSettingsName=name
    if not f.fsSettingsBound then
        f.fsSettingsBound=true
        local elapsed=0
        f:HookScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt; if elapsed<.15 then return end; elapsed=0
            if f:IsShown() and not InCombatLockdown() and f.fsSettingsSignature~=FS:SettingsSignature(f) then
                FS:ThemeSettings(f,f.fsSettingsName); f.fsSettingsSignature=FS:SettingsSignature(f)
            end
        end)
    end
    self:ThemeSettings(f,name)
    local back = f.back or (f.fsForm and f.fsForm.back)
    if back then
        back:SetText("Back to Control Center")
        back:SetScript("OnClick",function() f:Hide(); FS:ShowConfig() end)
    end
    self:CloseOtherWindows(f)
    self.settingsScreen=f
    f:Show()
    f.fsSettingsSignature=self:SettingsSignature(f)
    GameTooltip:Hide()
end
