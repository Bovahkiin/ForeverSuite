local _,FS=...
local T=FS.Tools
local M=T:Module("Map","map","Map","Coordinates, saved location pins, explored regions and dungeon or raid lockouts. Save a pin at your current location.",{coordinates=true,pins={}},{"ZONE_CHANGED_NEW_AREA","MAP_EXPLORATION_UPDATED","UPDATE_INSTANCE_INFO","PLAYER_ENTERING_WORLD"})
M.options={{key="coordinates",label="Show coordinates"}}; M.pinFrames={}
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
function M:UpdatePins()
    local world=WorldMapFrame; local canvas=world and world.ScrollContainer and world.ScrollContainer.Child
    if not canvas then return end
    local id=T:Call(world.GetMapID,world)
    for _,f in ipairs(self.pinFrames) do f:Hide() end
    if not FS:IsModuleEnabled(self.name) then return end
    local count=0
    for i,p in ipairs(self:Data().pins) do
        if p.map==id then
            count=count+1; local f=self.pinFrames[count]
            if not f then
                f=FS.HUD:Button(canvas,"+",0,0,20,function() self:Waypoint({pin=self.pinFrames[count].pin}) end)
                f:SetScript("OnClick",function(b) self:Waypoint({pin=b.pin}) end)
                f:SetScript("OnEnter",function(b) local pin=self:Data().pins[b.pin]; if pin then GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine(pin.name); GameTooltip:Show() end end)
                f:SetScript("OnLeave",function() GameTooltip:Hide() end); f:SetSize(20,20); self.pinFrames[count]=f
            end
            f.pin=i; f:ClearAllPoints(); f:SetPoint("CENTER",canvas,"TOPLEFT",p.x*canvas:GetWidth(),-p.y*canvas:GetHeight()); f:Show()
        end
    end
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
