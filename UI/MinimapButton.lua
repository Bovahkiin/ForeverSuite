local _, FS = ...
function FS:UpdateMinimapButton()
    local button = self.minimapButton
    if not button then return end
    local collector=self.modules.MinimapButtons
    if collector and collector.collected[button] then button:SetShown(self.db.minimap.show); return end
    local angle = math.rad(self.db.minimap.angle)
    local radius = math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2 + 8
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    if self.db.minimap.show then button:Show() else button:Hide() end
end

function FS:CreateMinimapButton()
    if self.minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "ForeverSuiteMinimapButton", Minimap)
    self.minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:SetNormalTexture(FS.icon)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then FS.modules.Bags:ToggleWindow() else FS:ToggleConfig() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ForeverSuite " .. FS.version)
        GameTooltip:AddLine(FS.L.TOOLTIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            if not cx or not cy then return end
            local scale = Minimap:GetEffectiveScale()
            FS.db.minimap.angle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
            FS:UpdateMinimapButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil); GameTooltip:Hide() end)
    self:UpdateMinimapButton()
end
