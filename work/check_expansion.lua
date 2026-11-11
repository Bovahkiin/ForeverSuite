-- TEST: Profiles retain edited settings, isolate snapshots and preserve startup preferences
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles
P:Initialize(); FS.db.bags.scale=.8; FS.db.patchLog.showOnLoad=false
assert(P:Save('Travel')); FS.db.bags.scale=1; assert(P:Save('Raid'))
FS.db.bags.scale=1.1; assert(P:Load('Travel')); assert(FS.db.bags.scale==.8 and not FS.db.patchLog.showOnLoad)
assert(FS.db.profiles.saved.Raid.bags.scale==1.1); FS.db.bags.scale=.9
assert(FS.db.profiles.saved.Travel.bags.scale==.8)
TEST.combat=true; assert(not P:Load('Raid')); TEST.combat=false
FS.modules.Vendor.busy=true; assert(not P:Save('No')); FS.modules.Vendor.busy=false

-- TEST: Focus and group units use secure attributes, group visibility and deferred combat changes
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames
TEST.units.focus={name='Focus',health=60,maxHealth=100,player=true,class='MAGE'}
FocusFrame=CreateFrame('Button'); local child=CreateFrame('Button',nil,FocusFrame)
U:SettingsChanged(); assert(U.frames.focus:GetAttribute('unit')=='focus' and U.frames.focus.watched)
assert(U.frames.party4:GetAttribute('unit')=='party4' and U.frames.raid40:GetAttribute('unit')=='raid40')
assert(U.frames.raid40:GetParent()==U.groups.raid)
assert(U.groups.party.stateDriver=='[group:raid] hide; [group:party] show; hide')
assert(FocusFrame:GetAlpha()==0 and not child:IsMouseEnabled()); FocusFrame:SetAlpha(1); assert(FocusFrame:GetAlpha()==0)
TEST.combat=true; FS.db.unitFrames.showFocus=false; U:SettingsChanged(); assert(U.pending)
TEST.combat=false; U:SettingsChanged(); assert(not U.frames.focus.watched and FocusFrame:GetAlpha()==1 and child:IsMouseEnabled())
FS.db.unitFrames.showFocus=true; U:SettingsChanged(); FocusFrame=nil

-- TEST: Nameplates highlight only current target and clear old threat labels
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
TEST.units.nameplate1={name='Enemy',health=70,maxHealth=100,enemy=true}
local plate=CreateFrame('Frame'); plate.UnitFrame=CreateFrame('Frame',nil,plate); plate.UnitFrame.unit='nameplate1'
UnitIsUnit=function(a,b) return a=='nameplate1' and b=='target' end
UnitThreatSituation=function() return 3 end
N:Update(plate,'nameplate1'); local f=N.custom[plate].canvas; assert(f.threat:GetText()=='You have aggro')
UnitThreatSituation=function() return nil end; N:Update(plate,'nameplate1'); assert(f.threat:GetText()=='')
UnitIsUnit=nil; UnitThreatSituation=nil; N:Release(N.custom[plate])

-- TEST: Every added module opens a working skinned window, paginates settings and respects disable
ResetTest(); local FS=ForeverSuite; FS:ShowConfig()
for _,name in ipairs({'Map','Quests','Loot','Buffs','Cooldowns','Combat','Professions','AuctionHouse','Chat','Social','Guild','QoL','Bank','Bindings'}) do
    local M=FS.modules[name]; FS:ConfigureModule(name); assert(M.settings:IsShown())
    M:ShowWindow()
    if name=='Chat' then assert(M.settings:IsShown() and not FS.window:IsShown() and not M.window)
    else assert(M.window:IsShown() and not FS.window:IsShown()) end
    FS:SetModuleEnabled(name,false); assert((not M.window or not M.window:IsShown()) and not FS:IsModuleEnabled(name))
    FS:SetModuleEnabled(name,true)
end
FS:ShowConfig(); local f=FS.window; assert(f.cardCount==24)
f.nextModules:Click(); assert(f.cardPage==2 and f.cards.Quests.card:IsShown() and not f.cards.Bags.card:IsShown())
f.nextModules:Click(); assert(f.cardPage==3 and f.cards.Bank.card:IsShown())
f.previousModules:Click(); f.previousModules:Click(); assert(f.cardPage==1)

