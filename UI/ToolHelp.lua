local _,FS=...
local T,H,E=FS.Tools,FS.HUD,FS.Extensions

-- Short, task-specific copy shared by the directory and the live tool window.
T.moduleHelp={
    Map={summary="Saved pins and navigation",input="Pin name",placeholder="e.g. Meeting point",
        empty="No saved pins",hint="Save your current location to start navigating."},
    Quests={summary="Your active quests",empty="No quests to show",hint="Accept a quest or clear the search filter."},
    Loot={summary="Recent drops and active loot rolls",empty="No loot yet",hint="Loot an item or open Settings to change the view."},
    Buffs={summary="Your buffs and missing-buff reminders",input="Spell ID",placeholder="e.g. 21562",
        empty="No buffs to show",hint="Add a spell ID to track a missing buff."},
    Cooldowns={summary="Track your important abilities",input="Spell ID",placeholder="Enter an ability's spell ID",
        empty="No tracked abilities",hint="Add a spell ID below to start tracking."},
    Combat={summary="Damage, healing and group performance",empty="No combat data yet",hint="Complete a fight to view the recorded report."},
    Professions={summary="Recipes, materials and skill-up plans",input="Craft quantity",placeholder="1",
        empty="Open a profession",hint="Open a learned profession in the game, or switch to Level routes."},
    AuctionHouse={summary="Observed prices and your shopping list",input="Item ID and quantity",placeholder="e.g. 2589 20",
        empty="No items recorded",hint="Open an auction house and click Scan all, or add a shopping goal."},
    Social={summary="Friends and contacts",empty="No friends to show",hint="Use Contacts to open your friends list."},
    Guild={summary="Your guild roster",empty="No guild members to show",hint="Join a guild or refresh the roster."},
    QoL={summary="Leveling progress and quick actions",input="Player name",placeholder="Name-Realm",
        empty="No leveling data yet",hint="Earn experience to update your session."},
    Bank={summary="Your bank inventory",empty="Visit a banker",hint="Open your bank to view or move stored items."},
    Bindings={summary="Select an action, then press Bind",empty="No matching actions",hint="Try a bar name or clear the search."},
    Mail={summary="Your mailbox",empty="Visit a mailbox",hint="Open a mailbox to read mail and collect attachments."},
    MinimapButtons={summary="Manage your minimap addon buttons",empty="No addon buttons found",hint="Enable an addon with a minimap button, then refresh."},
    GearAdvisor={summary="Compare gear for your class and build",empty="No gear to compare",hint="Check your bags or open the Gear Planner."},
}

