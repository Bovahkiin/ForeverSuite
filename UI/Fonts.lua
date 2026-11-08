local _, FS = ...
FS.font = "Fonts\\ARIALN.TTF"
for name,size in pairs({ ForeverSuiteFontSmall=12, ForeverSuiteFontNormal=14, ForeverSuiteFontLarge=20, ForeverSuiteFontNumber=12 }) do
    local font=CreateFont(name); font:SetFont(FS.font,size,""); font:SetTextColor(0.9,0.94,1,1)
end
function FS:ApplyFont(region, size, flags)
    if not region or not region.SetFont then return end
    if self.StyleFont then return self:StyleFont(region,size,flags) end
    local _, oldSize, oldFlags
    if region.GetFont then _, oldSize, oldFlags = region:GetFont() end
    region:SetFont(self.font, size or oldSize or 12, flags or oldFlags or "")
end
function FS:FontTree(frame, depth)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    depth = depth or 0; if depth > 12 then return end
    if frame.GetRegions then for _, region in ipairs({ frame:GetRegions() }) do self:ApplyFont(region) end end
    if frame.GetFontString then self:ApplyFont(frame:GetFontString()) end
    if frame.SetFont and frame.GetFont then self:ApplyFont(frame) end
    if frame.GetChildren then for _, child in ipairs({ frame:GetChildren() }) do self:FontTree(child, depth + 1) end end
end
function FS:ClickEffect(button)
    local flash = button:CreateTexture(nil, "OVERLAY"); flash.ignoreInLayout=true; flash.fsSuiteStyle=true; flash:SetAllPoints(); flash:SetColorTexture(0.95, 0.68, 0.24, 1); flash:Hide()
    local group = flash:CreateAnimationGroup(); local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.3); alpha:SetToAlpha(0); alpha:SetDuration(0.24)
    group:SetScript("OnFinished", function() flash:Hide() end)
    button:HookScript("PostClick", function() group:Stop(); flash:Show(); group:Play() end)
    return group
end
FS.menuAtlas = "Interface\\AddOns\\ForeverSuite\\Assets\\Menu\\FantasyAtlas.tga"
FS.menuIndices = { Character=0, Professions=1, Spells=2, Talents=3, Achievements=4, Quests=5, Guild=6, Social=7, Groups=8, PVP=9, Collections=10, Guide=11, Map=12, Store=13, Menu=14, Help=15, Legacy=16, Housing=17, Reputation=18, Skills=19, Currency=20, Statistics=21, Enemy=22, Equipment=23, Friendly=24 }
function FS:SetMenuIcon(texture, name)
    local index = self.menuIndices[name] or 0; local x,y = index % 5, math.floor(index / 5)
    texture:SetTexture(self.menuAtlas); texture:SetTexCoord((x+0.015)/5,(x+0.985)/5,(y+0.015)/5,(y+0.985)/5)
end
