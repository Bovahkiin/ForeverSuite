local _, FS = ...
local B = {}
FS.Beginner = B
local H = FS.HUD

-- Account preferences belong to onboarding, outside profile snapshots.
FS.defaults.setup.tourDismissed = false
FS.defaults.setup.tourCompleted = false

B.help = {
    Bags = "Find items, organize your bags and keep favorites close at hand.",
    Vendor = "Choose how to sell junk and repair equipment at merchants.",
    Gear = "See damaged equipment and get a reminder before it breaks.",
    UnitFrames = "See your health and power, your target and your pet.",
    ActionBars = "Choose how your action buttons look and open the game bar layout.",
    Nameplates = "Customize the health bars above enemies and other players.",
    Character = "View equipment, character stats, your pet and reputation.",
    Map = "Find your way with a quest arrow, minimap trail and coordinates.",
    Quests = "Follow quest objectives and see what to do next.",
    Loot = "Loot faster and keep track of recent drops and loot rolls.",
    Buffs = "See active buffs and reminders for missing effects.",
    Cooldowns = "Track when important abilities are ready again.",
    Combat = "Review group damage, healing and recent combat.",
    Professions = "Find recipes and see which materials you need.",
    AuctionHouse = "Track prices you have observed and prepare a shopping list.",
    Chat = "Make messages easier to read and customize chat windows.",
    Social = "Find friends and manage your contacts.",
    Guild = "Find guild members and customize your guild view.",
    QoL = "Track leveling progress and choose everyday conveniences.",
    Bank = "Search and organize items while your bank is open.",
    Bindings = "Assign keyboard shortcuts to action and pet buttons.",
    Mail = "Collect mail attachments and money with fewer clicks.",
    MinimapButtons = "Keep supported minimap addon buttons together in one tray.",
    GearAdvisor = "See whether found equipment is better for your class and build.",
}

B.aliases = {
    Bags = "bags inventory items tassen tas spullen inventory verplaatsen tassen verplaatsen",
    Map = "arrow waypoint navigation pijl terug pijl kwijt route navigatie minimap coords coordinaten",
    UnitFrames = "health target pet huisdier levensbalk speler doelwit pet voeren feed happiness happy",
    Chat = "chat messages berichten chatvenster tekst leesbaar",
    ActionBars = "buttons spells action bars actiebalk knoppen vaardigheden",
    GearAdvisor = "upgrade equipment advice uitrusting advies beter wapen armor",
    Mail = "mail post brieven attachments bijlagen geld ophalen",
    MinimapButtons = "minimap addon buttons verzamelknop addons verzamelen",
    Bindings = "keys keyboard shortcuts toetsen sneltoetsen",
}

local explicit = {
    Bags = {"showNewLoot", "showCooldowns", "showEmpty", "openAtMerchant"},
    Vendor = {"includeGray", "autoRepair", "report", "protectRare"},
    Gear = {"showButton", "warn", "warningPercent"},
    UnitFrames = {"showPet", "showFocus", "showParty", "showRaid"},
    ActionBars = {"menu"},
    Nameplates = {"enemies", "friendlyPlayers", "friendlyNPCs"},
    Map = {"navigation", "coordinates", "autoQuest", "trail"},
    GearAdvisor = {"preset", "role", "tooltips", "minimum"},
}

function B:Title(name)
    local card = FS.window and FS.window.cards[name]
    return card and card.heading:GetText() or FS.modules[name].title or name
end

function B:Allowed()
    return FS.modules.Profiles:Allowed()
end

function B:Window(key, title)
    local f = self[key]
    if not f then
        f = CreateFrame("Frame", "ForeverSuiteBeginner" .. key, UIParent, "BackdropTemplate")
        self[key] = f
        H:Skin(f)
        f:SetSize(760, 520)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f.title = H:Label(f, title, 24, -22, 712)
        f.description = H:Label(f, "", 24, -60, 712)
        f.back = H:Button(f, "Back to Control Center", 24, -460, 344, function()
            f:Hide()
            FS:ShowConfig()
        end)
        f.rows = {}
        UISpecialFrames[#UISpecialFrames + 1] = f:GetName()
        f:Hide()
    end
    f.title:SetText(title)
    return f
end

function B:Present(f, entries, description)
    if not self:Allowed() then return false end
    f.fsFontModule=f.owner or "Core"
    FS:FontTree(f)
    local color=FS.moduleCardColors[f.owner] or {.12,.72,.86}
    f:SetBackdropBorderColor(unpack(color))
    f.description:SetText(description)
    local y = 22 + H:TextHeight(f.title, 712, 2) + 16
    f.description:ClearAllPoints()
    f.description:SetPoint("TOPLEFT", 24, -y)
    y = y + H:TextHeight(f.description, 712, 6) + 20
    for index, entry in ipairs(entries) do
        if not f.rows[index] then
            f.rows[index] = H:Button(f, "", 24, 0, 712, function() end)
        end
        local row = f.rows[index]
        row:SetText(entry.text)
        row:SetScript("OnClick", function() FS:SettingAction(entry.run) end)
        row:SetEnabled(entry.enabled ~= false)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 24, -y)
        row:Show()
        local color = FS.moduleCardColors[f.owner] or {.12, .72, .86}
        row:SetBackdropBorderColor(unpack(color))
        y = y + H:FitButton(row, 3, 34) + 10
    end
    for index = #entries + 1, #f.rows do f.rows[index]:Hide() end
    f.back:ClearAllPoints()
    f.back:SetPoint("TOPLEFT", 24, -y - 10)
    f:SetHeight(y + H:FitButton(f.back, 2) + 44)
    f:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 760, (UIParent:GetHeight() - 32) / f:GetHeight()))
    FS:CloseOtherWindows(f)
    FS.settingsScreen=f
    f:Show()
    return true
