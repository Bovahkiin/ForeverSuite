local _,FS=...
local C,H=FS.modules.Character,FS.HUD
local function label(parent,text,x,y,width) return H:Label(parent,text,x,y,width) end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); f.fsCharacterSkin=true; H:Skin(f); f:SetBackdropColor(.025,.035,.05,1); f:SetSize(w,h); f:SetPoint("TOPLEFT",x,y); return f
end
function C:NativeMouse(frame,hidden)
    if not frame or frame.fsCharacterSkin or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame.EnableMouse and frame.IsMouseEnabled then
        self.nativeMouse=self.nativeMouse or {}
        local state=self.nativeMouse[frame]
        if not state then
            state={enabled=frame:IsMouseEnabled()}; self.nativeMouse[frame]=state
            hooksecurefunc(frame,"EnableMouse",function(f)
                if state.hidden and not state.setting then state.setting=true; f:EnableMouse(false); state.setting=false end
            end)
        end
        state.hidden=hidden
        if hidden then frame:EnableMouse(false) else frame:EnableMouse(state.enabled) end
    end
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do self:NativeMouse(child,hidden) end end
end
function C:HideNativeFrame(f,hidden)
    if not f then return end
    self.hiddenFrames=self.hiddenFrames or {}
    local state=self.hiddenFrames[f]
    if not state then
        state={alpha=f:GetAlpha()}; self.hiddenFrames[f]=state
        hooksecurefunc(f,"SetAlpha",function(frame)
            if state.hidden and not state.setting then state.setting=true; frame:SetAlpha(0); state.setting=false end
        end)
    end
    state.hidden=hidden; f:SetAlpha(hidden and 0 or state.alpha)
    self:NativeMouse(f,hidden)
end
function C:IconButton(parent,text,icon,x,y,width,callback)
    local b=H:Button(parent,text,x,y,width,callback); b:SetHeight(48)
    b.image=b:CreateTexture(nil,"ARTWORK"); b.image:SetSize(22,22); b.image:SetPoint("TOP",0,-3); FS:SetMenuIcon(b.image,icon)
    if b.GetFontString then local old=b:GetFontString(); if old then old:Hide() end end
    local caption=FS.Widgets:Label(b,"ForeverSuiteFontSmall"); caption:SetPoint("BOTTOM",0,3); caption:SetText(text); caption:SetWidth(width-4); caption:SetHeight(16); b:SetFontString(caption); b.fsLabel=caption
    FS:ClickEffect(b); return b
end
function C:LayoutText()
    if not self.root or InCombatLockdown() or not FS:IsModuleEnabled(self.name) then return end
    local _,size=self.sideTabs[1].fsLabel:GetFont(); size=size or 14
    local large=size>14
    local sideWidth=large and math.max(308,size*13+20) or 308
    local width=456+sideWidth+16
    self.side:SetWidth(sideWidth); self.root:SetWidth(width); CharacterFrame:SetWidth(width)
    self.root.close:ClearAllPoints(); self.root.close:SetPoint("TOPRIGHT",-14,-12)
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
    local tabCount=self:HasActivePet() and 4 or 3
    local tabWidth=math.floor((sideWidth-8)/tabCount)-4; local tabsHeight=48
    for i,b in ipairs(self.sideTabs) do
        b:SetShown(i<=tabCount); b:SetWidth(tabWidth); at(b,6+(i-1)*(tabWidth+4),6)
        local h=H:TextHeight(b.fsLabel,tabWidth-4,2); b:SetHeight(math.max(48,28+h)); tabsHeight=math.max(tabsHeight,b:GetHeight())
    end
    self.sideHeading:SetWidth(sideWidth-24); at(self.sideHeading,12,tabsHeight+16)
    local headingHeight=H:TextHeight(self.sideHeading,sideWidth-24,2)
    self.listTop=math.max(94,tabsHeight+16+headingHeight+12)
    local rowHeight=large and size+16 or 28
    self.rowsPerPage=math.max(1,math.min(9,math.floor(((large and 340 or 346)-self.listTop)/rowHeight)))
    for i,b in ipairs(self.rows) do b:SetWidth(sideWidth-24); at(b,12,self.listTop+(i-1)*rowHeight); H:TextHeight(b.fsLabel,sideWidth-36,1); b:SetHeight(large and rowHeight-3 or 25) end
    local titleHeight=H:TextHeight(self.root.title,width-90,1)
    at(self.root.level,20,math.max(43,16+titleHeight+8)); local levelHeight=H:TextHeight(self.root.level,width-90,1)
    local bodyTop=math.max(72,math.max(43,16+titleHeight+8)+levelHeight+12)
    at(self.character,16,bodyTop); at(self.side,456,bodyTop); at(self.content,16,bodyTop)
    local offset=bodyTop-72; at(self.footer,16,516+offset)
    local footerWidth=width-32; self.footer:SetWidth(footerWidth); self.content:SetWidth(footerWidth)
    local bottomWidth=math.floor((footerWidth-8)/6); local footerHeight=52
    for i,b in ipairs(self.tabs) do
        b:SetWidth(bottomWidth-4); at(b,4+(i-1)*bottomWidth,2)
        local h=H:TextHeight(b.fsLabel,bottomWidth-8,2); b:SetHeight(math.max(48,28+h)); footerHeight=math.max(footerHeight,b:GetHeight()+4)
    end
    self.footer:SetHeight(footerHeight); self.root:SetHeight(528+footerHeight+offset); CharacterFrame:SetHeight(528+footerHeight+offset)
