local _, FS = ...
local B, V = FS.modules.Bags, FS.modules.Vendor
local icons = { All = 133635, Favorites = 135994, Gear = 132722, Consumables = 134829,
    Ammo = 132382, Materials = 133234, ["Quest Items"] = 134400, Junk = 133784,
    Other = 133647, Bags = 133634, Stock = 133639, Gems = 134071, Recipes = 134939,
    Professions = 136241, Keys = 134238, Pets = 132599, Mounts = 132261 }
local function text(parent, value, x, y, width)
    local f = FS.Widgets:Label(parent, "ForeverSuiteFontSmall")
    f:SetText(value)
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT")
    return f
end
local function fill(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetTexture("Interface\\Buttons\\WHITE8X8"); t:SetVertexColor(r, g, b, a or 1)
    return t
end
local function control(parent, caption, x, y, width, action)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(width, 28); f:SetPoint("TOPLEFT", x, y)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.045, .065, .085, 1); f:SetBackdropBorderColor(.12, .22, .28, 1)
    f.caption = text(f, caption, 8, -7, width - 16)
    f:SetScript("OnClick", action)
    f:SetScript("OnEnter", function() f:SetBackdropBorderColor(.15, .8, .95, 1) end)
    f:SetScript("OnLeave", function() f:SetBackdropBorderColor(.12, .22, .28, 1) end)
    return f
end
function B:SelectView(mode, category)
    FS.db.bags.viewMode = mode or "categories"
    FS.db.bags.category = category or "All"
    self.page, self.selected, self.itemOptions = 1, nil, false
    self:Refresh()
