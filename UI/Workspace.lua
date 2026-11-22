local _, FS = ...
local H = FS.HUD
local W = {}
FS.Workspace = W

-- Each shortcut opens the same live window or Workbench view used elsewhere.
local shortcuts = {
    {"bags", "Bags", "Open Bags"},
    {"map", "Map", "Open map tools"},
    {"gear", "GearAdvisor", "Open Gear Advisor"},
    {"talents", "TalentAdvisor", "Open Talent Advisor", "Choose builds, plan your next talent and link gear priorities.", function() FS.modules.TalentAdvisor:ShowWindow() end,"Talents"},
    {"mail", "Mail", "Open mail tools"},
    {"vendor", "Vendor", "Review vendor items"},
    {"quests", "Quests", "Open quest log"},
    {"character", "Character", "Open Character Info", "View equipment, stats, reputation and skills.",
        function()
            if not CharacterFrame or InCombatLockdown() then return end
            FS:CloseOtherWindows(CharacterFrame)
            if ShowUIPanel then ShowUIPanel(CharacterFrame) else CharacterFrame:Show() end
        end},
    {"overview", nil, "Character Overview", "See your level, gold, professions, equipment level and guild together.",
        function() FS.Beginner:ShowCharacterOverview() end, "Character"},
    {"journal", nil, "Dungeon & Raid Journal", "Browse dungeons, bosses and loot for your level.", "Dungeon & Raid Journal", "Guide"},
    {"prep", nil, "Dungeon preparation", "Build a checklist for your next dungeon or raid.", "Dungeon preparation", "Guide"},
    {"routes", "Map", "Route Library", "Browse, save and follow routes for professions and travel.", "Route Library"},
    {"waypoints", "Map", "Waypoint queue", "Add, reorder and follow saved destinations.", "Waypoint queue"},
    {"gathering", "Map", "Gathering runs", "Record a gathering run and review the items collected.", "Gathering runs"},
    {"rares", "Map", "Rare sightings", "Review observed rare creatures and their last known locations.", "Rare sightings"},
    {"runNotes", nil, "Run Notes", "Keep notes from your dungeon and raid runs.", "Run Notes", "Guide"},
    {"planner", "GearAdvisor", "Gear Planner", "Compare equipment by slot, class, level and source.", "Gear Planner"},
    {"wishlist", "GearAdvisor", "Gear Wishlist", "Track equipment you're looking for and mark it acquired.", "Gear Wishlist"},
    {"recipes", "Professions", "Browse recipes"},
    {"trainers", "Professions", "Trainer preview", "Check known trainers and the recipes they teach.", "Trainer preview"},
    {"stock", nil, "Alt Tracker", "Review your characters, their gear, professions and bags.", "Alt Tracker", "Character"},
    {"checklists", "Bags", "Item checklists", "Make a checklist and track the items you still need.", "Item checklists"},
    {"buyback", "Vendor", "Buyback", "Review items you can buy back from the current merchant.", "Buyback"},
    {"loot", "Loot", "Loot session", "Review recent drops and the value of your loot.", "Loot session"},
    {"chat", "Chat", "Chat history", "Look up messages if you have enabled chat history capture.", "Chat history"},
    {"keywords", "Chat", "Chat keywords", "Manage the words that highlight matching messages.", "Chat keywords"},
    {"guildNotes", "Guild", "Guild notes", "Keep private notes about your guild members.", "Guild notes"},
    {"groups", "Social", "Recent groups", "Review group members recorded when group history is enabled.", "Recent groups"},
    {"leveling", "QoL", "Leveling session", "Track your experience, gains and time played.", "Leveling session"},
    {"alerts", nil, "Alerts", "Choose when ForeverSuite shows its alerts.", "Alerts", "Help"},
    {"notifications", nil, "Notification Center", "Review recent ForeverSuite notifications.", "Notification Center", "Help"},
    {"recommendations", "Professions", "Profession recommendations", "Read skill-up and gathering suggestions.", "Profession recommendations"},
    {"layout", nil, "Layout Presets", "Preview predefined layouts for different screens and play styles.",
        function() FS.Installer:ShowLayouts() end, "Grid"},
}

local function canOpen(tool)
    return not tool.owner or FS:IsModuleEnabled(tool.owner)
end