end
function C:CreateNavigation()
    if self.root then return end
    self.originalSize={CharacterFrame:GetWidth(),CharacterFrame:GetHeight()}
    local f=panel(CharacterFrame,0,0,780,580); self.root=f; f:SetFrameLevel(CharacterFrame:GetFrameLevel()+100)
    f.title=label(f,"",20,-16,690); FS:ApplyFont(f.title,18)
    f.level=label(f,"",20,-43,690)
    f.close=H:Button(f,"X",736,-12,30,function() if HideUIPanel then HideUIPanel(CharacterFrame) else CharacterFrame:Hide() end end)
    self.drag=CreateFrame("Frame",nil,f); self.drag:SetPoint("TOPLEFT",14,-4); self.drag:SetSize(710,52); self.drag:EnableMouse(true); self.drag:RegisterForDrag("LeftButton")
    self.drag:SetScript("OnDragStart",function() if not InCombatLockdown() then CharacterFrame:SetMovable(true); CharacterFrame:StartMoving() end end)
    self.drag:SetScript("OnDragStop",function() CharacterFrame:StopMovingOrSizing(); if not InCombatLockdown() then FS.Layout:Save("CharacterInfo",CharacterFrame) end end)
    self.character=panel(f,16,-72,430,432)
    self.model=CreateFrame("PlayerModel",nil,self.character); self.model:SetSize(306,328); self.model:SetPoint("TOPLEFT",62,-5); self.model:SetUnit("player"); self.model:EnableMouse(false)
    self.slots={}
    local left={1,2,3,15,5,4,19,9}; local right={10,6,7,8,11,12,13,14}
    for col,ids in ipairs({left,right,{16,17,18,0}}) do
        for i,slot in ipairs(ids) do
            local b=CreateFrame("Button",nil,self.character,"SecureActionButtonTemplate,BackdropTemplate"); H:Skin(b)
            b:SetSize(42,42); b:SetPoint("TOPLEFT",col==3 and (104+(i-1)*50) or (col==1 and 8 or 380),col==3 and -382 or (-8-(i-1)*46))
            b.slot=slot; b:EnableMouse(true); b:RegisterForClicks("AnyUp"); b:RegisterForDrag("LeftButton")
            b:SetAttribute("useOnKeyDown",false); b:SetAttribute("type2","item"); b:SetAttribute("item2",tostring(slot)); b:SetAttribute("target-slot",slot)
            b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",3,-3); b.icon:SetPoint("BOTTOMRIGHT",-3,3)
            b.empty=label(b,"",3,-14,36); b.empty:SetJustifyH("CENTER"); FS:ApplyFont(b.empty,10)
            b.count=FS.Widgets:Label(b,"ForeverSuiteFontSmall"); b.count:SetPoint("BOTTOMRIGHT",-3,3)
            b:HookScript("PreClick",function() b.wasTargeting=SpellIsTargeting and SpellIsTargeting() end)
            b.cooldown=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate"); b.cooldown:SetAllPoints(); b.cooldown:EnableMouse(false)
            local function pickup()
                if InCombatLockdown() then FS:Print("Leave combat to move equipment."); return end
                if PickupInventoryItem then PickupInventoryItem(slot) end
            end
            b:HookScript("OnClick",function(_,button)
                if button=="LeftButton" then
                    if b.wasTargeting then return end
                    local link=GetInventoryItemLink("player",slot)
                    if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
                    pickup()
                end
            end)
            b:SetScript("OnDragStart",pickup); b:SetScript("OnReceiveDrag",pickup)
            b:SetScript("OnEnter",function()
                GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
                if GetInventoryItemLink("player",slot) and GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player",slot) else GameTooltip:AddLine(self.slotLabels[slot] or "Equipment") end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end); self.slots[slot]=b
        end
    end
    H:Button(self.character,"Rotate left",78,-342,128,function() self:RotateModel(-.35) end)
    H:Button(self.character,"Rotate right",220,-342,128,function() self:RotateModel(.35) end)
    self.side=panel(f,456,-72,308,432); self.sideTabs={}
    for i,entry in ipairs({{"Stats","Statistics"},{"Gear sets","Equipment"},{"Titles","Reputation"},{"Pet","Friendly"}}) do
        self.sideTabs[i]=self:IconButton(self.side,entry[1],entry[2],6+(i-1)*100,-6,96,function() if InCombatLockdown() then FS:Print("Leave combat to change Character panels."); return end; self.sideMode=i; self.listPage=1; self.confirmAction=nil; self:RefreshCharacter() end)
    end
    self.sideTabs[4].image:SetTexture('Interface\\Icons\\Ability_Hunter_BeastTaming'); self.sideTabs[4].image:SetTexCoord(0,1,0,1)
    self.sideHeading=label(self.side,"",12,-64,282)
    self.rows={}
    for i=1,9 do
        local b=H:Button(self.side,"",12,-94-(i-1)*28,282,function() end); b:SetHeight(25); self.rows[i]=b
    end
    self.prev=H:Button(self.side,"<",12,-352,36,function() self.listPage=math.max(1,(self.listPage or 1)-1); self:RefreshCharacter() end)
    self.next=H:Button(self.side,">",56,-352,36,function() self.listPage=(self.listPage or 1)+1; self:RefreshCharacter() end)
    self.pageLabel=label(self.side,"",106,-360,182)
    self.setName=CreateFrame("EditBox",nil,self.side,"BackdropTemplate"); H:Skin(self.setName); self.setName:SetSize(176,26); self.setName:SetPoint("TOPLEFT",12,-391); self.setName:SetAutoFocus(false); self.setName:SetFont(FS.font,12,"")
    self.createSet=H:Button(self.side,"Save new set",195,-391,100,function() self:CreateSet() end); self.createSet:SetHeight(26)
    self.equip=CreateFrame("Button",nil,self.side,"SecureActionButtonTemplate,BackdropTemplate"); H:Skin(self.equip); self.equip:SetSize(94,26); self.equip:SetPoint("TOPLEFT",108,-352); self.equip:RegisterForClicks("AnyUp"); self.equip:SetAttribute("useOnKeyDown",false); self.equip:SetAttribute("type","equipmentset")
    local caption=FS.Widgets:Label(self.equip); caption:SetPoint("CENTER"); caption:SetText("Equip set")
    self.delete=H:Button(self.side,"Delete set",208,-352,86,function() self:DeleteSet() end); self.delete:SetHeight(26)
    self.content=panel(f,16,-72,748,432); self.content:SetClipsChildren(true); self.content:Hide()
    self.footer=panel(f,16,-516,748,52); self.tabs={}
    for i,page in ipairs(self.pages) do self.tabs[i]=self:IconButton(self.footer,page.name=="Player vs. Player" and "PvP" or page.name,page.icon,4+(i-1)*124,-2,120,function() self:SelectPage(i) end) end
    self.sideMode=1; self.listPage=1
end
function C:SelectPage(index)
    if InCombatLockdown() then FS:Print("Leave combat to change Character pages."); return end
    self.page=index
    -- Native Camelot tabs dispatch through OnMouseUp, not Button:Click.
    -- Use the same public page entry point directly from our own hardware click.
    if ToggleCharacter then ToggleCharacter(self.pages[index].frame,true)
    elseif CharacterFrame.ShowSubFrame then CharacterFrame:ShowSubFrame(self.pages[index].frame) else CharacterFrame.activeSubframe=self.pages[index].frame end
    self:Apply()
end
function C:RefreshTabs()
    if not self.root then return end
    for i,b in ipairs(self.tabs) do
        local selected=(self.page or 1)==i
        b:SetBackdropBorderColor(selected and .95 or .12,selected and .68 or .72,selected and .24 or .86,1)
        b:SetEnabled(_G[self.pages[i].frame]~=nil)
    end
end
function C:RestoreMounted()
    if not self.mounted then return end
    local s=self.mounted; self.mountChanging=true
    for node,points in pairs(s.anchors or {}) do H:RestorePoints(node,points) end
    for _,host in pairs(s.hosts or {}) do host:Hide() end
    s.frame:SetParent(s.parent); H:RestorePoints(s.frame,s.points); s.frame:SetSize(s.width,s.height); s.frame:SetScale(s.scale); s.frame:SetFrameLevel(s.level); self:HideNativeFrame(s.frame,false); self.mounted=nil; self.mountChanging=false
end
function C:InPage(node,parent)
    for _=1,20 do
        if node==parent then return true end
        if not node or not node.GetParent then return false end
        node=node:GetParent()
    end
    return false
end
function C:RebasePageNode(node,native)
    if not node or node==native or node.fsCharacterSkin or not node.GetNumPoints then return end
    local points=H:SavePoints(node); local changed=false
    for _,point in ipairs(points) do
        local relative=type(point[2])=="string" and _G[point[2]] or point[2]
        if relative and self:InPage(relative,CharacterFrame) and not self:InPage(relative,native) then
            local name=relative.GetName and relative:GetName() or ""
            local left=relative==CharacterFrame.LeftPaneHost or relative==_G.CharacterFrameLeftPaneHost or name:find("LeftPaneHost")
            local right=relative==CharacterFrame.RightPaneHost or relative==_G.CharacterFrameRightPaneHost or name:find("RightPaneHost")
            point[2]=(left and self.mounted.hosts.left) or (right and self.mounted.hosts.right) or native
            changed=true
        end
    end
    if changed then
        self.mounted.anchors[node]=self.mounted.anchors[node] or H:SavePoints(node)
        self.mountChanging=true; H:RestorePoints(node,points); self.mountChanging=false
    end
    self.pageAnchorHooks=self.pageAnchorHooks or {}
    if not self.pageAnchorHooks[node] and node.SetPoint then
        self.pageAnchorHooks[node]=true
        hooksecurefunc(node,"SetPoint",function()
            if self.mounted and self:InPage(node,self.mounted.frame) and not self.mountChanging and not InCombatLockdown() then self:RebasePageNode(node,self.mounted.frame) end
        end)
    end
end
function C:FitPageTree(node,native,scale,depth)
    depth=depth or 0; if depth>12 or not node or node.fsCharacterSkin then return end
    self:RebasePageNode(node,native)
    if node.GetObjectType and node:GetObjectType()=="StatusBar" and (self.page==3 or self.page==4) then
        if not self.pageBars then self.pageBars={} end
        if not self.pageBars[node] then
            local texture=node.GetStatusBarTexture and node:GetStatusBarTexture()
            local path=texture and texture.GetTexture and texture:GetTexture()
            local r,g,b,a=1,1,1,1
            if node.GetStatusBarColor then r,g,b,a=node:GetStatusBarColor() end
            self.pageBars[node]={texture=path,color={r,g,b,a}}
        end
        node:SetStatusBarTexture(H.texture); node:SetStatusBarColor(.12,.72,.86,1)
        self:SkinControl(node)
    end
    if node.GetRegions then
        for _,region in ipairs({node:GetRegions()}) do
            self:RebasePageNode(region,native)
            if region.GetObjectType and region:GetObjectType()=="FontString" then FS:ApplyFont(region,12) end
        end
    end
    if node.GetChildren then for _,child in ipairs({node:GetChildren()}) do self:FitPageTree(child,native,scale,depth+1) end end
end
function C:MountPage(native)
    local width,height=native:GetWidth(),native:GetHeight()
    self.mounted={frame=native,parent=native:GetParent(),points=H:SavePoints(native),width=width,height=height,scale=native:GetScale(),level=native:GetFrameLevel(),anchors={}}
    -- Preserve a full native layout canvas; resizing it to the viewport leaves
    -- fixed-height controls and CharacterFrame-relative anchors in the footer.
    local canvasWidth,canvasHeight=math.max(631,width),math.max(540,height)
    local fitted=self.page==3 or self.page==4
    if fitted then canvasWidth,canvasHeight=732,416 end
    local scale=math.min(732/canvasWidth,416/canvasHeight)
    native:SetParent(self.content); native:ClearAllPoints(); native:SetPoint("TOPLEFT",(748-canvasWidth*scale)/2,-8)
    native:SetSize(canvasWidth,canvasHeight); native:SetScale(scale); native:SetFrameLevel(self.content:GetFrameLevel()+1)
    -- The client's list and detail templates reference DIFFERENT pane hosts.
    -- Keep that distinction instead of redirecting both onto the full page.
    self.pageHosts=self.pageHosts or {}
    local hosts=self.pageHosts[native]
    if not hosts then
        hosts={left=CreateFrame("Frame",nil,native,"BackdropTemplate"),right=CreateFrame("Frame",nil,native,"BackdropTemplate")}
        for _,host in pairs(hosts) do H:Skin(host); host:SetBackdropColor(.025,.035,.05,1); host:EnableMouse(false) end
        hosts.left.fsCharacterSkin=true; hosts.right.fsCharacterSkin=true
        self.pageHosts[native]=hosts
    end
    self.mounted.hosts=hosts
    local leftWidth=canvasWidth-233
    hosts.left:SetSize(leftWidth,canvasHeight); hosts.left:ClearAllPoints(); hosts.left:SetPoint("TOPLEFT",native,"TOPLEFT",0,0); hosts.left:Show()
    hosts.right:SetSize(233,canvasHeight); hosts.right:ClearAllPoints(); hosts.right:SetPoint("TOPLEFT",native,"TOPLEFT",leftWidth,0); hosts.right:Show()
    self:HideNativeFrame(native,false); self:SkinTree(native); native:Show()
    if not native.fsPageRefresh then
        native.fsPageRefresh=true; local elapsed=0
        native:HookScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt; if elapsed<.2 then return end; elapsed=0
            if self.mounted and self.mounted.frame==native and not InCombatLockdown() then
                self:SkinTree(native); self:FitPageTree(native,native,native:GetScale())
            end
        end)
    end
    self:FitPageTree(native,native,scale)
