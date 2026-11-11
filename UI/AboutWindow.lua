local _,FS=...
FS.patchNotes={
    {version="0.9.12",lines={"Module settings open on their own screen, including Vendor & Junk and its advanced options."}},
}
function FS:CreateAboutWindow()
    if self.aboutWindow then return self.aboutWindow end
    local H=self.HUD
    local f=CreateFrame("Frame","ForeverSuiteAboutWindow",UIParent,"BackdropTemplate"); self.aboutWindow=f; H:Skin(f); f:SetBackdropColor(.025,.035,.05,1)
    f:SetSize(510,330); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:SetScale(math.min(1,(UIParent:GetWidth()-32)/510,(UIParent:GetHeight()-32)/330))
    f.title=H:Label(f,"",20,-20,465); self:ApplyFont(f.title,18)
    f.body=H:Label(f,"",20,-65,465); f.body:SetHeight(155)
    f.hideStartup=self.Widgets:Checkbox(f,-223,function(checked) self.db.patchLog.showOnLoad=not checked end)
    f.hideStartup.label:SetText("Don't show again at startup")
    f.close=H:Button(f,FS.Text.close,360,-276,130,function()
        f:Hide()
        if self.installerReturn then self.installerReturn=false; self.Installer:Refresh(); self.Installer.window:Show()
        elseif self.aboutReturn then self.aboutReturn=false; self:ShowConfig() end
    end)
    UISpecialFrames[#UISpecialFrames+1]="ForeverSuiteAboutWindow"
    function f:LayoutText()
        local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
        local y=20+H:TextHeight(self.title,465,2)+20; at(self.body,20,y)
        y=y+H:TextHeight(self.body,465,24)+20
        if self.hideStartup:IsShown() then
            at(self.hideStartup,20,y); H:TextHeight(self.hideStartup.label,425,3)
            y=y+math.max(30,self.hideStartup.label:GetHeight())+18
        end
        at(self.close,360,y); self:SetHeight(math.max(330,y+H:FitButton(self.close,2)+20))
        self:SetScale(math.min(1,(UIParent:GetWidth()-32)/510,(UIParent:GetHeight()-32)/self:GetHeight()))
    end
    f:Hide(); return f
end
function FS:RefreshAboutWindow()
    local f=self.aboutWindow; if not f then return end
    local patches=self.aboutMode=="patch"
    f.close:SetText(self.installerReturn and "Back to setup" or FS.Text.close)
    f.hideStartup:SetShown(patches); f.hideStartup.label:SetShown(patches)
    if patches then
        local entry=self.patchNotes[1]
        f.title:SetText("PATCH LOG  |  v"..entry.version)
        f.body:SetText("What's new\n\n- "..table.concat(entry.lines,"\n\n- "))
        f.hideStartup:SetChecked(not self.db.patchLog.showOnLoad)
    else
        f.title:SetText("CREDITS  |  ForeverSuite")
        f.body:SetText("Created by DeluxiZ\n\nMade with help from AI.\n\nThank you for using ForeverSuite.")
    end
    f:LayoutText()
end
function FS:ShowPatchLog(fromSetup)
    if InCombatLockdown() and CharacterFrame and CharacterFrame:IsShown() then self:Print("Leave combat to switch windows."); return end
    self.installerReturn=fromSetup==true
    self:CloseOtherWindows(self.aboutWindow, true)
    self:CreateAboutWindow(); self.aboutMode="patch"; self:RefreshAboutWindow(); self.aboutWindow:Show()
end
function FS:ShowCredits()
    if InCombatLockdown() and CharacterFrame and CharacterFrame:IsShown() then self:Print("Leave combat to switch windows."); return end
    self.installerReturn=false
    self:CloseOtherWindows(self.aboutWindow, true)
    self:CreateAboutWindow(); self.aboutMode="credits"; self:RefreshAboutWindow(); self.aboutWindow:Show()
end
