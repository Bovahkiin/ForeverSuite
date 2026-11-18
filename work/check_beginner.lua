-- TEST: Unchanged quest tracker content updates distance without rebuilding text and geometry
ResetTest(); local FS=ForeverSuite; local Q,H=FS.modules.Quests,FS.HUD
Q.rows={{id=987,title='Collect supplies',complete=false,objectives={'0 / 5'},details={{text='0 / 5',have=0,need=5}},distance=80}}
Q:UpdateTracker(true)
local fit=H.FitButton; local calls=0
H.FitButton=function(self,...) calls=calls+1; return fit(self,...) end
for i=1,10 do Q:UpdateTracker(true) end
assert(calls==0)
Q.rows[1].distance=40; Q:UpdateTracker(true)
assert(Q.tracker.cards[1].distance:GetText()=='40y' and calls==0)
Q.rows[1].details[1].text='1 / 5'; Q.rows[1].details[1].have=1; Q:UpdateTracker(true)
assert(calls>0)
H.FitButton=fit

-- TEST: Every tool view has a compact summary and opens only its own relevant settings
ResetTest(); local FS=ForeverSuite; FS:ShowWorkspacePage('home')
local W,T=FS.modules.Workbench,FS.Tools
W.prepActivity=nil; W.journalInstance=nil
for _,view in ipairs(W.views) do
    W:Choose(view)
    local f=W.window; local help=assert(T.viewHelp[view],view)
    assert(f.heading:GetText()==view and f.summary:GetText()==help.summary,view)
    assert(f.inputLabel:IsShown()==f.input:IsShown(),view)
    if T.viewSettings[view] then
        assert(f.toolSettings:IsShown(),view)
        assert(W:ShowViewSettings(view),view)
        assert(FS.Beginner.toolSettings.title:GetText()==view..' settings',view)
        assert(not W.window:IsShown() and (not FS.Beginner.moduleWindow or not FS.Beginner.moduleWindow:IsShown()),view)
    else assert(not f.toolSettings:IsShown(),view) end
end

-- TEST: Empty tools offer a working next step and disable selection-only operations
ResetTest(); local FS=ForeverSuite; local W=FS.modules.Workbench
FS:ShowConfig(); FS.db.extras.runNotes={}; W:Choose('Run Notes')
local f=W.window
assert(f.emptyTitle:IsShown() and f.emptyTitle:GetText()=='No run notes yet')
assert(f.emptyAction:IsShown() and not f.actionButtons[2]:IsEnabled() and not f.actionButtons[3]:IsEnabled())
assert(not f.input:IsShown() and not f.previous:IsShown() and not f.next:IsShown() and f:GetHeight()<600)
f.emptyAction:Click(); assert(FS.Extensions.form:IsShown())
FS.Extensions.form.cancel:Click()
FS.db.extras.waypointQueue={}; FS.db.map.pins={}; W:Choose('Waypoint queue')
assert(f.emptyAction:GetText()=='Save a location pin' and not f.actionButtons[1]:IsEnabled())
f.emptyAction:Click()
assert(FS.modules.Map.window:IsShown() and not W.window:IsShown())
assert(FS.modules.Map.window.inputLabel:GetText()=='Pin name')

-- TEST: Tool shortcuts open view-specific preferences and filtering clears stale selections
ResetTest(); local FS=ForeverSuite; local W=FS.modules.Workbench
FS:ShowWorkspacePage('allTools')
for _,row in ipairs(FS.Workspace.rows) do
    if row:IsShown() and row.tool.id=='rares' then row.settings:Click(); break end
end
assert(FS.Beginner.toolSettings.title:GetText()=='Rare sightings settings')
assert(not FS.modules.Map.settings or not FS.modules.Map.settings:IsShown())
local before=FS.db.extras.discovery.enabled
FS.Beginner.toolSettings.rows[1]:Click()
assert(FS.db.extras.discovery.enabled~=before and FS.db.map.enabled)
local C=FS.modules.Cooldowns
C:ShowWindow(); C.window.input:SetText('123')
C.window.input.scripts.OnTextChanged(C.window.input)
assert(C.window.actionButtons[1]:IsEnabled())
C.window.actionButtons[1]:Click()
C.window.cells[1]:Click(); assert(C.selected and C.window.actionButtons[3]:IsEnabled())
C.window.search:SetText('no-such-spell'); C.window.search.scripts.OnTextChanged(C.window.search)
assert(not C.selected and not C.window.actionButtons[3]:IsEnabled())

