-- TEST: Profile codec round trips structured data without treating text as executable code
function ExtensionFixture()
    ResetTest(); local FS=ForeverSuite; local E=FS.Extensions; E:Normalize(); E.undo={}; E.chat={}; E.lastChatKey=nil; E.loot={items=0,value=0,unknown=0}; E.alerts={}; E.queueActive=false; E.queueTarget=nil; E.xp=nil; E:Refresh()
    return FS,E,FS.modules.Workbench
end
local FS,E=ExtensionFixture(); local data={name='Aalire\n|cffff0000 text',flag=false,items={[12]=4},text='error("Do not run")'}
local encoded=E:Encode(data); local decoded,err=E:Decode(encoded)
assert(decoded.name==data.name and decoded.flag==false and decoded.items[12]==4 and decoded.text==data.text and err==nil)
assert(not E:Decode('return _G'))

-- TEST: Profile decoder rejects truncation duplicate keys unknown tags excessive data and excessive depth
local FS,E=ExtensionFixture()
for _,code in ipairs({'FS1:s10:short','FS1:t1:s1:a','FS1:ninf;','FS1:b2','FS1:t2:s1:ab1s1:ab0','FS1:x','FS1:t10001:','FS1:s200001:'..string.rep('x',200001)}) do assert(not E:Decode(code)) end
local value={}; local root=value; for i=1,25 do value.next={}; value=value.next end
assert(not pcall(E.Encode,E,root))
assert(not E:Decode(E:Encode({a=1})..'extra'))

