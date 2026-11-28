local _, FS = ...
local B = FS.modules.Bags

B.storageLayouts = { "Vault", "Field Kit", "Quartermaster", "Ledger", "Satchels" }
B.storageDescriptions = {
    Vault = "Categories on the left, with items grouped by type.",
    ["Field Kit"] = "One compact grid with a category filter.",
    Quartermaster = "View bags and bank together and move selected stacks at a banker.",
    Ledger = "Read item names, categories, stack sizes and storage locations in a list.",
    Satchels = "See each bag or bank tab in its own collapsible section.",
}

function B:StorageLayout()
    local name = FS.db.bags.storageLayout
    return self.storageDescriptions[name] and name or "Satchels"
end

function B:StorageWidth()
    local width = FS.db.bags.width or 820
    local layout = self:StorageLayout()
    if layout == "Field Kit" then return math.min(width, 560) end
    if layout == "Quartermaster" then return math.min(width, 620) end
    return width
end

function B:SetStorageLayout(name,pane)
    if InCombatLockdown() or not self.storageDescriptions[name] then return false end
    FS.db.bags.storageLayout = name
    FS.db.bags.viewMode, FS.db.bags.category = "categories", "All"
    self.page, self.selected, self.itemOptions, self.inspectOpen = 1, nil, false, false
    local bank = FS.modules.Bank
    bank.page, bank.selected, bank.categoryIndex, bank.transferStatus = 1, nil, 1, nil
    if bank.open then
        if name=="Quartermaster" then bank:ShowWindow()
        else bank:SelectStoragePane(pane or bank.storagePane or "bank") end
    else bank:Render() end
    self:Refresh()
    FS.modules.Profiles:PersistCurrent()
    return true
end

function B:StorageMenu(host, anchor, entries)
    if InCombatLockdown() then return end
    local H=FS.HUD
    local menu=host.storageMenu
    if not menu then
        menu=CreateFrame("Frame",nil,host,"BackdropTemplate")
        host.storageMenu=menu; menu.rows={}
        menu:EnableMouse(true); menu:SetClampedToScreen(true)
        menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetFrameLevel(host:GetFrameLevel()+40)
        self:StorageSkin(menu,"panel")
        menu:Hide()
    end
    if menu:IsShown() and menu.anchor==anchor then menu:Hide(); return end
    if host.filterMenu then host.filterMenu:Hide() end
    if host.options then host.options:Hide() end
    local y=8
    for i,entry in ipairs(entries) do
        local row=menu.rows[i]
        if not row then
            row=H:Button(menu,"",8,0,208,function(button) menu:Hide(); button.entry.choose() end)
            self:StorageSkin(row,"button")
            menu.rows[i]=row
        end
        row.entry=entry; row:SetText(entry.name); H:SetHelp(row,entry.help)
        self:StorageHighlight(row,entry.selected)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",8,-y); row:Show()
        y=y+H:FitButton(row,2)+4
    end
    for i=#entries+1,#menu.rows do menu.rows[i]:Hide(); menu.rows[i].entry=nil end
    menu:SetSize(224,y+4); menu.anchor=anchor
    menu:ClearAllPoints(); menu:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-4); menu:Show()
end

function B:ChooseStorageLayout(host,anchor)
    local entries={}
    for _,name in ipairs(self.storageLayouts) do
        entries[#entries+1]={name=name,help=self.storageDescriptions[name],selected=self:StorageLayout()==name,
            choose=function() self:SetStorageLayout(name,host==FS.modules.Bank.window and "bank" or "bags") end}
    end
    self:StorageMenu(host,anchor,entries)
end

function B:StorageBagName(bag, bank)
    if bank then
        if bag == (BANK_CONTAINER or -1) then return "Bank storage" end
        local labels = FS.modules.Bank.bagNames
        return labels and labels[bag] or ("Bank tab " .. bag)
    end
    if bag == 0 then return BACKPACK_TOOLTIP or "Backpack" end
    return GetBagName and GetBagName(bag) or ("Bag " .. bag)