-- TEST: Hidden native windows stay unskinned until shown and idle discovery skips their children
ResetTest(); local FS=ForeverSuite; local old=SpellBookFrame
local frame=CreateFrame('Frame','SpellBookFrame',UIParent); frame:Hide()
for i=1,40 do CreateFrame('Button',nil,frame) end
local before=#TEST.frames
FS.NativeWindows:Refresh()
assert(#TEST.frames==before and not FS.NativeWindows.windows[frame])
local visited=0; local children=frame.GetChildren
frame.GetChildren=function(...) visited=visited+1; return children(...) end
FS.Style:Discover(); FS.Style:Discover()
assert(visited==0 and not FS.Typography.events:GetScript('OnUpdate'))
frame:Show(); assert(FS.NativeWindows.windows[frame])
frame:Hide(); SpellBookFrame=old

-- TEST: Workspace separates opening tools from settings and saves directory pins per profile
ResetTest(); local FS=ForeverSuite; FS:ShowWorkspacePage('home')
local W,f,P=FS.Workspace,FS.window,FS.modules.Profiles
assert(f.author:GetText()=='Made by DeluxiZ' and f.title:GetText()=='Control Center')
assert(f.tabs.profiles:IsShown() and f.tabs.settings:IsShown() and f.tabs.modules:IsShown())
assert(W.rows[1].tool.id=='bags' and W.rows[1].open:GetText()=='Open Bags')
W.rows[1].open:Click(); assert(FS.modules.Bags.window:IsShown() and not f:IsShown())
FS:ShowConfig(); W.browse:Click(); assert(f.workspacePage=='allTools')
local function find(id)
    for _,row in ipairs(W.rows) do if row:IsShown() and row.tool.id==id then return row end end
end
local vendor=assert(find('vendor'))
assert(vendor.summary:GetText():find('junk',1,true) and vendor.pin:GetText()=='Pin')
vendor.pin:Click()
assert(vendor.pin:GetText()=='Unpin' and FS.db.profiles.saved.Default.window.pinnedTools.vendor)
W.back:Click(); assert(f.workspacePage=='home' and find('vendor'))
find('vendor').settings:Click(); assert(FS.Beginner.moduleWindow:IsShown() and not f:IsShown())
FS.Beginner.moduleWindow.back:Click(); assert(f.workspacePage=='home' and find('vendor'))
assert(P:Save('Alternate workspace')); find('vendor').pin:Click(); assert(not find('vendor'))
assert(P:Load('Default') and find('vendor'))
f.moduleSearch:SetText('waypoint'); f.moduleSearch.scripts.OnTextChanged(f.moduleSearch)
assert(f.workspacePage=='allTools' and find('waypoints') and not find('vendor'))
f.tabs.modules:Click(); FS:SetModuleEnabled('Bags',false)
assert(f.cards.Bags.toggle:IsShown() and f.cards.Bags.toggle:GetText()=='Disabled')
f.tabs.home:Click(); assert(find('bags') and not find('bags').open:IsEnabled())

-- TEST: The four-step wizard stages theme layout and play style until the review is applied
ResetTest(); local FS=ForeverSuite; local I=FS.Installer
FS.db.layout.frames.Clock={x=40,y=350,scale=1.2}; FS.db.appearance.theme='Royal Aether'
I:Show(); local f=I.window
assert(I.step==2 and I:StepIndex()==1)
f.choices[2]:Click(); f.next:Click()
assert(I.step==5 and I:StepIndex()==2)
f.choices[2]:Click(); f.next:Click()
assert(I.step==4 and I:StepIndex()==3)
f.choices[3]:Click(); f.next:Click()
assert(I.step==6 and I:StepIndex()==4 and f.next:GetText()=='Apply & finish')
local summary=f.description:GetText()
assert(summary:find('Theme: Dark',1,true) and summary:find('Layout: Standard',1,true) and summary:find('Profile: PvP',1,true))
assert(FS.db.appearance.theme=='Royal Aether' and FS.db.layout.frames.Clock.x==40 and FS:IsModuleEnabled('Quests'))
f.previous:Click(); assert(I.step==4); f.previous:Click(); assert(I.step==5); f.previous:Click(); assert(I.step==2)
f.recommended:Click(); assert(I.step==6 and I.draft.layout=='Layout 1' and I.draft.preference=='Casual')
I:Dismiss(); assert(not FS.db.setup.completed and FS.db.appearance.theme=='Royal Aether')

-- TEST: Finishing recommended setup applies profile and text then opens a dismissible three tip tour
ResetTest(); local FS=ForeverSuite; local I=FS.Installer
I:Show(); I:Recommended(); I.draft.nativeLayout=false; I:Refresh(); I.window.next:Click()
assert(FS.db.setup.completed and not I.window:IsShown() and FS.db.typography.global.size==14)
assert(FS.db.profiles.saved[FS.db.profiles.current].typography.global.size==14)
assert(FS.Beginner.tourWindow:IsShown() and FS.Beginner.tourStep==1)
local tour=FS.Beginner.tourWindow
assert(tour.frameStrata=='FULLSCREEN_DIALOG' and tour.highlight.frameStrata==tour.frameStrata)
assert(tour:GetFrameLevel()>tour.highlight:GetFrameLevel() and not FS.Themes.frames[tour.highlight])
assert(tour.point[1]=='TOP' and tour.point[2]==FS.window.moduleSearch and tour.highlight.point[2]==FS.window.moduleSearch)
FS.Beginner.tourWindow.next:Click(); assert(FS.Beginner.tourStep==2)
assert(tour.point[1]=='BOTTOM' and tour.point[2]==FS.window.move and tour.highlight.point[2]==FS.window.move)
FS.Beginner.tourWindow.next:Click(); assert(FS.Beginner.tourStep==3)
assert(tour.point[1]=='TOP' and tour.point[2]==FS.window.tabs.profiles and tour.highlight.point[2]==FS.window.tabs.profiles)
FS.Beginner.tourWindow.next:Click(); assert(FS.db.setup.tourCompleted and not FS.Beginner.tourWindow:IsShown())
FS.Beginner:ShowTour(); FS.window:Hide(); assert(not tour:IsShown() and not tour.highlight:IsShown())
FS.Beginner:ShowTour(); FS.Beginner.tourWindow.dismiss:Click(); assert(FS.db.setup.tourDismissed)
I:Show(); I.draft.layout='Keep current'; I.step=3; assert(I:Apply()); assert(not FS.Beginner.tourWindow:IsShown())

-- TEST: Every setup layout theme and text page previews the same neutral player target pet chat and quest layout
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show()
for _,step in ipairs({2,5,3,6}) do
 I.step=step; I:Refresh(); assert(I.window.layoutPreview:IsShown() and not I.window.design:IsShown())
 for _,id in ipairs({'Unit:player','Unit:target','Unit:pet','ChatFrame1','QuestTracker'}) do assert(I.window.layoutPreview.parts[id].frame:IsShown()) end
end
I.step=2; I:Refresh()
for index,choice in ipairs(I.themeChoices) do
 I.window.choices[index]:Click()
 assert(FS.Themes.frames[I.window.layoutPreview].parts[1].texture==FS.Themes:Asset(FS.Themes:Index(choice[2]),'Panel'))
 assert(FS.db.appearance.theme=='Legacy')
end
I.step=3; I:Refresh(); I.window.choices[4]:Click(); assert(I.window.layoutPreview.parts['Unit:player'].frame.label.font[2]==13 and not I.window.themeSample:IsShown())
I:Dismiss()

-- TEST: Module cards open independent basic screens with real options and automatic saving
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local B=FS.Beginner
FS.window.cards.GearAdvisor.card:Click()
assert(B.moduleWindow:IsShown() and B.moduleWindow:GetParent()==UIParent and not FS.window:IsShown())
assert(B.moduleWindow.description:GetText():find('better for your class',1,true))
local rows=B:Options('GearAdvisor'); local before=rows[1].ref[rows[1].key]
B.moduleWindow.rows[2]:Click(); assert(rows[1].ref[rows[1].key]~=before)
assert(FS.db.profiles.saved[FS.db.profiles.current].gearAdvisor.preset==FS.db.gearAdvisor.preset)
B.moduleWindow.rows[1]:Click(); assert(not FS:IsModuleEnabled('GearAdvisor') and B.moduleWindow.rows[1]:GetText()=='Module disabled')
B.moduleWindow.back:Click(); assert(FS.window:IsShown() and not B.moduleWindow:IsShown())

-- TEST: All dashboard modules have a beginner explanation and no more than four quick settings
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local B=FS.Beginner
for _,name in ipairs(FS.window.moduleOrder) do
 assert(B.help[name],name); assert(B:ShowModule(name)); assert(#B:Options(name)<=4)
 assert(B.moduleWindow:IsShown() and not FS.window:IsShown())
 assert(B.moduleWindow:GetHeight()*B.moduleWindow:GetScale()<=UIParent:GetHeight()-30)
 B.moduleWindow.back:Click()
end

-- TEST: More options and all custom forms are standalone screens with a working Control Center return
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local B=FS.Beginner
for _,name in ipairs(FS.window.moduleOrder) do
 assert(B:ShowModule(name))
 FindButton(B.moduleWindow,'More options'):Click()
 local module=FS.modules[name]
 local panel=(name=='Bags' or name=='Vendor') and FS.window.settings or module.settings
 assert(panel and panel:IsShown() and panel:GetParent()==UIParent,name)
 assert(not FS.window:IsShown() and not B.moduleWindow:IsShown() and FS.settingsScreen==panel,name)
 local back=panel.back or panel.fsForm and panel.fsForm.back
 assert(back,name); back:Click(); assert(FS.window:IsShown() and not panel:IsShown(),name)
end

-- TEST: Plain language search finds text sizing pet feeding lost arrows moving bags and exact options
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local B=FS.Beginner
for _,query in ipairs({'text size','restore waypoint','feed pet','move bags','show coordinates'}) do
 local rows=B:Find(query); assert(#rows>0,query); assert(type(rows[1].run)=='function')
end
FS.window.moduleSearch:SetText('text size'); FS.window.moduleSearch.scripts.OnTextChanged(FS.window.moduleSearch); FS.window.moduleSearch.scripts.OnEnterPressed(FS.window.moduleSearch)
assert(B.searchWindow:IsShown() and not FS.window:IsShown()); B.searchWindow.rows[1]:Click(); assert(FS.Typography.window:IsShown())
B:Search('show coordinates'); B.searchWindow.rows[1]:Click(); assert(FS.modules.Map.settings:IsShown())
assert(FS.modules.Map.settings:GetParent()==UIParent and not FS.window:IsShown())

-- TEST: Move Frames selects a handle and centers aligns or restores only that selected frame
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; FS:ShowConfig(); L:Start()
L:Select('Unit:pet'); assert(L.selected=='Unit:pet' and L.overlay.center:IsEnabled())
local playerBefore=L:Placements()['Unit:player']; assert(L:AlignSelected('center'))
assert(L:Placements()['Unit:pet'].x==0 and L:Placements()['Unit:player']==playerBefore)
assert(L:AlignSelected('below')); assert(L:Placements()['Unit:pet'].y<400)
assert(L:AlignSelected('restore') and L:Placements()['Unit:pet']==nil)
L:Select('Unit:player'); assert(not L:AlignSelected('below'))
assert(L:SaveChanges(false)); assert(FS.db.profiles.saved[FS.db.profiles.current].layout.frames['Unit:pet']==nil)
L:Stop()

-- TEST: Move Frames aligns to a chosen reference without moving it or saving the preview
ResetTest(); local FS=ForeverSuite; local L=FS.Layout
local function frame(id,x,y,w,scale)
    local f=CreateFrame('Frame',nil,UIParent); f:SetSize(w,40); f:SetScale(scale)
    f:SetPoint('CENTER',UIParent,'CENTER')
    f.GetCenter=function() return x/scale,y/scale end
    f.GetEffectiveScale=function(self) return self:GetScale()*UIParent:GetEffectiveScale() end
    L:Register(id,f,id)
    return f
end
local first=frame('AlignSelectedTest',400,250,120,1.2)
local second=frame('AlignReferenceTest',600,350,80,.8)
L:Start()
local selected=L.handles.AlignSelectedTest
local reference=L.handles.AlignReferenceTest
assert(not L.overlay.sameHeight:IsEnabled())
selected:GetScript('OnMouseDown')(selected,'LeftButton')
reference:GetScript('OnMouseDown')(reference,'RightButton')
assert(L.overlay.sameHeight:IsEnabled() and L.overlay.leftEdges:IsEnabled())
L.overlay.sameHeight:Click()
local pos=L:Placements().AlignSelectedTest
assert(math.abs(pos.y-350)<.01 and math.abs(pos.x-(400-UIParent:GetWidth()/2))<.01)
L.overlay.leftEdges:Click()
pos=L:Placements().AlignSelectedTest
assert(math.abs(pos.x-(640-UIParent:GetWidth()/2))<.01 and math.abs(pos.y-250)<.01)
assert(not L:Placements().AlignReferenceTest and not FS.db.layout.frames.AlignSelectedTest)
selected:GetScript('OnMouseDown')(selected,'RightButton')
assert(not L.overlay.sameHeight:IsEnabled() and not L:AlignSelected('left'))
L.overlay.close:Click()
assert(first:GetPoint()=='CENTER' and select(3,first:GetPoint())=='CENTER')
assert(select(3,second:GetPoint())=='CENTER' and not FS.db.layout.frames.AlignSelectedTest)
for _,id in ipairs({'AlignSelectedTest','AlignReferenceTest'}) do L.targets[id]=nil; L.handles[id]=nil end

-- TEST: Recovery constrains saved frames preserves unrelated settings and commits repaired positions
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner; FS:ShowConfig(); FS.Layout:Collect()
FS.db.layout.frames['Unit:player']={x=9000,y=9000,scale=1}
FS.db.typography.global.size=19; local preset=FS.db.appearance.theme
assert(FS:SettingAction(function() return B:Recover('visible') end))
assert(FS.db.layout.frames['Unit:player'].x<UIParent:GetWidth()/2)
assert(FS.db.layout.frames['Unit:player'].y<=UIParent:GetHeight())
assert(FS.db.typography.global.size==19 and FS.db.appearance.theme==preset)
assert(FS.db.profiles.saved[FS.db.profiles.current].layout.frames['Unit:player'].x==FS.db.layout.frames['Unit:player'].x)
assert(FS.Extensions:Undo()); assert(FS.db.layout.frames['Unit:player'].x==9000)

-- TEST: Recovery search respects external navigation choices and resumes suppressed ForeverSuite quests
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner; local M=FS.modules.Map
M.suppressedQuest=123; M.noNext=true; M.finishedQuest=456
assert(B:RestoreWaypoint()); assert(M.suppressedQuest==nil and M.noNext==nil and M.finishedQuest==nil)
local show=FS.Compatibility.Show; local chosen
FS.Compatibility.Show=function(self,category) chosen=category end
local data=FS.Compatibility:Data(); data.waypoints='RXPGuides'
assert(not B:RestoreWaypoint() and chosen=='waypoints')
FS.Compatibility.Show=show

-- TEST: Beginner actions guard combat and vendor work while large text keeps every screen inside the viewport
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner; FS:ShowConfig()
TEST.combat=true; assert(not B:ShowModule('Chat') and not B:Recover('visible') and not B:RestoreWaypoint()); TEST.combat=false
FS.modules.Vendor.busy=true; assert(not B:ShowRecovery()); FS.modules.Vendor.busy=false
local w,h=UIParent:GetWidth(),UIParent:GetHeight(); UIParent:SetSize(800,600)
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply()
for _,show in ipairs({function() B:ShowModule('Map') end,function() B:Search('feed pet') end,function() B:ShowRecovery() end}) do
 show()
 local f=B.moduleWindow:IsShown() and B.moduleWindow or B.searchWindow:IsShown() and B.searchWindow or B.recoveryWindow
 assert(f:GetHeight()*f:GetScale()<=568 and f:GetWidth()*f:GetScale()<=768)
end
UIParent:SetSize(w,h)

-- TEST: Other addons explains the active provider and replaces the module settings screen
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner; local C=FS.Compatibility
C:Data().waypoints='ForeverSuite'; B:ShowModule('Map'); C:Show('waypoints')
assert(C.window:IsShown() and not B.moduleWindow:IsShown() and not FS.window:IsShown())
assert(C.window.help:GetText():find('RestedXP',1,true) and C.window.rows[1]:GetText():find('saved choice',1,true))
C.window.later:Click(); assert(not C.window:IsShown() and FS.window:IsShown())

-- TEST: Onboarding PvP and custom selections apply only staged modules and standalone layouts keep the active theme
ResetTest(); local FS=ForeverSuite; local I=FS.Installer
I:Show(); local f=I.window; f.next:Click(); f.choices[3]:Click(); f.next:Click()
f.choices[3]:Click()
assert(I.draft.preference=='PvP' and I.draft.modules.Buffs and I.draft.modules.Cooldowns and I.draft.modules.Nameplates and not I.draft.modules.Quests)
assert(FS:IsModuleEnabled('Quests'))
f.choices[4]:Click(); f.choices[7]:Click()
assert(I.draft.preference=='Custom' and I.draft.modules.Quests)
f.choices[3]:Click(); f.next:Click(); I.draft.nativeLayout=false; f.next:Click()
assert(FS.db.setup.completed and FS.db.layout.preset=='Advanced' and not FS:IsModuleEnabled('Quests'))
local theme=FS.db.appearance.theme
I:ShowLayouts(); assert(I.layoutOnly and f.next:GetText()=='Apply layout')
f.choices[5]:Click(); f.next:Click(); assert(FS.db.layout.preset=='Questing' and FS.db.appearance.theme==theme and not FS:IsModuleEnabled('Quests'))

-- TEST: Module directory describes all paged modules and dashboard toggles the actual saved state
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner
FS:ShowConfig(); FS.window.included:Click()
local f=B.directoryWindow
assert(f:IsShown() and not FS.window:IsShown() and f.title:GetText()=="What's Included?")
assert(f.rows[1]:GetText():find('Bags & Stock  |  Enabled',1,true) and f.rows[1]:GetText():find('favorites',1,true))
f.rows[8]:Click()
assert(f.rows[1]:GetText():find('Map',1,true))
f.rows[1]:Click(); assert(B.moduleWindow:IsShown() and not f:IsShown())
FS:ShowConfig(); FS.window.modulesPage:Click()
f.rows[1]:Click(); assert(not FS:IsModuleEnabled('Bags') and f.rows[1]:GetText():find('Disabled',1,true))
assert(FS.db.profiles.saved[FS.db.profiles.current].bags.enabled==false)
f.rows[1]:Click(); assert(FS:IsModuleEnabled('Bags'))

-- TEST: Config search updates while typing and reset only changes confirmed module settings
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner; B:Search('')
local f=B.searchWindow
f.search:SetText('chat timestamp'); f.search.scripts.OnTextChanged(f.search,true)
assert(f.rows[1]:GetText():lower():find('timestamp',1,true))
FS.db.chat.timestamps=not FS.defaults.chat.timestamps
FS.db.actionBars.fade=50; FS.db.extras.guildNotes.friend='Keep this'; FS.db.chat.enabled=false
assert(B:ConfirmModuleReset('Chat')); B.moduleReset.rows[2]:Click(); assert(FS.db.chat.timestamps~=FS.defaults.chat.timestamps)
B:ConfirmModuleReset('Chat'); B.moduleReset.rows[1]:Click()
assert(FS.db.chat.timestamps==FS.defaults.chat.timestamps and FS.db.actionBars.fade==50 and not FS:IsModuleEnabled('Chat'))
assert(FS.db.extras.guildNotes.friend=='Keep this')
B:ShowModule('ActionBars')
local help=B.moduleWindow.rows[2]
help.scripts.OnEnter(help); assert(GameTooltip.lines[#GameTooltip.lines]:find('pointer',1,true))
help.scripts.OnLeave(help)
assert(B:ResetModule('ActionBars') and FS.db.actionBars.fade==100)

-- TEST: Character overview uses actual equipped item level and Forever profession skill lines
ResetTest(); local FS=ForeverSuite; local B=FS.Beginner
local old={GetAverageItemLevel,GetGuildInfo,GetProfessions,Enum,C_SkillInfo,C_TradeSkillUI}
GetAverageItemLevel=function() return 50,25.5 end
GetGuildInfo=function(unit) assert(unit=='player'); return 'Example Guild' end
GetProfessions=nil; Enum={Profession={Blacksmithing=1,FirstAid=0}}
C_TradeSkillUI={GetProfessionSkillLineID=function(id) return id==1 and 164 or 129 end}
C_SkillInfo={GetSkillLineInfoByID=function(id)
 if id==164 then return {name='Blacksmithing',rank=18,maxRank=75} end
 return {name='First Aid',rank=0,maxRank=75}
end}
FS:ShowConfig(); FS.window.characterOverview:Click()
local f=B.characterOverview
assert(f:IsShown() and not FS.window:IsShown())
assert(f.rows[3]:GetText()=='Gold: 100g 0s 0c')
assert(f.rows[4]:GetText()=='Professions: Blacksmithing 18/75')
assert(f.rows[5]:GetText()=='Equipped Item Level: 25.5' and f.rows[6]:GetText()=='Guild: Example Guild')
GetAverageItemLevel,GetGuildInfo,GetProfessions,Enum,C_SkillInfo,C_TradeSkillUI=unpack(old,1,6)

-- TEST: Minimap right-click lists six shortcuts and Layouts opens the expanded preset picker
ResetTest(); local FS=ForeverSuite; local old=MenuUtil; local menu,owner={},nil
MenuUtil={CreateContextMenu=function(source,build)
 owner=source
 build(source,{CreateButton=function(_,name,run) menu[#menu+1]={name,run} end})
end}
FS:CreateMinimapButton()
local b=FS.minimapButton
b.scripts.OnClick(b,'RightButton')
assert(owner==b and #menu==6)
assert(menu[1][1]=='Config' and menu[2][1]=='Profiles' and menu[3][1]=='Themes' and menu[4][1]=='Layouts' and menu[5][1]=='Modules' and menu[6][1]=='Reload UI')
menu[4][2](); assert(FS.Installer.layoutOnly and FS.LayoutPresets:Valid('Immersive'))
  FS.Installer:Dismiss(); menu[5][2](); assert(FS.window:IsShown() and FS.window.workspacePage=='modules')
local reloads=TEST.reloads or 0; menu[6][2](); assert(TEST.reloads==reloads+1)
MenuUtil=old

-- TEST: Action bar visibility is reversible and quick bind keeps native clicks and saves the selected key
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; local B=FS.modules.Bindings
local base=MainActionBar:GetAlpha(); local hovered=false
local oldMouse=MainActionBar.IsMouseOver
MainActionBar.IsMouseOver=function() return hovered end
FS.db.actionBars.fade=50; A:SettingsChanged()
assert(math.abs(MainActionBar:GetAlpha()-base*.5)<.001)
FS.db.actionBars.mouseover=true; A:UpdateVisibilityDriver(); assert(MainActionBar:GetAlpha()==0)
hovered=true; A:RefreshBarVisibility(); assert(MainActionBar:GetAlpha()==base)
hovered=false; TEST.combat=true; A:RefreshBarVisibility(); assert(MainActionBar:GetAlpha()==base); TEST.combat=false
local button=CreateFrame('Button','ActionButton12',MainActionBar); button:Show()
local clicks=0; button:SetScript('OnClick',function() clicks=clicks+1 end)
local old=ActionButton12; ActionButton12=button
A:SkinButton(button,true,MainActionBar)
local oldSet,oldSave,oldGet=SetBinding,SaveBindings,GetBindingKey
local binding,save; SetBinding=function(key,command) binding={key,command}; return true end
SaveBindings=function(set) save=set end; GetBindingKey=function(command) if binding and command==binding[2] then return binding[1] end end
assert(B:OpenQuickBindings() and MainActionBar:GetAlpha()==base)
local f=B.quick; f.buttons[button]:Click(); assert(B.capturing=='ACTIONBUTTON12' and clicks==0)
f.scripts.OnKeyDown(f,'F8'); assert(binding[1]=='F8' and binding[2]=='ACTIONBUTTON12' and save and not B.capturing)
assert(f.buttons[button].key:GetText()=='F8')
f.buttons[button]:Click(); f.scripts.OnKeyDown(f,'ESCAPE'); assert(not B.capturing and f:IsShown())
TEST.combat=true; A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED'); assert(not f:IsShown() and not B.capturing)
TEST.combat=false; FS.db.actionBars.mouseover=false; FS.db.actionBars.fade=100; A:UpdateVisibilityDriver()
assert(MainActionBar:GetAlpha()==base); button:Click(); assert(clicks==1)
f.buttons[button]:Hide(); A.buttons[button]=nil; f.buttons[button]=nil; button:Hide()
MainActionBar.IsMouseOver=oldMouse; ActionButton12=old; SetBinding,SaveBindings,GetBindingKey=oldSet,oldSave,oldGet

-- TEST: Gear Planner text help uses client-compatible hover frames and survives reopening
ResetTest(); local FS=ForeverSuite; FS.Extensions:Normalize()
local W,H=FS.modules.Workbench,FS.HUD
W:Choose('Gear Planner'); local f=W.window
assert(f.heading:GetText()=='Gear Planner' and f.actionButtons[1]:GetText()=='Item details')
assert(f.visibleRows~=nil and f:GetHeight()>=320)
assert(f.summary.HookScript==nil and f.summary.SetScript==nil)
local hover=assert(f.summary.fsHelpFrame)
assert(hover:GetParent()==f and hover.allPoints[1]==f.summary)
H:SetHelp(f.summary,'Updated planner help')
assert(f.summary.fsHelpFrame==hover)
hover.scripts.OnEnter(hover)
assert(GameTooltip.lines[#GameTooltip.lines]=='Updated planner help')
hover.scripts.OnLeave(hover); assert(not GameTooltip:IsShown())
f.summary:Hide(); assert(not hover:IsShown())
f.summary:Show(); assert(hover:IsShown())
f.summary:SetShown(false); assert(not hover:IsShown())
f.summary:SetShown(true); assert(hover:IsShown())
f:Hide(); assert(not hover:IsShown())
W:Choose('Gear Planner'); assert(hover:IsShown() and f.summary.fsHelpFrame==hover)
local button=f.close; H:SetHelp(button,'Close the planner')
assert(button.fsHelpFrame==nil and button.fsHelp=='Close the planner')

-- TEST: Route Library recovers from a failed planner and leaves focused route input stable
ResetTest(); local FS=ForeverSuite; local E,W=FS.Extensions,FS.modules.Workbench
E:Normalize(); W:Choose('Settings')
local f,G=W.window,FS.modules.GearAdvisor
local oldRows,oldLevel=G.PlannerRows,UnitLevel; UnitLevel=function() return 11 end
local attempts=0
G.PlannerRows=function() attempts=attempts+1; error('Simulated gear source failure') end
local oldSearch,oldInput=f.search.SetText,f.input.SetText
local function changed(field,set,text)
    set(field,text); local callback=field:GetScript('OnTextChanged'); if callback then callback(field,false) end
end
f.search.SetText=function(field,text) changed(field,oldSearch,text) end
f.input.SetText=function(field,text) changed(field,oldInput,text) end
assert(not pcall(function() W:Choose('Gear Planner') end) and attempts==1)
G:QueuePlannerRefresh(W); assert(G.plannerRefresh)
W:Choose('Route Library')
Drain(); assert(not G.plannerRefresh)
assert(attempts==1 and W:Data().view=='Route Library' and f.input:IsShown())
assert(f.heading:GetText()=='Route Library' and f.actionButtons[1]:GetText()=='Save queue')
G.PlannerRows=oldRows; UnitLevel=oldLevel
E:Data().waypointQueue={{map=12,x=.2,y=.3,name='Route stop'}}
W:Refresh()
local build=W.Build; local builds=0
W.Build=function(self) builds=builds+1; return build(self) end
f.input:SetFocus()
for _,name in ipairs({'D','Du','Durotar copper'}) do
    f.input:SetText(name)
    for i=1,20 do W.ticker(W.events,.1) end
    assert(f.input:IsShown() and f.input:HasFocus() and f.input:GetText()==name)
end
assert(builds==0 and f.actionButtons[1]:IsEnabled())
f.input:ClearFocus(); f.actionButtons[1]:Click()
assert(E:Data().routes['Durotar copper'][1].name=='Route stop')
assert(builds==1 and f.input:IsShown())
f:Hide(); assert(W.events:GetScript('OnUpdate')==nil)
W.Build=build; f.search.SetText=oldSearch; f.input.SetText=oldInput