end

function B:Options(name)
    local available, byKey = {}, {}
    for _, row in ipairs(FS.Extensions:SettingsIndex()) do
        if row.owner == name and row.key ~= "" and row.key ~= "enabled" then
            local value = row.ref[row.key]
            if type(value) == "boolean" or row.option.values or row.option.min then
                available[#available + 1] = row
                byKey[row.key] = row
            end
        end
    end
    local result, added = {}, {}
    for _, key in ipairs(explicit[name] or {}) do
        if byKey[key] then result[#result + 1] = byKey[key]; added[key] = true end
    end
    for _, row in ipairs(available) do
        if #result >= 4 then break end
        if not added[row.key] then result[#result + 1] = row; added[row.key] = true end
    end
    return result
end

function B:ChangeOption(row)
    if not self:Allowed() then return false end
    local option, current = row.option, row.ref[row.key]
    if option.values then
        local index = 1
        for i, value in ipairs(option.values) do
            if current == value then index = i % #option.values + 1; break end
        end
        row.ref[row.key] = option.values[index]
    elseif option.min then
        local value = current + (option.step or 1)
        row.ref[row.key] = value > option.max and option.min or value
    else row.ref[row.key] = not current end
    local module = FS.modules[row.owner]
    if module.SettingsChanged then module:SettingsChanged()
    elseif row.owner == "Bags" then module:NormalizeSettings(); module:Refresh() end
    FS.modules.Profiles:PersistCurrent()
    FS:RefreshConfig()
    return true
end

function B:ShowModule(name)
    if not FS.modules[name] or not self:Allowed() then return false end
    FS:CreateConfigWindow()
    local f = self:Window("moduleWindow", self:Title(name) .. " settings")
    f.owner = name
    local enabled = FS:IsModuleEnabled(name)
    local entries = {{text = "Module " .. (enabled and "enabled" or "disabled"), run = function()
        if not self:Allowed() then return end
        FS:SetModuleEnabled(name, not FS:IsModuleEnabled(name))
        FS.modules.Profiles:PersistCurrent()
        self:ShowModule(name)
    end}}
    for _, row in ipairs(self:Options(name)) do
        local value = row.ref[row.key]
        if type(value) == "boolean" then value = value and "On" or "Off" end
        entries[#entries + 1] = {text = row.label .. ": " .. tostring(value), run = function()
            if self:ChangeOption(row) then self:ShowModule(name) end
        end}
    end
    entries[#entries + 1] = {text = "More options", run = function() FS:ConfigureModule(name) end}
    entries[#entries + 1] = {text = "Text and fonts for this module", run = function()
        FS.Typography.scope = name
        FS.Typography:Show()
    end}
    local module=FS.modules[name]
    if module.ShowWindow then
        entries[#entries + 1] = {text = "Open " .. self:Title(name), enabled = enabled, run = function() module:ShowWindow() end}
    end
    if name == "ActionBars" then
        entries[#entries + 1] = {text = "Move game action bars", run = function() FS.modules.ActionBars:OpenNativeLayout() end}
    elseif name == "Map" or name == "Nameplates" then
        entries[#entries + 1] = {text = "Choose which addon manages this", run = function()
            FS.Compatibility:Show(name == "Map" and "waypoints" or "nameplates")
        end}
    end
    local status = enabled and "Changes are saved automatically." or "Enable this module to see its features."
    if name == "Nameplates" then status = status .. " Switching to another nameplate addon requires Reload UI." end
    return self:Present(f, entries, (self.help[name] or self:Title(name)) .. "\n" .. status)
end

function B:SearchText(name)
    return (self.help[name] or "") .. " " .. (self.aliases[name] or "")
end

B.tasks = {
    {text = "Make text larger / change fonts", words = "letters groter lettertype font fonts text size tekst groter grootte", run = function() FS.Typography.scope="All modules"; FS.Typography:Show() end},
    {text = "Bring the quest arrow back", words = "pijl terug pijl kwijt arrow missing waypoint restore", run = function() B:RestoreWaypoint() end},
    {text = "Move bags, chat or another frame", words = "tassen verplaatsen bags move chat verplaatsen positie", run = function() FS.Layout:Start() end},
    {text = "Pet feeding and happiness", words = "pet voeren feed happy happiness huisdier", run = function() B:ShowPetHelp() end},
    {text = "Repair my interface layout", words = "help herstel recovery interface verkeerd buiten beeld offscreen reset", run = function() B:ShowRecovery() end},
    {text = "Choose waypoint or nameplate addons", words = "restedxp zygor plater platynator addons samenwerking waypoint nameplates", run = function() FS.Compatibility:Show() end},
}

function B:Matches(text, query)
    text = text:lower()
    for token in query:lower():gmatch("%S+") do
        if not text:find(token, 1, true) then return false end
    end
    return true
end

function B:Find(query)
    local results = {}
    for _, task in ipairs(self.tasks) do
        if self:Matches(task.text .. " " .. task.words, query) then results[#results + 1] = task end
    end
    for _, row in ipairs(FS.Extensions:SettingsIndex()) do
        if self:Matches(row.text, query) then
            local result = {text = row.text, row = row}
            result.run = function()
                if row.owner == "Typography" then FS.Typography.scope="All modules"; FS.Typography:Show()
                elseif row.owner == "Workbench" then FS.modules.Workbench:Choose("Maintenance")
                else
                    FS:ConfigureModule(row.owner)
                    local panel = FS.modules[row.owner].settings
                    if row.owner == "Bags" or row.owner == "Vendor" then panel = FS.window.settings end
                    if panel and row.key ~= "" and FS.modules[row.owner].options then
                        for index, option in ipairs(FS.modules[row.owner].options) do
                            if option.key == row.key and panel.optionPages then panel.optionsPage = math.floor((index - 1) / 12) + 1 end
                        end
                        FS.modules[row.owner]:RefreshSettings()
                        FS:BindSettings(panel, row.owner)
                    end
                end
            end
            results[#results + 1] = result
        end
    end
    return results
end

function B:Search(query, page)
    if not self:Allowed() then return false end
    query = type(query) == "string" and query:match("^%s*(.-)%s*$") or ""
    local f = self:Window("searchWindow", "Find an option")
    local results = self:Find(query)
    local pages = math.max(1, math.ceil(#results / 7))
    page = math.max(1, math.min(pages, page or 1))
    local entries = {}
    for index = (page - 1) * 7 + 1, math.min(page * 7, #results) do entries[#entries + 1] = results[index] end
    if pages > 1 then
        entries[#entries + 1] = {text = "Previous results", enabled = page > 1, run = function() self:Search(query, page - 1) end}
        entries[#entries + 1] = {text = "Next results", enabled = page < pages, run = function() self:Search(query, page + 1) end}
    end
    return self:Present(f, entries, #results .. " results for '" .. query .. "'. Page " .. page .. " / " .. pages .. ".\n" ..
        (#results == 0 and "Try 'text size', 'restore waypoint', 'feed pet' or a module name." or "Choose a result to open the relevant setting or tool."))
end

function B:RestoreWaypoint()
    if not self:Allowed() then return false end
    local selected=FS.Compatibility:Data().waypoints
    if selected and selected~="ForeverSuite" then FS.Compatibility:Show("waypoints"); return false end
    FS.db.map.navigation = true
    FS:SetModuleEnabled("Map", true)
    local map = FS.modules.Map
    map.suppressedQuest=nil
    map.noNext=nil
    map.finishedQuest=nil
    map.explicitNavigation=true
    map:UpdateNavigation()
    FS.modules.Profiles:PersistCurrent()
    FS:Print("Navigation enabled. Select a tracked quest to choose its destination.")
    FS:ConfigureModule("Map")
    return true
end

function B:ShowPetHelp()
    local f = self:Window("petHelp", "Pet feeding and happiness")
    self:Present(f, {{text = "Pet frame settings", run = function() self:ShowModule("UnitFrames") end}},
        "Select Feed Pet, then click suitable food in your bags. The pet happiness icon shows when your pet needs feeding.\nEnable the pet frame in Unit Frames to see your pet's health and happiness.")
end

function B:Recover(action)
    if not self:Allowed() then return false end
    local layout = FS.Layout
    if layout.active then layout:Stop() end
    if action == "visible" then
        layout:Collect()
        for id in pairs(FS.db.layout.frames) do layout:ConstrainSaved(id) end
        layout:ApplyAll()
    elseif action == "undo" then
        if not FS.Extensions:Undo() then return false end
    else return false end
    FS.modules.Profiles:PersistCurrent()
    FS:Print("Layout saved to profile " .. FS.db.profiles.current .. ".")
    FS:ShowConfig()
    return true
end

function B:ShowRecovery()
    local f = self:Window("recoveryWindow", "Help with my interface")
    return self:Present(f, {
        {text = "Bring saved frames back on screen", run = function() self:Recover("visible") end},
        {text = "Preview the recommended layout", run = function()
            if FS.Installer:Show() then
                FS.Installer.draft.layout="Layout 1"
                FS.Installer.step=5
                FS.Installer:Refresh()
            end
        end},
        {text = "Undo the last addon settings change", run = function() self:Recover("undo") end},
        {text = "Move or restore one frame", run = function() FS.Layout:Start() end},
    }, "Choose a repair. Preview the recommended layout before applying it, or bring your saved frames back inside the screen.")
end

local tour = {
    {title = "1 / 3  Find your settings", text = "Open ForeverSuite with /fs or its minimap button. Click a module card for its main settings. More options opens the full settings screen.", target = "moduleSearch"},
    {title = "2 / 3  Place your interface", text = "Move Frames lets you drag and resize supported frames. Click a handle for Center, Below player or Restore this frame. Save keeps your layout.", target = "move"},
    {title = "3 / 3  Keep your profile", text = "Your changes are saved automatically. Use Save in Profiles to keep a named setup. Use loads the profile you selected. Help with layout can recover misplaced frames.", target = "profiles"},
}

function B:ShowTour(index)
    if not self:Allowed() then return false end
    FS:ShowConfig()
    index = math.max(1, math.min(3, index or 1))
    local f = self.tourWindow
    if not f then
        f = CreateFrame("Frame", "ForeverSuiteQuickTour", UIParent, "BackdropTemplate")
        self.tourWindow = f
        H:Skin(f)
        f:SetSize(620, 230)
        -- Keep the tour above the dashboard and its scroll content.
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f.heading = H:Label(f, "", 20, -18, 580)
        f.text = H:Label(f, "", 20, -54, 580)
        f.skip = H:Button(f, "Skip", 20, -150, 170, function() self:EndTour(false) end)
        f.dismiss = H:Button(f, "Do not show again", 210, -150, 200, function() self:EndTour(true) end)
        f.next = H:Button(f, "Next", 430, -150, 170, function()
            if self.tourStep == 3 then FS.db.setup.tourCompleted = true; self:EndTour(false)
            else self:ShowTour(self.tourStep + 1) end
        end)
        f.highlight=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        f.highlight.fsThemeTransparent=true
        H:Skin(f.highlight)
        f.highlight:SetBackdropColor(0,0,0,0)
        f.highlight:SetBackdropBorderColor(.95,.68,.24,1)
        f.highlight:EnableMouse(false)
        f.highlight:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(f.highlight:GetFrameLevel()+1)
        f:SetScript("OnHide",function() f.highlight:Hide() end)
        FS.window:HookScript("OnHide",function() f:Hide() end)
        f:Hide()
        UISpecialFrames[#UISpecialFrames + 1] = f:GetName()
    end
    self.tourStep = index
    local step = tour[index]
    f.heading:SetText(step.title)
    f.text:SetText(step.text.."\nThe related control has a gold border in the Control Center.")
    local y = 18 + H:TextHeight(f.heading, 580, 2) + 12
    f.text:ClearAllPoints(); f.text:SetPoint("TOPLEFT", 20, -y)
    y = y + H:TextHeight(f.text, 580, 6) + 16
    local height = 0
    for i, button in ipairs({f.skip, f.dismiss, f.next}) do
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", ({20, 210, 430})[i], -y)
        height = math.max(height, H:FitButton(button, 3))
    end
    f.next:SetText(index == 3 and "Finish tour" or "Next")
    f:SetHeight(y + height + 20)
    f:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 620, (UIParent:GetHeight() - 32) / f:GetHeight()))
    f:ClearAllPoints(); f:SetPoint("CENTER")
    local target = FS.window[step.target]
    if target then
        FS:ScrollConfig(step.target == "moduleSearch" and 0 or FS.window.scrollMaximum)
        f.highlight:ClearAllPoints()
        f.highlight:SetPoint("TOPLEFT",target,"TOPLEFT",-3,3)
        f.highlight:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",3,-3)
        f.highlight:Show()
    end
    f:Show()
    return true
end

function B:EndTour(dismiss)
    if dismiss then FS.db.setup.tourDismissed = true end
    if self.tourWindow then self.tourWindow:Hide() end
end