end
function B:AddCategory(name)
    if InCombatLockdown() or type(name) ~= "string" then return false end
    name = name:match("^%s*(.-)%s*$")
    if #name < 1 or #name > 24 or name:find("[%c|]") or #FS.db.bags.customCategories >= 12 then
        return false, "Use 1-24 characters. Up to 12 custom categories."
    end
    for _, existing in ipairs(self.categories) do
        if existing:lower() == name:lower() or (self.categoryNames[existing] or ""):lower() == name:lower() then return false, "That category already exists." end
    end
    for _, reserved in ipairs({ "Recent", "Recent Items", "Free Slots", "OneBag", "MultiBag" }) do
        if reserved:lower() == name:lower() then return false, "Choose a different category name." end
    end
    FS.db.bags.customCategories[#FS.db.bags.customCategories + 1] = name
    self:NormalizeSettings()
    if self.selected then self:AssignCategory(name) end
    self.status = "Category added. Select an item, then More item options to assign it."
    self:Refresh(); return true
end
function B:CreateSidebar(f)
    f.sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.sidebar:SetPoint("TOPLEFT", 1, -62); f.sidebar:SetSize(194, 390)
    local bg = fill(f.sidebar, .025, .035, .05); bg:SetAllPoints()
    local border = fill(f.sidebar, .12, .25, .3); border:SetWidth(1)
    border:SetPoint("TOPRIGHT"); border:SetPoint("BOTTOMRIGHT")
    f.sidebarTitle=text(f.sidebar, "CATEGORIES", 12, -12, 170); f.sidebarTitle:SetTextColor(.5, .7, .8)
    f.sidebar:EnableMouseWheel(true)
    f.sidebar:SetScript("OnMouseWheel", function(_, delta)
        self.sidebarOffset = math.max(0, math.min(self.sidebarMax or 0, (self.sidebarOffset or 0) - delta))
        self:Refresh()
    end)
    f.sidebarRows = {}
    for i = 1, 18 do
        local c = control(f.sidebar, "", 7, -34 - (i - 1) * 32, 180, function(control)
            if control.entry then self:SelectView(control.entry.mode, control.entry.category) end
        end)
        c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(22, 22); c.icon:SetPoint("LEFT", 5, 0)
        c.caption:ClearAllPoints(); c.caption:SetPoint("LEFT", 34, 0); c.caption:SetWidth(117)
        c.count = text(c, "", 151, -7, 23); c.count:SetJustifyH("RIGHT")
        f.sidebarRows[i] = c
    end
    f.addCategory = control(f.sidebar, "+ Add category", 7, -330, 180, function()
        f.categoryDialog:SetShown(not f.categoryDialog:IsShown())
        if f.categoryDialog:IsShown() then f.categoryName:SetFocus() end
    end)
    f.sidebarHint = text(f.sidebar, "Scroll for more categories", 12, -363, 174)
    f.sidebarHint:SetTextColor(.48, .6, .68)
    f.categoryDialog = CreateFrame("Frame", nil, f, "BackdropTemplate")
    local panel = f.categoryDialog; panel:SetSize(350, 164); panel:SetPoint("CENTER")
    panel:SetFrameLevel(f:GetFrameLevel() + 40); panel:EnableMouse(true)
    FS.HUD:Skin(panel); panel:SetBackdropColor(.025, .035, .05, 1)
    text(panel, "New category", 16, -15, 318)
    f.categoryName = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    local input = f.categoryName; input:SetSize(318, 28); input:SetPoint("TOPLEFT", 16, -43)
    input:SetFontObject("ForeverSuiteFontSmall"); input:SetAutoFocus(false); input:SetTextInsets(8, 8, 0, 0)
    input:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    input:SetBackdropColor(.02, .025, .035, 1); input:SetBackdropBorderColor(.15, .7, .8, 1)
    input:SetMaxLetters(24)
    f.categoryError = text(panel, "Select an item to assign it immediately.", 16, -81, 318)
    local function save()
        local ok, message = self:AddCategory(input:GetText())
        if ok then input:ClearFocus(); input:SetText(""); panel:Hide()
        else f.categoryError:SetText(message or "Enter a category name.") end
    end
    control(panel, "Add category", 16, -118, 153, save)
    control(panel, "Cancel", 181, -118, 153, function() input:ClearFocus(); panel:Hide() end)
    input:SetScript("OnEnterPressed", save)
    input:SetScript("OnEscapePressed", function() input:ClearFocus(); panel:Hide() end)
    panel:Hide()
    f.placeholders = {}
    for i = 1, 132 do
        local t = fill(f, .06, .085, .1); t:SetSize(38, 38); t:Hide(); f.placeholders[i] = t
    end
    f.recentToggle = control(f, "", 212, -69, 160, function()
        FS.db.bags.showRecent = not FS.db.bags.showRecent; self.page = 1; self:Refresh()
    end)
    f.recentToggle.caption:SetText("Hide recent items")
    f.resize = CreateFrame("Button", nil, f)
    f.resize:SetSize(16, 16); f.resize:SetPoint("BOTTOMRIGHT", -2, 2)
    f.resize.texture = f.resize:CreateTexture(nil, "ARTWORK")
    f.resize.texture:SetAllPoints(); f.resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resize:SetScript("OnMouseDown", function(_, mouse)
        if mouse ~= "LeftButton" or InCombatLockdown() then return end
        local x, y = GetCursorPosition()
        self.resizeStart = { x = x, y = y, width = f:GetWidth(), height = f:GetHeight(), scale = f:GetEffectiveScale() }
        local fx, fy = f:GetCenter(); local ux, uy = UIParent:GetCenter()
        local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if fx and fy and ux and uy then
            f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "CENTER", fx - ux / ratio - f:GetWidth() / 2, fy - uy / ratio + f:GetHeight() / 2)
        end
        f.resize:SetScript("OnUpdate", function()
            if InCombatLockdown() or not self.resizeStart then return end
            local cx, cy = GetCursorPosition(); local start = self.resizeStart
            FS.db.bags.width = math.max(660, math.min(1100, start.width + (cx - start.x) / start.scale))
            FS.db.bags.height = math.max(420, math.min(780, start.height - (cy - start.y) / start.scale))
            self:Refresh()
        end)
    end)
    f.resize:SetScript("OnMouseUp", function()
        if self.resizeStart and not InCombatLockdown() then f:GetScript("OnDragStop")(f) end
        self.resizeStart = nil; f.resize:SetScript("OnUpdate", nil)
    end)
    f:HookScript("OnHide", function()
        self.resizeStart = nil; f.resize:SetScript("OnUpdate", nil); input:ClearFocus(); panel:Hide()
    end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) self.page = math.max(1, self.page - delta); self:Refresh() end)
    f:SetScript("OnUpdate", function(_, elapsed)
        self.recentElapsed = (self.recentElapsed or 0) + elapsed
        if self.recentElapsed < 10 or InCombatLockdown() then return end
        self.recentElapsed = 0
        local changed = false
        for id, time in pairs(self.recentItems or {}) do
            if GetTime() - time >= 600 then self.recentItems[id] = nil; changed = true end
        end
        if changed then self:Refresh() end
    end)
