local _,FS=...
local T=FS.Tools
local K=T:Module("Bank","bank","Bank","Search and group your bank items. Left-click or drag an item to move it between bank and bags while visiting a banker.",{replace=true,account=false,showEmpty=true},{"BANKFRAME_OPENED","BANKFRAME_CLOSED","BANK_TABS_CHANGED","BAG_UPDATE_DELAYED","PLAYER_REGEN_ENABLED"})
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
    local free,capacity=0,0; local V=FS.modules.Vendor
    for _,bag in ipairs(self:BagIDs()) do
        local size=T:Call(C_Container.GetContainerNumSlots,bag) or 0; capacity=capacity+size
        for slot=1,size do
            local item=V:ReadItem(bag,slot)
            if item then
                item.category=FS.modules.Bags:Category(item); if item.quality==0 and item.category=="Other" then item.category="Junk" end
                item.text=item.category.." | "..item.name.." x"..item.count; self.rows[#self.rows+1]=item
            else
                local raw=T:Call(C_Container.GetContainerItemInfo,bag,slot)
                if not raw then free=free+1; if self:Data().showEmpty then self.rows[#self.rows+1]={bag=bag,slot=slot,empty=true,category="Empty",text="Empty space"} end end
            end
        end
    end
    local order={}; for i,name in ipairs(FS.modules.Bags.categories) do order[name]=i end; order.Empty=999
    table.sort(self.rows,function(a,b) if a.category~=b.category then return (order[a.category] or 998)<(order[b.category] or 998) end; return a.text<b.text end)
    self.status=(self:Data().account and "Account bank" or "Character bank").." | "..free.." / "..capacity.." free spaces. Click or drag to move items."
end
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
    elseif event=="BANKFRAME_CLOSED" then self.open=false; self:Native(false); if self.window then self.window:Hide() end
    elseif event=="PLAYER_REGEN_ENABLED" and self.open and self:Data().replace then self:Native(true); self:ShowWindow() end
end
local show=K.ShowWindow
function K:ShowWindow()
    if self.open and not InCombatLockdown() and FS:IsModuleEnabled(self.name) then
        local f=self:CreateWindow(); FS.modules.Bags:ShowWindow()
        if FS.modules.Bags.window and FS.modules.Bags.window:IsShown() then f:ClearAllPoints(); f:SetPoint("RIGHT",FS.modules.Bags.window,"LEFT",-12,0) end
    end
    show(self)
end
local create=K.CreateWindow
function K:CreateWindow()
    if self.window then return self.window end
    local f=create(self); for _,b in ipairs(f.cells) do b:Hide() end; f.cells={}; f.input:Hide()
    f.grid={}
    for i=1,42 do
        local b=CreateFrame("Button",nil,f,"BackdropTemplate"); FS.HUD:Skin(b); b:SetSize(54,38); b:SetPoint("TOPLEFT",16+(i-1)%7*90,-140-math.floor((i-1)/7)*48); b:RegisterForDrag("LeftButton")
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(34,34); b.icon:SetPoint("LEFT",2,0)
        b.count=FS.HUD:Label(b,"",34,-20,18); FS:ApplyFont(b.count,10)
        b.category=FS.HUD:Label(b,"",0,10,85); FS:ApplyFont(b.category,9)
        local function pickup(c)
            if not self.open or InCombatLockdown() or not c.row or not FS:IsModuleEnabled(self.name) then return end
            local current=T:Call(C_Container.GetContainerItemInfo,c.row.bag,c.row.slot)
            if current and (FS.modules.Vendor:IsSecret(current.itemID) or FS.modules.Vendor:IsSecret(current.isLocked) or current.isLocked) then return end
            if c.row.empty and current or not c.row.empty and (not current or current.itemID~=c.row.id) then self:Refresh(); return end
            T:Call(C_Container.PickupContainerItem,c.row.bag,c.row.slot)
        end
        b:SetScript("OnClick",pickup); b:SetScript("OnDragStart",pickup); b:SetScript("OnReceiveDrag",pickup)
        b:SetScript("OnEnter",function(c) if c.row and c.row.link then GameTooltip:SetOwner(c,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(c.row.link); GameTooltip:Show() end end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end); f.grid[i]=b
    end
    f:HookScript("OnHide",function()
        self.rows={}
        for _,button in ipairs(f.grid) do button.row=nil end
        self:Native(false)
        if self.open then self.open=false; T:Call(CloseBankFrame) end
    end)
    return f
end
function K:Render()
    local f=self.window; if not f or not f:IsShown() then return end
    local rows={}; local search=string.lower(f.search:GetText() or "")
    for _,r in ipairs(self.rows) do if string.find(string.lower(r.text),search,1,true) then rows[#rows+1]=r end end
    local pages=math.max(1,math.ceil(#rows/42)); self.page=math.max(1,math.min(self.page or 1,pages))
    local last
    for i,b in ipairs(f.grid) do
        b.row=rows[(self.page-1)*42+i]; local r=b.row; b:SetShown(r~=nil)
        if r then b.icon:SetTexture(r.empty and "Interface\\PaperDoll\\UI-Backpack-EmptySlot" or r.icon); b.count:SetText(r.count and r.count>1 and tostring(r.count) or ""); b.category:SetText(r.category~=last and r.category or ""); last=r.category end
    end
    f.status:SetText(self.status); f.pageLabel:SetText("Page "..self.page.." / "..pages)
end
local settings=K.SettingsChanged
function K:SettingsChanged() settings(self); self:Native(self.open and self:Data().replace and FS:IsModuleEnabled(self.name)); if self.window and self.window:IsShown() then self:Refresh() end end
