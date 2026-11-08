local _,FS=...
local Q,T=FS.modules.Quests,FS.Tools
Q.minimapPins={}; Q.worldPins={}
local function validPoint(x,y) return T:Number(x) and T:Number(y) and x>=0 and x<=1 and y>=0 and y<=1 end
function Q:QuestLocations(map)
    local result,seen={},{}
    local function add(row,x,y)
        if not row or not validPoint(x,y) or #result>=80 then return end
        local key=row.id..":"..string.format("%.4f:%.4f",x,y)
        if not seen[key] then result[#result+1]={row=row,map=map,x=x,y=y}; seen[key]=true end
    end
    local pois=T:Call(C_QuestLog and C_QuestLog.GetQuestsOnMap,map)
    if type(pois)=="table" then for _,poi in ipairs(pois) do
        if type(poi)=="table" and T:Number(poi.questID) then add(self.byID[poi.questID],poi.x,poi.y) end
    end end
    for _,row in ipairs(self.rows) do
        if row.id then
            local questMap,x,y=T:Call(C_QuestLog and C_QuestLog.GetNextWaypoint,row.id)
            if questMap==map then add(row,x,y) end
        end
    end
    return result
end
function Q:OpenQuestMap(row)
    if not row or not row.id or InCombatLockdown() then return end
    self:Track(row)
    if QuestMapFrame_OpenToQuestDetails then self:OnSelect(row)
    else
        local map=T:Call(C_QuestLog and C_QuestLog.GetNextWaypoint,row.id)
        if T:Number(map) and OpenWorldMap then T:Call(OpenWorldMap,map)
        else self:OnSelect(row) end
    end
end
function Q:MapSize(map)
    local width,height=T:Call(C_Map and C_Map.GetMapWorldSize,map)
    if not T:Number(width) or not T:Number(height) or width<=0 or height<=0 then
        if not CreateVector2D then return end
        local instance,a=T:Call(C_Map and C_Map.GetWorldPosFromMapPos,map,CreateVector2D(0,0))
        local other,b=T:Call(C_Map and C_Map.GetWorldPosFromMapPos,map,CreateVector2D(.5,.5))
        if not a or not b or instance~=other then return end
        local north,west=T:Call(a.GetXY,a); local south,east=T:Call(b.GetXY,b)
        if not T:Number(north) or not T:Number(west) or not T:Number(south) or not T:Number(east) then return end
        width,height=(west-east)*2,(north-south)*2
    end
    if width>0 and height>0 then return width,height end
end
function Q:PinIcon(row)
    if row.complete then return "Reputation" end
    local kind=row.details[1] and row.details[1].kind
    return kind=="monster" and "Enemy" or kind=="item" and "Equipment" or "Quests"
end
function Q:Pin(pool,index,parent)
    local f=pool[index]
    if not f then
        f=CreateFrame("Button",nil,parent); f:SetSize(22,22); f:SetFrameLevel(parent:GetFrameLevel()+8)
        f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetAllPoints()
        f.count=FS.HUD:Label(f,"",12,-12,15); FS:ApplyFont(f.count,10,"OUTLINE")
        f:SetScript("OnClick",function(b)
            if b.members and #b.members>0 then
                b.clickIndex=(b.clickIndex or 0)%#b.members+1; self:OpenQuestMap(b.members[b.clickIndex].row)
            end
        end)
        f:SetScript("OnEnter",function(b)
            local p=b.location; if not p then return end
            GameTooltip:SetOwner(b,"ANCHOR_LEFT"); GameTooltip:AddLine(p.row.title,1,.8,.3)
            for _,line in ipairs(p.row.objectives) do GameTooltip:AddLine(line,1,1,1,true) end
            if b.members and #b.members>1 then
                for i=2,#b.members do GameTooltip:AddLine(b.members[i].row.title,1,.8,.3) end
                GameTooltip:AddLine("Click again to cycle quests at this location.",.7,.8,.9,true)
            end
            GameTooltip:AddLine(p.row.complete and "Turn-in location" or "Objective area",.3,.8,1)
            GameTooltip:AddLine(b.onEdge and "Beyond minimap range. Click for the map." or "Click to focus and open the quest map.",.7,.8,.9,true); GameTooltip:Show()
        end)
        f:SetScript("OnLeave",function() GameTooltip:Hide() end); pool[index]=f
    end
    return f
end
function Q:Cluster(locations,project)
    local clusters={}
    for _,location in ipairs(locations) do
        local x,y,edge=project(location); local group
        for _,candidate in ipairs(clusters) do
            if (candidate.x-x)^2+(candidate.y-y)^2<22^2 then group=candidate; break end
        end
        if group then
            local duplicate=false
            for _,member in ipairs(group.members) do if member.row.id==location.row.id then duplicate=true; break end end
            if not duplicate then group.members[#group.members+1]=location end
        else clusters[#clusters+1]={x=x,y=y,edge=edge,members={location}} end
    end
    return clusters
end
function Q:RenderPins(pool,parent,clusters,anchor)
    for i,group in ipairs(clusters) do
        local f=self:Pin(pool,i,parent); f.members=group.members; f.location=group.members[1]; f.onEdge=group.edge
        f.count:SetText(#group.members>1 and #group.members or ""); FS:SetMenuIcon(f.icon,self:PinIcon(f.location.row))
        f:ClearAllPoints(); f:SetPoint("CENTER",parent,anchor,group.x,group.y); f:Show()
    end
end
function Q:MinimapOffset(p,px,py,width,height,radius,facing)
    local east,north=(p.x-px)*width,(py-p.y)*height
    if facing then
        local cosine,sine=math.cos(facing),math.sin(facing)
        east,north=east*cosine+north*sine,north*cosine-east*sine
    end
    local x,y=east/radius,north/radius
    local length=math.sqrt(x*x+y*y); local onEdge=length>.85
    if onEdge then x,y=x*.85/length,y*.85/length end
    return x*Minimap:GetWidth()/2,y*Minimap:GetHeight()/2,onEdge
end
function Q:UpdateQuestPins()
    for _,pool in ipairs({self.minimapPins,self.worldPins}) do for _,f in ipairs(pool) do f:Hide(); f.location=nil end end
    if not FS:IsModuleEnabled(self.name) then return end
    local db=self:Data(); local map,px,py=FS.modules.Map:Position()
    local world=WorldMapFrame; local canvas=world and world.ScrollContainer and world.ScrollContainer.Child
    local worldMap=canvas and T:Call(world.GetMapID,world)
    if db.worldMap and T:Number(worldMap) and world:IsShown() then
        self:RenderPins(self.worldPins,canvas,self:Cluster(self:QuestLocations(worldMap),function(p) return p.x*canvas:GetWidth(),-p.y*canvas:GetHeight(),false end),"TOPLEFT")
    end
    if not db.minimap or not map or not Minimap or not Minimap:IsShown() then return end
    local radius=T:Call(C_Minimap and C_Minimap.GetViewRadius)
    local width,height=self:MapSize(map)
    if not width or not T:Number(radius) or radius<=0 then return end
    local rotate=T:Call(GetCVar,"rotateMinimap")=="1"; local facing=rotate and T:Call(GetPlayerFacing) or nil
    if rotate and not T:Number(facing) then return end
    self:RenderPins(self.minimapPins,Minimap,self:Cluster(self:QuestLocations(map),function(p) return self:MinimapOffset(p,px,py,width,height,radius,facing) end),"CENTER")
end
