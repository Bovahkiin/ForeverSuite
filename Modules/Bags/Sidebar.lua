local _, FS = ...
local B, V = FS.modules.Bags, FS.modules.Vendor
local categoryIcons = {
    Favorites = "Star", Gear = "Gear", Consumables = "Potion",
    Ammo = "Ammo", Materials = "Stock", ["Quest Items"] = "Quests", Junk = "Junk",
    Bags = "Bags", Stock = "Statistics", Gems = "Gem", Recipes = "Guide",
    Professions = "Professions", Keys = "Keys", Pets = "Pet", Mounts = "Mounts",
}
local function text(parent, value, x, y, width)
    local f = FS.Widgets:Label(parent, "ForeverSuiteFontSmall")
    B:StorageText(f)
    f:SetText(value)
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT")
    return f
end
local function control(parent, caption, x, y, width, action)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(width, 28); f:SetPoint("TOPLEFT", x, y)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f.caption = text(f, caption, 8, -7, width - 16)
    B:StorageSkin(f, "button")
    f:SetScript("OnClick", action)
    f:SetScript("OnEnter", function() B:StorageHighlight(f, f.fsStorageSelected, true) end)
    f:SetScript("OnLeave", function() B:StorageHighlight(f, f.fsStorageSelected) end)
    return f
