local _,FS=...
local M,Q,T,H=FS.modules.Map,FS.modules.Quests,FS.Tools,FS.HUD
local arrowSegments={{-13,0,17,0},{17,0,3,12},{17,0,3,-12},{3,12,3,3},{3,-12,3,-3},{3,3,-13,3},{3,-3,-13,-3}}
local defaults={navigation=true,autoQuest=true,followFocused=true,autoNext=true,navDistance=true,navTitle=true,navHideCombat=false,nativeWaypoint=true,navColor="Cyan",navSize=1,navFont=14,arrival=20,navStyle="Arrow"}
for key,value in pairs(defaults) do FS.defaults.map[key]=value end
for key,value in pairs({trail=true,trailColor="Cyan",trailSize=3,trailSpacing=10,trailOpacity=.8}) do FS.defaults.map[key]=value end
local colors={Cyan={.12,.72,.86},Gold={.95,.68,.24},Blue={.22,.52,1},Green={.18,.75,.45},Purple={.65,.45,.95},White={.9,.94,1}}
M.description="Quest waypoints update automatically. Click the arrow for the map; right-click to stop. Use Move Frames to move or resize it."
for _,option in ipairs({{key="navigation",label="Enable waypoint navigation"},{key="autoQuest",label="Waypoint on quest accept"},{key="followFocused",label="Follow clicked quest"},{key="autoNext",label="Next quest after turn-in"},{key="navDistance",label="Show distance"},{key="navTitle",label="Show destination title"},{key="navHideCombat",label="Hide arrow during combat"},{key="nativeWaypoint",label="Also set game map waypoint"},{key="navColor",label="Arrow color",values={"Cyan","Gold","Blue","Green","Purple","White"}},{key="navSize",label="Waypoint size",values={.8,1,1.2,1.4}},{key="navFont",label="Waypoint text size",values={12,14,16,18}},{key="arrival",label="Arrival radius (yards)",values={10,20,35,50}},{key="navStyle",label="Arrow style",values={"Arrow","Chevron"}}}) do M.options[#M.options+1]=option end
M.settingsHint="Automatic quest navigation needs a location from the client. Manual saved pins take priority."
for _,option in ipairs({{key="trail",label="Minimap ant trail"},{key="trailColor",label="Trail color",values={"Cyan","Gold","Blue","Green","Purple","White"}},{key="trailSize",label="Trail dot size",values={2,3,4,5}},{key="trailSpacing",label="Trail dot spacing",values={6,10,14,18}},{key="trailOpacity",label="Trail opacity",values={.4,.6,.8,1}}}) do M.options[#M.options+1]=option end
for _,option in ipairs({{key="worldControls",label="Show world map controls"},
    {key="worldPins",label="Show saved pins on the world map"},{key="worldRoute",label="Show queued stops on the world map"}}) do
    M.options[#M.options+1]=option
end
local function valid(p)
    return type(p)=="table" and T:Number(p.map) and p.map>0 and T:Number(p.x) and T:Number(p.y) and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end
local function same(a,b) return valid(a) and valid(b) and a.map==b.map and math.abs(a.x-b.x)<.00001 and math.abs(a.y-b.y)<.00001 end
function M:ReadNativeWaypoint()
    local p=T:Call(C_Map and C_Map.GetUserWaypoint)
    if type(p)~="table" or not p.position then return end
    local x,y=T:Call(p.position.GetXY,p.position); local result={map=p.uiMapID,x=x,y=y}
    if valid(result) then return result end
end
function M:ReleaseNativeWaypoint()
    if not self.ownedWaypoint then return end
    if InCombatLockdown() then self.releasePending=true; return end
    if same(self:ReadNativeWaypoint(),self.ownedWaypoint) then T:Call(C_Map and C_Map.ClearUserWaypoint) end
    self.ownedWaypoint=nil; self.releasePending=false
end
function M:SyncNativeWaypoint(p)
    if self.releasePending then self:ReleaseNativeWaypoint() end
    if not self:Data().nativeWaypoint or not valid(p) then self:ReleaseNativeWaypoint(); return end
    if InCombatLockdown() then return end
    if not self.ownedWaypoint and not self.explicitNavigation and self:ReadNativeWaypoint() then self.externalWaypoint=true end
    -- A manual game pin placed after ours stays under the player's control.
    if self.ownedWaypoint and C_Map and C_Map.GetUserWaypoint and not same(self:ReadNativeWaypoint(),self.ownedWaypoint) then self.ownedWaypoint=nil; self.externalWaypoint=true end
    if self.externalWaypoint or same(p,self.ownedWaypoint) or not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    local point=T:Call(UiMapPoint.CreateFromCoordinates,p.map,p.x,p.y)
    if point then
        local ok=pcall(C_Map.SetUserWaypoint,point)
        if ok then self.ownedWaypoint={map=p.map,x=p.x,y=p.y}; self.explicitNavigation=nil; T:Call(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
    end
end
function M:ClearNavigation()
    self.suppressedQuest=self.questID; self.questID=nil; self.manualTarget=nil; self.destination=nil; self.waitingRow=nil; self.noNext=true; self.explicitNavigation=nil
    self.navVector=nil; self:ReleaseNativeWaypoint(); if self.navigator then self.navigator:Hide() end
    self:AnimateNavigation(); self:UpdateTrail()
end
function M:SetNavigation(pin)
    if not valid(pin) or not FS:IsModuleEnabled(self.name) then return end
    self:NormalizeSettings()
    self.manualTarget={map=pin.map,x=pin.x,y=pin.y,name=T:Text(pin.name)~="" and pin.name or "Saved location"}; self.externalWaypoint=nil; self.explicitNavigation=true
    self:UpdateNavigation()
end
function M:FocusNavigation(id)
    if not self:Data().followFocused or not FS:IsModuleEnabled(self.name) or not T:Number(id) then return end
    self:NormalizeSettings(); self.manualTarget=nil; self.questID=id; self.suppressedQuest=nil; self.externalWaypoint=nil; self.explicitNavigation=true; self.noNext=nil; self.finishedQuest=nil; self:UpdateNavigation()
end
function M:QuestDestination(row)
    local map,x,y=T:Call(C_QuestLog and C_QuestLog.GetNextWaypoint,row.id)
    local p={map=map,x=x,y=y,name=row.title,questID=row.id,complete=row.complete}
    if valid(p) then return p end
    local current=self:Position()
    if current then
        local fx,fy=T:Call(C_QuestLog and C_QuestLog.GetNextWaypointForMap,row.id,current)
        p.map,p.x,p.y=current,fx,fy; if valid(p) then return p end
        for _,location in ipairs(Q:QuestLocations(current)) do
            if location.row.id==row.id then p.map,p.x,p.y=current,location.x,location.y; return p end
        end
    end
end
function M:NavigationEvent(event,...)
    self:NormalizeSettings()
    if event=="QUEST_ACCEPTED" and self:Data().autoQuest and FS:IsModuleEnabled("Quests") then
        local first,second=...; local id=T:Number(second) and second or first
        if T:Number(id) and id>0 then self.questID=id; self.suppressedQuest=nil; self.externalWaypoint=nil; self.explicitNavigation=true; self.noNext=nil; self.finishedQuest=nil; self.awaitQuestUntil=GetTime()+10 end
    elseif event=="QUEST_TURNED_IN" or event=="QUEST_REMOVED" then
        local id=...; if id==self.questID then self.questID=nil; self.finishedQuest=id; if not self:Data().autoNext then self.noNext=true end end
    elseif event=="PLAYER_ENTERING_WORLD" then self.noNext=nil end
    self:UpdateNavigation()
end
function M:ResolveNavigation()
    if valid(self.manualTarget) then return self.manualTarget end
    if not FS:IsModuleEnabled("Quests") then return end
    Q:Build()
    local row=self.questID and Q.byID[self.questID]
    if row and row.id~=self.finishedQuest and row.id~=self.suppressedQuest then
        local p=self:QuestDestination(row)
        return p,row
    end
    if self.questID and self.awaitQuestUntil and GetTime()<self.awaitQuestUntil and not self.finishedQuest then return nil,{title="Accepted quest - loading location"} end
    if self.questID then self.questID=nil end
    if not self:Data().autoQuest or not self:Data().autoNext or self.noNext then return end
    local rows={}; for _,candidate in ipairs(Q.rows) do rows[#rows+1]=candidate end
    table.sort(rows,function(a,b) return (a.distance or math.huge)==(b.distance or math.huge) and a.index<b.index or (a.distance or math.huge)<(b.distance or math.huge) end)
    for _,candidate in ipairs(rows) do
        if candidate.id and candidate.id~=self.suppressedQuest and candidate.id~=self.finishedQuest then
            local p=self:QuestDestination(candidate)
            if p then self.questID=candidate.id; return p,candidate end
        end
    end
end
function M:NavigationVector(p)
    local map,px,py=self:Position(); if not map then return end
    if CreateVector2D and C_Map and C_Map.GetWorldPosFromMapPos then
        local instance,a=T:Call(C_Map.GetWorldPosFromMapPos,map,CreateVector2D(px,py))
        local other,b=T:Call(C_Map.GetWorldPosFromMapPos,p.map,CreateVector2D(p.x,p.y))
        if a and b and instance==other then
            local north,west=T:Call(a.GetXY,a); local tn,tw=T:Call(b.GetXY,b)
            if T:Number(north) and T:Number(west) and T:Number(tn) and T:Number(tw) then return west-tw,tn-north end
        end
    end
    if map==p.map then local width,height=Q:MapSize(map); if width then return (p.x-px)*width,(py-p.y)*height end end
end
function M:CreateNavigator()
    if self.navigator then return self.navigator end
    local f=CreateFrame("Button","ForeverSuiteWaypoint",UIParent); self.navigator=f
    f:SetSize(250,48); f:SetPoint("TOP",UIParent,"TOP",0,-160); f:SetClampedToScreen(true); f:RegisterForClicks("LeftButtonUp","RightButtonUp")
    f.title=H:Label(f,"",54,-2,196); f.title:SetHeight(22); if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.arrow=CreateFrame("Frame",nil,f); f.arrow:SetSize(40,40); f.arrow:SetPoint("LEFT",f,"LEFT",4,0); f.arrow:EnableMouse(false)
    f.lines={}; f.shadows={}
    for i=1,7 do
        local shadow=f.arrow:CreateLine(nil,"ARTWORK"); shadow:SetTexture(H.texture); shadow:SetVertexColor(0,0,0,.8); shadow:SetThickness(5); f.shadows[i]=shadow
        local line=f.arrow:CreateLine(nil,"OVERLAY"); line:SetTexture(H.texture); f.lines[i]=line
    end
    f.distance=H:Label(f,"",54,-25,196); f.distance:SetHeight(22)
    -- Status is retained for navigation logic; compact mode uses the distance
    -- line for arrival or unavailable-data messages instead of a third row.
    f.status=H:Label(f,"",0,0,1); f.status:Hide()
    f:SetScript("OnClick",function(_,button)
        if button=="RightButton" then self:ClearNavigation()
        elseif not InCombatLockdown() then
            if self.destination and self.destination.questID and Q.byID[self.destination.questID] then Q:OpenQuestMap(Q.byID[self.destination.questID])
            elseif self.destination then T:Call(OpenWorldMap,self.destination.map) end
        end
    end)
    f:SetScript("OnEnter",function() GameTooltip:SetOwner(f,"ANCHOR_BOTTOM"); GameTooltip:AddLine(self.destination and self.destination.name or "Quest waypoint"); GameTooltip:AddLine("Left-click: open map. Right-click: stop navigation.",.8,.9,1,true); GameTooltip:Show() end)
    f:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f:SetScript("OnUpdate",function(_,elapsed)
        self.navElapsed=(self.navElapsed or 0)+elapsed
        if self.navElapsed>=.05 then self.navElapsed=self.navElapsed%.05; self:RenderNavigation() end
        self:AnimateNavigation(elapsed)
        self:UpdateTrail(elapsed)
    end)
    FS.Layout:Register("Waypoint",f,"Quest Waypoint"); f:Hide(); return f
end
function M:UpdateTrail(elapsed)
    local count=self:RenderTrail(elapsed)
    for i=count+1,self.visibleTrailDots or 0 do self.trailDots[i]:Hide() end
    self.visibleTrailDots=count
end
function M:RenderTrail(elapsed)
    local db=self:Data(); local v=self.navVector
    if not db.trail or not FS:IsModuleEnabled(self.name) or not db.navigation or not v or not Minimap or not Minimap:IsShown() then return 0 end
    local radius=T:Call(C_Minimap and C_Minimap.GetViewRadius)
    if not T:Number(radius) or radius<=0 then return 0 end
    local east,north=v.east,v.north
    if T:Call(GetCVar,"rotateMinimap")=="1" then
        local facing=T:Call(GetPlayerFacing); if not T:Number(facing) then return 0 end
        east,north=east*math.cos(facing)+north*math.sin(facing),north*math.cos(facing)-east*math.sin(facing)
    end
    local x,y=east/radius,north/radius; local length=math.sqrt(x*x+y*y)
    if length==0 then return 0 end
    local limit=math.min(length,.85); x,y=x/length*limit*Minimap:GetWidth()/2,y/length*limit*Minimap:GetHeight()/2
    local pixels=math.sqrt(x*x+y*y); if pixels<=12 then return 0 end
    self.trailPhase=((self.trailPhase or 0)+math.max(0,elapsed or 0)*16)%db.trailSpacing
    self.trailDots=self.trailDots or {}
    local color=colors[db.trailColor]; local index=0
    for distance=12+self.trailPhase,pixels,db.trailSpacing do
        if index==40 then break end
        index=index+1
        local dot=self.trailDots[index]
        if not dot then
            dot=CreateFrame("Frame",nil,Minimap); dot:SetFrameLevel(Minimap:GetFrameLevel()+4); dot:EnableMouse(false)
            dot.texture=dot:CreateTexture(nil,"OVERLAY"); dot.texture:SetAllPoints(); self.trailDots[index]=dot
        end
        if dot:GetParent()~=Minimap then dot:SetParent(Minimap) end
        if dot.trailSize~=db.trailSize then dot:SetSize(db.trailSize,db.trailSize); dot.trailSize=db.trailSize end
        if dot.trailColor~=color or dot.trailOpacity~=db.trailOpacity then
            dot.texture:SetColorTexture(color[1],color[2],color[3],db.trailOpacity)
            dot.trailColor,dot.trailOpacity=color,db.trailOpacity
        end
        dot:SetPoint("CENTER",Minimap,"CENTER",x*distance/pixels,y*distance/pixels)
        if not dot:IsShown() then dot:Show() end
    end
    return index
end
function M:AnimateNavigation(elapsed)
    local f=self.navigator; if not f then return end
    local v=self.navVector; local facing=T:Call(GetPlayerFacing)
    if not f:IsShown() or not v or not T:Number(facing) then
        self.navAngle=nil; self.navTarget=nil
        for i,line in ipairs(f.lines) do line:Hide(); f.shadows[i]:Hide() end
        if f.themeArrow then f.themeArrow:Hide() end
        return
    end
    local target=math.atan2(v.north,v.east)-facing
    if not self.navAngle or self.navTarget~=v.key then self.navAngle=target end
    self.navTarget=v.key
    -- Follow the shortest turn, including crossing the -pi/pi boundary.
    local delta=(target-self.navAngle+math.pi)%(2*math.pi)-math.pi
    self.navAngle=self.navAngle+delta*(1-math.exp(-18*math.max(0,elapsed or 0)))
    local x,y=math.cos(self.navAngle),math.sin(self.navAngle)
    local theme=FS.Themes:Current()
    if theme then
        if not f.themeArrow then f.themeArrow=f.arrow:CreateTexture(nil,"OVERLAY"); f.themeArrow.ignoreInLayout=true; f.themeArrow:SetAllPoints() end
        if f.themeArrowIndex~=theme then f.themeArrow:SetTexture(FS.Themes:Asset(theme,"Arrow")); f.themeArrowIndex=theme end
        if f.themeArrow.SetRotation then f.themeArrow:SetRotation(self.navAngle-math.pi/2) end
        f.themeArrow:Show()
        for i,line in ipairs(f.lines) do line:Hide(); f.shadows[i]:Hide() end
        return
    elseif f.themeArrow then f.themeArrow:Hide() end
    local fullArrow=self:Data().navStyle=="Arrow"
    for i,point in ipairs(arrowSegments) do
        local ax,ay=x*point[1]-y*point[2],y*point[1]+x*point[2]
        local bx,by=x*point[3]-y*point[4],y*point[3]+x*point[4]
        local show=fullArrow or (i>=2 and i<=5)
        local shadow,line=f.shadows[i],f.lines[i]
        shadow:SetStartPoint("CENTER",f.arrow,ax,ay); shadow:SetEndPoint("CENTER",f.arrow,bx,by); shadow:SetShown(show)
        line:SetStartPoint("CENTER",f.arrow,ax,ay); line:SetEndPoint("CENTER",f.arrow,bx,by); line:SetShown(show)
    end
end
function M:RenderNavigation()
    local f=self.navigator; if not f then return end
    local db=self:Data(); local p=self.destination
    f:SetShown(FS:IsModuleEnabled(self.name) and db.navigation and (p~=nil or self.waitingRow~=nil) and not (db.navHideCombat and InCombatLockdown()))
    if not f:IsShown() then self.navVector=nil; self:AnimateNavigation(); self:UpdateTrail(); return end
    local title=db.navTitle and (p and p.name or self.waitingRow.title) or 'Waypoint'; if f.title:GetText()~=title then f.title:SetText(title) end
    local fontSignature=db.navFont..':'..tostring(FS.fontGeneration)
    if f.fontSignature~=fontSignature then FS:ApplyFont(f.title,db.navFont,"OUTLINE"); FS:ApplyFont(f.distance,db.navFont,"OUTLINE"); f.fontSignature=fontSignature end
    f.title:SetShown(db.navTitle)
    local saved=FS.db.layout.frames.Waypoint
    if self.navAppliedSize and self.navAppliedSize~=db.navSize then
        if saved then saved.scale=db.navSize; FS.Layout:Apply("Waypoint") else f:SetScale(db.navSize) end
    elseif not saved and f:GetScale()~=db.navSize then f:SetScale(db.navSize) end
    self.navAppliedSize=db.navSize
    local east,north,distance
    if p then east,north=self:NavigationVector(p) end
    if T:Number(east) and T:Number(north) then distance=math.sqrt(east*east+north*north) end
    local arrived=distance and distance<=db.arrival
    local facing=T:Call(GetPlayerFacing); local color=colors[arrived and "Green" or db.navColor]
    for i,line in ipairs(f.lines) do line:SetVertexColor(unpack(i>3 and colors.Gold or color)); line:SetThickness(i>3 and 1.5 or 2.5) end
    self.navVector=nil
    if distance and distance>0 and T:Number(facing) and not arrived then
        self.navVector={east=east,north=north,key=tostring(p.questID or p.name)..":"..tostring(p.map)}
    end
    self:AnimateNavigation()
    self:UpdateTrail()
    local mapInfo=p and not distance and T:Call(C_Map and C_Map.GetMapInfo,p.map)
    local status=not p and "Quest location unavailable" or arrived and "Arrived at objective area"
        or not distance and (mapInfo and T:Text(mapInfo.name)~="" and "Travel to "..mapInfo.name or "Direction unavailable here")
        or not T:Number(facing) and "Facing unavailable" or p.complete and "Return to turn in" or "Follow the arrow"
    if f.status:GetText()~=status then f.status:SetText(status) end
    local caption
    if not p or arrived or not distance or not T:Number(facing) then caption=arrived and "Arrived" or status
    else caption=db.navDistance and (distance>=1000 and string.format("%.1fk yards",distance/1000) or math.floor(distance).." yards") or "" end
    if f.distance:GetText()~=caption then f.distance:SetText(caption) end
    local _,textSize=f.title:GetFont(); textSize=T:Number(textSize) and textSize or db.navFont
    local layoutSignature=textSize..':'..tostring(db.navTitle)
    if f.navLayoutSignature~=layoutSignature then
        f.title:SetHeight(textSize+4); f.distance:SetHeight(textSize+4); f.distance:ClearAllPoints(); f.distance:SetPoint("TOPLEFT",54,db.navTitle and -textSize-8 or -2)
        f:SetHeight(math.max(42,db.navTitle and textSize*2+12 or textSize+8)); f.navLayoutSignature=layoutSignature
    end
end
function M:UpdateNavigation()
    if self.navUpdating then return end; self.navUpdating=true
    self:NormalizeSettings()
    if not FS:IsModuleEnabled(self.name) or not self:Data().navigation then self.destination=nil; self.waitingRow=nil; self:ReleaseNativeWaypoint()
    else
        self.destination,self.waitingRow=self:ResolveNavigation()
        self:SyncNativeWaypoint(self.destination)
        self:CreateNavigator()
    end
    self:RenderNavigation(); self.navUpdating=false
end
local oldNormalize=M.Normalize
function M:Normalize()
    oldNormalize(self)
    for key,value in pairs(defaults) do if type(value)=="boolean" and type(self:Data()[key])~="boolean" then self:Data()[key]=value end end
    if self.navigationData~=self:Data() then
        self:ReleaseNativeWaypoint(); self.navigationData=self:Data(); self.questID=nil; self.manualTarget=nil; self.suppressedQuest=nil; self.finishedQuest=nil; self.noNext=nil; self.externalWaypoint=nil; self.explicitNavigation=nil; self.navAppliedSize=nil; self.awaitQuestUntil=nil
    end
end
local oldInitialize=M.Initialize
function M:Initialize()
    oldInitialize(self)
    for _,event in ipairs({"QUEST_ACCEPTED","QUEST_TURNED_IN","QUEST_REMOVED","QUEST_LOG_UPDATE","QUEST_POI_UPDATE","QUEST_WATCH_UPDATE","PLAYER_REGEN_DISABLED"}) do FS:RegisterClientEvent(self.events,event) end
end
function M:Event(event,...) self:NavigationEvent(event,...) end
local oldQuestSettings=Q.SettingsChanged
function Q:SettingsChanged() oldQuestSettings(self); M:UpdateNavigation() end