function W:Build(frame)
    local host = CreateFrame("Frame", nil, frame.bodyContent)
    host:SetPoint("TOPLEFT")
    host:SetSize(916, 1)
    self.host = host
    frame.profiles:SetParent(host)
    self.heading = FS.Widgets:Label(host, "ForeverSuiteFontLarge")
    self.heading:SetJustifyH("LEFT")
    self.note = H:Label(host, "", 24, 0, 650)
    self.browse = H:Button(host, "Browse all tools", 693, -16, 210, function()
        FS:ShowWorkspacePage("allTools")
    end)
    self.back = H:Button(host, "Back to Home", 24, -18, 196, function()
        FS:ShowWorkspacePage("home")
    end)
    self.profiles = H:Button(host, "Manage profiles", 24, 0, 223, function()
        FS.modules.Workbench:Choose("Profiles")
    end)
    self.rows, self.tools = {}, {}
    local owners = {}
    local function add(id, owner, action, summary, run, icon)
        local title = owner and type(run)~="string" and FS.Beginner:Title(owner) or action
        local description = summary or FS.Beginner.help[owner] or FS.modules[owner].description
        local tool = {id=id, owner=owner, title=title, action=action, description=description, icon=icon or owner,
            view=type(run)=="string" and run or nil}
        tool.searchText = table.concat({owner or "", title, action, description, owner and FS.Beginner:SearchText(owner) or ""}, " ")
        if type(run)=="string" then tool.open=function() FS.modules.Workbench:Choose(run) end
        elseif run then tool.open=run
        else tool.open=function() FS:OpenModule(owner) end end
        self.tools[#self.tools+1]=tool
        if owner then owners[owner]=true end
    end
    for _, shortcut in ipairs(shortcuts) do add(unpack(shortcut,1,6)) end
    for _, name in ipairs(frame.moduleOrder) do
        if not owners[name] and FS.modules[name].ShowWindow then
            add(name, name, "Open "..FS.Beginner:Title(name))
        end
    end
end

function W:CreateRow()
    local row = CreateFrame("Frame", nil, self.host, "BackdropTemplate")
    H:Skin(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34,34)
    row.icon:SetPoint("TOPLEFT",12,-12)
    row.title = H:Label(row, "", 56, -12, 350)
    row.summary = H:Label(row, "", 56, 0, 350)
    row.open = H:Button(row, "", 12, 0, 172, function()
        if canOpen(row.tool) then row.tool.open() end
    end)
    row.settings = H:Button(row, "Settings", 0, 0, 104, function()
        if row.tool.view then FS.modules.Workbench:ShowViewSettings(row.tool.view)
        else FS.Beginner:ShowModule(row.tool.owner) end
    end)
    row.pin = H:Button(row, "", 0, 0, 82, function()
        local pins = FS.db.window.pinnedTools
        pins[row.tool.id] = not pins[row.tool.id]
        FS.modules.Profiles:PersistCurrent()
        FS:LayoutConfigText()
    end)
    return row
end

local function at(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT",x,-y)
end

function W:LayoutRow(index, tool, isHome, x, y)
    local row = self.rows[index]
    if not row then row=self:CreateRow(); self.rows[index]=row end
    row.tool=tool
    FS:SetMenuIcon(row.icon, tool.icon or "Category")
    row.title:SetText(tool.title)
    row.summary:SetText(tool.description)
    local width = isHome and 430 or 882
    local copyWidth = isHome and 355 or 407
    local titleHeight = H:TextHeight(row.title,copyWidth,2)
    at(row.summary,56,15+titleHeight)
    local summaryHeight = H:TextHeight(row.summary,copyWidth,3)
    local buttonY = isHome and 21+titleHeight+summaryHeight or 12
    row.open:SetText(canOpen(tool) and tool.action or "Module disabled")
    row.open:SetEnabled(canOpen(tool))
    row.pin:SetText(FS.db.window.pinnedTools[tool.id] and "Unpin" or "Pin")
    row.settings:SetShown(tool.view and FS.Tools.viewSettings[tool.view]~=nil or not tool.view and tool.owner~=nil)
    local buttonHeight = 0
    for _, button in ipairs({row.open,row.settings,row.pin}) do
        buttonHeight=math.max(buttonHeight,H:FitButton(button,3))
    end
    local buttonX = isHome and 12 or 467
    for i,button in ipairs({row.open,row.settings,row.pin}) do
        at(button,buttonX+({0,180,292})[i],buttonY)
        button:SetHeight(buttonHeight)
    end
    local height=math.max(74,buttonY+buttonHeight+12,25+titleHeight+summaryHeight)
    row:SetSize(width,height)
    at(row,x,y)
    row:Show()
    return height
end

function W:Layout(frame, page)
    local isHome = page=="home"
    local isProfiles = page=="profiles"
    local show = isHome or page=="allTools" or isProfiles
    self.host:SetShown(show)
    if not show then return 0 end
    self.profiles:SetShown(isProfiles)
    self.browse:SetShown(isHome)
    self.back:SetShown(page=="allTools")
    self.heading:SetText(isHome and "Pinned tools" or isProfiles and "Profiles" or "All Tools")
    local y=18
    if page=="allTools" then
        y=y+H:FitButton(self.back,2)+14
    end
    at(self.heading,24,y)
    y=y+H:TextHeight(self.heading,650,2)+8
    local query=frame.moduleQuery
    self.note:SetText(isHome and "Pin your most-used tools from All Tools." or isProfiles
        and "Save or switch your layout, theme and module settings."
        or query~="" and "Search results" or "Find a tool, see what it does and pin it to Home.")
    at(self.note,24,y)
    y=y+H:TextHeight(self.note,650,2)+16
    if isHome then y=math.max(y,16+H:FitButton(self.browse,2)+12) end
    if isProfiles then
        for _,row in ipairs(self.rows) do row:Hide() end
        FS.modules.Profiles:LayoutBar(y)
        y=y+frame.profiles:GetHeight()+16
        at(self.profiles,24,y)
        return y+H:FitButton(self.profiles,2)+12
    end
    local shown, rowHeight = 0, 0
    for _,tool in ipairs(self.tools) do
        local matches = isHome and FS.db.window.pinnedTools[tool.id]
            or not isHome and FS.Beginner:Matches(tool.searchText,query)
        if matches then
            shown=shown+1
            local column=isHome and (shown-1)%2 or 0
            rowHeight=math.max(rowHeight,self:LayoutRow(shown,tool,isHome,24+column*446,y))
            if not isHome or column==1 then y=y+rowHeight+12; rowHeight=0 end
        end
    end
    for i=shown+1,#self.rows do self.rows[i]:Hide() end
    if shown==0 then
        self.note:SetText(isHome and "No pinned tools yet. Browse All Tools to get started." or "No tools match. Press Enter to search individual settings.")
        H:TextHeight(self.note,650,2)
    end
    return y+rowHeight+12
end