end
function B:RefreshSidebar(view)
    local f, db = self.window, FS.db.bags
    local width, height = db.width, db.height
    f.title:SetText("INVENTORY   " .. (view.capacity - view.free) .. " / " .. view.capacity)
    local H=FS.HUD
    local _,fontSize=f.title:GetFont(); fontSize=fontSize or 14
    local large=fontSize>14
    local sidebarWidth=large and math.min(math.floor(width*.42),math.max(194,math.ceil(fontSize*12+36))) or 194
    local contentX=sidebarWidth+18; local contentWidth=width-contentX-12
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
    local function fit(b,w,lines)
        b:SetWidth(w); b.caption:SetWidth(w-16)
        local h=H:TextHeight(b.caption,w-16,lines or 2); b:SetHeight(math.max(28,h+12))
        return b:GetHeight()
    end
    local top=62
    if large then
        H:TextHeight(f.title,width-60,2)
        top=math.max(62,18+f.title:GetHeight()+14)
        at(f.search,contentX,top); f.search:SetWidth(contentWidth)
        local _,searchSize=f.search:GetFont(); f.search:SetHeight(math.max(24,(searchSize or 14)+12))
        top=top+f.search:GetHeight()+12
    else at(f.search,width-312,12); f.search:SetWidth(268); f.search:SetHeight(24) end
    f.sidebar:SetWidth(sidebarWidth); f.sidebar:SetHeight(height-113)
    f.sidebarTitle:SetWidth(sidebarWidth-24); H:TextHeight(f.sidebarTitle,sidebarWidth-24,2)
    local toolbarBottom
    if large then
        local controlWidth=math.floor((contentWidth-8)/2); local rowHeight=0
        for _,b in ipairs({f.back,f.organize,f.more,f.recentToggle}) do rowHeight=math.max(rowHeight,fit(b,controlWidth,2)) end
        for i,b in ipairs({f.back,f.organize,f.more,f.recentToggle}) do at(b,contentX+(i-1)%2*(controlWidth+8),top+math.floor((i-1)/2)*(rowHeight+8)) end
        toolbarBottom=top+2*(rowHeight+8)+4
    else
        at(f.back,212,62); f.back:SetWidth(122); f.back:SetHeight(26)
        at(f.organize,342,62); f.organize:SetWidth(78); f.organize:SetHeight(26)
        at(f.more,428,62); f.more:SetWidth(102); f.more:SetHeight(26)
        at(f.recentToggle,538,62); f.recentToggle:SetWidth(width-550); f.recentToggle:SetHeight(28); f.recentToggle.caption:SetWidth(width-566)
        toolbarBottom=100
        for _,b in ipairs({f.back,f.organize,f.more}) do b.caption:SetWidth(b:GetWidth()-16); H:TextHeight(b.caption,b:GetWidth()-16,1) end
    end
    f.back:SetText("Control Center")
    f.filter:Hide(); f.filterMenu:Hide(); f.categoryHint:Hide()
    f.recentToggle.caption:SetText(db.showRecent and "Hide recent items" or "Show recent items")
    local footerReserve=large and math.max(120,fontSize*5+30) or 120
    local viewportHeight=large and math.max(height,toolbarBottom+footerReserve+fontSize+56) or height
    self.textLayout={width=width,height=height,viewportHeight=viewportHeight,contentX=contentX,contentWidth=contentWidth,contentTop=toolbarBottom,
        headerHeight=large and fontSize+12 or 26,footerReserve=footerReserve,large=large,fontSize=fontSize}
    height=viewportHeight; f.sidebar:SetHeight(height-113)
    local counts, total = {}, 0
    for _, row in ipairs(view.plan.items) do
        local name = self:Category(row); counts[name] = (counts[name] or 0) + 1; total = total + 1
    end
    local entries = {
        { title = "All Items", mode = "categories", category = "All", icon = icons.All, count = total },
        { title = "OneBag", mode = "onebag", category = "All", icon = 133634, count = total },
        { title = "MultiBag", mode = "multibag", category = "All", icon = 133633, count = total },
        { title = "Recent Items", mode = "recent", category = "All", icon = 134377, count = #self:RecentRows({ rows = view.plan.items }) },
    }
    for _, name in ipairs(self.categories) do
        local custom = false; for _, value in ipairs(db.customCategories) do if value == name then custom = true end end
        if name ~= "All" and (name == "Favorites" or (counts[name] or 0) > 0 or custom or name == db.category) then
            entries[#entries + 1] = { title = self.categoryNames[name] or name, mode = "categories", category = name, icon = icons[name] or 134400, count = counts[name] or 0 }
        end
    end
    local sidebarTop=large and 18+f.sidebarTitle:GetHeight() or 34
    local rowHeight=large and math.max(32,2*(fontSize+3)+12) or 32
    local addHeight=large and fit(f.addCategory,sidebarWidth-14,2) or 28
    f.addCategory:SetWidth(sidebarWidth-14)
    f.sidebarHint:SetWidth(sidebarWidth-24); local hintHeight=H:TextHeight(f.sidebarHint,sidebarWidth-24,2)
    local sidebarBottom=height-113-addHeight-hintHeight-24
    local visible = math.max(1, math.min(18, math.floor((sidebarBottom-sidebarTop) / rowHeight)))
    self.sidebarMax = math.max(0, #entries - visible)
    self.sidebarOffset = math.max(0, math.min(self.sidebarOffset or 0, self.sidebarMax))
    for i, c in ipairs(f.sidebarRows) do
        local entry = i <= visible and entries[i + self.sidebarOffset] or nil
        c.entry = entry; c:SetShown(entry ~= nil)
        if entry then
            c:SetWidth(sidebarWidth-14); c:SetHeight(large and rowHeight-4 or 28); at(c,7,sidebarTop+(i-1)*rowHeight)
            c.caption:SetText(entry.title); c.count:SetText(entry.count); c.icon:SetTexture(entry.icon)
            local countWidth=large and math.max(32,fontSize*2.5) or 23
            c.caption:SetWidth(sidebarWidth-60-countWidth); if c.caption.SetNonSpaceWrap then c.caption:SetNonSpaceWrap(true) end; H:TextHeight(c.caption,sidebarWidth-60-countWidth,2)
            at(c.count,sidebarWidth-22-countWidth,large and (c:GetHeight()-fontSize-3)/2 or 7)
            H:TextHeight(c.count,countWidth,1)
            local active = db.category == entry.category and (db.category ~= "All" or db.viewMode == entry.mode)
            c:SetBackdropColor(active and .065 or .025, active and .16 or .045, active and .2 or .065, 1)
            c.caption:SetTextColor(active and .3 or .8, active and .9 or .85, active and 1 or .88)
        end
    end
    if large then
        at(f.addCategory,7,height-113-hintHeight-addHeight-18); at(f.sidebarHint,12,height-113-hintHeight-8)
    else
        at(f.addCategory,7,height-178); at(f.sidebarHint,12,height-141)
    end
    f.sidebarHint:SetShown(self.sidebarMax > 0)
end
