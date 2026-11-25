local _,FS=...
local F,T,H=FS.modules.LootFeed,FS.Tools,FS.HUD
local icons={item=134400,currency=133784,reputation="Reputation",skill="Skills",money=133784}
function F:CreateFeed()
    if self.feed then return self.feed end
    local root=CreateFrame("Frame","ForeverSuiteLootFeed",UIParent); self.feed=root
    root.fsSuiteStyle=true; root.fsFontModule=self.name; root:SetFrameStrata("MEDIUM"); root:SetClampedToScreen(true)
    root:SetPoint("CENTER",UIParent,"CENTER",320,-40); root:SetSize(self:Data().width,280); root:EnableMouse(false); root:SetMovable(true)
    function root:fsFitScale(scale)
        return math.min(scale,math.max(1,UIParent:GetWidth()-32)/self:GetWidth(),math.max(1,UIParent:GetHeight()-32)/self:GetHeight())
    end
    local header=CreateFrame("Frame",nil,root,"BackdropTemplate"); root.header=header; H:Skin(header,true)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(28); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function()
        if not InCombatLockdown() then self.dragging=true; root.fsDirectDragging=true; root:StartMoving() end
    end)
    header:SetScript("OnDragStop",function()
        root:StopMovingOrSizing(); self.dragging=nil; root.fsDirectDragging=nil
        for _,entry in ipairs(self.entries) do entry.expires=GetTime()+self:Data().duration end
        local saved=FS.Layout:Placements().LootFeed
        FS.Layout:Save("LootFeed",root,saved and saved.scale or 1)
    end)
    header.logo=header:CreateTexture(nil,"ARTWORK"); header.logo:SetTexture(FS.emblem); header.logo:SetSize(22,22); header.logo:SetPoint("LEFT",5,0)
    header.title=H:Label(header,"LOOT FEED",34,-7,180); FS:ApplyFont(header.title,11)
    header.settings=H:Button(header,"Settings",0,0,70,function() if not InCombatLockdown() then FS.Beginner:ShowModule("LootFeed") end end)
    header.settings:ClearAllPoints(); header.settings:SetPoint("RIGHT",-3,0); header.settings:SetHeight(22); FS:ApplyFont(header.settings.fsLabel,10)
    header.history=H:Button(header,"History",0,0,62,function() self:ShowWindow() end)
    header.history:ClearAllPoints(); header.history:SetPoint("RIGHT",header.settings,"LEFT",-4,0); header.history:SetHeight(22); FS:ApplyFont(header.history.fsLabel,10)
    H:SetHelp(header,"Drag to move. /fs lootfeed previews the feed. /fs lootfeed settings opens its options.")
    root:SetScript("OnHide",function()
        root:SetScript("OnUpdate",nil); root:StopMovingOrSizing()
        self.dragging=nil; root.fsDirectDragging=nil
        if self.hovered then GameTooltip:Hide(); self.hovered=nil end
    end)
    root:SetScript("OnShow",function()
        if #self.entries>0 then root:SetScript("OnUpdate",function(_,dt) self:Animate(dt) end) end
    end)
    root:Hide(); self.pool={}
    FS.Layout:Register("LootFeed",root,"Loot Feed")
    if not self.themeHook then
        self.themeHook=true
        hooksecurefunc(FS.Themes,"Refresh",function()
            if self.feed and self:Ready() and not InCombatLockdown() then self:LayoutFeed(); for _,entry in ipairs(self.entries) do self:Paint(entry) end end
        end)
        hooksecurefunc(FS.Typography,"Apply",function() if self.feed and FS.db and not InCombatLockdown() then self:LayoutFeed() end end)
    end
    self:LayoutFeed(); return root