end
function B:SelectView(mode, category)
    FS.db.bags.viewMode = mode or "categories"
    FS.db.bags.category = category or "All"
    self.page, self.selected, self.itemOptions, self.inspectOpen = 1, nil, false, false
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
    self:StorageSkin(f.sidebar, "slot")
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
    f.resize = CreateFrame("Button", nil, f)
    f.resize:SetSize(16, 16); f.resize:SetPoint("BOTTOMRIGHT", -2, 2)
    f.resize.texture = f.resize:CreateTexture(nil, "ARTWORK")
    f.resize.texture:SetAllPoints(); f.resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resize:SetScript("OnMouseDown", function(_, mouse)
        if mouse ~= "LeftButton" or InCombatLockdown() then return end
        local x, y = GetCursorPosition()
        self.resizeStart = { x = x, y = y, width = FS.db.bags.width, height = FS.db.bags.height, scale = f:GetEffectiveScale() }
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
    local style=self:StorageLayout()
    local width, height = self:StorageWidth(), db.height
    local sidebar=style=="Vault"
    local fontSize=select(2,f.title:GetFont()) or 14
    local sidebarWidth=math.max(142,math.min(232,fontSize*7+42))
    local contentX=sidebar and sidebarWidth+29 or 14
    local contentWidth=width-contentX-14
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
    local list=style=="Ledger"
    local top=self:LayoutStorageHeader(f,width,"Inventory",false)
    f.layoutPicker:SetText(style)
    self:StorageArrow(f.layoutPicker,"down","RIGHT")
    self:StorageArrow(f.filter,not sidebar and "down" or nil,"RIGHT")
    f.organize:SetShown(not list and style~="Satchels")
    f.filter:SetShown(not sidebar)
    f.sidebar:SetShown(sidebar)
    local controls={}
    if not sidebar then controls[#controls+1]={f.filter,102} end
    if f.organize:IsShown() then controls[#controls+1]={f.organize,92} end
    controls[#controls+1]={f.layoutPicker,126}
    controls[#controls+1]={f.more,100}
    self:StorageHighlight(f.organize,db.sort=="name")
    local bodyTop=self:LayoutStorageToolbar(f,width,top,controls)
    local slotSize=style=="Field Kit" and 34 or list and math.max(28,fontSize+9) or 38
    local contentTop=self:LayoutStorageColumns(f,list,contentX,bodyTop,contentWidth,slotSize,self.quantitySort)
    local footerReserve=math.max(112,fontSize*3+62)
    local merchant=V.merchantOpen and MerchantFrame and MerchantFrame:IsShown() and V:Settings().enabled
    local minContent=math.max(90,fontSize+64)+(merchant and 58 or 0)
    local viewportHeight=math.max(style=="Field Kit" and math.min(height,408) or height,contentTop+footerReserve+minContent)
    self.textLayout={width=width,height=height,viewportHeight=viewportHeight,contentX=contentX,contentWidth=contentWidth,contentTop=contentTop,
        headerHeight=math.max(27,fontSize+10),footerReserve=footerReserve,slotSize=slotSize,fontSize=fontSize}
    self:PlaceStorageTools(f)
    if not sidebar then return end

    local H=FS.HUD
    local sidebarHeight=viewportHeight-bodyTop-math.max(58,fontSize*2+24)
    f.sidebar:SetSize(sidebarWidth,sidebarHeight); at(f.sidebar,14,bodyTop)
    f.sidebarTitle:SetWidth(sidebarWidth-24); H:TextHeight(f.sidebarTitle,sidebarWidth-24,1)
    local counts={}
    for _, row in ipairs(view.plan.items) do
        local name = self:Category(row,true)
        counts[name] = (counts[name] or 0) + 1
        if db.favorites[row.id] then counts.Favorites=(counts.Favorites or 0)+1 end
    end
    local entries={
        {title="All items",category="All",icon="Menu",count=#view.plan.items},
        {title="Recent items",category="All",mode="recent",icon="Cooldowns",count=#self:RecentRows({rows=view.plan.items})},
    }
    for _, name in ipairs(self.categories) do
        local custom
        for _,value in ipairs(db.customCategories) do if value==name then custom=true; break end end
        if name~="All" and (name=="Favorites" or counts[name] or custom or name==db.category) then
            entries[#entries+1]={title=self.categoryNames[name] or name,category=name,icon=categoryIcons[name] or "Category",count=counts[name] or 0}
        end
    end
    local sidebarTop=18+f.sidebarTitle:GetHeight()
    local rowHeight=math.max(29,fontSize+13)
    local visible=math.max(1,math.min(#f.sidebarRows,math.floor((sidebarHeight-sidebarTop-32)/rowHeight)))
    self.sidebarMax=math.max(0,#entries-visible)
    self.sidebarOffset=math.min(self.sidebarOffset or 0,self.sidebarMax)
    for i,c in ipairs(f.sidebarRows) do
        local entry=i<=visible and entries[i+self.sidebarOffset] or nil
        c.entry=entry; c:SetShown(entry~=nil)
        if entry then
            c:SetSize(sidebarWidth-12,rowHeight-4); at(c,6,sidebarTop+(i-1)*rowHeight)
            c.caption:SetText(entry.title); c.count:SetText(entry.count)
            FS:SetMenuIcon(c.icon,entry.icon)
            c.icon:SetSize(16,16); c.caption:ClearAllPoints(); c.caption:SetPoint("LEFT",26,0)
            local countWidth=math.max(24,fontSize*1.7)
            H:TextHeight(c.caption,sidebarWidth-countWidth-47,1)
            c.count:ClearAllPoints(); c.count:SetPoint("RIGHT",-7,0)
            H:TextHeight(c.count,countWidth,1)
            self:StorageHighlight(c,db.category==entry.category and (entry.mode or "categories")==db.viewMode)
        end
    end
    at(f.sidebarHint,12,sidebarHeight-23)
    H:TextHeight(f.sidebarHint,sidebarWidth-24,1)
    f.sidebarHint:SetShown(self.sidebarMax>0)
end

function B:PlaceStorageTools(f)
    local button=f.fsContextLauncher
    if not button then return end
    if button:GetParent()~=f then button:SetParent(f) end
    button:SetText("Bag tools"); button:SetWidth(102)
    FS.HUD:FitButton(button,1,25)
    button:ClearAllPoints(); button:SetPoint("BOTTOM",f,"BOTTOM",0,6)
    if not button.fsStorageControl then
        self:StorageSkin(button,"button"); button.fsStorageControl=true
    end
end
