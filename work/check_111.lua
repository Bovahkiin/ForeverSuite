-- TEST: Release 111 fixture isolates auction jobs, native APIs and account price data
function Release111Fixture()
    ResetTest()
    local FS=ForeverSuite; FS.Hub.locked=false
    local A=FS.modules.AuctionHouse
    A.fullScan=nil; A.open=true; A.enchanter=nil
    if A.window then A.window:Hide() end
    FS.Hub:Data().auctionPrices={}; FS.Hub:Data().auctionScanRequests={}
    return FS,A
end

-- TEST: Auction price cache migrates legacy profiles and stays separate from exported settings
local FS,A=Release111Fixture(); local scope=A:Scope()
FS.db.auctionHouse.prices={[scope]={[5]={price=25,time=100,kind='per item'}}}
A:Normalize(); assert(A:Prices()[5].price==25 and next(FS.db.auctionHouse.prices)==nil)
local exported=FS.Extensions:Encode(FS.modules.Profiles:Snapshot())
assert(not exported:find('auctionPrices',1,true))
FS.db.auctionHouse.prices={[scope]={[5]={price=1,time=50,kind='per item'}}}
A:Normalize(); assert(A:Prices()[5].price==25)
local saved=FS.Hub:Data(); FS.Hub.locked=true
A:StoreScan({[5]={price=99,time=200,kind='per item'}})
assert(saved.auctionPrices[scope][5].price==25 and next(A:Prices())==nil)
FS.Hub.locked=false

-- TEST: Full auction scan consumes all results in batches and records minimum stack buyouts atomically
local FS,A=Release111Fixture(); local old=C_AuctionHouse; local requests,reads=0,0
C_AuctionHouse={ReplicateItems=function() requests=requests+1 end,GetNumReplicateItems=function() return 405 end,
    IsThrottledMessageSystemReady=function() return true end,
    GetReplicateItemInfo=function(i)
        reads=reads+1
        return 'Item',1,i==1 and 10 or 2,2,true,1,'',0,0,i==1 and 1000 or i==2 and 100 or 0,0,false,'','','',0,i<=2 and 42 or 43,true
    end}
assert(A:StartFullScan() and requests==1); A:Event('REPLICATE_ITEM_LIST_UPDATE')
assert(reads==200 and not A:Prices()[42]); Drain()
assert(reads==405 and not A.fullScan and A:Prices()[42].price==50 and not A:Prices()[43])
assert(A.scanMessage:find('complete',1,true)); assert(not A:StartFullScan() and requests==1)
C_AuctionHouse=old; A.open=false

-- TEST: Auction scan cancellation preserves prices and stale callbacks cannot finish another job
local FS,A=Release111Fixture(); local old=C_AuctionHouse
C_AuctionHouse={ReplicateItems=function() end,GetNumReplicateItems=function() return 500 end,
    GetReplicateItemInfo=function() return 'Item',1,1,2,true,1,'',0,0,25,0,false,'','','',0,44,true end}
A:StoreScan({[42]={price=50,time=1,kind='per item'}})
assert(A:StartFullScan()); A:ConsumeFullScan(); A:Event('AUCTION_HOUSE_CLOSED'); Drain()
assert(not A.fullScan and A:Prices()[42].price==50 and not A:Prices()[44])
A.open=true; FS.Hub:Data().auctionScanRequests={}; assert(A:StartFullScan())
A:ConsumeFullScan(); local original=FS.db; FS.db={auctionHouse=original.auctionHouse}; Drain()
assert(not A.fullScan and not A:Prices()[44]); FS.db=original
C_AuctionHouse=old; A.open=false

-- TEST: Auction scan rejects unavailable or throttled clients and times out without overwriting cache
local FS,A=Release111Fixture(); local old=C_AuctionHouse; local requests=0
C_AuctionHouse={}; assert(not A:StartFullScan())
C_AuctionHouse={ReplicateItems=function() requests=requests+1 end,GetNumReplicateItems=function() return 0 end,
    GetReplicateItemInfo=function() end,IsThrottledMessageSystemReady=function() return false end}
assert(not A:StartFullScan() and requests==0)
C_AuctionHouse.IsThrottledMessageSystemReady=function() return true end
TEST.combat=true; assert(not A:StartFullScan()); TEST.combat=false
assert(A:StartFullScan()); Drain(); assert(not A.fullScan and A.scanMessage:find('No scan response',1,true))
C_AuctionHouse=old; A.open=false

