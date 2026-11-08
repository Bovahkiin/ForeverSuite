local _,FS=...
local T=FS.Tools
local B=T:Module("Bindings","bindings","Key Bindings","Select an action, click Bind, then press a key. Changes save immediately to your current game binding set.",{}, {"PLAYER_REGEN_DISABLED"})
B.commands={}
for i=1,12 do B.commands[#B.commands+1]={command="ACTIONBUTTON"..i,label="Main bar "..i} end
for bar=1,4 do for i=1,12 do B.commands[#B.commands+1]={command="MULTIACTIONBAR"..bar.."BUTTON"..i,label="Extra bar "..bar.." - "..i} end end
for i=1,10 do B.commands[#B.commands+1]={command="SHAPESHIFTBUTTON"..i,label="Stance "..i}; B.commands[#B.commands+1]={command="BONUSACTIONBUTTON"..i,label="Pet "..i} end
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
    if self.capture then self.capture:EnableKeyboard(false); if self.capture.SetPropagateKeyboardInput then self.capture:SetPropagateKeyboardInput(true) end; self.capture:Hide() end
end
function B:BindKey(key)
    if not self.capturing then return end
    if key=="ESCAPE" or InCombatLockdown() then self:StopCapture(); return end
    if key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then return end
    local binding=(IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")..key
    local ok=T:Call(SetBinding,binding,self.capturing)
    if ok then T:Call(SaveBindings,T:Call(GetCurrentBindingSet) or 1) end
    self:StopCapture(); self:Refresh()
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
function B:Event() self:StopCapture() end
local create=B.CreateWindow
function B:CreateWindow() local f=create(self); if not self.closeHook then self.closeHook=true; f:HookScript("OnHide",function() self:StopCapture() end) end; return f end
B.actions={{label="Bind",run=function(self) self:BeginCapture() end},{label="Unbind",run=function(self)
    if InCombatLockdown() or not self.selected then return end
    local a,b=T:Call(GetBindingKey,self.selected.command); if a then T:Call(SetBinding,a) end; if b then T:Call(SetBinding,b) end
    T:Call(SaveBindings,T:Call(GetCurrentBindingSet) or 1)
end},{label="Game UI",run=function() T:Call(KeyBindingFrame_LoadUI); if KeyBindingFrame then if ShowUIPanel then ShowUIPanel(KeyBindingFrame) else KeyBindingFrame:Show() end end end}}