end

-- These windows own their flat surfaces so the selected theme controls the
-- accents without putting textured panels behind every inventory slot.
local skins = setmetatable({}, { __mode = "k" })
local palette
function B:StorageText(region)
    if region.fsStorageText then return end
    FS.Themes:ReleaseFont(region)
    region.fsStorageText=true
end
local function colors(index)
    local r, g, b = FS.Themes:Accent(index)
    return {
        accent = { .38 + r * .62, .38 + g * .62, .38 + b * .62, 1 },
        border = { .19 + r * .28, .19 + g * .28, .2 + b * .28, 1 },
        panel = { .045 + r * .06, .053 + g * .06, .069 + b * .07, 1 },
        header = { .064 + r * .10, .075 + g * .10, .095 + b * .11, 1 },
        section = { .061 + r * .08, .069 + g * .08, .085 + b * .08, 1 },
        button = { .064 + r * .10, .071 + g * .10, .085 + b * .10, 1 },
        slot = { .035 + r * .05, .037 + g * .05, .045 + b * .05, 1 },
        selected = { .09 + r * .2, .095 + g * .2, .11 + b * .2, 1 },
    }
end

local function paint(frame, role, custom)
    local p = custom or palette
    local fill=p[role]
    if frame.fsStorageBare then
        frame:SetBackdropColor(0,0,0,0); frame:SetBackdropBorderColor(0,0,0,0)
    else
        frame:SetBackdropColor(unpack(frame.fsStorageSelected and p.selected or fill))
        if frame.fsStorageHover or frame.fsStorageSelected then frame:SetBackdropBorderColor(unpack(p.accent))
        elseif frame.fsStorageList then frame:SetBackdropBorderColor(0,0,0,0)
        else frame:SetBackdropBorderColor(unpack(p.border)) end
    end
    if frame.fsStorageAccent then frame.fsStorageAccent:SetColorTexture(unpack(p.accent)) end
    if frame.fsStorageArrow then
        for _,bar in ipairs(frame.fsStorageArrow) do bar:SetColorTexture(unpack(p.accent)) end
    end
    local caption = frame.caption or frame.fsLabel
    if caption then
        B:StorageText(caption)
        if frame.fsStorageBare then caption:SetTextColor(unpack(p.accent))
        else caption:SetTextColor(.91,.94,.98,1) end
    end
end

function B:StorageArrow(control,direction,side)
    if control.fsStorageArrowDirection==direction and control.fsStorageArrowSide==side then return end
    local bars=control.fsStorageArrow
    if not direction then
        if bars then for _,bar in ipairs(bars) do bar:Hide() end end
        control.fsStorageArrowDirection,control.fsStorageArrowSide=nil,side
        return
    end
    if not bars then
        bars={}
        for i=1,4 do
            bars[i]=control:CreateTexture(nil,"OVERLAY")
            bars[i]:SetColorTexture(unpack(palette.accent))
        end
        control.fsStorageArrow=bars
    end
    control.fsStorageArrowDirection,control.fsStorageArrowSide=direction,side
    local x=side=="LEFT" and 7 or -12
    local directionAcross=direction=="right"
    for i,bar in ipairs(bars) do
        local span=10-2*i
        local offset=(i-2.5)*2
        bar:ClearAllPoints()
        bar:SetSize(directionAcross and 2 or span,directionAcross and span or 2)
        bar:SetPoint("CENTER",control,side,x+(directionAcross and offset or 0),
            directionAcross and 0 or (direction=="down" and -offset or offset))
        bar:Show()
    end
end

function B:StorageFavorite(cell,row)
    local favorite=row and row.id and FS.db.bags.favorites[row.id]
    local badge=cell.fsStorageFavorite
    if favorite and not badge then
        badge=cell:CreateTexture(nil,"OVERLAY",nil,2)
        badge:SetSize(14,14); badge:SetPoint("TOPRIGHT",cell.icon,"TOPRIGHT",1,1)
        cell.fsStorageFavorite=badge
        FS:SetMenuIcon(badge,"Star")
    end
    if badge then badge:SetShown(not not favorite) end