end
function F:CreateRow()
    local row=CreateFrame("Button",nil,self.feed,"BackdropTemplate"); row.fsSuiteStyle=true; row.fsFontModule=self.name
    H:Skin(row,true); row:RegisterForClicks("LeftButtonUp","RightButtonUp")
    row.rail=row:CreateTexture(nil,"ARTWORK"); row.rail:SetWidth(2); row.rail:SetPoint("TOPLEFT",1,-3); row.rail:SetPoint("BOTTOMLEFT",1,3)
    row.iconButton=CreateFrame("Button",nil,row); row.iconButton:SetSize(32,32); row.iconButton:SetPoint("LEFT",8,0); row.iconButton:EnableMouse(false)
    row.icon=row.iconButton:CreateTexture(nil,"ARTWORK"); row.icon:SetAllPoints(); row.icon:SetTexCoord(.08,.92,.08,.92)
    row.iconBorder=row.iconButton:CreateTexture(nil,"OVERLAY"); row.iconBorder:SetAllPoints(); row.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame"); row.iconBorder:SetAlpha(.5)
    row.name=H:Label(row,"",48,-7,180); if row.name.SetMaxLines then row.name:SetMaxLines(1) end; row.name:SetWordWrap(false)
    row.amount=H:Label(row,"",0,0,90); row.amount:ClearAllPoints(); row.amount:SetPoint("TOPRIGHT",-9,-7); row.amount:SetJustifyH("RIGHT")
    row.amount:SetWordWrap(false); if row.amount.SetMaxLines then row.amount:SetMaxLines(1) end
    row.detail=H:Label(row,"",48,-26,270); if row.detail.SetMaxLines then row.detail:SetMaxLines(1) end; row.detail:SetWordWrap(false)
    row.track=row:CreateTexture(nil,"BORDER"); row.track:SetColorTexture(.3,.35,.4,.2); row.track:SetPoint("BOTTOMLEFT",48,3); row.track:SetPoint("BOTTOMRIGHT",-9,3); row.track:SetHeight(2)
    row.progress=row:CreateTexture(nil,"ARTWORK"); row.progress:SetPoint("BOTTOMLEFT",48,3); row.progress:SetHeight(2)
    row:SetScript("OnEnter",function(b)
        if not b.entry then return end
        b.hovered=GetTime(); self.hovered=b; self:Tooltip(b)
    end)
    row:SetScript("OnLeave",function(b)
        if b.entry and b.hovered then b.entry.expires=b.entry.expires+math.max(0,GetTime()-b.hovered) end
        b.hovered=nil; if self.hovered==b then self.hovered=nil; GameTooltip:Hide() end
    end)
    row:SetScript("OnClick",function(b,mouse)
        if not b.entry then return end
        if mouse=="RightButton" then self:Dismiss(b.entry)
        elseif b.entry.link then
            if not T:Call(HandleModifiedItemClick,b.entry.link) then T:Call(SetItemRef,b.entry.link:match("|H(.-)|h") or b.entry.link,b.entry.link,mouse,b) end
        end
    end)
    row:SetScript("OnHide",function(b)
        if self.hovered==b then self.hovered=nil; GameTooltip:Hide() end
        b.hovered=nil
    end)
    self.pool[#self.pool+1]=row; return row
end
function F:LayoutFeed()
    if not self.feed then return end
    local data=self:Data(); local header=self.feed.header
    local function buttonWidth(button)
        local text=button.fsLabel; local _,size=text:GetFont()
        local measured=T:Call(text.GetUnboundedStringWidth,text)
        return math.max(62,(T:Number(measured) and measured or #text:GetText()*(size or 12)*.65)+16)
    end
    header.settings:SetWidth(buttonWidth(header.settings)); header.history:SetWidth(buttonWidth(header.history))
    local headerHeight=math.max(H:FitButton(header.settings,1,22),H:FitButton(header.history,1,22))+6
    header:SetHeight(headerHeight); self.headerHeight=headerHeight+4
    local width=math.max(data.width,header.settings:GetWidth()+header.history:GetWidth()+148)
    self.feed:SetWidth(width)
    header.title:SetWidth(width-header.settings:GetWidth()-header.history:GetWidth()-50)
    header.title:SetWordWrap(false); if header.title.SetMaxLines then header.title:SetMaxLines(1) end
    for _,row in ipairs(self.pool) do
        FS:ApplyFont(row.name,data.textSize); FS:ApplyFont(row.amount,data.textSize); FS:ApplyFont(row.detail,math.max(10,data.textSize-2))
        local _,nameSize=row.name:GetFont(); local _,detailSize=row.detail:GetFont()
        row.name:SetHeight((nameSize or data.textSize)+3); row.amount:SetHeight((nameSize or data.textSize)+3); row.detail:SetHeight((detailSize or data.textSize-2)+3)
        self.rowHeight=math.max(48,(nameSize or data.textSize)+(detailSize or data.textSize-2)+20)
        row:SetSize(width,self.rowHeight); row.name:SetWidth(width-165); row.detail:SetWidth(width-60)
        row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT",48,-(nameSize or data.textSize)-12)
        row:EnableMouse(data.interactive)
    end
    self.rowHeight=self.rowHeight or 48
    self.feed:SetHeight(self.headerHeight+data.visible*(self.rowHeight+4))
    local saved=FS.Layout:Placements().LootFeed
    self.feed:SetScale(self.feed:fsFitScale(saved and saved.scale or 1))
    -- Direction changes affect the rows, not the saved mover position.
    self.feed.header:ClearAllPoints(); self.feed.header:SetPoint(data.growth=="Up" and "BOTTOMLEFT" or "TOPLEFT")
    self.feed.header:SetPoint(data.growth=="Up" and "BOTTOMRIGHT" or "TOPRIGHT")
    for i,entry in ipairs(self.entries) do if entry.row then
        local row=entry.row; row.target=(i-1)*(self.rowHeight+4)+self.headerHeight
        if not row.y then row.y=row.target-10 end
        local up=data.growth=="Up"; row:ClearAllPoints()
        row:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT",self.feed,up and "BOTTOMLEFT" or "TOPLEFT",0,up and row.y or -row.y)
    end end
end
function F:Paint(entry)
    local row=entry.row; if not row then return end
    local r,g,b=FS.Themes:Accent()
    if entry.kind=="item" and entry.quality then
        local qr,qg,qb=T:Call(GetItemQualityColor,entry.quality)
        if T:Number(qr) and T:Number(qg) and T:Number(qb) then r,g,b=qr,qg,qb end
    end
    row.rail:SetColorTexture(r,g,b,.95); row.iconBorder:SetVertexColor(r,g,b); row.progress:SetColorTexture(r,g,b,.8)
    local factor=FS.Themes:Current()==10 and .23 or 1
    row.name:SetText(entry.name); row.name:SetTextColor(r*factor,g*factor,b*factor)
    row.amount:SetText(self:Amount(entry)); row.amount:SetTextColor(.96*factor,.9*factor,.72*factor)
    row.detail:SetText(entry.detail); row.detail:SetTextColor(.72*factor,.8*factor,.85*factor)
    FS:ClearMenuIcon(row.icon); row.icon:SetTexCoord(.08,.92,.08,.92)
    local icon=entry.icon or icons[entry.kind]
    if type(icon)=="string" and not icon:find("\\",1,true) then FS:SetMenuIcon(row.icon,icon)
    else row.icon:SetTexture(icon or icons.item) end
    local progress=entry.progress and entry.maximum and entry.maximum>0
    row.track:SetShown(progress and true or false); row.progress:SetShown(progress and true or false)
    if progress then row.progress:SetWidth(math.max(1,(self.feed:GetWidth()-60)*math.min(1,math.max(0,entry.progress/entry.maximum)))) end
    if row.masque and entry.kind=="item" then T:Call(self.masqueGroup and self.masqueGroup.ReSkin,self.masqueGroup) end
end
function F:SkinIcons()
    local group=self.masqueGroup
    if not group and self:Data().masque and LibStub then
        local ok,library=pcall(function() return LibStub("Masque",true) end)
        if ok and library and type(library.Group)=="function" then
            group=T:Call(library.Group,library,"ForeverSuite","Loot Feed"); self.masqueGroup=group
        end
    end
    if not group then return end
    for _,row in ipairs(self.pool or {}) do
        local use=self:Data().masque and row.entry and row.entry.kind=="item"
        if use and not row.masque then
            local ok=pcall(group.AddButton,group,row.iconButton,{Icon=row.icon,Border=row.iconBorder},"Item",true)
            row.masque=ok
        elseif not use and row.masque then
            T:Call(group.RemoveButton,group,row.iconButton); row.masque=nil; row.icon:SetTexCoord(.08,.92,.08,.92)
            if row.entry then self:Paint(row.entry) end
        end
    end
end
function F:FindMerge(entry)
    if not self:Data().merge then return end
    for _,list in ipairs({self.entries,self.queue}) do for _,old in ipairs(list) do
        if old.key==entry.key and GetTime()-old.received<=2 and not old.preview then return old end
    end end
end
function F:HasRoom(entry)
    return self:FindMerge(entry)~=nil or #self.entries<self:Data().visible or #self.queue<self.limits.queue
end
function F:Receive(entry)
    if not self:Ready() then return false end
    local eligible=self:Eligible(entry)
    if eligible==nil then
        entry.received=GetTime(); if #self.pending>=self.limits.pending then table.remove(self.pending,1) end
        self.pending[#self.pending+1]=entry; T:Call(C_Item and C_Item.RequestLoadItemDataByID,entry.id); return false
    end
    if not eligible or not self:HasRoom(entry) then return false end
    if self.previewing then self:Clear(); self.previewing=nil end
    local now=GetTime(); local previous=self:FindMerge(entry)
    if previous then
        previous.quantity=math.min(100000000,previous.quantity+entry.quantity)
        if entry.rank then previous.rank=math.max(previous.rank,entry.rank) end
        previous.received=now
        if previous.expires then previous.expires=now+self:Data().duration end
        self:Context(previous); self:Paint(previous); return true
    end
    entry.received=now; self:Context(entry,true)
    table.insert(self.history,1,entry); while #self.history>self.limits.history do table.remove(self.history) end
    self.queue[#self.queue+1]=entry; self:Promote(); return true
end
function F:Promote()
    if not self:Ready() then self:Clear(); return end
    local root=self:CreateFeed(); local changed=false
    while #self.entries<self:Data().visible and #self.queue>0 do
        local entry=table.remove(self.queue,1); local row
        for _,candidate in ipairs(self.pool) do if not candidate.entry then row=candidate; break end end
        if not row then row=self:CreateRow(); self:LayoutFeed(); self:SkinIcons() end
        entry.row=row; row.entry=entry; row.y=nil; row.hovered=nil
        if not entry.preview then self:Context(entry) end
        entry.started=GetTime(); entry.expires=GetTime()+self:Data().duration
        table.insert(self.entries,1,entry); row:Show(); self:Paint(entry); changed=true
    end
    if changed then self:LayoutFeed() end
    self:SkinIcons()
    if #self.entries>0 then
        root.header.title:SetText(self.previewing and "PREVIEW" or "LOOT FEED")
        root:Show(); root:SetScript("OnUpdate",function(_,dt) self:Animate(dt) end)
    else root:SetScript("OnUpdate",nil); root:Hide() end
end
function F:Dismiss(entry)
    for i=#self.entries,1,-1 do if self.entries[i]==entry then
        self:ReleaseRow(entry); table.remove(self.entries,i); break
    end end
    self:Promote(); self:LayoutFeed()
end
function F:ReleaseRow(entry)
    local row=entry.row; entry.row=nil
    if row then row.entry=nil; row:Hide() end
end
function F:Animate(dt)
    if not self:Ready() then self:Clear(); return end
    self.elapsed=(self.elapsed or 0)+dt; if self.elapsed<.03 then return end
    local step=self.elapsed; self.elapsed=0; local now=GetTime(); local changed=false
    for i=#self.entries,1,-1 do
        local entry=self.entries[i]; local row=entry.row
        local paused=row.hovered or self.dragging or FS.Layout.active
        if not paused and now>=entry.expires+.4 then
            self:ReleaseRow(entry); table.remove(self.entries,i); changed=true
        else
            local alpha=math.min(1,math.max(0,(now-entry.started)/.18))
            if not paused then alpha=math.min(alpha,math.max(0,(entry.expires+.4-now)/.4)) end
            row:SetAlpha(alpha)
            local target=row.target or self.headerHeight or 32
            row.y=row.y or target-10; row.y=row.y+(target-row.y)*math.min(1,step*18)
            row:ClearAllPoints()
            local up=self:Data().growth=="Up"
            row:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT",self.feed,up and "BOTTOMLEFT" or "TOPLEFT",0,up and row.y or -row.y)
        end
    end
    if changed then self:Promote(); self:LayoutFeed() end
end
function F:Preview()
    if not self:Ready() then FS:Print("Enable Loot Feed and leave combat if its combat display is disabled."); return end
    if #self.entries>0 then return end
    self.previewing=true
    self.queue={
        {kind="item",key="preview:item",name="Linen Cloth",quantity=6,icon=132889,detail="Sample  |  Owned 24  |  Vendor 78c",preview=true},
        {kind="money",key="preview:money",name="Money looted",quantity=1250,icon=133784,detail="Sample money gain",preview=true},
        {kind="currency",key="preview:currency",name="Currency",quantity=5,detail="Sample  |  75 / 100",progress=75,maximum=100,preview=true},
        {kind="reputation",key="preview:reputation",name="Orgrimmar",quantity=75,detail="Sample  |  Friendly  |  1200 / 6000",progress=1200,maximum=6000,preview=true},
        {kind="skill",key="preview:skill",name="Leatherworking",rank=54,quantity=1,detail="Sample  |  54 / 75",progress=54,maximum=75,preview=true},
    }
    self:Promote()
end
