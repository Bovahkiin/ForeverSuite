local _,FS=...
local T=FS.Tools
local B=T:Module("Bindings","bindings","Key Bindings","Select an action, click Bind, then press a key. Changes save immediately to your current game binding set.",{}, {"PLAYER_REGEN_DISABLED"})
B.commands={}
for i=1,12 do B.commands[#B.commands+1]={command="ACTIONBUTTON"..i,label="Main bar "..i} end
for bar=1,7 do for i=1,12 do B.commands[#B.commands+1]={command="MULTIACTIONBAR"..bar.."BUTTON"..i,label="Extra bar "..bar.." - "..i} end end
for i=1,10 do B.commands[#B.commands+1]={command="SHAPESHIFTBUTTON"..i,label="Stance "..i}; B.commands[#B.commands+1]={command="BONUSACTIONBUTTON"..i,label="Pet "..i} end
local buttonCommands={
    ActionButton="ACTIONBUTTON",MultiBarBottomLeftButton="MULTIACTIONBAR1BUTTON",
    MultiBarBottomRightButton="MULTIACTIONBAR2BUTTON",MultiBarRightButton="MULTIACTIONBAR3BUTTON",
    MultiBarLeftButton="MULTIACTIONBAR4BUTTON",MultiBar5Button="MULTIACTIONBAR5BUTTON",
    MultiBar6Button="MULTIACTIONBAR6BUTTON",MultiBar7Button="MULTIACTIONBAR7BUTTON",
    StanceButton="SHAPESHIFTBUTTON",PetActionButton="BONUSACTIONBUTTON",
}
function B:CommandForButton(button)
    local name=T:Text(T:Call(button.GetName,button))
    local prefix,index=name:match("^(.-)(%d+)$")
    local command=buttonCommands[prefix]
    return command and command..index or nil
end
function B:Build()
    self.rows={}
    for _,entry in ipairs(self.commands) do
        local a,b=T:Call(GetBindingKey,entry.command)
        self.rows[#self.rows+1]={command=entry.command,text=entry.label.." | "..(a or "Unbound")..(b and " / "..b or "")}
    end
    self.status=self.capturing and "Press your new key. Escape cancels. Existing assignments for that key will be replaced." or "Select an action, then Bind. Your other bindings remain in place."
end
function B:StopCapture()
    self.capturing=nil
    if self.quick then
        self.quick:EnableKeyboard(false)
        if self.quick.SetPropagateKeyboardInput then self.quick:SetPropagateKeyboardInput(true) end
    end
    if self.capture then self.capture:EnableKeyboard(false); if self.capture.SetPropagateKeyboardInput then self.capture:SetPropagateKeyboardInput(true) end; self.capture:Hide() end
end
function B:BindKey(key)
    if not self.capturing then return end
    local quick=self.quick and self.quick:IsShown()
    if key=="ESCAPE" or InCombatLockdown() then
        self:StopCapture()
        if quick then self:RefreshQuickBindings() end
        return
    end
    if key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then return end
    local binding=(IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")..key
    local ok=T:Call(SetBinding,binding,self.capturing)
    if ok then T:Call(SaveBindings,T:Call(GetCurrentBindingSet) or 1) end
    self:StopCapture()
    if quick then self:RefreshQuickBindings(ok and "Binding saved." or "This key could not be bound.")
    else self:Refresh() end
end
function B:RefreshQuickBindings(message)
    local f=self.quick
    f.hint:SetText(message or "Click an action button, then press a key. Keys already assigned elsewhere are replaced.")
    for _,item in pairs(f.buttons) do
        local key=T:Call(GetBindingKey,item.command)
        local shown=(item.native.IsVisible and item.native:IsVisible()) or (not item.native.IsVisible and item.native:IsShown())
        item:SetShown(shown)
        item:SetBackdropBorderColor(.12,.72,.86,.9)
        item.key:SetText(key or "")
    end
end
function B:OpenQuickBindings()
    if not FS.modules.Profiles:Allowed() then return false end
    if not self.quick then
        local H=FS.HUD
        local f=CreateFrame("Frame","ForeverSuiteQuickBindings",UIParent,"BackdropTemplate")
        self.quick=f; f.buttons={}; H:Skin(f)
        f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetSize(496,106); f:SetPoint("TOP",0,-70)
        H:Label(f,"Quick keybind mode",16,-14,350)
        f.hint=H:Label(f,"",16,-45,464); f.hint:SetHeight(48)
        H:Button(f,"Done",394,-8,86,function() f:Hide() end)
        f:SetScript("OnHide",function() self:StopCapture(); FS.modules.ActionBars:RefreshBarVisibility() end)
        f:SetScript("OnKeyDown",function(_,key) self:BindKey(key) end)
        UISpecialFrames[#UISpecialFrames+1]=f:GetName()
        f:Hide()
    end
    local f,H=self.quick,FS.HUD
    FS:CloseOtherWindows(f); self:StopCapture()
    for native in pairs(FS.modules.ActionBars.buttons) do
        local command=self:CommandForButton(native)
        if command and not f.buttons[native] then
            local button=CreateFrame("Button",nil,f,"BackdropTemplate"); f.buttons[native]=button
            button.native=native; button.command=command
            button:SetAllPoints(native); button:SetFrameLevel(f:GetFrameLevel()+2)
            button:SetBackdrop({edgeFile=H.texture,edgeSize=2})
            button.key=FS.Widgets:Label(button); button.key:SetPoint("CENTER")
            button:RegisterForClicks("LeftButtonUp")
            button:SetScript("OnClick",function()
                if InCombatLockdown() then f:Hide(); return end
                self.capturing=command; self:RefreshQuickBindings("Press a key. Escape cancels.")
                button:SetBackdropBorderColor(.95,.68,.24,1)
                f:EnableKeyboard(true)
                if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
            end)
        end
    end
    f:Show()
    FS.modules.ActionBars:RefreshBarVisibility()
    self:RefreshQuickBindings()
    return true
end
function B:BeginCapture()
    if InCombatLockdown() or not self.selected then return end
    if not self.capture then
        self.capture=CreateFrame("Frame",nil,self.window); self.capture:SetAllPoints(); self.capture:SetFrameLevel(self.window:GetFrameLevel()+5)
        self.capture:SetScript("OnKeyDown",function(_,key) self:BindKey(key) end)
    end
    self.capturing=self.selected.command; self.capture:Show(); self.capture:EnableKeyboard(true)
    if self.capture.SetPropagateKeyboardInput then self.capture:SetPropagateKeyboardInput(false) end
end
function B:Event()
    self:StopCapture()
    if self.quick then self.quick:Hide() end
end
local create=B.CreateWindow
function B:CreateWindow() local f=create(self); if not self.closeHook then self.closeHook=true; f:HookScript("OnHide",function() self:StopCapture() end) end; return f end
B.actions={{label="Bind",run=function(self) self:BeginCapture() end},{label="Unbind",run=function(self)
    if InCombatLockdown() or not self.selected then return end
    local a,b=T:Call(GetBindingKey,self.selected.command); if a then T:Call(SetBinding,a) end; if b then T:Call(SetBinding,b) end
    T:Call(SaveBindings,T:Call(GetCurrentBindingSet) or 1)
end},{label="Game UI",run=function() T:Call(KeyBindingFrame_LoadUI); if KeyBindingFrame then if ShowUIPanel then ShowUIPanel(KeyBindingFrame) else KeyBindingFrame:Show() end end end}}