end

function B:StorageGroupHeader(header,satchel,collapsed)
    header.fsStorageBare=true
    paint(header,"button")
    self:StorageArrow(header,satchel and (collapsed and "right" or "down") or nil,"LEFT")
    local caption=header.caption or header.fsLabel
    local inset=satchel and 19 or 2
    caption:ClearAllPoints(); caption:SetPoint("LEFT",header,"LEFT",inset,0)
    FS.HUD:TextHeight(caption,header:GetWidth()-inset-5,1)
    if not header.fsStorageRule then
        local line=header:CreateTexture(nil,"BORDER")
        line:SetPoint("BOTTOMLEFT",0,0); line:SetPoint("BOTTOMRIGHT",0,0); line:SetHeight(1)
        header.fsStorageRule=line
    end
    header.fsStorageRule:SetColorTexture(unpack(palette.border))
    header.fsStorageRule:SetShown(not satchel)
end

function B:StorageBand(frame,footer,detail)
    if not frame.storageBand then
        frame.storageBand=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        frame.storageBand:SetFrameLevel(frame:GetFrameLevel())
        self:StorageSkin(frame.storageBand,"header")
    end
    local band=frame.storageBand
    band:ClearAllPoints(); band:SetPoint("TOPLEFT",1,-footer); band:SetPoint("BOTTOMRIGHT",-1,1)
    if not frame.storageDivider then
        frame.storageDivider=frame:CreateTexture(nil,"BORDER")
        frame.storageDivider:SetHeight(1)
    end
    local line=frame.storageDivider
    line:ClearAllPoints(); line:SetPoint("TOPLEFT",14,-detail); line:SetPoint("TOPRIGHT",-14,-detail)
    line:SetColorTexture(unpack(palette.border))
end

local function position(frame,x,y)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y)
end

function B:CreateStorageHeader(frame,title,bank)
    local H=FS.HUD
    local p=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    frame.storageHeader=p
    p:SetPoint("TOPLEFT",1,-2); p:SetPoint("TOPRIGHT",-1,-2); p:SetHeight(58)
    self:StorageSkin(p,"header")
    p.logo=p:CreateTexture(nil,"ARTWORK"); p.logo:SetTexture(FS.emblem); p.logo:SetSize(34,34); p.logo:SetPoint("LEFT",13,0)
    p.brand=p:CreateFontString(nil,"OVERLAY"); p.brand:SetFont(FS.font,10,""); p.brand:SetPoint("TOPLEFT",56,-11)
    p.brand:SetText("FOREVERSUITE"); p.brand:SetTextColor(.79,.71,.55,1)
    p.title=title; title:SetParent(p)
    p.close=H:Button(p,"×",0,0,34,function() frame:Hide() end)
    p.bags=H:Button(p,"Bags",0,0,66,function() FS.modules.Bank:SelectStoragePane("bags") end)
    p.bank=H:Button(p,"Bank",0,0,66,function() FS.modules.Bank:SelectStoragePane("bank") end)
    for _,control in ipairs({p.bags,p.bank,p.close}) do self:StorageSkin(control,"button") end
    self:StorageHighlight(p.bags,not bank); self:StorageHighlight(p.bank,bank)
    H:SetHelp(p.bank,"Visit a banker to open your bank.")
    H:SetHelp(p.close,"Close")
    return p
end

