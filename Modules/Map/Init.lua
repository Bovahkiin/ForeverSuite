local _,FS=...
local T=FS.Tools
local M=T:Module("Map","map","Map","Coordinates, saved location pins, explored regions and dungeon or raid lockouts. Save a pin at your current location.",{coordinates=true,pins={},worldControls=true,worldPins=true,worldRoute=true},{"ZONE_CHANGED_NEW_AREA","MAP_EXPLORATION_UPDATED","UPDATE_INSTANCE_INFO","PLAYER_ENTERING_WORLD"})
M.options={{key="coordinates",label="Show coordinates"}}
M.pinFrames={}; M.routeFrames={}
function M:Normalize()
    local valid={}
    for _,p in ipairs(self:Data().pins) do
        if type(p)=="table" and T:Number(p.map) and T:Number(p.x) and T:Number(p.y) and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 and T:Text(p.name)~="" and #valid<100 then valid[#valid+1]=p end
    end
    self:Data().pins=valid
end
function M:Position()
    local id=T:Call(C_Map and C_Map.GetBestMapForUnit,"player")
    local pos=id and T:Call(C_Map.GetPlayerMapPosition,id,"player")
    if not pos then return end
    local x,y=T:Call(pos.GetXY,pos)
    if T:Number(x) and T:Number(y) and x>=0 and y>=0 and x<=1 and y<=1 then return id,x,y end
end
function M:SavePin(name)
    local id,x,y=self:Position(); if not id then self.status="Your position is unavailable in this area."; return end
    name=T:Text(name):match("^%s*(.-)%s*$"); if name=="" then name=T:Call(GetSubZoneText) or "Location" end
    if #self:Data().pins>=100 then self.status="Remove a saved pin before adding more (100 maximum)."; return end
    table.insert(self:Data().pins,{map=id,x=x,y=y,name=name:sub(1,60)}); self:UpdatePins()
end
function M:Waypoint(row)
    if not row or not row.pin then return end
    local p=self:Data().pins[row.pin]
    if not p then return end
    if self.SetNavigation then self:SetNavigation(p); return end
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        T:Call(C_Map.SetUserWaypoint,UiMapPoint.CreateFromCoordinates(p.map,p.x,p.y)); T:Call(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint,true)
    else self.status=p.name..": "..string.format("%.1f, %.1f",p.x*100,p.y*100).." (map "..p.map..")" end
