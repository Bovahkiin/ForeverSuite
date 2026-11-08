-- TEST: Minimap trail projects waypoints clips to rim rotates with minimap and animates
local FS,M,d=NavigationFixture(); local oldMap,oldMini,oldCVar=Minimap,C_Minimap,GetCVar
Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(200,200); Minimap:Show()
C_Minimap={GetViewRadius=function() return 100 end}; GetCVar=function() return '0' end
M:NavigationEvent('QUEST_ACCEPTED',11); M.trailPhase=0; M:UpdateTrail(0)
local dot=M.trailDots[1]; assert(dot:IsShown() and dot:GetParent()==Minimap and dot:GetWidth()==3 and dot.point[4]==12 and math.abs(dot.point[5])<.001)
for _,p in ipairs(M.trailDots) do if p:IsShown() then assert(math.sqrt(p.point[4]^2+p.point[5]^2)<=85.001) end end
M:UpdateTrail(.1); assert(math.abs(dot.point[4]-13.6)<.001)
GetCVar=function() return '1' end; d.facing=math.pi/2; M.trailPhase=0; M:UpdateTrail(0)
assert(math.abs(dot.point[4])<.001 and dot.point[5]<-11.9)
FS.db.map.trailSize=5; FS.db.map.trailSpacing=18; M:SettingsChanged(); assert(dot:GetWidth()==5 and #M.trailDots<=40)
d.x=.7; M:RenderNavigation(); for _,p in ipairs(M.trailDots) do assert(not p:IsShown()) end
d:restore(); Minimap,C_Minimap,GetCVar=oldMap,oldMini,oldCVar

-- TEST: Minimap trail clears unavailable data hidden minimap stop disable and validates profile settings
local FS,M,d=NavigationFixture(); local oldMap,oldMini,oldCVar=Minimap,C_Minimap,GetCVar
Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(200,200); Minimap:Show()
C_Minimap={GetViewRadius=function() return 100 end}; GetCVar=function() return '0' end
M:NavigationEvent('QUEST_ACCEPTED',11); local dot=M.trailDots[1]; assert(dot:IsShown())
Minimap:Hide(); M:UpdateTrail(.1); assert(not dot:IsShown()); Minimap:Show()
C_Minimap.GetViewRadius=function() return nil end; M:UpdateTrail(.1); assert(not dot:IsShown())
C_Minimap.GetViewRadius=function() return 100 end; M:UpdateTrail(.1); assert(dot:IsShown())
FS.db.map.trail=false; M:SettingsChanged(); assert(not dot:IsShown())
FS.db.map.trail=true; FS.db.map.trailSize=100; FS.db.map.trailColor='bad'; FS.db.map.trailOpacity=-1; M:SettingsChanged()
assert(FS.db.map.trailSize==3 and FS.db.map.trailColor=='Cyan' and FS.db.map.trailOpacity==.8)
local P=FS.modules.Profiles; FS.db.map.trailSpacing=14; assert(P:Save('Trail test')); assert(P:Save('Other trail')); FS.db.map.trailSpacing=6; assert(P:Load('Trail test')); assert(FS.db.map.trailSpacing==14)
M:ClearNavigation(); assert(not dot:IsShown()); M:NavigationEvent('QUEST_ACCEPTED',11); assert(dot:IsShown())
FS:SetModuleEnabled('Map',false); assert(not dot:IsShown())
d:restore(); Minimap,C_Minimap,GetCVar=oldMap,oldMini,oldCVar
