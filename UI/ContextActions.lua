local _,FS=...
local C,T,H,E=FS.Context,FS.Tools,FS.HUD,FS.Extensions
local W=FS.modules.Workbench
local function entry(label,owner,run,help) return {label=label,owner=owner,run=run,help=help} end
local function tool(label,owner,view,prepare)
    return entry(label,owner,function(host) C:Open(host,view and 'Workbench' or owner,view,prepare) end)
end
local function view(label,name,owner) return tool(label,owner or 'Workbench',name) end
local function message(text) if text then FS:Print(text) end end
function C:ItemID(item)
    if type(item)~='table' then return end
    local id=item.id or item.itemID or FS.modules.Vendor:ItemID(item.link)
    if T:Number(id) and id>0 and id%1==0 then return id end
end
function C:SelectedItem(host)
    if host and (host==FS.modules.Bank.window or host==BankFrame) then return FS.modules.Bank.selected end
    return FS.modules.Bags.selected
end
function C:ItemEntries(host,item)
    return {entry('Add to checklist','Bags',function() C:ItemChecklist(host,item) end),
        entry('Set shopping goal','AuctionHouse',function() C:ItemShopping(host,item) end),
        entry('Track gear goal','GearAdvisor',function() C:ItemWishlist(host,item) end),
        entry('Never sell this item','Vendor',function()
            local id=C:ItemID(item); if not id then return message('Select an item first.') end
            FS.modules.Vendor:KeepItem(id); message('Item protected from junk selling.')
        end)}
end
function C:ItemChecklist(host,item)
    local id=self:ItemID(item)
    if not id then return message('Select an item first.') end
    E:Form('Add item '..id..' to a checklist',{{label='Checklist',value='Shopping',limit=32},{label='Target quantity',value=1,limit=6}},function(name,count)
        if not E:Checklist(name,id,tonumber(count)) then return false,'Enter a checklist name and a quantity from 1 to 100000.' end
        return true
    end,'Save goal',function() C:Open(host,'Workbench','Item checklists') end)
end
function C:ItemShopping(host,item)
    local id=self:ItemID(item)
    if not id then return message('Select an item first.') end
    if not FS:IsModuleEnabled('AuctionHouse') then return message('Enable Auction House to use its shopping list.') end
    E:Form('Shopping goal for item '..id,{{label='Target quantity',value=FS.db.auctionHouse.shopping[id] or 1,limit=6}},function(count)
        count=tonumber(count)
        if not T:Number(count) or count<1 or count>100000 or count%1~=0 then return false,'Enter a whole quantity from 1 to 100000.' end
        FS.db.auctionHouse.shopping[id]=count; return true
    end,'Save goal',function() C:Shopping(host) end)
end
function C:ItemWishlist(host,item)
    local id=self:ItemID(item)
    if not id then return message('Select an item first.') end
    self:Open(host,'Workbench','Gear Wishlist')
    self:Run(host,function() W:WishlistForm(nil,nil,id) end)
end
function C:Shopping(host)
    self:Open(host,'AuctionHouse',nil,function(m) m.contextShoppingOnly=true end)
end
function C:Gear(host,slot)
    self:Open(host,'Workbench','Gear Planner',function(m)
        m.contextSlot=slot; m.plannerLevel=1; m.page=1; m.selected=nil
        if m.window then m.window.search:SetText('') end
    end)