end
function M:Build()
    self.rows={}; local id,x,y=self:Position()
    self.status=id and string.format("Your location: %.1f, %.1f (map %d)",x*100,y*100,id) or "Coordinates are unavailable in this area."
    if id then
        local regions=T:Call(C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures,id)
        if regions then self.rows[#self.rows+1]={text="Exploration: "..#regions.." explored map regions"} end
    end
    for i,p in ipairs(self:Data().pins) do self.rows[#self.rows+1]={pin=i,text=p.name..string.format(" - %.1f, %.1f",p.x*100,p.y*100).." | map "..p.map} end
    local name,kind,difficulty,difficultyName,_,_,_,instanceID=T:Call(GetInstanceInfo)
    if name and kind~="none" then self.rows[#self.rows+1]={text="Instance: "..name.." - "..(difficultyName or kind)} end
    for i=1,(T:Call(GetNumSavedInstances) or 0) do
        local n,_,reset,_,locked,_,_,raid,_,d,_,encounters,killed=T:Call(GetSavedInstanceInfo,i)
        if n and locked then self.rows[#self.rows+1]={text="[Lockout] "..n.." | "..(killed or 0).."/"..(encounters or 0).." bosses | "..math.ceil((reset or 0)/3600).."h until reset"} end
    end
end
function M:UpdateWorldControls(world)
    local db=self:Data()
    local f=self.worldControls
    if f and f:GetParent()~=world then f:Hide(); self.worldControls=nil; f=nil end
    local show=FS:IsModuleEnabled(self.name) and db.worldControls
    if not show then if f then f:Hide() end; return end
    if not f then
        local H=FS.HUD
        f=CreateFrame("Frame",nil,world,"BackdropTemplate"); self.worldControls=f
        H:Skin(f); f:SetSize(432,36); f:SetPoint("BOTTOM",world,"BOTTOM",0,12)
        f:SetFrameLevel(world:GetFrameLevel()+12)
        f.zone=H:Button(f,"My zone",4,-3,100,function()
            if InCombatLockdown() then return end
            local id=T:Call(MapUtil and MapUtil.GetDisplayableMapForPlayer) or self:Position()
            if id then T:Call(world.SetMapID,world,id); self:UpdatePins() end
        end)
        f.pins=H:Button(f,"",110,-3,100,function() self:ToggleWorldLayer("worldPins") end)
        f.stops=H:Button(f,"",216,-3,106,function() self:ToggleWorldLayer("worldRoute") end)
        f.routes=H:Button(f,"Routes",328,-3,100,function() FS.modules.Workbench:Choose("Route Library") end)
    end
    local pins=db.worldPins and "Pins: On" or "Pins: Off"
    local stops=db.worldRoute and "Stops: On" or "Stops: Off"
    if f.pins:GetText()~=pins then f.pins:SetText(pins) end
    if f.stops:GetText()~=stops then f.stops:SetText(stops) end
    local width=world:GetWidth()
    if T:Number(width) and width>0 then
        local scale=math.min(1,math.max(.2,(width-24)/432))
        if f:GetScale()~=scale then f:SetScale(scale) end
    end
    f:Show()
end
function M:ToggleWorldLayer(key)
    if InCombatLockdown() then return end
    local db=self:Data()
    db[key]=not db[key]
    self:UpdatePins()
end
local function positionMarker(frame,canvas,p,width,height,point)
    if frame:GetParent()~=canvas then frame:SetParent(canvas) end
    local x,y=p.x*width,-p.y*height
    local oldPoint,relative,_,oldX,oldY=frame:GetPoint()
    if oldPoint~=point or relative~=canvas or oldX~=x or oldY~=y then
        frame:ClearAllPoints(); frame:SetPoint(point,canvas,"TOPLEFT",x,y)
    end
    if not frame:IsShown() then frame:Show() end
end
function M:UpdatePins()
    if InCombatLockdown() then return end
    local world=WorldMapFrame; local canvas=world and world.ScrollContainer and world.ScrollContainer.Child
    if not canvas or not world:IsShown() or (world.IsForbidden and world:IsForbidden()) or (canvas.IsForbidden and canvas:IsForbidden()) then return end
    self:UpdateWorldControls(world)
    local id=T:Call(world.GetMapID,world)
    local width,height=canvas:GetWidth(),canvas:GetHeight()
    local enabled=FS:IsModuleEnabled(self.name) and T:Number(width) and T:Number(height)
    local db=self:Data()
    local count,stopCount=0,0
    for i,p in ipairs(enabled and db.worldPins and db.pins or {}) do
        if p.map==id then
            count=count+1; local f=self.pinFrames[count]
            if not f then
                f=FS.HUD:Button(canvas,"+",0,0,20,function() end)
                f:SetScript("OnClick",function(b)
                    if InCombatLockdown() then return end
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        local E=FS.Extensions; local queue=E:Data().waypointQueue; local pin=self:Data().pins[b.pin]
                        if E.gathering then FS:Print("Finish recording the run before adding stops.")
                        elseif pin and #queue<50 then queue[#queue+1]=E.Copy(pin); self:UpdatePins(); FS:Print("Added stop: "..pin.name)
                        elseif pin then FS:Print("The waypoint queue is full.") end
                    else self:Waypoint({pin=b.pin}) end
                end)
                f:SetScript("OnEnter",function(b) local pin=self:Data().pins[b.pin]; if pin then GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine(pin.name); GameTooltip:AddLine("Shift-click to add a route stop."); GameTooltip:Show() end end)
                f:SetScript("OnLeave",function() GameTooltip:Hide() end); f:SetSize(20,20); self.pinFrames[count]=f
            end
            f.pin=i; positionMarker(f,canvas,p,width,height,"CENTER")
        end
    end
    for i=count+1,#self.pinFrames do self.pinFrames[i]:Hide() end
    local queue=FS.Extensions and FS.Extensions:Data().waypointQueue
    for i,p in ipairs(enabled and db.worldRoute and queue or {}) do
        if p.map==id then
            stopCount=stopCount+1
            local marker=self.routeFrames[stopCount]
            if not marker then
                marker=CreateFrame("Frame",nil,canvas,"BackdropTemplate"); self.routeFrames[stopCount]=marker
                FS.HUD:Skin(marker); marker:SetSize(24,22); marker:EnableMouse(false)
                marker.number=FS.Widgets:Label(marker); marker.number:SetPoint("CENTER")
            end
            local label=tostring(i)
            if marker.number:GetText()~=label then marker.number:SetText(label) end
            positionMarker(marker,canvas,p,width,height,"BOTTOMLEFT")
        end
    end
    for i=stopCount+1,#self.routeFrames do self.routeFrames[i]:Hide() end
end
function M:Tick()
    if not self.coordinateFrame then
        local f=CreateFrame("Frame","ForeverSuiteCoordinates",UIParent,"BackdropTemplate"); self.coordinateFrame=f; FS.HUD:Skin(f); f:SetSize(150,25)
        if Minimap then f:SetPoint("TOP",Minimap,"BOTTOM",0,-4) else f:SetPoint("TOPRIGHT",-20,-180) end
        f.text=FS.HUD:Label(f,"",6,-5,138)
        f.text:ClearAllPoints(); f.text:SetPoint("TOPLEFT",f,"TOPLEFT",6,-3); f.text:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-6,3)
        f.text:SetJustifyH("CENTER"); f.text:SetJustifyV("MIDDLE")
        FS.Layout:Register("Coordinates",f,"Map Coordinates")
    end
    if Minimap and not InCombatLockdown() and not FS.db.layout.frames.Coordinates then
        self.coordinateFrame:SetScale(Minimap:GetEffectiveScale()/UIParent:GetEffectiveScale())
    end
    self.coordinateFrame:SetShown(self:Data().coordinates)
    local _,x,y=self:Position(); self.coordinateFrame.text:SetText(x and string.format("%.1f, %.1f",x*100,y*100) or "Coordinates unavailable")
    self:UpdatePins()
    if self.UpdateNavigation then self:UpdateNavigation() end
end
local base=M.SettingsChanged
function M:SettingsChanged() base(self); if self.coordinateFrame then self.coordinateFrame:SetShown(FS:IsModuleEnabled(self.name) and self:Data().coordinates) end; self:UpdatePins(); if self.UpdateNavigation then self:UpdateNavigation() end end
M.actions={{label="Save pin",run=function(self,text) self:SavePin(text) end},{label="Waypoint",run=function(self) self:Waypoint(self.selected) end},{label="Remove",run=function(self) if self.selected and self.selected.pin then table.remove(self:Data().pins,self.selected.pin); self.selected=nil; self:UpdatePins() end end}}