function B:LayoutStorageHeader(frame,width,title,bank)
    local H=FS.HUD
    local p=frame.storageHeader
    p.title:SetText(title); position(p.title,56,25)
    local titleHeight=H:TextHeight(p.title,width-262,2)
    local _,fontSize=p.title:GetFont()
    local tabWidth=math.max(64,(fontSize or 14)*3.1)
    local closeWidth=math.max(30,(fontSize or 14)+12)
    local height=0
    for i,control in ipairs({p.close,p.bank,p.bags}) do
        local w=i==1 and closeWidth or tabWidth
        control:SetWidth(w); height=math.max(height,H:FitButton(control,1))
    end
    local x=width-13-closeWidth
    position(p.close,x,12); position(p.bank,x-8-tabWidth,12); position(p.bags,x-14-2*tabWidth,12)
    H:TextHeight(p.title,math.max(115,x-14-2*tabWidth-65),2)
    p:SetHeight(math.max(57,25+math.max(titleHeight,p.title:GetHeight())+9,24+height))
    local canBank=FS.modules.Bank.open and FS:IsModuleEnabled("Bank")
    p.bank:SetEnabled(not not (canBank and not bank))
    if not bank then
        if canBank then p.bank.fsLabel:SetTextColor(.91,.94,.98,1)
        else p.bank.fsLabel:SetTextColor(.58,.65,.71,1) end
    end
    p.bags:SetEnabled(bank and FS:IsModuleEnabled("Bags"))
    return p:GetHeight()+10
end

function B:LayoutStorageToolbar(frame,width,top,controls)
    local H=FS.HUD
    local _,fontSize=frame.search:GetFont()
    fontSize=fontSize or 14
    local available=width-28
    local gutter=6
    local used,height=0,math.max(28,fontSize+11)
    for _,entry in ipairs(controls) do
        local control=entry[1]
        local caption=control.caption or control.fsLabel
        local _,textSize=caption:GetFont()
        local captionWidth=caption.GetUnboundedStringWidth and caption:GetUnboundedStringWidth()
            or #control:GetText()*(textSize or fontSize)*.65
        local arrow=control.fsStorageArrowDirection and 19 or 0
        local padding=14+arrow
        local maxWidth=math.min(available,math.max(entry[2],math.floor(available*.5)))
        local w=math.min(maxWidth,math.max(entry[2],math.ceil(captionWidth)+padding))
        control:SetWidth(w)
        caption:ClearAllPoints(); caption:SetPoint("CENTER",control,"CENTER",-arrow/2,0)
        height=math.max(height,H:TextHeight(caption,w-padding,2)+10)
        used=used+w+gutter
    end
    local stacked=available-used<math.max(145,fontSize*6)
    local searchWidth=stacked and available or available-used
    position(frame.search,14,top); frame.search:SetSize(searchWidth,height)
    local hint=frame.search.placeholder or frame.searchHint
    if hint then hint:SetWidth(searchWidth-19) end
    local x=stacked and 14 or 14+searchWidth+gutter
    local y=stacked and top+height+gutter or top
    for _,entry in ipairs(controls) do
        local control=entry[1]
        local w=control:GetWidth()
        if stacked and x+w>width-14+.01 then x=14; y=y+height+gutter end
        position(control,x,y); control:SetHeight(height); x=x+w+gutter
    end
    return y+height+10
end

function B:CreateStorageColumns(frame, nameSort, quantitySort)
    local H=FS.HUD
    local names=H:Button(frame,"Item",0,0,100,nameSort)
    local qty=H:Button(frame,"Qty",0,0,50,quantitySort)
    self:StorageSkin(names,"button"); self:StorageSkin(qty,"button")
    frame.storageColumns={names,H:Label(frame,"Category",0,0,100),H:Label(frame,"Location",0,0,100),qty}
    self:StorageText(frame.storageColumns[2]); self:StorageText(frame.storageColumns[3])
end