-- TEST: Profile export excludes private notes observed groups history and profile manager data
local FS,E=ExtensionFixture(); local P=FS.modules.Profiles
FS.db.extras.guildNotes['Friend-Realm']='Private'; FS.db.extras.recentGroups['Friend-Realm']={name='Friend',time=1}; FS.db.loot.history={{text='Private loot'}}
local text=P:Export(); local data=assert(P:PreviewImport(text))
assert(not data.profiles and not data.setup and not data.patchLog and next(data.extras.guildNotes)==nil and next(data.extras.recentGroups)==nil and not data.loot.history)
assert(FS.db.extras.guildNotes['Friend-Realm']=='Private' and #FS.db.loot.history==1)
assert(not P:PreviewImport(E:Encode({format=1,settings={profiles={}}})))

-- TEST: Import preview is nonmutating and replacing the active profile keeps a restorable backup
local FS,E=ExtensionFixture(); local P=FS.modules.Profiles; P:Save('Import target'); FS.db.gear.warn=false
local source=P:Snapshot(); source.gear.warn=true; local before=FS.db.gear.warn
local candidate=P:PreviewImport(E:Encode({format=1,settings=source})); assert(candidate and FS.db.gear.warn==before)
assert(P:Import('Import target',candidate) and FS.db.gear.warn and FS.db.profiles.current=='Import target')
assert(#FS.db.profiles.backups>0)
local index; for i,b in ipairs(FS.db.profiles.backups) do if b.name=='Import target' and b.data.gear.warn==false then index=i end end
assert(index and P:RestoreBackup(index) and not FS.db.gear.warn)

-- TEST: Profile review applies only selected sections and preserves personal history
local FS,E,W=ExtensionFixture(); local P=FS.modules.Profiles
FS.db.gear.warn=false
FS.db.loot.history={{text='Keep this'}}
local baseline=P:Export()
assert(not P:ReviewImport(baseline))
local data=P:Snapshot()
data.gear.warn=true
data.loot.history={{text='Ignore this'}}
data.modules.Loot=not data.modules.Loot
local code=E:Encode({format=1,settings=data})
local review=assert(P:ReviewImport(code))
assert(#review.sections==2 and review.sections[1].key=='gear' and review.sections[2].key=='modules')
assert(not P:ImportSelected('Selective',review) and not FS.db.profiles.saved.Selective)
local previousLoot=FS.db.modules.Loot
W:Choose('Profiles')
for _,row in ipairs(W.rows) do if row.kind=='import' then W.selected=row; break end end
W:Perform(1,'Selective')
local dialog=E.dialog
assert(dialog and dialog:IsShown())
dialog.edit:SetText(code)
dialog.preview:GetScript('OnClick')()
assert(dialog.candidate and dialog.reviewText:IsShown() and not dialog.apply:IsEnabled())
dialog.reviewButtons[2]:GetScript('OnClick')()
assert(dialog.apply:IsEnabled())
dialog.edit:SetText(code..'x')
dialog.edit:GetScript('OnTextChanged')()
assert(not dialog.candidate and not dialog.reviewText:IsShown() and not dialog.apply:IsEnabled())
dialog.edit:SetText(code)
dialog.preview:GetScript('OnClick')()
dialog.reviewButtons[2]:GetScript('OnClick')()
dialog.apply:GetScript('OnClick')()
assert(FS.db.gear.warn and FS.db.modules.Loot==previousLoot and FS.db.loot.history[1].text=='Keep this')
assert(FS.db.profiles.current=='Selective' and #FS.db.profiles.backups>0)

-- TEST: Profile replacement backups are capped and combat and vendor transactions block import and restore
local FS,E=ExtensionFixture(); local P=FS.modules.Profiles
for i=1,9 do FS.db.gear.warn=i%2==0; P:Save('Bounded') end
assert(#FS.db.profiles.backups==5)
local data=P:Snapshot(); TEST.combat=true; assert(not P:Import('Blocked',data) and not P:RestoreBackup(1)); TEST.combat=false
FS.modules.Vendor.busy=true; assert(not P:Import('Blocked',data)); FS.modules.Vendor.busy=false
assert(not FS.db.profiles.saved.Blocked)

-- TEST: Character assignments load a saved profile after initialization and may be cleared
local FS,E=ExtensionFixture(); local P=FS.modules.Profiles; local oldName,oldRealm=UnitName,GetNormalizedRealmName
UnitName=function() return 'Aalire' end; GetNormalizedRealmName=function() return 'TestRealm' end
FS.db.gear.warn=false; P:Save('Character profile'); assert(P:AssignCharacter('Character profile'))
FS.db.gear.warn=true; E:Initialize(); assert(FS.db.gear.warn)
P:Save('Other character profile'); E:Initialize(); assert(not FS.db.gear.warn)
assert(P:AssignCharacter(nil) and not FS.db.profiles.characters['Aalire-TestRealm'])
UnitName,GetNormalizedRealmName=oldName,oldRealm

-- TEST: Setup text presets preview without changing live settings and apply only on finish
local FS,E=ExtensionFixture(); local I=FS.Installer; I:Show(); I.step=3; I:Refresh(); local old=FS.db.typography.global.size
I.window.choices[4]:Click(); assert(I.draft.preset=='Readable text' and FS.db.typography.global.size==old and I.window.layoutPreview.parts['Unit:player'].frame.label.font[2]==13)
assert(I:Apply() and FS.db.typography.global.size==18 and FS.db.typography.global.outline=='Thin')
I:Show(); I.step=3; I:Refresh(); I.window.choices[5]:Click(); assert(I:Apply() and FS.db.typography.global.size==12 and FS.db.unitFrames.scale==.85)

-- TEST: Settings search includes custom modules and typography and changing a found setting uses module normalization
local FS,E,W=ExtensionFixture(); W:Choose('Settings'); local indexed=E:SettingsIndex(); local found={}
for _,r in ipairs(indexed) do found[r.id]=r end
assert(found['Loot:fast'] and found['Vendor:protectRare'] and found['Nameplates:width'] and found['Typography:family'])
W.selected=found['Loot:fast']; W:Perform(2,''); assert(FS.db.loot.fast)
W.window.search:SetText('low durability'); W:Render(); assert(W.window.cells[1].row and W.window.cells[1].row.owner=='Gear')

-- TEST: Favorite settings survive profile storage and the favorites view contains only pinned settings
local FS,E,W=ExtensionFixture(); W:Choose('Settings')
for _,r in ipairs(W.rows) do if r.id=='Loot:fast' then W.selected=r end end; W:Perform(3,'')
FS.modules.Profiles:Save('Pinned'); FS.modules.Profiles:Save('Other'); FS.db.extras.settingFavorites={}; FS.modules.Profiles:Load('Pinned')
FS:ShowConfig(); FS.window.favorites:Click(); assert(W:Data().view=='Favorites' and #W.rows==1 and W.rows[1].id=='Loot:fast')

-- TEST: Saved profile comparison and support report open read-only previews
local FS,E,W=ExtensionFixture(); local P=FS.modules.Profiles
FS.db.gear.warn=false; assert(P:Save('Reference'))
assert(P:Save('Active')); FS.db.gear.warn=true
W:Choose('Profiles')
for _,r in ipairs(W.rows) do if r.name=='Reference' then W.selected=r end end
W:Perform(1,'')
assert(E.dialog:IsShown() and E.dialog.readOnly and E.dialog.edit:GetText():find('Gear: Warn',1,true))
assert(FS.db.gear.warn and FS.db.profiles.current=='Active')
E.dialog:Hide()
local old=FS.runtimeErrors
FS.runtimeErrors={'ADDON_ACTION_BLOCKED | ForeverSuite | TestAction | combat=true'}
W:Choose('Maintenance'); W:Perform(1,'')
local report=E.dialog.edit:GetText()
assert(E.dialog:IsShown() and E.dialog.readOnly and report:find('TestAction',1,true))
assert(report:find('Vendor:',1,true) and report:find('Interface',1,true) and report:find('nameplates:',1,true))
assert(not report:find('Active',1,true))
FS.runtimeErrors=old; E.dialog:Hide()

-- TEST: Layout presets switch placement visibility and alerts without changing other settings
local FS,E,W=ExtensionFixture(); local L=FS.Layout
FS.db.layout.frames.Clock={x=40,y=90,scale=1}
FS.db.quests.tracker=false; FS.db.map.coordinates=true
FS.db.extras.alerts.Keyword={sound='Bell',channel='SFX'}
W:Choose('Layout presets'); W:Perform(1,'Farming'); W:Build()
assert(#W.rows==1 and W.rows[1].id=='Farming')
FS.db.layout.frames.Clock.x=100; FS.db.quests.tracker=true; FS.db.map.coordinates=false
FS.db.extras.alerts.Keyword.sound='Silent'; FS.db.gear.warn=false
TEST.combat=true; assert(not E:UseContext('Farming')); TEST.combat=false
W.selected=W.rows[1]; W:Perform(2,'')
assert(FS.db.layout.frames.Clock.x==40 and not FS.db.quests.tracker and FS.db.map.coordinates)
assert(FS.db.extras.alerts.Keyword.sound=='Bell' and not FS.db.gear.warn)
assert(FS.db.profiles.saved[FS.db.profiles.current].layout.frames.Clock.x==40)
W:Perform(3,''); assert(not FS.db.extras.contexts.Farming)

-- TEST: Character stock keeps its last complete record and stays outside profile exports
local FS,E,W=ExtensionFixture()
local V=FS.modules.Vendor
local oldStock,oldName,oldRealm,oldSnapshot=ForeverSuiteStock,UnitName,GetNormalizedRealmName,V.Snapshot
ForeverSuiteStock={}
local name,unknown='Crafter',0
UnitName=function() return name end; GetNormalizedRealmName=function() return 'Realm' end
V.Snapshot=function() return {},{[42]=7},unknown end
W:Choose('Character stock'); W:Perform(1,''); W:Build()
assert(#W.rows==1 and W.rows[1].id=='Crafter-Realm')
assert(E:ObservedStock(42)==0)
unknown=1
assert(not E:RecordStock() and E:StockRecords()['Crafter-Realm'].counts[42]==7)
name='Other'
assert(E:ObservedStock(42)==7)
local exported=assert(FS.modules.Profiles:PreviewImport(FS.modules.Profiles:Export()))
assert(not exported.stock and not exported.extras.stock and not exported.extras.contexts['Crafter-Realm'])
W.selected=W.rows[1]; W:Perform(2,'')
assert(E.dialog:IsShown() and E.dialog.readOnly and E.dialog.edit:GetText():find('x7',1,true))
E.dialog:Hide()
W:Perform(3,''); assert(E:ObservedStock(42)==0)
ForeverSuiteStock,UnitName,GetNormalizedRealmName,V.Snapshot=oldStock,oldName,oldRealm,oldSnapshot

-- TEST: Character records update readable sections independently
local FS,E,W=ExtensionFixture()
local V,G=FS.modules.Vendor,FS.modules.Gear
local oldStock,oldBag,oldGear,oldTime=ForeverSuiteStock,V.Snapshot,G.Snapshot,time
local oldProfessions,oldInfo=GetProfessions,GetProfessionInfo
local stamp,unknown,readable=1000,0,true
ForeverSuiteStock={}
time=function() return stamp end
V.Snapshot=function() return {},{[42]=7},unknown end
G.Snapshot=function()
    if not readable then return {equipped=0,items={}} end
    return {equipped=1,averageItemLevel=22,lowest=60,items={{equipped=true,label='Head',id=11,name='Test Helm',itemLevel=22}}}
end
GetProfessions=function() return 3,nil,5 end
GetProfessionInfo=function(id)
    if id==3 then return 'Mining',0,40,75 end
    if readable then return 'Fishing',0,10,75 end
end
assert(E:RecordCharacter())
local record=E:StockRecords()[E:CharacterKey()]
assert(record.bagTime==1000 and record.gear.time==1000 and record.professions.time==1000)
assert(#record.professions.items==2 and record.gear.items[1].id==11)
stamp,unknown,readable=2000,1,false
assert(not E:RecordCharacter() and record.time==1000)
unknown=0
assert(E:RecordCharacter() and record.bagTime==2000 and record.time==2000)
assert(record.gear.time==1000 and record.professions.time==1000)
local report=W:CharacterRecordText(record)
assert(report:find('Test Helm',1,true) and report:find('Mining',1,true) and report:find('40 / 75',1,true))
ForeverSuiteStock,V.Snapshot,G.Snapshot,time=oldStock,oldBag,oldGear,oldTime
GetProfessions,GetProfessionInfo=oldProfessions,oldInfo

-- TEST: Trainer preview lists available ranks and reads Forever service order without training
local FS,E,W=ExtensionFixture()
local oldFrame,oldCount,oldInfo,oldCost,oldFilter=ClassTrainerFrame,GetNumTrainerServices,GetTrainerServiceInfo,GetTrainerServiceCost,GetTrainerServiceTypeFilter
local shown,filter=true,true
ClassTrainerFrame={IsShown=function() return shown end}
GetNumTrainerServices=function() return 5 end
GetTrainerServiceInfo=function(i)
    if i==1 then return 'Class skills','','header' end
    if i==2 then return 'Arcane Shot','Rank 2','available' end
    if i==3 then return 'Claw','available',1234,20,'Rank 3' end
    if i==4 then return 'Growl','used',5678 end
    return 'First Aid','available',9012
end
GetTrainerServiceCost=function(i) if i==2 then return 125 elseif i==3 then return 75,2 end end
GetTrainerServiceTypeFilter=function() return filter end
W:Choose('Trainer preview')
assert(#W.rows==3 and W.rows[1].text:find('Rank 2',1,true))
assert(W.rows[2].text:find('Rank 3',1,true) and W.rows[2].text:find('2 talent points',1,true))
assert(W.rows[3].text:find('Cost unavailable',1,true))
assert(W.status:find('Known coin subtotal: 0g 2s 0c',1,true))
assert(W.window.actionButtons[1]:IsShown() and W.window.actionButtons[2]:IsShown() and not W.window.actionButtons[3]:IsShown())
filter=false; W:Refresh(); assert(#W.rows==0 and W.status:find('Enable Available',1,true))
shown=false; W:Refresh(); assert(#W.rows==0 and W.status:find('Open a class',1,true))
W:Choose('Settings'); assert(W.window.actionButtons[2]:IsShown())
ClassTrainerFrame,GetNumTrainerServices,GetTrainerServiceInfo,GetTrainerServiceCost,GetTrainerServiceTypeFilter=oldFrame,oldCount,oldInfo,oldCost,oldFilter

-- TEST: Train All rechecks approval and waits for confirmation before buying the next skill
local FS,E,W=ExtensionFixture()
local oldFrame,oldCount,oldInfo,oldCost,oldBuy,oldMoney=ClassTrainerFrame,GetNumTrainerServices,GetTrainerServiceInfo,GetTrainerServiceCost,BuyTrainerService,GetMoney
local names={'Spell A','Spell B','Newly unlocked'}
local learned,issued={},{}
local prices={100,150,200}
local money=500
ClassTrainerFrame={IsShown=function() return true end}
GetNumTrainerServices=function() return 3 end
GetTrainerServiceInfo=function(i)
    return names[i],'Rank 1',learned[i] and 'used' or i==3 and not learned[1] and 'unavailable' or 'available'
end
GetTrainerServiceCost=function(i) return prices[i],0,0 end
GetMoney=function() return money end
BuyTrainerService=function(i)
    if i==2 then assert(learned[1]) end
    issued[#issued+1]=i
    C_Timer.After(.2,function() learned[i]=true; money=money-prices[i] end)
end
W:Choose('Trainer preview'); W:Perform(2,'')
assert(E.form:IsShown() and #issued==0)
prices[2]=151
E.form.save:Click()
assert(E.form:IsShown() and #issued==0 and not W.training)
E.form.cancel:Click()
prices[2]=150
money=200
W:Perform(2,''); E.form.save:Click()
assert(E.form:IsShown() and #issued==0 and not W.training)
money=500
E.form.save:Click(); Drain()
assert(#issued==2 and issued[1]==1 and issued[2]==2 and money==250)
assert(not learned[3] and not W.training)
BuyTrainerService=function(i) issued[#issued+1]=i end
W:Perform(2,''); E.form.save:Click(); Drain()
assert(#issued==3 and issued[3]==3 and not learned[3] and not W.training)
ClassTrainerFrame,GetNumTrainerServices,GetTrainerServiceInfo,GetTrainerServiceCost,BuyTrainerService,GetMoney=oldFrame,oldCount,oldInfo,oldCost,oldBuy,oldMoney

-- TEST: Undo restores reversible settings without rolling back observed loot or merchant history
local FS,E=ExtensionFixture(); local old=FS.db.gear.warn
FS:SettingAction(function() FS.db.gear.warn=not old end); assert(#E.undo==1)
FS.db.vendor.history={{date='Today',text='Completed sale'}}; E.loot.items=4
assert(E:Undo() and FS.db.gear.warn==old and #FS.db.vendor.history==1 and E.loot.items==4)
assert(not E:Undo())

-- TEST: Undo history is bounded and undo remains blocked in combat or during a merchant transaction
local FS,E=ExtensionFixture()
for i=1,15 do FS:SettingAction(function() FS.db.gear.warn=not FS.db.gear.warn end) end
assert(#E.undo==10); TEST.combat=true; assert(not E:Undo() and #E.undo==10); TEST.combat=false
FS.modules.Vendor.busy=true; assert(not E:Undo()); FS.modules.Vendor.busy=false

-- TEST: Accessibility palettes restore original colors and keep labels and distinct NPC health semantics
local FS,E=ExtensionFixture(); local N=FS.modules.Nameplates; local original=E.Copy(FS.moduleCardColors.Bags); local old=UnitCanAttack
FS.db.extras.palette='Color-friendly'; E:Refresh(); UnitCanAttack=function() return true end
local r,g,b=N:HealthColor('target',0,FS.db.nameplates); assert(r==1 and g==.55)
UnitCanAttack=function() return false end; r,g,b=N:HealthColor('target',0,FS.db.nameplates); assert(b==1 and r==.1)
FS.db.extras.palette='Original'; E:Refresh(); assert(FS.moduleCardColors.Bags[1]==original[1]); UnitCanAttack=old

-- TEST: Alert sounds respect mute channel volume behavior and repeated-notification cooldowns without changing CVars
local FS,E=ExtensionFixture(); local oldSound,oldCVar=PlaySound,SetCVar; local sounds,settings={},0
PlaySound=function(id,channel) sounds[#sounds+1]={id,channel} end; SetCVar=function() settings=settings+1 end
assert(not E:Alert('Keyword')); FS.db.extras.alerts.Keyword={sound='Bell',channel='Dialog'}
assert(E:Alert('Keyword') and not E:Alert('Keyword') and #sounds==1 and sounds[1][2]=='Dialog' and settings==0)
TEST.now=TEST.now+11; assert(E:Alert('Keyword') and #sounds==2); FS.db.extras.alerts.Keyword.sound='Silent'; assert(not E:Alert('Keyword',true))
PlaySound,SetCVar=oldSound,oldCVar

-- TEST: Notification Center keeps bounded history independent of sound and popup settings
local FS,E,W=ExtensionFixture()
E.notifications={}; E.noticeTimes={}
local config=E:AlertOptions('Low stock',true)
assert(config.history and not config.popup and config.sound=='Silent')
E:Alert('Low stock',false,'1 stock goal below target.')
E:Alert('Low stock',false,'Duplicate')
assert(#E.notifications==1 and not E.alertPopup)
W:Choose('Notification Center')
assert(#W.rows==1 and W.rows[1].text:find('below target',1,true))
W:Perform(1,'')
for _,entry in ipairs(W.rows) do if entry.name=='Low stock' then W.selected=entry end end
W:Perform(4,''); assert(config.popup and config.history)
W:Perform(4,''); assert(not config.popup and not config.history)
W:Perform(4,''); assert(config.popup and not config.history)
TEST.now=TEST.now+11; E:Alert('Low stock',false,'Only a popup')
assert(E.alertPopup:IsShown() and #E.notifications==1)
E:Alert('Low stock',true,'Sound test')
assert(#E.notifications==1 and E.alertPopup.label:GetText():find('Only a popup',1,true))
W:Choose('Notification Center'); W:Perform(2,''); assert(#E.notifications==0)
config.popup=false; config.history=true
for i=1,55 do TEST.now=TEST.now+11; E:Alert('Low stock',false,tostring(i)) end
assert(#E.notifications==50 and E.notifications[1].message=='55' and E.notifications[50].message=='6')
E.notifications={}; E.noticeTimes={}
Drain(); assert(not E.alertPopup:IsShown())

-- TEST: Merchant stock alerts require a confirmed shortage from a complete bag scan
local FS,E=ExtensionFixture()
local V=FS.modules.Vendor
E.notifications={}; E.noticeTimes={}
V:SetRule(8,false,0,4)
local original=V.Snapshot
local unknown,amount=1,0
V.Snapshot=function() return {},{[8]=amount},unknown end
V:NotifyLowStock(); assert(#E.notifications==0)
unknown,amount=0,4
V:NotifyLowStock(); assert(#E.notifications==0)
amount=3
V:NotifyLowStock(); assert(#E.notifications==1 and E.notifications[1].category=='Low stock')
V.Snapshot=original; E.notifications={}; E.noticeTimes={}

-- TEST: Rare sightings track readable NPCs once across signals and show optional portraits
local FS,E,W=ExtensionFixture()
local oldGUID,oldName,oldClass,oldPortrait,oldDead,oldControlled=UnitGUID,UnitName,UnitClassification,SetPortraitTexture,UnitIsDeadOrGhost,UnitPlayerControlled
local id,kind,dead=42,'rareelite',false
UnitGUID=function() return 'Creature-0-1-2-3-'..id..'-001' end
UnitName=function() return 'Test beast' end
UnitClassification=function() return kind end
UnitIsDeadOrGhost=function() return dead end
UnitPlayerControlled=function() return false end
local portraitUnit
SetPortraitTexture=function(_,unit) portraitUnit=unit end
E.notifications={}; E.noticeTimes={}; E.sightings={}
E:AlertOptions('Rare or elite',true).popup=true
assert(not E:ObserveNPC('target','Target'))
W:Choose('Rare sightings'); W:Perform(1,'')
local scanner
for _,frame in ipairs(TEST.frames) do
    if frame.events.UPDATE_MOUSEOVER_UNIT and frame.events.NAME_PLATE_UNIT_ADDED then scanner=frame end
end
assert(scanner)
scanner.scripts.OnEvent(scanner,'NAME_PLATE_UNIT_ADDED','nameplate1')
scanner.scripts.OnEvent(scanner,'PLAYER_TARGET_CHANGED')
assert(#E.sightings==1 and #E.notifications==1 and E.sightings[1].source=='Nameplate')
assert(portraitUnit=='nameplate1' and E.alertPopup.portrait:IsShown())
id,kind=43,'elite'; assert(not E:ObserveNPC('target','Target'))
W:Perform(2,''); assert(E:ObserveNPC('target','Target') and #E.notifications==2)
id,dead=44,true; assert(not E:ObserveNPC('target','Target'))
W:Perform(1,''); assert(not scanner.events.NAME_PLATE_UNIT_ADDED)
UnitGUID,UnitName,UnitClassification,SetPortraitTexture,UnitIsDeadOrGhost,UnitPlayerControlled=oldGUID,oldName,oldClass,oldPortrait,oldDead,oldControlled
E.notifications={}; E.noticeTimes={}; E.sightings={}; Drain()

-- TEST: Per-NPC nameplate rules apply only to matching readable NPC IDs and preserve the global design
local FS,E=ExtensionFixture(); local N=FS.modules.Nameplates; local old=UnitGUID
UnitGUID=function(unit) return unit=='target' and 'Creature-0-1-2-3-12345-0001' or 'Creature-0-1-2-3-54321-0001' end
FS.db.nameplates.width=240; FS.db.nameplates.positions.name.y=27; assert(E:SaveNPCRule(E:NPCID('target')))
FS.db.nameplates.width=190; FS.db.nameplates.positions.name.y=17; N:SettingsChanged()
assert(N:UnitDesign('target').width==240 and N:UnitDesign('target').positions.name.y==27 and N:UnitDesign('other').width==190)
assert(FS.db.nameplates.width==190); UnitGUID=old

-- TEST: Corrupt NPC rule values are ignored and rule caches clear after global design changes
local FS,E=ExtensionFixture(); local N=FS.modules.Nameplates; local old=UnitGUID
UnitGUID=function() return 'Creature-0-1-2-3-12-0001' end
FS.db.extras.npcRules[12]={width=99999,positions=true,enemyColor='Invalid'}
assert(N:UnitDesign('target').width==FS.db.nameplates.width)
FS.db.nameplates.width=210; N:SettingsChanged(); assert(N:UnitDesign('target').width==210)
UnitGUID=old

-- TEST: Important spell IDs emphasize readable enemy casts without triggering protected actions
local FS,E=ExtensionFixture(); local N=FS.modules.Nameplates; local old=UnitCastingInfo
local f=N:CreateCanvas(UIParent); f.cast:Show(); f.cast.label:SetText('Dangerous cast'); FS.db.extras.importantSpells[777]=true
UnitCastingInfo=function() return 'Dangerous cast','',123,0,1000,false,1,false,777 end
N:CastAppearance(f,'target',FS.db.nameplates); assert(f.cast.label:GetText()=='! Dangerous cast')
FS.db.extras.importantSpells[777]=nil; f.cast.label:SetText('Dangerous cast'); N:CastAppearance(f,'target',FS.db.nameplates); assert(f.cast.label:GetText()=='Dangerous cast')
UnitCastingInfo=old

-- TEST: Keyword highlighting is literal case-insensitive and preserves links textures and color escape payloads
local FS,E=ExtensionFixture(); assert(E:AddKeyword('wow'))
local link='|Hitem:123|h[wow item]|h'; local icon='|TInterface/wow:12|t'
local result,found=E:Highlight('|cffffffffWOW|r '..link..' '..icon)
assert(found and result:find('|cffffce52WOW|r',1,true) and result:find(link,1,true) and result:find(icon,1,true))
assert(not E:AddKeyword('WoW') and not E:AddKeyword('|c'))
assert(not E:Decode('os.execute("anything")'))

-- TEST: Keyword lists and chat capture are bounded opt-in and duplicate chat-window deliveries are ignored
local FS,E=ExtensionFixture()
E:ChatMessage('CHAT_MSG_SAY','hello','Friend',1); assert(#E.chat==0)
FS.db.extras.captureChat=true; E:ChatMessage('CHAT_MSG_SAY','hello','Friend',1); E:ChatMessage('CHAT_MSG_SAY','hello','Friend',1); assert(#E.chat==1)
for i=2,250 do E:ChatMessage('CHAT_MSG_SAY','message '..i,'Friend',i) end
assert(#E.chat==200 and not FS.db.extras.chat)
for i=1,25 do E:AddKeyword('word'..i) end; assert(#FS.db.extras.keywords==20)

-- TEST: Chat filter lifecycle installs once removes when disabled and preserves trailing event arguments
local FS,E=ExtensionFixture(); local oldAdd,oldRemove=ChatFrame_AddMessageEventFilter,ChatFrame_RemoveMessageEventFilter; local adds,removes=0,0
E.filtersInstalled=false; ChatFrame_AddMessageEventFilter=function() adds=adds+1 end; ChatFrame_RemoveMessageEventFilter=function() removes=removes+1 end
E:AddKeyword('hello'); E:UpdateFilters(); assert(adds==#E.chatEvents)
local out={E.filter(nil,'CHAT_MSG_SAY','hello','Friend','tail')}; assert(out[1]==false and out[2]:find('hello',1,true) and out[3]=='Friend' and out[4]=='tail')
FS:SetModuleEnabled('Chat',false); assert(removes==#E.chatEvents and not E.filtersInstalled)
ChatFrame_AddMessageEventFilter,ChatFrame_RemoveMessageEventFilter=oldAdd,oldRemove

-- TEST: Guild favorites and private notes remain local and preserve normal roster filtering
local FS,E=ExtensionFixture(); local oldN,oldInfo,oldGuild=GetNumGuildMembers,GetGuildRosterInfo,GetGuildInfo
GetNumGuildMembers=function() return 2 end
GetGuildRosterInfo=function(i) return i==1 and 'Alice' or 'Bob','Member',1,10,'HUNTER','Zone','','',true end
GetGuildInfo=function() return 'Test guild' end
local key=E:PlayerKey('Bob'); FS.db.extras.guildFavorites[key]=true; FS.db.extras.guildNotes[key]='Private reminder'
FS.modules.Guild:Build(); assert(FS.modules.Guild.rows[1].name=='Bob' and not FS.modules.Guild.rows[1].text:find('Private reminder',1,true))
FS.db.extras.showPrivateNotes=true; FS.modules.Guild:Build(); assert(FS.modules.Guild.rows[1].text:find('Private reminder',1,true))
GetNumGuildMembers,GetGuildRosterInfo,GetGuildInfo=oldN,oldInfo,oldGuild

-- TEST: Recent group-member history is opt-in respects Social disable and trims old records
local FS,E=ExtensionFixture(); local oldExists,oldName,oldSame,oldRaid=UnitExists,UnitName,UnitIsUnit,IsInRaid
UnitExists=function(unit) return unit=='party1' end; UnitName=function() return 'Friend','Realm' end; UnitIsUnit=function() return false end; IsInRaid=function() return false end
E:GroupChanged(); assert(next(FS.db.extras.recentGroups)==nil)
FS.db.extras.trackGroups=true; E:GroupChanged(); assert(FS.db.extras.recentGroups['Friend-Realm'])
FS.db.social.enabled=false; FS.db.extras.recentGroups={}; E:GroupChanged(); assert(next(FS.db.extras.recentGroups)==nil)
for i=1,120 do FS.db.extras.recentGroups[tostring(i)]={name=tostring(i),time=i} end; E:Trim(FS.db.extras.recentGroups,100)
local n=0; for _ in pairs(FS.db.extras.recentGroups) do n=n+1 end; assert(n==100 and not FS.db.extras.recentGroups['1'])
UnitExists,UnitName,UnitIsUnit,IsInRaid=oldExists,oldName,oldSame,oldRaid

-- TEST: Named item checklists count carried stock without modifying vendor rules or item protections
local FS,E=ExtensionFixture(); TEST.data[456]={name='Test item',quality=1,price=3}; AddItem(1,456,4)
assert(E:Checklist('Dungeon supplies',456,10)); local rows=E:ChecklistRows(); assert(#rows==1 and rows[1].owned==4 and rows[1].required==10 and rows[1].text:find('Missing 6',1,true))
assert(not FS.db.vendor.rules[456] and not E:Checklist('',456,1) and not E:Checklist('Bad',0,1) and not E:Checklist('Bad',456,0))

-- TEST: Dungeon journal merges game and Group Finder entries and links to preparation
local FS,E,W=ExtensionFixture()
local oldInstances,oldBosses,oldLFG,oldCurrent=EJ_GetInstanceByIndex,EJ_GetEncounterInfoByIndex,C_LFGList,GetInstanceInfo
EJ_GetInstanceByIndex=function(i,raid) if i==1 and not raid then return 10,'Test dungeon' end end
EJ_GetEncounterInfoByIndex=function(i,instance)
    assert(instance==10)
    if i==1 then return 'Test boss','A description.',20 end
end
C_LFGList={
    GetAvailableActivities=function(category) return category==2 and {101,102} or {103} end,
    GetActivityInfoTable=function(id)
        return {fullName=({[101]='Test dungeon',[102]='Fallback dungeon',[103]='Fallback raid'})[id],
            minLevelSuggestion=15,maxLevelSuggestion=20,mapID=100+id}
    end,
}
GetInstanceInfo=function() return nil,'none' end
W.journalInstance=nil; W.journalFilter=nil
W:Choose('Dungeon & Raid Journal')
assert(#W.rows==3 and W.rows[1].text:find('15-20',1,true))
assert(W.rows[2].instance.journalID==10 and W.rows[2].instance.minimum==15)
W:Perform(3,''); W:Perform(3,''); W:Build(); assert(#W.rows==1 and W.rows[1].instance.kind=='Raid')
W:Perform(3,''); W:Build(); W.selected=W.rows[2]; W:Perform(1,''); W:Build()
assert(#W.rows==2 and W.rows[1].name=='Test boss' and W.rows[2].kind=='journal-notes')
W.selected=W.rows[1]; W:Perform(1,'')
assert(E.dialog:IsShown() and E.dialog.edit:GetText()=='A description.')
E.dialog:Hide()
W:Perform(4,''); assert(E.form:IsShown() and E.form.edits[1]:GetText()=='Test dungeon' and E.form.edits[2]:GetText()=='Test boss')
E.form.edits[3]:SetText('42'); E.form.save:Click()
assert(not E.form:IsShown())
W:Perform(2,''); assert(W:Data().view=='Dungeon preparation' and W.prepActivity=='Test dungeon')
assert(E:Data().preparation['Test dungeon'])
W.prepActivity=nil; W.journalInstance=nil; W.journalFilter=nil
EJ_GetInstanceByIndex,EJ_GetEncounterInfoByIndex,C_LFGList,GetInstanceInfo=oldInstances,oldBosses,oldLFG,oldCurrent

-- TEST: Journal opens instance-specific Run Notes and returns to the same instance
local FS,E,W=ExtensionFixture()
local oldInstances,oldBosses,oldLFG=EJ_GetInstanceByIndex,EJ_GetEncounterInfoByIndex,C_LFGList
EJ_GetInstanceByIndex=function(i,raid) if i==1 and not raid then return 10,'Test dungeon' end end
EJ_GetEncounterInfoByIndex=function(i) if i==1 then return 'Test boss','A description.',20 end end
C_LFGList=nil
assert(E:SaveRunNote('TEST DUNGEON','Test boss','Interrupt here.'))
assert(E:SaveRunNote('Other raid','Other boss','Stay spread.'))
W.journalInstance=nil; W.journalFilter=nil
W:Choose('Dungeon & Raid Journal')
W.window.cells[1]:Click(); W.window.actionButtons[1]:Click()
local function openNotes()
    for i,entry in ipairs(W.rows) do if entry.kind=='journal-notes' then W.window.cells[i]:Click(); break end end
    assert(W.window.actionButtons[1]:GetText()=='Open notes')
    W.window.actionButtons[1]:Click()
    assert(W:Data().view=='Run Notes' and W.status:find('Test dungeon',1,true))
end
openNotes()
assert(#W.rows==1 and W.rows[1].note.boss=='Test boss')
W.window.actionButtons[1]:Click()
assert(E.form.fieldCount==2 and E.form.heading:GetText():find('Test dungeon',1,true))
E.form.cancel:Click(); assert(#W.rows==1 and W:Data().view=='Run Notes')
W.window.actionButtons[1]:Click()
E.form.edits[1]:SetText('Second boss'); E.form.edits[2]:SetText('Swap after the cast.'); E.form.save:Click()
assert(#W.rows==2 and E:RunNote('Test dungeon','Second boss') and not E:RunNote('Other raid','Second boss'))
W.window.actionButtons[4]:Click()
assert(W:Data().view=='Dungeon & Raid Journal' and W.journalInstance.name=='Test dungeon')
openNotes()
W.window.search:SetText('Interrupt')
W:Choose('Run Notes')
assert(#W.rows==3 and W.window.search:GetText()=='' and not W.notesInstance)
W.window.actionButtons[1]:Click()
assert(E.form.fieldCount==3 and E.form.edits[1]:GetText()=='')
E.form.cancel:Click(); W.window.actionButtons[4]:Click()
assert(W:Data().view=='Dungeon & Raid Journal' and not W.journalInstance)
EJ_GetInstanceByIndex,EJ_GetEncounterInfoByIndex,C_LFGList=oldInstances,oldBosses,oldLFG

-- TEST: Observed encounter loot is tied to a matching instance and fills the wishlist form
local FS,E,W=ExtensionFixture()
local oldInfo,oldJournal,oldLFG=GetInstanceInfo,EJ_GetInstanceByIndex,C_LFGList
local oldFullName=UnitFullName
UnitFullName=function(unit) if unit=='player' then return 'Player','Home Realm' end end
local instance='Test instance'
GetInstanceInfo=function() return instance,'party',nil,nil,nil,nil,nil,123 end
EJ_GetInstanceByIndex=nil; C_LFGList=nil
E.recentEncounters={}
local events=E.events
local fire=events.scripts.OnEvent
assert(not E:ObserveEncounterLoot(10,42))
fire(events,'ENCOUNTER_END',10,'Loot boss')
instance='Elsewhere'; assert(not E:ObserveEncounterLoot(10,42))
instance='Test instance'
fire(events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Ignored player')
fire(events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Ignored player')
instance=''
assert(E:AddWishlistItem('Another instance','Loot boss',42))
assert(E:AddWishlistItem('Test instance','Unrelated boss',42))
W.journalInstance=nil; W.journalFilter=nil
W:Choose('Dungeon & Raid Journal'); assert(#W.rows==1 and W.rows[1].instance.source=='Observed encounters')
W.selected=W.rows[1]; W:Perform(1,''); W:Build()
assert(#W.rows==3 and W.rows[2].kind=='journal-loot' and W.rows[2].item==42)
assert(W.rows[2].text:find('[Observed]',1,true) and not W.rows[2].goalKey)
W.selected=W.rows[2]; W:Perform(4,'')
assert(E.form:IsShown() and E.form.edits[1]:GetText()=='Test instance'
    and E.form.edits[2]:GetText()=='Loot boss' and E.form.edits[3]:GetText()=='42')
E.form.save:Click()
local exact,key=E:WishlistGoalForDrop(' test INSTANCE ','LOOT BOSS',42)
assert(exact and W.rows[2].goalKey==key and W.rows[2].text:find('[Wanted]',1,true))
assert(W.window.actionButtons[4]:GetText()=='View goal')
assert(E:AddWishlistItem('Test instance','',42))
local general,generalKey=E:WishlistGoalForDrop('Test instance','Other boss',42)
assert(general and general.boss=='' and generalKey~=key)
assert(E:WishlistGoalForDrop('Test instance','Loot boss',42)==exact)
assert(not E:WishlistGoalForDrop('Unlisted instance','Loot boss',42))
instance='Test instance'
fire(events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Player-HomeRealm')
assert(exact.acquired and general.acquired and W.rows[2].text:find('[Acquired]',1,true))
for i=1,9 do assert(E:AddWishlistItem('Earlier instance','Boss',i)) end
W.window.cells[2]:Click(); W.window.actionButtons[4]:Click()
assert(W:Data().view=='Gear Wishlist' and W.selected.id==key and W.page==2)
local visible=false
for _,cell in ipairs(W.window.cells) do if cell.row and cell.row.id==key then visible=true end end
assert(visible)
local exported=assert(FS.modules.Profiles:PreviewImport(FS.modules.Profiles:Export()))
assert(not exported.extras.encounterLoot)
W.journalInstance=nil; E.recentEncounters={}
GetInstanceInfo,EJ_GetInstanceByIndex,C_LFGList=oldInfo,oldJournal,oldLFG
UnitFullName=oldFullName

-- TEST: Wishlist acquisition requires the matching boss or instance and an unambiguous player recipient
local FS,E,W=ExtensionFixture()
local oldInfo,oldFullName,oldCount,oldRaid=GetInstanceInfo,UnitFullName,GetNumGroupMembers,IsInRaid
GetInstanceInfo=function() return 'Test instance','party',nil,nil,nil,nil,nil,123 end
local other='Player'
UnitFullName=function(unit)
    if unit=='player' then return 'Player','Home Realm' end
    if unit=='party1' then return other,'Other Realm' end
end
GetNumGroupMembers=function() return 2 end
IsInRaid=function() return false end
assert(E:AddWishlistItem('Test instance','Matching boss',42))
assert(E:AddWishlistItem('Test instance','Different boss',42))
assert(E:AddWishlistItem('Test instance','',42))
assert(E:AddWishlistItem('Different instance','Matching boss',42))
E.recentEncounters={}; E.notifications={}; E.noticeTimes={}
local event=E.events.scripts.OnEvent
event(E.events,'ENCOUNTER_END',10,'Matching boss')
local function acquired()
    local count=0
    for _,goal in pairs(E:Data().wishlist) do if goal.acquired then count=count+1 end end
    return count
end
event(E.events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Player-OtherRealm')
event(E.events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Player')
assert(acquired()==0 and #E.notifications==0)
event(E.events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Player-HomeRealm')
assert(acquired()==2 and #E.notifications==1 and E.notifications[1].category=='Wishlist acquired')
event(E.events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Player-HomeRealm')
assert(acquired()==2 and #E.notifications==1)
for _,goal in pairs(E:Data().wishlist) do goal.acquired=false end
other='Different player'
event(E.events,'ENCOUNTER_LOOT_RECEIVED',10,42,'item:42',1,'Player')
assert(acquired()==2)
GetInstanceInfo,UnitFullName,GetNumGroupMembers,IsInRaid=oldInfo,oldFullName,oldCount,oldRaid
E.recentEncounters={}; E.notifications={}; E.noticeTimes={}

-- TEST: Run Notes match instance and encounter names and remain private on export
local FS,E,W=ExtensionFixture()
local previous=GetInstanceInfo
local instance='Test dungeon'
GetInstanceInfo=function() return instance,'party' end
E.notifications={}; E.noticeTimes={}
if E.alertPopup then E.alertPopup:Hide() end
W:Choose('Run Notes'); W:Perform(1,'')
E.form.edits[1]:SetText('Test dungeon'); E.form.edits[2]:SetText('Test boss')
E.form.edits[3]:SetText('Interrupt the first cast.'); E.form.save:Click()
assert(E:RunNote(' test dungeon ','TEST BOSS').note=='Interrupt the first cast.')
E.events.scripts.OnEvent(E.events,'ENCOUNTER_START',42,'Other boss')
assert(not E.alertPopup or not E.alertPopup:IsShown())
instance='Other dungeon'; assert(not E:EncounterRunNote('Test boss'))
instance='Test dungeon'
E.events.scripts.OnEvent(E.events,'ENCOUNTER_START',42,'Test boss')
assert(E.alertPopup:IsShown() and E.alertPopup.label:GetText():find('Interrupt the first cast.',1,true))
assert(#E.notifications==0)
local exported=assert(FS.modules.Profiles:PreviewImport(FS.modules.Profiles:Export()))
assert(not exported.extras.runNotes)
W:Build(); W.selected=W.rows[1]; W:Perform(3,''); assert(E.form:IsShown())
E.form.save:Click(); assert(not E:RunNote('Test dungeon','Test boss'))
GetInstanceInfo=previous; E.noticeTimes={}; Drain()

-- TEST: Gear Wishlist deduplicates source goals and preserves manually acquired status
local FS,E,W=ExtensionFixture()
assert(E:AddWishlistItem('Test raid','First boss',42))
assert(not E:AddWishlistItem(' test raid ','first boss',42))
assert(E:AddWishlistItem('Test raid','Second boss',42))
assert(not E:AddWishlistItem('Test raid','',0))
W:Choose('Gear Wishlist')
assert(#W.rows==2 and W.rows[1].text:find('First boss',1,true))
W.selected=W.rows[1]; W:Perform(2,''); W:Build()
assert(W.rows[2].goal.acquired and W.rows[2].text:find('[Acquired]',1,true))
local exported=assert(FS.modules.Profiles:PreviewImport(FS.modules.Profiles:Export()))
local key=W.rows[2].id
assert(exported.extras.wishlist[key].acquired)
W.selected=W.rows[2]; W:Perform(3,''); W:Build()
assert(#W.rows==1 and W.rows[1].goal.boss=='Second boss')

-- TEST: Next steps links to open goals and hides completed shopping and acquired gear
local FS,E,W=ExtensionFixture()
local A=FS.modules.AuctionHouse
local oldCount=C_Item.GetItemCount
C_Item.GetItemCount=function(id) return id==21 and 5 or 1 end
A:Data().shopping={[21]=5,[22]=3}
assert(E:AddWishlistItem('Test dungeon','Test boss',42))
assert(E:SavePreparation('Test dungeon',75,4,0))
E:Data().waypointQueue={{map=12,x=.5,y=.5,name='First stop'}}
FS:ShowConfig(); FS.window.nextSteps:Click()
assert(W:Data().view=='Next steps')
local byID={}
for _,entry in ipairs(W.rows) do byID[entry.id]=entry; if entry.goal then byID.gear=entry end end
assert(not byID['shopping:21'] and byID['shopping:22'].text:find('Need 2',1,true))
assert(byID['prepare:Test dungeon'] and byID.queue and byID.gear)
W.selected=byID['shopping:22']; W:Perform(1,'')
assert(A.window:IsShown() and A.selected.id==22)
W:Choose('Next steps')
for _,entry in ipairs(W.rows) do if entry.goal then W.selected=entry end end
W:Perform(2,''); W:Build()
for _,entry in ipairs(W.rows) do assert(not entry.goal) end
C_Item.GetItemCount=oldCount

-- TEST: Dungeon preparation shows activity targets and distinguishes missing and unreadable supplies
local FS,E,W=ExtensionFixture()
local G,V=FS.modules.Gear,FS.modules.Vendor
local oldGear,oldSnapshot,oldSlots=G.Snapshot,V.Snapshot,C_Container.GetContainerNumFreeSlots
G.Snapshot=function() return {lowest=80,broken=0,averageItemLevel=12} end
local unknown=0
V.Snapshot=function() return {},{[42]=2},unknown end
C_Container.GetContainerNumFreeSlots=function(bag) if bag==0 then return 4,0 elseif bag==1 then return 8,1 else return 0 end end
W:Choose('Dungeon preparation'); W:Perform(1,'Test dungeon'); W:Build()
assert(W.prepActivity=='Test dungeon' and #W.rows==3)
assert(E:SavePreparation('Test dungeon',90,5,15))
assert(not E:SavePreparation('Test dungeon',90,5.5,15))
assert(E:Checklist('Test dungeon',42,3))
W:Build()
for _,entry in ipairs(W.rows) do assert(entry.status=='Check',entry.text) end
assert(W.rows[4].text:find('2 / 3 carried',1,true))
unknown=1; W:Build(); assert(W.rows[4].status=='Unknown')
W.selected=W.rows[4]; W:Perform(3,'')
assert(E.form:IsShown() and E.form.edits[1]:GetText()=='42')
E.form.edits[2]:SetText('0'); E.form.save:Click()
assert(not E:Data().checklists['Test dungeon'][42])
W:Perform(4,''); W:Build(); assert(not W.prepActivity and W.rows[1].name=='Test dungeon')
G.Snapshot,V.Snapshot,C_Container.GetContainerNumFreeSlots=oldGear,oldSnapshot,oldSlots

-- TEST: Buyback is manual and rechecks merchant state price money and combat before spending
local FS,E=ExtensionFixture(); local oldN,oldInfo,oldBuy,oldMoney=GetNumBuybackItems,GetBuybackItemInfo,BuybackItem,GetMoney; local bought=0
GetNumBuybackItems=function() return 1 end; GetBuybackItemInfo=function() return 'Sold item',123,50,1 end; GetMoney=function() return 100 end; BuybackItem=function(i) assert(i==1); bought=bought+1 end
assert(not E:Buyback(1)); FS.modules.Vendor.merchantOpen=true; MerchantFrame:Show(); assert(E:Buyback(1) and bought==1)
GetMoney=function() return 10 end; assert(not E:Buyback(1)); TEST.combat=true; assert(not E:Buyback(1)); TEST.combat=false
assert(bought==1 and not E:Buyback(2)); GetNumBuybackItems,GetBuybackItemInfo,BuybackItem,GetMoney=oldN,oldInfo,oldBuy,oldMoney

-- TEST: Loot session totals use own received quantities and expose unknown prices separately
local FS,E=ExtensionFixture(); TEST.data[123]={name='Test loot',quality=1,price=7}
E:RecordLoot('You receive loot: |Hitem:123|h[Test loot]|h x2.'); assert(E.loot.items==2 and E.loot.value==14)
E:RecordLoot('Friend receives loot: |Hitem:123|h[Test loot]|h.'); assert(E.loot.items==2)
E:RecordLoot('You receive loot: |Hitem:9999|h[Unknown]|h.'); assert(E.loot.unknown==1 and E.loot.value==14)

-- TEST: XP session rates handle level rollover and never count negative XP as progress
local FS,E=ExtensionFixture(); local oldXP,oldMax,oldLevel=UnitXP,UnitXPMax,UnitLevel; local xp,max,level=50,100,1
UnitXP=function() return xp end; UnitXPMax=function() return max end; UnitLevel=function() return level end
E:ResetXP(); xp=80; E:ObserveXP(); xp=10; max=200; level=2; E:ObserveXP(); TEST.now=TEST.now+120
local gained,rate,eta=E:XPStats(); assert(gained==60 and math.abs(rate-1800)<.01 and math.abs(eta-380)<.01)
xp=5; E:ObserveXP(); assert(E.xp.gained==60); UnitXP,UnitXPMax,UnitLevel=oldXP,oldMax,oldLevel

-- TEST: Waypoint queue clones saved pins advances on arrival and stops after the last destination
local FS,M,d=NavigationFixture(); local E=FS.Extensions; E:Normalize(); E.queueActive=false
FS.db.extras.waypointQueue={{map=12,x=.55,y=.5,name='First'},{map=12,x=.8,y=.5,name='Second'}}
assert(E:StartQueue() and E.queueActive and M.destination.name=='First')
d.x=.55; M:RenderNavigation(); assert(#FS.db.extras.waypointQueue==1 and M.destination.name=='Second' and E.queueActive)
d.x=.8; M:RenderNavigation(); assert(#FS.db.extras.waypointQueue==0 and not E.queueActive and not M.destination)
d:restore()

-- TEST: Manual navigation supersedes queue tracking and missing position data never consumes destinations
local FS,M,d=NavigationFixture(); local E=FS.Extensions; E:Normalize(); E.queueActive=false
FS.db.extras.waypointQueue={{map=12,x=.7,y=.5,name='Queued'}}; E:StartQueue()
M:SetNavigation({map=12,x=.2,y=.5,name='Manual'}); E:QueueArrival(); assert(not E.queueActive and #FS.db.extras.waypointQueue==1)
d:restore()

-- TEST: Route Library saves and shares independent validated copies of the waypoint queue
local FS,E,W=ExtensionFixture()
local d=E:Data()
local oldMap=C_Map
C_Map={GetMapInfo=function(id) if id==12 then return {name='Zephras Isle'} end end}
d.waypointQueue={{map=12,x=.55,y=.5,name='First'},{map=34,x=.8,y=.5,name='Second'}}
W:Choose('Route Library')
W:Perform(1,'Morning loop'); W:Build()
assert(#W.rows==5 and d.routes['Morning loop'][2].name=='Second')
assert(W.rows[5].text:find('Zephras Isle +1 more',1,true))
for _,query in ipairs({'zephras isle','MAP 34','Second','morning loop'}) do
    W.window.search:SetText(query); W:Render()
    assert(W.window.cells[1].row.name=='Morning loop' and not W.window.cells[2].row)
end
W.window.search:SetText('')
C_Map=oldMap
W.selected=W.rows[5]; W:Perform(4,'')
assert(E.form:IsShown() and E.form.fieldCount==5)
E.form.edits[2]:SetText('Mining'); E.form.edits[3]:SetText('65'); E.form.edits[4]:SetText('1')
E.form.save:Click()
assert(E.form:IsShown() and not d.routeDetails['Morning loop'])
E.form.edits[3]:SetText('1'); E.form.edits[4]:SetText('65'); E.form.edits[5]:SetText('Recorded in game')
E.form.save:Click()
assert(not E.form:IsShown() and d.routeDetails['Morning loop'].minimum=='1')
W.window.search:SetText('mining 1-65'); W:Render()
assert(W.window.cells[1].row.name=='Morning loop' and not W.window.cells[2].row)
W.window.search:SetText(''); W:Render()
W.selected=W.rows[5]; W:Perform(3,'')
local code=E.dialog.edit:GetText()
assert(E.dialog.readOnly and not E:PreviewRoute(code))
E.dialog:Hide()
assert(E:RenameRoute('Morning loop','Evening loop'))
assert(d.routeDetails['Evening loop'].source=='Recorded in game' and not d.routeDetails['Morning loop'])
W:Build(); W.selected=W.rows[1]; W:Perform(3,'')
E.dialog.edit:SetText(code); E.dialog.preview:Click()
assert(E.dialog.apply:IsEnabled() and not d.routes['Morning loop'])
assert(E.dialog.status:GetText():find('Mining 1-65',1,true) and E.dialog.status:GetText():find('Recorded in game',1,true))
E.dialog.apply:Click()
assert(d.routes['Morning loop'] and d.routes['Evening loop'])
assert(d.routeDetails['Morning loop'].maximum=='65')
local legacy=assert(E:PreviewRoute(E:Encode({kind='route',version=1,name='Legacy route',stops=d.routes['Morning loop']})))
assert(not legacy.details)
assert(not E:PreviewRoute(E:Encode({kind='route',version=1,name='Bad tags',stops=legacy.stops,details={profession='Mining',minimum='1',maximum='0'}})))
assert(not E:PreviewRoute(E:Encode({kind='route',version=1,name='Invalid',stops={{map=0,x=.5,y=.5}}})))
W:Build()
for _,entry in ipairs(W.rows) do if entry.name=='Morning loop' then W.selected=entry end end
W:Perform(2,'')
assert(W:Data().view=='Waypoint queue' and d.waypointQueue[1].name=='First')
table.remove(d.waypointQueue,1)
assert(#d.routes['Morning loop']==2 and d.routes['Morning loop'][1].name=='First')
assert(E:RenameRoute('Morning loop','') and not d.routes['Morning loop'] and #d.waypointQueue==1)
assert(not d.routeDetails['Morning loop'] and d.routeDetails['Evening loop'].profession=='Mining')
d.routeDetails['Missing route']={source='Orphan'}
E.dataRef=nil; E:Normalize()
assert(not d.routeDetails['Missing route'] and d.routeDetails['Evening loop'].profession=='Mining')

-- TEST: Route Library previews pasted waypoint text and saves it without replacing the active queue
local FS,E,W=ExtensionFixture()
local d=E:Data()
local oldMap=C_Map
local maps={{mapID=37,name='Elwynn Forest'},{mapID=12,name='Zephras Isle'},{mapID=34,name='Duplicate'},{mapID=35,name='Duplicate'}}
C_Map={
    GetMapChildrenInfo=function() return maps end,
    GetBestMapForUnit=function() return 12 end,
    GetMapInfo=function(id) for _,map in ipairs(maps) do if map.mapID==id then return map end end end,
}
d.waypointQueue={{map=12,x=.5,y=.5,name='Existing'}}
W:Choose('Route Library')
for _,entry in ipairs(W.rows) do if entry.kind=='route-waypoints' then W.selected=entry end end
W:Perform(3,'Imported loop')
assert(E.dialog:IsShown() and not E.dialog.apply:IsEnabled())
E.dialog.edit:SetText('/way Elwynn Forest 43.2 65.1 First stop\r\n/way 45 60.2 Second stop\n/way #12 40.1 50.2 Last stop')
E.dialog.preview:Click()
assert(E.dialog.apply:IsEnabled() and not d.routes['Imported loop'])
E.dialog.apply:Click()
local route=d.routes['Imported loop']
assert(#route==3 and route[1].map==37 and math.abs(route[1].x-.432)<.000001)
assert(route[2].map==37 and route[3].map==12 and route[3].name=='Last stop')
assert(#d.waypointQueue==1 and d.waypointQueue[1].name=='Existing')
assert(E:PreviewWaypointText('/way 12.5 60','Current map').stops[1].map==12)
for _,bad in ipairs({'/way Duplicate 40 50','/way Unknown zone 40 50','/way #99 40 50','/way 101 50','/way 40 50\n/reload',string.rep('/way 40 50\n',51)}) do
    assert(not E:PreviewWaypointText(bad,'Invalid route'))
end
C_Map=oldMap

-- TEST: Route Library recommendations link to attributed guides without replacing waypoints
local FS,E,W=ExtensionFixture()
local d=E:Data()
d.waypointQueue={{map=12,x=.5,y=.5,name='Existing'}}
W:Choose('Route Library')
W.window.cells[4]:Click()
assert(W.selected.kind=='route-recommendations' and W.window.actionButtons[2]:GetText()=='Browse guides')
W.window.actionButtons[2]:Click()
assert(W:Data().view=='Profession recommendations' and #W.rows==8)
W.window.search:SetText('tin veins'); W:Render()
assert(W.window.cells[1].row.text:find('Westfall',1,true) and not W.window.cells[2].row)
W.window.cells[1]:Click(); W.window.actionButtons[1]:Click()
assert(E.dialog:IsShown() and E.dialog.readOnly and E.dialog.heading:GetText():find('65-125',1,true))
assert(E.dialog.edit:GetText():find('https://www.wow-professions.com/forever/mining-leveling-guide',1,true))
E.dialog.cancel:Click(); W.window.actionButtons[2]:Click()
assert(W:Data().view=='Route Library' and #d.waypointQueue==1 and d.waypointQueue[1].name=='Existing')

-- TEST: Gathering runs record own loot once and finish independently of the saved route
local FS,M,position=NavigationFixture()
local E,W=FS.Extensions,FS.modules.Workbench
E:Normalize()
assert(E:SaveRoute('Test run',{{map=12,x=.8,y=.5,name='Finish'}}))
assert(E:StartGathering('Test run') and not E:StartGathering('Test run'))
local capture
for _,f in ipairs(TEST.frames) do
    if f.events.CHAT_MSG_LOOT and f~=FS.modules.Loot.events then capture=f end
end
assert(capture and E.gathering)
local L=FS.modules.Loot
local own=L.OwnMessage
L.OwnMessage=function(_,msg) return msg:find('You receive',1,true)~=nil end
capture.scripts.OnEvent(capture,'CHAT_MSG_LOOT','Other receives |Hitem:7|h[Ore]|h x5.')
capture.scripts.OnEvent(capture,'CHAT_MSG_LOOT','You receive |Hitem:7|h[Ore]|h x3.')
assert(E.gathering.total==3 and E.gathering.items[7]==3)
position.x=.8; M:RenderNavigation()
local history=E:Data().gatheringRuns
assert(not E.gathering and not capture.events.CHAT_MSG_LOOT and #history==1)
assert(history[1].result=='Route completed' and #E:Data().routes['Test run']==1)
local saved=assert(FS.modules.Profiles:PreviewImport(FS.modules.Profiles:Export()))
assert(not saved.extras.gatheringRuns)
history[1].duration=60
history[2]={route='Test run',result='Route completed',duration=30,total=99,partial=true}
history[3]={route='Test run',result='Route completed',duration=120,total=4,items={[7]=1,[8]=3}}
W:Choose('Gathering runs')
for _,entry in ipairs(W.rows) do if entry.kind=='gathering-history' and entry.index==1 then W.selected=entry end end
W:Perform(3,'')
local report=E.dialog.edit:GetText()
assert(E.dialog:IsShown() and report:find('x3 (+2)',1,true) and report:find('x0 (-3)',1,true))
assert(report:find('Loot per hour: 180.0 items',1,true) and report:find('-60 sec | -1 items',1,true))
E.dialog:Hide(); L.OwnMessage=own; position:restore()

-- TEST: Disabled generic modules release update scripts and optional subscriptions and restore them on enable
local FS,E=ExtensionFixture(); local C=FS.modules.Chat; C:SettingsChanged()
if C.window then C.window:Hide() end
assert(not C.events:GetScript('OnUpdate'))
FS:SetModuleEnabled('Chat',false); assert(not C.events.events.UPDATE_CHAT_WINDOWS and C.events.events.PLAYER_REGEN_ENABLED)
FS:SetModuleEnabled('Chat',true); assert(C.events.events.UPDATE_CHAT_WINDOWS)
local S=FS.modules.Social; S:ShowWindow(); assert(S.events:GetScript('OnUpdate')); S.window:Hide(); assert(not S.events:GetScript('OnUpdate'))

-- TEST: Tool lists defer hidden rebuilds and clamp the visible page after filtered rows shrink
local FS,E,W=ExtensionFixture()
local build,calls=W.Build,0
W:ShowWindow(); W.window:Hide()
W.Build=function(self)
    calls=calls+1
    self.rows={}
    for i=1,18 do self.rows[i]={id=i,text='Entry '..i,searchText='matching row '..i} end
end
W:SettingsChanged(); assert(calls==0)
W:ShowWindow(); assert(calls==1)
W.window.search:SetText('matching')
W.page=2; W:Render(); assert(W.window.cells[1].row.id==10)
for i=10,18 do W.rows[i].searchText='hidden' end
W:Render()
assert(W.page==1 and W.window.cells[9].row.id==9)
W.Build=build; W.window:Hide()

-- TEST: Bag cooldown events update pooled visuals without rebuilding inventory and shared plans avoid duplicate snapshots
local FS,E=ExtensionFixture(); local B,V=FS.modules.Bags,FS.modules.Vendor; B:ShowWindow(); local oldRefresh=B.Refresh; local rebuilt=0
B.Refresh=function() rebuilt=rebuilt+1 end
B.events.scripts.OnEvent(B.events,'SPELL_UPDATE_COOLDOWN'); assert(rebuilt==0)
B.Refresh=oldRefresh; local plan=V:BuildPlan(); local build=V.BuildPlan
V.BuildPlan=function() error('Duplicate inventory snapshot') end; local view=B:BuildView(plan); assert(view.plan==plan); V.BuildPlan=build

-- TEST: Unrelated addon loads do not rebuild unit geometry and unchanged waypoint updates do not rewrite fonts or anchors
local FS,M,d=NavigationFixture(); local E=FS.Extensions; E.queueActive=false; M:NavigationEvent('QUEST_ACCEPTED',11)
local U=FS.modules.UnitFrames; local settings=U.SettingsChanged; local rebuild=0; U.SettingsChanged=function() rebuild=rebuild+1 end
U.events.scripts.OnEvent(U.events,'ADDON_LOADED','UnrelatedAddon'); assert(rebuild==0); U.SettingsChanged=settings
M:RenderNavigation(); local apply=FS.ApplyFont; local point=M.navigator.distance.SetPoint; local fonts,points=0,0
FS.ApplyFont=function(self,...) fonts=fonts+1; return apply(self,...) end; M.navigator.distance.SetPoint=function(self,...) points=points+1; return point(self,...) end
for i=1,20 do M:RenderNavigation() end; assert(fonts==0 and points==0)
FS.fontGeneration=(FS.fontGeneration or 0)+1; M:RenderNavigation(); assert(fonts==2)
FS.ApplyFont=apply; M.navigator.distance.SetPoint=point; d:restore()

-- TEST: Extra data normalization removes corrupt entries and bounds queues keywords notes and backups
local FS,E=ExtensionFixture(); FS.db.extras.recentGroups={bad=true}; FS.db.extras.guildNotes={bad={}}; FS.db.extras.alerts.Keyword={sound={},channel='Invalid'}
FS.db.extras.keywords={true,'ok','|cBAD'}; FS.db.profiles.backups={false,{name='Broken'}}; E:Normalize()
assert(next(FS.db.extras.recentGroups)==nil and next(FS.db.extras.guildNotes)==nil and #FS.db.profiles.backups==0 and #FS.db.extras.keywords==1)
assert(FS.db.extras.alerts.Keyword.sound=='Silent' and FS.db.extras.alerts.Keyword.channel=='SFX')

-- TEST: New tools and text/form modals remain inside small viewports with maximum typography
local FS,E,W=ExtensionFixture(); local width,height=UIParent.w,UIParent.h; UIParent:SetSize(1024,768)
FS.db.typography.global.size=24; FS.Typography:Apply()
for _,view in ipairs(W.views) do W:Choose(view); local f=W.window; assert(f:GetHeight()*f:GetScale()<=737 and f:GetWidth()*f:GetScale()<=993); local p={f.section:GetPoint()}; local s={f.search:GetPoint()}; assert((s[5] or s[3])<(p[5] or p[3])) end
local f=E:Form('Long field labels in a small viewport',{{label='Checklist name',value='Supplies'},{label='Item ID',value='123'},{label='Required quantity',value='5'}},function() return true end)
assert(f:GetHeight()*f:GetScale()<=737)
local t=E:TextDialog('Copy chat history',string.rep('Long message\n',100),true); assert(t:GetHeight()*t:GetScale()<=737 and t.edit:GetHeight()>370)
t:Hide(); f:Hide(); UIParent:SetSize(width,height); FS.db.typography.global.size=0; FS.Typography:Apply()

-- TEST: Profile import dialog requires a valid preview and editing invalidates the candidate before Apply
local FS,E=ExtensionFixture(); local P=FS.modules.Profiles; local applied=0
local f=E:TextDialog('Import test','',false,function(text) return P:PreviewImport(text) end,function() applied=applied+1; return true end)
assert(not f.apply:IsEnabled()); f.edit:SetText(P:Export()); f.preview:Click(); assert(f.candidate and f.apply:IsEnabled() and applied==0)
f.edit:SetText('not a profile'); f.edit.scripts.OnTextChanged(f.edit); assert(not f.candidate and not f.apply:IsEnabled() and applied==0)
f.cancel:Click()

-- TEST: Live combat audit is read-only bounded and explicitly records geometry rather than correcting it
local FS,E=ExtensionFixture(); local b=MainActionBar; local point={b:GetPoint()}; local scale=b:GetScale()
for i=1,30 do E:Audit(i%2==0 and 'PLAYER_TARGET_CHANGED' or 'PLAYER_REGEN_DISABLED') end
assert(#E.audit==20 and b:GetScale()==scale); local now={b:GetPoint()}; for i,v in ipairs(point) do assert(now[i]==v) end

-- TEST: Modern ChatFrameUtil filters work without legacy globals and remove through the original API
local FS,E=ExtensionFixture(); local old,oldAdd,oldRemove=ChatFrameUtil,ChatFrame_AddMessageEventFilter,ChatFrame_RemoveMessageEventFilter; local adds,removes=0,0
ChatFrameUtil={AddMessageEventFilter=function() adds=adds+1 end,RemoveMessageEventFilter=function() removes=removes+1 end}; ChatFrame_AddMessageEventFilter=nil; ChatFrame_RemoveMessageEventFilter=nil
E.filtersInstalled=false; E:AddKeyword('modern'); assert(adds==#E.chatEvents)
FS.db.extras.keywordsEnabled=false; E:UpdateFilters(); assert(removes==#E.chatEvents)
ChatFrameUtil,ChatFrame_AddMessageEventFilter,ChatFrame_RemoveMessageEventFilter=old,oldAdd,oldRemove

-- TEST: Modal reuse keeps frame pools bounded and clears stale profile candidates when switching purposes
local FS,E=ExtensionFixture(); local a=E:Form('First',{{label='Name',value='A'},{label='ID',value='1'},{label='Count',value='2'}},function() return true end)
local poolSize=#a.edits
local b=E:Form('Second',{{label='Name',value='B'}},function() return true end); assert(a==b and #b.edits==poolSize and not b.edits[2]:IsShown())
local t=E:TextDialog('Import','',false,function() return {},'Valid' end,function() return true end); t.preview:Click(); assert(t.candidate)
local other=E:TextDialog('Copy','Read only',true); assert(other==t and not t.candidate and not t.applyAction and not t.apply:IsShown())
t:Hide(); assert(t.edit:GetText()==''); b:Hide()

-- TEST: Every registered module has a searchable entry and custom bag flags can be changed without a SettingsChanged method
local FS,E,W=ExtensionFixture(); local owners={}; for _,r in ipairs(E:SettingsIndex()) do owners[r.owner]=true end
for name in pairs(FS.modules) do assert(owners[name],name) end
W:Choose('Settings'); for _,r in ipairs(W.rows) do if r.id=='Bags:showEmpty' then W.selected=r end end
local before=FS.db.bags.showEmpty; W:Perform(2,''); assert(FS.db.bags.showEmpty~=before)

-- TEST: Native popup styling can be disabled and restored without disabling Social or its game window
local FS,E=ExtensionFixture(); local old=FriendsFrame; FriendsFrame=CreateFrame('Frame',nil,UIParent); FriendsFrame.Background=FriendsFrame:CreateTexture(); FriendsFrame.Background:SetAlpha(.41)
local N=FS.NativeWindows; N:Window(FriendsFrame,N.definitions[1]); assert(FriendsFrame.Background:GetAlpha()==0)
FS.db.extras.nativeWindows=false; N:Window(FriendsFrame,N.definitions[1]); assert(FriendsFrame.Background:GetAlpha()==.41 and FS:IsModuleEnabled('Social'))
FriendsFrame:Hide(); FriendsFrame=old

-- TEST: Client API diagnostics tolerate unavailable namespaces and report capability without calling it
local FS,E=ExtensionFixture(); local container,item,map=C_Container,C_Item,C_Map; C_Container=nil; C_Item=nil; C_Map=nil
local unavailable={}; for _,r in ipairs(FS:ClientCapabilities()) do if not r.available then unavailable[r.label]=true end end
assert(unavailable.Inventory and unavailable['Item information'] and unavailable['Map position']); C_Container,C_Item,C_Map=container,item,map

-- TEST: Nested setting operations form one undo step and observed private data survives profile imports
local FS,E=ExtensionFixture()
local snapshot,snapshots=E.SettingsSnapshot,0
E.SettingsSnapshot=function(self) snapshots=snapshots+1; return snapshot(self) end
FS:SettingAction(function() FS.db.gear.warn=false; FS:SettingAction(function() FS.db.loot.fast=true end) end)
assert(#E.undo==1 and snapshots==2)
FS:SettingAction(function() end); assert(#E.undo==1)
E.SettingsSnapshot=snapshot
assert(E:Undo() and FS.db.gear.warn and not FS.db.loot.fast)
FS.db.extras.guildNotes.Friend='Keep this'; FS.db.vendor.history={{date='Today',text='Keep sale'}}
local P=FS.modules.Profiles; local candidate=P:PreviewImport(P:Export()); assert(P:Import('Imported safely',candidate))
assert(FS.db.extras.guildNotes.Friend=='Keep this' and #FS.db.vendor.history==1)

-- TEST: Core extension subscriptions stop optional group tracking and XP recording when their modules are disabled
local FS,E=ExtensionFixture(); FS.db.extras.trackGroups=false; E:SyncEvents(); assert(not E.events.events.GROUP_ROSTER_UPDATE)
FS.db.extras.trackGroups=true; E:SyncEvents(); assert(E.events.events.GROUP_ROSTER_UPDATE)
FS:SetModuleEnabled('Social',false); assert(not E.events.events.GROUP_ROSTER_UPDATE)
FS:SetModuleEnabled('QoL',false); assert(not E.events.events.PLAYER_XP_UPDATE); FS:SetModuleEnabled('QoL',true); assert(E.events.events.PLAYER_XP_UPDATE)

-- TEST: Category selection opens a bounded direct menu instead of requiring a cycle through every tool
local FS,E,W=ExtensionFixture(); W:ShowWindow(); local f=W.window; f.section:Click(); assert(f.categoryMenu:IsShown() and #f.categoryMenu.buttons==#W.views)
f.categoryMenu.buttons[12]:Click(); assert(W:Data().view=='Item checklists' and not f.categoryMenu:IsShown())
f.section:Click(); f.categoryMenu.next:Click(); f.categoryMenu.next:Click()
assert(f.categoryMenu.page==3 and f.categoryMenu.buttons[#W.views]:IsShown() and not f.categoryMenu.buttons[1]:IsShown())
f.categoryMenu.buttons[#W.views]:Click(); assert(W:Data().view=='Profession recommendations')

-- TEST: Menu avoids a visible damage meter once, preserves separate placements and defers in combat
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; local A=FS.modules.ActionBars
local oldMeter=DamageMeter; local uw,uh=UIParent:GetWidth(),UIParent:GetHeight(); UIParent:SetSize(1280,1080)
A:SettingsChanged(); local menu=A.menuRoot; menu:Show(); FS.db.actionBars.menu=true
L:Register('MainMenu',menu,'Main Menu'); local oldRect=menu.GetRect
menu.GetRect=function() local p=FS.db.layout.frames.MainMenu; if p then return p.x+640-300,p.y-18,600,36 end; return 16,1028,600,36 end
DamageMeter=CreateFrame('Frame'); DamageMeter:Show(); DamageMeter.GetRect=function() return 0,900,300,180 end
TEST.combat=true; L:AvoidMeterOverlap(); assert(not FS.db.layout.frames.MainMenu)
TEST.combat=false; L:AvoidMeterOverlap(); local placement=FS.db.layout.frames.MainMenu; assert(placement and placement.y==870)
L:AvoidMeterOverlap(); assert(FS.db.layout.frames.MainMenu==placement)
L.active=true; FS.db.layout.frames.MainMenu=nil; L:AvoidMeterOverlap(); assert(not FS.db.layout.frames.MainMenu); L.active=false
menu.GetRect=oldRect; DamageMeter=oldMeter; UIParent:SetSize(uw,uh)

-- TEST: Map coordinates use symmetric text anchors and horizontal/vertical centering
ResetTest(); local FS=ForeverSuite; local M=FS.modules.Map; local label=FS.HUD.Label; local captured
M.coordinateFrame=nil
FS.HUD.Label=function(self,...)
    local t=label(self,...); captured=t; t.points={}
    t.ClearAllPoints=function(self) self.points={} end
    t.SetPoint=function(self,...) self.points[#self.points+1]={...} end
    t.SetJustifyH=function(self,v) self.horizontal=v end; t.SetJustifyV=function(self,v) self.vertical=v end
    return t
end
M:Tick(); FS.HUD.Label=label
assert(#captured.points==2 and captured.horizontal=='CENTER' and captured.vertical=='MIDDLE')
assert(captured.points[1][1]=='TOPLEFT' and captured.points[1][4]==6 and captured.points[1][5]==-3)
assert(captured.points[2][1]=='BOTTOMRIGHT' and captured.points[2][4]==-6 and captured.points[2][5]==3)

-- TEST: Portrait borders never receive opaque theme artwork over the player's or target's face
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames
if not U.frames.player then U:CreateUnit('player') end; if not U.frames.target then U:CreateUnit('target') end
FS.Style:Units()
for _,unit in ipairs({'player','target'}) do
    local rim=U.frames[unit].fsPortraitRim; assert(rim.fsThemeBorderOnly and rim.backdropColor[4]==0)
    for _,name in ipairs(FS.Themes.names) do FS.db.appearance.theme=name; FS.Themes:Register(rim); assert(not FS.Themes.frames[rim]) end
end
FS.db.appearance.theme='Legacy'

-- TEST: Grid lines and snapping share the screen center at odd resolutions and reuse lines after resize
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; local w,h=UIParent:GetWidth(),UIParent:GetHeight(); local center=UIParent.GetCenter
UIParent:SetSize(1365,769); UIParent.GetCenter=function() return 682.5,384.5 end
L:CreateGrid(); L.overlay:Show(); local lines=L.overlay.gridLines; local count=#lines; local vertical,horizontal={},{}
for _,line in ipairs(lines) do if line:IsShown() then
    local point,relative,anchor,x,y=line:GetPoint()
    if point=='BOTTOM' then vertical[x]=true; assert(x~=0 and x%32==0 and math.abs(x)<683)
    elseif point=='RIGHT' then horizontal[y]=true; assert(y~=0 and y%32==0 and math.abs(y)<385) else error('Unexpected grid anchor') end
end end
assert(vertical[32] and horizontal[32])
for x in pairs(vertical) do assert(vertical[-x]) end; for y in pairs(horizontal) do assert(horizontal[-y]) end
local target=CreateFrame('Frame'); L:Register('GridTest',target,'Grid Test'); local handle=CreateFrame('Frame')
handle.GetCenter=function() return 699.5,399.5 end; FS.db.layout.snap=true; L:Start(); L:Save('GridTest',handle)
assert(L:Placements().GridTest.x==32 and L:Placements().GridTest.y==384.5)
UIParent:SetSize(800,600); L:UpdateGrid(); assert(#lines==count); L:UpdateGrid(); assert(#lines==count)
UIParent.GetCenter=center; UIParent:SetSize(w,h); L:UpdateGrid(); L:Stop(); L.targets.GridTest=nil; L.handles.GridTest=nil

-- TEST: Resizing preserves physical center across scales and keeps dragged frames inside the viewport
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; local w,h=UIParent:GetWidth(),UIParent:GetHeight(); UIParent:SetSize(1280,720)
local f=CreateFrame('Frame'); f:SetSize(100,80); f.GetEffectiveScale=function(self) return self:GetScale()*UIParent:GetEffectiveScale() end
L:Register('ResizeTest',f,'Resize Test')
for _,scale in ipairs({.6,1,1.4,.8}) do
    FS.db.layout.frames.ResizeTest={x=100,y=200,scale=scale}; L:Apply('ResizeTest')
    local p,r,a,x,y=f:GetPoint(); assert(math.abs(x*scale-100)<.0001 and math.abs(y*scale-200)<.0001)
    assert(FS.db.layout.frames.ResizeTest.x==100 and FS.db.layout.frames.ResizeTest.y==200)
end
FS.db.layout.frames.ResizeTest={x=99999,y=-99999,scale=1.4}; L:ConstrainSaved('ResizeTest'); L:Apply('ResizeTest')
local saved=FS.db.layout.frames.ResizeTest; assert(saved.x==570 and saved.y==56)
local before={f:GetPoint()}; TEST.combat=true; saved.x=100; L:Apply('ResizeTest'); local after={f:GetPoint()}; assert(after[4]==before[4])
TEST.combat=false; L.targets.ResizeTest=nil; UIParent:SetSize(w,h)

-- TEST: World map controls filter addon markers and link the map to route planning
local FS,E,W=ExtensionFixture(); local M=FS.modules.Map
local oldMap,oldShift,oldUtil=WorldMapFrame,IsShiftKeyDown,MapUtil
local map=CreateFrame('Frame',nil,UIParent); map:SetSize(400,420); map:Show()
local canvas=CreateFrame('Frame',nil,map); canvas:SetSize(320,240); canvas:Show()
map.ScrollContainer={Child=canvas}
local mapID=12
map.GetMapID=function() return mapID end
map.SetMapID=function(_,id) mapID=id end
WorldMapFrame=map
MapUtil={GetDisplayableMapForPlayer=function() return 12 end}
M:Data().pins={{map=12,x=.25,y=.5,name='Mining spot'}}
E:Data().waypointQueue={{map=13,x=.1,y=.2,name='Elsewhere'}}
M:UpdatePins()
local controls=M.worldControls
local pin=M.pinFrames[1]
assert(controls:IsShown() and controls:GetWidth()*controls:GetScale()<=376)
assert(pin:IsShown() and select(4,pin:GetPoint())==80)
IsShiftKeyDown=function() return true end
pin:Click()
assert(#E:Data().waypointQueue==2 and not M.manualTarget)
local stop=M.routeFrames[1]
assert(stop:IsShown() and stop.number:GetText()=='2' and select(5,stop:GetPoint())==-120)
controls.stops:Click(); assert(not stop:IsShown() and pin:IsShown())
controls.pins:Click(); assert(not pin:IsShown())
controls.stops:Click(); assert(stop:IsShown())
mapID=13; M:UpdatePins(); assert(stop.number:GetText()=='1')
controls.zone:Click(); assert(mapID==12 and stop.number:GetText()=='2')
controls.routes:Click(); assert(W:Data().view=='Route Library' and W.window:IsShown())
M:Data().worldControls=false; M:UpdatePins(); assert(not controls:IsShown())
map:Hide(); WorldMapFrame,IsShiftKeyDown,MapUtil=oldMap,oldShift,oldUtil

-- TEST: Map chrome replaces dropdown reset settings and decoration while preserving map canvas pins and actions
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local oldMap,oldQuest=WorldMapFrame,QuestMapFrame
local map=CreateFrame('Frame','WorldMapFrame',UIParent); WorldMapFrame=map
map.NavBar=CreateFrame('Frame',nil,map); local navArt=map.NavBar:CreateTexture(); navArt:SetTexture('Blizzard-NavBar-Border')
map.ScrollContainer=CreateFrame('ScrollFrame',nil,map); local canvas=CreateFrame('Frame',nil,map.ScrollContainer)
local tile=canvas:CreateTexture(); tile:SetTexture('WorldMap-Tile'); local pin=CreateFrame('Button',nil,canvas)
pin.Icon=pin:CreateTexture(); pin.Icon:SetTexture('QuestLog-frame-devider-pin')
local filter=CreateFrame('DropdownButton',nil,map.ScrollContainer); filter.Icon=filter:CreateTexture(); filter.Icon:SetTexture('Blizzard-Filter-Icon')
filter.ResetButton=CreateFrame('Button',nil,filter); local resetArt=filter.ResetButton:CreateTexture(); resetArt:SetTexture('Blizzard-Red-Close')
local clicks=0; filter:SetScript('OnClick',function() clicks=clicks+1 end); filter.ResetButton:SetScript('OnClick',function() clicks=clicks+1 end)
local quest=CreateFrame('Frame',nil,map); map.QuestLog=quest; QuestMapFrame=quest
quest.SettingsButton=CreateFrame('Button',nil,quest); quest.SettingsButton.Icon=quest.SettingsButton:CreateTexture(); quest.SettingsButton.Icon:SetTexture('Blizzard-Cog')
local divider=quest:CreateTexture(); divider.GetAtlas=function() return 'QuestLog-frame-devider' end
N:MapChrome(map,true)
assert(N.controls[filter].glyph:GetText()=='...' and N.controls[filter.ResetButton].glyph:GetText()=='R')
assert(N.controls[quest.SettingsButton].glyph:GetText()=='...' and quest.SettingsButton.Icon:GetAlpha()==0)
assert(filter.Icon:GetAlpha()==0 and resetArt:GetAlpha()==0 and divider:GetAlpha()==0 and navArt:GetAlpha()==0)
assert(tile:GetAlpha()==1 and pin.Icon:GetAlpha()==1 and not N.controls[pin])
filter:Click(); filter.ResetButton:Click(); assert(clicks==2)
N:MapChrome(map,false); assert(filter.Icon:GetAlpha()==1 and resetArt:GetAlpha()==1 and divider:GetAlpha()==1 and quest.SettingsButton.Icon:GetAlpha()==1 and navArt:GetAlpha()==1)
assert(not N.controls[filter].plate:IsShown() and tile:GetAlpha()==1 and pin.Icon:GetAlpha()==1)
map:Hide(); WorldMapFrame,QuestMapFrame=oldMap,oldQuest

-- TEST: Assigned current profiles retain live edits across logout serialization and reload
local FS,E=ExtensionFixture(); local P=FS.modules.Profiles; local oldName,oldRealm=UnitName,GetNormalizedRealmName
UnitName=function() return 'ProfileTester' end; GetNormalizedRealmName=function() return 'TestRealm' end
P:Save('Reload profile'); P:AssignCharacter('Reload profile')
FS.db.layout.frames['Unit:player']={x=-200,y=150,scale=1.2}; FS.db.gear.warn=false
E:Initialize(); assert(FS.db.layout.frames['Unit:player'].scale==1.2 and not FS.db.gear.warn)
TEST.combat=true; FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGOUT'); TEST.combat=false
local stored=FS.db.profiles.saved['Reload profile']; assert(stored.layout.frames['Unit:player'].x==-200 and not stored.gear.warn)
ForeverSuiteDB=assert(E:Decode(E:Encode(FS.db))); FS:InitializeDatabase(); E:Initialize()
assert(FS.db.profiles.current=='Reload profile' and FS.db.layout.frames['Unit:player'].x==-200 and FS.db.layout.frames['Unit:player'].scale==1.2 and not FS.db.gear.warn)
UnitName,GetNormalizedRealmName=oldName,oldRealm

-- TEST: Menu corrections defer geometry mutations and never force native button visibility or enabled state
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
if not CharacterMicroButton then CharacterMicroButton=CreateFrame('Button','CharacterMicroButton',UIParent) end
A:SettingsChanged(); Drain(); local b=CharacterMicroButton; local saved=A.menuButtons[b]
local show,enabled=b.SetShown,b.SetEnabled; b.SetShown=function() error('Native visibility was rewritten') end; b.SetEnabled=function() error('Native enabled state was rewritten') end
A:ApplyMenu(); b.SetShown,b.SetEnabled=show,enabled; Drain()
b:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',50,50); assert(b.point[1]=='BOTTOMLEFT')
TEST.combat=true; Drain(); assert(b.point[1]=='BOTTOMLEFT' and A.pending)
local untouched=CreateFrame('Button',nil,UIParent); A:SkinButton(untouched,true); assert(not A.buttons[untouched])
TEST.combat=false; A:SettingsChanged(); Drain(); assert(b.point[1]=='TOPLEFT' and b:GetParent()==A.menuRoot)

-- TEST: Block diagnostics retain the latest local stack without replacing game logout callbacks
ResetTest(); local FS=ForeverSuite; local old=debugstack; debugstack=function() return 'Native callback stack' end
FS.events.scripts.OnEvent(FS.events,'ADDON_ACTION_FORBIDDEN','ForeverSuite','callback()')
assert(FS.lastBlockedStack=='Native callback stack'); debugstack=old

-- TEST: Temporary startup viewport cannot overwrite saved clock XP waypoint or quest-tracker positions
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; local w,h=UIParent:GetWidth(),UIParent:GetHeight()
local placements={Clock={889.22,790.22,1.4,72,28},ExperienceBar={56.44,1182,1.4,780,20},Waypoint={54,943.27,1.4,250,48},QuestTracker={841.55,539.89,1,300,384}}
local previous={}
UIParent:SetSize(1365,768)
for id,v in pairs(placements) do
    previous[id]=L.targets[id]; local f=CreateFrame('Frame',nil,UIParent); f:SetSize(v[4],v[5])
    FS.db.layout.frames[id]={x=v[1],y=v[2],scale=v[3]}; L:Register(id,f,id)
    assert(FS.db.layout.frames[id].x==v[1] and FS.db.layout.frames[id].y==v[2])
end
UIParent:SetSize(2133,1200); L:ApplyAll(); Drain()
for id,v in pairs(placements) do
    local saved=FS.db.layout.frames[id]; assert(saved.x==v[1] and saved.y==v[2] and saved.scale==v[3])
    local p,r,a,x,y=L.targets[id].frame:GetPoint(); assert(math.abs(x*v[3]-v[1])<.001 and math.abs(y*v[3]-v[2])<.001)
    L.targets[id]=previous[id]
end
UIParent:SetSize(w,h)

-- TEST: Dashboard search matches module names setting labels and aliases with literal multiword terms
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:ClearModuleFilter(); local f=FS.window
FS:SetModuleFilter('  NAMEPLATES  ','All'); assert(f.filteredCount==1 and f.filteredNames[1]=='Nameplates' and f.cards.Nameplates.card:IsShown())
FS:SetModuleFilter('dismount','All'); assert(f.filteredCount==1 and f.filteredNames[1]=='QoL')
FS:SetModuleFilter('dps','All'); assert(f.filteredCount==1 and f.filteredNames[1]=='Combat')
FS:SetModuleFilter('quest waypoint','All'); local found=false; for _,name in ipairs(f.filteredNames) do if name=='Map' then found=true end end; assert(found)
FS:SetModuleFilter('[no-such-module','All'); assert(f.filteredCount==0 and f.emptyModules:IsShown() and not f.previousModules:IsEnabled() and not f.nextModules:IsEnabled())
FS:ClearModuleFilter(); assert(f.filteredCount==f.cardCount and not f.emptyModules:IsShown())

-- TEST: Dashboard state filters follow toggles and clearing returns to the previous unfiltered page
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:ClearModuleFilter(); local f=FS.window
f.cardPage=3; FS:RefreshConfig(); f.moduleFilterButton:Click(); assert(f.moduleFilter=='Enabled')
for _,name in ipairs(f.filteredNames) do assert(FS:IsModuleEnabled(name)) end
FS:SetModuleEnabled('Gear',false); f.moduleFilterButton:Click(); assert(f.moduleFilter=='Disabled' and f.cards.Gear.card:IsShown())
for _,name in ipairs(f.filteredNames) do assert(not FS:IsModuleEnabled(name)) end
f.cards.Gear.toggle:Click(); assert(FS:IsModuleEnabled('Gear') and f.cards.Gear.page==0)
f.clearModuleSearch:Click(); assert(f.moduleFilter=='All' and f.cardPage==3 and not f.clearModuleSearch:IsEnabled())
f.cardPage=1; FS:RefreshConfig()

-- TEST: Dashboard search keyboard opens a unique result and Escape clears filters without changing profiles
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:ClearModuleFilter(); local f=FS.window; local name=FS.db.profiles.current
f.moduleSearch:SetText('Nameplates'); f.moduleSearch.scripts.OnTextChanged(f.moduleSearch)
local search=FS.Beginner.Search; local chosen; FS.Beginner.Search=function(self,query) chosen=query end
f.moduleSearch.scripts.OnEnterPressed(f.moduleSearch); assert(chosen=='nameplates')
FS:SetModuleFilter('','All'); chosen=nil; f.moduleSearch.scripts.OnEnterPressed(f.moduleSearch); assert(chosen==nil)
FS.Beginner.Search=search; FS:SetModuleFilter('loot','Disabled'); f.moduleSearch.scripts.OnEscapePressed(f.moduleSearch)
assert(f.moduleQuery=='' and f.moduleFilter=='All' and FS.db.profiles.current==name)
f.cardPage=2; FS:RefreshConfig(); f.moduleSearch.scripts.OnEscapePressed(f.moduleSearch); assert(f.cardPage==2)
f.cardPage=1; FS:RefreshConfig()

-- TEST: Dashboard filtering is session UI state and never mutates profile settings or undo history
local FS,E=ExtensionFixture(); FS:ShowConfig(); FS:ClearModuleFilter(); local snapshot=E:Encode(E:SettingsSnapshot()); local n=#E.undo
FS:SetModuleFilter('waypoint','All'); FS:SetModuleFilter(nil,'Disabled'); FS:ClearModuleFilter()
assert(E:Encode(E:SettingsSnapshot())==snapshot and #E.undo==n)

-- TEST: Dashboard card hover follows current palette and disabled icons remain distinguishable with labels
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:ClearModuleFilter(); local f=FS.window; f.cardPage=1; FS:RefreshConfig(); local c=f.cards.Gear
FS:SetModuleEnabled('Gear',false); assert(c.icon.desaturated and c.toggle:GetText()==FS.Text.disabled)
local old=FS.moduleCardColors.Gear; FS.moduleCardColors.Gear={.2,.8,.4}; c.card.scripts.OnEnter(c.card)
assert(c.hover:IsShown() and c.card.border[1]==.2 and c.card.border[2]==.8)
c.card.scripts.OnLeave(c.card); assert(not c.hover:IsShown())
FS.moduleCardColors.Gear=old; FS:SetModuleEnabled('Gear',true); assert(not c.icon.desaturated and c.toggle:GetText()==FS.Text.enabled)

-- TEST: Dashboard search controls fit large typography and no-result filtering retains stable window geometry
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:ClearModuleFilter(); local f=FS.window; local F=FS.Typography
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; F:Apply(); FS:RefreshConfig()
local height=f:GetHeight(); local searchY=-f.moduleSearch.point[3]
assert(f.bodyTop+searchY>=-f.profiles.point[3]+f.profiles:GetHeight())
assert(-f.cards.Bags.card.point[3]>=searchY+f.moduleSearch:GetHeight())
assert(f.moduleSearch:GetWidth()==460 and f.moduleFilterButton:GetWidth()==260 and f.moduleSearch:GetHeight()>=36)
FS:SetModuleFilter('no-result-zzzz','All'); assert(f:GetHeight()==height and f.emptyModules:IsShown())
FS:ClearModuleFilter(); FS.db.typography.global.size=0; FS.db.typography.global.scale=1; F:Apply(); FS:RefreshConfig()