T.viewHelp={
    Settings={summary="Find and change individual options",empty="No matching settings",hint="Try a module name.",select={1,2,3}},
    Favorites={summary="Your saved setting shortcuts",empty="No favorite settings",hint="Find an option in Settings and click Favorite.",select={1,2,3}},
    Profiles={summary="Import, export and compare setups",input="Profile name",placeholder="Imported profile",select={1,2,3}},
    ["Next steps"]={summary="Continue your saved plans",empty="You're all caught up",hint="Add a gear goal, craft plan or route.",select={1,2,4}},
    ["Run Notes"]={summary="Your private boss reminders",empty="No run notes yet",hint="Add a boss name and a short reminder.",startLabel="Add your first note",
        start=function(m) m:Perform(1,""); end,select={2,3}},
    ["Gear Planner"]={summary="Find gear by slot and level",empty="No matching equipment",hint="Change the level or clear your search.",select={1,3}},
    ["Gear Wishlist"]={summary="Equipment you want to collect",empty="Your wishlist is empty",hint="Add a goal or browse the Dungeon Journal.",
        startLabel="Add a gear goal",start=function(m) m:Perform(1,"") end,select={2,3}},
    ["Dungeon & Raid Journal"]={summary="Dungeons, bosses and observed loot",empty="No instances available",hint="Try another filter or clear the search.",select={1}},
    ["Dungeon preparation"]={summary="Check your gear and supplies before a run",input="Activity name",placeholder="e.g. Ragefire Chasm",
        empty="Prepare your first run",hint="Enter a dungeon or raid name below."},
    ["Trainer preview"]={summary="Review available training",empty="Visit a trainer",hint="Open a trainer to see available services."},
    ["Alt Tracker"]={summary="Your characters, with their gear, professions and bags",empty="No characters yet",hint="Log in on a character or record it to get started.",
        startLabel="Record this character",start=function(m) m:Perform(1,""); m:Refresh() end,select={2,3}},
    ["Layout presets"]={summary="Save your current interface arrangement",input="Preset name",placeholder="e.g. Farming",
        empty="No saved layouts",hint="Enter a name to save your current layout.",select={2,3}},
    Accessibility={summary="Text size and readable colors",select={1}},
    Alerts={summary="Sounds, popups and notification history",select={1,2,3,4}},
    ["Rare sightings"]={summary="Rares and elites you encounter",empty="No sightings yet",hint="Enable tracking, then target or mouse over a rare.",
        startLabel="Tracking settings",start=function(m) m:ShowViewSettings("Rare sightings") end,select={3}},
    ["Notification Center"]={summary="Your recent ForeverSuite notifications",empty="No notifications yet",hint="New notifications appear here during this session."},
    ["NPC rules"]={summary="Nameplate designs for specific NPCs",input="NPC ID (or use your target)",placeholder="Target an NPC or enter its ID",
        empty="No saved NPC rules",hint="Target an NPC, then save your current nameplate design.",select={2,3}},
    ["Important casts"]={summary="Highlight spells you want to notice",input="Spell ID",placeholder="Enter a spell ID",
        empty="No highlighted spells",hint="Add a spell ID below to highlight its cast.",select={3}},
    ["Chat keywords"]={summary="Highlight words in chat",input="Keyword",placeholder="e.g. your character name",
        empty="No keywords yet",hint="Enter a word below to highlight matching messages.",select={3}},
    ["Chat history"]={summary="Optional message capture for this session"},
    ["Guild notes"]={summary="Private notes and favorite guild members",input="Private note",placeholder="Select a member, then write a note",select={1,2,3}},
    ["Recent groups"]={summary="People you've played with",empty="No recent group members",hint="Start tracking to record your party and raid members.",select={3}},
    ["Item checklists"]={summary="Track the items you still need",empty="No checklist items",
        hint="Add an item and the quantity you want to carry.",startLabel="Add a checklist item",start=function(m) m:Perform(1,"") end,select={2,3}},
    Buyback={summary="Recover items from the current merchant",empty="No buyback items",hint="Visit the merchant where you sold the item.",select={1}},
    ["Loot session"]={summary="Your loot from this play session"},
    ["Gathering runs"]={summary="Record loot while following a route",empty="Choose a route first",hint="Create or import a route in Route Library.",
        startLabel="Open Route Library",start=function(m) m:Choose("Route Library") end,select={1,3}},
    ["Profession recommendations"]={summary="Pick a profession guide",select={1}},
    ["Route Library"]={summary="Save, import and manage routes",input="Route name",placeholder="e.g. Durotar copper",select={2,3,4}},
    ["Waypoint queue"]={summary="Follow your saved stops in order",empty="No stops in your queue",hint="Save a location pin, then add it here.",
        startLabel="Save a location pin",start=function() FS:OpenModule("Map") end,select={2}},
    ["Leveling session"]={summary="Experience gains and time to level"},
    Maintenance={summary="Troubleshooting and recent layout changes"},
}

T.viewSettings={
    ["Gear Planner"]={owner="GearAdvisor",keys={"preset","role","minimum","showAll"}},
    ["Gear Wishlist"]={alert="Wishlist acquired"},
    ["Run Notes"]={alert="Run note"},
    ["Rare sightings"]={alert="Rare or elite",extra="discovery"},
    ["Waypoint queue"]={owner="Map",keys={"navigation","arrival","trail","nativeWaypoint"},alert="Waypoint arrival"},
    ["Route Library"]={owner="Map",keys={"navigation","worldRoute","worldPins","arrival"}},
    ["Gathering runs"]={owner="Map",keys={"navigation","arrival","trail"}},
    ["Dungeon preparation"]={preparation=true},
    ["Chat keywords"]={extra="keywords",alert="Keyword"},
    ["Chat history"]={extra="chat"},
    ["Guild notes"]={extra="guild"},
    ["Recent groups"]={extra="groups"},
    ["Loot session"]={owner="Loot",keys={"recordHistory","historyLimit","showTime"}},
    ["Leveling session"]={owner="QoL",keys={"showXP","showToNext","showRested"}},
    ["NPC rules"]={designer=true},
    ["Important casts"]={alert="Important cast"},
    Alerts={alert=true},
    Accessibility={fonts=true},
}