function B:LayoutStorageColumns(frame,list,x,y,width,size,quantity)
    local columns=frame.storageColumns
    local height=0
    for _,column in ipairs(columns) do column:SetShown(list) end
    if not list then return y end
    local H=FS.HUD
    self:StorageArrow(columns[1],not quantity and "up" or nil,"RIGHT")
    self:StorageArrow(columns[4],quantity and "down" or nil,"RIGHT")
    for i,column in ipairs(columns) do
        local start=({0,.50,.73})[i]
        if i==1 or i==4 then
            local _,fontSize=column.fsLabel:GetFont()
            local base=i==1 and 100 or 66
            local w=math.max(base,(fontSize or 14)*2.8+24)
            column:SetWidth(math.min(w,width*.24))
            local arrow=column.fsStorageArrowDirection and 17 or 0
            local caption=column.fsLabel
            caption:ClearAllPoints(); caption:SetPoint("CENTER",column,"CENTER",-arrow/2,0)
            column:SetHeight(math.max(25,H:TextHeight(caption,column:GetWidth()-10-arrow,1)+10))
            height=math.max(height,column:GetHeight())
        else
            height=math.max(height,H:TextHeight(column,i==2 and width*.23-8 or width*.27-72,1)+5)
        end
        position(column,x+(start and start*width or width-column:GetWidth()),y+((i==2 or i==3) and 5 or 0))
    end
    return y+math.max(height,size)+5
end

function B:StorageSkin(frame, role, previewIndex)
    frame.fsThemeTransparent = true
    local themes = FS.Themes
    local registered = themes.frames[frame]
    if registered then
        for _, part in ipairs(registered.parts or {}) do part:Hide() end
        themes.frames[frame] = nil
    end
    frame:SetBackdrop({ bgFile = FS.HUD.texture, edgeFile = FS.HUD.texture, edgeSize = 1 })
    palette = palette or colors()
    if previewIndex then
        paint(frame, role, colors(previewIndex))
    else
        skins[frame] = role
        paint(frame, role)
    end
end

function B:StorageHighlight(frame, selected, hover)
    if frame.fsStorageSelected==selected and frame.fsStorageHover==hover then return end
    frame.fsStorageSelected, frame.fsStorageHover = selected, hover
    if skins[frame] then paint(frame, skins[frame]) end
end

function B:RefreshStorageTheme()
    palette = colors()
    for frame, role in pairs(skins) do
        paint(frame, role)
        if frame.fsStorageFavorite then FS:SetMenuIcon(frame.fsStorageFavorite,"Star") end
    end
end

function B:StorageWatermark(frame)
    local mark = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    mark:SetTexture(FS.emblem)
    mark:SetSize(174, 174)
    mark:SetPoint("BOTTOMRIGHT", -20, 54)
    mark:SetAlpha(.11)
    return mark
end

function B:StorageCellGeometry(cell, row, list, width, size, bank)
    if cell.fsStorageList~=list or cell.fsStorageSize~=size or (list and cell.fsStorageWidth~=width) then
        cell.fsStorageList,cell.fsStorageSize,cell.fsStorageWidth=list,size,width
        cell:SetSize(list and width or size,size)
        cell.icon:ClearAllPoints()
        cell.icon:SetPoint("LEFT",2,0)
        local iconSize=list and math.min(30,size-4) or size-4
        cell.icon:SetSize(iconSize,iconSize)
        cell.count:ClearAllPoints(); cell.count:SetPoint(list and "RIGHT" or "BOTTOMRIGHT",-3,list and 0 or 2)
        local countWidth=list and math.max(34,size*1.65) or 28
        cell.count:SetWidth(countWidth); cell.count:SetJustifyH("RIGHT")
        if list and not cell.storageText then
            cell.storageText={}
            for i=1,3 do
                cell.storageText[i]=FS.HUD:Label(cell,"",0,0,100)
                self:StorageText(cell.storageText[i])
            end
        end
        if cell.storageText then
            local starts={ iconSize+10, width*.50, width*.73 }
            local ends={ width*.50-8, width*.73-8, width-countWidth-8 }
            for i,text in ipairs(cell.storageText) do
                text:ClearAllPoints(); text:SetPoint("LEFT",cell,"LEFT",starts[i],0)
                text:SetWidth(math.max(20,ends[i]-starts[i]))
                if text.SetMaxLines then text:SetMaxLines(1) end
                text:SetShown(list)
            end
        end
        if skins[cell] then paint(cell,skins[cell]) end
    end
    if list then
        local kind=not row.empty and not row.stock and (row.category or self:Category(row))
        cell.storageText[1]:SetText(row.name or "Empty space")
        cell.storageText[2]:SetText(kind and (self.categoryNames[kind] or kind) or "")
        cell.storageText[3]:SetText(row.bag and self:StorageBagName(row.bag,bank) or "")
        for _,text in ipairs(cell.storageText) do text:SetTextColor(.91,.94,.98,1) end
    end