-- TEST: Native auction scan button starts directly in the auction window and disabling hides it
local FS,A=Release111Fixture(); local oldFrame,oldAPI=AuctionHouseFrame,C_AuctionHouse
AuctionHouseFrame=CreateFrame('Frame',nil,UIParent); C_AuctionHouse={ReplicateItems=function() end,
    GetNumReplicateItems=function() return 0 end,GetReplicateItemInfo=function() end}
A:InstallScanButton(); assert(A.scanButton:GetParent()==AuctionHouseFrame and A.scanButton.mouseEnabled~=false)
A.scanButton:Click(); assert(A.fullScan and A.scanButton:GetText()=='Stop scan')
A.scanButton:Click(); assert(not A.fullScan and A.scanButton:GetText()=='Scan all')
FS.db.auctionHouse.enabled=false; A:SettingsChanged(); assert(not A.scanButton:IsShown())
FS.db.auctionHouse.enabled=true; A:SettingsChanged(); assert(A.scanButton:IsShown() and not A.events:GetScript('OnUpdate'))
A.scanButton:Hide(); A.scanStatus:Hide(); A.scanRoot=nil
AuctionHouseFrame,C_AuctionHouse=oldFrame,oldAPI; A.open=false

-- TEST: Auction tooltip shows cached unit prices anywhere with age, clearing and duplicate protection
local FS,A=Release111Fixture(); A.open=false
A:StoreScan({[42]={price=100,time=1,kind='per item'}})
local tooltip=CreateFrame('Frame'); tooltip.GetItem=function() return 'Item','item:42' end
A:PriceTooltip(tooltip); assert(#tooltip.lines==2 and tooltip.lines[1]:find('AH per item',1,true))
A:PriceTooltip(tooltip); assert(#tooltip.lines==2)
tooltip.scripts.OnTooltipCleared(tooltip); tooltip.lines={}; A:PriceTooltip(tooltip); assert(#tooltip.lines==2)
A:Data().tooltips=false; tooltip.scripts.OnTooltipCleared(tooltip); tooltip.lines={}; A:PriceTooltip(tooltip); assert(#tooltip.lines==0)

-- TEST: Disenchant estimates require enchanting, supported equipment and every material price
local FS,A=Release111Fixture(); local old=C_Item.GetItemInfo; local oldLevel=C_Item.GetDetailedItemLevelInfo
local quality,level,class,equip,bind=2,15,4,'INVTYPE_CHEST',2
C_Item.GetItemInfo=function() return 'Armor','item:45',quality,level,1,'Armor','',1,equip,1,10,class,0,bind end
C_Item.GetDetailedItemLevelInfo=nil
local prices={[10940]={price=100,time=4,kind='per item'},[10938]={price=200,time=3,kind='per item'}}
local low,high,reason,stamp=A:DisenchantValue('item:45',prices)
assert(low==100 and high==400 and not reason and stamp==3)
prices[10938]=nil; low,high,reason=A:DisenchantValue('item:45',prices); assert(not low and reason:find('missing',1,true))
quality=0; assert(not A:DisenchantValue('item:45',prices)); quality=2
class=1; assert(not A:DisenchantValue('item:45',prices)); class=4
bind=4; assert(not A:DisenchantValue('item:45',prices)); bind=2
level=100; low,high,reason=A:DisenchantValue('item:45',prices); assert(not low and reason:find('item level',1,true))
C_Item.GetItemInfo,C_Item.GetDetailedItemLevelInfo=old,oldLevel

-- TEST: Disenchant tooltips invalidate profession detection and never treat listing totals as unit material prices
local FS,A=Release111Fixture(); local oldInfo,oldProfession,oldSkill,oldEnum=C_Item.GetItemInfo,C_TradeSkillUI,C_SkillInfo,Enum
Enum={Profession={Enchanting=8}}; local rank=1
C_TradeSkillUI={GetProfessionSkillLineID=function() return 333 end}
C_SkillInfo={GetSkillLineInfoByID=function() return {rank=rank,maxRank=75} end}
C_Item.GetItemInfo=function() return 'Armor','item:45',2,15,1,'Armor','',1,'INVTYPE_CHEST',1,10,4,0,2 end
A:StoreScan({[10940]={price=100,time=1,kind='per item'},[10938]={price=200,time=1,kind='per item'}})
local tooltip=CreateFrame('Frame'); tooltip.GetItem=function() return 'Armor','item:45' end
A:PriceTooltip(tooltip); assert(tooltip.lines[1]:find('Disenchant estimate',1,true))
rank=0; A:Event('SKILL_LINES_CHANGED'); tooltip.scripts.OnTooltipCleared(tooltip); tooltip.lines={}
A:PriceTooltip(tooltip); assert(#tooltip.lines==0)
rank=1; A:Event('SKILL_LINES_CHANGED'); A:Prices()[10938].kind='lowest listing'
A:PriceTooltip(tooltip); assert(tooltip.lines[1]:find('missing',1,true) and not tooltip.lines[1]:find('estimate:',1,true))
C_Item.GetItemInfo,C_TradeSkillUI,C_SkillInfo,Enum=oldInfo,oldProfession,oldSkill,oldEnum; A.enchanter=nil

-- TEST: Quest nameplate markers use own kill and item objectives, hide complete goals and cache tooltip work
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
local oldTip,oldQuest,oldEnum,oldBoss=C_TooltipInfo,C_QuestLog,Enum,UnitIsQuestBoss
Enum={TooltipDataLineType={QuestTitle=17,QuestObjective=8}}
local have,reads=0,0
C_QuestLog={GetNumQuestLogEntries=function() return 1 end,GetInfo=function() return {questID=7,title='Our Quest'} end,
    GetQuestObjectives=function() return {{text='Hides: '..have..'/3',finished=have>=3}} end}
C_TooltipInfo={GetUnit=function() reads=reads+1; return {lines={{type=17,leftText='Our Quest'},{type=8,leftText='Hides: '..have..'/3'}}} end}
UnitIsQuestBoss=function() return true end
N.questRevision=100; N.questObjectives=nil
local f=N:CreateCanvas(UIParent); TEST.units.nameplate1={name='Quest Mob',enemy=true}
N:UpdateQuestMarker(f,'nameplate1',FS.db.nameplates); assert(f.quest:IsShown() and reads==1)
N:UpdateQuestMarker(f,'nameplate1',FS.db.nameplates); assert(reads==1)
have=3; N.events.scripts.OnEvent(N.events,'QUEST_LOG_UPDATE'); N:UpdateQuestMarker(f,'nameplate1',FS.db.nameplates)
assert(not f.quest:IsShown() and reads==2)
C_TooltipInfo.GetUnit=function() return {lines={{type=8,leftText='Wolves slain: 1/4'}}} end
C_QuestLog.GetQuestObjectives=function() return {{text='Wolves slain: 1/4',finished=false}} end
N.questRevision=N.questRevision+1; N.questObjectives=nil
N:UpdateQuestMarker(f,'nameplate1',FS.db.nameplates); assert(f.quest:IsShown())
FS.db.nameplates.showQuest=false; N:UpdateQuestMarker(f,'nameplate1',FS.db.nameplates); assert(not f.quest:IsShown())
TEST.units.nameplate1=nil; f:Hide(); C_TooltipInfo,C_QuestLog,Enum,UnitIsQuestBoss=oldTip,oldQuest,oldEnum,oldBoss
N.questObjectives=nil; Drain()

-- TEST: Alt Tracker removal asks for confirmation and refuses deletion of a changed record
local FS,E,W=ExtensionFixture(); local oldHub=ForeverSuiteHub
ForeverSuiteHub={schemaVersion=1,characters={['Alt-Realm']={level=20,lastSeen=5}}}
W:Choose('Alt Tracker'); W.selected=W.rows[1]; W:Perform(3,'')
assert(E.form:IsShown() and ForeverSuiteHub.characters['Alt-Realm'])
E.form.cancel:Click(); assert(ForeverSuiteHub.characters['Alt-Realm'])
W.selected=W.rows[1]; W:Perform(3,''); ForeverSuiteHub.characters['Alt-Realm']={level=21,lastSeen=6}
E.form.save:Click(); assert(E.form:IsShown() and ForeverSuiteHub.characters['Alt-Realm'].level==21)
E.form.cancel:Click(); W:Build(); W.selected=W.rows[1]; W:Perform(3,''); E.form.save:Click()
assert(not ForeverSuiteHub.characters['Alt-Realm']); ForeverSuiteHub=oldHub
if W.window then W.window:Hide() end

-- TEST: Alt Tracker stays available with Bags disabled and preserves existing stock pins
local FS,E,W=ExtensionFixture(); FS.db.bags.enabled=false; FS.db.window.pinnedTools.stock=true
FS:ShowWorkspacePage('home'); local tool
for _,candidate in ipairs(FS.Workspace.tools) do if candidate.id=='stock' then tool=candidate end end
assert(tool and not tool.owner and tool.view=='Alt Tracker' and FS.db.window.pinnedTools.stock)
tool.open(); assert(W:Data().view=='Alt Tracker' and W.window:IsShown())
W.window:Hide(); FS.db.bags.enabled=true

-- TEST: Auction caches from newer DataHub formats remain untouched before hub initialization
local FS,A=Release111Fixture(); local oldHub=ForeverSuiteHub
ForeverSuiteHub={schemaVersion=999,characters={},auctionPrices={future=true}}
FS.db.auctionHouse.prices={[A:Scope()]={[8]={price=20,kind='per item',time=1}}}
A:Normalize(); assert(ForeverSuiteHub.auctionPrices.future and not ForeverSuiteHub.auctionPrices[A:Scope()])
assert(FS.db.auctionHouse.prices[A:Scope()][8] and next(A:Prices())==nil)
ForeverSuiteHub=oldHub

-- TEST: Oversized auction scan refuses partial results and keeps the previous cache
local FS,A=Release111Fixture(); local old=C_AuctionHouse
C_AuctionHouse={ReplicateItems=function() end,GetNumReplicateItems=function() return 20001 end,
    GetReplicateItemInfo=function(i) return 'Item',1,1,2,true,1,'',0,0,5,0,false,'','','',0,i,true end}
A:StoreScan({[40000]={price=10,time=1,kind='per item'}})
assert(A:StartFullScan()); A:ConsumeFullScan(); Drain()
assert(not A.fullScan and A:Prices()[40000] and not A:Prices()[1] and A.scanMessage:find('20,000',1,true))
C_AuctionHouse=old; A.open=false

-- TEST: Quest events coalesce plate refreshes and recycled plates never retain a previous quest target
ResetTest(); local N=ForeverSuite.modules.Nameplates
local oldRefresh,oldBoss,oldGUID,oldTip=N.RefreshPlates,UnitIsQuestBoss,UnitGUID,C_TooltipInfo
local refreshes=0; N.RefreshPlates=function() refreshes=refreshes+1 end
for i=1,20 do N.events.scripts.OnEvent(N.events,'QUEST_LOG_UPDATE') end
Drain(); assert(refreshes==1)
local guid,needed='First',true
UnitGUID=function() return guid end; UnitIsQuestBoss=function() return needed end; C_TooltipInfo=nil
TEST.units.nameplate1={name='Enemy',enemy=true}
local f=N:CreateCanvas(UIParent); N:UpdateQuestMarker(f,'nameplate1',ForeverSuite.db.nameplates); assert(f.quest:IsShown())
guid,needed='Second',false; N:UpdateQuestMarker(f,'nameplate1',ForeverSuite.db.nameplates); assert(not f.quest:IsShown())
N.RefreshPlates,UnitIsQuestBoss,UnitGUID,C_TooltipInfo=oldRefresh,oldBoss,oldGUID,oldTip
TEST.units.nameplate1=nil; N.questObjectives=nil; f:Hide()

-- TEST: Dragging tool windows keeps their saved UIParent anchor without ever anchoring to themselves
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; FS.db.layout.snap=false
for _,name in ipairs({'Workbench','Map','AuctionHouse'}) do
    local f=FS.modules[name]:CreateWindow(); local id='Tool:'..name
    f:SetScale(1); f.GetCenter=function() return 700,600 end
    local center=UIParent:GetCenter()
    f.scripts.OnDragStop(f)
    local saved=FS.db.layout.frames[id]
    assert(saved.x==700-center and saved.y==600 and saved.scale==1)
    local point,relative,anchor,x,y=f:GetPoint()
    assert(point=='CENTER' and relative==UIParent and anchor=='BOTTOM' and x==saved.x and y==saved.y)
    local snapshot=FS.modules.Profiles:Snapshot()
    assert(snapshot.layout.frames[id].x==saved.x and snapshot.layout.frames[id].y==saved.y)
    f:ClearAllPoints(); f:SetPoint('CENTER',UIParent,'CENTER',0,0); L:Apply(id)
    assert(select(2,f:GetPoint())==UIParent)
    f.GetCenter=nil; f:Hide()
end
Drain()

-- TEST: Layout saving keeps separate mover handles attached to the positioned frame
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; FS.db.layout.snap=true
local target=CreateFrame('Frame',nil,UIParent); target:SetSize(100,80)
local handle=CreateFrame('Frame',nil,UIParent); handle.GetCenter=function() return 563,683 end
L:Register('MoverAnchorTest',target,'Test'); L:Save('MoverAnchorTest',handle,1.2)
local point,relative,anchor=handle:GetPoint()
assert(point=='CENTER' and relative==target and anchor=='CENTER')
assert(select(2,target:GetPoint())==UIParent and target:GetScale()==1.2)
local saved=FS.db.layout.frames.MoverAnchorTest
assert(saved.x%32==0 and (saved.y-UIParent:GetHeight()/2)%32==0)
L.targets.MoverAnchorTest=nil; target:Hide(); handle:Hide(); Drain()
