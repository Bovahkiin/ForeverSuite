local _,FS=...
local T={}; FS.Tools=T
function T:Call(fn,...)
    if type(fn)~="function" then return nil end
    local function pack(...) return {n=select("#",...),...} end
    local result=pack(pcall(fn,...)); if not result[1] then return nil end
    for i=2,result.n do if FS.HUD:Safe(result[i])==false then return nil end end
    return unpack(result,2,result.n)
end
function T:Number(value) return FS.HUD:Safe(value) and type(value)=="number" and value==value and math.abs(value)<1e15 end
function T:Text(value) return FS.HUD:Safe(value) and type(value)=="string" and value or "" end
function T:Edit(parent,x,y,width)
    local f=CreateFrame("EditBox",nil,parent,"BackdropTemplate"); FS.HUD:Skin(f); f:SetSize(width,30); f:SetPoint("TOPLEFT",x,y)
    f:SetAutoFocus(false); FS:ApplyFont(f,14,""); f:SetText(""); f:SetScript("OnEscapePressed",function(b) b:ClearFocus() end); return f
end
function T:Module(name,key,title,description,defaults,events)
    local M={name=name,key=key,title=title,description=description,options={},actions={},rows={}}
    defaults.enabled=true; FS.defaults[key]=defaults; FS:RegisterModule(name,M)
    function M:Data() return FS.db[self.key] end
    function M:NormalizeSettings()
        FS:ApplyDefaults(self:Data(),FS.defaults[self.key])
        for _,option in ipairs(self.options) do if option.values then
            local valid=false; for _,value in ipairs(option.values) do if self:Data()[option.key]==value then valid=true; break end end
            if not valid then self:Data()[option.key]=FS.defaults[self.key][option.key] end
        end end
        if self.Normalize then self:Normalize() end
    end
    function M:RefreshSettings()
        if not self.settings then return end
        for i,option in ipairs(self.options) do
            local value=self:Data()[option.key]
            local caption=option.values and tostring(value) or (value and "On" or "Off")
            if option.format then caption=option.format(value) end
            self.settings[option.key]:SetText(option.label..": "..caption)
            self.settings[option.key]:SetShown(not self.settings.optionPages or math.floor((i-1)/12)+1==self.settings.optionsPage)
        end
        local f=self.settings
        if f.LayoutText then f:LayoutText() end
        if f.optionPages then
            f.optionsPageLabel:SetText("Settings "..f.optionsPage.." / "..f.optionPages)
            f.previousOptions:SetEnabled(f.optionsPage>1); f.nextOptions:SetEnabled(f.optionsPage<f.optionPages)
        end
    end
    function M:CreateSettings(host)
        local H=FS.HUD; local f=CreateFrame("Frame",nil,host,"BackdropTemplate"); self.settings=f; H:Skin(f)
        f:SetBackdropColor(.018,.027,.038,1)
        f:SetSize(892,420); f:SetPoint("TOPLEFT",24,FS.settingsTop); f:SetFrameLevel(host:GetFrameLevel()+30); f:EnableMouse(true)
        f.back=H:Button(f,FS.Text.back,20,-12,220,function() f:Hide() end)
        f.heading=H:Label(f,self.title.." settings",260,-20,590); f.description=H:Label(f,self.description,20,-65,850)
        local compact=#self.options>12
        if compact then f.optionPages=math.ceil(#self.options/12); f.optionsPage=1 end
        for i,option in ipairs(self.options) do
            local slot=compact and (i-1)%12 or i-1
            f[option.key]=H:Button(f,"",20+slot%2*430,-110-math.floor(slot/2)*(compact and 34 or 38),410,function()
                if option.values then
                    local index=1; for j,value in ipairs(option.values) do if self:Data()[option.key]==value then index=j%#option.values+1; break end end
                    self:Data()[option.key]=option.values[index]
                else self:Data()[option.key]=not self:Data()[option.key] end
                self:SettingsChanged()
            end)
        end
        if compact then
            f.previousOptions=H:Button(f,"Previous settings",20,-318,170,function() f.optionsPage=math.max(1,f.optionsPage-1); self:RefreshSettings() end)
            f.nextOptions=H:Button(f,"Next settings",700,-318,170,function() f.optionsPage=math.min(f.optionPages,f.optionsPage+1); self:RefreshSettings() end)
            f.previousOptions:SetHeight(24); f.nextOptions:SetHeight(24)
            f.optionsPageLabel=H:Label(f,"",350,-322,240)
        end
        f.hint=H:Label(f,self.settingsHint or "Changes are saved automatically. Open the module to use its tools.",20,compact and -355 or -335,850)
        f.open=H:Button(f,self.openLabel or "Open "..self.title,20,compact and -380 or -370,850,function()
            if self.settingsAction then self:settingsAction() else self:ShowWindow() end
        end)
        local module=self
        function f:LayoutText()
            local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
            local header=math.max(H:FitButton(self.back,2),H:TextHeight(self.heading,590,2)+8)
            local descriptionTop=math.max(65,12+header+10)
            at(self.description,20,descriptionTop)
            local descriptionHeight=H:TextHeight(self.description,850,3)
            local start=math.max(110,descriptionTop+descriptionHeight+12)
            local rowHeight=compact and 34 or 38
            for _,option in ipairs(module.options) do rowHeight=math.max(rowHeight,H:FitButton(self[option.key],2)+4) end
            for i,option in ipairs(module.options) do local slot=compact and (i-1)%12 or i-1; at(self[option.key],20+slot%2*430,start+math.floor(slot/2)*rowHeight) end
            local bottom=start+math.ceil(math.min(#module.options,12)/2)*rowHeight
            if compact then
                local navigationHeight=math.max(H:FitButton(self.previousOptions,2,24),H:FitButton(self.nextOptions,2,24),H:TextHeight(self.optionsPageLabel,240,2))
                at(self.previousOptions,20,bottom+4); at(self.nextOptions,700,bottom+4); at(self.optionsPageLabel,350,bottom+8)
                bottom=bottom+navigationHeight+16
            else bottom=math.max(335,bottom+12) end
            at(self.hint,20,bottom); bottom=bottom+H:TextHeight(self.hint,850,3)+10
            at(self.open,20,bottom); local height=bottom+H:FitButton(self.open,2)+10
            self:SetHeight(math.max(420,height))
            if self.fsSettingsBound then FS:FitSettingsViewport(self)
            else self:SetScale(math.min(1,(UIParent:GetWidth()-40)/892,(UIParent:GetHeight()-40)/self:GetHeight())) end
        end
        self:RefreshSettings(); f:Hide(); return f
    end
    function M:CreateWindow()
        if self.window then return self.window end
        local H=FS.HUD; local f=CreateFrame("Frame","ForeverSuite"..self.name.."Window",UIParent,"BackdropTemplate"); self.window=f; H:Skin(f); f:SetBackdropColor(.025,.035,.05,1)
        f:SetSize(660,540); f:SetPoint("CENTER"); f:SetScale(math.min(1,(UIParent:GetWidth()-32)/660,(UIParent:GetHeight()-32)/540))
        f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function(b) if not InCombatLockdown() then b:StartMoving() end end)
        f:SetScript("OnDragStop",function(b) b:StopMovingOrSizing(); FS.Layout:Save("Tool:"..self.name,b,b:GetScale()) end)
        f:SetScript("OnHide",function(b) b:StopMovingOrSizing(); GameTooltip:Hide() end)
        f.heading=H:Label(f,"FOREVERSUITE / "..string.upper(self.title),16,-18,420)
        f.control=H:Button(f,"Control Center",466,-10,178,function() FS:ShowConfig() end)
        f.search=T:Edit(f,16,-54,628); f.search:SetScript("OnTextChanged",function() self.page=1; self:Render() end)
        f.status=H:Label(f,"",16,-94,628); f.status:SetHeight(40)
        f.cells={}
        for i=1,9 do
            local b=H:Button(f,"",16,-140-(i-1)*32,628,function() self.selected=f.cells[i].row; if self.OnSelect then self:OnSelect(self.selected) end; self:Render() end)
            b:SetScript("OnEnter",function(c)
                if c.row then GameTooltip:SetOwner(c,"ANCHOR_RIGHT"); if c.row.link then GameTooltip:SetHyperlink(c.row.link) else GameTooltip:AddLine(c.row.text,1,1,1,true) end; GameTooltip:Show() end
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end); f.cells[i]=b
        end
        f.previous=H:Button(f,FS.Text.previous,16,-438,110,function() self.page=math.max(1,(self.page or 1)-1); self:Render() end)
        f.pageLabel=H:Label(f,"",142,-446,235)
        f.next=H:Button(f,FS.Text.next,384,-438,110,function() self.page=(self.page or 1)+1; self:Render() end)
        f.close=H:Button(f,FS.Text.close,510,-438,134,function() f:Hide() end)
        f.input=T:Edit(f,16,-480,290)
        f.actionButtons={}
        for i,action in ipairs(self.actions) do f.actionButtons[i]=H:Button(f,action.label,316+(i-1)*110,-480,104,function()
            local before=self.status; action.run(self,f.input:GetText())
            if self.status~=before then self.notice=self.status; self.noticeUntil=GetTime()+6 end
            self:Refresh()
        end) end
        function f:LayoutText()
            local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
            local y=math.max(54,math.max(H:TextHeight(self.heading,420,2)+18,H:FitButton(self.control,2)+10)+10)
            local _,searchSize=self.search:GetFont(); self.search:SetHeight(math.max(30,(searchSize or 14)+12)); at(self.search,16,y)
            y=y+self.search:GetHeight()+10; at(self.status,16,y); y=y+H:TextHeight(self.status,628,3)+12
            local rowHeight=30
            for _,b in ipairs(self.cells) do rowHeight=math.max(rowHeight,H:FitButton(b,2)) end
            for i,b in ipairs(self.cells) do at(b,16,y+(i-1)*(rowHeight+4)) end
            y=y+9*(rowHeight+4)+10
            local footer=H:TextHeight(self.pageLabel,235,2)
            for i,b in ipairs({self.previous,self.next,self.close}) do at(b,({16,384,510})[i],y); footer=math.max(footer,H:FitButton(b,2)) end
            at(self.pageLabel,142,y+4); y=y+footer+12
            local _,inputSize=self.input:GetFont(); self.input:SetHeight(math.max(30,(inputSize or 14)+12)); at(self.input,16,y); footer=self.input:GetHeight()
            for i,b in ipairs(self.actionButtons) do at(b,316+(i-1)*110,y); footer=math.max(footer,H:FitButton(b,3)) end
            self:SetHeight(math.max(540,y+footer+20))
            if not FS.db.layout.frames["Tool:"..self.fsToolName] then self:SetScale(math.min(1,(UIParent:GetWidth()-32)/660,(UIParent:GetHeight()-32)/self:GetHeight())) end
        end
        f.fsToolName=self.name
        f:HookScript('OnShow',function() if self.SyncLifecycle then self:SyncLifecycle() end end)
        f:HookScript('OnHide',function() if self.SyncLifecycle then self:SyncLifecycle() end end)
        UISpecialFrames[#UISpecialFrames+1]=f:GetName(); f:Hide(); FS.Layout:Register("Tool:"..self.name,f,self.title); return f
    end
    function M:Render()
        local f=self.window; if not f or not f:IsShown() then return end
        local rows={}; local query=string.lower(f.search:GetText() or "")
        for _,row in ipairs(self.rows or {}) do if string.find(string.lower(row.text or ""),query,1,true) then rows[#rows+1]=row end end
        local pages=math.max(1,math.ceil(#rows/9)); self.page=math.max(1,math.min(self.page or 1,pages))
        local function key(row) return row and (row.id or row.roll or row.index or row.command or row.name or row.pin or row.text) end
        for i,b in ipairs(f.cells) do
            b.row=rows[(self.page-1)*9+i]; local caption=b.row and b.row.text or ""; b:SetText(#caption>88 and caption:sub(1,85).."..." or caption); b:SetShown(b.row~=nil)
            local selected=b.row and self.selected and key(b.row)==key(self.selected)
            b:SetBackdropBorderColor(selected and 1 or .12,selected and .75 or .72,selected and .2 or .86,1)
        end
        f.pageLabel:SetText("Page "..self.page.." / "..pages.."  |  "..#rows.." entries")
        f.status:SetText(self.noticeUntil and GetTime()<self.noticeUntil and self.notice or self.status or (#rows==0 and "No entries to show yet." or "Select an entry for details."))
        if f.LayoutText then f:LayoutText() end
    end
    function M:Refresh() if self.Build then self:Build() end; self:Render() end
    function M:ShowWindow()
        if not FS:IsModuleEnabled(self.name) then FS:Print("Enable "..self.title.." in the Control Center first."); return end
        if InCombatLockdown() then FS:Print("Leave combat to open this window."); return end
        local f=self:CreateWindow(); FS:CloseOtherWindows(f); f:Show(); self:Refresh()
    end
    function M:SettingsChanged()
        self:NormalizeSettings()
        if InCombatLockdown() then self.pending=true; return end
        self.pending=false
        self:SyncLifecycle()
        self:RefreshSettings()
        if not FS:IsModuleEnabled(self.name) then if self.StopCapture then self:StopCapture() end; if self.window then self.window:Hide() end; return end
        if self.Apply then self:Apply() end; self:Refresh()
    end
    function M:SyncLifecycle()
        if not self.events or not self.ticker or InCombatLockdown() then return end
        local active=FS:IsModuleEnabled(self.name)
        if self.lifecycleActive~=active then
            self.lifecycleActive=active
            for event in pairs(FS.client.frameEvents[self.events] or {}) do
                if active then FS:RegisterClientEvent(self.events,event)
                elseif event~='PLAYER_REGEN_ENABLED' then self.events:UnregisterEvent(event) end
            end
        end
        self.events:SetScript('OnUpdate',active and (self.Tick or (self.window and self.window:IsShown())) and self.ticker or nil)
    end
    function M:Initialize()
        self.events=CreateFrame("Frame")
        FS:RegisterClientEvent(self.events,"PLAYER_REGEN_ENABLED")
        for _,event in ipairs(events or {}) do
            if event~="COMBAT_LOG_EVENT_UNFILTERED" or CombatLogGetCurrentEventInfo then FS:RegisterClientEvent(self.events,event) end
        end
        self.events:SetScript("OnEvent",function(_,event,...)
            if event=="PLAYER_REGEN_ENABLED" then if self.pending then self:SettingsChanged() else self:SyncLifecycle() end; if FS:IsModuleEnabled(self.name) and self.Event then self:Event(event,...) end; return end
            if not FS:IsModuleEnabled(self.name) then return end
            if self.Event then self:Event(event,...) end; if self.window and self.window:IsShown() then self:Refresh() end
        end)
        local elapsed=0
        self.ticker=function(_,dt)
            elapsed=elapsed+dt; if elapsed<1 then return end; elapsed=0
            if FS:IsModuleEnabled(self.name) then if self.Tick then self:Tick() end; if self.window and self.window:IsShown() then self:Refresh() end end
        end
        self:SettingsChanged()
    end
    return M
end
