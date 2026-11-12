-- TEST: Action bar decorations are separate from every native layout child and region list
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
A:SettingsChanged(); FS.Style:Bars()
local bar=MainActionBar
for _,child in ipairs({bar:GetChildren()}) do assert(not child.fsActionDecoration and not child.fsSuiteStyle) end
for _,button in ipairs(bar.actionButtons) do
    for _,child in ipairs({button:GetChildren()}) do assert(not child.fsActionDecoration and not child.fsSuiteStyle) end
    for _,region in ipairs({button:GetRegions()}) do assert(not region.fsSuiteStyle) end
    local state=A.buttons[button]
    assert(state.border:GetParent()==UIParent and state.slot:GetParent()==UIParent)
    assert(not state.border.fsHUDBackdrop and not state.slot.fsHUDBackdrop)
end
assert(FS.Style.plates[bar]:GetParent()==UIParent and not FS.Style.plates[bar].fsHUDBackdrop)

-- TEST: Theme corners skip secret native geometry without arithmetic or replacing prior corner sizes
ResetTest(); local FS=ForeverSuite; local f=CreateFrame('Frame',nil,UIParent)
local token={}; local previous=issecretvalue
issecretvalue=function(value) return value==token end
f.GetWidth=function() return token end
local state={kind='Button',corner=9,parts={}}
FS.Themes:Size(f,state); assert(state.corner==9)
issecretvalue=previous

-- TEST: Detached action art follows visibility and alpha in combat without touching native frames
ResetTest(); local A=ForeverSuite.modules.ActionBars; local b=MainActionBar.actionButtons[1]
A:SettingsChanged(); local state=A.buttons[b]
local show,hide,alpha=b.Show,b.Hide,b.SetAlpha
b.Show=function() error('Decoration driver changed native visibility') end
b.Hide=function() error('Decoration driver changed native visibility') end
b.SetAlpha=function() error('Decoration driver changed native alpha') end
TEST.combat=true; hide(b); A:SyncDecorations()
assert(not state.border:IsShown() and state.slot:IsShown())
show(b); alpha(b,.4); A:SyncDecorations(); assert(state.border:IsShown() and state.border:GetAlpha()==.4)
local want=state.slot:IsShown(); A.decorationDriver.scripts.OnUpdate(A.decorationDriver,.1); assert(state.slot:IsShown()==want)
TEST.combat=false; b.Show,b.Hide,b.SetAlpha=show,hide,alpha; alpha(b,1); A:SyncDecorations()

-- TEST: Native action skins never add feedback hooks to hover leave or post-click scripts
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
local b=CreateFrame('CheckButton',nil,UIParent); b.icon=b:CreateTexture(); b:SetSize(36,36)
local calls=0
b:SetScript('OnEnter',function() calls=calls+1 end)
b:SetScript('OnLeave',function() calls=calls+1 end)
b:SetScript('PostClick',function() calls=calls+1 end)
local enter,leave,post=b:GetScript('OnEnter'),b:GetScript('OnLeave'),b:GetScript('PostClick')
A:SkinButton(b,true); FS.Style:Feedback(b); FS.Style:Feedback(b)
assert(b:GetScript('OnEnter')==enter and b:GetScript('OnLeave')==leave and b:GetScript('PostClick')==post)
assert(not b.fsSuiteFeedback and A.buttons[b].border:IsShown())
TEST.combat=true; enter(b); leave(b); post(b); TEST.combat=false; assert(calls==3)

