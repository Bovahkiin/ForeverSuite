local _, FS = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
FS.settingsTop=-526
FS.moduleCardColors = {
    Bags={.12,.72,.86}, Vendor={.95,.68,.24}, Gear={.65,.45,.95},
    UnitFrames={.20,.80,.65}, ActionBars={.22,.52,1.00}, Nameplates={.95,.30,.30},
    Character={.92,.80,.46}, Profiles={.40,.65,.90},
    Workbench={.43,.75,.88},
    Mail={.88,.69,.36}, MinimapButtons={.28,.84,.96}, GearAdvisor={.71,.87,.49},
    Map={.46,.78,.29}, Quests={.98,.86,.22}, Loot={1.00,.46,.17}, Buffs={.14,.88,.78},
    Cooldowns={.91,.39,.78}, Combat={1.00,.38,.49}, Professions={.77,.56,.38}, AuctionHouse={.74,.90,.23},
    Social={.70,.63,1.00}, Chat={.91,.73,.90}, Guild={.38,.74,.58}, QoL={.98,.58,.72}, Bank={.52,.90,.70}, Bindings={.70,.79,.88},
}
local function text(parent, value, x, y, width, font)
    local f = FS.Widgets:Label(parent, font or "ForeverSuiteFontSmall")
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(value)
    return f
end
local function button(parent, value, width, action)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(width, 28)
    FS.Themes:Register(f,"Button")
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0.08, 0.11, 0.15, 1); f:SetBackdropBorderColor(0.16, 0.22, 0.29, 1)
    local label = f:CreateFontString(nil, "OVERLAY", "ForeverSuiteFontSmall")
    f.fsLabel=label
    label:SetPoint("CENTER"); f:SetFontString(label); f:SetText(value)
    f:SetScript("OnClick", function(...) return FS:SettingAction(action,...) end)
    f:SetScript("OnEnter", function(b) b:SetBackdropBorderColor(0.2, 0.75, 0.9, 1) end)
    f:SetScript("OnLeave", function(b) b:SetBackdropBorderColor(0.16, 0.22, 0.29, 1) end)
    return f
end
function FS:DisableAllModules()
    if InCombatLockdown() or self.modules.Vendor.busy then
        self:Print("Leave combat and finish vendor actions before disabling all modules."); return false
    end
    local f=self.window; if not f or not f.moduleOrder then return false end
    for _,name in ipairs(f.moduleOrder) do
        if self:IsModuleEnabled(name) then self:SetModuleEnabled(name,false) end
    end
    self.modules.Profiles:PersistCurrent(); self:RefreshConfig()
    self:Print("All modules disabled. Settings are kept; enable individual cards or use Undo last setting.")
    return true
end
function FS:SetModuleFilter(query,mode)
    local f=self.window; if not f then return end
    local wasDefault=(f.moduleQuery or "")=="" and (f.moduleFilter or "All")=="All"
    query=type(query)=="string" and query:lower():match("^%s*(.-)%s*$") or f.moduleQuery or ""
    mode=mode or f.moduleFilter or "All"
    if mode~="All" and mode~="Enabled" and mode~="Disabled" then mode="All" end
    local isDefault=query=="" and mode=="All"
    if wasDefault and not isDefault then f.unfilteredPage=f.cardPage end
    f.moduleQuery=query; f.moduleFilter=mode
    f.cardPage=isDefault and (wasDefault and f.cardPage or f.unfilteredPage or 1) or 1
    self:RefreshConfig()
    self:ScrollConfig(0)
end
function FS:ClearModuleFilter()
    local f=self.window; if not f then return end
    f.filterUpdating=true; f.moduleSearch:SetText(""); f.filterUpdating=false
    self:SetModuleFilter("","All"); f.moduleSearch:ClearFocus()
