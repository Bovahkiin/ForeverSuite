-- TEST: Recommended onboarding stages a four step start without changing an existing profile
ResetTest(); local FS=ForeverSuite; local I=FS.Installer
FS.db.layout.frames.Clock={x=40,y=350,scale=1.2}; FS.db.appearance.theme='Royal Aether'
I:Show(); I.window.recommended:Click()
assert(I.step==5 and I:StepIndex()==2 and I.draft.layout=='Layout 1' and I.draft.preset=='Standard text')
assert(FS.db.appearance.theme=='Royal Aether' and FS.db.layout.frames.Clock.x==40)
assert(I.window.next:GetText()=='Apply & finish')
I.window.previous:Click(); I.window.customize:Click(); assert(not I.quickStart and I.step==5)
I.window.next:Click(); assert(I.step==2 and I:StepIndex()==3)
I.window.next:Click(); assert(I.step==3 and I:StepIndex()==4 and I.window.next:GetText()=='Apply & finish')
I.window.previous:Click(); assert(I.step==2); I.window.previous:Click(); assert(I.step==5)
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
FS.Beginner.tourWindow.next:Click(); assert(FS.Beginner.tourStep==2)
FS.Beginner.tourWindow.next:Click(); assert(FS.Beginner.tourStep==3)
FS.Beginner.tourWindow.next:Click(); assert(FS.db.setup.tourCompleted and not FS.Beginner.tourWindow:IsShown())
FS.Beginner:ShowTour(); FS.window:Hide(); assert(not tour:IsShown() and not tour.highlight:IsShown())
FS.Beginner:ShowTour(); FS.Beginner.tourWindow.dismiss:Click(); assert(FS.db.setup.tourDismissed)
I:Show(); I.draft.layout='Keep current'; I.step=3; assert(I:Apply()); assert(not FS.Beginner.tourWindow:IsShown())

-- TEST: Every setup layout theme and text page previews the same neutral player target pet chat and quest layout
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show()
for _,step in ipairs({1,5,2,3}) do
 I.step=step; I:Refresh(); assert(I.window.layoutPreview:IsShown() and not I.window.design:IsShown())
 for _,id in ipairs({'Unit:player','Unit:target','Unit:pet','ChatFrame1','QuestTracker'}) do assert(I.window.layoutPreview.parts[id].frame:IsShown()) end
end
I.step=2; I:Refresh()
for index=1,10 do
 I.window.choices[index]:Click()
 assert(FS.Themes.frames[I.window.layoutPreview].parts[1].texture==FS.Themes:Asset(index,'Panel'))
 assert(FS.db.appearance.theme=='Legacy')
end
I.step=3; I:Refresh(); I.window.choices[4]:Click(); assert(I.window.layoutPreview.parts['Unit:player'].frame.label.font[2]==13)
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
 FS:ConfigureModule(name)
 local module=FS.modules[name]
 local panel=(name=='Bags' or name=='Vendor') and FS.window.settings or module.settings
 assert(panel and panel:IsShown() and panel:GetParent()==UIParent,name)
 assert(not FS.window:IsShown(),name)
 local back=panel.back or panel.fsForm and panel.fsForm.back
 assert(back,name); back:Click(); assert(FS.window:IsShown() and not panel:IsShown(),name)
end

-- TEST: Plain language search finds text sizing pet feeding lost arrows moving bags and exact options
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local B=FS.Beginner
for _,query in ipairs({'letters groter','pijl terug','pet voeren','tassen verplaatsen','show coordinates'}) do
 local rows=B:Find(query); assert(#rows>0,query); assert(type(rows[1].run)=='function')
end
FS.window.moduleSearch:SetText('letters groter'); FS.window.moduleSearch.scripts.OnTextChanged(FS.window.moduleSearch); FS.window.moduleSearch.scripts.OnEnterPressed(FS.window.moduleSearch)
assert(B.searchWindow:IsShown() and not FS.window:IsShown()); B.searchWindow.rows[1]:Click(); assert(FS.Typography.window:IsShown())
B:Search('show coordinates'); B.searchWindow.rows[1]:Click(); assert(FS.modules.Map.settings:IsShown())
assert(FS.modules.Map.settings:GetParent()==UIParent and not FS.window:IsShown())

-- TEST: Move Frames selects a handle and centers aligns or restores only that selected frame
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; FS:ShowConfig(); L:Start()
L:Select('Unit:pet'); assert(L.selected=='Unit:pet' and L.overlay.center:IsEnabled())
local playerBefore=FS.db.layout.frames['Unit:player']; assert(L:AlignSelected('center'))
assert(FS.db.layout.frames['Unit:pet'].x==0 and FS.db.layout.frames['Unit:player']==playerBefore)
assert(L:AlignSelected('below')); assert(FS.db.layout.frames['Unit:pet'].y<400)
assert(L:AlignSelected('restore') and FS.db.layout.frames['Unit:pet']==nil)
L:Select('Unit:player'); assert(not L:AlignSelected('below'))
assert(L:SaveChanges(false)); assert(FS.db.profiles.saved[FS.db.profiles.current].layout.frames['Unit:pet']==nil)
L:Stop()

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
for _,show in ipairs({function() B:ShowModule('Map') end,function() B:Search('pet voeren') end,function() B:ShowRecovery() end}) do
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