-- TEST: Quest objectives and automation preserve reward choices and combat/Shift pauses
ResetTest(); local FS=ForeverSuite; local Q=FS.modules.Quests; local accept,complete,reward=0,0,0; local choices=2; local shift=false
C_QuestLog={GetNumQuestLogEntries=function() return 2 end,GetInfo=function(i) return i==1 and {title='Zone',isHeader=true} or {title='Collect arrows',questID=5,isComplete=false} end,GetQuestObjectives=function() return {{text='0/8 arrows'}} end}
AcceptQuest=function() accept=accept+1 end; CompleteQuest=function() complete=complete+1 end; IsQuestCompletable=function() return true end
GetNumQuestChoices=function() return choices end; GetQuestReward=function() reward=reward+1 end; IsShiftKeyDown=function() return shift end
Q:Build(); assert(#Q.rows==1 and string.find(Q.rows[1].text,'0/8 arrows',1,true))
FS.db.quests.accept=true; FS.db.quests.turnIn=true
Q:Event('QUEST_DETAIL'); Q:Event('QUEST_PROGRESS'); Q:Event('QUEST_COMPLETE'); assert(accept==1 and complete==1 and reward==0)
choices=0; Q:Event('QUEST_COMPLETE'); assert(reward==1)
shift=true; Q:Event('QUEST_DETAIL'); assert(accept==1); shift=false
TEST.combat=true; Q:Event('QUEST_DETAIL'); assert(accept==1); TEST.combat=false
C_QuestLog=nil; AcceptQuest=nil; CompleteQuest=nil; IsQuestCompletable=nil; GetNumQuestChoices=nil; GetQuestReward=nil; IsShiftKeyDown=nil

-- TEST: Loot history is bounded, fast loot is opt-in and roll eligibility is rechecked
ResetTest(); local FS=ForeverSuite; local L=FS.modules.Loot; local calls=0; local need=false; local rolled
GetNumLootItems=function() return 2 end; LootSlot=function() calls=calls+1 end
L:Event('LOOT_OPENED'); assert(calls==0); FS.db.loot.fast=true; L:Event('LOOT_OPENED'); assert(calls==2)
for i=1,110 do L:Event('CHAT_MSG_LOOT','Loot '..i) end; assert(#FS.db.loot.history==100 and FS.db.loot.history[1].text=='Loot 110')
GetLootRollItemInfo=function() return 1,'Sword',1,2,false,need,true end; RollOnLoot=function(id,choice) rolled=choice end
L:Event('START_LOOT_ROLL',42,30000); L:Build(); L.selected=L.rows[1]; L:Roll(1); assert(rolled==nil)
need=true; L:Roll(1); assert(rolled==1 and not L.rolls[42])
GetNumLootItems=nil; LootSlot=nil; GetLootRollItemInfo=nil; RollOnLoot=nil

-- TEST: Buff reminders match spell IDs and disappear when the buff returns
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Buffs; FS.db.buffs.reminders={[17]=true}; local present=false
C_UnitAuras={GetAuraDataByIndex=function(_,i,filter) if present and i==1 and filter=='HELPFUL' then return {name='Shield',spellId=17,expirationTime=0} end end}
B:Tick(); assert(#B.missing==1 and B.reminder:IsShown()); present=true; B:Tick(); assert(#B.missing==0 and not B.reminder:IsShown())
FS:SetModuleEnabled('Buffs',false); assert(not B.reminder:IsShown()); FS:SetModuleEnabled('Buffs',true); C_UnitAuras=nil

-- TEST: Cooldowns show durations and charges, allow grouping and tolerate unavailable spells
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Cooldowns; local previous=C_Spell
FS.db.cooldowns.spells={[123]='Interrupt'}
C_Spell={GetSpellName=function() return 'Kick' end,GetSpellCooldown=function() return {startTime=GetTime(),duration=10} end,GetSpellCharges=function() return {currentCharges=1,maxCharges=2} end}
C:Build(); assert(#C.rows==1 and string.find(C.rows[1].text,'10s',1,true) and string.find(C.rows[1].text,'1/2 charges',1,true))
C.selected=C.rows[1]; C.actions[2].run(C); assert(FS.db.cooldowns.spells[123]=='Defensive')
C_Spell=nil; C:Build(); assert(string.find(C.rows[1].text,'unavailable',1,true)); C_Spell=previous

-- TEST: Combat uses native session data outside combat and confirms resetting global game sessions
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Combat; local prior=Enum; local resets=0
Enum={DamageMeterType={DamageDone=1,HealingDone=2,Deaths=3,Interrupts=4,Dispels=5},DamageMeterSessionType={Current=1,Overall=2}}
C_DamageMeter={IsDamageMeterAvailable=function() return true end,GetCombatSessionFromType=function() return {combatSources={{name='Mage',sourceGUID='one',totalAmount=1200,amountPerSecond=120},{name='Warrior',sourceGUID='two',totalAmount=300,amountPerSecond=30}}} end,ResetAllCombatSessions=function() resets=resets+1 end}
C:Build(); assert(#C.rows==2 and C.rows[1].id=='one')
TEST.combat=true; C:Build(); assert(#C.rows==0 and string.find(C.status,'after combat',1,true)); TEST.combat=false
C.actions[1].run(C); assert(resets==0); C.actions[1].run(C); assert(resets==1)
C.actions[2].run(C); assert(FS.db.combat.metric=='HealingDone'); C_DamageMeter=nil; Enum=prior

-- TEST: Legacy combat fallback totals effective healing, interrupts and deaths without enemy damage
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Combat; C:Reset(); local prior=UnitGUID
UnitGUID=function() return 'self' end
C:Record(0,'SWING_DAMAGE',false,'self','Player',0,0,'enemy','Enemy',0,0,50)
C:Record(0,'SPELL_HEAL',false,'self','Player',0,0,'self','Player',0,0,17,'Heal',2,100,25)
C:Record(0,'SPELL_INTERRUPT',false,'self','Player',0,0,'enemy','Enemy',0,0)
C:Record(0,'UNIT_DIED',false,'enemy','Enemy',0,0,'self','Player',0,0)
C:Record(0,'SWING_DAMAGE',false,'enemy','Enemy',0,0,'self','Player',0,0,500)
assert(C.people.self.damage==50 and C.people.self.healing==75 and C.people.self.interrupts==1 and C.people.self.deaths==1)
UnitGUID=prior

-- TEST: Map coordinates and pins use normalized positions and waypoint actions use saved map IDs
ResetTest(); local FS=ForeverSuite; local M=FS.modules.Map; local point
C_Map={GetBestMapForUnit=function() return 12 end,GetPlayerMapPosition=function() return {GetXY=function() return .25,.75 end} end,SetUserWaypoint=function(p) point=p end}
UiMapPoint={CreateFromCoordinates=function(id,x,y) return {id=id,x=x,y=y} end}
M:SavePin('Camp'); assert(#FS.db.map.pins==1 and FS.db.map.pins[1].x==.25)
M:Build(); assert(string.find(M.status,'25.0, 75.0',1,true)); M:Waypoint({pin=1}); assert(point.id==12 and point.y==.75)
C_Map=nil; UiMapPoint=nil

-- TEST: Profession materials use recipe reagent quantities and return to the full recipe list
ResetTest(); local P=ForeverSuite.modules.Professions
GetNumTradeSkills=function() return 2 end; GetTradeSkillInfo=function(i) if i==1 then return 'Metal','header',0 else return 'Copper sword','optimal',2 end end
GetTradeSkillNumReagents=function() return 1 end; GetTradeSkillReagentInfo=function() return 'Copper',1,3,6 end
P.materials=nil; P:Build(); assert(#P.rows==1); P:OnSelect(P.rows[1]); assert(#P.rows==1 and string.find(P.rows[1].text,'Need 3, have 6',1,true))
P.actions[1].run(P); P:Build(); assert(string.find(P.rows[1].text,'Copper sword',1,true))
GetNumTradeSkills=nil; GetTradeSkillInfo=nil; GetTradeSkillNumReagents=nil; GetTradeSkillReagentInfo=nil

-- TEST: Auction scans compute stack unit prices, isolate realms and retain shopping quantities
ResetTest(); local FS=ForeverSuite; local A=FS.modules.AuctionHouse; A.open=true
GetNumAuctionItems=function() return 2 end
GetAuctionItemInfo=function(_,i) return 'Copper',1,i==1 and 10 or 2,1,true,1,'',0,0,i==1 and 1000 or 100 end
GetAuctionItemLink=function() return 'item:1' end; GetRealmName=function() return 'Test realm' end
A:Scan(); assert(A:Prices()[1].price==50 and A:Prices()[1].kind=='per item')
A.actions[1].run(A,'1 20'); assert(FS.db.auctionHouse.shopping[1]==20)
GetRealmName=function() return 'Other realm' end; assert(A:Prices()[1]==nil)
GetNumAuctionItems=nil; GetAuctionItemInfo=nil; GetAuctionItemLink=nil; GetRealmName=nil; A.open=false

-- TEST: Social online filter and whispers prepare input; QoL never invites automatically
ResetTest(); local FS=ForeverSuite; local S=FS.modules.Social; local told,invited
C_FriendList={GetNumFriends=function() return 2 end,GetFriendInfoByIndex=function(i) return {name=i==1 and 'Online' or 'Offline',connected=i==1} end}
ChatFrame_SendTell=function(name) told=name end; S:Build(); assert(#S.rows==2); FS.db.social.onlineOnly=true; S:Build(); assert(#S.rows==1)
S.selected=S.rows[1]; S.actions[1].run(S); assert(told=='Online')
InviteUnit=function(name) invited=name end; local Q=FS.modules.QoL; Q:Build(); assert(not invited); Q.actions[1].run(Q,'Friend'); assert(invited=='Friend')
TEST.combat=true; Q.actions[1].run(Q,'Blocked'); assert(invited=='Friend'); TEST.combat=false
C_FriendList=nil; ChatFrame_SendTell=nil; InviteUnit=nil

-- TEST: Bank scans actual purchased tabs and rechecks changed slots before pickup
ResetTest(); local FS=ForeverSuite; local K=FS.modules.Bank; local prior=Enum
Enum={BankType={Character=1,Account=2}}; C_Bank={FetchPurchasedBankTabData=function(kind) return {{ID=kind==1 and 8 or 9}} end}
TEST.data={[1]={classID=6,quality=1}}; TEST.bagSizes={[8]=2,[9]=1}; TEST.bags[8]={[1]=AddItem(1,1,200)}; TEST.bags[0]={}
K.open=true; K:Build(); assert(#K.rows==2 and K.rows[1].category=='Ammo'); K:ShowWindow(); local b=K.window.grid[1]; assert(b.row.bag==8)
TEST.bags[8][1].itemID=2; b:Click(); assert(not TEST.cursor)
TEST.bags[8][1].itemID=1; K:Refresh(); b:Click(); assert(TEST.cursor and TEST.cursor.itemID==1)
ClearCursor(); K.window:Hide(); Enum=prior; C_Bank=nil

-- TEST: Key binding capture adds modifiers, saves the current set and cancels in combat
ResetTest(); local B=ForeverSuite.modules.Bindings; local binding,command,saved
SetBinding=function(key,action) binding,command=key,action; return true end
SaveBindings=function(set) saved=set end; GetCurrentBindingSet=function() return 2 end; IsControlKeyDown=function() return true end
B.capturing='ACTIONBUTTON1'; B:BindKey('F'); assert(binding=='CTRL-F' and command=='ACTIONBUTTON1' and saved==2)
B.capturing='ACTIONBUTTON2'; TEST.combat=true; B:BindKey('G'); assert(binding=='CTRL-F' and not B.capturing); TEST.combat=false
SetBinding=nil; SaveBindings=nil; GetCurrentBindingSet=nil; IsControlKeyDown=nil

-- TEST: Modern profession enumeration supports filtered recipe IDs and material schematics
ResetTest(); local P=ForeverSuite.modules.Professions
TEST.data={[7]={name='Copper bar',quality=1}}
C_TradeSkillUI={GetFilteredRecipeIDs=function() return {21,22} end,GetRecipeInfo=function(id) return {name='Smelt copper',learned=id==21} end,GetCraftableCount=function() return 3 end,GetRecipeSchematic=function() return {reagentSlotSchematics={{quantityRequired=2,reagents={{itemID=7}}}}} end}
C_Item.GetItemCount=function() return 5 end
P.materials=nil; P:Build(); assert(#P.rows==1 and P.rows[1].modern)
P:OnSelect(P.rows[1]); assert(#P.rows==1 and P.rows[1].text=='Copper bar | Need 2, have 5')
P.materials=nil; C_TradeSkillUI=nil; C_Item.GetItemCount=nil

-- TEST: Modern commodity scans respect opt-out and save actual unit prices
ResetTest(); local FS=ForeverSuite; local A=FS.modules.AuctionHouse; A.open=true
C_AuctionHouse={GetNumCommoditySearchResults=function() return 2 end,GetCommoditySearchResultInfo=function(_,i) return {unitPrice=i==1 and 100 or 75} end}
FS.db.auctionHouse.record=false; A:Event('COMMODITY_SEARCH_RESULTS_UPDATED',7); assert(not A:Prices()[7])
FS.db.auctionHouse.record=true; A:Event('COMMODITY_SEARCH_RESULTS_UPDATED',7); assert(A:Prices()[7].price==75)
A.open=false; C_AuctionHouse=nil

-- TEST: Bank and bags coexist side by side while other suite windows still close them
ResetTest(); local FS=ForeverSuite; local K=FS.modules.Bank; local B=FS.modules.Bags; K.open=true
K:ShowWindow(); assert(K.window:IsShown() and B.window:IsShown())
B:ShowWindow(); assert(K.window:IsShown()); FS:ShowConfig(); assert(not K.window:IsShown() and not B.window:IsShown() and not K.open)

-- TEST: Key capture UI consumes input only while binding and restores propagation on close
ResetTest(); local B=ForeverSuite.modules.Bindings; B:ShowWindow(); B.selected={command='ACTIONBUTTON1'}
B:BeginCapture(); assert(B.capture.keyboard and not B.capture.propagate)
B.window:Hide(); assert(not B.capture.keyboard and B.capture.propagate and not B.capturing)

-- TEST: Core has one slash entry and reset preserves settings while combat or vendor actions are active
ResetTest(); local FS=ForeverSuite
assert(SLASH_FOREVERSUITE1=='/fs' and SLASH_FOREVERSUITE2==nil)
SlashCmdList.FOREVERSUITE('reset'); assert(FS.window:IsShown())
FS.db.bags.scale=.8; TEST.combat=true; FS:ResetDatabase(); assert(FS.db.bags.scale==.8)
TEST.combat=false; FS.modules.Vendor.busy=true; FS:ResetDatabase(); assert(FS.db.bags.scale==.8); FS.modules.Vendor.busy=false

-- TEST: Shared API wrapper preserves nil return positions and map migration drops corrupt pins
ResetTest(); local FS=ForeverSuite; local T=FS.Tools
local a,b,c=T:Call(function() return nil,'middle',5 end); assert(a==nil and b=='middle' and c==5)
assert(T:Call(function() error('unavailable') end)==nil)
FS.db.map.pins={false,{map=1,x='bad',y=.5,name='Bad'},{map=1,x=.5,y=.5,name='Good'}}
FS.modules.Map:SettingsChanged(); assert(#FS.db.map.pins==1 and FS.db.map.pins[1].name=='Good')

-- TEST: Disabled quest tracker restores native mouse and alpha after combat
ResetTest(); local FS=ForeverSuite; local Q=FS.modules.Quests
ObjectiveTrackerFrame=CreateFrame('Frame'); ObjectiveTrackerFrame:SetAlpha(.6); local child=CreateFrame('Button',nil,ObjectiveTrackerFrame)
Q:SettingsChanged(); assert(ObjectiveTrackerFrame:GetAlpha()==0 and not child:IsMouseEnabled())
TEST.combat=true; FS:SetModuleEnabled('Quests',false); assert(ObjectiveTrackerFrame:GetAlpha()==0)
TEST.combat=false; Q.events.scripts.OnEvent(Q.events,'PLAYER_REGEN_ENABLED')
assert(ObjectiveTrackerFrame:GetAlpha()==.6 and child:IsMouseEnabled()); ObjectiveTrackerFrame=nil; FS:SetModuleEnabled('Quests',true)

-- TEST: Profile switching removes obsolete saved placement and resets keep a usable default profile
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles; local U=FS.modules.UnitFrames
P:Initialize(); FS.db.layout.frames['Unit:player']={x=400,y=500,scale=1}; FS.Layout:ApplyAll(); P:Save('Moved')
assert(P:Load('Default')); assert(U.frames.player.point[4]==-430 and U.frames.player.point[5]==224)
FS:ResetDatabase(); assert(FS.db.profiles.saved.Default and P:Load('Default'))

-- TEST: Sidebar modes, category counts and search keep unique inventory accounting
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags
TEST.data[1]={quality=1,price=1,classID=2,name='Sword'}; TEST.data[2]={quality=1,price=1,classID=7,name='Ore'}
AddItem(1,1,1); AddItem(2,2,20); B:ShowWindow(); local f=B.window
assert(f.title:GetText()=='INVENTORY   2 / 16' and tonumber(f.sidebarRows[1].count:GetText())==2, f.title:GetText())
assert(f.sidebarRows[1].entry.title=='All Items' and f.sidebarRows[4].entry.title=='Recent Items')
Click(f.sidebarRows[2]); assert(FS.db.bags.viewMode=='onebag' and f.headers[1].category=='OneBag' and #B.view.rows==2)
Click(f.sidebarRows[3]); assert(FS.db.bags.viewMode=='multibag' and f.headers[1].category=='Bag 0')
B:SelectView('categories','Gear'); assert(#B.view.rows==1 and f.cells[1].row.id==1)
f.search:SetText('ore'); f.search.scripts.OnTextChanged(f.search); assert(#B.view.rows==0)
B:SelectView('categories'); f.search:SetText(''); f.search.scripts.OnTextChanged(f.search)
assert(#B.view.rows==2 and not f.filter:IsShown())

-- TEST: Recent quick view duplicates only visuals, retains reviewed loot and expires
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,3); TEST.newItems['0:1']=true
B:ScanNewItems(); B:ShowWindow(); local f=B.window
assert(f.headers[1].category=='Recent' and #B.view.plan.items==1 and B.view.plan.units==3 and B.view.plan.value==30, tostring(f.headers[1].category)..' '..#B.view.plan.items..' '..B.view.plan.units..' '..B.view.plan.value..' '..tostring(B.view.plan.items[1].protection))
local copies=0; local recentCell
for _,cell in ipairs(f.cells) do if cell.row and cell.row.id==1 then copies=copies+1; recentCell=recentCell or cell end end
assert(copies==2 and recentCell:GetAttribute('item2')==nil, 'At a merchant secure use remains disabled')
recentCell.scripts.OnEnter(recentCell); B:ScanNewItems(); B:Refresh(); assert(#B:RecentRows(B.view)==1)
Click(f.recentToggle); assert(not FS.db.bags.showRecent and f.headers[1].category=='Favorites')
B:SelectView('recent'); assert(f.headers[1].category=='Recent' and f.cells[1].row.id==1 and not f.cells[2]:IsShown())
TEST.now=TEST.now+601; f.scripts.OnUpdate(f,10); assert(not f.cells[1]:IsShown() and f.noResults:IsShown())
TEST.newItems={}; B:SelectView('categories'); B:ScanNewItems(); AddItem(2,1,5); B:ScanNewItems(); assert(#B:RecentRows(B:BuildView())==2)

-- TEST: Custom category validation, selected assignment and saved reload retain safety priorities
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
TEST.data[1]={quality=1,price=10,classID=7}; AddItem(1,1,1); B:ShowWindow(); B.selected=V:ReadItem(0,1)
assert(B:AddCategory('  Raid supplies  ')); assert(B:Category(V:ReadItem(0,1))=='Raid supplies')
assert(not B:AddCategory('raid supplies') and not B:AddCategory('Recent') and not B:AddCategory('Bad|cff00ff00') and not B:AddCategory(''))
FS:InitializeDatabase(); assert(FS.db.bags.customCategories[1]=='Raid supplies' and FS.db.bags.categoryOverrides[1]=='Raid supplies')
B:SelectView('categories','Raid supplies'); assert(#B.view.rows==1 and B.window.headers[1].category=='Raid supplies')
V:SetRule(1,true,0,0); assert(B:Category(V:BuildPlan().bySlot['0:1'])=='Junk')
FS.db.bags.favorites[1]=true; assert(B:Category(V:BuildPlan().bySlot['0:1'])=='Favorites')
TEST.combat=true; assert(not B:AddCategory('Combat')); TEST.combat=false

-- TEST: Resizing follows cursor immediately, persists bounds and keeps content clear of footer
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
TEST.data[1]={quality=1,price=1,classID=2}; AddItem(1,1,1); B:ShowWindow(); local f=B.window
local originalCursor=GetCursorPosition; local x,y=100,100; GetCursorPosition=function() return x,y end
f.resize.scripts.OnMouseDown(f.resize,'LeftButton'); x,y=240,20; f.resize.scripts.OnUpdate(f.resize)
assert(FS.db.bags.width==960 and FS.db.bags.height==580 and f:GetWidth()==960 and f:GetHeight()==580)
f.resize.scripts.OnMouseUp(f.resize); assert(not f.resize.scripts.OnUpdate)
FS:InitializeDatabase(); assert(FS.db.bags.width==960 and FS.db.bags.height==580)
f.resize.scripts.OnMouseDown(f.resize,'LeftButton'); x,y=10000,-10000; f.resize.scripts.OnUpdate(f.resize)
assert(f:GetWidth()==1100 and f:GetHeight()==780)
f:Hide(); assert(not f.resize.scripts.OnUpdate and not B.resizeStart); GetCursorPosition=originalCursor
FS.db.bags.width=0/0; FS.db.bags.height=math.huge; B:NormalizeSettings(); assert(FS.db.bags.width==820 and FS.db.bags.height==500)
local rows={}; for i=1,350 do rows[i]={id=1,bag=0,slot=i,name='Gear',classID=2} end
for _,size in ipairs({{660,420},{820,500},{1100,780}}) do
 FS.db.bags.width,FS.db.bags.height=size[1],size[2]
 for _,merchant in ipairs({false,true}) do
  V.merchantOpen=merchant
  local count=0
  for _,page in ipairs(B:Layout({rows=rows})) do
   for _,entry in ipairs(page.cells) do
    assert(entry.x+38<=size[1]-224 and 100+entry.y+38<=size[2]-(merchant and 144 or 109)); count=count+1
   end
  end
  assert(count==350)
 end
end
FS.modules.Vendor.merchantOpen=false

-- TEST: Sidebar scrolling exposes every custom category and modal input closes with inventory
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; B:ShowWindow(); local f=B.window
for i=1,12 do assert(B:AddCategory('Group '..i)) end
assert(not B:AddCategory('Too many'))
f.sidebar.scripts.OnMouseWheel(f.sidebar,-99); assert(B.sidebarOffset==B.sidebarMax)
local found=false; for _,c in ipairs(f.sidebarRows) do if c.entry and c.entry.title=='Group 12' then found=true; Click(c) end end
assert(found and FS.db.bags.category=='Group 12')
Click(f.addCategory); assert(f.categoryDialog:IsShown()); f:Hide(); assert(not f.categoryDialog:IsShown())

-- TEST: Quest cards show real completion, objective progress, distance ordering, folding and every page
ResetTest(); local FS=ForeverSuite; local Q=FS.modules.Quests; Q.trackerPage=1; Q.focusID=nil
local quests={}
for i=1,7 do quests[i]={title='Quest '..i,questID=100+i,isHeader=false} end
C_QuestLog={GetNumQuestLogEntries=function() return #quests end,GetInfo=function(i) return quests[i] end,
 IsComplete=function(id) return id==102 end,GetDistanceSqToQuest=function(id) return (108-id)^2*100 end,
 GetQuestObjectives=function(id) return {{text='2/4 targets',finished=false,numFulfilled=2,numRequired=4,type='monster'},{text='1/1 item',finished=true,numFulfilled=1,numRequired=1,type='item'}} end}
Q:UpdateTracker(); local f=Q.tracker
assert(f.cards[1].row.id==107 and f.cards[1].progress.value==.75 and f.cards[1].distance:GetText()=='10y')
local initial=f:GetHeight(); Click(f.cards[1].fold); assert(FS.db.quests.collapsed[107] and f:GetHeight()<initial)
Click(f.cards[1].fold); assert(not FS.db.quests.collapsed[107])
Click(f.next); assert(Q.trackerPage==2); Click(f.next); assert(Q.trackerPage==3 and not f.cards[2]:IsShown())
FS.db.quests.hideComplete=true; Q:UpdateTracker(); assert(#Q:TrackerRows()==6 and Q.trackerPage==2)
local tracked; C_SuperTrack={SetSuperTrackedQuestID=function(id) tracked=id end}; C_QuestLog.AddQuestWatch=function() end
Q:Track(Q.byID[101]); assert(tracked==101 and Q.focusID==101)
TEST.combat=true; Q:Track(Q.byID[103]); assert(tracked==101); TEST.combat=false
for _,c in ipairs(f.cards) do if c:IsShown() then assert(-c.point[3]+c:GetHeight()<=f:GetHeight()-36) end end
C_QuestLog=nil; C_SuperTrack=nil; Q.focusID=nil; Q:UpdateTracker(); assert(f.empty:IsShown())

-- TEST: Quest map pins project real coordinates, cluster overlaps, rotate and clean disabled or unavailable data
ResetTest(); local FS=ForeverSuite; local Q=FS.modules.Quests; local oldMinimap=Minimap
Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(200,200)
C_Map={GetBestMapForUnit=function() return 12 end,GetPlayerMapPosition=function() return {GetXY=function() return .5,.5 end} end,GetMapWorldSize=function() return 1000,1000 end}
C_Minimap={GetViewRadius=function() return 100 end}; GetCVar=function() return '0' end
C_QuestLog={GetNumQuestLogEntries=function() return 2 end,GetInfo=function(i) return {title='Mapped '..i,questID=i,isHeader=false} end,
 GetQuestObjectives=function() return {{text='Find target',type='monster',finished=false}} end,
 GetQuestsOnMap=function() return {{questID=1,x=.55,y=.5},{questID=2,x=.551,y=.5},{questID=1,x=2,y=.5},{questID=99,x=.5,y=.5}} end,
 GetNextWaypoint=function() return 12,.55,.5 end}
Q:Build(); Q:UpdateQuestPins(); local pin=Q.minimapPins[1]
assert(pin:IsShown() and #pin.members==2 and not Q.minimapPins[2], 'Duplicate and nearby markers should collapse into one visible icon')
assert(math.abs(pin.point[4]-50)<.01 and pin.point[5]==0 and not pin.onEdge)
local x,y,edge=Q:MinimapOffset({x=.95,y=.5},.5,.5,1000,1000,100,nil)
assert(math.abs(x-85)<.01 and edge)
x,y=Q:MinimapOffset({x=.55,y=.5},.5,.5,1000,1000,100,math.pi/2); assert(math.abs(x)<.01 and math.abs(y+50)<.01)
local opened; QuestMapFrame_OpenToQuestDetails=function(id) opened=id end
Click(pin); assert(opened==1); Click(pin); assert(opened==2)
FS.db.quests.minimap=false; Q:UpdateQuestPins(); assert(not pin:IsShown())
FS.db.quests.minimap=true; C_Map.GetMapWorldSize=function() return nil end; Q:UpdateQuestPins(); assert(not pin:IsShown())
C_Map.GetMapWorldSize=function() return 1000,1000 end; FS:SetModuleEnabled('Quests',false); assert(not pin:IsShown())
C_Map=nil; C_Minimap=nil; C_QuestLog=nil; GetCVar=nil; QuestMapFrame_OpenToQuestDetails=nil; Minimap=oldMinimap; FS:SetModuleEnabled('Quests',true)

-- TEST: Native spellbook clears suite dialogs and sits below menu; suite dialogs hide native windows
ResetTest(); local FS=ForeverSuite; local W=FS.WindowManager
SpellBookFrame=CreateFrame('Frame',nil,UIParent); SpellBookFrame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',10,-10); SpellBookFrame:Hide()
W:Install(); FS:ShowConfig(); SpellBookFrame:Show(); assert(SpellBookFrame:GetAlpha()==0); Drain()
assert(SpellBookFrame:GetAlpha()==1 and FS.NativeWindows.windows[SpellBookFrame].enabled)
assert(not FS.window:IsShown() and SpellBookFrame.point[1]=='TOPLEFT' and SpellBookFrame.point[5]==-76)
FS:ShowPatchLog(); assert(not SpellBookFrame:IsShown() and FS.aboutWindow:IsShown())
SpellBookFrame:Show(); Drain(); assert(not FS.aboutWindow:IsShown())
FS:SetModuleEnabled('ActionBars',false); assert(SpellBookFrame.point[5]==-10)
FS:SetModuleEnabled('ActionBars',true); SpellBookFrame:Hide(); SpellBookFrame=nil
local previous=PlayerSpellsFrame
PlayerSpellsFrame=CreateFrame('Frame',nil,UIParent); local talents=PlayerSpellsFrame
talents:SetAlpha(.7); talents:Hide(); W:Install()
talents:Show(); assert(talents:GetAlpha()==0); Drain()
assert(talents:GetAlpha()==.7 and FS.NativeWindows.windows[talents].enabled)
talents:Hide(); talents:Show(); talents:Hide(); Drain(); assert(talents:GetAlpha()==.7)
TEST.combat=true; talents:Show(); assert(talents:GetAlpha()==.7)
talents:Hide(); TEST.combat=false; Drain(); PlayerSpellsFrame=previous

-- TEST: Own XP bar replaces native overlapping strips and restores native input on disable
ResetTest(); local FS=ForeverSuite; local W=FS.WindowManager
StatusTrackingBarManager=CreateFrame('Frame',nil,UIParent); StatusTrackingBarManager:SetAlpha(.7)
local child=CreateFrame('Button',nil,StatusTrackingBarManager); child:EnableMouse(true)
UnitXP=function() return 250 end; UnitXPMax=function() return 1000 end
W:UpdateExperience(); assert(StatusTrackingBarManager:GetAlpha()==0 and not child:IsMouseEnabled())
assert(W.experience:IsShown() and W.experience.bar.value==250 and W.experience.text:GetText()=='XP  25%')
assert(W.experience.point[2]==(MainActionBar or MainMenuBar) and W.experience.point[5]==-6)
TEST.combat=true; FS:SetModuleEnabled('ActionBars',false); assert(StatusTrackingBarManager:GetAlpha()==0)
TEST.combat=false; FS.modules.ActionBars.events.scripts.OnEvent(FS.modules.ActionBars.events,'PLAYER_REGEN_ENABLED')
assert(StatusTrackingBarManager:GetAlpha()==.7 and child:IsMouseEnabled() and not W.experience:IsShown())
StatusTrackingBarManager=nil; UnitXP=nil; UnitXPMax=nil; FS:SetModuleEnabled('ActionBars',true)

-- TEST: V toggles recover pooled nameplates without target updates resetting game visibility
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
local vars={nameplateShowEnemies='1',nameplateShowFriends='0',nameplateShowFriendlyPlayers='0',nameplateShowFriendlyNPCs='0'}
GetCVar=function(key) return vars[key] end; local writes=0
SetCVar=function(key,value) vars[key]=value; writes=writes+1 end
local plate=CreateFrame('Frame',nil,UIParent); plate.namePlateUnitToken='target'; plate.UnitFrame=CreateFrame('Frame',nil,plate)
C_NamePlate={GetNamePlates=function() return {plate} end}; TEST.units.target.enemy=true
N:SettingsChanged(); local canvas=N.custom[plate].canvas; assert(canvas:IsShown())
vars.nameplateShowEnemies='0'; N.events.scripts.OnEvent(N.events,'CVAR_UPDATE','nameplateShowEnemies'); Drain()
assert(not canvas:IsShown() and not FS.db.nameplates.enemies)
local before=writes; N.events.scripts.OnEvent(N.events,'PLAYER_TARGET_CHANGED'); assert(writes==before and vars.nameplateShowEnemies=='0')
plate:Hide(); vars.nameplateShowEnemies='1'; N.events.scripts.OnEvent(N.events,'CVAR_UPDATE','nameplateShowEnemies'); plate:Show(); Drain()
assert(canvas:IsShown() and FS.db.nameplates.enemies and plate.UnitFrame:GetAlpha()==0)
EnterCombat(); vars.nameplateShowEnemies='0'; N.events.scripts.OnEvent(N.events,'CVAR_UPDATE','nameplateShowEnemies'); Drain(); assert(not canvas:IsShown())
vars.nameplateShowEnemies='1'; N.events.scripts.OnEvent(N.events,'CVAR_UPDATE','nameplateShowEnemies'); Drain(); assert(canvas:IsShown())
TEST.combat=false; N:Release(N.custom[plate]); C_NamePlate=nil; GetCVar=nil; SetCVar=nil; N.originalCVars=nil

-- TEST: World-map quest markers use canvas coordinates, completion icons and clear removed quests
ResetTest(); local FS=ForeverSuite; local Q=FS.modules.Quests; local originalMap=WorldMapFrame
WorldMapFrame=CreateFrame('Frame',nil,UIParent); WorldMapFrame.ScrollContainer={Child=CreateFrame('Frame',nil,WorldMapFrame)}
local canvas=WorldMapFrame.ScrollContainer.Child; canvas:SetSize(200,300); WorldMapFrame.GetMapID=function() return 12 end
local ids={1,2}
C_QuestLog={GetNumQuestLogEntries=function() return #ids end,GetInfo=function(i) return {title='World '..ids[i],questID=ids[i]} end,
 GetQuestObjectives=function() return {} end,IsComplete=function(id) return id==2 end,
 GetQuestsOnMap=function() return {{questID=1,x=.2,y=.3},{questID=2,x=.8,y=.7},{questID=3,x=.4,y=.4}} end}
Q:Build(); Q:UpdateQuestPins(); local first=Q.worldPins[1]; local second=Q.worldPins[2]
assert(first:IsShown() and second:IsShown() and first.point[4]==40 and first.point[5]==-90)
assert(second.location.row.complete and Q:PinIcon(second.location.row)=='Reputation')
ids={1}; Q:Build(); Q:UpdateQuestPins(); assert(first:IsShown() and not second:IsShown())
FS.db.quests.worldMap=false; Q:UpdateQuestPins(); assert(not first:IsShown())
C_QuestLog=nil; WorldMapFrame:Hide(); WorldMapFrame=originalMap

-- TEST: Character and backpack coexist in both opening orders and bag drag reaches the native equipment slot
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local C=FS.modules.Character
TEST.data[901]={quality=1,price=1,classID=4}; AddItem(1,901,1)
B:ShowWindow(); CharacterFrame:Show(); assert(B.window:IsShown() and CharacterFrame:IsShown() and C.root:IsShown())
assert(CharacterFrame:GetAlpha()==0); Drain(); assert(CharacterFrame:GetAlpha()==1)
CharacterFrame:Hide(); assert(B.window:IsShown()); B.window:Hide()
CharacterFrame:Show(); B:ShowWindow(); assert(B.window:IsShown() and CharacterFrame:IsShown())
local cell; for _,button in ipairs(B.window.cells) do if button.row and button.row.id==901 then cell=button; break end end
cell.scripts.OnDragStart(cell); assert(TEST.cursor and TEST.cursor.itemID==901)
local original=PickupInventoryItem; local equipped
PickupInventoryItem=function(slot) equipped=slot; TEST.cursor=nil end
C.slots[5].scripts.OnReceiveDrag(C.slots[5]); assert(equipped==5 and not TEST.cursor)
TEST.combat=true; equipped=nil; C.slots[5].scripts.OnReceiveDrag(C.slots[5]); assert(not equipped); TEST.combat=false
PickupInventoryItem=original
B.window:Hide(); assert(CharacterFrame:IsShown()); B:ShowWindow()
FS:ShowConfig(); assert(not B.window:IsShown() and not CharacterFrame:IsShown() and FS.window:IsShown())
CharacterFrame:Show(); B:ShowWindow(); FS:ShowPatchLog(); assert(not B.window:IsShown() and not CharacterFrame:IsShown())

-- TEST: Every Character secondary page contains external anchors and restores them on exit
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character
CharacterFrame:Show()
for index=2,#C.pages do
 local name=C.pages[index].frame; local original=_G[name]
 local native=CreateFrame('Frame',nil,CharacterFrame); native:SetSize(700,560); native:SetScale(1)
 _G[name]=native
 local title=native:CreateFontString(nil,'OVERLAY'); title:SetPoint('TOP',CharacterFrame,'TOP',0,-20)
 local control=CreateFrame('CheckButton',nil,native); control:SetPoint('BOTTOMLEFT',CharacterFrame,'BOTTOMLEFT',20,24)
 CharacterFrame.activeSubframe=name; C:Apply()
 assert(native:GetParent()==C.content and C.content.clipsChildren)
 assert(native:GetHeight()*native:GetScale()<=416.001 and native:GetWidth()*native:GetScale()<=732.001)
 assert(title.point[2]==native and control.point[2]==native, 'Header and footer widgets must anchor inside the page')
 control:SetPoint('BOTTOMLEFT',CharacterFrame,'BOTTOMLEFT',30,30)
 assert(control.point[2]==native, 'Native refresh must not restore an outside anchor')
 C:RestoreMounted()
 assert(native:GetParent()==CharacterFrame and native:GetHeight()==560 and native:GetScale()==1)
 assert(title.point[2]==CharacterFrame and control.point[2]==CharacterFrame)
 native:Hide(); _G[name]=original
end
CharacterFrame.activeSubframe='PaperDollFrame'; C:Apply(); CharacterFrame:Hide()

-- TEST: Character native list and detail hosts stay distinct and pooled rows retain consistent fonts
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character
CharacterFrameLeftPaneHost=CreateFrame('Frame','CharacterFrameLeftPaneHost',CharacterFrame)
CharacterFrameRightPaneHost=CreateFrame('Frame','CharacterFrameRightPaneHost',CharacterFrame)
local old=SkillsFrame; SkillsFrame=CreateFrame('Frame',nil,CharacterFrame); SkillsFrame:SetSize(631,540)
local list=CreateFrame('Frame',nil,SkillsFrame); list:SetPoint('TOPLEFT',CharacterFrameLeftPaneHost,'TOPLEFT',10,-40)
local details=CreateFrame('Frame',nil,SkillsFrame); details:SetPoint('TOPLEFT',CharacterFrameRightPaneHost,'TOPLEFT',16,-14)
CharacterFrame.activeSubframe='SkillsFrame'; CharacterFrame:Show(); C:Apply()
local hosts=C.mounted.hosts
assert(list.point[2]==hosts.left and details.point[2]==hosts.right and hosts.left~=hosts.right)
assert(hosts.right:GetWidth()==233 and hosts.right.point[4]==SkillsFrame:GetWidth()-233)
local row=CreateFrame('Frame',nil,list); local text=row:CreateFontString(nil,'OVERLAY'); text:SetFont('old',9,'')
SkillsFrame.scripts.OnUpdate(SkillsFrame,.3)
local font,size=text:GetFont(); assert(font==FS.font and size==12)
details:SetPoint('TOPLEFT',CharacterFrameRightPaneHost,'TOPLEFT',16,-14); assert(details.point[2]==hosts.right)
C:RestoreMounted(); assert(list.point[2]==CharacterFrameLeftPaneHost and details.point[2]==CharacterFrameRightPaneHost)
assert(not hosts.left:IsShown() and not hosts.right:IsShown())
SkillsFrame:Hide(); SkillsFrame=old; CharacterFrameLeftPaneHost=nil; CharacterFrameRightPaneHost=nil
CharacterFrame.activeSubframe='PaperDollFrame'; C:Apply(); CharacterFrame:Hide()

-- TEST: Move Frames resize grips follow cursor, preserve position, clamp and cancel
ResetTest(); local FS=ForeverSuite; local L=FS.Layout
local original=GetCursorPosition; local x,y=100,100; GetCursorPosition=function() return x,y end
L:Start(); local id='Unit:player'; local h=L.handles[id]; local f=L.targets[id].frame
local before=f:GetScale(); assert(h.resize:IsShown())
h.resize.scripts.OnMouseDown(h.resize,'LeftButton'); x=120; y=80
h.resize.scripts.OnUpdate(h.resize,.01); assert(f:GetScale()>before and FS.db.layout.frames[id].scale==f:GetScale())
local pos=FS.db.layout.frames[id]; local px,py=pos.x,pos.y
local originalCenter=h.GetCenter; h.GetCenter=function() return 9000,8000 end
x=10000; h.resize.scripts.OnUpdate(h.resize,.01); assert(f:GetScale()==1.4)
x=-10000; h.resize.scripts.OnUpdate(h.resize,.01); assert(f:GetScale()==.6)
assert(FS.db.layout.frames[id].x==px and FS.db.layout.frames[id].y==py)
h.resize.scripts.OnMouseUp(h.resize,'LeftButton'); h.GetCenter=originalCenter; assert(not h.resizeStart)
Click(L.overlay.close); assert(f:GetScale()==before and not L.active)
L:Start(); h.resize.scripts.OnDragStart(h.resize); EnterCombat(); h.resize.scripts.OnUpdate(h.resize,.01)
assert(not L.active and not h.resizeStart); TEST.combat=false; GetCursorPosition=original

-- TEST: Skills and PvP use full readable viewport and suite progress bars without changing values
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character
for _,index in ipairs({3,4}) do
 local name=C.pages[index].frame; local original=_G[name]
 local page=CreateFrame('Frame',nil,CharacterFrame); page:SetSize(780,580); _G[name]=page
 local bar=CreateFrame('StatusBar',nil,page); bar:SetMinMaxValues(0,75); bar:SetValue(3)
 local text=bar:CreateFontString(nil,'OVERLAY'); text:SetText('3 / 75')
 CharacterFrame.activeSubframe=name; CharacterFrame:Show(); C:Apply()
 assert(page:GetScale()==1 and page:GetWidth()==732 and page:GetHeight()==416)
 assert(C.mounted.hosts.left:GetWidth()+C.mounted.hosts.right:GetWidth()==732)
 assert(bar.value==3 and bar.maximum==75); local _,size=text:GetFont(); assert(size==12)
 C:RestoreMounted(); assert(page:GetWidth()==780 and page:GetHeight()==580)
 page:Hide(); _G[name]=original
end
CharacterFrame.activeSubframe='PaperDollFrame'; C:Apply(); CharacterFrame:Hide()

-- TEST: Suite style groups bars without replacing native clicks, icons, class colors or saved gear placement
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local A=FS.modules.ActionBars
FS.initialized=true; A:SettingsChanged(); FS.modules.Gear:SettingsChanged(); S:Refresh()
assert(S.plates[A.menuRoot]:IsShown() and FS.modules.UnitFrames.frames.player.fsPortraitRim)
local native=ActionButton1; local calls=0; native:SetScript('OnClick',function() calls=calls+1 end)
S:Feedback(native); Click(native); assert(calls==1)
local icon=CharacterBag0Slot and (CharacterBag0Slot.icon or CharacterBag0Slot.Icon); local tex=icon and icon:GetTexture()
S:Bars(); if icon then assert(icon:GetTexture()==tex) end
FS.db.layout.frames.GearButton={x=-123,y=55,scale=1}; FS.Layout:Apply('GearButton'); S:Bars()
assert(FS.modules.Gear.indicator.point[4]==-123)
FS:SetModuleEnabled('ActionBars',false); S:Refresh(); assert(not S.plates[A.menuRoot]:IsShown())
FS:SetModuleEnabled('ActionBars',true)

-- TEST: Suite minimap and chat style restore native art and fonts when modules are disabled
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local oldMap=Minimap; local oldChat=ChatFrame1
Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(140,140)
MinimapBorder=Minimap:CreateTexture(nil,'OVERLAY'); MinimapBorder:SetAlpha(.7)
MinimapZoneTextButton=CreateFrame('Button',nil,Minimap)
ChatFrame1=CreateFrame('ScrollingMessageFrame',nil,UIParent); ChatFrame1:SetFont('original',14,'')
ChatFrame1Tab=CreateFrame('Button',nil,ChatFrame1); local text=ChatFrame1Tab:CreateFontString(nil,'OVERLAY'); text:SetFont('original',12,'')
S.minimap=nil; S.mapRim=nil; S:Refresh()
assert(S.minimap:IsShown() and MinimapBorder:GetAlpha()==0 and S.plates[ChatFrame1]:IsShown())
local font=ChatFrame1:GetFont(); assert(font==FS.font)
FS:SetModuleEnabled('Map',false); FS:SetModuleEnabled('Chat',false); S:Refresh()
assert(not S.minimap:IsShown() and MinimapBorder:GetAlpha()==.7 and not S.plates[ChatFrame1]:IsShown())
assert(ChatFrame1:GetFont()=='original')
S.minimap:Hide(); S.mapRim:Hide(); S.minimap=nil; S.mapRim=nil; Minimap=oldMap; ChatFrame1=oldChat
MinimapBorder=nil; MinimapZoneTextButton=nil; ChatFrame1Tab=nil; FS:SetModuleEnabled('Map',true); FS:SetModuleEnabled('Chat',true)

-- TEST: Native damage meter receives suite styling while values and class colors remain untouched
ResetTest(); local FS=ForeverSuite; local S=FS.Style
DamageMeter=CreateFrame('Frame',nil,UIParent); local session=CreateFrame('Frame',nil,DamageMeter)
DamageMeter.windowDataList={}; DamageMeter.ForEachSessionWindow=function(_,fn) fn(session) end
session.Background=session:CreateTexture(nil,'BACKGROUND'); session.Background:SetAlpha(.6)
local bar=CreateFrame('StatusBar',nil,session); bar:SetStatusBarTexture('original'); bar:SetStatusBarColor(.2,.7,.3,1); bar:SetMinMaxValues(0,100); bar:SetValue(65)
local text=bar:CreateFontString(nil,'OVERLAY'); text:SetText('Player 65')
S:Refresh(); assert(S.plates[session]:IsShown() and session.Background:GetAlpha()==0)
assert(bar.barTexture==FS.HUD.texture and bar.value==65 and bar.barColor[2]==.7 and text:GetText()=='Player 65')
FS:SetModuleEnabled('Combat',false); S:Refresh(); assert(bar.barTexture=='original' and session.Background:GetAlpha()==.6 and not S.plates[session]:IsShown())
DamageMeter:Hide(); DamageMeter=nil; FS:SetModuleEnabled('Combat',true)

-- TEST: XP follows main bar, hides text until hover and bounds rested segment to the next level
ResetTest(); local FS=ForeverSuite; local W=FS.WindowManager
UnitXP=function() return 250 end; UnitXPMax=function() return 1000 end; GetXPExhaustion=function() return 2000 end
W:UpdateExperience(); local f=W.experience; assert(f.point[2]==(MainActionBar or MainMenuBar) and not f.text:IsShown())
assert(f.rested:IsShown() and f.rested:GetWidth()==f:GetWidth()*.75 and f.rested.point[4]==f:GetWidth()*.25)
f.scripts.OnEnter(f); assert(f.text:IsShown()); f.scripts.OnLeave(f); assert(not f.text:IsShown())
GetXPExhaustion=function() return 0 end; W:UpdateExperience(); assert(not f.rested:IsShown())
TEST.combat=true; FS.Style:Refresh(); TEST.combat=false
UnitXP=nil; UnitXPMax=nil; GetXPExhaustion=nil

-- TEST: Minimap rim fits its owner, modern duplicate header restores and menu width matches icon count
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local A=FS.modules.ActionBars
local old=Minimap; Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(198,198)
MinimapCluster={BorderTop=CreateFrame('Frame',nil,UIParent),ZoneTextButton=CreateFrame('Button',nil,UIParent)}
MinimapCompassTexture=Minimap:CreateTexture(nil,'OVERLAY'); MinimapCompassTexture:SetAlpha(.8)
S.minimap=nil; S.mapRim=nil; S:Minimap()
assert(S.mapRim.texture=='Interface\\AddOns\\ForeverSuite\\Assets\\Minimap-Rim.tga' and S.mapRim.point[2]==Minimap)
assert(MinimapCompassTexture:GetAlpha()==0 and MinimapCluster.BorderTop:GetAlpha()==0 and MinimapCluster.ZoneTextButton:GetAlpha()==0)
FS:SetModuleEnabled('Map',false); S:Minimap(); assert(MinimapCompassTexture:GetAlpha()==.8 and MinimapCluster.BorderTop:GetAlpha()==1)
S.minimap:Hide(); S.mapRim:Hide(); S.minimap=nil; S.mapRim=nil; Minimap=old; MinimapCluster=nil; MinimapCompassTexture=nil; FS:SetModuleEnabled('Map',true)
A:SettingsChanged(); local count=0; for _,state in pairs(A.menuButtons) do if state.slot and state.proxy:IsShown() then count=count+1 end end
assert(A.menuRoot:GetWidth()==math.max(36,count*41-5))
S:Bars(); local bag=BagsBar or MainMenuBarBagButtons; if bag then assert(S.plates[bag].point[2]==bag) end

-- TEST: Damage meter texture headers and compact controls preserve native clicks and restore art
ResetTest(); local FS=ForeverSuite; local S=FS.Style
DamageMeterSessionWindow1=CreateFrame('Frame',nil,UIParent); local f=DamageMeterSessionWindow1
f.Header=f:CreateTexture(nil,'BACKGROUND'); f.Header:SetAlpha(.7)
local clicks=0
for _,key in ipairs({'DamageMeterTypeDropdown','SettingsDropdown','MinimizeButton','SessionDropdown'}) do
 local b=CreateFrame('Button',nil,f); f[key]=b; b.normalRegion=b:CreateTexture(nil,'ARTWORK'); b:SetScript('OnClick',function() clicks=clicks+1 end)
end
local row=CreateFrame('Button',nil,f); row:SetScript('OnClick',function() clicks=clicks+1 end)
S:Meter(); assert(f.Header:GetAlpha()==0 and f.fsMeterHeader:IsShown())
assert(not S.plates[f.SettingsDropdown].gold:IsShown() and not S.plates[f.SettingsDropdown].cyan:IsShown())
for _,key in ipairs({'DamageMeterTypeDropdown','SettingsDropdown','MinimizeButton','SessionDropdown'}) do Click(f[key]) end
Click(row); assert(clicks==5 and not S.plates[row])
FS:SetModuleEnabled('Combat',false); S:Meter(); assert(f.Header:GetAlpha()==.7 and not f.fsMeterHeader:IsShown() and not f.SettingsDropdown.fsMeterGlyph:IsShown())
f:Hide(); DamageMeterSessionWindow1=nil; FS:SetModuleEnabled('Combat',true)

-- TEST: Chat tabs and edit field replace native textures without intercepting input and restore on disable
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local old=ChatFrame1
ChatFrame1=CreateFrame('ScrollingMessageFrame',nil,UIParent)
ChatFrame1Tab=CreateFrame('Button',nil,UIParent); local tabArt=ChatFrame1Tab:CreateTexture(nil,'BACKGROUND'); tabArt:SetAlpha(.5)
ChatFrame1EditBox=CreateFrame('EditBox',nil,UIParent); local art=ChatFrame1EditBox:CreateTexture(nil,'BACKGROUND'); art:SetAlpha(.8)
local text=ChatFrame1EditBox:CreateFontString(nil,'OVERLAY'); text:SetText('message')
S:Chat(); assert(art:GetAlpha()==0 and tabArt:GetAlpha()==0 and text:GetText()=='message')
assert(not S.plates[ChatFrame1EditBox]:IsMouseEnabled() and not S.plates[ChatFrame1Tab].gold:IsShown())
FS:SetModuleEnabled('Chat',false); S:Chat(); assert(art:GetAlpha()==.8 and tabArt:GetAlpha()==.5 and not S.plates[ChatFrame1EditBox]:IsShown())
ChatFrame1EditBox:Hide(); ChatFrame1Tab:Hide(); ChatFrame1=old; ChatFrame1Tab=nil; ChatFrame1EditBox=nil; FS:SetModuleEnabled('Chat',true)

-- TEST: Minimap cluster has a resize grip and saved scale survives native reset, cancel and combat
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; local old=MinimapCluster
MinimapCluster=CreateFrame('Frame',nil,UIParent); MinimapCluster:SetSize(256,256); MinimapCluster:SetScale(1); MinimapCluster:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',0,0)
L.targets.Minimap=nil; L.handles.Minimap=nil
local original=GetCursorPosition; local x,y=100,100; GetCursorPosition=function() return x,y end
L:Start(); local h=L.handles.Minimap; assert(h and h.resize:IsShown() and L.targets.Minimap.frame==MinimapCluster)
h.resize.scripts.OnMouseDown(h.resize,'LeftButton'); x=120; y=80; h.resize.scripts.OnUpdate(h.resize,.1)
local scale=MinimapCluster:GetScale(); assert(scale>1 and FS.db.layout.frames.Minimap.scale==scale)
h.resize.scripts.OnMouseUp(h.resize,'LeftButton'); L:Stop()
MinimapCluster:SetScale(1); Drain(); assert(MinimapCluster:GetScale()==scale)
L:Start(); h.resize.scripts.OnMouseDown(h.resize,'LeftButton'); x=0; h.resize.scripts.OnUpdate(h.resize,.1); Click(L.overlay.close)
assert(MinimapCluster:GetScale()==scale)
L:Start(); EnterCombat(); L:Stop(); assert(not h.resizeStart and not L.active); TEST.combat=false
GetCursorPosition=original; MinimapCluster:Hide(); MinimapCluster=old; L.targets.Minimap=nil; L.handles.Minimap=nil; FS.db.layout.frames.Minimap=nil

-- TEST: Standalone clock defaults bottom center, keeps saved placement and hides the minimap time
ResetTest(); local FS=ForeverSuite; local S=FS.Style
S:Clock(18,56,true); assert(S.clock.text:GetText()=='18:56' and S.clock:IsShown())
assert(FS.Layout.targets.Clock.frame==S.clock)
FS.db.layout.frames.Clock={x=120,y=40,scale=1.2}; FS.Layout:Apply('Clock'); S:Clock(0,5,true)
assert(S.clock.text:GetText()=='00:05' and S.clock.point[4]*1.2==120 and S.clock:GetScale()==1.2)
S:Clock(0,5,false); assert(not S.clock:IsShown())
FS.db.layout.frames.Clock=nil; S.clock:ClearAllPoints(); S.clock:SetPoint('BOTTOM',UIParent,'BOTTOM',0,12); S.clock:SetScale(1)

-- TEST: Duplicate Ellesmere coordinate label is hidden only while suite coordinates are enabled
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local old=Minimap
Minimap=CreateFrame('Frame',nil,UIParent); S.minimap=nil; S.mapRim=nil
_EBS_CoordFrame=Minimap:CreateFontString(nil,'OVERLAY'); _EBS_CoordFrame:SetAlpha(.9)
S:Minimap(); assert(_EBS_CoordFrame:GetAlpha()==0)
FS.db.map.coordinates=false; S:Minimap(); assert(_EBS_CoordFrame:GetAlpha()==.9)
FS.db.map.coordinates=true; S:Minimap(); assert(_EBS_CoordFrame:GetAlpha()==0)
FS:SetModuleEnabled('Map',false); S:Minimap(); assert(_EBS_CoordFrame:GetAlpha()==.9)
assert(S.minimap.zone.font[1]=='Interface\\AddOns\\ForeverSuite\\Assets\\Arial-Bold.ttf')
S.minimap:Hide(); S.mapRim:Hide(); S.minimap=nil; S.mapRim=nil; _EBS_CoordFrame=nil; Minimap=old; FS:SetModuleEnabled('Map',true)

-- TEST: Local clock ignores server timezone and coordinate duplicates cannot be re-enabled by another addon
ResetTest(); local FS=ForeverSuite; local S=FS.Style; local old=Minimap; local oldDate=date
Minimap=CreateFrame('Frame',nil,UIParent); S.minimap=nil; S.mapRim=nil
local extra=Minimap:CreateFontString(nil,'OVERLAY'); extra:SetText('43.3, 23.5'); extra:SetAlpha(.8)
local name=Minimap:CreateFontString(nil,'OVERLAY'); name:SetText('Thendal Village')
date=function(format) assert(format=='*t'); return {hour=22,min=25} end
GetGameTime=function() return 13,24 end
S:Minimap(); assert(S.clock.text:GetText()=='22:25' and extra:GetAlpha()==0 and name:GetAlpha()==1)
extra:SetAlpha(1); assert(extra:GetAlpha()==0)
FS.db.map.coordinates=false; S:Minimap(); assert(extra:GetAlpha()==.8)
FS.db.map.coordinates=true; FS:SetModuleEnabled('Map',false); S:Minimap(); assert(extra:GetAlpha()==.8)
S.minimap:Hide(); S.mapRim:Hide(); S.minimap=nil; S.mapRim=nil; Minimap=old; date=oldDate; GetGameTime=nil; FS:SetModuleEnabled('Map',true)

-- TEST: Contacts styling keeps friend and raid actions, disabled controls, icons and original restoration
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=FriendsFrame; local oldTarget=FS.Layout.targets.FriendsFrame
FS.Layout.targets.FriendsFrame=nil
FriendsFrame=CreateFrame('Frame','FriendsFrame',UIParent); local f=FriendsFrame
f.NineSlice=CreateFrame('Frame',nil,f); local border=f.NineSlice:CreateTexture(); border:SetTexture(123456)
f.Background=f:CreateTexture(); f.Background:SetAlpha(.6)
local status=f:CreateTexture(); status:SetTexture('online'); f.Status=status
local clicks=0
for _,name in ipairs({'Friends','Recent Allies','Raid','Add Friend','Send Message'}) do
 local b=CreateFrame('Button',nil,f); local t=b:CreateFontString(nil,'OVERLAY'); b:SetFontString(t); b:SetText(name)
 b.normalRegion=b:CreateTexture(nil,'BACKGROUND'); b:SetScript('OnClick',function() clicks=clicks+1 end)
 if name=='Send Message' then b:SetEnabled(false) end
 b:Click()
end
f.CloseButton=CreateFrame('Button',nil,f); f.CloseButton.Icon=f.CloseButton:CreateTexture(); f.CloseButton:SetScript('OnClick',function() f:Hide() end)
N:Refresh(); assert(clicks==4 and f.Background:GetAlpha()==0 and border:GetAlpha()==0 and status:GetTexture()=='online' and status:GetAlpha()==1)
assert(N.windows[f].header:IsShown() and FS.Layout.targets.FriendsFrame.frame==f and N.controls[f.CloseButton].glyph:GetText()=='X' and f.CloseButton.Icon:GetAlpha()==0)
f.Background:SetAlpha(1); assert(f.Background:GetAlpha()==0)
FS:SetModuleEnabled('Social',false); N:Refresh(); assert(f.Background:GetAlpha()==.6 and border:GetAlpha()==1 and not N.windows[f].header:IsShown())
f.CloseButton:Click(); assert(not f:IsShown()); FriendsFrame=old; FS.Layout.targets.FriendsFrame=oldTarget; FS:SetModuleEnabled('Social',true)

-- TEST: Professions and spellbook keep progress values, spell icons, paging and native drag actions
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local saved={ProfessionsBookFrame,SpellBookFrame}
ProfessionsBookFrame=CreateFrame('Frame','ProfessionsBookFrame',UIParent); local f=ProfessionsBookFrame
local b=CreateFrame('CheckButton',nil,f); b.IconTexture=b:CreateTexture(); b.IconTexture.layer='BORDER'; b.IconTexture:SetTexture(134400)
b.normalRegion=b:CreateTexture(); b:SetChecked(true); b:SetScript('OnDragStart',function() TEST.profDragged=true end)
local bar=CreateFrame('StatusBar',nil,f); bar:SetStatusBarTexture('native-fill'); bar:SetMinMaxValues(0,75); bar:SetValue(3); bar:SetStatusBarColor(.2,.7,.9)
local fill=bar:GetStatusBarTexture(); bar.GetStatusBarTexture=function() return fill end
SpellBookFrame=CreateFrame('Frame','SpellBookFrame',UIParent); local book=SpellBookFrame
local title=book:CreateFontString(); title.GetTextColor=function(self) return unpack(self.textColor or {0,0,0,1}) end
title.SetTextColor=function(self,...) self.textColor={...} end; title:SetText('General')
book.NextPageButton=CreateFrame('Button',nil,book); book.NextPageButton:SetScript('OnClick',function() TEST.spellPage=(TEST.spellPage or 1)+1 end)
N:Refresh(); assert(b.IconTexture:GetAlpha()==1 and b.normalRegion:GetAlpha()==0 and N.controls[b].plate:IsShown())
assert(bar.barTexture==FS.HUD.texture and bar.value==3 and bar.maximum==75 and bar.barColor[2]==.7 and fill:GetAlpha()==1)
assert(title.font[1]==FS.font and title.textColor[1]==.9 and N.controls[book.NextPageButton].glyph:GetText()=='>')
book.NextPageButton:Click(); b.scripts.OnDragStart(); assert(TEST.spellPage==2 and TEST.profDragged)
FS:SetModuleEnabled('Professions',false); FS:SetModuleEnabled('ActionBars',false); N:Refresh()
assert(bar.barTexture=='native-fill' and b.normalRegion:GetAlpha()==1 and title.font[1]=='Fonts\\FRIZQT__.TTF' and title.textColor[1]==0)
f:Hide(); book:Hide(); ProfessionsBookFrame,SpellBookFrame=unpack(saved); FS:SetModuleEnabled('Professions',true); FS:SetModuleEnabled('ActionBars',true)

-- TEST: Achievements guild and appearances retain filters tab dispatch model content and pooled rows
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local saved={AchievementFrame,CommunitiesFrame,CollectionsJournal,WardrobeFrame}
AchievementFrame=CreateFrame('Frame','AchievementFrame',UIParent); CommunitiesFrame=CreateFrame('Frame','CommunitiesFrame',UIParent); CollectionsJournal=CreateFrame('Frame','CollectionsJournal',UIParent)
WardrobeFrame=CreateFrame('Frame','WardrobeFrame',CollectionsJournal)
local model=CreateFrame('DressUpModel',nil,WardrobeFrame); local scene=model:CreateTexture(); scene:SetTexture('model-content'); scene.layer='BACKGROUND'
local actions=0
for _,f in ipairs({AchievementFrame,CommunitiesFrame,CollectionsJournal}) do
 f.Background=f:CreateTexture(); local filter=CreateFrame('Button',nil,f); filter:SetScript('OnClick',function() actions=actions+1 end); filter:Click()
end
N:Refresh(); assert(actions==3 and not N.windows[WardrobeFrame] and scene:GetAlpha()==1 and scene:GetTexture()=='model-content')
local row=CreateFrame('Button',nil,AchievementFrame); local label=row:CreateFontString(); label:SetText('New achievement'); row.normalRegion=row:CreateTexture(); row:SetScript('OnClick',function() TEST.achSelected=true end)
AchievementFrame:Hide(); AchievementFrame:Show(); assert(label.font[1]==FS.font and row.normalRegion:GetAlpha()==0); row:Click(); assert(TEST.achSelected)
AchievementFrame:Hide(); CommunitiesFrame:Hide(); CollectionsJournal:Hide(); AchievementFrame,CommunitiesFrame,CollectionsJournal,WardrobeFrame=unpack(saved)

-- TEST: World map skin preserves canvas tiles native and addon pins and quest actions
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=WorldMapFrame
WorldMapFrame=CreateFrame('Frame','WorldMapFrame',UIParent); local f=WorldMapFrame
f.BorderFrame=CreateFrame('Frame',nil,f); f.BorderFrame.NineSlice=CreateFrame('Frame',nil,f.BorderFrame)
local chrome=f.BorderFrame.NineSlice:CreateTexture(); chrome:SetTexture(23456)
f.ScrollContainer=CreateFrame('ScrollFrame',nil,f); local tile=f.ScrollContainer:CreateTexture(); tile.layer='BACKGROUND'; tile:SetTexture(765432)
local pin=CreateFrame('Button',nil,f.ScrollContainer); pin.normalRegion=pin:CreateTexture(); pin:SetScript('OnClick',function() TEST.mapPin=true end)
local addon=CreateFrame('Frame',nil,f.ScrollContainer); local custom=addon:CreateTexture(); custom:SetTexture('custom-pin')
local quest=CreateFrame('Button',nil,f); quest:SetScript('OnClick',function() TEST.mapQuest=true end)
N:Refresh(); assert(chrome:GetAlpha()==0 and tile:GetAlpha()==1 and not N.controls[pin] and custom:GetTexture()=='custom-pin' and custom:GetAlpha()==1)
pin:Click(); quest:Click(); assert(TEST.mapPin and TEST.mapQuest)
FS:SetModuleEnabled('Map',false); N:Refresh(); assert(chrome:GetAlpha()==1 and tile:GetAlpha()==1 and not N.windows[f].header:IsShown())
f:Hide(); WorldMapFrame=old; FS:SetModuleEnabled('Map',true)

-- TEST: Native skin loading respects combat forbidden subtrees and interactive NineSlice children
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=ContactsFrame
ContactsFrame=CreateFrame('Frame','ContactsFrame',UIParent); local f=ContactsFrame
f.NineSlice=CreateFrame('Frame',nil,f); local close=CreateFrame('Button',nil,f.NineSlice); close:SetScript('OnClick',function() TEST.nineClick=true end)
local blocked=CreateFrame('Frame',nil,f); blocked.IsForbidden=function() return true end; local art=blocked:CreateTexture(); art.layer='BACKGROUND'
local widget=CreateFrame('Frame',nil,f); widget.widgetSetID=42; local secret=widget:CreateTexture(); secret.layer='BACKGROUND'
TEST.combat=true; N:Refresh(); assert(not N.windows[f]); TEST.combat=false; N:Refresh()
assert(N.windows[f] and not N.controls[blocked] and art:GetAlpha()==1 and secret:GetAlpha()==1 and f.NineSlice:GetAlpha()==1)
close:Click(); assert(TEST.nineClick)
f:Hide(); ContactsFrame=old

-- TEST: Professions and communities join window coordination while wardrobe tabs keep their parent open
ResetTest(); local FS=ForeverSuite; local W=FS.WindowManager; local old={ProfessionsBookFrame,CommunitiesFrame,CollectionsJournal,WardrobeFrame}
ProfessionsBookFrame=CreateFrame('Frame','ProfessionsBookFrame',UIParent); CommunitiesFrame=CreateFrame('Frame','CommunitiesFrame',UIParent)
CollectionsJournal=CreateFrame('Frame','CollectionsJournal',UIParent); WardrobeFrame=CreateFrame('Frame','WardrobeFrame',CollectionsJournal)
W:Install(); assert(W.native[ProfessionsBookFrame] and W.native[CommunitiesFrame] and not W.native[WardrobeFrame])
ProfessionsBookFrame:Hide(); CommunitiesFrame:Hide(); CollectionsJournal:Hide(); WardrobeFrame:Hide()
CommunitiesFrame:Show(); assert(CommunitiesFrame:IsShown()); ProfessionsBookFrame:Show(); Drain(); assert(ProfessionsBookFrame:IsShown() and not CommunitiesFrame:IsShown())
CollectionsJournal:Show(); WardrobeFrame:Show(); Drain(); assert(CollectionsJournal:IsShown() and WardrobeFrame:IsShown() and not ProfessionsBookFrame:IsShown())
CollectionsJournal:Hide(); ProfessionsBookFrame,CommunitiesFrame,CollectionsJournal,WardrobeFrame=unpack(old)

-- TEST: Social split migrates old preferences once and retains independent chat guild and friend settings
ResetTest(); local FS=ForeverSuite
ForeverSuiteDB={social={enabled=false,timestamps=true,onlineOnly=true}}; FS:InitializeDatabase()
assert(not FS:IsModuleEnabled('Chat') and not FS:IsModuleEnabled('Guild') and not FS:IsModuleEnabled('Social'))
assert(FS.db.chat.timestamps and FS.db.guild.onlineOnly)
FS.db.chat.enabled=true; FS.db.chat.timestamps=false; FS.db.guild.onlineOnly=false; FS:InitializeDatabase()
assert(FS:IsModuleEnabled('Chat') and not FS.db.chat.timestamps and not FS.db.guild.onlineOnly and not FS:IsModuleEnabled('Social'))
FS.db.chat.fontSize=900; FS.db.chat.borderColor='bad'; FS.modules.Chat:NormalizeSettings(); assert(FS.db.chat.fontSize==14 and FS.db.chat.borderColor=='Cyan')
FS:SetModuleEnabled('Guild',true); FS:SetModuleEnabled('Social',true)

-- TEST: Chat appearance settings apply independently restore native properties and defer combat changes
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Chat; local old={ChatFrame1,GetCVar,SetCVar}; local vars={showTimestamps='%H-%M'}
GetCVar=function(key) return vars[key] end; SetCVar=function(key,value) vars[key]=value end; C.originalTimestamp=nil
ChatFrame1=CreateFrame('ScrollingMessageFrame',nil,UIParent); local f=ChatFrame1; f:SetFont('original-chat',15,''); f.fading=true; f.visibleTime=30; f.maxLines=128
f.GetFading=function(self) return self.fading end; f.SetFading=function(self,v) self.fading=v end
f.GetTimeVisible=function(self) return self.visibleTime end; f.SetTimeVisible=function(self,v) self.visibleTime=v end
f.GetMaxLines=function(self) return self.maxLines end; f.SetMaxLines=function(self,v) self.maxLines=v end
FS.db.chat.fontSize=18; FS.db.chat.outline=true; FS.db.chat.timestamps=true; FS.db.chat.timestampFormat='24h + seconds'; FS.db.chat.fade=false
C:SettingsChanged(); assert(f.font[1]==FS.font and f.font[2]==18 and f.font[3]=='OUTLINE' and not f.fading and f.maxLines==512 and vars.showTimestamps=='%H:%M:%S')
FS:SetModuleEnabled('Social',false); FS:SetModuleEnabled('Guild',false); assert(FS.Style.plates[f]:IsShown() and vars.showTimestamps=='%H:%M:%S')
FS.db.chat.timestamps=false; C:SettingsChanged(); assert(vars.showTimestamps=='none')
TEST.combat=true; FS.db.chat.fontSize=12; C:SettingsChanged(); assert(f.font[2]==18); TEST.combat=false; C:SettingsChanged(); assert(f.font[2]==12)
FS:SetModuleEnabled('Chat',false); assert(f.font[1]=='original-chat' and f.font[2]==15 and f.fading and f.visibleTime==30 and f.maxLines==128 and vars.showTimestamps=='%H-%M')
f:Hide(); ChatFrame1,GetCVar,SetCVar=unpack(old); FS:SetModuleEnabled('Chat',true); FS:SetModuleEnabled('Social',true); FS:SetModuleEnabled('Guild',true)

-- TEST: Friend and guild rosters have separate filters sorting details and whisper preparation
ResetTest(); local FS=ForeverSuite; local S,G=FS.modules.Social,FS.modules.Guild; local old={C_FriendList,GetNumGuildMembers,GetGuildRosterInfo,GetGuildInfo,ChatFrame_SendTell}
C_FriendList={GetNumFriends=function() return 2 end,GetFriendInfoByIndex=function(i) return {name=i==1 and 'Zulu' or 'Alice',connected=i==1,level=4,className='Hunter',area='Forest',notes='friend note'} end}
GetNumGuildMembers=function() return 2 end; GetGuildRosterInfo=function(i) return i==1 and 'Member' or 'OfflineMember','Officer',1,60,'Mage','City','public note','private note',i==1 end
GetGuildInfo=function() return 'Test Guild' end; local whisper; ChatFrame_SendTell=function(name) whisper=name end
S:Build(); G:Build(); assert(#S.rows==2 and #G.rows==2 and S.rows[1].name=='Zulu' and G.rows[1].text:find('Officer',1,true))
FS.db.social.showZone=false; FS.db.social.showNotes=true; FS.db.social.onlineFirst=false; FS.db.guild.onlineOnly=true; FS.db.guild.showRank=false; FS.db.guild.showNotes=true
S:Build(); G:Build(); assert(S.rows[1].name=='Alice' and not S.rows[1].text:find('Forest',1,true) and S.rows[1].text:find('friend note',1,true))
assert(#G.rows==1 and not G.rows[1].text:find('Officer',1,true) and G.rows[1].text:find('public note',1,true) and not G.rows[1].text:find('private note',1,true))
G.selected=G.rows[1]; G.actions[1].run(G); assert(whisper=='Member'); S.selected=S.rows[1]; S.actions[1].run(S); assert(whisper=='Alice')
FS:ConfigureModule('Chat'); local C=FS.modules.Chat; local before=FS.db.chat.fontSize; Click(C.settings.fontSize); assert(FS.db.chat.fontSize~=before and C.settings.fontSize:GetText():find(tostring(FS.db.chat.fontSize),1,true))
C_FriendList,GetNumGuildMembers,GetGuildRosterInfo,GetGuildInfo,ChatFrame_SendTell=unpack(old)

-- TEST: Fixed profile controls remain visible on every module page and save update switch without a separate card
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles; FS:ShowConfig(); local f=FS.window; local bar=f.profiles
assert(bar==P.bar and not f.cards.Profiles and f.cardCount==24)
for page=1,3 do f.cardPage=page; FS:RefreshConfig(); assert(bar:IsShown()) end
FS:ConfigureModule('Chat'); assert(not bar:IsShown() and FS.modules.Chat.settings:IsShown() and FS.modules.Chat.settings.point[1]=='CENTER' and FS.modules.Chat.settings.point[2]==UIParent)
FS.modules.Chat.settings.back:Click(); assert(bar:IsShown())
assert(-bar.point[3]+bar:GetHeight()<176)
FS.db.chat.fontSize=18; bar.name:SetText('Raid'); bar.save:Click(); assert(FS.db.profiles.current=='Raid' and FS.db.profiles.saved.Raid.chat.fontSize==18 and bar.name:GetText()=='')
FS.db.chat.fontSize=12; bar.save:Click(); assert(FS.db.profiles.saved.Raid.chat.fontSize==12)
bar.choice:Click(); assert(P.selected=='Default'); bar.use:Click(); assert(FS.db.profiles.current=='Default' and FS.db.chat.fontSize==14 and bar.current:GetText():find('Default',1,true))
FS.db.modules.Profiles=false; assert(P:Save('Legacy flag does not block'))
TEST.combat=true; assert(not P:Save('Combat')); TEST.combat=false
FS.modules.Vendor.busy=true; assert(not P:Load('Raid')); FS.modules.Vendor.busy=false
FS.window:Hide()

-- TEST: Chat scrollbar keeps native scroll and thumb handlers with themed controls inside the panel and restores on disable
ResetTest(); local FS=ForeverSuite; local S,N=FS.Style,FS.NativeWindows; local old={ChatFrame1,ChatFrame1ScrollBar,ChatFrame1ScrollToBottomButton}
ChatFrame1=CreateFrame('ScrollingMessageFrame','ChatFrame1',UIParent); local f=ChatFrame1; f.GetRight=function() return 400 end
f.ScrollBar=CreateFrame('Frame',nil,f); local bar=f.ScrollBar; bar:SetSize(18,200); bar.GetRight=function() return 428 end
bar.Track=CreateFrame('Frame',nil,bar); local track=bar.Track; track.art=track:CreateTexture(); track.art:SetTexture('native-track')
track.Thumb=CreateFrame('Button',nil,track); local thumb=track.Thumb; thumb.art=thumb:CreateTexture(); thumb.art:SetTexture('native-brown-thumb')
local scrolls,drags=0,0; thumb:SetScript('OnDragStart',function() drags=drags+1 end)
bar.Back=CreateFrame('Button',nil,bar); bar.Back.normalRegion=bar.Back:CreateTexture(); bar.Back:SetScript('OnClick',function() scrolls=scrolls+1 end)
bar.Forward=CreateFrame('Button',nil,bar); bar.Forward.normalRegion=bar.Forward:CreateTexture(); bar.Forward:SetScript('OnClick',function() scrolls=scrolls-1 end)
f.ScrollToBottomButton=CreateFrame('Button',nil,f); f.ScrollToBottomButton.normalRegion=f.ScrollToBottomButton:CreateTexture(); f.ScrollToBottomButton:GetNormalTexture():SetTexture('return-bottom')
f.ScrollToBottomButton.GetRight=function() return 432 end; f.ScrollToBottomButton:SetScript('OnClick',function() scrolls=0 end)
S:Chat(); assert(track.art:GetAlpha()==0 and thumb.art:GetAlpha()==0 and S.plates[thumb]:IsShown() and S.plates[f].point[4]==37)
assert(N.controls[bar.Back].glyph:GetText()=='^' and N.controls[bar.Forward].glyph:GetText()=='v' and f.ScrollToBottomButton:GetNormalTexture():GetAlpha()==0)
bar.Back:Click(); assert(scrolls==1); thumb.scripts.OnDragStart(thumb); assert(drags==1); bar.Forward:Click(); assert(scrolls==0)
bar.Back:Click(); f.ScrollToBottomButton:Click(); assert(scrolls==0); track.art:SetAlpha(1); assert(track.art:GetAlpha()==0)
FS.db.chat.styleWindow=false; S:Chat(); assert(track.art:GetAlpha()==1 and thumb.art:GetAlpha()==1 and not N.controls[bar.Back].glyph:IsShown() and not S.plates[track]:IsShown())
FS.db.chat.styleWindow=true; FS:SetModuleEnabled('Chat',false); assert(not S.plates[thumb]:IsShown() and not N.controls[f.ScrollToBottomButton].glyph:IsShown())
f:Hide(); f.ScrollBar=nil; f.ScrollToBottomButton=nil
ChatFrame1ScrollBar=CreateFrame('Slider','ChatFrame1ScrollBar',f); local slider=ChatFrame1ScrollBar; slider:SetWidth(20); slider.ScrollUpButton=CreateFrame('Button',nil,slider)
local texture=slider:CreateTexture(); texture:SetTexture('classic-thumb'); slider.GetThumbTexture=function() return texture end; slider:SetScript('OnValueChanged',function() scrolls=5 end)
f:Show(); FS:SetModuleEnabled('Chat',true); assert(texture:GetAlpha()==0 and texture.fsChatThumb:IsShown() and S.plates[f].point[4]==28)
slider.scripts.OnValueChanged(slider,2); assert(scrolls==5); FS:SetModuleEnabled('Chat',false); assert(texture:GetAlpha()==1 and not texture.fsChatThumb:IsShown())
ChatFrame1,ChatFrame1ScrollBar,ChatFrame1ScrollToBottomButton=unpack(old); FS:SetModuleEnabled('Chat',true)

-- TEST: Chat side buttons retain native menus tooltips counts notifications and disabled states while styling restores independently
ResetTest(); local FS=ForeverSuite; local S,N=FS.Style,FS.NativeWindows; local names={'QuickJoinToastButton','ChatFrameChannelButton','ChatFrameMenuButton'}; local saved={}; local clicks=0
for _,name in ipairs(names) do
 saved[name]=_G[name]; local b=CreateFrame('Button',name,UIParent); b:SetSize(34,40); b:SetPoint('LEFT',UIParent,'LEFT',0,10); b:SetAlpha(.8)
 b.normalRegion=b:CreateTexture(); b.pushedRegion=b:CreateTexture(); b.highlightRegion=b:CreateTexture(); b.Icon=b:CreateTexture()
 b:SetScript('OnClick',function() clicks=clicks+1 end); b:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self); GameTooltip:Show() end)
end
local contact=QuickJoinToastButton; contact.count=contact:CreateFontString(); contact.count:SetText('0'); contact.count:SetFont('count-original',11,'OUTLINE')
contact.Toast=CreateFrame('Frame',nil,contact); local toast=contact.Toast:CreateTexture(); toast:SetTexture('notification-content')
S:Chat(); assert(S.chatButtons[contact].icon.texture.texture==FS.menuAtlas and contact.Icon:GetAlpha()==0 and contact.count:GetText()=='0' and toast:GetAlpha()==1)
local speaker=S.chatButtons[ChatFrameChannelButton].icon; local lines=0; for _,child in ipairs({speaker:GetChildren()}) do if child.kind=='Line' then lines=lines+1; assert(child.thickness==1.5 and child.startPoint and child.endPoint) end end
assert(lines>0 and S.chatButtons[ChatFrameMenuButton].icon:IsShown())
for _,name in ipairs(names) do local b=_G[name]; b:Click(); b.scripts.OnEnter(b); assert(GameTooltip.owner==b and b:GetParent()==UIParent and b.point[1]=='LEFT' and b:GetAlpha()==.8) end
assert(clicks==3); contact.count:SetText('7'); contact.Icon:SetAlpha(1); assert(contact.Icon:GetAlpha()==0 and contact.count:GetText()=='7')
ChatFrameChannelButton:SetEnabled(false); S:Chat(); assert(S.chatButtons[ChatFrameChannelButton].icon:GetAlpha()==.35); ChatFrameChannelButton:Click(); assert(clicks==3)
local plate=N.controls[contact].plate; plate.SetBackdropBorderColor=function(self,...) self.testBorder={...} end; plate.SetBackdropColor=function(self,...) self.testBackground={...} end
FS.db.chat.borderColor='Gold'; FS.db.chat.backgroundOpacity=.55; S:Chat(); assert(plate.testBorder[1]==.95 and plate.testBackground[4]==.55)
FS:SetModuleEnabled('Social',false); assert(S.chatButtons[contact].icon:IsShown())
FS.db.chat.styleButtons=false; S:Chat(); assert(contact.Icon:GetAlpha()==1 and not S.chatButtons[contact].icon:IsShown() and contact.count.font[1]=='count-original' and toast:GetAlpha()==1)
FS.db.chat.styleButtons=true; TEST.combat=true; S:Chat(); assert(not S.chatButtons[contact].icon:IsShown()); TEST.combat=false; S.events.scripts.OnEvent(S.events,'PLAYER_REGEN_ENABLED'); assert(S.chatButtons[contact].icon:IsShown())
FS:SetModuleEnabled('Chat',false); assert(contact.Icon:GetAlpha()==1 and not N.controls[contact].plate:IsShown() and contact.count:GetText()=='7')
for _,name in ipairs(names) do _G[name]:Hide(); _G[name]=saved[name] end; FS:SetModuleEnabled('Chat',true); FS:SetModuleEnabled('Social',true)
FS:ConfigureModule('Chat'); local f=FS.modules.Chat.settings; assert(#FS.modules.Chat.options==13 and f.styleButtons and -f.historyLines.point[3]+30<355)

-- TEST: Loot history limits scope display filters timestamps ordering and confirmed clearing preserve pickup behavior and saved messages
ResetTest(); local FS=ForeverSuite; local L=FS.modules.Loot; local data=FS.db.loot; local old={GetItemInfo,date,LOOT_ITEM_SELF}; local quality={}
LOOT_ITEM_SELF='You receive loot: %s.'; GetItemInfo=function(link) return 'Item',link,quality[link] end
data.historyLimit=25; for i=1,35 do L:Event('CHAT_MSG_LOOT','Loot '..i) end; assert(#data.history==25 and data.history[1].text=='Loot 35')
data.recordHistory=false; L:Event('CHAT_MSG_LOOT','Not recorded'); assert(data.history[1].text=='Loot 35'); data.recordHistory=true; data.historySource='You'
L:Event('CHAT_MSG_LOOT','Friend receives loot: |Hitem:1|h[Other]|h.'); assert(#data.history==25)
L:Event('CHAT_MSG_LOOT','You receive loot: |Hitem:2|h[Your item]|h.'); assert(data.history[1].link=='|Hitem:2|h[Your item]|h')
data.history={{text='Epic',link='epic',time=100},{text='Poor',link='poor',time=90},{text='Pending',link='pending',time=80}}; quality.epic=4; quality.poor=0
data.historyQuality='Rare+'; L:Build(); assert(#L.rows==2 and L.rows[1].text=='Epic' and L.rows[2].text=='Pending' and L.status:find('Uncached',1,true))
quality.pending=1; L:Event('GET_ITEM_INFO_RECEIVED'); L:Build(); assert(#L.rows==1 and L.rows[1].text=='Epic')
data.historyQuality='All'; data.newestFirst=false; data.showTime=true; date=function() return '22:25' end; L:Build(); assert(L.rows[1].text=='[22:25] Pending' and data.history[3].text=='Pending')
data.showHistory=false; L:Build(); assert(#L.rows==0 and #data.history==3); data.showHistory=true
data.historyLimit=999999; data.historyQuality='bad'; L:NormalizeSettings(); assert(data.historyLimit==100 and data.historyQuality=='All')
FS:ConfigureModule('Loot'); local f=L.settings; assert(#L.options==14 and f.autoOpenRolls and -f.autoOpenRolls.point[3]+30<355)
f.clear:Click(); assert(#data.history==3 and f.clear:GetText()=='Confirm clear'); TEST.now=TEST.now+6; f.clear:Click(); assert(#data.history==3)
f.clear:Click(); assert(#data.history==0 and f.clear:GetText()=='Clear history')
GetItemInfo,date,LOOT_ITEM_SELF=old[1],old[2],old[3]

-- TEST: Loot roll views sorting auto opening and native window styling preserve eligibility expiration confirmation and disabled cleanup
ResetTest(); local FS=ForeverSuite; local L=FS.modules.Loot; local data=FS.db.loot; L.rolls={}; local old={GetLootRollItemInfo,RollOnLoot,LootFrame,IsShiftKeyDown,GetNumLootItems,LootSlot}; local rolled,calls=0,0
GetLootRollItemInfo=function(id) return 1,id==1 and 'Zulu' or 'Alice',2,4,false,false,true end; RollOnLoot=function() rolled=rolled+1 end
L:Event('START_LOOT_ROLL',1,10000); L:Event('START_LOOT_ROLL',2,30000); L:Build(); assert(L.rows[1].roll==1 and not (L.window and L.window:IsShown()))
data.rollSort='Name'; data.showRollCount=false; data.showRollTime=false; L:Build(); assert(L.rows[1].roll==2 and L.rows[1].text=='[Roll] Alice')
L.selected=L.rows[1]; L:Roll(1); assert(rolled==0 and L.rolls[2]); L:Roll(2); assert(rolled==1 and not L.rolls[2])
L.selected=L.rows[1]; L:Event('CANCEL_LOOT_ROLL',2); assert(not L.selected)
data.showRolls=false; L:Build(); assert(#L.rows==0 and L.rolls[1]); data.showRolls=true; data.autoOpenRolls=true
TEST.combat=true; L:Event('START_LOOT_ROLL',3,10000); assert(not (L.window and L.window:IsShown())); TEST.combat=false; L:Event('START_LOOT_ROLL',4,10000); assert(L.window:IsShown())
L.selected={roll=4}; RollOnLoot=function() error('game rejected') end; L:Roll(2); assert(L.rolls[4] and L.selected); RollOnLoot=function() rolled=rolled+1 end
TEST.now=TEST.now+31; L:Build(); assert(not next(L.rolls) and not L.selected)
GetNumLootItems=function() return 2 end; LootSlot=function() calls=calls+1 end; data.fast=true; IsShiftKeyDown=function() return true end; L:Event('LOOT_OPENED'); assert(calls==0)
IsShiftKeyDown=function() return false end; TEST.combat=true; L:Event('LOOT_OPENED'); assert(calls==0); TEST.combat=false; L:Event('LOOT_OPENED'); assert(calls==2)
LootFrame=CreateFrame('Frame','LootFrame',UIParent); LootFrame.Background=LootFrame:CreateTexture(); local slot=CreateFrame('Button',nil,LootFrame); slot.Icon=slot:CreateTexture(); slot.Icon:SetTexture('Interface\\Icons\\Loot'); slot:SetScript('OnClick',function() calls=calls+1 end)
FS.NativeWindows:Refresh(); assert(LootFrame.Background:GetAlpha()==0 and slot.Icon:GetAlpha()==1); slot:Click(); assert(calls==3)
data.styleWindow=false; FS.NativeWindows:Refresh(); assert(LootFrame.Background:GetAlpha()==1 and not FS.NativeWindows.windows[LootFrame].plate:IsShown())
data.styleWindow=true; FS:SetModuleEnabled('Loot',false); FS.NativeWindows:Refresh(); assert(LootFrame.Background:GetAlpha()==1)
LootFrame:Hide(); GetLootRollItemInfo,RollOnLoot,LootFrame,IsShiftKeyDown,GetNumLootItems,LootSlot=unpack(old); FS:SetModuleEnabled('Loot',true)

-- TEST: Chat opens useful settings directly and typing uses native activation without clearing drafts or sending messages
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Chat; local old={ChatEdit_GetActiveWindow,ChatEdit_ActivateChat,ChatFrame1EditBox}; local activated
C:ShowWindow(); assert(not FS.window:IsShown() and C.settings:IsShown() and not C.window and C.settings.open:GetText()=='Start typing in chat')
ChatFrame1EditBox=CreateFrame('EditBox',nil,UIParent); local input=ChatFrame1EditBox; input:SetText('My draft'); input:Hide()
ChatEdit_GetActiveWindow=function() return input end; ChatEdit_ActivateChat=function(edit) activated=edit; edit:Show() end
C.settings.open:Click(); assert(activated==input and input:IsShown() and input:GetText()=='My draft' and not FS.window:IsShown() and not C.settings:IsShown())
C:ShowWindow(); ChatEdit_ActivateChat=nil; input.SetFocus=function(self) self.focus=true end; C.settings.open:Click(); assert(input.focus and input:GetText()=='My draft' and not FS.window:IsShown())
TEST.combat=true; C:ShowWindow(); assert(not FS.window:IsShown()); TEST.combat=false
ChatEdit_GetActiveWindow,ChatEdit_ActivateChat,ChatFrame1EditBox=unpack(old); FS:ShowConfig()

-- TEST: Profession Frame rank visuals follow real fill bounds and skill updates instead of hiding progress
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=ProfessionsFrame
ProfessionsFrame=CreateFrame('Frame','ProfessionsFrame',UIParent); local f=ProfessionsFrame; f:SetSize(800,600)
f.CraftingPage=CreateFrame('Frame',nil,f); local bar=CreateFrame('Frame',nil,f.CraftingPage); f.CraftingPage.RankBar=bar; bar:SetSize(460,18)
bar.Fill=bar:CreateTexture(); bar.Fill.layer='BACKGROUND'; bar.Fill:SetTexture('native-progress'); bar.Fill:SetWidth(18); bar.Fill:SetAlpha(.8)
bar.FillLeft=bar:CreateTexture(); bar.FillLeft.layer='BORDER'; bar.FillLeft:SetTexture('native-fill-cap')
bar.Background=bar:CreateTexture(); bar.Background:SetAlpha(.6); bar.Border=bar:CreateTexture()
bar.Rank=CreateFrame('Frame',nil,bar); bar.Rank.Text=bar.Rank:CreateFontString(); bar.Rank.Text:SetText('Skinning 3/75')
N:Refresh(); local plate=FS.Style.plates[bar]
assert(bar.Fill:GetAlpha()==0 and bar.FillLeft:GetAlpha()==0 and bar.Background:GetAlpha()==0 and bar.Border:GetAlpha()==0)
assert(N.progress[bar].visual:IsShown() and N.progress[bar].visual.allPoints[1]==bar.Fill)
assert(plate.w==452 and plate.h==18 and plate.point[2]==bar.Fill and bar.Fill.w==18 and bar.Rank.Text:GetText()=='Skinning 3/75')
bar.Fill:SetWidth(36); bar.Rank.Text:SetText('Skinning 6/75'); bar:SetWidth(600); f.scripts.OnSizeChanged(f)
assert(plate.w==592 and bar.Fill.w==36 and bar.Rank.Text:GetText()=='Skinning 6/75' and bar.Fill.texture=='native-progress')
FS:SetModuleEnabled('Professions',false); N:Refresh(); assert(not plate:IsShown() and not N.progress[bar].visual:IsShown() and bar.Fill:GetAlpha()==.8 and bar.FillLeft:GetAlpha()==1 and bar.Background:GetAlpha()==.6)
f:Hide(); ProfessionsFrame=old; FS:SetModuleEnabled('Professions',true)

-- TEST: Automatic quest waypoints handle delayed log population and update objective and turn-in locations
function NavigationFixture()
    ResetTest(); local FS=ForeverSuite; local M=FS.modules.Map; M:NormalizeSettings()
    local old={C_Map,C_QuestLog,GetPlayerFacing,CreateVector2D,UiMapPoint,C_SuperTrack}
    local data={ids={11,22},targets={[11]={12,.7,.5},[22]={12,.2,.5}},complete={},x=.5,y=.5,facing=0,writes=0}
    C_Map={GetBestMapForUnit=function() return 12 end,GetPlayerMapPosition=function() return {GetXY=function() return data.x,data.y end} end,GetMapWorldSize=function() return 1000,1000 end,
      GetUserWaypoint=function() return data.native end,ClearUserWaypoint=function() data.native=nil; data.clears=(data.clears or 0)+1 end,
      SetUserWaypoint=function(p) data.native=p; data.writes=data.writes+1 end,GetMapInfo=function() return {name='Other zone'} end}
    UiMapPoint={CreateFromCoordinates=function(map,x,y) return {uiMapID=map,position={GetXY=function() return x,y end}} end}
    C_SuperTrack={SetSuperTrackedUserWaypoint=function() end}; GetPlayerFacing=function() return data.facing end; CreateVector2D=nil
    C_QuestLog={GetNumQuestLogEntries=function() return #data.ids end,GetInfo=function(i) return {title='Quest '..data.ids[i],questID=data.ids[i]} end,
      GetQuestObjectives=function() return {} end,IsComplete=function(id) return data.complete[id] end,
      GetDistanceSqToQuest=function(id) return id==11 and 40000 or 90000 end,GetNextWaypoint=function(id) if data.targets[id] then return unpack(data.targets[id]) end end}
    function data:restore() TEST.combat=false; M:ClearNavigation(); C_Map,C_QuestLog,GetPlayerFacing,CreateVector2D,UiMapPoint,C_SuperTrack=unpack(old) end
    return FS,M,data
end
local FS,M,d=NavigationFixture(); d.ids={}; M:NavigationEvent('QUEST_ACCEPTED',11)
assert(M.questID==11 and M.waitingRow and not M.destination)
d.ids={11,22}; M:UpdateNavigation(); assert(M.destination.questID==11 and M.destination.x==.7 and d.writes==1)
M:UpdateNavigation(); assert(d.writes==1)
d.targets[11]={12,.8,.4}; M:NavigationEvent('QUEST_LOG_UPDATE'); assert(M.destination.x==.8 and d.writes==2)
d.complete[11]=true; d.targets[11]={12,.3,.6}; M:NavigationEvent('QUEST_LOG_UPDATE'); assert(M.destination.complete and M.destination.x==.3)
M:NavigationEvent('QUEST_TURNED_IN',11); assert(M.destination.questID==22)
d:restore()

-- TEST: Manual pins take priority and explicit stop stays stopped until another accepted or focused quest
local FS,M,d=NavigationFixture(); M:NavigationEvent('QUEST_ACCEPTED',11)
M:SetNavigation({map=12,x=.1,y=.2,name='Camp'}); M:NavigationEvent('QUEST_ACCEPTED',22); assert(M.destination.name=='Camp' and not M.destination.questID)
M:ClearNavigation(); M:UpdateNavigation(); assert(not M.destination and not M.navigator:IsShown() and not d.native)
M:FocusNavigation(11); assert(M.destination.questID==11)
FS.db.map.followFocused=false; M:FocusNavigation(22); assert(M.destination.questID==11)
FS.db.map.autoQuest=false; M:NavigationEvent('QUEST_ACCEPTED',22); assert(M.destination.questID==11)
FS.db.map.autoNext=false; M:NavigationEvent('QUEST_REMOVED',11); assert(not M.destination)
FS.db.map.autoQuest=true; M:NavigationEvent('QUEST_ACCEPTED',0,22); assert(M.destination.questID==22)
d:restore()

-- TEST: Waypoint location fallbacks use real client coordinates and never invent missing directions
local FS,M,d=NavigationFixture(); d.targets[11]=nil; M:NavigationEvent('QUEST_ACCEPTED',11)
assert(not M.destination and M.navigator.status:GetText()=='Quest location unavailable')
C_QuestLog.GetNextWaypointForMap=function(id,map) if id==11 and map==12 then return .6,.4 end end
M:UpdateNavigation(); assert(M.destination.x==.6 and M.destination.map==12)
C_QuestLog.GetNextWaypointForMap=nil; C_QuestLog.GetQuestsOnMap=function() return {{questID=11,x=.9,y=.5}} end
M:UpdateNavigation(); assert(M.destination.x==.9)
d.targets[11]={99,.5,.5}; M:UpdateNavigation(); assert(M.destination.map==99 and M.navigator.distance:GetText()=='Travel to Other zone' and M.navigator.status:GetText()=='Travel to Other zone')
for _,line in ipairs(M.navigator.lines) do assert(not line:IsShown()) end
d.targets[11]={12,2,.5}; C_QuestLog.GetQuestsOnMap=nil; M:UpdateNavigation(); assert(not M.destination)
d:restore()

-- TEST: Navigation arrows rotate with player facing use world coordinates across maps and indicate arrival without completing quests
local FS,M,d=NavigationFixture(); M:NavigationEvent('QUEST_ACCEPTED',11); local f=M.navigator
assert(f.template==nil and f.icon==nil and f:GetWidth()==250 and f:GetHeight()<=48 and not f.status:IsShown())
assert(#f.lines==7 and #f.shadows==7 and f.lines[4].color[1]>f.lines[1].color[1])
for i,line in ipairs(f.lines) do assert(line:IsShown() and f.shadows[i]:IsShown()); assert(line.endPoint[3]==f.shadows[i].endPoint[3] and line.endPoint[4]==f.shadows[i].endPoint[4]) end
assert(f.distance:GetText()=='199 yards' or f.distance:GetText()=='200 yards'); assert(f.lines[1].endPoint[3]>16 and math.abs(f.lines[1].endPoint[4])<.001)
d.facing=math.pi/2; M:RenderNavigation(); M:AnimateNavigation(1); assert(math.abs(f.lines[1].endPoint[3])<.001 and f.lines[1].endPoint[4]<-16)
d.x=.7; M:RenderNavigation(); assert(f.status:GetText()=='Arrived at objective area' and f.distance:GetText()=='Arrived' and not f.lines[1]:IsShown() and M.questID==11)
CreateVector2D=function(x,y) return {x=x,y=y} end
C_Map.GetWorldPosFromMapPos=function(map,pos) return 1,{GetXY=function() return -pos.y*1000,-pos.x*1000+(map==99 and -1000 or 0) end} end
d.targets[11]={99,.7,.5}; M:UpdateNavigation(); assert(f.distance:GetText()=='1.0k yards' and f.lines[1]:IsShown())
C_Map.GetWorldPosFromMapPos=function(map,pos) return map,{GetXY=function() return pos.x,pos.y end} end
M:RenderNavigation(); assert(f.distance:GetText()=='Travel to Other zone' and not f.lines[1]:IsShown())
d:restore()

-- TEST: Waypoint animation interpolates each frame takes the shortest turn and is independent of frame rate
local FS,M,d=NavigationFixture(); M:NavigationEvent('QUEST_ACCEPTED',11); local f=M.navigator
d.facing=math.pi/2; f:GetScript('OnUpdate')(f,1/60)
assert(M.navAngle<0 and M.navAngle>-math.pi/2 and f.lines[1].endPoint[3]>0 and f.lines[1].endPoint[4]<0)
local function run(fps)
    M.navAngle=0
    for i=1,fps do M:AnimateNavigation(1/fps) end
    return M.navAngle
end
assert(math.abs(run(30)-run(144))<.000001)
M.navAngle=math.pi-.01; d.facing=-math.pi-.01; M:AnimateNavigation(1/60)
assert(M.navAngle>math.pi-.01 and M.navAngle<math.pi+.01)
M.navVector=nil; M:AnimateNavigation(1/60); assert(M.navAngle==nil and not f.lines[1]:IsShown() and not f.shadows[1]:IsShown())
d:restore()

-- TEST: Native waypoint ownership preserves external pins defers combat writes and restores only owned markers
local FS,M,d=NavigationFixture(); local previous=UiMapPoint.CreateFromCoordinates(12,.3,.3); d.native=previous
M:UpdateNavigation(); assert(d.native==previous and d.writes==0)
TEST.combat=true; M:NavigationEvent('QUEST_ACCEPTED',11); assert(M.destination and d.writes==0)
TEST.combat=false; M:NavigationEvent('PLAYER_REGEN_ENABLED'); assert(d.writes==1)
local external=UiMapPoint.CreateFromCoordinates(12,.1,.1); d.native=external
d.targets[11]={12,.8,.5}; M:UpdateNavigation(); assert(d.native==external and d.writes==1 and M.externalWaypoint)
FS:SetModuleEnabled('Map',false); assert(d.native==external and not M.navigator:IsShown())
FS:SetModuleEnabled('Map',true); M:NavigationEvent('QUEST_ACCEPTED',22); assert(d.writes==2)
TEST.combat=true; FS.db.map.navigation=false; M:SettingsChanged(); assert(M.releasePending and d.native)
TEST.combat=false; M:NavigationEvent('PLAYER_REGEN_ENABLED'); assert(not M.releasePending and not d.native)
d:restore()

-- TEST: Waypoint settings validate migrate save in profiles and share stable Move Frames position and resize
local FS,M,d=NavigationFixture(); assert(#M.options==19); FS:ConfigureModule('Map'); assert(M.settings.navColor and M.settings.navStyle and M.settings.trail)
FS.db.map.navColor='invalid'; FS.db.map.arrival=10000; FS.db.map.navHideCombat='bad'; M:SettingsChanged()
assert(FS.db.map.navColor=='Cyan' and FS.db.map.arrival==20 and FS.db.map.navHideCombat==false)
M:NavigationEvent('QUEST_ACCEPTED',11); local f=M.navigator
FS.db.map.navColor='Gold'; FS.db.map.navStyle='Chevron'; FS.db.map.navFont=18; FS.db.map.navDistance=false; M:SettingsChanged()
assert(not f.lines[1]:IsShown() and f.lines[2]:IsShown() and f.distance:GetText()=='' and f.title.font[2]==18)
FS.db.layout.frames.Waypoint={x=100,y=300,scale=1.1}; FS.Layout:Apply('Waypoint'); M:RenderNavigation(); assert(f:GetScale()==1.1)
FS.db.map.navSize=1.4; M:SettingsChanged(); assert(f:GetScale()==1.4 and FS.db.layout.frames.Waypoint.x==100)
FS.db.map.navHideCombat=true; TEST.combat=true; M:RenderNavigation(); assert(not f:IsShown()); TEST.combat=false; M:RenderNavigation(); assert(f:IsShown())
local P=FS.modules.Profiles; assert(P:Save('Navigation')); assert(P:Save('Other navigation')); FS.db.map.navColor='Blue'; assert(P:Load('Navigation')); assert(FS.db.map.navColor=='Gold')
FS:SetModuleEnabled('Quests',false); assert(not M.destination); FS:SetModuleEnabled('Quests',true)
d:restore()

-- TEST: Global typography changes family weight outline shadow and size without repeated growth
ResetTest(); local FS=ForeverSuite; local F=FS.Typography; local frame=CreateFrame('Frame',nil,UIParent); frame.fsFontModule='Loot'
local label=FS.HUD:Label(frame,'Sample',0,0,250); FS:ApplyFont(label,14,'OUTLINE')
local style=FS.db.typography.global; style.family='Friz Quadrata'; style.scale=1.2; style.weight='Normal'; style.outline='Thick'; style.shadow='On'; F:Apply()
assert(label.font[1]=='Fonts\\FRIZQT__.TTF' and math.abs(label.font[2]-16.8)<.001 and label.font[3]=='THICKOUTLINE' and label.shadowOffset[1]==1)
for i=1,5 do FS:ApplyFont(label); FS:FontTree(frame) end; assert(math.abs(label.font[2]-16.8)<.001)
style.weight='Bold'; F:Apply(); assert(label.font[1]:find('Arial%-Bold.ttf'))
style.size=20; F:Apply(); assert(label.font[2]==24)
style.shadow='Off'; F:Apply(); assert(label.shadowOffset[1]==0)

-- TEST: Each module supports typography ownership overrides inheritance and future labels
ResetTest(); local FS=ForeverSuite; local F=FS.Typography; FS.db.typography.global.family='Friz Quadrata'
for name in pairs(FS.modules) do
 local frame=CreateFrame('Frame',nil,UIParent); frame.fsFontModule=name
 local label=FS.HUD:Label(frame,name,0,0,200); assert(F:Owner(label)==name and label.font[1]=='Fonts\\FRIZQT__.TTF')
 F.scope=name; F:Edit('family'); assert(FS.db.typography.modules[name] and label.font[1]=='Fonts\\MORPHEUS.TTF')
 local nextLabel=FS.HUD:Label(frame,'Later',0,0,200); assert(nextLabel.font[1]=='Fonts\\MORPHEUS.TTF')
 FS.db.typography.modules[name]=nil; F:Apply(); assert(label.font[1]=='Fonts\\FRIZQT__.TTF')
end
F.scope='All modules'

-- TEST: Font ownership handles nested settings native windows unit canvases chat and forbidden regions
ResetTest(); local FS=ForeverSuite; local F=FS.Typography; local oldFriends=FriendsFrame
FriendsFrame=CreateFrame('Frame','FriendsFrame',UIParent); local child=CreateFrame('Frame',nil,FriendsFrame); local label=FS.HUD:Label(child,'Friends',0,0,200); assert(F:Owner(label)=='Social')
local chat=CreateFrame('Frame','ChatFrame9',UIParent); local text=FS.HUD:Label(chat,'Chat',0,0,200); assert(F:Owner(text)=='Chat')
local forbidden=CreateFrame('FontString'); forbidden.IsForbidden=function() return true end; forbidden:SetFont('Original',17,''); FS:ApplyFont(forbidden,20); assert(forbidden.font[1]=='Original')
FS:ConfigureModule('Map'); local row=FS.HUD:Label(FS.modules.Map.settings,'Map',0,0,200); assert(F:Owner(row)=='Map')
FriendsFrame=oldFriends; child:Hide(); chat:Hide()

-- TEST: Native fonts and shadow restore on disable and typography never reactivates released styling
ResetTest(); local FS=ForeverSuite; local F=FS.Typography; local frame=CreateFrame('Frame',nil,UIParent); frame.fsFontModule='Social'
local label=frame:CreateFontString(); label:SetFont('Native',15,'OUTLINE'); label:SetShadowOffset(2,-2)
FS.db.typography.global.shadow='Off'; FS.NativeWindows:Font(label,true); assert(label.font[1]==FS.font and label.shadowOffset[1]==0)
FS.NativeWindows:Font(label,false); assert(label.font[1]=='Native' and label.shadowOffset[1]==2)
FS.db.typography.global.weight='Bold'; F:Apply(); assert(label.font[1]=='Native')
FS.NativeWindows:Font(label,true); assert(label.font[1]:find('Arial%-Bold.ttf'))
FS.NativeWindows:Font(label,false)

-- TEST: Typography validates saved settings and profile changes restore global and module choices
ResetTest(); local FS=ForeverSuite; local F=FS.Typography
FS.db.typography.global.family='bad'; FS.db.typography.global.scale=999; FS.db.typography.global.outline='bad'; FS.db.typography.modules.Fake={}; F:Normalize()
assert(FS.db.typography.global.family=='Default' and FS.db.typography.global.scale==1 and not FS.db.typography.modules.Fake)
FS.db.typography.global.family='Skurri'; F.scope='Chat'; F:Edit('weight'); assert(FS.db.typography.modules.Chat.weight=='Normal')
local P=FS.modules.Profiles; assert(P:Save('Text')); assert(P:Save('Other text')); FS.db.typography.global.family='Morpheus'; assert(P:Load('Text'))
assert(FS.db.typography.global.family=='Skurri' and FS.db.typography.modules.Chat.weight=='Normal'); F.scope='All modules'

-- TEST: Typography editor preview scopes combat deferral and navigation remain separate from module settings
ResetTest(); local FS=ForeverSuite; local F=FS.Typography; FS:ShowConfig(); assert(FS.window.typography)
F.scope='All modules'; F:Show(); local f=F.window; local count=1; for _ in pairs(FS.modules) do count=count+1 end; assert(f:IsShown() and not FS.window:IsShown() and #F:Scopes()==count)
F:Edit('family'); assert(f.preview.font[1]==FS.font and FS.db.typography.global.family=='Arial Narrow')
local before=FS.db.typography.global.weight; TEST.combat=true; F:Edit('weight'); assert(FS.db.typography.global.weight==before)
FS.db.typography.global.family='Friz Quadrata'; F:Apply(); assert(F.pending and f.preview.font[1]==FS.font)
FS:ApplyFont(f.preview); assert(f.preview.font[1]==FS.font)
TEST.combat=false; F.events.scripts.OnEvent(F.events); assert(not F.pending and f.preview.font[1]=='Fonts\\FRIZQT__.TTF')
FS:ShowConfig(); assert(not f:IsShown() and FS.window:IsShown())

-- TEST: Nameplate design defaults migrate safely validate corrupted sizes offsets and choices and preserve profile snapshots
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates; local P=FS.modules.Profiles
ForeverSuiteDB={nameplates={enabled=true,scale=1.1,enemies=false,friendlyPlayers=true,width=999,height='bad',positions={name={x=9999,y=-12}},enemyColor='invalid',auraCount=5.7}}
FS:InitializeDatabase(); local db=FS.db.nameplates
assert(db.width==190 and db.height==22 and db.positions.name.x==0 and db.positions.name.y==-12 and db.enemyColor=='Red' and db.auraCount==6,table.concat({db.width,db.height,db.positions.name.x,db.positions.name.y,db.enemyColor,db.auraCount},','))
assert(not db.enemies and db.friendlyPlayers and db.scale==1.1 and db.positions.cast.y==-4 and not FS.Layout.targets.NameplatePreview)
N:MovePart('name',21,33); db.width=260; db.healthFormat='Percent'; assert(P:Save('Plates')); assert(P:Save('Other'))
N:ApplyPreset('Compact'); assert(db.width==150 and db.fontSize==11 and not db.enemies and db.friendlyPlayers)
assert(P:Load('Plates')); assert(FS.db.nameplates.width==260 and FS.db.nameplates.positions.name.x==21 and FS.db.nameplates.positions.name.y==33 and FS.db.nameplates.healthFormat=='Percent')
N:ApplyPreset('ForeverSuite'); assert(FS.db.nameplates.width==190 and not FS.db.nameplates.enemies and FS.db.nameplates.friendlyPlayers)

-- TEST: Nameplate designer offers all option groups typed sizes reversible presets and bounded preview without fake live units
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
FS:ConfigureModule('Nameplates'); assert(N.settings.designer and N.settings:IsShown()); N.settings.designer:Click()
local f=N.editor; assert(f:IsShown() and not FS.window:IsShown() and #N.designGroups==4 and #f.optionCells==10 and f.stage.clipsChildren)
assert(f.preview.name:GetText()=='ForeverSuite Training Target' and f.preview.health.value==7200 and f.preview.cast:GetScript('OnUpdate')==nil)
local cell=f.optionCells[1]; cell.input:SetText('260'); cell.input.scripts.OnEnterPressed(cell.input); assert(FS.db.nameplates.width==260 and f.preview.health.w==256)
cell.input:SetText('9999'); cell.input.scripts.OnEnterPressed(cell.input); assert(FS.db.nameplates.width==260 and f.message:GetText():find('80 to 360',1,true))
N:EditorGroup(2); assert(#f.optionCells==9 and not cell:IsShown()); f.optionCells[1]:Click(); assert(not FS.db.nameplates.showName and not f.preview.name:IsShown() and not f.handles.name:IsShown())
N:EditorGroup(3); assert(#f.optionCells==8); N:EditorGroup(4); assert(#f.optionCells==7)
N:ApplyPreset('Large'); assert(FS.db.nameplates.width==240 and f.preview.auras[1].w==24)
N:ApplyPreset('Minimal'); assert(not f.preview.level:IsShown() and not f.preview.auras[1]:IsShown())
FS.db.nameplates.width=360; FS.db.nameplates.scale=1.4; FS.db.nameplates.targetScale=1.5; N:SettingsChanged()
assert(f.preview.w*f.preview:GetScale()<f.stage:GetWidth())
f:Hide(); FS:ShowConfig()

-- TEST: Designer drags use effective scale stable cursor deltas clamp positions and stop on hide or combat
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates; local old=GetCursorPosition; local x,y=100,100
GetCursorPosition=function() return x,y end; N:ShowWindow(); local f=N.editor; local handle=f.handles.name; local previous=f.preview.GetEffectiveScale
f.preview.GetEffectiveScale=function() return 2 end
handle.scripts.OnDragStart(handle); x=120; y=90; handle.scripts.OnUpdate(handle)
assert(FS.db.nameplates.positions.name.x==10 and FS.db.nameplates.positions.name.y==12 and N.dragPart==handle)
handle.scripts.OnUpdate(handle); assert(FS.db.nameplates.positions.name.x==10 and FS.db.nameplates.positions.name.y==12)
x=10000; handle.scripts.OnUpdate(handle); assert(FS.db.nameplates.positions.name.x==300)
TEST.combat=true; y=10000; handle.scripts.OnUpdate(handle); assert(not N.dragPart and FS.db.nameplates.positions.name.y==12); assert(not N:MovePart('name',0,0))
TEST.combat=false; f:Hide(); assert(not handle.drag); assert(N:MovePart('name',0,17)); f.preview.GetEffectiveScale=previous; GetCursorPosition=old

-- TEST: Nameplate style choices change visual dimensions text colors target size and opacity while native targeting stays intact
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates; local old={UnitIsUnit,UnitThreatSituation}; local oldPlateAPI=C_NamePlate; local selected=true; local threat=3
UnitIsUnit=function() return selected end; UnitThreatSituation=function() return threat end
local plate=CreateFrame('Frame'); plate.UnitFrame=CreateFrame('Button',nil,plate); plate.UnitFrame.unit='target'; local clicked=0; plate.UnitFrame:SetScript('OnClick',function() clicked=clicked+1 end)
TEST.plates={plate}; TEST.plateMap={target=plate}; C_NamePlate={GetNamePlates=function() return TEST.plates end}; N:SettingsChanged(); local f=N.custom[plate].canvas
f.SetBackdropBorderColor=function(self,...) self.testBorder={...} end
local db=FS.db.nameplates; db.width=260; db.height=30; db.fontSize=18; db.valueFontSize=14; db.outline=false; db.classColors=false; db.enemyColor='Blue'; db.targetScale=1.25; db.targetColor='Pink'; db.otherOpacity=.4; db.healthFormat='Percent'
N:SettingsChanged(); assert(f.health.w==256 and f.health.h==26 and f.name.font[2]==18 and f.name.font[3]=='')
assert(f.value:GetText()=='50%' and f.health.barColor[1]==.22 and f:GetScale()==1.25 and f:GetAlpha()==1 and f.testBorder[1]==.91)
selected=false; N:Update(plate,'target'); assert(f:GetScale()==1 and f:GetAlpha()==.4)
db.threatColors=true; N:SettingsChanged(); assert(f.health.barColor[1]==.85); threat=1; N:Update(plate,'target'); assert(f.health.barColor[1]==.95)
db.showName=false; db.showLevel=false; db.showThreat=false; db.showHealth=false; N:SettingsChanged(); assert(not f.name:IsShown() and not f.level:IsShown() and not f.threat:IsShown() and not f.value:IsShown())
plate.UnitFrame:Click(); assert(clicked==1 and f:IsMouseEnabled()==false and plate.UnitFrame:GetAlpha()==0)
FS:SetModuleEnabled('Nameplates',false); assert(plate.UnitFrame:GetAlpha()==1 and not f:IsShown()); TEST.plates={}; TEST.plateMap={}; UnitIsUnit,UnitThreatSituation=unpack(old); C_NamePlate=oldPlateAPI; FS:SetModuleEnabled('Nameplates',true)

-- TEST: Custom cast and aura controls retain real timings filters and limited icon counts and clear recycled visuals
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates; local old={UnitCastingInfo,UnitChannelInfo,C_UnitAuras}; local oldPlateAPI=C_NamePlate; TEST.now=1
UnitCastingInfo=function() return 'Frostbolt',nil,135846,1000,5000,nil,nil,true end; UnitChannelInfo=nil
local seen; C_UnitAuras={GetAuraDataByIndex=function(_,i,filter) seen=filter; return {icon=100+i,duration=20,expirationTime=21} end}
local plate=CreateFrame('Frame'); plate.UnitFrame=CreateFrame('Button',nil,plate); plate.UnitFrame.unit='target'; TEST.plates={plate}; TEST.plateMap={target=plate}; C_NamePlate={GetNamePlates=function() return TEST.plates end}
local db=FS.db.nameplates; db.auraCount=5; db.onlyMine=true; db.castIcon=true; db.castTime=true; N:SettingsChanged(); local f=N.custom[plate].canvas
assert(seen=='HARMFUL|PLAYER' and f.auras[5]:IsShown() and not f.auras[6]:IsShown() and f.cast.icon.texture==135846 and f.cast.icon:IsShown())
f.cast.scripts.OnUpdate(f.cast); assert(f.cast.time:GetText()=='4.0s' and f.cast.barColor[1]==.45)
db.auraType='Buffs'; db.auraCountdown=false; N:SettingsChanged(); assert(seen=='HELPFUL|PLAYER' and not f.auras[1].cooldown:IsShown())
db.debuffs=false; db.showCast=false; N:SettingsChanged(); assert(not f.auras[1]:IsShown() and not f.cast:IsShown())
UnitCastingInfo=nil; db.showCast=true; N:SettingsChanged(); assert(not f.cast:IsShown() and not f.cast.icon:IsShown() and f.cast.time:GetText()=='')
N:Release(N.custom[plate]); TEST.plates={}; TEST.plateMap={}; UnitCastingInfo,UnitChannelInfo,C_UnitAuras=unpack(old); C_NamePlate=oldPlateAPI

-- TEST: Appearance changes defer during combat while updates and module disable preserve plate behavior
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates; local oldPlateAPI=C_NamePlate
local plate=CreateFrame('Frame'); plate.UnitFrame=CreateFrame('Button',nil,plate); plate.UnitFrame.unit='target'; TEST.plates={plate}; TEST.plateMap={target=plate}; C_NamePlate={GetNamePlates=function() return TEST.plates end}
N:SettingsChanged(); local f=N.custom[plate].canvas; TEST.combat=true; FS.db.nameplates.width=280; N:SettingsChanged(); N:Update(plate,'target')
assert(N.appearancePending and f.w==190 and f:IsShown())
FS:SetModuleEnabled('Nameplates',false); assert(not f:IsShown() and plate.UnitFrame:GetAlpha()==1)
TEST.combat=false; FS:SetModuleEnabled('Nameplates',true); N.events.scripts.OnEvent(N.events,'PLAYER_REGEN_ENABLED')
assert(not N.appearancePending and f.w==280 and f:IsShown() and plate.UnitFrame:GetAlpha()==0)
N:Release(N.custom[plate]); TEST.plates={}; TEST.plateMap={}; C_NamePlate=oldPlateAPI

-- TEST: Profession search filter and reset have separate bounds and keep callbacks visibility and reversible anchors
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=ProfessionsFrame
ProfessionsFrame=CreateFrame('Frame','ProfessionsFrame',UIParent); local f=ProfessionsFrame
f.CraftingPage=CreateFrame('Frame',nil,f); local list=CreateFrame('Frame',nil,f.CraftingPage); f.CraftingPage.RecipeList=list; list:SetSize(300,460)
list.SearchBox=CreateFrame('EditBox',nil,list); local search=list.SearchBox; search:SetSize(170,20); search:SetPoint('TOPLEFT',list,'TOPLEFT',7,-5); search:SetText('Leather')
search:SetScript('OnTextChanged',function() TEST.recipeSearch=search:GetText() end)
list.FilterDropdown=CreateFrame('Button',nil,list); local filter=list.FilterDropdown; filter:SetSize(100,20); filter:SetPoint('TOPRIGHT',list,'TOPRIGHT',-10,-5)
filter.Text=filter:CreateFontString(); filter.Text:SetText('Filter'); filter.Text:SetPoint('CENTER',filter,'CENTER',0,0)
filter:SetScript('OnClick',function() TEST.filtersOpened=true end)
filter.ResetButton=CreateFrame('Button',nil,filter); local reset=filter.ResetButton; reset:SetSize(26,26); reset:SetPoint('RIGHT',filter,'RIGHT',12,0); reset:Hide()
reset:SetScript('OnClick',function() TEST.filtersCleared=true end)
N:Refresh(); assert(search:GetText()=='Leather' and search.point[2]==filter and search.point[4]==-30 and search.h==filter.h)
assert(reset.point[2]==filter and reset.point[3]=='LEFT' and reset.w==18 and not reset:IsShown() and filter.fsProfessionCaret:IsShown())
filter:Click(); search.scripts.OnTextChanged(); reset:Show(); reset:Click(); assert(TEST.filtersOpened and TEST.recipeSearch=='Leather' and TEST.filtersCleared)
assert(N.controls[reset].glyph:GetText()=='X')
FS:SetModuleEnabled('Professions',false); N:Refresh()
assert(search.w==170 and search.h==20 and search.point[4]==7 and filter.w==100 and filter.point[4]==-10 and reset.w==26 and reset.point[4]==12)
assert(filter.Text.point[1]=='CENTER' and not filter.fsProfessionCaret:IsShown() and search:GetText()=='Leather')
f:Hide(); ProfessionsFrame=old; FS:SetModuleEnabled('Professions',true)

-- TEST: Profession tabs including sibling buttons preserve selection tooltips icon updates and original geometry
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=ProfessionsFrame
ProfessionsFrame=CreateFrame('Frame','ProfessionsFrame',UIParent); local f=ProfessionsFrame; f:SetSize(800,600)
local overview=CreateFrame('CheckButton',nil,UIParent); overview.normalRegion=overview:CreateTexture(); overview.normalRegion:SetTexture(1234)
local skin=CreateFrame('CheckButton',nil,f); skin.Icon=skin:CreateTexture(); skin.Icon:SetTexture(5678); skin.Icon.layer='BORDER'
for _,tab in ipairs({overview,skin}) do tab:SetSize(50,50); tab:SetPoint('LEFT',f,'RIGHT',0,-80); tab:SetScript('OnEnter',function(b) GameTooltip:SetOwner(b,'ANCHOR_RIGHT') end) end
f.ProfessionsOverviewTab=overview; f.rightProfessionTabs={skin}
skin:SetScript('OnClick',function() skin:SetChecked(true); TEST.professionSelected=true end)
N:Refresh(); assert(overview:GetParent()==UIParent and skin.w==36 and skin.point[1]=='TOPRIGHT' and skin.point[4]==-10)
assert(overview.normalRegion:GetAlpha()==0 and skin.Icon:GetAlpha()==0 and N.controls[skin].professionIcon:GetTexture()==5678)
skin:Click(); skin.scripts.OnEnter(skin); assert(TEST.professionSelected and skin:GetChecked() and GameTooltip.owner==skin)
skin.Icon:SetTexture(6789); N:Refresh(); assert(N.controls[skin].professionIcon:GetTexture()==6789)
TEST.combat=true; skin:SetPoint('LEFT',f,'RIGHT',1,-90); N:Refresh(); assert(skin.point[1]=='LEFT'); TEST.combat=false; N:Refresh(); assert(skin.point[1]=='TOPRIGHT')
FS:SetModuleEnabled('Professions',false); N:Refresh(); assert(skin.w==50 and skin.point[1]=='LEFT' and skin.point[4]==0 and skin.Icon:GetAlpha()==1 and not N.controls[skin].professionIcon:IsShown())
overview:Hide(); f:Hide(); ProfessionsFrame=old; FS:SetModuleEnabled('Professions',true)

-- TEST: Profession modern scrollbar shows arrows and thumb while native scroll drag disabled state and restoration survive
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=ProfessionsFrame
ProfessionsFrame=CreateFrame('Frame','ProfessionsFrame',UIParent); local f=ProfessionsFrame; f.RecipeList=CreateFrame('Frame',nil,f)
local bar=CreateFrame('Frame',nil,f.RecipeList); f.RecipeList.ScrollBar=bar; bar.Track=CreateFrame('Frame',nil,bar)
local art=bar.Track:CreateTexture(); art:SetTexture('native-brown-track'); art:SetAlpha(.7)
bar.Back=CreateFrame('Button',nil,bar); bar.Forward=CreateFrame('Button',nil,bar)
bar.Back:SetScript('OnClick',function() TEST.recipeScroll=(TEST.recipeScroll or 0)-1 end); bar.Forward:SetScript('OnClick',function() TEST.recipeScroll=(TEST.recipeScroll or 0)+1 end)
bar.Track.Thumb=CreateFrame('Button',nil,bar.Track); local thumb=bar.Track.Thumb; thumb.normalRegion=thumb:CreateTexture(); thumb:SetScript('OnDragStart',function() TEST.recipeDragged=true end)
N:Refresh(); assert(art:GetAlpha()==0 and thumb.normalRegion:GetAlpha()==0 and FS.Style.plates[thumb]:IsShown())
assert(N.controls[bar.Back].glyph:GetText()=='^' and N.controls[bar.Forward].glyph:GetText()=='v')
bar.Back:Click(); bar.Forward:SetEnabled(false); bar.Forward:Click(); thumb.scripts.OnDragStart(); assert(TEST.recipeScroll==-1 and TEST.recipeDragged and not bar.Forward:IsEnabled())
FS:SetModuleEnabled('Professions',false); N:Refresh(); assert(art:GetAlpha()==.7 and thumb.normalRegion:GetAlpha()==1 and not FS.Style.plates[thumb]:IsShown())
f:Hide(); ProfessionsFrame=old; FS:SetModuleEnabled('Professions',true)
