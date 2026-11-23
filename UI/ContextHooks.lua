local _,FS=...
local C,T,H,E=FS.Context,FS.Tools,FS.HUD,FS.Extensions
local W=FS.modules.Workbench
local function action(label,owner,run) return {label=label,owner=owner,run=run} end
function C:BindExisting(host,button,entries)
    if not host or not button or button.fsContextRight then return end
    button.fsContextRight=true; button:RegisterForClicks('LeftButtonUp','RightButtonUp')
    self.hosts[host]={button=button,visual=host,spec={entries=entries},update=function() end}
    local original=button:GetScript('OnClick')
    button:SetScript('OnClick',function(b,mouse,...)
        if mouse=='RightButton' then C:Menu(host,entries(host),b)
        elseif original then original(b,mouse,...) end
    end)
    host:HookScript('OnHide',function()
        local state=C.hosts[host]; if state and state.menu then state.menu:Hide() end
        C:HideHost(host)
    end)
end
function C:QuestEntries(host,row)
    return {action('Navigate to this quest','Map',function()
        if not row then return end
        FS.modules.Quests:Track(row)
    end),action('Add quest destination to queue','Map',function()
        if not row then return end
        local point=FS.modules.Map:QuestDestination(row)
        if not point then FS:Print('The game has no known map location for this quest.'); return end
        local queue=E:Data().waypointQueue
        if #queue>=50 then FS:Print('Your waypoint queue is full.'); return end
        queue[#queue+1]=E.Copy(point); FS:Print('Quest destination added to your waypoint queue.')
    end),action('Waypoint queue','Map',function() C:Open(host,'Workbench','Waypoint queue') end),
        action('Stop navigation','Map',function() FS.modules.Map:ClearNavigation() end)}
end
function C:ActionBarEntries()
    local A=FS.modules.ActionBars
    return {action('Quick keybind mode','Bindings',function() FS.modules.Bindings:OpenQuickBindings() end),
        action('Mouseover: '..(FS.db.actionBars.mouseover and 'On' or 'Off'),'ActionBars',function()
            FS.db.actionBars.mouseover=not FS.db.actionBars.mouseover; A:SettingsChanged()
        end),action('Cycle idle opacity','ActionBars',function()
            local values={100,50,10}; local current=FS.db.actionBars.fade; local index=1
            for i,value in ipairs(values) do if value==current then index=i%#values+1; break end end
            FS.db.actionBars.fade=values[index]; A:SettingsChanged()
        end)}
end
local discover=C.Discover
function C:Discover()
    discover(self)
    if InCombatLockdown() then return end
    local friends=C_FriendList
    if friends and type(friends.SetSelectedFriend)=='function' and self.friendAPI~=friends then
        self.friendAPI=friends
        hooksecurefunc(friends,'SetSelectedFriend',function(index)
            local info=T:Call(friends.GetFriendInfoByIndex,index)
            local host=ContactsFrame and T:Call(ContactsFrame.IsShown,ContactsFrame) and ContactsFrame or FriendsFrame
            if host and type(info)=='table' and T:Text(info.name)~='' then C.playerSelection={host=host,kind='Social',name=info.name} end
        end)
    end
    local character=FS.modules.Character
    local bags=FS.modules.Bags
    local inventory=bags.window
    if inventory and inventory.itemMore and not inventory.itemPlanning then
        inventory.itemPlanning=H:Button(inventory.itemPanel,'Plan item',0,0,92,function()
            local selected=bags.selected
            if C:ItemID(selected) then C:Menu(inventory,C:ItemEntries(inventory,selected),inventory.itemPlanning) end
        end)
        inventory.itemPlanning:ClearAllPoints(); inventory.itemPlanning:SetPoint('TOPRIGHT',inventory.itemMore,'TOPRIGHT',0,0)
        inventory.itemPlanning.fsSuiteStyle=true; inventory.itemPlanning.ignoreInLayout=true
        inventory.itemPlanning:SetFrameLevel(inventory.itemMore:GetFrameLevel()+2)
        H:SetHelp(inventory.itemPlanning,'Planning tools for this item: checklist, auction shopping and gear goals.')
    end
    local bank=FS.modules.Bank
    for _,button in ipairs(bank.window and bank.window.grid or {}) do if not button.fsContextItem then
        button.fsContextItem=true; button:RegisterForClicks('LeftButtonUp','MiddleButtonUp')
        local pickup=button:GetScript('OnClick')
        button:SetScript('OnClick',function(b,mouse,...)
            if mouse=='MiddleButton' then
                if C:ItemID(b.row) then bank.selected=b.row; C:Menu(bank.window,C:ItemEntries(bank.window,b.row),b) end
            elseif pickup then pickup(b,mouse,...) end
        end)
        button:HookScript('OnEnter',function() GameTooltip:AddLine('Middle-click: item planning tools.',.55,.85,1,true); GameTooltip:Show() end)
    end end
    local memberList=CommunitiesFrame and CommunitiesFrame.MemberList
    if memberList and type(memberList.OnClubMemberButtonClicked)=='function' and not memberList.fsContextSelection then
        memberList.fsContextSelection=true
        hooksecurefunc(memberList,'OnClubMemberButtonClicked',function(_,button)
            local root=CommunitiesFrame
            local guild=T:Call(C_Club and C_Club.GetGuildClubId)
            local club=root and T:Call(root.GetSelectedClubId,root)
            if not guild or club~=guild then C.nativeGuildName=nil; return end
            local info=button and T:Call(button.GetMemberInfo,button)
            C.nativeGuildName=type(info)=='table' and T:Text(info.name) or nil; C.nativeGuildHost=root
            if T:Text(C.nativeGuildName)~='' then C.playerSelection={host=root,kind='Guild',name=C.nativeGuildName} end
        end)
    end
    local crafting=ProfessionsFrame and ProfessionsFrame.CraftingPage or TradeSkillFrame
    local schematic=crafting and crafting.SchematicForm
    if schematic and type(schematic.Init)=='function' and not schematic.fsContextSelection then
        schematic.fsContextSelection=true
        hooksecurefunc(schematic,'Init',function()
            if C.recipeQueued then return end; C.recipeQueued=true
            C_Timer.After(0,function()
                C.recipeQueued=false; local p=FS.modules.Professions
                if p.contextFollowSelection and (p.recipeView or 1)==1 and p.window and p.window.fsContextHost and p.window:IsShown() then
                    local id=C:SelectedRecipe()
                    if id and (not p.planRecipe or p.planRecipe.id~=id) then C:Profession(p.window.fsContextHost,1,true) end
                end
            end)
        end)
    end
    for _,button in pairs(character.slots or {}) do if not button.fsContextSlot then
        button.fsContextSlot=true
        button:HookScript('OnClick',function(b,mouse)
            if mouse=='MiddleButton' then C:Gear(CharacterFrame,b.slot) end
        end)
        button:HookScript('OnEnter',function()
            GameTooltip:AddLine('Middle-click: plan gear for this slot.',.55,.85,1,true); GameTooltip:Show()
        end)
    end end
    local tracker=FS.modules.Quests.tracker
    if tracker then
        if tracker.log and not tracker.log.fsContextLog then
            tracker.log.fsContextLog=true; tracker.log:SetScript('OnClick',function() C:Open(tracker,'Quests') end)
        end
        for _,cell in ipairs(tracker.cards or {}) do
            if cell.heading then C:BindExisting(tracker,cell.heading,function(host) return C:QuestEntries(host,cell.row) end) end
        end
    end
    local controls=FS.modules.Map.worldControls
    if controls and controls.routes and not controls.routes.fsContextRoutes then
        controls.routes.fsContextRoutes=true
        controls.routes:SetScript('OnClick',function() C:Open(controls:GetParent(),'Workbench','Route Library') end)
    end
    for i=1,10 do
        local chat=_G['ChatFrame'..i]
        if chat then C:Attach(chat,{owner='Chat',label='Chat tools',width=104,entries=function(host) return C:ChatEntries(host) end,
            place=function(button,host) button:SetPoint('BOTTOMRIGHT',host,'TOPRIGHT',0,36) end}) end
    end
    local unit=FS.modules.UnitFrames.frames and FS.modules.UnitFrames.frames.target
    if unit then C:Attach(unit,{owner='Nameplates',label='...',width=24,entries=function(host) return C:TargetEntries(host) end,x=-2,y=-2}) end
    local collector=FS.modules.MinimapButtons
    if collector.button then
        self:BindExisting(collector.button,collector.button,function(host)
            return {action('Manage addon icons','MinimapButtons',function() C:Open(host,'MinimapButtons') end),
                action('Rescan addon icons','MinimapButtons',function() collector:Scan() end),
                action('Include / exclude selected icon','MinimapButtons',function()
                    if not collector.selected then FS:Print('Select an icon in Manage addon icons first.'); return end
                    collector.actions[2].run(collector); collector:Refresh()
                end)}
        end)
    end
    for _,name in ipairs({'DamageMeterSessionWindow1','DamageMeterSessionWindow2','DamageMeterSessionWindow3'}) do
        self:Attach(_G[name],{owner='Combat',label='Report',width=70,place=function(button,host)
            button:SetPoint('BOTTOMRIGHT',host,'BOTTOMRIGHT',-8,6)
        end,entries=function()
            return {action('Combat report','Combat',function(host) C:Open(host,'Combat') end),
                action('Current / overall session','Combat',function() FS.modules.Combat.actions[3].run(FS.modules.Combat); FS.modules.Combat:Refresh() end)}
        end})
    end
    for host,state in pairs(self.hosts) do
        if state.spec.name=='EditModeManagerFrame' then state.spec.entries=function() return C:ActionBarEntries() end end
    end
end
function C:WrapNativeOpen(name,resolver)
    local module=FS.modules[name]
    if not module or module.fsContextOpen then return end
    module.fsContextOpen=true; local original=module.ShowWindow
    module.ShowWindow=function(m,...)
        local host=resolver()
        if host and host:IsShown() and not C.pendingHost then
            local args={...}
            return C:Run(host,function()
                original(m,unpack(args))
                if m.window and m.window:IsShown() and not m.window.fsContextHost then FS:CloseOtherWindows(m.window) end
                if m.window and m.window.fsContextHost and m.window.LayoutText then m.window:LayoutText() end
            end)
        end
        return original(m,...)
    end
end
local initialize=C.Initialize
function C:Initialize()
    if self.hooksInitialized then return end
    self.hooksInitialized=true; initialize(self)
    self:WrapNativeOpen('TalentAdvisor',function() return FS.modules.TalentAdvisor.nativeFrame end)
    self:WrapNativeOpen('Mail',function() return MailFrame end)
    self:WrapNativeOpen('Vendor',function() return MerchantFrame end)
    local selected=W.OnSelect
    W.OnSelect=function(module,row)
        selected(module,row)
        local host=module.window and module.window.fsContextHost
        if host and row and module:Data().view=='Guild notes' and T:Text(row.key)~='' then
            C.playerSelection={host=host,kind='Guild',name=row.key}
        elseif host and row and module:Data().view=='Recent groups' and T:Text(row.id)~='' then
            C.playerSelection={host=host,kind='Social',name=row.id}
        end
    end
    for _,event in ipairs({'TRADE_SKILL_LIST_UPDATE','CRAFT_UPDATE','UPDATE_CHAT_WINDOWS'}) do FS:RegisterClientEvent(self.events,event) end
    local previous=self.events:GetScript('OnEvent')
    self.events:SetScript('OnEvent',function(frame,event,...)
        if event=='TRADE_SKILL_LIST_UPDATE' or event=='CRAFT_UPDATE' then
            local p=FS.modules.Professions
            if p.contextFollowSelection and (p.recipeView or 1)==1 and p.window and p.window.fsContextHost and p.window:IsShown() then
                local id,index=C:SelectedRecipe()
                local current=p.planRecipe
                if id and (not current or current.id~=id) or index and (not current or current.index~=index) then
                    C:Profession(p.window.fsContextHost,1,true)
                end
            end
        else previous(frame,event,...) end
    end)
end
