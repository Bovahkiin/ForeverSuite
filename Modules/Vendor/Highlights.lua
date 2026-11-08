local _, FS = ...
local V = FS.modules.Vendor
local colors = { green = { 0.2, 1, 0.35 }, gold = { 1, 0.8, 0.15 }, cyan = { 0.1, 0.85, 1 } }

function V:CreateGlow(button)
    if button.fsVendorGlow then return button.fsVendorGlow end
    if InCombatLockdown() then return nil end
    local glow = CreateFrame("Frame", nil, button)
    button.fsVendorGlow = glow
    glow:SetPoint("TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", 2, -2)
    glow:SetFrameLevel(button:GetFrameLevel() + 4)
    glow:EnableMouse(false)
    glow.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = glow:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 1, 1, 1)
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(2)
            edge:SetPoint(side .. "LEFT", glow, side .. "LEFT")
            edge:SetPoint(side .. "RIGHT", glow, side .. "RIGHT")
        else
            edge:SetWidth(2)
            edge:SetPoint("TOP" .. side, glow, "TOP" .. side)
            edge:SetPoint("BOTTOM" .. side, glow, "BOTTOM" .. side)
        end
        glow.edges[#glow.edges + 1] = edge
    end
    glow.count = glow:CreateFontString(nil, "OVERLAY", "ForeverSuiteFontSmall")
    glow.count.fsFontModule="Vendor"; FS:ApplyFont(glow.count)
    glow.count:SetPoint("TOP", glow, "TOP", 0, -2)
    glow.anim = glow:CreateAnimationGroup()
    glow.anim:SetLooping("BOUNCE")
    local alpha = glow.anim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.35)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.85)
    glow:SetScript("OnHide", function(self) self.anim:Stop() end)
    glow:Hide()
    return glow
end

function V:ApplyGlow(button, item)
    local db = self:Settings()
    local show = db.enabled and db.glow.enabled and item and item.sellCount and item.sellCount > 0
    local glow = button.fsVendorGlow
    if not show then if glow then glow:Hide() end; return end
    glow = glow or self:CreateGlow(button)
    if not glow then return end
    local partial = item.sellCount < item.count
    local color = partial and { 1, 0.6, 0.1 } or colors[db.glow.color]
    for _, edge in ipairs(glow.edges) do edge:SetVertexColor(color[1], color[2], color[3], db.glow.intensity) end
    glow.count:SetText(partial and ("x" .. item.sellCount) or "")
    glow.count:SetTextColor(color[1], color[2], color[3])
    glow:Show()
    if db.glow.pulse then if not glow.anim:IsPlaying() then glow.anim:Play() end
    else glow.anim:Stop(); glow:SetAlpha(1) end
end

function V:TrackBagButton(button)
    if not button or not button.GetBagID or not button.GetID then return end
    self.trackedButtons[button] = true
    if not button.fsVendorHooked and not InCombatLockdown() then
        button.fsVendorHooked = true
        button:HookScript("OnHide", function(self) if self.fsVendorGlow then self.fsVendorGlow:Hide() end end)
        button:HookScript("OnEnter", function(self)
            if not V:Settings().enabled or not V.plan then return end
            local bag, slot = self:GetBagID(), self:GetID()
            if V:IsSecret(bag) or V:IsSecret(slot) or type(bag) ~= "number" or type(slot) ~= "number" then return end
            local item = V.plan.bySlot[bag .. ":" .. slot]
            if item and GameTooltip:IsShown() then
                GameTooltip:AddLine("ForeverSuite: " .. item.reason, 0.3, 1, 0.7, true)
                if item.sellCount > 0 and item.sellCount < item.count then
                    GameTooltip:AddLine("Partial stack: use ForeverSuite Sell to preserve reserved stock.", 1, 0.65, 0.15, true)
                end
                GameTooltip:Show()
            end
        end)
    end
end

function V:InstallBagHooks()
    if not self.mixinHooked and ContainerFrameItemButtonMixin and hooksecurefunc then
        self.mixinHooked = true
        if ContainerFrameItemButtonMixin.Initialize then
            hooksecurefunc(ContainerFrameItemButtonMixin, "Initialize", function(button) V:TrackBagButton(button); V:QueueRefresh() end)
        end
        if ContainerFrameItemButtonMixin.Update then
            hooksecurefunc(ContainerFrameItemButtonMixin, "Update", function(button) V:TrackBagButton(button); V:QueueRefresh() end)
        end
    end
    if not self.toggleHooked and ToggleAllBags and hooksecurefunc then
        self.toggleHooked = true
        hooksecurefunc("ToggleAllBags", function() V:QueueRefresh() end)
    end
end

function V:RefreshHighlights()
    local function collect(frame)
        if not frame then return end
        if frame.Items then
            for _, button in pairs(frame.Items) do self:TrackBagButton(button) end
        end
        if frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do self:TrackBagButton(button) end
        end
    end
    collect(ContainerFrameCombinedBags)
    for index = 1, (NUM_CONTAINER_FRAMES or 13) do collect(_G["ContainerFrame" .. index]) end
    for button in pairs(self.trackedButtons) do
        local item
        if button:IsShown() then
            local bag, slot = button:GetBagID(), button:GetID()
            if not self:IsSecret(bag) and not self:IsSecret(slot) and type(bag) == "number" and type(slot) == "number" and bag >= 0 and bag <= self:BagLimit() then
                item = self.plan.bySlot[bag .. ":" .. slot]
            end
        end
        self:ApplyGlow(button, item)
    end
end

-- Third-party bag modules can register each button through TrackBagButton.
-- Only the default separate/combined Blizzard bags are discovered automatically.
