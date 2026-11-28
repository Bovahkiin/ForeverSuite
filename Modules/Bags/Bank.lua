local _,FS=...
local T=FS.Tools
local B,V,H=FS.modules.Bags,FS.modules.Vendor,FS.HUD
local filters={"All","Favorites","Gear","Consumables","Materials","Quest Items","Empty"}
local K=T:Module("Bank","bank","Bank","Search and organize bank items while visiting a banker.",
    {replace=true,account=false,showEmpty=true},
    {"BANKFRAME_OPENED","BANKFRAME_CLOSED","BANK_TABS_CHANGED","PLAYERBANKSLOTS_CHANGED",
        "PLAYERBANKBAGSLOTS_CHANGED","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED"})
K.options={{key="replace",label="Use ForeverSuite bank"},{key="account",label="Show account bank"},{key="showEmpty",label="Show empty bank spaces"}}
function K:BankType() return Enum and Enum.BankType and (self:Data().account and Enum.BankType.Account or Enum.BankType.Character) end
function K:BagIDs()
    local ids={}; local kind=self:BankType()
    if kind and C_Bank and C_Bank.FetchPurchasedBankTabData then
        for _,tab in ipairs(T:Call(C_Bank.FetchPurchasedBankTabData,kind) or {}) do if T:Number(tab.ID) then ids[#ids+1]=tab.ID end end
    elseif not self:Data().account then
        ids[1]=BANK_CONTAINER or -1
        for i=1,(NUM_BANKBAGSLOTS or 7) do ids[#ids+1]=(NUM_BAG_SLOTS or 4)+i end
    end
    return ids
end
function K:Build()
    self.rows={}; if not self.open then self.status="Visit a banker to view or move bank items."; return end
    local free,capacity,tab=0,0,0
    self.bagNames={}; self.bagUsage={}
    for _,bag in ipairs(self:BagIDs()) do
        local size=T:Call(C_Container.GetContainerNumSlots,bag) or 0; capacity=capacity+size
        local used=size
        if size>0 and bag~=(BANK_CONTAINER or -1) then
            tab=tab+1; self.bagNames[bag]="Bank tab "..tab
        end
        for slot=1,size do
            local item=V:ReadItem(bag,slot)
            if item then
                item.category=B:Category(item,true); if item.quality==0 and item.category=="Other" then item.category="Junk" end
                item.text=item.category.." | "..item.name.." x"..item.count; self.rows[#self.rows+1]=item
            else
                local raw=T:Call(C_Container.GetContainerItemInfo,bag,slot)
                if not raw then
                    free=free+1; used=used-1
                    if self:Data().showEmpty then self.rows[#self.rows+1]={bag=bag,slot=slot,empty=true,category="Empty",text="Empty space"} end
                end
            end
        end
        if size>0 then self.bagUsage[bag]={used=used,capacity=size} end
    end
    local order={}; for i,name in ipairs(FS.modules.Bags.categories) do order[name]=i end; order.Empty=999
    table.sort(self.rows,function(a,b)
        if a.category~=b.category then return (order[a.category] or 998)<(order[b.category] or 998) end
        if a.text~=b.text then return a.text<b.text end
        if a.bag~=b.bag then return a.bag<b.bag end
        return a.slot<b.slot
    end)
    self.status=free.." free slots  ·  "..(capacity-free).." / "..capacity.." used"
end
function K:RefreshOnTick() return false end
function K:Native(hidden)
    local f=BankFrame; if not f or InCombatLockdown() or (f.IsForbidden and f:IsForbidden()) then return end
    if self.nativeAlpha==nil then
        self.nativeAlpha=f:GetAlpha()
        hooksecurefunc(f,"SetAlpha",function(frame) if self.hideNative and not self.setting then self.setting=true; frame:SetAlpha(0); self.setting=false end end)
    end
    self.hideNative=hidden; self.setting=true; f:SetAlpha(hidden and 0 or self.nativeAlpha); self.setting=false
    FS.modules.Character:NativeMouse(f,hidden)
end
function K:Event(event)
    if event=="BANKFRAME_OPENED" then
        self.open=true
        if self:Data().replace and not InCombatLockdown() then self:Native(true); self:ShowWindow() end
    elseif event=="BANKFRAME_CLOSED" then
        self.open=false; self.storagePane=nil; self:Native(false)
        if self.window then self.window:Hide() end
        B:Refresh()
    elseif event=="PLAYER_REGEN_ENABLED" and self.open and self:Data().replace then
        self:Native(true)
        self:SelectStoragePane(self.storagePane or "bank")
    end
end
local show=K.ShowWindow
function K:ShowWindow()
    if not self.open or InCombatLockdown() or not FS:IsModuleEnabled(self.name) then return show(self) end
    local f=self:CreateWindow()
    self.storagePane="bank"; self.switchingPane=true
    if B:StorageLayout()=="Quartermaster" and FS:IsModuleEnabled("Bags") then
        B:ShowWindow()
        f:ClearAllPoints(); f:SetPoint("RIGHT",B.window,"LEFT",-12,0)
    elseif self.storagePaired and not f.fsContextHost then
        f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER")
    end
    self.storagePaired=B:StorageLayout()=="Quartermaster" and B.window and B.window:IsShown()
    if not self.storagePaired and B.window then B.window:Hide() end
    show(self)
    self.switchingPane=false
    B:Refresh()
end

function K:SelectStoragePane(pane)
    if InCombatLockdown() then return end
    if pane=="bank" then
        if self.open then self:ShowWindow() end
        return
    end
    if not FS:IsModuleEnabled("Bags") then return end
    self.switchingPane=true
    if self.open then self.storagePane="bags" end
    if B:StorageLayout()~="Quartermaster" and self.window then self.window:Hide() end
    B:ShowWindow()
    self.switchingPane=false
    if B.window and B.window.Raise then B.window:Raise() end
end

function K:CloseStorageSession()
    self.storagePane=nil
    self.rows={}; self.selected=nil; self.transferStatus=nil; self.categoryIndex=1
    self:Native(false)
    if self.open then self.open=false; T:Call(CloseBankFrame) end
end

function K:Transfer(row, fromBank)
    if not self.open or not self.window or not self.window:IsShown() or not FS:IsModuleEnabled("Bank")
        or not FS:IsModuleEnabled("Bags") or not row or row.empty or row.stock or not B:Guard() or CursorHasItem() then return false end
    local function finish(message)
        self.transferStatus=fromBank and message or nil
        B.status=not fromBank and message or nil
        self:Refresh(); B:Refresh()
    end
    local ids=self:BagIDs()
    local bankSlot=false
    for _,id in ipairs(ids) do if id==row.bag then bankSlot=true; break end end
    if fromBank~=bankSlot or (not fromBank and (row.bag<0 or row.bag>V:BagLimit())) then return false end
    local current=V:ReadItem(row.bag,row.slot)
    if not current or current.locked or current.id~=row.id or current.link~=row.link or current.count~=row.count
        or (row.guid and current.guid~=row.guid) then finish("The stack changed. Select it again."); return false end
    if fromBank then
        ids={}
        for bag=0,V:BagLimit() do ids[#ids+1]=bag end
    end
    local targetBag,targetSlot
    for _,bag in ipairs(ids) do
        local free,family=T:Call(C_Container.GetContainerNumFreeSlots,bag)
        if V:ValidNumber(free,1,1000) and not V:IsSecret(family) and family==0 then
            for slot=1,(T:Call(C_Container.GetContainerNumSlots,bag) or 0) do
                if not C_Container.GetContainerItemInfo(bag,slot) then targetBag,targetSlot=bag,slot; break end
            end
        end
        if targetSlot then break end
    end
    if not targetSlot then finish("No empty general-purpose space. Drag the stack to move it manually."); return false end
    T:Call(C_Container.PickupContainerItem,row.bag,row.slot)
    if not CursorHasItem() then finish("The stack could not be picked up."); return false end
    if not C_Container.GetContainerItemInfo(targetBag,targetSlot) then
        T:Call(C_Container.PickupContainerItem,targetBag,targetSlot)
    end
    if CursorHasItem() then
        if not C_Container.GetContainerItemInfo(row.bag,row.slot) then
            T:Call(C_Container.PickupContainerItem,row.bag,row.slot)
        end
        ClearCursor()
        finish("The stack could not be moved to that space."); return false
    end
    self.selected,B.selected=nil,nil
    finish((fromBank and "Withdrew " or "Deposited ")..current.name.." ×"..current.count)
    return true
end
local create=K.CreateWindow
function K:CreateWindow()
    if self.window then return self.window end
    local f=create(self); for _,b in ipairs(f.cells) do b:Hide() end; f.cells={}; f.input:Hide()
    B:StorageSkin(f,"panel"); B:StorageWatermark(f)
    B:StorageSkin(f.search,"slot")
    for _,text in ipairs({ f.search,f.heading,f.status,f.pageLabel,f.emptyTitle,f.searchHint }) do B:StorageText(text) end
    B:CreateStorageHeader(f,f.heading,true)
    f.control:Hide(); f.close:Hide()
    f.search:SetScript("OnEditFocusGained",function() f.searchHint:Hide() end)
    f.search:SetScript("OnEditFocusLost",function(b) f.searchHint:SetShown(b:GetText()=="") end)
    f.layoutChoice=H:Button(f,"",16,-91,126,function(control) B:ChooseStorageLayout(f,control) end)
    f.sortChoice=H:Button(f,"Sort A-Z",231,-91,92,function() self.alphaSort=not self.alphaSort; self.page=1; self:Render() end)
    B:CreateStorageColumns(f,function() self.quantitySort=false; self.page=1; self:Render() end,
        function() self.quantitySort=true; self.page=1; self:Render() end)
    f.categoryChoice=H:Button(f,"",218,-91,174,function()
        local entries={}
        for i,category in ipairs(filters) do
            entries[#entries+1]={name=B.categoryNames[category] or "Empty spaces",selected=i==(self.categoryIndex or 1),
                choose=function() self.categoryIndex=i; self.page=1; self:Render() end}
        end
        B:StorageMenu(f,f.categoryChoice,entries)
    end)
    f.transfer=H:Button(f,"Withdraw",492,-91,152,function() self:Transfer(self.selected,true) end)
    f.capacity=H:Label(f,"",0,0,290); B:StorageText(f.capacity)
    f.transfer:SetWidth(120)
    for _,button in ipairs({f.layoutChoice,f.sortChoice,f.categoryChoice,f.transfer,f.previous,f.next,f.close,f.toolSettings,f.control}) do B:StorageSkin(button,"button") end
    f.categoryButtons={}
    for i,category in ipairs(filters) do
        local button=H:Button(f,B.categoryNames[category] or "Empty spaces",16,0,132,function()
            self.categoryIndex=i; self.page=1; self:Render()
        end)
        B:StorageSkin(button,"button")
        f.categoryButtons[i]=button
    end
    f.grid={}; f.storageHeaders={}
    for i=1,42 do
        local b=CreateFrame("Button",nil,f,"BackdropTemplate"); B:StorageSkin(b,"slot"); b:RegisterForDrag("LeftButton")
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(34,34); b.icon:SetPoint("LEFT",2,0)
        b.count=FS.HUD:Label(b,"",34,-20,18); FS:ApplyFont(b.count,10)
        B:StorageText(b.count)
        local function pickup(c)
            if not self.open or InCombatLockdown() or not c.row or not FS:IsModuleEnabled(self.name) then return end
            local current=T:Call(C_Container.GetContainerItemInfo,c.row.bag,c.row.slot)
            if current and (FS.modules.Vendor:IsSecret(current.itemID) or FS.modules.Vendor:IsSecret(current.isLocked) or current.isLocked) then return end
            if c.row.empty and current or not c.row.empty and (not current or current.itemID~=c.row.id) then self:Refresh(); return end
            T:Call(C_Container.PickupContainerItem,c.row.bag,c.row.slot)
        end
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(c,mouse)
            if self.open and not InCombatLockdown() and mouse~="RightButton"
                and c.row and not c.row.empty and not CursorHasItem() then
                self.selected=c.row; self.transferStatus=nil; self:Render()
            else pickup(c) end
        end); b:SetScript("OnDragStart",pickup); b:SetScript("OnReceiveDrag",pickup)
        b:SetScript("OnEnter",function(c)
            if c.row and c.row.link then
                GameTooltip:SetOwner(c,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(c.row.link)
                GameTooltip:AddLine("Click to inspect. Drag or right-click to pick up.",.7,.85,1)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end); f.grid[i]=b
        local header=H:Button(f,"",0,0,628,function(control)
            local key=control.category
            if key and B:StorageLayout()=="Satchels" then
                self.collapsed=self.collapsed or {}; self.collapsed[key]=not self.collapsed[key]; self.page=1; self:Render()
            end
        end)
        header.fsLabel:SetJustifyH("LEFT")
        B:StorageSkin(header,"button")
        f.storageHeaders[i]=header
    end
    f:HookScript("OnHide",function()
        if f.storageMenu then f.storageMenu:Hide() end
        for _,button in ipairs(f.grid) do button.row=nil end
        if not self.switchingPane then self:CloseStorageSession() end
    end)
    function f:LayoutText() K:Render() end
    return f
end
function K:Render()
    local f=self.window; if not f or not f:IsShown() or InCombatLockdown() then return end
    local style=B:StorageLayout()
    local list=style=="Ledger"
    local sidebar=style=="Vault"
    local category=filters[self.categoryIndex or 1]
    local rows={}; local search=string.lower(f.search:GetText() or "")
    local selected
    for _,r in ipairs(self.rows or {}) do
        if (category=="All" or category=="Favorites" and FS.db.bags.favorites[r.id] or category==r.category)
            and string.find(string.lower(r.text.." "..(B.categoryNames[r.category] or "")),search,1,true) then
            rows[#rows+1]=r
            local saved=self.selected
            if saved and r.id==saved.id and r.bag==saved.bag and r.slot==saved.slot and r.link==saved.link
                and (not saved.guid or r.guid==saved.guid) then selected=r end
        end
    end
    self.selected=selected
    if style=="Satchels" then
        table.sort(rows,function(a,b) if a.bag~=b.bag then return a.bag<b.bag end; return a.slot<b.slot end)
    elseif list or self.alphaSort then
        table.sort(rows,function(a,b)
            if not a.empty~=not b.empty then return not a.empty end
            if self.quantitySort and list and (a.count or 0)~=(b.count or 0) then return (a.count or 0)>(b.count or 0) end
            return (a.name or a.text):lower()<(b.name or b.text):lower()
        end)
    end
    local _,fontSize=f.heading:GetFont(); fontSize=fontSize or 14
    local width=style=="Field Kit" and 560 or style=="Quartermaster" and 620 or 740
    local contentWidth=width-28
    local gridX=sidebar and 179 or 14
    local size=list and math.max(28,fontSize+9) or style=="Field Kit" and 34 or 38
    local headerHeight=math.max(26,fontSize+12)
    local spec={width=width-gridX-14,height=style=="Field Kit" and 182 or 246,size=size,headerHeight=headerHeight,maxCells=#f.grid,list=list}
    if style=="Satchels" then
        spec.group=function(row) return row.bag end
        spec.groupOrder=function(a,b) return a<b end
        spec.groupLabel=function(id) return B:StorageBagName(id,true) end
        spec.collapsed=search=="" and category=="All" and self.collapsed
        spec.lanes=2
        spec.cards=true
        if search=="" and category=="All" then spec.seed=self.bagUsage end
        spec.groupCount=function(id) return self.bagUsage and self.bagUsage[id] end
    elseif style=="Vault" then
        spec.group=function(row) return row.category end
        spec.groupLabel=function(name) return B.categoryNames[name] or name end
        spec.lanes=category=="All" and 2 or 1
        spec.wideGroup="Materials"
    end
    local layouts=B:StoragePages(rows,spec)
    local pages=#layouts; self.page=math.max(1,math.min(self.page or 1,pages))
    local layout=layouts[self.page]
    local function at(region,x,y) region:ClearAllPoints(); region:SetPoint("TOPLEFT",x,-y) end
    f:SetWidth(width)
    local top=B:LayoutStorageHeader(f,width,self:Data().account and "Account bank" or "Bank",true)
    f.summary:Hide(); f.input:Hide(); f.inputLabel:Hide(); f.emptyAction:Hide(); f.emptyText:Hide()
    f.searchHint:SetText("Search items..."); f.searchHint:SetShown(search=="" and not f.search:HasFocus())
    f.layoutChoice:SetText(style)
    B:StorageArrow(f.layoutChoice,"down","RIGHT")
    f.sortChoice:SetShown(not list and style~="Satchels")
    B:StorageHighlight(f.sortChoice,self.alphaSort)
    f.categoryChoice:SetText(B.categoryNames[category] or "Empty spaces"); f.categoryChoice:SetShown(not sidebar)
    B:StorageArrow(f.categoryChoice,not sidebar and "down" or nil,"RIGHT")
    local controls={}
    if not sidebar then controls[#controls+1]={f.categoryChoice,102} end
    if f.sortChoice:IsShown() then controls[#controls+1]={f.sortChoice,92} end
    controls[#controls+1]={f.layoutChoice,126}
    local y=B:LayoutStorageToolbar(f,width,top,controls)
    y=B:LayoutStorageColumns(f,list,gridX,y,spec.width,size,self.quantitySort)
    f.transfer:SetShown(style=="Quartermaster"); f.transfer:SetEnabled(selected and not selected.locked or false)
    local categoryHeight=0
    for i,button in ipairs(f.categoryButtons) do
        button:SetShown(sidebar)
        if sidebar then
            at(button,16,y+categoryHeight)
            B:StorageHighlight(button,filters[i]==category)
            categoryHeight=categoryHeight+H:FitButton(button,2)+4
        end
    end
    f.emptyTitle:SetText(self.open and (search~="" and "No matching items" or "No items to show") or "Visit a banker to see your bank")
    f.emptyTitle:SetShown(#rows==0 and #layout.headers==0); at(f.emptyTitle,gridX,y); H:TextHeight(f.emptyTitle,spec.width,2)
    B:DrawStorageSections(f,layout,gridX,y)
    for i,header in ipairs(f.storageHeaders) do
        local entry=layout.headers[i]
        header.category=entry and entry.category
        header:SetShown(entry~=nil)
        if entry then
            header:SetWidth(entry.width); header:SetHeight(headerHeight-4); header.fsLabel:SetWidth(entry.width-16)
            local satchel=style=="Satchels"
            header:SetEnabled(satchel and search=="" and category=="All")
            header:SetText(entry.text)
            B:StorageGroupHeader(header,satchel,entry.collapsed)
            at(header,gridX+entry.x,y+entry.y)
        end
    end
    for i,b in ipairs(f.grid) do
        local entry=layout.cells[i]
        local r=entry and entry.row; b.row=r; b:SetShown(r~=nil)
        B:StorageFavorite(b,r)
        if r then
            B:StorageCellGeometry(b,r,list,spec.width,size,true); at(b,gridX+entry.x,y+entry.y)
            b.icon:SetTexture(r.icon)
            b.count:SetText(r.count and (list or r.count>1) and tostring(r.count) or "")
            B:StorageHighlight(b,selected==r)
        end
    end
    local inspectY=y+math.max(spec.height,categoryHeight)+12
    local detail=selected and (selected.name.."  ×"..selected.count.."  ·  "..B:StorageBagName(selected.bag,true))
    f.status:SetText(self.transferStatus or detail or (self.open and "Select an item to see its details" or ""))
    local transferWidth=style=="Quartermaster" and 132 or 0
    at(f.transfer,width-134,inspectY)
    at(f.status,14,inspectY+5)
    local nav=inspectY+math.max(H:TextHeight(f.status,contentWidth-transferWidth,2)+10,H:FitButton(f.transfer,1))+8
    f.pageLabel:SetText("Page "..self.page.." / "..pages); at(f.pageLabel,137,nav+5)
    f.previous:SetShown(pages>1); f.next:SetShown(pages>1); f.pageLabel:SetShown(pages>1)
    f.previous:SetEnabled(self.page>1); f.next:SetEnabled(self.page<pages)
    at(f.previous,14,nav); at(f.next,width-124,nav)
    local footer=pages>1 and nav+math.max(H:FitButton(f.previous,1),H:FitButton(f.next,1))+8 or nav
    f.capacity:SetText(self.open and self.status or "")
    at(f.capacity,14,footer+8)
    local captionHeight=H:TextHeight(f.capacity,width-250,1)
    at(f.toolSettings,width-118,footer+4); f.toolSettings:SetWidth(104)
    local actionHeight=H:FitButton(f.toolSettings,1,25)
    if f.fsContextLauncher then B:PlaceBankTools(f) end
    f:SetHeight(footer+math.max(captionHeight+16,actionHeight+8))
    B:StorageBand(f,footer,inspectY-5)
    local saved=FS.db.layout.frames["Tool:Bank"]
    local combined=B.window and B.window:IsShown() and B:StorageWidth()+width+12 or width
    f:SetScale(math.min(saved and saved.scale or 1,(UIParent:GetWidth()-32)/combined,(UIParent:GetHeight()-32)/f:GetHeight()))
    if f.fsContextHost and FS.Context then FS.Context:Position(f) end
end

function B:PlaceBankTools(f)
    local button=f.fsContextLauncher
    if not button then return end
    button:SetText("Bank tools"); button:SetWidth(104); H:FitButton(button,1,25)
    button:ClearAllPoints(); button:SetPoint("RIGHT",f.toolSettings,"LEFT",-8,0)
    if not button.fsStorageControl then B:StorageSkin(button,"button"); button.fsStorageControl=true end
end
local settings=K.SettingsChanged
function K:SettingsChanged() settings(self); self:Native(self.open and self:Data().replace and FS:IsModuleEnabled(self.name)); if self.window and self.window:IsShown() then self:Refresh() end end
