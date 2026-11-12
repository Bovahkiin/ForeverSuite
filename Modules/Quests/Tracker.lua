local _,FS=...
local Q,T,H=FS.modules.Quests,FS.Tools,FS.HUD
function Q:Track(row)
    if not row or not row.id or InCombatLockdown() then return end
    T:Call(C_QuestLog and C_QuestLog.AddQuestWatch,row.id)
    T:Call(C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID,row.id)
    self.focusID=row.id; self:UpdateTracker()
    if FS.modules.Map.FocusNavigation then FS.modules.Map:FocusNavigation(row.id) end
end
function Q:TrackerRows()
    local rows={}
    for _,row in ipairs(self.rows) do if not self:Data().hideComplete or not row.complete then rows[#rows+1]=row end end
    if self:Data().nearby then
        table.sort(rows,function(a,b)
            if a.id==self.focusID then return b.id~=self.focusID end
            if b.id==self.focusID then return false end
            if (a.distance or math.huge)~=(b.distance or math.huge) then return (a.distance or math.huge)<(b.distance or math.huge) end
            return a.index<b.index
        end)
    end
    return rows
end
function Q:CreateTracker()
    if self.tracker then return self.tracker end
    local f=CreateFrame("Frame","ForeverSuiteQuestTracker",UIParent,"BackdropTemplate"); self.tracker=f
    f:SetSize(300,200); f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:EnableMouse(true)
    if Minimap then f:SetPoint("TOPRIGHT",Minimap,"BOTTOMRIGHT",0,-42) else f:SetPoint("TOPRIGHT",-26,-260) end
    f:SetBackdrop({bgFile=H.texture}); f:SetBackdropColor(.025,.035,.05,.7)
    f.accent=f:CreateTexture(nil,"ARTWORK"); f.accent:SetColorTexture(.95,.68,.24,.8); f.accent:SetSize(30,2); f.accent:SetPoint("TOPLEFT",8,-2)
    f.title=H:Label(f,"QUEST OBJECTIVES",38,-12,220); FS:ApplyFont(f.title,14)
    f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetSize(25,25); f.icon:SetPoint("TOPLEFT",8,-7); FS:SetMenuIcon(f.icon,"Quests")
    f.log=H:Button(f,"Log",249,-6,44,function() self:ShowWindow() end); f.log:SetHeight(26)
    f.cards={}
    for i=1,3 do
        local c=CreateFrame("Frame",nil,f,"BackdropTemplate"); f.cards[i]=c
        c:SetSize(284,100); c:SetPoint("TOPLEFT",8,-44); c:SetBackdrop({bgFile=H.texture}); c:SetBackdropColor(.055,.075,.09,.85)
        c.stripe=c:CreateTexture(nil,"ARTWORK"); c.stripe:SetColorTexture(.15,.75,.9,1); c.stripe:SetWidth(2); c.stripe:SetPoint("TOPLEFT"); c.stripe:SetPoint("BOTTOMLEFT")
        c.heading=H:Button(c,"",27,-3,204,function(b) if b.row then self:Track(b.row) end end)
        c.heading:SetBackdropColor(0,0,0,0); c.heading:SetBackdropBorderColor(0,0,0,0)
        local font=c.heading.GetFontString and c.heading:GetFontString(); if font then font:SetJustifyH("LEFT"); FS:ApplyFont(font,13) end
        c.complete=c:CreateTexture(nil,"OVERLAY"); c.complete:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); c.complete:SetSize(18,18); c.complete:SetPoint("BOTTOMRIGHT",-4,5); c.complete:Hide()
        c.icon=c:CreateTexture(nil,"ARTWORK"); c.icon:SetSize(22,22); c.icon:SetPoint("TOPLEFT",4,-5)
        c.fold=H:Button(c,"-",239,-4,36,function()
            if c.row and c.row.id then self:Data().collapsed[c.row.id]=not self:Data().collapsed[c.row.id]; self:UpdateTracker() end
        end); c.fold:SetHeight(25)
        c.map=H:Button(c,"Map",239,-34,36,function() if c.row then self:OpenQuestMap(c.row) end end); c.map:SetHeight(25)
        c.lines={}
        for j=1,3 do local line=H:Label(c,"",12,-33-(j-1)*18,218); line:SetHeight(18); c.lines[j]=line end
        c.progress=CreateFrame("StatusBar",nil,c); c.progress:SetPoint("BOTTOMLEFT",12,8); c.progress:SetSize(218,4)
        c.progress:SetStatusBarTexture(H.texture); c.progress:SetMinMaxValues(0,1)
        c.progress.bg=c.progress:CreateTexture(nil,"BACKGROUND"); c.progress.bg:SetAllPoints(); c.progress.bg:SetColorTexture(.1,.14,.17,1)
        c.distance=H:Label(c,"",239,-64,38); c.distance:SetJustifyH("RIGHT")
        c.heading:SetScript("OnEnter",function(b)
            if b.row then GameTooltip:SetOwner(b,"ANCHOR_LEFT"); GameTooltip:AddLine(b.row.title,1,.8,.3)
                for _,line in ipairs(b.row.objectives) do GameTooltip:AddLine(line,1,1,1,true) end
                GameTooltip:AddLine("Click to focus. Map opens the quest location.",.4,.8,1,true); GameTooltip:Show() end
        end)
        c.heading:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    f.previous=H:Button(f,"<",8,-160,32,function() self.trackerPage=math.max(1,(self.trackerPage or 1)-1); self:UpdateTracker() end)
    f.next=H:Button(f,">",260,-160,32,function() self.trackerPage=(self.trackerPage or 1)+1; self:UpdateTracker() end)
    f.page=H:Label(f,"",47,-168,207); f.page:SetJustifyH("CENTER")
    f.empty=H:Label(f,"No active quests. Explore to find your next adventure.",14,-52,272); f.empty:SetHeight(44)
    f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,delta) self.trackerPage=math.max(1,(self.trackerPage or 1)-delta); self:UpdateTracker() end)
    f:SetScript("OnUpdate",function(_,elapsed)
        self.pinElapsed=(self.pinElapsed or 0)+elapsed
        if self.pinElapsed>=.2 then self.pinElapsed=0; self:UpdateQuestPins() end
    end)
    FS.Layout:Register("QuestTracker",f,"Quest Objectives"); return f
