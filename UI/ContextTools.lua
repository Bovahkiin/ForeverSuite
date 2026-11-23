local _,FS=...
local C={hosts=setmetatable({},{__mode='k'}),frames=setmetatable({},{__mode='k'}),watched=setmetatable({},{__mode='k'})}
FS.Context=C
local T,H=FS.Tools,FS.HUD
local function shown(f) return f and not (f.IsForbidden and f:IsForbidden()) and f:IsShown() end
function C:Allowed()
    if InCombatLockdown() then FS:Print(FS.Text.leaveCombat); return false end
    if FS.databaseReadOnly then FS:Print('Saved settings are read-only. Update ForeverSuite before changing these tools.'); return false end
    return FS.db and not FS.databaseReadOnly
end
function C:IsTool(frame)
    if not frame then return false end
    if FS.Extensions and (frame==FS.Extensions.form or frame==FS.Extensions.dialog) then return true end
    if FS.Beginner and frame==FS.Beginner.characterOverview then return true end
    if FS.modules.Bindings and frame==FS.modules.Bindings.quick then return true end
    for _,module in FS:EachModule() do if module.window==frame or module.saleReview==frame then return true end end
    return false
end
function C:IsHostFamily(frame,host)
    local current=host
    for _=1,20 do
        if current==frame then return true end
        current=current and T:Call(current.GetParent,current)
        if not current then return false end
    end
    return false
end
function C:Release(frame)
    local saved=self.frames[frame]
    frame.fsContextHost=nil; frame.fsContextRows=nil
    if frame.fsContextModule then frame.fsContextModule.contextShoppingOnly=nil; frame.fsContextModule.contextSlot=nil end
    frame.fsContextModule=nil
    if not saved then return end
    frame:SetScale(saved.scale); frame:SetSize(saved.width,saved.height); H:RestorePoints(frame,saved.points)
    if frame.control then frame.control:Show() end
    if frame.back and saved.back~=nil then frame.back:SetShown(saved.back) end
    if frame.fsContextLauncher then frame.fsContextLauncher:SetShown(saved.launcher~=false) end
    if frame.heading and saved.heading then frame.heading:SetText(saved.heading) end
    if frame.section then frame.section:Show(); frame.previousSection:Show() end
    self.frames[frame]=nil