-- TEST: Protected native controls are excluded from feedback while suite buttons retain it
ResetTest(); local S=ForeverSuite.Style
local protected=CreateFrame('Button',nil,UIParent); protected.IsProtected=function() return true end
local count=#TEST.frames; S:Feedback(protected)
assert(#TEST.frames==count and not protected.fsSuiteFeedback and not protected:GetScript('OnEnter'))
local own=CreateFrame('Button',nil,UIParent); S:Feedback(own)
assert(own.fsSuiteFeedback and own:GetScript('OnEnter') and own:GetScript('PostClick'))

-- TEST: World map overlay close art does not create extra close glyphs while native actions and canvas remain intact
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=WorldMapFrame
local f=CreateFrame('Frame','WorldMapFrame',UIParent); WorldMapFrame=f
f.BorderFrame=CreateFrame('Frame',nil,f); f.BorderFrame.CloseButton=CreateFrame('Button',nil,f.BorderFrame)
f.BorderFrame.CloseButton:SetScript('OnClick',function() TEST.mapClose=true end)
f.NavBar=CreateFrame('Frame',nil,f); f.NavBar.CloseButton=CreateFrame('Button',nil,f.NavBar)
local helper=f.NavBar.CloseButton; helper.normalRegion=helper:CreateTexture(); helper.normalRegion:SetTexture('close-helper'); helper:SetScript('OnClick',function() TEST.mapHelper=true end)
f.SidePanelToggle=CreateFrame('Button',nil,f); f.SidePanelToggle.normalRegion=f.SidePanelToggle:CreateTexture(); f.SidePanelToggle.normalRegion:SetTexture('close-panel'); f.SidePanelToggle:SetScript('OnClick',function() TEST.mapPanel=true end)
f.ScrollContainer=CreateFrame('ScrollFrame',nil,f); local tile=f.ScrollContainer:CreateTexture(); tile:SetTexture('map-tile')
N:Refresh(); assert(N.controls[f.BorderFrame.CloseButton].glyph:GetText()=='X')
assert(N.controls[helper].glyph:GetText()=='<' and N.controls[helper].plate:IsShown() and helper.normalRegion:GetAlpha()==0)
assert((N.controls[f.SidePanelToggle].glyph:GetText()=='<' or N.controls[f.SidePanelToggle].glyph:GetText()=='>') and tile:GetAlpha()==1)
helper:Click(); f.SidePanelToggle:Click(); f.BorderFrame.CloseButton:Click(); assert(TEST.mapHelper and TEST.mapPanel and TEST.mapClose)
FS:SetModuleEnabled('Map',false); N:Refresh(); assert(f.SidePanelToggle.normalRegion:GetAlpha()==1 and not N.controls[f.SidePanelToggle].glyph:IsShown())
f:Hide(); WorldMapFrame=old; FS:SetModuleEnabled('Map',true)

-- TEST: Achievement header remains inside window and category art summary borders restore without changing progress
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=AchievementFrame
local f=CreateFrame('Frame','AchievementFrame',UIParent); AchievementFrame=f; f:SetSize(800,500)
f.Header=CreateFrame('Frame',nil,f); f.Header:SetSize(300,80); f.Header:SetPoint('TOP',f,'TOP',0,20)
f.Header.Title=f.Header:CreateFontString(); f.Header.Title:SetText('Account Achievement Points'); f.Header.Title:SetPoint('TOP',0,10)
f.Header.Points=f.Header:CreateFontString(); f.Header.Points:SetText('123'); f.Header.Points:SetPoint('TOP',0,-15)
f.Header.Shield=f.Header:CreateTexture(); f.Header.Shield:SetTexture('achievement-shield')
f.Categories=CreateFrame('Frame',nil,f); f.Categories.BG=f.Categories:CreateTexture(); f.Categories.BG:SetTexture('parchment'); f.Categories.BG:SetAlpha(.7)
local bar=CreateFrame('StatusBar',nil,f); bar:SetStatusBarTexture('native-fill'); bar:SetValue(37)
local left=bar:CreateTexture('AchievementFrameSummaryCategoriesCategory1Left','OVERLAY'); left:SetTexture('border-left')
local count=bar:CreateFontString(); count:SetText('37/111')
N:Refresh(); assert(f.Header.point[5]==-2 and f.Header:GetHeight()==28 and f.Header.Title.point[1]=='CENTER' and f.Header.Points.point[1]=='RIGHT')
assert(f.Categories.BG:GetAlpha()==0 and left:GetAlpha()==0 and f.Header.Shield:GetAlpha()==1 and bar.value==37 and count:GetText()=='37/111')
FS:SetModuleEnabled('ActionBars',false); N:Refresh(); assert(f.Header.point[5]==20 and f.Header:GetHeight()==80 and f.Header.Title.point[3]==10)
assert(f.Categories.BG:GetAlpha()==.7 and left:GetAlpha()==1 and bar.barTexture=='native-fill')
f:Hide(); AchievementFrame=old; FS:SetModuleEnabled('ActionBars',true)

-- TEST: Map settings paginate all options inside panel with separate navigation hint and open controls
ResetTest(); local FS=ForeverSuite; local M=FS.modules.Map; FS:ConfigureModule('Map'); local f=M.settings
assert(f.optionPages==2 and f.optionsPage==1 and not f.previousOptions:IsEnabled() and f.nextOptions:IsEnabled())
assert(f.navFont:IsShown() and not f.arrival:IsShown() and not f.trail:IsShown())
for _,o in ipairs(M.options) do local b=f[o.key]; if b:IsShown() then assert(-b.point[3]+b:GetHeight()<318) end end
f.nextOptions:Click(); assert(f.optionsPage==2 and not f.navFont:IsShown() and f.arrival:IsShown() and f.trailOpacity:IsShown() and not f.nextOptions:IsEnabled())
local before=FS.db.map.trail; f.trail:Click(); assert(FS.db.map.trail~=before and f.optionsPage==2)
for _,o in ipairs(M.options) do local b=f[o.key]; if b:IsShown() then assert(-b.point[3]+b:GetHeight()<318) end end
assert(-f.open.point[3]+f.open:GetHeight()<=f:GetHeight())
f.previousOptions:Click(); assert(f.optionsPage==1 and f.coordinates:IsShown() and not f.trailOpacity:IsShown())
f:Hide()

-- TEST: Control Center typography reflows cards profile controls navigation and footer without cumulative growth
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; local F=FS.Typography
local original=f:GetHeight(); local originalContent=f.bodyContent:GetHeight(); local profileHeight=f.profiles:GetHeight()
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.db.typography.global.weight='Bold'; F:Apply()
assert(f.cards.Bags.heading.font[2]==36 and f.bodyContent:GetHeight()>originalContent and f.profiles:GetHeight()>profileHeight)
for _,c in pairs(f.cards) do
 assert(c.bodyEnd+10+c.toggle:GetHeight()<=c.card:GetHeight()-10)
 assert(not c.hint:IsShown() and c.toggle:GetWidth()<=220 and c.toggle.fsLabel:GetWidth()<c.toggle:GetWidth())
 local row=math.floor(c.position/2); if row>0 then assert(-c.card.point[3]>c.card:GetHeight()*row) end
end
local p=f.profiles
assert(-p.current.point[3]+p.current:GetHeight() < -p.name.point[3])
for _,b in ipairs({p.name,p.save,p.choice,p.use}) do assert(-b.point[3]+b:GetHeight()<=p:GetHeight()-10) end
assert(f.reset:GetHeight()>36 and f.previousModules:GetHeight()>36 and -f.typography.point[3]+f.typography:GetHeight()<f.bodyContent:GetHeight())
local height=f:GetHeight(); FS:RefreshConfig(); F:Apply(); assert(f:GetHeight()==height)
FS.db.layout.frames.ControlCenter={x=0,y=0,scale=1.2}; f:SetScale(1.2); FS:LayoutConfigText(); assert(f:GetScale()==1.2)
FS.db.layout.frames.ControlCenter=nil; FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.db.typography.global.weight='Default'; F:Apply(); assert(f:GetHeight()==original and p:GetHeight()==profileHeight)
f:Hide()

-- TEST: Large typography keeps generic settings tool lists and font editor controls separated and resets cleanly
ResetTest(); local FS=ForeverSuite; local F=FS.Typography; FS:ConfigureModule('Map'); local M=FS.modules.Map; local f=M.settings
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; F:Apply()
for _,o in ipairs(M.options) do local b=f[o.key]; if b:IsShown() then assert(-b.point[3]+b:GetHeight() < -f.previousOptions.point[3]) end end
assert(-f.hint.point[3]+f.hint:GetHeight() < -f.open.point[3] and -f.open.point[3]+f.open:GetHeight()<=f:GetHeight())
local height=f:GetHeight(); F:Apply(); assert(height==f:GetHeight()); f.nextOptions:Click(); assert(f.trailOpacity:IsShown())
F.scope='All modules'; F:Show(); local editor=F.window
assert(-editor.optionButtons.shadow.point[3]+editor.optionButtons.shadow:GetHeight() < -editor.preview.point[3])
assert(-editor.status.point[3]+editor.status:GetHeight() < -editor.close.point[3] and -editor.close.point[3]+editor.close:GetHeight()<editor:GetHeight())
local L=FS.modules.Loot; local list=L:CreateWindow(); list:Show(); L.rows={{text=string.rep('Long loot title ',6),id=1}}; L:Render()
for i=2,9 do assert(-list.cells[i].point[3]>=-list.cells[i-1].point[3]+list.cells[i-1]:GetHeight()) end
assert(-list.cells[9].point[3]+list.cells[9]:GetHeight() < -list.previous.point[3])
assert(-list.input.point[3]+list.input:GetHeight()<list:GetHeight())
FS.db.typography.global.size=0; FS.db.typography.global.scale=1; F:Apply(); assert(f:GetHeight()<height)
list:Hide(); editor:Hide(); f:Hide()

-- TEST: Quest tracker grows for large fonts and long objectives while preserving folding and pagination
ResetTest(); local FS=ForeverSuite; local Q=FS.modules.Quests; local build=Q.Build
Q.Build=function(self) self.rows={{id=999,index=1,title='A long quest title to read',details={{text=string.rep('Long objective ',9),done=false}},objectives={}}} end
FS.db.typography.modules.Quests={size=24,scale=1.5}; FS.Typography:Apply(); Q:UpdateTracker(); FS.Typography:Apply()
local f=Q.tracker; local c=f.cards[1]; assert(f:GetWidth()>300 and c.lines[1]:GetHeight()>36)
assert(-c.heading.point[3]+c.heading:GetHeight() < -c.lines[1].point[3])
assert(-c.lines[1].point[3]+c.lines[1]:GetHeight() < c:GetHeight()-8)
assert(c.map:GetWidth()>36 and c.map:GetHeight()>36 and c.distance:GetWidth()>38)
local height=c:GetHeight(); local fullHeight=f:GetHeight(); Q:UpdateTracker(); assert(f:GetHeight()==fullHeight)
c.fold:Click(); assert(c:GetHeight()<height and not c.lines[1]:IsShown()); c.fold:Click(); assert(c:GetHeight()==height)
FS.db.typography.modules.Quests=nil; FS.Typography:Apply(); assert(f:GetWidth()<792 and c:GetHeight()<height)
Q.Build=build; Q:UpdateTracker()

-- TEST: Inventory large typography separates toolbar sidebar counts and item pages without changing saved size
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags
TEST.data[1]={quality=1,price=1,classID=2}; AddItem(1,1,1); B:ShowWindow(); local f=B.window
FS.db.typography.modules.Bags={size=24,scale=1.5}; FS.Typography:Apply()
local metrics=B.textLayout; assert(metrics.large and metrics.contentX>212)
assert(f.organize:GetWidth()>78 and f.sidebarRows[1].count:GetWidth()>23)
assert(-f.more.point[3] >= -f.back.point[3]+f.back:GetHeight())
for _,c in ipairs(f.sidebarRows) do if c:IsShown() then assert(c.caption:GetWidth()+34 < c.count.point[2]) end end
for _,page in ipairs(B:Layout(B.view)) do for _,entry in ipairs(page.cells) do assert(metrics.contentTop+entry.y+38<=f:GetHeight()-metrics.footerReserve) end end
local savedHeight=FS.db.bags.height; local h=f:GetHeight(); FS.Typography:Apply(); assert(f:GetHeight()==h and FS.db.bags.height==savedHeight)
FS.db.typography.modules.Bags=nil; FS.Typography:Apply(); assert(f.organize:GetWidth()==78 and B.textLayout.contentX==212); f:Hide()

-- TEST: Character typography gives tab labels space and pages stats inside panel while disable restores size
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character; C:Apply()
FS.db.typography.modules.Character={size=24,scale=1.5}; FS.Typography:Apply(); C:RefreshCharacter()
assert(C.rowsPerPage<9 and C.side:GetWidth()>308 and C.tabs[4]:GetText()=='PvP')
for _,b in ipairs(C.sideTabs) do assert(b.fsLabel:GetHeight()+28<=b:GetHeight()) end
for i,b in ipairs(C.rows) do if b:IsShown() then assert(-b.point[3]+b:GetHeight()<352 and i<=C.rowsPerPage) end end
FS.db.typography.modules.Character=nil; FS.Typography:Apply(); assert(C.side:GetWidth()==308 and C.rowsPerPage==9,tostring(C.side:GetWidth())..'/'..tostring(C.rowsPerPage))
FS:SetModuleEnabled('Character',false); local w=CharacterFrame:GetWidth(); FS.Typography:Apply(); assert(CharacterFrame:GetWidth()==w); FS:SetModuleEnabled('Character',true)

-- TEST: Native map text fits breadcrumb and search counter stay separate with geometry restoration
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local oldMap,oldQuest=WorldMapFrame,QuestMapFrame
local map=CreateFrame('Frame','WorldMapFrame',UIParent); WorldMapFrame=map
map.NavBar=CreateFrame('Frame',nil,map); local nav=CreateFrame('Button',nil,map.NavBar); nav:SetWidth(75)
local label=nav:CreateFontString(); label:SetFont(FS.font,36,''); label:SetText('World')
local q=CreateFrame('Frame','QuestMapFrame',map); QuestMapFrame=q; q:SetWidth(340)
q.SearchBox=CreateFrame('EditBox','QuestMapFrameSearchBox',q); q.SearchBox:SetSize(240,30); q.SearchBox:SetPoint('TOPLEFT',0,-5); q.SearchBox:SetFont(FS.font,36,'')
local count=q:CreateFontString(); count:SetFont(FS.font,36,''); count:SetText('Quests: 3/40'); count:SetPoint('TOPRIGHT',-10,-5)
N:MapText(map,true); assert(label.font[2]<36 and q.SearchBox:GetWidth()+54+count:GetWidth()<=q:GetWidth()+1)
assert(q.SearchBox.font[2]<=22)
N:MapText(map,false); assert(q.SearchBox:GetWidth()==240 and count.point[2]==-10)
map:Hide(); WorldMapFrame,QuestMapFrame=oldMap,oldQuest

-- TEST: Every Control Center settings page uses its card color and custom forms share two responsive columns
ResetTest(); local FS=ForeverSuite
for name,module in pairs(FS.modules) do if name~='Profiles' then
 FS:ConfigureModule(name); local f=(name=='Bags' or name=='Vendor') and FS.window.settings or module.settings
 assert(f and f.fsSettingsName==name)
 local c=FS.moduleCardColors[name]; assert(f.border[1]==c[1] and f.border[2]==c[2] and f.border[3]==c[3])
 if f.fsForm then for _,item in ipairs(f.fsForm.items) do if item.control:IsShown() then assert(item.control:GetWidth()==410 and (item.control.point[2]==20 or item.control.point[2]==450)) end end end
end end
FS:ConfigureModule('Gear'); local G=FS.modules.Gear; local f=G.settings; local before=FS.db.gear.warn
f.warn:Click(); assert(FS.db.gear.warn~=before); FS:ThemeSettings(f,'Gear')
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply()
for _,item in ipairs(f.fsForm.items) do if item.control:IsShown() then assert(-item.control.point[3]+item.control:GetHeight()<f:GetHeight()) end end
local h=f:GetHeight(); FS:ThemeSettings(f,'Gear'); assert(f:GetHeight()==h)
FS:ConfigureModule('Vendor'); local v=FS.window.settings; v.more:Click(); FS:ThemeSettings(v,'Vendor'); assert(v.advanced and v.fields.repairLimit:IsShown())
for _,item in ipairs(v.fsForm.items) do if item.control==v.fields.repairLimit then assert(item.explanation==v.fieldLabels.repairLimit) end end
v.fields.repairLimit:SetText('7'); v.save:Click(); assert(FS.db.vendor.repairLimit==70000)
FS:ThemeSettings(v,'Vendor'); assert(v.fields.repairLimit:GetText()=='7')
FS:ConfigureModule('Bags'); assert(FS.window.settings.fsSettingsName=='Bags' and FS.window.settings.border[1]==FS.moduleCardColors.Bags[1])
FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.Typography:Apply()

-- TEST: Extra cooldown buff and combat preferences change real filtering display ordering and combat visibility
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Cooldowns; local B=FS.modules.Buffs; local D=FS.modules.Combat
local spellAPI=C_Spell; C_Spell={GetSpellName=function(id) return id==11 and 'Zulu' or 'Alpha' end,GetSpellCooldown=function(id) return {startTime=GetTime(),duration=id==11 and 20 or 5} end,GetSpellCharges=function() return {currentCharges=1,maxCharges=2} end}
FS.db.cooldowns.spells={[11]='Interrupt',[12]='Defensive'}; FS.db.cooldowns.sort='Remaining'; C:Build(); assert(C.rows[1].id==12 and C.rows[1].text:find('charges'))
FS.db.cooldowns.groupFilter='Interrupt'; FS.db.cooldowns.showCharges=false; C:Build(); assert(#C.rows==1 and C.rows[1].id==11 and not C.rows[1].text:find('charges'))
local aura=B.Aura; B.Aura=function(_,unit,index,filter) if index==1 then return {name=filter=='HELPFUL' and 'Helpful' or 'Harmful',spellId=1,expirationTime=GetTime()+10} end end
FS.db.buffs.showBuffs=false; FS.db.buffs.showEnchants=false; FS.db.buffs.showDuration=false; B:Build(); assert(#B.rows==1 and B.rows[1].text=='[Debuff] Harmful')
FS.db.buffs.reminders={[99]=true}; B:UpdateReminder(); assert(B.reminder:IsShown()); FS.db.buffs.hideReminderCombat=true; TEST.combat=true; B:Event('PLAYER_REGEN_DISABLED'); assert(not B.reminder:IsShown()); TEST.combat=false
local meter=C_DamageMeter; C_DamageMeter=nil; D.people={one={name='One',damage=100,healing=1,deaths=0,interrupts=0,dispels=0},two={name='Two',damage=1,healing=100,deaths=0,interrupts=0,dispels=0}}
FS.db.combat.metric='HealingDone'; FS.db.combat.maxEntries=10; FS.db.combat.showRates=false; D:Build(); assert(D.rows[1].id=='two' and not D.rows[1].text:find('/s',1,true))
FS.db.combat.selfOnly=true; D:Build(); assert(#D.rows==0)
C_DamageMeter=meter; C_Spell=spellAPI; B.Aura=aura

-- TEST: Additional auction profession and QoL options filter actual data and survive Profiles
ResetTest(); local FS=ForeverSuite; local A=FS.modules.AuctionHouse; local P=FS.modules.Professions; local Q=FS.modules.QoL
local itemInfo,itemCount=C_Item.GetItemInfo,C_Item.GetItemCount
C_Item.GetItemInfo=function(id) return 'Item '..id,'item:'..id end; C_Item.GetItemCount=function(_,bank) return bank and 10 or 0 end
FS.db.auctionHouse.shopping={[11]=2}; A:Prices()[12]={price=1,kind='per item',time=10}; FS.db.auctionHouse.shoppingOnly=true; FS.db.auctionHouse.hideSatisfied=true; A:Build(); assert(#A.rows==0)
FS.db.auctionHouse.countBank=false; A:Build(); assert(#A.rows==1 and A.rows[1].id==11)
assert(A.rows[1].text:find('Have 0/2 | Need 2',1,true) and A.rows[1].text:find('No observed price',1,true))
FS.db.auctionHouse.shoppingOnly=false; FS.db.auctionHouse.showDates=false; FS.db.auctionHouse.sort='Lowest price'; A:Build(); assert(A.rows[1].id==12 and not A.rows[1].text:find('10',1,true))
assert(A.rows[1].text:find('Observed ',1,true))
local api=C_TradeSkillUI; C_TradeSkillUI={GetAllRecipeIDs=function() return {11,12} end,GetRecipeInfo=function(id) return {name=id==11 and 'Zulu' or 'Alpha',learned=true} end,GetCraftableCount=function(id) return id==11 and 2 or 5 end}
FS.db.professions.sort='Craftable'; FS.db.professions.showCounts=false; P:Build(); assert(P.rows[1].id==12 and P.rows[1].text=='Alpha')
P.materials={{text='Enough',required=1,owned=2},{text='Missing',required=3,owned=1}}; FS.db.professions.missingOnly=true; P:Build(); assert(#P.rows==1 and P.rows[1].text=='Missing'); P.materials=nil
FS.db.qol.showXP=false; FS.db.qol.showToNext=false; FS.db.qol.showRested=false; FS.db.qol.showQuestTip=false; Q:Build(); assert(#Q.rows==0)
local profiles=FS.modules.Profiles; profiles:Save('New choices'); profiles:Save('Other choices'); FS.db.auctionHouse.countBank=true; FS.db.professions.missingOnly=false; assert(profiles:Load('New choices'))
assert(not FS.db.auctionHouse.countBank and FS.db.professions.missingOnly and not FS.db.qol.showRested)
FS.db.cooldowns.sort='Invalid'; FS.modules.Cooldowns:NormalizeSettings(); assert(FS.db.cooldowns.sort=='Group')
C_Item.GetItemInfo,C_Item.GetItemCount=itemInfo,itemCount; C_TradeSkillUI=api

-- TEST: All module settings fit a moved and scaled dashboard at maximum typography in small viewports
ResetTest(); local FS=ForeverSuite; FS:ShowConfig()
local effective=FS.window.GetEffectiveScale; local uw,uh=UIParent:GetWidth(),UIParent:GetHeight()
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply()
for _,ratio in ipairs({.65,1.4}) do
 FS.window.GetEffectiveScale=function() return ratio end
 UIParent:SetSize(1024,768); FS.window:ClearAllPoints(); FS.window:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',900,-500)
 local function bounds(f)
  assert(f.point[1]=='CENTER' and f.point[2]==UIParent)
  assert(f:GetParent()==UIParent and f:GetWidth()*f:GetScale()<=976.01 and f:GetHeight()*f:GetScale()<=720.01,f.fsSettingsName)
 end
 for name,module in pairs(FS.modules) do if name~='Profiles' then
  FS:ConfigureModule(name); local f=(name=='Bags' or name=='Vendor') and FS.window.settings or module.settings; bounds(f)
  if f.more then
   if not f.advanced then f.more:Click() end; FS:ThemeSettings(f,name); bounds(f)
   assert(f.fsForm.description==f.description and f.description:GetText():find('Advanced options',1,true))
   if name=='Vendor' then
    for _,item in ipairs(f.fsForm.items) do if item.control==f.mode then assert(item.help and not item.explanation and not item.help:GetText():find('New items',1,true)) end end
    f.fields.repairLimit:SetText('9'); FS:ThemeSettings(f,name); assert(f.fields.repairLimit:GetText()=='9')
   end
   f.more:Click(); bounds(f)
  elseif f.nextOptions then
   f.nextOptions:Click(); bounds(f); f.previousOptions:Click(); bounds(f)
  end
 end end
end
UIParent:SetSize(uw,uh); FS.window.GetEffectiveScale=effective
FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.Typography:Apply()

-- TEST: Native bar layout writes remain client-owned even with saved addon positions and during combat
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; local old=MultiBarBottomLeft
local bar=CreateFrame('Frame',nil,UIParent); MultiBarBottomLeft=bar; bar:SetPoint('BOTTOM',UIParent,'BOTTOM',-40,40)
FS.db.layout.frames.MultiBarBottomLeft={x=50,y=300,scale=.8}; A:SettingsChanged(); FS.Layout:Apply('MultiBarBottomLeft')
assert(bar.point[4]==-40 and bar.point[5]==40 and bar:GetScale()==1)
assert(not bar.skipAutomaticPositioning and not bar.ignoreFramePositionManager and not FS.Layout.targets.MultiBarBottomLeft)
TEST.combat=true; bar:SetPoint('BOTTOM',UIParent,'BOTTOM',25,60); Drain(); assert(bar.point[4]==25 and bar.point[5]==60 and not A.pending)
TEST.combat=false; A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_ENABLED'); assert(bar.point[5]==60)
FS.db.layout.frames.MultiBarBottomLeft=nil; MultiBarBottomLeft=old


-- TEST: Idle styling does not rebuild backdrops fonts saved anchors or settings geometry
ResetTest(); local FS=ForeverSuite
local frame=CreateFrame('Frame',nil,UIParent); local backdrops=0; local setBackdrop=frame.SetBackdrop
frame.SetBackdrop=function(self,...) backdrops=backdrops+1; return setBackdrop(self,...) end
for i=1,5 do FS.HUD:Skin(frame) end; assert(backdrops==1)
local label=FS.HUD:Label(frame,'Stable text',0,0,200); local fonts=0; local setFont=label.SetFont
label.SetFont=function(self,...) fonts=fonts+1; return setFont(self,...) end
for i=1,5 do FS:ApplyFont(label) end; assert(fonts==0)
FS.Layout:Register('TestIdle',frame); FS.db.layout.frames.TestIdle={x=15,y=20,scale=.9}; FS.Layout:Apply('TestIdle')
local moves=0; local setPoint=frame.SetPoint; frame.SetPoint=function(self,...) moves=moves+1; return setPoint(self,...) end
for i=1,5 do FS.Layout:Apply('TestIdle') end; assert(moves==0)
FS:ConfigureModule('Gear'); local f=FS.modules.Gear.settings; local clears=0; local clear=f.ClearAllPoints
f.ClearAllPoints=function(self,...) clears=clears+1; return clear(self,...) end
f.scripts.OnUpdate(f,.2); clears=0
for i=1,5 do f.scripts.OnUpdate(f,.2) end; assert(clears==0)
FS.db.layout.frames.TestIdle=nil; FS.Layout.targets.TestIdle=nil; frame:Hide()

-- TEST: Cast progress advances every frame without range resets and native castbars restore on disable
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames
local oldCast,oldChannel=UnitCastingInfo,UnitChannelInfo; local oldModern,oldLegacy=PlayerCastingBarFrame,CastingBarFrame
PlayerCastingBarFrame=CreateFrame('Frame',nil,UIParent); CastingBarFrame=CreateFrame('Frame',nil,UIParent)
PlayerCastingBarFrame:SetAlpha(.8); CastingBarFrame:SetAlpha(.6); U:SettingsChanged()
assert(PlayerCastingBarFrame:GetAlpha()==0 and CastingBarFrame:GetAlpha()==0)
PlayerCastingBarFrame:SetAlpha(1); assert(PlayerCastingBarFrame:GetAlpha()==0)
TEST.now=10; UnitCastingInfo=function(unit) if unit=='player' then return 'Test cast',nil,1,10000,12000 end end; UnitChannelInfo=nil
U:RefreshCast('player'); local bar=U.frames.player.cast; local ranges=0; local setRange=bar.SetMinMaxValues
bar.SetMinMaxValues=function(self,...) ranges=ranges+1; return setRange(self,...) end
for i=1,30 do TEST.now=10+i/60; bar.scripts.OnUpdate(bar); assert(math.abs(bar.value-i/120)<.000001); U:RefreshCast('player') end
assert(ranges==0); TEST.now=12; bar.scripts.OnUpdate(bar); assert(not bar:IsShown())
UnitCastingInfo=function() end; UnitChannelInfo=function() return 'Test channel',nil,1,12000,14000 end
U:RefreshCast('player'); TEST.now=12.5; bar.scripts.OnUpdate(bar); assert(math.abs(bar.value-.75)<.000001)
TEST.combat=true; FS:SetModuleEnabled('UnitFrames',false); assert(PlayerCastingBarFrame:GetAlpha()==0)
TEST.combat=false; U.events.scripts.OnEvent(U.events,'PLAYER_REGEN_ENABLED')
assert(PlayerCastingBarFrame:GetAlpha()==.8 and CastingBarFrame:GetAlpha()==.6)
bar.SetMinMaxValues=setRange; UnitCastingInfo,UnitChannelInfo=oldCast,oldChannel
PlayerCastingBarFrame,CastingBarFrame=oldModern,oldLegacy; FS:SetModuleEnabled('UnitFrames',true)

-- TEST: Native Edit Mode tables reject every addon write and no layout manager methods are invoked
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; local old,manager=MultiBarBottomLeft,EditModeManagerFrame
local bar=CreateFrame('Frame',nil,UIParent); MultiBarBottomLeft=bar; bar:SetPoint('BOTTOM',UIParent,'BOTTOM',-20,44)
local values={isInDefaultPosition=true,anchorInfo={offsetX=-20,offsetY=44}}
bar.systemInfo=setmetatable({}, {__index=values,__newindex=function() error('Tainted native layout write') end})
bar.BreakFromFrameManager=function() error('Native manager detached') end
bar.ApplySystemAnchor=function() error('Insecure native method call') end
EditModeManagerFrame={GetActiveLayoutSystemInfo=function() error('Native layout accessed') end}
FS.db.layout.frames.MultiBarBottomLeft={x=70,y=350,scale=.8}; A:SettingsChanged(); FS.Layout:ApplyAll()
assert(bar.point[4]==-20 and bar.point[5]==44 and bar:GetScale()==1)
TEST.combat=true; bar:SetPoint('BOTTOM',UIParent,'BOTTOM',30,60); A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_DISABLED')
TEST.combat=false; A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_ENABLED'); A.events.scripts.OnEvent(A.events,'EDIT_MODE_LAYOUTS_UPDATED')
FS:SetModuleEnabled('ActionBars',false); assert(bar.point[4]==30 and bar.point[5]==60 and values.isInDefaultPosition)
FS.db.layout.frames.MultiBarBottomLeft=nil; MultiBarBottomLeft,EditModeManagerFrame=old,manager; FS:SetModuleEnabled('ActionBars',true)


-- TEST: Dynamic native windows trigger local discovery without restyling bars or the entire interface
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local N=FS.NativeWindows
local refresh,native,clock=S.Refresh,N.Refresh,S.UpdateClock; local full,calls,ticks=0,0,0
S.Refresh=function() full=full+1 end; N.Refresh=function(self,...) calls=calls+1; return native(self,...) end; S.UpdateClock=function() ticks=ticks+1 end
S.discovery=nil; S:Discover(); calls=0
for i=1,5 do S.events.scripts.OnUpdate(S.events,1.1) end; assert(full==0 and calls==0 and ticks==5)
local old=WorldMapFrame; WorldMapFrame=CreateFrame('Frame',nil,UIParent); S.events.scripts.OnUpdate(S.events,1.1); assert(calls==1 and full==0)
CreateFrame('Button',nil,WorldMapFrame); S.events.scripts.OnUpdate(S.events,1.1); assert(calls==2 and full==0)
TEST.combat=true; CreateFrame('Button',nil,WorldMapFrame); S.events.scripts.OnUpdate(S.events,1.1); assert(calls==2)
TEST.combat=false; S.events.scripts.OnUpdate(S.events,1.1); assert(calls==3 and full==0)
S.Refresh,N.Refresh,S.UpdateClock=refresh,native,clock; WorldMapFrame:Hide(); WorldMapFrame=old; S.discovery=nil


-- TEST: Target-style native anchor changes never enqueue addon correction or rebuild bar skins
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; local bar=MainActionBar
FS.db.layout.frames.MainActionBar={x=100,y=400,scale=.8}; A:SettingsChanged()
local settings,skin=A.SettingsChanged,A.SkinButton; local rebuilds,skins=0,0
A.SettingsChanged=function(self,...) rebuilds=rebuilds+1; return settings(self,...) end
A.SkinButton=function(self,...) skins=skins+1; return skin(self,...) end
for i=1,20 do bar:SetPoint('BOTTOMLEFT',UIParent,'BOTTOM',i,40); bar:SetScale(1) end
Drain(); assert(rebuilds==0 and skins==0 and bar.point[4]==20 and not A.queued)
A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_ENABLED'); assert(rebuilds==0 and skins==0)
FS.Layout:Apply('MainActionBar'); assert(bar.point[4]==20)
A.SettingsChanged,A.SkinButton=settings,skin; FS.db.layout.frames.MainActionBar=nil


-- TEST: Hidden empty secure buttons keep noninteractive slots in combat without forcing native visibility or actions
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; A:SettingsChanged()
local button=MainActionBar.actionButtons[4]; local state=A.buttons[button]; local handler=button:GetScript('OnClick'); local action=button:GetAttribute('action')
assert(state.slot and state.slot:GetParent()==UIParent and not state.slot:IsMouseEnabled())
TEST.combat=true; button:Hide(); A:SyncDecorations(); assert(not button:IsShown() and state.slot:IsShown())
assert(not state.border:IsShown() and button:GetAttribute('action')==action and button:GetScript('OnClick')==handler)
MainActionBar:Hide(); A:SyncDecorations(); assert(not state.slot:IsShown()); MainActionBar:Show(); A:SyncDecorations(); assert(state.slot:IsShown())
TEST.combat=false; button:Show(); FS:SetModuleEnabled('ActionBars',false); assert(not state.slot:IsShown())
FS:SetModuleEnabled('ActionBars',true); assert(state.slot:IsShown() and button:GetAttribute('action')==action)

-- TEST: Four bar appearances preserve secure actions and survive styling refreshes and profiles
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; A:SettingsChanged()
local b=MainActionBar.actionButtons[1]; local state=A.buttons[b]; local handler=b:GetScript('OnClick'); local action=b:GetAttribute('action'); local anchor={b:GetPoint()}
for _,style in ipairs(A.styles) do
    FS.db.actionBars.style=style; A:SettingsChanged(); FS.Style:Bars(); Drain()
    local tray=FS.Style.plates[MainActionBar]
    assert(tray:IsShown()==(style=='Minimal' or style=='Compact dock'))
    assert(state.border.fsTileStyle==style and state.slot.fsTileStyle==style)
    assert(state.slot.styleTexture.texture:find('Tile-'..A.art[style],1,true))
    assert(not state.slot:IsMouseEnabled() and b:GetScript('OnClick')==handler and b:GetAttribute('action')==action)
    local current={b:GetPoint()}; assert(current[1]==anchor[1] and current[4]==anchor[4] and current[5]==anchor[5])
end
FS.modules.Profiles:Save('Gold bars'); FS.db.actionBars.style='Floating'; FS.modules.Profiles:Save('Floating bars'); assert(FS.modules.Profiles:Load('Gold bars')); assert(FS.db.actionBars.style=='Gold & cyan')
FS.db.actionBars.style='bad style'; A:NormalizeSettings(); assert(FS.db.actionBars.style=='Minimal')
A:SettingsChanged(); Drain()
TEST.combat=true; FS.db.actionBars.style='Floating'; A:SettingsChanged(); A:ApplyAppearance(); assert(state.border.fsTileStyle=='Minimal' and A.pending)
TEST.combat=false; A:SettingsChanged(); assert(state.border.fsTileStyle=='Floating' and not A.pending)

-- TEST: Fresh installs prompt once and upgrades retain settings without restarting setup on profile switches
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; assert(I:NeedsSetup())
ForeverSuiteDB={actionBars={scale=.9,style='Floating'},setup=nil}; FS:InitializeDatabase()
assert(I:NeedsSetup() and FS.db.actionBars.scale==.9 and FS.db.actionBars.style=='Floating')
FS.db.setup.dismissed=true; FS.db.setup.completed=false; FS.modules.Profiles:Save('Existing setup')
assert(not FS.modules.Profiles:Snapshot().setup); FS.modules.Profiles:Load('Existing setup'); assert(FS.db.setup.dismissed and not I:NeedsSetup())
ResetTest(); I:Show(); I.window.later:Click(); assert(not I:NeedsSetup() and not FS.db.setup.completed)
assert(I:Show() and I.step==1); I.window:Hide()

-- TEST: Guided setup stages choices, shows welcome credits and returns from patch notes without losing the draft
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; assert(I:Show()); local f=I.window
assert(f.description:GetText():find(FS.version,1,true) and f.description:GetText():find('DeluxiZ',1,true) and f.patch:IsShown())
f.patch:Click(); assert(FS.aboutWindow:IsShown() and not f:IsShown() and FS.aboutWindow.close:GetText()=='Back to setup')
FS.aboutWindow.close:Click(); assert(f:IsShown() and I.step==1 and not FS.installerReturn)
FS:ShowPatchLog(); assert(FS.aboutWindow.close:GetText()=='Close' and not FS.installerReturn); FS.aboutWindow.close:Click(); I:Show()
f.next:Click(); f.choices[4]:Click(); f.next:Click(); f.choices[4]:Click(); assert(I.draft.theme=='Verdant Relic' and FS.db.appearance.theme=='Legacy' and not f.patch:IsShown())
assert(f.design.image.texture:find('04-Preview',1,true)); f.next:Click(); f.choices[1]:Click(); assert(I.draft.scale==.8 and FS.db.actionBars.scale==1)
f.previous:Click(); assert(I.draft.theme=='Verdant Relic'); f.next:Click()
assert(I.draft.modules.Quests and FS:IsModuleEnabled('Quests'))
FS.db.layout.frames.MainActionBar={x=77,y=123,scale=1}; local loot=FS:IsModuleEnabled('Loot')
assert(I:Apply()); Drain(); assert(FS.db.appearance.theme=='Verdant Relic' and FS.db.actionBars.style=='Minimal' and FS.db.actionBars.scale==1 and FS:IsModuleEnabled('Quests'))
assert(FS.db.layout.frames.MainActionBar.x==77 and FS.db.layout.frames.MainActionBar.y==123 and FS.db.layout.frames.MainActionBar.scale==1)
assert(FS:IsModuleEnabled('Loot')==loot and FS.db.setup.completed and not I:NeedsSetup() and not f:IsShown())
FS.db.layout.frames.MainActionBar=nil

-- TEST: Setup blocks combat and vendor conflicts and keeps every step within the viewport with large fonts
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show(); local f=I.window; I.draft.style='Floating'
TEST.combat=true; assert(not I:Apply() and not I:Show() and FS.db.actionBars.style=='Minimal'); TEST.combat=false
FS.modules.Vendor.busy=true; assert(not I:Apply() and not FS.db.setup.completed); FS.modules.Vendor.busy=false
FS.db.typography.global.size=24; FS.Typography:Apply()
for step=1,5 do
    I.step=step; I:Refresh()
    assert(f:GetHeight()*f:GetScale()<=UIParent:GetHeight()-47 and f:GetWidth()*f:GetScale()<=UIParent:GetWidth()-47)
    local point={f.next:GetPoint()}; local bottom=point[5] or point[3]; assert(-bottom+f.next:GetHeight()+20<=f:GetHeight())
    for index,choice in ipairs(f.choices) do if choice:IsShown() then local p={choice:GetPoint()}; local y=p[5] or p[3]; assert(-y+choice:GetHeight()<f:GetHeight()) end end
end
f:Hide(); FS.db.typography.global.size=0; FS.Typography:Apply()

-- TEST: First login prioritizes setup over patch notes and completed setup resumes normal startup preferences
ResetTest(); local FS=ForeverSuite; FS:CreateAboutWindow(); FS.aboutWindow:Hide()
FS.startupHandled=nil; FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); Drain(); assert(FS.Installer.window:IsShown() and not FS.aboutWindow:IsShown())
FS.Installer:Dismiss(); FS.db.patchLog.showOnLoad=true
FS.startupHandled=nil; FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); Drain(); assert(FS.aboutWindow:IsShown() and not FS.Installer.window:IsShown())
FS.aboutWindow.close:Click()

-- TEST: Textured bar artwork matches the installer and restores icon geometry without touching secure buttons
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
local b=CreateFrame('Button',nil,MainActionBar); b:SetSize(36,36); b:SetPoint('LEFT',MainActionBar,'LEFT',42,0)
b.icon=b:CreateTexture(); b.icon:SetPoint('CENTER',b,'CENTER',2,3); b.icon:SetTexCoord(0,1,0,1)
local handler=function() end; b:SetScript('OnClick',handler); b:SetAttribute('action',99)
A:SkinButton(b,true,MainActionBar); local state=A.buttons[b]; FS.Installer:Show()
for _,style in ipairs(A.styles) do
    FS.db.actionBars.style=style; A:ApplyAppearance(); FS.Installer.draft.style=style; FS.Installer:Refresh()
    assert(state.slot.styleTexture.texture==FS.Installer.window.preview.tiles[1].styleTexture.texture)
    assert(state.iconStyle==style and b.icon.point[1]=='BOTTOMRIGHT')
    assert(b.point[1]=='LEFT' and b.point[4]==42 and b:GetAttribute('action')==99 and b:GetScript('OnClick')==handler)
end
local setPoint=b.icon.SetPoint; local writes=0
b.icon.SetPoint=function(self,...) writes=writes+1; return setPoint(self,...) end
for n=1,10 do A:ApplyAppearance() end; assert(writes==0)
TEST.combat=true; A:ApplyAppearance(); assert(writes==0); TEST.combat=false
A:SkinButton(b,false,MainActionBar); assert(b.icon.point[1]=='CENTER' and b.icon.point[4]==2 and b.icon.point[5]==3)
assert(b.icon.coords[1]==0 and b.icon.coords[2]==1 and not state.slot:IsShown())
b.icon.SetPoint=setPoint; b:Hide(); A.buttons[b]=nil; FS.Installer.window:Hide()
local tray=FS.Installer.window.preview.tray
tray:SetSize(50,600); A:StyleTray(tray,'Compact dock',true); assert(tray.fsTrayVertical and #tray.styleTexture.coords==8)
tray:SetSize(600,50); A:StyleTray(tray,'Compact dock',true); assert(not tray.fsTrayVertical and #tray.styleTexture.coords==4)

-- TEST: Combat completion applies only deferred settings instead of rebuilding all modules and unit watches
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Chat; local U=FS.modules.UnitFrames
local apply=C.Apply; local applied=0; C.Apply=function(self,...) applied=applied+1; return apply(self,...) end
C.pending=false; C.events.scripts.OnEvent(C.events,'PLAYER_REGEN_ENABLED'); assert(applied==0)
TEST.combat=true; C:SettingsChanged(); assert(C.pending and applied==0)
TEST.combat=false; C.events.scripts.OnEvent(C.events,'PLAYER_REGEN_ENABLED'); assert(applied==1 and not C.pending); C.Apply=apply
local settings=U.SettingsChanged; local rebuilt=0; U.SettingsChanged=function(self,...) rebuilt=rebuilt+1; return settings(self,...) end
U.pending=false; U.events.scripts.OnEvent(U.events,'PLAYER_REGEN_ENABLED'); assert(rebuilt==0)
U.pending=true; U.events.scripts.OnEvent(U.events,'PLAYER_REGEN_ENABLED'); assert(rebuilt==1 and not U.pending); U.SettingsChanged=settings

-- TEST: Blocked addon action diagnostics record addon function and combat without altering the UI
ResetTest(); local FS=ForeverSuite; FS.runtimeErrors=nil; TEST.combat=true
for i=1,12 do FS.events.scripts.OnEvent(FS.events,'ADDON_ACTION_BLOCKED','ForeverSuite','ProtectedFunction'..i) end
assert(#FS.runtimeErrors==10 and FS.runtimeErrors[10]:find('ProtectedFunction12',1,true) and FS.runtimeErrors[10]:find('combat=true',1,true))
TEST.combat=false; FS.events.scripts.OnEvent(FS.events,'ADDON_ACTION_FORBIDDEN','OtherAddon','SetPoint')
assert(FS.runtimeErrors[10]:find('OtherAddon',1,true)); FS.runtimeErrors=nil

-- TEST: Native ResizeLayout child and region measurement stays stable with outward decoration
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
A:SettingsChanged(); FS.Style:Bars()
local bar=MainActionBar; local width,height=480,40
local control=CreateFrame('Frame',nil,bar); control.layoutRect=function() return 0,0,480,40 end
-- Mirror BaseLayoutMixin filtering: ResizeLayout ignores layoutIndex, but
-- includes shown frames and regions unless ignoreInLayout is explicitly set.
local function measure(owner)
    local left,bottom,right,top
    local regions={owner:GetChildren()}; for _,r in ipairs({owner:GetRegions()}) do regions[#regions+1]=r end
    for _,r in ipairs(regions) do
        if r:IsShown() and not r.ignoreInLayout and r.layoutRect then
            local l,b,rr,t=r.layoutRect()
            left=math.min(left or l,l); bottom=math.min(bottom or b,b)
            right=math.max(right or rr,rr); top=math.max(top or t,t)
        end
    end
    return right-left,top-bottom
end
local plate=FS.Style.plates[bar]
plate.layoutRect=function() return -5,-5,width+5,height+5 end
local slot=A.buttons[bar.actionButtons[4]].slot
slot.layoutRect=function() return -1,-1,width+1,height+1 end
-- Prove this fixture detects the former recursive expansion.
local intruder=CreateFrame('Frame',nil,bar); intruder.layoutRect=plate.layoutRect
plate:Show(); plate.ignoreInLayout=false
local w,h=measure(bar); assert(w==490 and h==50)
width,height=w,h; w,h=measure(bar); assert(w==500 and h==60)
intruder:Hide(); assert(plate:GetParent()==UIParent); width,height=480,40
local nativeRegion=bar:CreateTexture(); nativeRegion.layoutRect=function() return 0,0,480,40 end
for i=1,20 do
    TEST.combat=i%2==0
    A.events.scripts.OnEvent(A.events,TEST.combat and 'PLAYER_REGEN_DISABLED' or 'PLAYER_REGEN_ENABLED')
    FS.Style.events.scripts.OnUpdate(FS.Style.events,1)
    width,height=measure(bar); assert(width==480 and height==40)
end
TEST.combat=false; control:Hide(); nativeRegion:Hide(); plate.layoutRect=nil; slot.layoutRect=nil

-- TEST: Native action decorations exclude regions as well as child frames from layout
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; A:SettingsChanged(); FS.Style:Bars()
for button,state in pairs(A.buttons) do
    assert(state.border.ignoreInLayout and state.border.styleTexture.ignoreInLayout)
    if state.slot then assert(state.slot.ignoreInLayout and state.slot.styleTexture.ignoreInLayout) end
    for _,r in ipairs({button:GetRegions()}) do if r.fsSuiteStyle then assert(r.ignoreInLayout) end end
end
for _,plate in pairs(FS.Style.plates) do assert(plate.ignoreInLayout) end
local button=CreateFrame('Button',nil,UIParent); FS:ClickEffect(button)
for _,region in ipairs({button:GetRegions()}) do assert(region.ignoreInLayout) end

-- TEST: Forever client detection distinguishes the live interface from other clients
ResetTest(); local FS=ForeverSuite; local old=GetBuildInfo
GetBuildInfo=function() return '1.60.1','70862','Nov 2026',16001 end
assert(FS:RefreshClient().isForever and FS.client.build=='70862')
GetBuildInfo=function() return '12.1.5','70783','Nov 2026',120105 end
assert(not FS:RefreshClient().isForever)
GetBuildInfo=old; FS:RefreshClient()

-- TEST: Unsupported client events cannot abort registration of supported module events
ResetTest(); local FS=ForeverSuite; local old=C_EventUtils; local frame=CreateFrame('Frame')
C_EventUtils={IsEventValid=function(name) return name~='REMOVED_EVENT' end}
local register=frame.RegisterEvent; local calls=0
frame.RegisterEvent=function(self,name) calls=calls+1; assert(name~='REMOVED_EVENT'); return register(self,name) end
assert(not FS:RegisterClientEvent(frame,'REMOVED_EVENT') and calls==0)
assert(FS:RegisterClientEvent(frame,'PLAYER_LOGIN') and frame.events.PLAYER_LOGIN and calls==1)
assert(FS.client.unsupportedEvents.REMOVED_EVENT)
C_EventUtils=nil
frame.RegisterEvent=function(self,name) if name=='OLD_EVENT' then error('Unknown event') end; return register(self,name) end
assert(not FS:RegisterClientEvent(frame,'OLD_EVENT'))
assert(FS:RegisterClientEvent(frame,'PLAYER_REGEN_ENABLED') and frame.events.PLAYER_REGEN_ENABLED)
frame.RegisterEvent=register; assert(FS:RegisterClientEvent(frame,'OLD_EVENT') and not FS.client.unsupportedEvents.OLD_EVENT)
FS.client.unsupportedEvents.REMOVED_EVENT=nil; C_EventUtils=old

-- TEST: Client status reports active overlapping addons without changing module settings
ResetTest(); local FS=ForeverSuite; local old=C_AddOns; local print=FS.Print; local messages={}
C_AddOns={IsAddOnLoaded=function(name) return name=='Platynator' end}
FS.Print=function(self,text) messages[#messages+1]=text end
local enabled=FS:IsModuleEnabled('Nameplates'); FS:PrintClientStatus()
assert(FS:IsModuleEnabled('Nameplates')==enabled)
assert(table.concat(messages,'\n'):find('Platynator and ForeverSuite Nameplates',1,true))
FS.db.nameplates.enabled=false; messages={}; FS:PrintClientStatus()
assert(not table.concat(messages,'\n'):find('Platynator and ForeverSuite Nameplates',1,true))
FS.Print=print; C_AddOns=old; FS.db.nameplates.enabled=enabled

-- TEST: Ten theme choices change design previews without writing live profile choices
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show(); I.window.next:Click(); I.window.next:Click()
assert(#FS.Themes.names==10 and #I.window.choices==10 and I.step==2)
for i,name in ipairs(FS.Themes.names) do
    I.window.choices[i]:Click()
    assert(I.draft.theme==name and I.window.design.image.texture==FS.Themes:Asset(i,'Preview'))
    assert(FS.db.appearance.theme=='Legacy' and not FS.db.setup.completed)
end
I:Dismiss(); assert(FS.db.appearance.theme=='Legacy')

-- TEST: Theme picker cancellation and applying preserve setup progress modules and native geometry
ResetTest(); local FS=ForeverSuite; local I=FS.Installer
local setup=FS.db.setup.completed; local modules=FS:IsModuleEnabled('Quests'); local point={MainActionBar:GetPoint()}; local scale=MainActionBar:GetScale()
I:ShowThemes(); I.window.choices[6]:Click(); I.window.later:Click()
assert(FS.db.appearance.theme=='Legacy' and FS.db.setup.completed==setup and FS:IsModuleEnabled('Quests')==modules)
I:ShowThemes(); I.window.choices[6]:Click(); I.window.next:Click()
assert(FS.db.appearance.theme=='Royal Aether' and not I.window:IsShown())
assert(FS.db.setup.completed==setup and FS:IsModuleEnabled('Quests')==modules and MainActionBar:GetScale()==scale)
local now={MainActionBar:GetPoint()}; for i,v in ipairs(point) do assert(now[i]==v) end

-- TEST: Every theme applies real bar assets without changing secure actions or callbacks
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; A:SettingsChanged()
local b=MainActionBar.actionButtons[1]; local state=A.buttons[b]; local action=b:GetAttribute('action'); local click=b:GetScript('OnClick')
for i,name in ipairs(FS.Themes.names) do
    assert(FS.Themes:Set(name)); local parts=FS.Themes.frames[state.slot].parts
    assert(#parts==9 and parts[1].texture==FS.Themes:Asset(i,'Button') and parts[1]:IsShown())
    assert(b:GetAttribute('action')==action and b:GetScript('OnClick')==click)
    assert(not state.slot.styleTexture or not state.slot.styleTexture:IsShown())
end
assert(FS.Themes:Set('Legacy')); assert(state.slot.styleTexture:IsShown())
for _,p in ipairs(FS.Themes.frames[state.slot].parts) do assert(not p:IsShown()) end

-- TEST: Profiles store independent themes and corrupt theme names fall back without resetting old layouts
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles
assert(FS.Themes:Set('Astral Glass')); P:Save('Astral profile')
assert(FS.Themes:Set('Royal Aether')); P:Save('Royal profile')
P:Load('Astral profile'); assert(FS.db.appearance.theme=='Astral Glass')
FS.db.appearance.theme='missing'; FS.Themes:Normalize(); assert(FS.db.appearance.theme=='Legacy')
assert(not FS.Themes:Set('missing'))

-- TEST: Theme selection respects combat and vendor transactions and refresh defers until combat ends
ResetTest(); local FS=ForeverSuite; local old=FS.db.appearance.theme
TEST.combat=true; assert(not FS.Themes:Set('Runestone')); assert(not FS.Installer:ShowThemes())
assert(not FS.Themes:Refresh() and FS.Themes.pending and FS.db.appearance.theme==old)
TEST.combat=false; FS.Themes.events.scripts.OnEvent(FS.Themes.events,'PLAYER_REGEN_ENABLED'); assert(not FS.Themes.pending)
FS.modules.Vendor.busy=true; assert(not FS.Themes:Set('Runestone') and FS.db.appearance.theme==old); FS.modules.Vendor.busy=false

-- TEST: Nine-slice artwork keeps fixed corners and all decorative regions out of native resize measurements
ResetTest(); local FS=ForeverSuite; local frame=CreateFrame('Frame',nil,UIParent); frame:SetSize(900,90)
assert(FS.Themes:Set('Titanium Signal')); FS.Themes:Register(frame)
local state=FS.Themes.frames[frame]; assert(state.corner==18 and #state.parts==9)
for _,region in ipairs(state.parts) do assert(region.ignoreInLayout and region.fsSuiteStyle) end
frame:SetSize(90,30); FS.Themes:Size(frame,state); assert(state.corner==10)
assert(state.parts[1]:GetWidth()==10 and state.parts[1].coords[2]==.18 and state.parts[9].coords[4]==1)

-- TEST: Light-theme text contrast restores original colors when switching to a dark theme
ResetTest(); local FS=ForeverSuite; local label=CreateFrame('Frame'):CreateFontString(); local painted
label.GetTextColor=function() return .8,.7,.6,1 end
label.SetTextColor=function(self,...) painted={...} end
assert(FS.Themes:Set('Cartographer')); FS.Themes:Font(label); assert(painted[1]<.2 and painted[2]<.2)
assert(FS.Themes:Set('Runestone')); assert(painted[1]==.8 and painted[2]==.7 and painted[3]==.6)

-- TEST: Themed waypoint arrows keep smoothed direction and clear when facing is unavailable
local FS,M,d=NavigationFixture(); FS.Themes:Set('Cartographer'); M:NavigationEvent('QUEST_ACCEPTED',11); M:RenderNavigation()
local f=M.navigator; assert(f.themeArrow and f.themeArrow:IsShown() and f.themeArrowIndex==10)
local rotation; f.themeArrow.SetRotation=function(self,value) rotation=value end
M:AnimateNavigation(.016); assert(math.abs(rotation-(M.navAngle-math.pi/2))<.0001)
d.facing=false; M:AnimateNavigation(.016); assert(not f.themeArrow:IsShown())
d:restore(); FS.Themes:Set('Legacy')