end
function Q:UpdateTracker(useRows)
    if not FS:IsModuleEnabled(self.name) or not self:Data().tracker then
        if self.tracker then self.tracker:Hide() end
        return
    end
    local f=self:CreateTracker(); f:Show()
    if not useRows then self:Build() end
    local rows=self:TrackerRows(); local pages=math.max(1,math.ceil(#rows/3))
    self.trackerPage=math.max(1,math.min(self.trackerPage or 1,pages))
    local _,size=f.title:GetFont(); size=size or 14
    local width=math.max(300,size*22); f:SetWidth(width)
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
    local logWidth=math.max(44,size*3+12); f.log:SetWidth(logWidth); H:FitButton(f.log,1,26); at(f.log,width-logWidth-7,6)
    local titleHeight=H:TextHeight(f.title,width-logWidth-52,2)
    local y=math.max(44,math.max(titleHeight+12,f.log:GetHeight()+6)+10)
    local sideWidth=math.max(38,size*4+12); local textWidth=width-sideWidth-46
    for i,c in ipairs(f.cards) do
        local row=rows[(self.trackerPage-1)*3+i]; c.row=row; c.heading.row=row; c:SetShown(row~=nil)
        if row then
            local folded=row.id and self:Data().collapsed[row.id]
            local count=math.min(3,math.max(1,#row.details))
            c:SetWidth(width-16); c.heading:SetWidth(textWidth-15); c.fold:SetWidth(sideWidth); c.map:SetWidth(sideWidth)
            local sideX=width-16-sideWidth-9
            at(c.fold,sideX,4); H:FitButton(c.fold,1,25)
            c:ClearAllPoints(); c:SetPoint("TOPLEFT",8,-y)
            c.complete:SetShown(row.complete and not folded); c.heading:SetText(row.title); c.fold:SetText(folded and "+" or "-"); c.map:SetShown(not folded)
            c.progress:SetShown(not folded); c.distance:SetShown(not folded)
            c.distance:SetText(row.distance and (row.distance>=1000 and string.format("%.1fk",row.distance/1000) or math.floor(row.distance).."y") or "")
            FS:SetMenuIcon(c.icon,row.complete and "Reputation" or "Quests")
            c.stripe:SetColorTexture(row.complete and .3 or .15,row.complete and .85 or .75,row.complete and .5 or .9,1)
            local progress=0
            for j,line in ipairs(c.lines) do
                local detail=row.details[j]; line:SetShown(not folded and j<=count)
                line:SetText(detail and ((detail.done and "+ " or "- ")..detail.text) or (row.complete and "Ready to turn in" or "Open the quest log for details"))
                line:SetTextColor(detail and detail.done and .4 or .84,detail and detail.done and .9 or .9,detail and detail.done and .55 or .95)
            end
            local headingHeight=H:FitButton(c.heading,2)
            local lineTop=math.max(33,headingHeight+7)
            for j,line in ipairs(c.lines) do
                at(line,12,lineTop); lineTop=lineTop+H:TextHeight(line,textWidth,3)+3
                if j>=count then break end
            end
            local mapTop=c.fold:GetHeight()+9; at(c.map,sideX,mapTop); H:FitButton(c.map,1,25)
            c.distance:SetWidth(sideWidth); at(c.distance,sideX,mapTop+c.map:GetHeight()+5)
            local distanceHeight=H:TextHeight(c.distance,sideWidth,1)
            c.progress:SetWidth(textWidth)
            local height=folded and math.max(headingHeight+7,c.fold:GetHeight()+8) or math.max(lineTop+16,mapTop+c.map:GetHeight()+5+distanceHeight+16)
            c:SetHeight(height); y=y+height+6
            for _,o in ipairs(row.details) do progress=progress+(o.done and 1 or o.have and o.need and o.need>0 and math.min(1,o.have/o.need) or 0) end
            c.progress:SetValue(row.complete and 1 or #row.details>0 and progress/#row.details or 0)
            c.progress:SetStatusBarColor(row.complete and .3 or .15,.8,row.complete and .5 or .95)
        end
    end
    f.empty:SetWidth(width-28); at(f.empty,14,y+8); local emptyHeight=H:TextHeight(f.empty,width-28,3)
    f.empty:SetShown(#rows==0); if #rows==0 then y=y+emptyHeight+16 end
    for _,b in ipairs({f.previous,f.next}) do b:ClearAllPoints(); b:SetPoint("TOPLEFT",b==f.previous and 8 or width-40,-y); b:SetShown(pages>1) end
    f.page:ClearAllPoints(); f.page:SetPoint("TOPLEFT",47,-y-8)
    f.page:SetText(#rows.." quests"..(pages>1 and (" | "..self.trackerPage.." / "..pages) or ""))
    f.page:SetWidth(width-93); local footerHeight=H:TextHeight(f.page,width-93,2)
    H:FitButton(f.previous,1); H:FitButton(f.next,1)
    f:SetHeight(y+math.max(36,footerHeight+16,f.previous:GetHeight()+6))
end