local function optionText(label,value)
    if type(value)=="boolean" then value=value and "On" or "Off" end
    return label..": "..tostring(value)
end

function FS.modules.Workbench:ShowViewSettings(view,category)
    local spec=T.viewSettings[view]
    if not spec or not FS.Beginner:Allowed() then return false end
    local entries={}
    local function add(label,ref,key,values,changed)
        entries[#entries+1]={text=optionText(label,ref[key]),run=function()
            if not FS.Beginner:Allowed() then return end
            if values then
                local index=1
                for i,value in ipairs(values) do if value==ref[key] then index=i%#values+1; break end end
                ref[key]=values[index]
            else ref[key]=not ref[key] end
            if changed then changed() end
            FS.modules.Profiles:PersistCurrent()
            self:ShowViewSettings(view,category)
        end}
    end
    if spec.owner then
        local module=FS.modules[spec.owner]
        local wanted={}
        for _,key in ipairs(spec.keys) do wanted[key]=true end
        for _,option in ipairs(module.options or {}) do if wanted[option.key] then
            add(option.label,module:Data(),option.key,option.values,function() module:SettingsChanged() end)
        end end
    end
    local extra=E:Data()
    if spec.extra=="discovery" then
        add("Track rares",extra.discovery,"enabled",nil,function() E:SyncDiscovery() end)
        add("Include elites",extra.discovery,"elites")
        add("Show portrait",extra.discovery,"portrait")
    elseif spec.extra=="keywords" then
        add("Highlight keywords",extra,"keywordsEnabled",nil,function() E:UpdateFilters() end)
    elseif spec.extra=="chat" then
        add("Capture this session",extra,"captureChat",nil,function() E:UpdateFilters() end)
    elseif spec.extra=="guild" then
        add("Show private notes",extra,"showPrivateNotes")
    elseif spec.extra=="groups" then
        add("Remember group members",extra,"trackGroups",nil,function() E:GroupChanged() end)
    end
    if spec.preparation then
        local activity=self.prepActivity
        entries[#entries+1]={text=activity and "Edit targets for "..activity or "Choose an activity",run=function()
            self:Choose("Dungeon preparation")
            if activity then self:Perform(2,"") end
        end}
    end
    if spec.fonts then
        entries[#entries+1]={text="Text & Fonts",run=function() FS.Typography.scope="All modules"; FS.Typography:Show() end}
    end
    if spec.designer then
        entries[#entries+1]={text="Open nameplate designer",run=function() FS.modules.Nameplates:ShowWindow() end}
    end
    if spec.alert then
        category=type(spec.alert)=="string" and spec.alert or category
        if not category then
            entries[#entries+1]={text="Choose a notification type",run=function() self:Choose("Alerts") end}
        else
            local alert=E:AlertOptions(category,true)
            add("Sound",alert,"sound",{"Silent","Bell","Ready","Warning"})
            add("Channel",alert,"channel",{"SFX","Master","Dialog"})
            add("Show popup",alert,"popup")
            add("Keep history",alert,"history")
        end
    end
    entries[#entries+1]={text="Open "..view,run=function() self:Choose(view) end}
    local f=FS.Beginner:Window("toolSettings",view.." settings")
    return FS.Beginner:Present(f,entries,category or "Changes save automatically.")
end

function T:GetToolHelp(module)
    return (module.name=="Workbench" and self.viewHelp[module:Data().view]) or self.moduleHelp[module.name] or {}
end

local function positiveID(text)
    local id=tonumber(text)
    return T:Number(id) and id>0 and id%1==0
end

local moduleActions={
    Map=function(m,i,text) return i==1 or i==4 or (m.selected and m.selected.pin~=nil) end,
    Buffs=function(m,i,text) return i==1 and positiveID(text) or i==2 and m.selected and m:Data().reminders[m.selected.id]~=nil end,
    Cooldowns=function(m,i,text) return i==1 and positiveID(text) or i~=1 and m.selected~=nil end,
    Social=function(m,i) return i~=1 or m.selected and m.selected.name~=nil end,
    Guild=function(m,i) return i~=1 or m.selected and m.selected.name~=nil end,
    MinimapButtons=function(m,i) return i~=2 or m.selected~=nil end,
    Bindings=function(m,i) return i==3 or m.selected~=nil end,
    QoL=function(m,i,text) return i~=1 or text:find("%S")~=nil and not InCombatLockdown() end,
    AuctionHouse=function(m,i,text)
        if i==1 then
            local id,count=text:match("^(%d+)%s*(%d*)$")
            return positiveID(id) and (count=="" or tonumber(count)>0 and tonumber(count)<=100000)
        end
        if i==2 then return m.selected and m:Data().shopping[m.selected.id]~=nil end
        if i==3 then return m.open==true end
        return m.open and m.selected~=nil
    end,
    Mail=function(m,i)
        return (i==3 and m.collecting) or (i~=3 and m.atMailbox and not m.collecting
            and (i==2 and (m.window.visibleRows or 0)>0 or m.selected~=nil))
    end,
    Loot=function(m,i)
        local row=m.selected
        if not row or not row.roll or not m.rolls[row.roll] then return false end
        return i==3 or i==1 and row.need or i==2 and row.greed
    end,
    GearAdvisor=function(m,i,text) return i~=2 or m:Data().view=="Weights" and m.selected and m.selected.stat and T:Number(tonumber(text)) end,
    Professions=function(m,i)
        if i==1 then return m.materials or m.levelRoute~=nil end
        if i==2 then return m.selected~=nil or m.planRecipe~=nil or m.levelRoute~=nil end
        if i==3 then return m.planRecipe~=nil or m.levelRoute~=nil end
        return true
    end,
}

function FS.modules.Workbench:ActionAvailable(index)
    local view,r=self:Data().view,self.selected
    local text=self.window and self.window.input:GetText():match("^%s*(.-)%s*$") or ""
    local data=E:Data()
    if view=="Dungeon preparation" then return self.prepActivity~=nil or index==1 and (text~="" or r~=nil) end
    if view=="Profiles" then
        if index==1 then return r and (r.kind=="export" or r.kind=="import" or r.kind=="profile") end
        if index==2 then return r and (r.kind=="profile" or r.kind=="backup") end
        return r and (r.kind=="profile" or r.kind=="assignment")
    end
    if view=="Next steps" then
        if index==1 then return r and (r.module~=nil or r.view~=nil) end
        if index==2 or index==4 then return r and r.goal~=nil end
    end
    if view=="Dungeon & Raid Journal" and index==2 then return self.journalInstance~=nil or r and r.instance~=nil end
    if view=="Waypoint queue" then
        if index==1 then
            if r and r.kind=="pin" then return not E.gathering and #data.waypointQueue<50 end
            return #data.waypointQueue>0
        end
        if index==2 then return not E.gathering and r and r.kind=="queue" and r.index>1 end
        if index==3 then return not E.gathering and ((r and r.kind=="queue") or E.queueActive or FS.modules.Map.destination~=nil) end
    elseif view=="Gathering runs" then
        if index==1 then return not E.gathering and r and r.kind=="gathering-route" end
        if index==2 then return E.gathering~=nil end
        if index==3 then return r and r.run~=nil end
    elseif view=="Route Library" then
        if index==1 then return text~="" and #data.waypointQueue>0 end
        if index==2 then return r and (r.kind=="route" or r.kind=="route-recommendations") end
        if index==3 then return r and (r.name~=nil or r.kind=="route-import" or r.kind=="route-gathering" or r.kind=="route-waypoints") end
        if index==4 then return r and r.name~=nil end
    elseif view=="Trainer preview" then
        if index==2 then return not self.training and #self.rows>0 end
        if index==3 then return self.training~=nil end
    elseif view=="Chat history" then
        if index>1 then return #E.chat>0 end
    elseif view=="Rare sightings" then return index~=3 or r and r.sighting~=nil
    elseif view=="Notification Center" then return index~=2 or #E.notifications>0
    elseif view=="Buyback" then return index~=1 or FS.modules.Vendor.merchantOpen and r~=nil
    elseif view=="NPC rules" and index==1 then return positiveID(text) or E:NPCID("target")~=nil
    elseif view=="Important casts" and index==1 then return positiveID(text)
    elseif view=="Chat keywords" and index==1 then return #text>=2 and #text<=64
    elseif view=="Layout presets" and index==1 then return text~=""
    elseif view=="Settings" or view=="Favorites" then
        if index==2 then return r and (type(r.ref[r.key])=="boolean" or r.option.values~=nil or r.option.min~=nil) end
    end
    return true
end

function FS.modules.Workbench:UpdateActionLabels()
    local view,r=self:Data().view,self.selected
    local buttons=self.window.actionButtons
    if view=="Waypoint queue" then
        buttons[1]:SetText(r and r.kind=="pin" and "Add stop" or "Start route")
        buttons[3]:SetText(r and r.kind=="queue" and "Remove stop" or "Stop navigation")
    elseif view=="Dungeon preparation" and not self.prepActivity then
        buttons[1]:SetText(self.window.input:GetText()~="" and "Create / open activity" or "Open activity")
    elseif view=="Route Library" then
        buttons[2]:SetText(r and r.kind=="route-recommendations" and "Browse guides" or "Load route")
        buttons[3]:SetText(r and r.name and "Share route" or r and r.kind=="route-gathering" and "Gathering runs" or "Import route")
    end
end

local function brief(value)
    value=T:Text(value):gsub("\n+"," ")
    if #value<=112 then return value end
    return (value:sub(1,109):match("^(.*)%s") or value:sub(1,109)).."..."
end

function T:UpdateToolControls(module,count,pages)
    local f=module.window
    if not f or not f:IsShown() or f.fsChangingView then return end
    local help=self:GetToolHelp(module)
    if module.UpdateActionLabels then module:UpdateActionLabels() end
    f.heading:SetText(module.name=="Workbench" and module:Data().view or module.title)
    f.summary:SetText(help.summary or module.title)
    H:SetHelp(f.summary,module.description)
    local status=module.noticeUntil and GetTime()<module.noticeUntil and module.notice or module.status
    f.status:SetText(brief(status))
    H:SetHelp(f.status,status)
    local input=help.input
    local placeholder=help.placeholder
    if module.name=="Workbench" and module:Data().view=="Dungeon preparation" and module.prepActivity then input=nil end
    if module.name=="GearAdvisor" then input=module:Data().view=="Weights" and "Stat weight" or nil end
    if module.name=="Professions" and module.recipeView==5 then input="Skill range"; placeholder="e.g. 75 150" end
    f.input:SetShown(input~=nil)
    f.inputLabel:SetShown(input~=nil)
    f.inputLabel:SetText(input or "")
    f.inputHint:SetText(placeholder or "")
    f.inputHint:SetShown(f.input:GetText()=="")
    f.searchHint:SetShown(f.search:GetText()=="")
    if count then
        local empty=count==0
        f.emptyTitle:SetShown(empty); f.emptyText:SetShown(empty)
        f.emptyAction:SetShown(empty and help.start~=nil and f.search:GetText()=="")
        f.emptyTitle:SetText(f.search:GetText()~="" and "No matches" or help.empty or "Nothing here yet")
        f.emptyText:SetText(f.search:GetText()~="" and "Try another search or clear the filter." or help.hint or "Use an action below to get started.")
        f.emptyAction:SetText(help.startLabel or "Get started")
        f.previous:SetEnabled((module.page or 1)>1)
        f.next:SetEnabled((module.page or 1)<pages)
        f.previous:SetShown(pages>1); f.next:SetShown(pages>1); f.pageLabel:SetShown(pages>1)
    end
    for i,button in ipairs(f.actionButtons) do
        local available=true
        for _,index in ipairs(help.select or {}) do if index==i and not module.selected then available=false end end
        if module.ActionAvailable then available=available and module:ActionAvailable(i) end
        if moduleActions[module.name] then available=available and moduleActions[module.name](module,i,f.input:GetText()) end
        button:SetEnabled(not not available)
        H:SetHelp(button,available and button:GetText() or "Select an entry first, or complete the required step.")
    end
    f.toolSettings:SetShown(module.name~="Workbench" or self.viewSettings[module:Data().view]~=nil)
end