end
function FS:FilterModuleCards()
    local f=self.window; local names={}; local tokens={}
    for token in (f.moduleQuery or ""):gmatch("%S+") do tokens[#tokens+1]=token end
    for _,name in ipairs(f.moduleOrder) do
        local card=f.cards[name]; local enabled=self:IsModuleEnabled(name)
        local match=f.moduleFilter=="All" or (f.moduleFilter=="Enabled" and enabled) or (f.moduleFilter=="Disabled" and not enabled)
        for _,token in ipairs(tokens) do if not card.searchText:find(token,1,true) then match=false; break end end
        if match then names[#names+1]=name; card.page=math.floor((#names-1)/8)+1; card.position=(#names-1)%8
        else card.page=0 end
    end
    f.filteredNames=names; f.filteredCount=#names; f.filteredPages=math.max(1,math.ceil(#names/8))
    f.cardPage=math.max(1,math.min(f.filteredPages,f.cardPage))
end
function FS:PaintModuleCard(name)
    local card=self.window and self.window.cards[name]; if not card then return end
    local c=self.moduleCardColors[name]; local enabled=self:IsModuleEnabled(name); local factor=self.Themes:Current()==10 and .23 or 1
    card.heading:SetTextColor(c[1]*factor,c[2]*factor,c[3]*factor)
    card.card:SetBackdropBorderColor(c[1]*(card.hovered and 1 or .45),c[2]*(card.hovered and 1 or .45),c[3]*(card.hovered and 1 or .45),1)
    card.hover:SetColorTexture(c[1],c[2],c[3],.08); card.hover:SetShown(card.hovered==true)
    card.rail:SetColorTexture(c[1],c[2],c[3],enabled and 1 or .35)
    card.icon:SetDesaturated(not enabled)
    local caption=enabled and FS.Text.enabled or FS.Text.disabled
    card.toggle:SetText(caption); card.toggle.fsLabel:SetText(caption); card.displayedEnabled=enabled
    if enabled then card.toggle.fsLabel:SetTextColor(c[1]*factor,c[2]*factor,c[3]*factor)
    elseif factor==1 then card.toggle.fsLabel:SetTextColor(.60,.65,.72)
    else card.toggle.fsLabel:SetTextColor(.25,.28,.32) end
end
function FS:CreateConfigWindow()
    if self.window then return self.window end
    local frame = CreateFrame("Frame", "ForeverSuiteConfigWindow", UIParent, "BackdropTemplate")
    self.window = frame
    frame:SetSize(940, 1000)
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 940, (UIParent:GetHeight() - 32) / 1000))
    frame:SetPoint("CENTER", UIParent, "CENTER", self.db.window.x, self.db.window.y)
    frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:SetMovable(true)
    frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.035, 0.045, 0.065, 0.98); frame:SetBackdropBorderColor(0.16, 0.22, 0.29, 1)
    FS.Themes:Register(frame)
    local header = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerFill=header; header:SetColorTexture(0.055, 0.075, 0.105, 1); header:SetSize(938, 84); header:SetPoint("TOPLEFT", 1, -1)
    local watermark = frame:CreateTexture(nil, "BACKGROUND"); watermark:SetTexture(self.emblem)
    watermark:SetSize(330, 330); watermark:SetPoint("BOTTOMRIGHT", -46, 65); watermark:SetAlpha(0.075)
    local accent = frame:CreateTexture(nil, "ARTWORK"); accent:SetColorTexture(0.12, 0.72, 0.86, 1)
    accent:SetHeight(2); accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local x, y = f:GetCenter(); local ux, uy = UIParent:GetCenter()
        if x and y and ux and uy then FS.db.window.x, FS.db.window.y = x - ux, y - uy end
    end)
    frame:SetScript("OnHide", function(f) f:StopMovingOrSizing() end)
    frame.close=button(frame,"X",32,function() frame:Hide() end); frame.close:SetPoint("TOPRIGHT",-8,-8)
    local logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo = logo
    logo:SetTexture(self.logo); logo:SetSize(320, 80); logo:SetPoint("TOPLEFT", 24, -3)
    frame.title = text(frame, "", 380, -22, 520, "ForeverSuiteFontLarge")
    frame.intro = text(frame, "", 380, -53, 520)
    frame.profiles=self.modules.Profiles:CreateBar(frame)
    frame.moduleQuery=""; frame.moduleFilter="All"
    frame.moduleSearch=CreateFrame("EditBox",nil,frame,"BackdropTemplate"); FS.HUD:Skin(frame.moduleSearch); FS.Themes:Register(frame.moduleSearch,"Button")
    frame.moduleSearch:SetAutoFocus(false); frame.moduleSearch:SetMaxLetters(100); frame.moduleSearch:SetTextInsets(12,12,0,0); FS:ApplyFont(frame.moduleSearch,14)
    frame.moduleSearch:SetText("")
    frame.searchHint=text(frame.moduleSearch,"Search modules or features...",12,-8,436); frame.searchHint:SetTextColor(.5,.65,.75)
    frame.moduleSearch:SetScript("OnTextChanged",function(b) if not frame.filterUpdating then self:SetModuleFilter(b:GetText()) end end)
    frame.moduleSearch:SetScript("OnEscapePressed",function() self:ClearModuleFilter() end)
    frame.moduleSearch:SetScript("OnEnterPressed",function(b)
        b:ClearFocus()
        if frame.moduleQuery~="" then FS.Beginner:Search(frame.moduleQuery) end
    end)
    frame.clearModuleSearch=button(frame,"Clear",140,function() self:ClearModuleFilter() end)
    frame.moduleFilterButton=button(frame,"All modules",260,function()
        local nextMode={All="Enabled",Enabled="Disabled",Disabled="All"}; self:SetModuleFilter(nil,nextMode[frame.moduleFilter])
    end)
    frame.emptyModules=text(frame,"No modules found. Clear the filters or try a different word.",24,-200,850)
    frame.emptyModules:SetJustifyH("CENTER"); frame.emptyModules:Hide()
    frame.cards = {}
    local modules = {
        { name = "Bags", title = "Bags & Stock", detail = "Organize bags and keep items safe", icon = "Interface\\Icons\\INV_Misc_Bag_08" },
        { name = "Vendor", title = "Vendor & Junk", detail = "Sell junk, repair gear and buy supplies", icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    }
    modules[#modules + 1] = { name = "Gear", title = "Gear & Durability", detail = "Inspect equipment and repair status", icon = "Interface\\Icons\\INV_Chest_Plate04" }
    modules[#modules + 1] = { name = "UnitFrames", title = "Unit Frames", detail = "Player and target health at a glance", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" }
    modules[#modules + 1] = { name = "ActionBars", title = "Action Bars & Menu", detail = "Clean buttons and a compact main menu", icon = "Interface\\Icons\\INV_Sword_04" }
    modules[#modules + 1] = { name = "Nameplates", title = "Nameplates", detail = "Clear health bars above units", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" }
    modules[#modules + 1] = { name = "Character", title = "Character Info", detail = "Equipment, reputation, skills and more", icon = "Interface\\Icons\\INV_Helmet_03" }
    local additions={
        {"Map","Map","Coordinates, pins and instance details","INV_Misc_Map_01"},
        {"Quests","Quests","Objectives and optional quest convenience","INV_Misc_Note_01"},
        {"Loot","Loot","Fast loot, recent drops and roll choices","INV_Misc_Bag_10"},
        {"Buffs","Buffs","Buffs, debuffs and missing buff reminders","Spell_Holy_MagicalSentry"},
        {"Cooldowns","Cooldowns","Your spells, interrupts and defensives","Spell_Nature_TimeStop"},
        {"Combat","Combat","Group damage, healing and combat summaries","Ability_Warrior_BattleShout"},
        {"Professions","Professions","Recipes and required materials","Trade_BlackSmithing"},
        {"AuctionHouse","Auction House","Observed prices and shopping list","INV_Misc_Coin_01"},
        {"Chat","Chat","Chat panels, text and message display","INV_Misc_Note_02"},
        {"Social","Social","Contacts and friends list tools","INV_Misc_GroupLooking"},
        {"Guild","Guild","Guild members and community tools","INV_Misc_Tournaments_Tabard_Human"},
        {"QoL","Leveling & QoL","Level progress and convenient tools","INV_Misc_Book_11"},
        {"Bank","Bank","Grouped bank items and search","INV_Misc_Bag_10"},
        {"Bindings","Key Bindings","Choose keys for action, stance and pet bars","INV_Misc_Gear_01"},
        {"Mail","Mail","Read mail and collect attachments or money","INV_Letter_15"},
        {"MinimapButtons","Addon Buttons","Collect minimap addon buttons in one tray","INV_Misc_EngGizmos_17"},
        {"GearAdvisor","Gear Advisor","Compare equipment with customizable stat weights","INV_Chest_Chain_05"},
    }
    for _,d in ipairs(additions) do modules[#modules+1]={name=d[1],title=d[2],detail=d[3],icon="Interface\\Icons\\"..d[4]} end
    frame.cardCount=#modules; frame.cardPage=1; frame.moduleOrder={}
    for i, data in ipairs(modules) do
        frame.moduleOrder[#frame.moduleOrder+1]=data.name
        local name, color = data.name, self.moduleCardColors[data.name]
        local card = CreateFrame("Button", nil, frame, "BackdropTemplate")
        card:SetSize(432, 80); local position=(i-1)%8; card:SetPoint("TOPLEFT",24+(position%2)*460,-176-math.floor(position/2)*88)
        card:RegisterForClicks("LeftButtonUp")
        card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        card:SetBackdropColor(0.045 + color[1] * 0.025, 0.06 + color[2] * 0.025, 0.08 + color[3] * 0.025, 1)
        card:SetBackdropBorderColor(color[1] * 0.45, color[2] * 0.45, color[3] * 0.45, 1)
        FS.Themes:Register(card,"Panel")
        local rail = card:CreateTexture(nil, "ARTWORK"); rail:SetColorTexture(color[1], color[2], color[3], 1)
        rail:SetWidth(3); rail:SetPoint("TOPLEFT", 1, -1); rail:SetPoint("BOTTOMLEFT", 1, 1)
        local icon = card:CreateTexture(nil, "ARTWORK"); icon:SetTexture(data.icon)
        icon:SetSize(42, 42); icon:SetPoint("TOPLEFT", 14, -16)
        local heading=text(card, data.title, 68, -12, 340, "ForeverSuiteFontLarge"); heading:SetTextColor(color[1], color[2], color[3])
        data.detail = FS.Beginner.help[name] or data.detail
        local detail=text(card, data.detail, 68, -35, 345)
        local hint=text(card, "Settings", 68, -61, 240); hint:SetTextColor(0.55, 0.65, 0.75)
        local toggle = button(card, "", 92, function() self:SetModuleEnabled(name, not self:IsModuleEnabled(name)) end)
        toggle:SetPoint("TOPRIGHT", -14, -49)
        local flash = card:CreateTexture(nil, "OVERLAY"); flash:SetAllPoints(card)
        flash:SetColorTexture(color[1], color[2], color[3], 1); flash:Hide()
        local animation = flash:CreateAnimationGroup()
        local alpha = animation:CreateAnimation("Alpha"); alpha:SetFromAlpha(0.3); alpha:SetToAlpha(0); alpha:SetDuration(0.28)
        animation:SetScript("OnFinished", function() flash:Hide() end)
        local hover=card:CreateTexture(nil,"OVERLAY"); hover:SetAllPoints(card); hover:Hide()
        card:SetScript("OnEnter", function(c) frame.cards[name].hovered=true; self:PaintModuleCard(name); GameTooltip:SetOwner(c,"ANCHOR_RIGHT"); GameTooltip:AddLine(data.title); GameTooltip:AddLine(data.detail,.9,.94,1,true); GameTooltip:AddLine("Click to open settings.",.55,.75,.85,true); GameTooltip:Show() end)
        card:SetScript("OnLeave", function() frame.cards[name].hovered=false; self:PaintModuleCard(name); GameTooltip:Hide() end)
        card:SetScript("OnClick", function()
            animation:Stop(); flash:Show(); animation:Play(); FS.Beginner:ShowModule(name)
        end)
        frame.cards[name] = { toggle = toggle, card = card, rail=rail, icon=icon,hover=hover, animation = animation, flash = flash, page=math.floor((i-1)/8)+1,position=position,heading=heading,detail=detail,hint=hint,searchText=(data.name.." "..data.title.." "..data.detail):lower() }
        toggle:SetScript("OnEnter",function(b)
            local c=self.moduleCardColors[name]; b:SetBackdropBorderColor(c[1],c[2],c[3],1)
            GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine((self:IsModuleEnabled(name) and "Disable " or "Enable ")..data.title)
            GameTooltip:AddLine("Your module settings are kept. Click the card to customize them.",.8,.9,1,true); GameTooltip:Show()
        end)
        toggle:SetScript("OnLeave",function(b) b:SetBackdropBorderColor(.16,.22,.29,1); GameTooltip:Hide() end)
        local module=self.modules[name]
        local terms={data.name,data.title,data.detail,type(module.description)=="string" and module.description or ""}
        for _,option in ipairs(module.options or {}) do if type(option.label)=="string" then terms[#terms+1]=option.label end end
        local aliases={Combat="dps hps damage healing",QoL="xp experience",Bindings="hotkeys shortcuts",ActionBars="hotkeys buttons"}
        terms[#terms+1]=aliases[name] or ""
        terms[#terms+1]=FS.Beginner:SearchText(name)
        frame.cards[name].searchText=table.concat(terms," "):lower()
    end
    frame.previousModules=button(frame,"Previous modules",150,function() frame.cardPage=math.max(1,frame.cardPage-1); self:RefreshConfig(); self:ScrollConfig(0) end); frame.previousModules:SetPoint("TOPLEFT",24,-531)
    frame.nextModules=button(frame,"Next modules",150,function() frame.cardPage=math.min(frame.filteredPages or 1,frame.cardPage+1); self:RefreshConfig(); self:ScrollConfig(0) end); frame.nextModules:SetPoint("TOPRIGHT",-24,-531)
    frame.modulePage=text(frame,"",400,-539,200)
    frame.general=text(frame, "GENERAL", 24, -579, 500, "ForeverSuiteFontNormal")
    frame.minimap = self.Widgets:Checkbox(frame, -607, function(value)
        self.db.minimap.show = value; self:UpdateMinimapButton()
    end)
    frame.welcome = self.Widgets:Checkbox(frame, -648, function(value) self.db.welcome = value end)
    frame.help=text(frame, "Click a module card to open its settings. Disabled modules keep their settings.\nMove Frames lets you customize the layout.", 24, -682, 850)
    frame.typography=button(frame,"Text & Fonts",250,function() FS.Typography:Show() end); frame.typography:SetPoint("TOPLEFT",24,-740)
    frame.setup=button(frame,"Guided setup",290,function() FS.Installer:Show() end)
    frame.appearance=button(frame,"Appearance: 10 styles",250,function() FS.Installer:ShowThemes() end)
    frame.tools=button(frame,"Find a setting",290,function() FS.Beginner:Search(frame.moduleQuery) end)
    frame.undo=button(frame,"Undo last setting",290,function() FS.Extensions:Undo() end)
    frame.addons=button(frame,"Other addons",250,function() FS.Compatibility:Show() end)
    frame.recovery=button(frame,"Help with layout",290,function() FS.Beginner:ShowRecovery() end)
    frame.tour=button(frame,"Quick tour",290,function() FS.Beginner:ShowTour() end)
    frame.workbench=button(frame,"More tools",250,function() FS.modules.Workbench:ShowWindow() end)
    frame.disableAll=button(frame,"Disable all modules",290,function() self:DisableAllModules() end)
    frame.disableAll:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine("Disable all modules")
        GameTooltip:AddLine("Includes every module page. Settings and profiles are kept. Undo last setting restores the previous module choices.",.8,.9,1,true); GameTooltip:Show()
    end)
    frame.disableAll:SetScript("OnLeave",function() GameTooltip:Hide() end)
    frame.reset = button(frame, "", 160, function() self:ResetDatabase(); if frame.settings then self.modules.Bags:RefreshSettings(true, frame.settings) end; self.modules.Gear:Refresh() end)
    frame.reset:SetPoint("BOTTOMLEFT", 24, 16)
    frame.reload = button(frame, "Reload UI", 160, function() ReloadUI() end)
    frame.reload:SetPoint("BOTTOMRIGHT", -24, 16)
    frame.patchLog = button(frame,"Patch Log",160,function() self:ShowPatchLog() end)
    frame.patchLog:SetPoint("BOTTOMLEFT",207,16)
    frame.credits = button(frame,"Credits",160,function() self:ShowCredits() end)
    frame.credits:SetPoint("BOTTOMLEFT",573,16)
    frame.move = button(frame, "Move Frames", 160, function() self.Layout:Start() end)
    frame.move:SetPoint("BOTTOM", 0, 16)
    self:CreateConfigViewport(frame)
    frame:SetScript("OnUpdate",function(_,elapsed)
        frame.moduleStateElapsed=(frame.moduleStateElapsed or 0)+elapsed
        if frame.moduleStateElapsed<.25 then return end; frame.moduleStateElapsed=0
        for name,card in pairs(frame.cards) do
            if card.displayedEnabled~=self:IsModuleEnabled(name) then self:RefreshConfig(); break end
        end
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "ForeverSuiteConfigWindow"
    frame:Hide(); self:RefreshConfig(); return frame
end
function FS:LayoutConfigText()
    local f=self.window; if not f or not f.cards then return end
    local function size(r) local _,n=r:GetFont(); return n or 14 end
    local function place(r,x,y,w,lines)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",x,-y); r:SetWidth(w)
        if r.SetMaxLines then r:SetMaxLines(lines or 2) end
        local n=size(r); local value=r:GetText() or ""
        local width=r.GetUnboundedStringWidth and r:GetUnboundedStringWidth() or #value*n*.65
        local rows=math.min(lines or 2,math.max(1,math.ceil(width/w)))
        local h=rows*(n+3); r:SetHeight(h); return h
    end
    local function fitButton(b,w,lines)
        local label=b.fsLabel or b.GetFontString and b:GetFontString()
        local h=math.max(28,label and size(label)*(lines or 1)+12 or 28)
        b:SetSize(w,h)
        if label then label:SetWidth(w-12); label:SetHeight(h-6); if label.SetMaxLines then label:SetMaxLines(lines or 1) end end
        return h
    end
    local closeWidth=math.max(32,(f.close.fsLabel and size(f.close.fsLabel) or 12)+16)
    fitButton(f.close,closeWidth)
    local title=place(f.title,380,18,940-380-closeWidth-24,2)
    local introTop=math.max(50,18+title+6)
    local intro=place(f.intro,380,introTop,520,2)
    local profileTop=math.max(88,introTop+intro+12)
    f.headerFill:SetHeight(profileTop-4)
    self.modules.Profiles:LayoutBar(profileTop)
    local searchTop=profileTop+f.profiles:GetHeight()+16
    local searchHeight=math.max(36,fitButton(f.clearModuleSearch,140),fitButton(f.moduleFilterButton,260,2),size(f.moduleSearch)+12)
    f.moduleSearch:ClearAllPoints(); f.moduleSearch:SetPoint("TOPLEFT",24,-searchTop); f.moduleSearch:SetSize(460,searchHeight)
    f.clearModuleSearch:ClearAllPoints(); f.clearModuleSearch:SetPoint("TOPLEFT",496,-searchTop-(searchHeight-f.clearModuleSearch:GetHeight())/2)
    f.moduleFilterButton:ClearAllPoints(); f.moduleFilterButton:SetPoint("TOPLEFT",648,-searchTop-(searchHeight-f.moduleFilterButton:GetHeight())/2)
    f.searchHint:ClearAllPoints(); f.searchHint:SetPoint("LEFT",f.moduleSearch,"LEFT",12,0); f.searchHint:SetWidth(436); f.searchHint:SetHeight(size(f.searchHint)+5)
    if f.searchHint.SetMaxLines then f.searchHint:SetMaxLines(1) end
    local cardsTop=searchTop+searchHeight+16
    place(f.emptyModules,24,cardsTop+40,892,3)
    local cardHeight=80
    for _,c in pairs(f.cards) do
        local title=place(c.heading,68,12,345,2)
        local description=place(c.detail,68,16+title,345,2)
        local toggle=fitButton(c.toggle,math.min(220,math.max(116,(c.toggle.fsLabel and size(c.toggle.fsLabel) or 14)*8*.65+20)))
        local hint=place(c.hint,68,0,220,1)
        c.bodyEnd=16+title+description
        cardHeight=math.max(cardHeight,c.bodyEnd+10+math.max(toggle,hint)+10)
    end
    for _,c in pairs(f.cards) do
        c.card:SetSize(432,cardHeight); c.card:ClearAllPoints(); c.card:SetPoint("TOPLEFT",24+c.position%2*460,-cardsTop-math.floor(c.position/2)*(cardHeight+8))
        c.hint:ClearAllPoints(); c.hint:SetPoint("BOTTOMLEFT",68,12)
        c.hint:Hide()
        c.toggle:ClearAllPoints(); c.toggle:SetPoint("BOTTOMRIGHT",-14,10)
    end
    local navTop=cardsTop+4*(cardHeight+8)+4
    local navHeight=math.max(fitButton(f.previousModules,210,2),fitButton(f.nextModules,210,2))
    f.previousModules:ClearAllPoints(); f.previousModules:SetPoint("TOPLEFT",24,-navTop)
    f.nextModules:ClearAllPoints(); f.nextModules:SetPoint("TOPRIGHT",-24,-navTop)
    place(f.modulePage,248,navTop+6,444,1); f.modulePage:SetJustifyH("CENTER")
    local y=navTop+navHeight+24
    y=y+place(f.general,24,y,850,1)+12
    for _,b in ipairs({f.minimap,f.welcome}) do
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",20,-y)
        b.label:SetWidth(800); b.label:SetHeight(size(b.label)+5)
        y=y+math.max(30,size(b.label)+12)+10
    end
    y=y+place(f.help,24,y,850,3)+18
    fitButton(f.typography,290,2); f.typography:ClearAllPoints(); f.typography:SetPoint("TOPLEFT",24,-y)
    fitButton(f.setup,290,2); f.setup:ClearAllPoints(); f.setup:SetPoint("TOPLEFT",330,-y)
    fitButton(f.appearance,250,2); f.appearance:ClearAllPoints(); f.appearance:SetPoint("TOPLEFT",636,-y)
    y=y+math.max(f.typography:GetHeight(),f.setup:GetHeight(),f.appearance:GetHeight())+14
    fitButton(f.tools,290,2); f.tools:ClearAllPoints(); f.tools:SetPoint("TOPLEFT",24,-y)
    fitButton(f.undo,290,2); f.undo:ClearAllPoints(); f.undo:SetPoint("TOPLEFT",330,-y)
    fitButton(f.addons,250,2); f.addons:ClearAllPoints(); f.addons:SetPoint("TOPLEFT",636,-y)
    y=y+math.max(f.tools:GetHeight(),f.undo:GetHeight(),f.addons:GetHeight())+10
    for i, b in ipairs({f.recovery,f.tour,f.workbench}) do
        fitButton(b,i==3 and 250 or 290,2)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",({24,330,636})[i],-y)
    end
    y=y+math.max(f.recovery:GetHeight(),f.tour:GetHeight(),f.workbench:GetHeight())+10
    fitButton(f.disableAll,290,2); f.disableAll:ClearAllPoints(); f.disableAll:SetPoint("TOPLEFT",24,-y)
    y=y+f.disableAll:GetHeight()+12
    local footer=28
    for _,b in ipairs({f.reset,f.patchLog,f.move,f.credits,f.reload}) do footer=math.max(footer,fitButton(b,160,2)) end
    local height=math.max(800,y+footer+48)
    self:FitConfigViewport(searchTop,y,footer,height)
end
function FS:RefreshConfig()
    local frame = self.window; if not frame then return end
    frame.title:SetText("CONTROL CENTER  |  " .. self.version)
    frame.intro:SetText("Choose a module to configure, enable or disable.")
    frame.minimap.label:SetText(self.L.MINIMAP); frame.minimap:SetChecked(self.db.minimap.show)
    frame.welcome.label:SetText(self.L.WELCOME); frame.welcome:SetChecked(self.db.welcome)
    frame.reset:SetText(self.L.RESET)
    frame.appearance:SetText("Theme: "..self.db.appearance.theme)
    self.modules.Profiles:RefreshSettings()
    self:FilterModuleCards()
    for name, card in pairs(frame.cards) do
        if card.page~=frame.cardPage then card.hovered=false end
        card.card:SetShown(card.page==frame.cardPage)
        self:PaintModuleCard(name)
    end
    frame.previousModules:SetEnabled(frame.cardPage>1); frame.nextModules:SetEnabled(frame.cardPage<frame.filteredPages)
    frame.clearModuleSearch:SetEnabled(frame.moduleQuery~="" or frame.moduleFilter~="All")
    frame.searchHint:SetShown(frame.moduleQuery=="")
    frame.emptyModules:SetShown(frame.filteredCount==0)
    local labels={All="All modules",Enabled="Enabled only",Disabled="Disabled only"}; frame.moduleFilterButton:SetText(labels[frame.moduleFilter])
    if frame.moduleQuery~="" or frame.moduleFilter~="All" then frame.modulePage:SetText(frame.filteredCount.." matches | "..frame.cardPage.."/"..frame.filteredPages)
    else frame.modulePage:SetText("Modules "..frame.cardPage.." / "..frame.filteredPages) end
    self:LayoutConfigText()
    if frame.settings then self.modules.Bags:RefreshSettings(false, frame.settings) end
    self.modules.Gear:RefreshSettings()
    for _, name in ipairs({ "UnitFrames", "ActionBars", "Nameplates" }) do self.modules[name]:RefreshSettings() end
end
function FS:ConfigureModule(name)
    local module=self.modules[name]
    if not module then return end
    local frame = self:CreateConfigWindow()
    frame.moduleSearch:ClearFocus()
    if name~="Bags" and name~="Vendor" then
        if not module.CreateSettings then return end
        local panel = module.settings or module:CreateSettings(frame)
        self:BindSettings(panel,name,function() module:RefreshSettings() end)
        return
    end
    if not frame.settings then self.modules.Bags:CreateSettings(frame) end
    frame.settings.module = name
    frame.settings.advanced = false
    self:BindSettings(frame.settings,name,function() self.modules.Bags:RefreshSettings(true, frame.settings) end)
end
function FS:OpenModule(name)
    if not self:IsModuleEnabled(name) then return end
    if self.window then self.window:Hide() end
    self.modules[name]:ShowWindow(false)
end
function FS:ShowConfig()
    if InCombatLockdown() and CharacterFrame and CharacterFrame:IsShown() then self:Print("Leave combat to switch windows."); return end
    self:CloseOtherWindows(self.window)
    if self.Layout and self.Layout.active then self.Layout:Stop() end
    local frame = self:CreateConfigWindow()
    if self.Layout then self.Layout:Register("ControlCenter",frame,"Control Center") end
    self:FontTree(frame)
    for _, module in pairs(self.modules) do if module.ToggleMovers then module:ToggleMovers(false) end end
    for _, module in pairs(self.modules) do if module.window and not InCombatLockdown() then module.window:Hide() end end
    if frame.settings then frame.settings:Hide() end
    if frame.gearSettings then frame.gearSettings:Hide() end
    for _, module in pairs(self.modules) do if module.settings then module.settings:Hide() end end
    if self.modules.Vendor.saleReview then self.modules.Vendor.saleReview:Hide() end
    self:RefreshConfig(); frame:Show()
end
function FS:ToggleConfig()
    if self.window and self.window:IsShown() then self.window:Hide() else self:ShowConfig() end
end