end
function C:BagEntries(host)
    local item=self:SelectedItem(host); local id=self:ItemID(item)
    local list={view('Item checklists','Item checklists','Bags'),view('Alt Tracker','Alt Tracker'),
        entry('Auction shopping list','AuctionHouse',function() C:Shopping(host) end),
        view('Loot session','Loot session','Loot')}
    if id then
        list[#list+1]=entry('Selected item: add to checklist','Bags',function() C:ItemChecklist(host,item) end)
        list[#list+1]=entry('Selected item: set shopping goal','AuctionHouse',function() C:ItemShopping(host,item) end)
        list[#list+1]=entry('Selected item: track gear goal','GearAdvisor',function() C:ItemWishlist(host,item) end)
    end
    return list
end
function C:SelectedRecipe()
    local root=ProfessionsFrame and ProfessionsFrame.CraftingPage or TradeSkillFrame
    local info=root and root.SchematicForm and T:Call(root.SchematicForm.GetRecipeInfo,root.SchematicForm)
    local id=type(info)=='table' and (info.recipeID or info.recipeId)
    local list=root and root.RecipeList
    id=id or (list and T:Call(list.GetSelectedRecipeID,list))
    id=id or (root and root.selectedRecipeID)
    if T:Number(id) then return id end
    local index=T:Call(GetTradeSkillSelectionIndex) or T:Call(GetCraftSelectionIndex)
    if T:Number(index) and index>0 then return nil,index end
end
function C:Profession(host,which,materials)
    local id,index=self:SelectedRecipe()
    self:Open(host,'Professions',nil,function(p)
        p:ClearPlan(); p.recipeView=which; p.contextFollowSelection=materials==true
        if materials then
            p:Build()
            for _,row in ipairs(p.rows) do
                if id and row.id==id or not id and index and row.index==index then p:OnSelect(row,1,true); break end
            end
        end
    end)
end
function C:ProfessionEntries(host)
    return {
        entry('Selected recipe: materials','Professions',function() C:Profession(host,1,true) end),
        entry('Skill-ups','Professions',function() C:Profession(host,2) end),
        entry('Crafting costs and market','Professions',function() C:Profession(host,3) end),
        entry('Recipe book and sources','Professions',function() C:Profession(host,4) end),
        entry('Level routes','Professions',function() C:Profession(host,5) end),
        view('Gathering recommendations','Profession recommendations','Professions'),
        view('Trainer information','Trainer preview','Professions'),
        entry('Auction shopping list','AuctionHouse',function() C:Shopping(host) end),
    }
end
function C:SelectedPlayer(kind,host)
    local module=FS.modules[kind]
    local selected=module and module.selected
    local scope=host or self.pendingHost
    if self.playerSelection and self.playerSelection.host==scope and self.playerSelection.kind==kind then return self.playerSelection.name end
    if kind=='Guild' and scope==self.nativeGuildHost and T:Text(self.nativeGuildName)~='' then return self.nativeGuildName end
    if W.window and W.window:IsShown() and (W:Data().view=='Recent groups' or W:Data().view=='Guild notes') then selected=W.selected or selected end
    local name=selected and (selected.name or (selected.member and selected.member.name) or selected.id)
    if T:Text(name)~='' and not name:find('[|%c]') and #name<=100 then return name end
    local index=kind=='Guild' and T:Call(GetGuildRosterSelection) or T:Call(C_FriendList and C_FriendList.GetSelectedFriend)
    if T:Number(index) and index>0 then
        if kind=='Guild' then name=T:Call(GetGuildRosterInfo,index)
        else local info=T:Call(C_FriendList and C_FriendList.GetFriendInfoByIndex,index); name=type(info)=='table' and info.name end
        if T:Text(name)~='' and not name:find('[|%c]') then return name end
    end
end
function C:PlayerAction(kind,invite)
    local name=self:SelectedPlayer(kind)
    if not name then return message('Select a player in the roster or recent-groups list first.') end
    if invite then T:Call(C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit,name)
    else T:Call(ChatFrame_SendTell,name) end
end
function C:GuildNotes(host)
    local name=self:SelectedPlayer('Guild')
    local key=name and E:PlayerKey(name)
    self:Open(host,'Workbench','Guild notes')
    if name then for _,row in ipairs(W.rows) do if row.name==name or row.id==name or row.id==key then W.selected=row; W:OnSelect(row); W:Render(); break end end end
end
function C:GuildEntries(host)
    local name=self:SelectedPlayer('Guild',host)
    local suffix=name and (' '..name) or ' selected member'
    return {entry('Private notes and favorites','Guild',function() C:GuildNotes(host) end),tool('Search guild roster','Guild'),
        entry('Whisper'..suffix,'Guild',function() C:PlayerAction('Guild') end),
        entry('Invite'..suffix,'Guild',function() C:PlayerAction('Guild',true) end)}
end
function C:SocialEntries()
    return {tool('Search friends','Social'),view('Recent groups','Recent groups','Social'),
        entry('Whisper selected player','Social',function() C:PlayerAction('Social') end),
        entry('Invite selected player','Social',function() C:PlayerAction('Social',true) end)}
end
function C:ChatEntries(host)
    return {view('Chat history','Chat history','Chat'),view('Highlight keywords','Chat keywords','Chat'),
        entry('Add a keyword','Chat',function()
            E:Form('Highlight a word in chat',{{label='Keyword',limit=64}},function(word)
                return E:AddKeyword(word),'Enter a new keyword with 2 to 64 characters.'
            end,'Add keyword',function() C:Open(host,'Workbench','Chat keywords') end)
        end),entry('Chat settings','Chat',function() FS:ConfigureModule('Chat') end)}
end
function C:SpellEntries(host)
    local id=self.spellHost==host and self.spellID
    local name=id and (T:Call(C_Spell and C_Spell.GetSpellName,id) or T:Call(GetSpellInfo,id))
    local list={tool('Tracked cooldowns','Cooldowns'),tool('Buff reminders','Buffs')}
    if T:Number(id) then
        list[#list+1]=entry('Track cooldown: '..(name or id),'Cooldowns',function()
            FS.modules.Cooldowns:Data().spells[id]='General'; C:Open(host,'Cooldowns')
        end)
        list[#list+1]=entry('Buff reminder: '..(name or id),'Buffs',function()
            FS.modules.Buffs:Data().reminders[id]=true; FS.modules.Buffs:UpdateReminder(); C:Open(host,'Buffs')
        end)
    else list[#list+1]={label='Hover a spell, then open this menu',enabled=false} end
    list[#list+1]=entry('Quick keybind mode','Bindings',function() FS.modules.Bindings:OpenQuickBindings() end)
    return list
end
function C:MapEntries(host)
    return {view('Route Library','Route Library','Map'),view('Waypoint queue','Waypoint queue','Map'),
        tool('Saved locations and lockouts','Map'),view('Gathering runs','Gathering runs','Map'),
        view('Rare sightings','Rare sightings','Map'),entry('Stop navigation','Map',function() FS.modules.Map:ClearNavigation() end)}
end
function C:JournalEntries()
    local instance=W.journalInstance
    return {view('Dungeon & Raid Journal','Dungeon & Raid Journal'),entry('Dungeon preparation','Workbench',function(host)
        if instance then
            local name=instance.name:sub(1,32); local targets=E:PreparationTargets(name)
            if not E:Data().preparation[name] then
                local ok,why=E:SavePreparation(name,targets.durability,targets.slots,targets.itemLevel)
                if not ok then return message(why) end
            end
            W.prepActivity=name
        end
        C:Open(host,'Workbench','Dungeon preparation')
    end),entry('Run Notes','Workbench',function(host) C:Run(host,function() W:Choose('Run Notes',instance) end) end),
        view('Gear Wishlist','Gear Wishlist','GearAdvisor'),tool('Saved lockouts','Map')}
end
function C:TargetEntries(host)
    return {entry('Appearance for this NPC','Nameplates',function()
        local id=E:NPCID('target'); if not id then return message('Target an NPC first.') end
        C:Open(host,'Workbench','NPC rules')
        W.window.input:SetText(tostring(id))
    end),view('Important casts','Important casts','Nameplates'),
        entry('Mark the current cast as important','Nameplates',function()
            local cast={T:Call(UnitCastingInfo,'target')}; local id=cast[9]
            if not cast[1] then cast={T:Call(UnitChannelInfo,'target')}; id=cast[8] end
            if not T:Number(id) then return message('Target an NPC with a readable active cast first.') end
            E:Data().importantSpells[id]=true; message('Cast added to important casts.')
        end)}
end
local function headerTools(button,host) button:SetPoint('TOPLEFT',host,'TOPLEFT',48,-4) end
local function guildTools(button,host)
    -- Keep a separate row outside the native title, list art and dropdowns.
    button:SetPoint('TOPRIGHT',host,'BOTTOMRIGHT',-12,-8)
    button:SetClampedToScreen(true)
end
local function native(name,owner,entries,extra)
    local labels={Professions='Crafting tools',Guild='Member tools',Social='Player tools',Mail='Mail tools',Loot='Loot tools',Quests='Quest tools'}
    local spec={name=name,owner=owner,entries=entries,label=labels[owner]}
    for key,value in pairs(extra or {}) do spec[key]=value end
    return spec
end
C.nativeSpecs={
    native('CharacterFrame',nil,function(host)
        return {tool('Gear Advisor','GearAdvisor'),entry('Gear Planner','GearAdvisor',function() C:Gear(host) end),
            view('Gear Wishlist','Gear Wishlist','GearAdvisor'),view('Alt Tracker','Alt Tracker'),
            entry('Character Overview','Character',function() FS.Beginner:ShowCharacterOverview() end)}
    end,{visual=function(host) return FS:IsModuleEnabled('Character') and FS.modules.Character.root or host end,label='Character tools',y=-12}),
    native('MerchantFrame','Vendor',function()
        return {tool('Review junk and item rules','Vendor'),view('Buyback','Buyback','Vendor'),
            entry('Repair gear','Vendor',function() FS.modules.Vendor:TryRepair(FS.modules.Vendor.repairConfirmation~=nil) end),
            entry('Buy planned supplies','Vendor',function() FS.modules.Vendor:StartRestock() end)}
    end),
    native('ProfessionsFrame','Professions',function(host) return C:ProfessionEntries(host) end),
    native('TradeSkillFrame','Professions',function(host) return C:ProfessionEntries(host) end),
    native('CraftFrame','Professions',function(host) return C:ProfessionEntries(host) end),
    native('AuctionHouseFrame','AuctionHouse',function(host) return {entry('Shopping list','AuctionHouse',function() C:Shopping(host) end),
        tool('Recorded prices','AuctionHouse',nil,function(m) m.contextShoppingOnly=nil end),entry('Scan all','AuctionHouse',function() FS.modules.AuctionHouse:StartFullScan() end)} end,{x=-184,y=-2,label='Shopping tools'}),
    native('AuctionFrame','AuctionHouse',function(host) return {entry('Shopping list','AuctionHouse',function() C:Shopping(host) end),tool('Recorded prices','AuctionHouse',nil,function(m) m.contextShoppingOnly=nil end)} end,{x=-184}),
    native('MailFrame','Mail',function() return {tool('Read and collect mail','Mail'),entry('Collect all','Mail',function()
        local mail=FS.modules.Mail; if mail.window then mail.window.search:SetText('') end; mail:Collect(true)
    end),entry('Stop collection','Mail',function() FS.modules.Mail:Stop('Collection stopped.') end)} end),
    native('WorldMapFrame','Map',function(host) return C:MapEntries(host) end,{place=headerTools,label='Map tools'}),
    native('QuestLogFrame','Quests',function() return {tool('Quest objectives','Quests'),view('Waypoint queue','Waypoint queue','Map'),entry('Stop navigation','Map',function() FS.modules.Map:ClearNavigation() end)} end),
    native('CommunitiesFrame','Guild',function(host) return C:GuildEntries(host) end,{place=guildTools}),
    native('GuildFrame','Guild',function(host) return C:GuildEntries(host) end,{place=guildTools}),
    native('ContactsFrame','Social',function() return C:SocialEntries() end),
    native('FriendsFrame','Social',function() return C:SocialEntries() end),
    native('SpellBookFrame',nil,function(host) return C:SpellEntries(host) end,{place=headerTools}),
    native('PlayerSpellsFrame',nil,function(host) return C:SpellEntries(host) end,{place=headerTools}),
    native('EncounterJournal',nil,function() return C:JournalEntries() end),
    native('LootFrame','Loot',function() return {view('Loot session','Loot session','Loot'),tool('Loot history and rolls','Loot')} end),
    native('EditModeManagerFrame','ActionBars',function() return {entry('Quick keybind mode','Bindings',function() FS.modules.Bindings:OpenQuickBindings() end),entry('Action bar display','ActionBars',function() FS:ConfigureModule('ActionBars') end),view('Layout presets','Layout presets')} end),
    native('DamageMeter','Combat',function() return {tool('Combat report','Combat'),view('Loot session','Loot session','Loot')} end,
        {label='Report',width=70,place=function(button,host) button:SetPoint('BOTTOMRIGHT',host,'BOTTOMRIGHT',-8,6) end,
        visible=function() for i=1,3 do local frame=_G['DamageMeterSessionWindow'..i]; if frame and frame:IsShown() then return false end end; return true end}),
    native('BankFrame','Bank',function(host) return C:BagEntries(host) end,{label='Bank tools'}),
    native('ClassTrainerFrame',nil,function() return {view('Available training','Trainer preview')} end,{label='Training tools'}),
    native('TrainerFrame',nil,function() return {view('Available training','Trainer preview')} end,{label='Training tools'}),
}
function C:OwnEntries(name,host)
    if name=='Bags' or name=='Bank' then return self:BagEntries(host) end
    if name=='Guild' then return self:GuildEntries(host) end
    if name=='Social' then return self:SocialEntries() end
    if name=='Professions' then return self:ProfessionEntries(host) end
    if name=='Map' then return self:MapEntries(host) end
    if name=='Workbench' then
        local current=W:Data().view
        if current=='Dungeon & Raid Journal' or current=='Dungeon preparation' or current=='Run Notes' or current=='Gear Wishlist' then return self:JournalEntries() end
        if current=='Guild notes' then return self:GuildEntries(host) end
        if current=='Recent groups' then return self:SocialEntries() end
    end
    return {view('Gear Planner','Gear Planner','GearAdvisor'),view('Gear Wishlist','Gear Wishlist','GearAdvisor'),view('Alt Tracker','Alt Tracker')}
end
function C:AttachOwn(name,module,frame)
    if not frame then return end
    self:Attach(frame,{owner=name,entries=function(host) return C:OwnEntries(name,host) end,
        label='More tools',width=104,place=function(button)
            if name=='Bags' and frame.sidebar then
                button:SetParent(frame.sidebar); button:SetText('Bag tools'); button:SetWidth(100); button:SetPoint('TOPRIGHT',frame.sidebar,'TOPRIGHT',-6,-5)
                frame.sidebarTitle:SetWidth(math.max(60,frame.sidebar:GetWidth()-116))
            elseif name=='Gear' then button:SetPoint('TOPLEFT',280,-12)
            elseif frame.fsToolName then button:SetPoint('TOPLEFT',236,-10)
            else button:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-48,-42) end
        end})
    if name=='Bags' and self.hosts[frame] then frame.fsContextLauncher=self.hosts[frame].button end
end
function C:Discover()
    if InCombatLockdown() then return end
    for _,spec in ipairs(self.nativeSpecs) do self:Attach(_G[spec.name],spec) end
    for _,name in ipairs({'Bags','Bank','Guild','Social','Professions','Map','Gear','Workbench'}) do
        local module=FS.modules[name]
        if module and module.CreateWindow and not module.fsContextCreate then
            module.fsContextCreate=true; local create=module.CreateWindow; local key=name
            module.CreateWindow=function(m,...) local f=create(m,...); C:AttachOwn(key,m,f); return f end
        end
        if module then self:AttachOwn(name,module,module.window) end
    end
    local xp=FS.WindowManager and FS.WindowManager.experience
    if xp and not xp.fsContextClick then
        xp.fsContextClick=true; xp:SetScript('OnMouseUp',function(_,button) if button=='LeftButton' then C:Open(xp,'Workbench','Leveling session') end end)
    end
    for _,state in pairs(self.hosts) do if state.button then state.update() end end
end
local function observeSpell(tooltip,data)
    local host=SpellBookFrame and SpellBookFrame:IsShown() and SpellBookFrame or PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and PlayerSpellsFrame
    if not host then return end
    local _,id=T:Call(tooltip.GetSpell,tooltip); id=id or (type(data)=='table' and data.id)
    if T:Number(id) and id>0 then C.spellID=id; C.spellHost=host end
end
local initialize=C.Initialize
function C:Initialize()
    initialize(self)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell,observeSpell)
    elseif GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript('OnTooltipSetSpell') then GameTooltip:HookScript('OnTooltipSetSpell',observeSpell) end
end
