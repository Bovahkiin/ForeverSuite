local _, FS = ...
FS.Widgets = {}
function FS.Widgets:Label(parent, size)
    local f = parent:CreateFontString(nil, "OVERLAY", size or "ForeverSuiteFontNormal")
    FS:ApplyFont(f); if FS.Themes then FS.Themes:Font(f) end; return f
end

function FS.Widgets:Checkbox(parent, y, onClick)
    local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", 20, y)
    button.label = FS.Widgets:Label(parent, "ForeverSuiteFontNormal")
    button.label:SetPoint("LEFT", button, "RIGHT", 4, 0)
    button:SetScript("OnClick", function(self) FS:SettingAction(onClick,self:GetChecked() and true or false) end)
    return button
end

function FS.Widgets:Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetText(text)
    button:SetScript("OnClick", function(...) return FS:SettingAction(onClick,...) end)
    if FS.Themes then FS.Themes:Register(button,"Button") end
    return button
end

-- Modal suite windows share a single foreground screen. HUD bars stay visible.
function FS:CloseOtherWindows(keep,returnToCenter)
    if self.Extensions then for _,f in pairs({self.Extensions.form,self.Extensions.dialog}) do if f~=keep then f:Hide() end end end
    if self.Installer and self.Installer.window and self.Installer.window~=keep then self.Installer.window:Hide() end
    if self.WindowManager then self.WindowManager:HideNativeWindows(keep) end
    self.closingOtherWindows=true
    local bank=self.modules.Bank; local bags=self.modules.Bags
    local bankPair=bank and bank.open and (keep==bank.window or keep==bags.window)
    local equipmentPair=CharacterFrame and (keep==CharacterFrame or (keep==bags.window and CharacterFrame:IsShown()))
    if returnToCenter then self.aboutReturn=self.window and self.window:IsShown() or false end
    for _,frame in pairs({self.window,self.aboutWindow,self.Typography and self.Typography.window,self.Compatibility and self.Compatibility.window}) do if frame and frame~=keep and frame:IsShown() then frame:Hide() end end
    for _,module in pairs(self.modules) do
        for _,key in ipairs({"window","saleReview"}) do local frame=module[key]; local paired=(bankPair and (frame==bank.window or frame==bags.window)) or (equipmentPair and frame==bags.window); if frame and frame~=keep and not paired and frame:IsShown() and not InCombatLockdown() then frame:Hide() end end
    end
    if CharacterFrame and CharacterFrame~=keep and not equipmentPair and CharacterFrame:IsShown() and not InCombatLockdown() then
        if HideUIPanel then HideUIPanel(CharacterFrame) else CharacterFrame:Hide() end
    end
    self.closingOtherWindows=false
end