end
function C:Clear()
    self.host=nil; self.activeFrame=nil
    self.playerSelection=nil
    for _,state in pairs(self.hosts) do if state.menu then state.menu:Hide() end end
    local frames={}; for frame in pairs(self.frames) do frames[#frames+1]=frame end
    for _,frame in ipairs(frames) do self:Release(frame) end
end
function C:HideHost(host)
    if self.host~=host then return end
    for frame in pairs(self.frames) do if shown(frame) then frame:Hide() end end
    self:Clear()
end
function C:BeforeOpen(frame)
    local host=self.pendingHost
    if not host and self.host and shown(self.host) and self:IsTool(frame) then host=self.host end
    if frame==self.host then return self.host end
    if not host or not shown(host) or frame==host or not self:IsTool(frame) then self:Clear(); return end
    if self.host and self.host~=host then self:Clear() end
    self.host=host; self.activeFrame=frame
    self:Dock(frame,host)
    return host
end
function C:Dock(frame,host)
    if not self.frames[frame] then
        self.frames[frame]={points=H:SavePoints(frame),scale=frame:GetScale(),width=frame:GetWidth(),height=frame:GetHeight(),
            control=frame.control and frame.control:IsShown(),launcher=frame.fsContextLauncher and frame.fsContextLauncher:IsShown(),
            back=frame.back and frame.back:IsShown(),
            section=frame.section and frame.section:IsShown(),previousSection=frame.previousSection and frame.previousSection:IsShown(),
            heading=frame.heading and frame.heading:GetText()}
    end
    frame.fsContextHost=host
    if frame.control then frame.control:Hide() end
    if frame.back then frame.back:Hide() end
    if not frame.fsContextHooks then
        frame.fsContextHooks=true
        local start,stop=frame:GetScript('OnDragStart'),frame:GetScript('OnDragStop')
        frame:SetScript('OnDragStart',function(f,...) if not f.fsContextHost and start then start(f,...) end end)
        frame:SetScript('OnDragStop',function(f,...) if not f.fsContextHost and stop then stop(f,...) end end)
        frame:HookScript('OnHide',function()
            C_Timer.After(0,function()
                if C.host and not shown(C.activeFrame) then C:Clear() end
            end)
        end)
        if frame.fsToolName and frame.LayoutText then
            local original=frame.LayoutText
            frame.LayoutText=function(f)
                if f.fsContextHost and not f.grid then return C:LayoutTool(f) end
                local result=original(f)
                if f.fsContextHost then C:Position(f) end
                return result
            end
        end
    end
    if frame.fsToolName then
        frame.fsContextModule=FS.modules[frame.fsToolName]; frame.fsContextRows=not frame.grid and 5 or nil
        if frame.control then frame.control:Hide() end
        if frame.fsContextLauncher then frame.fsContextLauncher:Hide() end
    end
    self:Position(frame)
end
function C:Position(frame)
    if InCombatLockdown() or not frame.fsContextHost then return end
    local host=frame.fsContextHost; local state=self.hosts[host]
    local anchor=state and state.visual or host
    local width,height=frame:GetWidth(),frame:GetHeight()
    local scale=math.min(1,(UIParent:GetHeight()-56)/math.max(1,height),(UIParent:GetWidth()-32)/math.max(1,width))
    frame:SetScale(scale); frame:SetClampedToScreen(true); frame:SetFrameStrata('DIALOG')
    frame:SetFrameLevel((T:Call(anchor.GetFrameLevel,anchor) or 1)+50)
    local left,_,hostWidth=T:Call(anchor.GetRect,anchor)
    local ratio=(T:Call(anchor.GetEffectiveScale,anchor) or 1)/UIParent:GetEffectiveScale()
    frame:ClearAllPoints()
    if T:Number(left) and T:Number(hostWidth) and UIParent:GetWidth()-(left+hostWidth)*ratio>=width*scale+16 then
        frame:SetPoint('TOPLEFT',anchor,'TOPRIGHT',10,0)
    elseif T:Number(left) and left*ratio>=width*scale+16 then
        frame:SetPoint('TOPRIGHT',anchor,'TOPLEFT',-10,0)
    else
        -- A drawer keeps the host's title and left-hand selection accessible.
        frame:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',-8,-64)
    end
end
function C:LayoutTool(f)
    local module=f.fsContextModule
    if not module then return end
    local width=math.min(500,UIParent:GetWidth()-32); local inner=width-32
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint('TOPLEFT',x,-y) end
    f.heading:SetText(module.name=='Workbench' and module:Data().view or module.title)
    at(f.heading,16,14); local y=14+H:TextHeight(f.heading,inner-100,2)+8
    at(f.toolSettings,width-112,10); f.toolSettings:SetWidth(96); H:FitButton(f.toolSettings,2)
    if f.section then f.section:Hide(); f.previousSection:Hide() end
    at(f.summary,16,y); y=y+H:TextHeight(f.summary,inner,2)+8
    at(f.search,16,y); f.search:SetSize(inner,math.max(30,select(2,f.search:GetFont())+12)); f.searchHint:SetWidth(inner-20)
    y=y+f.search:GetHeight()+8; at(f.status,16,y); y=y+H:TextHeight(f.status,inner,2)+10
    H:SetHelp(f.status,f.status:GetText())
    local rowHeight=30
    for i=1,f.visibleRows or 0 do f.cells[i]:SetWidth(inner); rowHeight=math.max(rowHeight,H:FitButton(f.cells[i],2)) end
    for i,b in ipairs(f.cells) do at(b,16,y+(i-1)*(rowHeight+4)) end
    if (f.visibleRows or 0)==0 then
        at(f.emptyTitle,16,y); y=y+H:TextHeight(f.emptyTitle,inner,2)+10
        at(f.emptyText,16,y); y=y+H:TextHeight(f.emptyText,inner,3)+10
        if f.emptyAction:IsShown() then at(f.emptyAction,16,y); f.emptyAction:SetWidth(inner); y=y+H:FitButton(f.emptyAction,2)+10 end
    else y=y+f.visibleRows*(rowHeight+4)+8 end
    if f.input:IsShown() then
        at(f.inputLabel,16,y); y=y+H:TextHeight(f.inputLabel,inner,1)+4
        at(f.input,16,y); f.input:SetSize(inner,math.max(30,select(2,f.input:GetFont())+12)); f.inputHint:SetWidth(inner-20)
        y=y+f.input:GetHeight()+10
    end
    local count,height=0,0
    for _,b in ipairs(f.actionButtons) do if b:IsShown() then count=count+1; b:SetWidth((inner-8)/2); height=math.max(height,H:FitButton(b,2)) end end
    local index=0
    for _,b in ipairs(f.actionButtons) do if b:IsShown() then at(b,16+index%2*(inner+8)/2,y+math.floor(index/2)*(height+6)); index=index+1 end end
    y=y+math.ceil(count/2)*(height+6)+8
    at(f.pageLabel,16,y); y=y+H:TextHeight(f.pageLabel,inner,1)+8
    local footer=0
    for i,b in ipairs({f.previous,f.next,f.close}) do b:SetWidth((inner-16)/3); at(b,16+(i-1)*(inner+8)/3,y); footer=math.max(footer,H:FitButton(b,2)) end
    f:SetSize(width,y+footer+14); self:Position(f)
end
function C:Run(host,action)
    if not self:Allowed() or not shown(host) then return false end
    if not self.watched[host] then
        self.watched[host]=true
        host:HookScript('OnHide',function() C:HideHost(host) end)
    end
    local old=self.pendingHost; self.pendingHost=host
    local ok,message=pcall(action)
    self.pendingHost=old
    if not ok then self:HideHost(host); error(message,0) end
    return true
end
function C:Open(host,moduleName,view,prepare)
    local module=FS.modules[moduleName]
    if not module or not FS:IsModuleEnabled(moduleName) then FS:Print('Enable '..moduleName..' to use this tool.'); return false end
    if self.host and self.host~=host then self:Clear() end
    return self:Run(host,function()
        if prepare then prepare(module) end
        if view then module:Choose(view) else module:ShowWindow() end
        local frame=module.window
        if frame and frame~=host and frame:IsShown() and not frame.fsContextHost then FS:CloseOtherWindows(frame) end
        if frame and frame.fsContextHost then
            frame.fsContextModule=module
            if frame.LayoutText then frame:LayoutText() else self:Position(frame) end
        end
    end)
end
function C:Menu(host,entries,anchor)
    if not self:Allowed() then return end
    local state=self.hosts[host]; if not state then return end
    local launcher=anchor or state.button
    if state.menu and state.menu:IsShown() then state.menu:Hide(); return end
    local menu=state.menu
    if not menu then
        local name='ForeverSuiteContextMenu'..tostring(self.menuCount or 0); self.menuCount=(self.menuCount or 0)+1
        menu=CreateFrame('Frame',name,UIParent,'BackdropTemplate'); state.menu=menu
        H:Skin(menu); menu:SetFrameStrata('TOOLTIP'); menu:SetClampedToScreen(true); menu:EnableMouse(true); menu.buttons={}
        -- Escape support uses named frames; the menu remains owned by its host.
        _G[name]=menu; UISpecialFrames[#UISpecialFrames+1]=name
    end
    local y=10
    for i,entry in ipairs(entries) do
        local b=menu.buttons[i]
        if not b then b=H:Button(menu,'',10,0,300,function(button)
            local choice=button.entry; menu:Hide()
            if choice then C:Run(host,function() choice.run(host) end) end
        end); menu.buttons[i]=b end
        local enabled=entry.enabled~=false and (not entry.owner or FS:IsModuleEnabled(entry.owner))
        b.entry=entry; b:SetText(entry.label); b:SetEnabled(enabled)
        H:SetHelp(b,not enabled and entry.owner and ('Enable '..entry.owner..' in Control Center > Modules.') or entry.help)
        b:ClearAllPoints(); b:SetPoint('TOPLEFT',10,-y); b:Show(); y=y+H:FitButton(b,2)+5
    end
    for i=#entries+1,#menu.buttons do menu.buttons[i]:Hide(); menu.buttons[i].entry=nil end
    menu:SetSize(320,y+5); menu:SetFrameLevel((T:Call(launcher.GetFrameLevel,launcher) or 1)+100)
    menu:SetScale(math.min(1,(UIParent:GetHeight()-32)/(y+5)))
    menu:ClearAllPoints(); menu:SetPoint('TOPRIGHT',launcher,'BOTTOMRIGHT',0,-4); menu:Show()
end
function C:Attach(host,spec)
    if not host or type(host.HookScript)~='function' or self.hosts[host] or (host.IsForbidden and host:IsForbidden()) then return end
    local state={spec=spec}; self.hosts[host]=state
    self.watched[host]=true
    local function update()
        if InCombatLockdown() then return end
        if not state.button then
            state.visual=spec.visual and spec.visual(host) or host
            state.button=H:Button(state.visual,spec.label or 'ForeverSuite',0,0,spec.width or 128,function() C:Menu(host,spec.entries(host)) end)
            state.button.fsSuiteStyle=true; state.button.ignoreInLayout=true; state.button.fsLabel.fsSuiteStyle=true
            state.button:SetFrameLevel((T:Call(state.visual.GetFrameLevel,state.visual) or 1)+30); H:FitButton(state.button,1,24)
            state.button:ClearAllPoints()
            if spec.place then spec.place(state.button,host) else state.button:SetPoint('TOPRIGHT',state.visual,'TOPRIGHT',spec.x or -48,spec.y or -4) end
            H:SetHelp(state.button,'Tools for this screen. Your selection is kept when opening a tool.')
            if host.fsToolName then host.fsContextLauncher=state.button end
        end
        local visual=spec.visual and spec.visual(host) or host
        if visual~=state.visual then
            state.visual=visual; state.button:SetParent(visual); state.button:ClearAllPoints()
            state.button:SetFrameLevel((T:Call(visual.GetFrameLevel,visual) or 1)+30)
            if spec.place then spec.place(state.button,host) else state.button:SetPoint('TOPRIGHT',visual,'TOPRIGHT',spec.x or -48,spec.y or -4) end
        end
        if spec.place then state.button:ClearAllPoints(); spec.place(state.button,host) end
        state.button:SetShown((not spec.owner or FS:IsModuleEnabled(spec.owner)) and not host.fsContextHost and (not spec.visible or spec.visible(host)))
    end
    state.update=update
    host:HookScript('OnShow',function()
        update()
        if not C.queued then C.queued=true; C_Timer.After(0,function() C.queued=false; C:Discover() end) end
    end)
    host:HookScript('OnHide',function()
        if state.menu then state.menu:Hide() end
        if C.spellHost==host then C.spellHost=nil; C.spellID=nil end
        if C.nativeGuildHost==host then C.nativeGuildHost=nil; C.nativeGuildName=nil end
        C:HideHost(host)
    end)
    if shown(host) then update() end
end
function C:Initialize()
    if self.events then return end
    self.events=CreateFrame('Frame')
    for _,event in ipairs({'ADDON_LOADED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}) do FS:RegisterClientEvent(self.events,event) end
    self.events:SetScript('OnEvent',function(_,event)
        if event=='PLAYER_REGEN_DISABLED' then for _,state in pairs(C.hosts) do if state.menu then state.menu:Hide() end end; return end
        if C.queued then return end; C.queued=true
        C_Timer.After(0,function() C.queued=false; if not InCombatLockdown() then C:Discover() end end)
    end)
    self:Discover()
end
