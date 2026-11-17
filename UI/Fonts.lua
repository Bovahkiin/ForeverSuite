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