end

-- All views use the original slot records. Only their grouping and geometry
-- change, so item use, dragging and vendor rules still act on the same slot.
function B:StoragePages(rows, spec)
    local pages, page, offsets = {}, nil, nil
    local lanes = spec.lanes or 1
    local laneWidth = math.floor((spec.width - (lanes - 1) * 12) / lanes)
    local function newPage()
        page = { cells = {}, headers = {}, sections = {} }
        pages[#pages + 1], offsets = page, {}
        for i=1,lanes do offsets[i]=0 end
    end
    newPage()
    local function fitLane(height,wide)
        local lane=1
        if wide then
            for i=2,lanes do offsets[1]=math.max(offsets[1],offsets[i]) end
        else
            for i=2,lanes do if offsets[i]<offsets[lane] then lane=i end end
        end
        if offsets[lane]+height>spec.height or #page.cells>=spec.maxCells then newPage(); lane=1 end
        return lane
    end
    local groups, order = {}, {}
    for name in pairs(spec.seed or {}) do groups[name]={}; order[#order+1]=name end
    for _, row in ipairs(rows) do
        local name = spec.group and spec.group(row) or false
        if not groups[name] then groups[name] = {}; order[#order + 1] = name end
        local group = groups[name]
        group[#group + 1] = row
    end
    if spec.groupOrder then table.sort(order, spec.groupOrder) end
    for _, name in ipairs(order) do
        local group = groups[name]
        local wide = spec.wideGroup==name and lanes>1
        local groupWidth=wide and spec.width or laneWidth
        local pad=spec.cards and 8 or 0
        local columns = spec.list and 1 or math.max(1,math.floor((groupWidth-2*pad+5)/(spec.size+5)))
        local collapsed = spec.collapsed and spec.collapsed[name]
        local headerHeight = name and spec.headerHeight or 0
        local rowHeight = (collapsed or #group==0) and 0 or spec.size
        local lane = fitLane(headerHeight + rowHeight+pad*2,wide)
        local origin=offsets[lane]
        local y = origin+pad
        local x = (lane-1)*(laneWidth+12)
        local function header()
            if not name then return end
            local label = spec.groupLabel and spec.groupLabel(name) or name
            local usage=spec.groupCount and spec.groupCount(name)
            local count=usage and usage.used.." / "..usage.capacity or tostring(#group)
            page.headers[#page.headers + 1] = {
                category = name, x = x+pad, y = y, width = groupWidth-2*pad,
                text = label.."  ·  "..count, collapsed=collapsed,
            }
            y = y + headerHeight
        end
        local function section(bottom)
            if spec.cards then page.sections[#page.sections+1]={x=x,y=origin,width=groupWidth,height=bottom+pad-origin} end
        end
        header()
        if not collapsed then
            local column = 0
            for _, row in ipairs(group) do
                if column == columns then y = y + spec.size + 5; column = 0 end
                if y + spec.size+pad > spec.height or #page.cells >= spec.maxCells then
                    section(y)
                    offsets[lane]=spec.height
                    lane=fitLane(headerHeight+spec.size+pad*2,wide)
                    origin=offsets[lane]
                    y,x,column=origin+pad,(lane-1)*(laneWidth+12),0
                    header()
                end
                page.cells[#page.cells + 1] = { row = row, x = x + pad + column * (spec.size + 5), y = y }
                column = column + 1
            end
            y = y + (column > 0 and spec.size or 0)
        end
        section(y)
        offsets[lane]=y+pad+10
        if wide then for i=2,lanes do offsets[i]=offsets[lane] end end
    end
    return pages
end

function B:DrawStorageSections(frame, layout, x, top)
    local cards=frame.storageSections or {}
    frame.storageSections=cards
    for i,entry in ipairs(layout.sections) do
        local card=cards[i]
        if not card then
            card=CreateFrame("Frame",nil,frame,"BackdropTemplate")
            card:SetFrameLevel(frame:GetFrameLevel())
            card:EnableMouse(false); self:StorageSkin(card,"section")
            cards[i]=card
        end
        position(card,x+entry.x,top+entry.y)
        card:SetSize(entry.width,entry.height); card:Show()
    end
    for i=#layout.sections+1,#cards do cards[i]:Hide() end
end

function B:CreateStoragePreview(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(712, 176)
    frame.labels, frame.slots = {}, {}
    local H = FS.HUD
    for i = 1, 4 do frame.labels[i] = H:Label(frame, "", 0, 0, 150) end
    local icons = { 134414, 134943, 132889, 133628, 134827, 133722 }
    for i = 1, 12 do
        local slot = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        slot.icon = slot:CreateTexture(nil, "ARTWORK"); slot.icon:SetPoint("TOPLEFT", 2, -2); slot.icon:SetSize(22, 22)
        slot.icon:SetTexture(icons[(i - 1) % #icons + 1])
        if i<=3 then
            slot.example=H:Label(slot,({"Healing Potion","Wool Cloth","Silver Ring"})[i],36,-4,210)
            self:StorageText(slot.example)
        end
        frame.slots[i] = slot
    end
    self:StorageWatermark(frame)
    frame:Hide()
    return frame
end

function B:PreviewStorage(frame, name, theme)
    self:StorageSkin(frame, "panel", theme)
    local captions = {
        Vault = { "Categories", "Equipment", "Crafting" },
        ["Field Kit"] = { "All items" },
        Quartermaster = { "Bags", "Bank", "Selected stack" },
        Ledger = { "Item", "Category", "Quantity", "Location" },
        Satchels = { "Backpack", "Linen Bag", "Leather Bag" },
    }
    local positions = {
        Vault = { { 18, 12 }, { 174, 12 }, { 174, 85 } },
        ["Field Kit"] = { { 18, 16 } },
        Quartermaster = { { 18, 12 }, { 250, 12 }, { 485, 12 } },
        Ledger = { { 18, 12 }, { 270, 12 }, { 420, 12 }, { 550, 12 } },
        Satchels = { { 18, 12 }, { 250, 12 }, { 485, 12 } },
    }
    local columns = name == "Field Kit" and 8 or name == "Ledger" and 1 or 4
    for i, label in ipairs(frame.labels) do
        local point = positions[name][i]
        label:SetShown(point ~= nil)
        if point then label:ClearAllPoints(); label:SetPoint("TOPLEFT", point[1], -point[2]); label:SetText(captions[name][i]); label:SetTextColor(.91,.94,.98,1) end
    end
    for i, slot in ipairs(frame.slots) do
        local group = math.floor((i - 1) / columns)
        local x, y = 18 + (i - 1) % columns * 33, 40 + group * 33
        if name == "Vault" then x, y = x + 156, group == 0 and 40 or 110
        elseif name == "Quartermaster" or name == "Satchels" then x, y = x + group * 232, 40 end
        slot:SetShown(name ~= "Ledger" or i <= 3)
        if name == "Vault" and i > 8 then slot:Hide() end
        slot:ClearAllPoints(); slot:SetPoint("TOPLEFT", x, -y)
        slot:SetSize(name == "Ledger" and 670 or 26, 26)
        if slot.example then slot.example:SetShown(name=="Ledger") end
        self:StorageSkin(slot, name == "Ledger" and "button" or "slot", theme)
    end
end