end
function C:Apply()
    if not CharacterFrame or self.applying then return end
    if InCombatLockdown() then self.pending=true; return end
    self.applying=true
    if not FS:IsModuleEnabled(self.name) then
        self:RestoreMounted()
        for frame in pairs(self.hiddenFrames or {}) do self:HideNativeFrame(frame,false) end
        for region,alpha in pairs(self.alpha) do region:SetAlpha(alpha) end
        for region,font in pairs(self.fonts) do if font[1] then FS:ReleaseFont(region); region:SetFont(unpack(font)) end end
        for bar,state in pairs(self.pageBars or {}) do if state.texture then bar:SetStatusBarTexture(state.texture) end; bar:SetStatusBarColor(unpack(state.color)) end
        for _,skin in pairs(self.skins) do skin:Hide() end
        for _,skin in pairs(self.controls) do skin:Hide() end
        if self.root then self.root:Hide(); CharacterFrame:SetSize(unpack(self.originalSize)) end
        self.applying=false; return
    end
    self.pending=false; self:CreateNavigation(); self:RestoreMounted()
    self.originalSize=self.originalSize or {CharacterFrame:GetWidth(),CharacterFrame:GetHeight()}
    CharacterFrame:SetSize(780,580)
    for _,child in ipairs({CharacterFrame:GetChildren()}) do if child~=self.root then self:HideNativeFrame(child,true) end end
    for _,region in ipairs({CharacterFrame:GetRegions()}) do self:HideArt(region) end
    self.page=1
    for i,page in ipairs(self.pages) do if CharacterFrame.activeSubframe==page.frame then self.page=i end end
    local character=self.page==1; self.character:SetShown(character); self.side:SetShown(character); self.content:SetShown(not character)
    if not character then
        local native=_G[self.pages[self.page].frame]
        if native then
            self:MountPage(native)
        end
    end
    self.root:Show(); self:RefreshTabs(); self:RefreshCharacter()
    FS.Layout:Collect(); FS.Layout:Apply("CharacterInfo"); self.applying=false
end
function C:InstallHooks()
    if not CharacterFrame or self.hooked then return end; self.hooked=true
    CharacterFrame:HookScript("OnShow",function() if FS:IsModuleEnabled(self.name) then FS:CloseOtherWindows(CharacterFrame) end; self:Apply() end)
    for _,method in ipairs({"RefreshDisplay","ShowSubFrame"}) do if CharacterFrame[method] then hooksecurefunc(CharacterFrame,method,function() self:Apply() end) end end
    local elapsed=0
    CharacterFrame:HookScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt; if elapsed<.25 then return end; elapsed=0
        if FS:IsModuleEnabled(self.name) and self.root and self.root:IsShown() then self:RefreshCharacter() end
    end)
end
