-- TEST: Talent Advisor fixture loads only the active class and has no background ticker
local A=ForeverSuite.modules.TalentAdvisor
TEST.advisorOriginal={UnitClass=UnitClass,UnitLevel=UnitLevel,C_Traits=C_Traits,C_SpecializationInfo=C_SpecializationInfo,hub=ForeverSuiteHub,
    PlayerSpellsFrame=PlayerSpellsFrame,PlayerSpellsUtil=PlayerSpellsUtil,
    ClassTrainerFrame=ClassTrainerFrame,GetNumTrainerServices=GetNumTrainerServices,GetTrainerServiceInfo=GetTrainerServiceInfo,
    GetTrainerServiceCost=GetTrainerServiceCost,GetTrainerServiceTypeFilter=GetTrainerServiceTypeFilter,BuyTrainerService=BuyTrainerService,GetMoney=GetMoney}
function TalentFixture(class)
    ResetTest();local FS=ForeverSuite;FS:CloseOtherWindows()
    TEST.advisorClass=class or 'MAGE';UnitClass=function() return TEST.advisorClass,TEST.advisorClass end;UnitLevel=function() return 20 end
    ForeverSuiteHub={schemaVersion=1,characters={},legacy={imported=true}};FS.Hub:Initialize()
    local A=FS.modules.TalentAdvisor;A.catalog=nil;A.current={};A.currentReady=false;A.dirty=true;A.draft=nil;A.gearWeights=nil;A.gearPlan=nil;A.bundleUndo=nil;A.profileSelected=nil;A.tab='Overview';A.page=1;A.message=nil
    local c=A:Catalog();TEST.talentRanks={};TEST.talentStaged=false;TEST.talentAvailable=2;TEST.changedMax=false
    local ids={};for id in pairs(c.nodes) do ids[#ids+1]=id end;table.sort(ids)
    C_SpecializationInfo={GetActiveSpecGroup=function() return 1 end,GetCombatConfigIDForSpecGroup=function(group) assert(group==1);return 77 end}
    C_Traits={ConfigHasStagedChanges=function() return TEST.talentStaged end,GetConfigInfo=function(id) assert(id==77);return {treeIDs={900}} end,
        GetTreeNodes=function() return ids end,
        GetNodeInfo=function(_,id) local n=c.nodes[id];return {ranksPurchased=TEST.talentRanks[id] or 0,maxRanks=n.max+(TEST.changedMax and 1 or 0),entryIDs={id+1000000}} end,
        GetEntryInfo=function(_,id) return {definitionID=id-1000000} end,
        GetDefinitionInfo=function(id) return {spellID=c.nodes[id].spells[1]} end,
        GetTreeCurrencyInfo=function() return {{quantity=TEST.talentAvailable}} end}
    A:SyncLifecycle();return FS,A,c
end
local FS,A,c=TalentFixture()
assert(c.class=='MAGE' and A.catalog==c and not A.events:GetScript('OnUpdate'))
assert(FS.Hub:Data().talents==nil)

-- TEST: All nine Talent Advisor catalogs validate every guide allocation and retain attribution
local FS,A=TalentFixture();local classes,builds,nodes=0,0,0
for class in pairs(FS.TalentCatalogLoaders) do
    TEST.advisorClass=class;A.catalog=nil;local c=A:Catalog();classes=classes+1
    for id,n in pairs(c.nodes) do nodes=nodes+1;assert(n.id==id and n.row>=0 and n.row<=6 and n.column>=0 and n.column<=3 and #n.spells>=1) end
    for _,p in ipairs(c.builds) do
        builds=builds+1;local ranks,why=A:ValidatePlan(p);assert(ranks,why)
        assert(#p.order<=51 and p.source:find('https://www.icy-veins.com/wow-forever/',1,true)==1 and p.author~='' and p.checked=='2026-11-22')
        for id in pairs(p.optional) do assert(ranks[id]) end
    end
end
assert(classes==9 and builds==73 and nodes>=450)
TEST.advisorClass='MAGE';A.catalog=nil

-- TEST: Talent Advisor reads committed live traits and rejects staged changed or missing client data
local FS,A,c=TalentFixture();local p=c.builds[1]
for i=1,6 do local id=p.order[i];TEST.talentRanks[id]=(TEST.talentRanks[id] or 0)+1 end
local ranks=A:ReadCurrent();assert(ranks and A.currentSpent==6 and A.available==2)
TEST.talentStaged=true;local data,why=A:ReadCurrent();assert(not data and why:find('pending',1,true))
TEST.talentStaged=false;TEST.changedMax=true;data,why=A:ReadCurrent();assert(not data and why:find('ranks changed',1,true))
TEST.changedMax=false;C_Traits.GetDefinitionInfo=function() return {spellID=99999999} end
data,why=A:ReadCurrent();assert(not data and why:find('spell differs',1,true))
C_Traits=nil;assert(not A:ReadCurrent())

-- TEST: Talent Advisor next point follows the saved route and refuses divergent live builds
local FS,A,c=TalentFixture();local p=c.builds[1];assert(A:Select(p.id));A:ReadCurrent()
assert(A:NextPoint()==p.order[1])
for i=1,7 do local id=p.order[i];TEST.talentRanks[id]=(TEST.talentRanks[id] or 0)+1 end
A:ReadCurrent();assert(A:NextPoint()==p.order[8])
local target=A:Ranks(p.order);local extra
for id,n in pairs(c.nodes) do if not target[id] and n.gate==0 then extra=id;break end end
assert(extra);TEST.talentRanks[extra]=1;A:ReadCurrent();local id,why=A:NextPoint();assert(not id and why:find('differs',1,true))

-- TEST: Talent Advisor editing enforces gates prerequisites maximum ranks and flexible choices
local FS,A,c=TalentFixture();assert(A:NewDraft());local p=c.builds[1]
local deep;for id,n in pairs(c.nodes) do if n.gate>=30 then deep=id;break end end
assert(not A:EditTalent(deep,false,false) and #A.draft.order==0)
for i=1,10 do assert(A:EditTalent(p.order[i],false,false)) end
local id=p.order[1];assert(A:EditTalent(id,false,true) and A.draft.optional[id])
assert(A:SavePlan('Test plan','Tester','Personal build notes'))
local saved=A:Selected();assert(saved.name=='Test plan' and saved.origin=='personal' and saved.optional[id] and not A.draft)
local before=#saved.order;TEST.combat=true;assert(not A:EditTalent(id,true,false) and #saved.order==before);TEST.combat=false
assert(not A:SavePlan('|bad','Tester','Notes'))

-- TEST: Talent Advisor share codes are inert bounded class checked and never overwrite existing community builds
local FS,A,c=TalentFixture();A:Select(c.builds[1].id)
local code=A:ExportPlan();assert(code:sub(1,6)=='FSTA1:')
assert(A:ImportShare(code));local p=A:Selected();assert(p.origin=='community' and not p.reviewedAt and p.reference:find('icy-veins',1,true))
assert(not A:ImportShare(code));assert(A:ReviewBuild() and p.reviewedAt)
assert(not A:DecodeShare('FSTA1:FS1:loadstring("bad")'))
assert(not A:DecodeShare('FSTA1:'..string.rep('x',60001)))
local wire=FS.Extensions:Decode(code:sub(7));wire.plan.class='WARRIOR';assert(not A:ImportShare('FSTA1:'..FS.Extensions:Encode(wire)))
wire.plan.class='MAGE';wire.plan.version='old';assert(not A:ImportShare('FSTA1:'..FS.Extensions:Encode(wire)))
wire.plan.version=c.version;wire.plan.order={999999};assert(not A:DecodeShare('FSTA1:'..FS.Extensions:Encode(wire)))
local saved=FS.Hub:Data().talents;FS.Hub.locked=true;assert(not A:ImportShare(code) and FS.Hub:Data().talents==saved);FS.Hub.locked=nil

-- TEST: Talent Advisor gear linking preserves Custom scales and caches build validation for repeated comparisons
local FS,A,c=TalentFixture();A:Select(c.builds[1].id)
local G=FS.modules.GearAdvisor;G:Data().preset='Custom';G:Data().weights={Intellect=12}
assert(not A:LinkGear());local w=G:Weights();assert(w.Intellect==12 and G:Data().preset=='Custom')
G:Data().preset='Auto';assert(A:LinkGear());A.gearWeights=nil
local validate=A.ValidatePlan;local calls=0;A.ValidatePlan=function(self,...) calls=calls+1;return validate(self,...) end
local first=G:Weights();for i=1,50 do assert(G:Weights()==first) end
assert(calls==1);A.ValidatePlan=validate
assert(not A.events:GetScript('OnUpdate'));A:ShowWindow();assert(not A.events:GetScript('OnUpdate'))
Drain();local reads=0;local read=A.ReadCurrent;A.ReadCurrent=function(self,...) reads=reads+1;return read(self,...) end
for i=1,30 do A.events.scripts.OnEvent(A.events,'TRAIT_CONFIG_UPDATED',77) end
assert(reads==0);Drain();assert(reads==1);A.ReadCurrent=read;A.window:Hide()

-- TEST: Talent Advisor build profiles persist in DataHub preview gear and layout choices and undo cleanly
local FS,A,c=TalentFixture();A:Select(c.builds[1].id)
local original=A:Selected();local G=FS.modules.GearAdvisor
G:Data().preset='Caster';FS.db.layout.frames.TestFrame={x=40,y=50,scale=1}
A:Data().includeLayout=true;assert(A:SaveBundle('Caster setup'));local id=A.profileSelected
local bundle=A:Library().profiles[id];assert(bundle.layout.TestFrame.x==40 and bundle.plan.name==original.name)
G:Data().preset='Agility';FS.db.layout.frames.TestFrame.x=99
assert(A:UseBundle(id,false) and G:Data().preset=='Caster' and FS.db.layout.frames.TestFrame.x==99)
assert(A:Selected().name==original.name and A:Data().activeBundle==id)
A.draft=nil;A.catalog=nil;assert(A:Selected().name==original.name)
assert(A:UndoBundle() and G:Data().preset=='Agility' and FS.db.layout.frames.TestFrame.x==99)
assert(A:UseBundle(id,true) and FS.db.layout.frames.TestFrame.x==40)
assert(A:UndoBundle() and FS.db.layout.frames.TestFrame.x==99)
local code='FSTA1:'..FS.Extensions:Encode(bundle);local decoded=A:DecodeShare(code);assert(decoded.name=='Caster setup')
assert(A:ImportShare(code) and A:Library().profiles[A.profileSelected].name=='Caster setup')
local profile=FS.modules.Profiles:Export();assert(not profile:find('Caster setup',1,true))

-- TEST: Talent Advisor window tabs source tools sharing and large typography stay usable and reuse cells
local FS,A,c=TalentFixture();A:Select(c.builds[1].id);A:ShowWindow();local f=A.window
assert(f:IsShown() and #f.nav==5 and f.heading:GetText()=='Talent Advisor')
for _,tab in ipairs({'Overview','Builds','Talents','Gear','Profiles'}) do A.tab=tab;A:Refresh();assert(f:GetHeight()>0 and f:GetScale()*f:GetHeight()<=UIParent:GetHeight()-31) end
A.tab='Talents';A:Refresh();local count=0;for _,b in pairs(f.talentButtons) do if b:IsShown() then count=count+1;assert(b.talent.group>=1 and b.talent.group<=3) end end
assert(count>=50);local before=#TEST.frames;for i=1,20 do A:Refresh() end;assert(#TEST.frames==before)
FS.db.typography.global.size=24;FS.db.typography.global.scale=1.5;FS.Typography:Apply();A:Refresh()
assert(f:GetScale()*f:GetHeight()<=UIParent:GetHeight()-31 and -f.close.point[3]+f.close:GetHeight()<=f:GetHeight())
FS.db.typography.global.size=0;FS.db.typography.global.scale=1;FS.Typography:Apply()
A:ShowPointOrder();assert(FS.Extensions.dialog:IsShown());FS.Extensions.dialog:Hide();A:ShowWindow()
FS:SetModuleEnabled('TalentAdvisor',false);assert(not f:IsShown() and not A.events:GetScript('OnUpdate'));FS:SetModuleEnabled('TalentAdvisor',true)

-- TEST: Native trainer Train all previews costs and trains without ever opening Control Center or Workbench
function NativeTrainerFixture()
    ResetTest();local FS=ForeverSuite;FS:CloseOtherWindows();local W=FS.modules.Workbench
    if W.training then W:StopTraining('Fixture') end
    ClassTrainerFrame=CreateFrame('Frame','ClassTrainerFrame',UIParent);ClassTrainerFrame:SetSize(338,430)
    ClassTrainerFrame.TrainButton=CreateFrame('Button',nil,ClassTrainerFrame);ClassTrainerFrame.TrainButton:SetSize(80,22)
    TEST.lessons={{name='Spell A',cost=100},{name='Profession recipe',cost=150}};TEST.trained={};TEST.money=500
    GetNumTrainerServices=function() return #TEST.lessons end
    GetTrainerServiceInfo=function(i) local s=TEST.lessons[i];return s.name,TEST.trained[i] and 'used' or 'available',100+i,1,'Rank 1' end
    TEST.legacyTrainerCost=false
    GetTrainerServiceCost=function(i)
        local s=TEST.lessons[i]
        if TEST.legacyTrainerCost then return s.cost,s.talent or 0,s.slots or 0 end
        return s.cost,(s.slots or 0)>0
    end
    GetTrainerServiceTypeFilter=function() return true end;GetMoney=function() return TEST.money end
    BuyTrainerService=function(i) TEST.actions[#TEST.actions+1]=i;C_Timer.After(.2,function() TEST.trained[i]=true;TEST.money=TEST.money-TEST.lessons[i].cost end) end
    FS.Training:Refresh();return FS,W,ClassTrainerFrame.fsTrainAll
end
local FS,W,b=NativeTrainerFixture();assert(b:IsShown() and b:IsEnabled() and b:GetText()=='Train all')
assert(b.point[2]==ClassTrainerFrame.TrainButton and b:GetWidth()<=92)
b:Click();assert(FS.Extensions.form:IsShown() and #TEST.actions==0 and FS.Extensions.form.heading:GetText():find('2 skills',1,true))
FS.Extensions.form.save:Click();Drain()
assert(#TEST.actions==2 and TEST.money==250 and not W.training)
assert((not FS.window or not FS.window:IsShown()) and (not W.window or not W.window:IsShown()))
assert(not FS.Training.events:GetScript('OnUpdate'))

-- TEST: Native trainer buttons respect filters unknown costs funds profession slots and changed approvals
local FS,W,b=NativeTrainerFixture()
TEST.legacyTrainerCost=true
TEST.lessons[1].slots=1;TEST.lessons[2].talent=1;FS.Training:Refresh();assert(not b:IsEnabled())
TEST.lessons[1].slots=0;TEST.lessons[2].talent=0;TEST.money=10;FS.Training:Refresh();assert(not b:IsEnabled())
TEST.money=500;GetTrainerServiceTypeFilter=function() return false end;FS.Training:Refresh();assert(not b:IsEnabled())
GetTrainerServiceTypeFilter=function() return true end;FS.Training:Refresh();b:Click()
TEST.lessons[2].cost=200;FS.Extensions.form.save:Click();assert(#TEST.actions==0 and FS.Extensions.form:IsShown())
FS.Extensions.form.cancel:Click();assert(not W.window or not W.window:IsShown())
FS.db.qol.trainAllButton=false;FS.modules.QoL:SettingsChanged();assert(not b:IsShown());FS.db.qol.trainAllButton=true

-- TEST: Native trainer batches stop on close or combat and ignore stale queued requests
local FS,W,b=NativeTrainerFixture();b:Click();FS.Extensions.form.save:Click()
ClassTrainerFrame:Hide();Drain();assert(not W.training and #TEST.actions==0)
FS,W,b=NativeTrainerFixture();b:Click();FS.Extensions.form.save:Click();Drain()
assert(#TEST.actions==2 and not W.training)
FS,W,b=NativeTrainerFixture();b:Click();FS.Extensions.form.save:Click();TEST.combat=true
FS.Training.events.scripts.OnEvent(FS.Training.events,'PLAYER_REGEN_DISABLED');Drain();assert(#TEST.actions==0 and not W.training)
TEST.combat=false

-- TEST: Talent Advisor profile switches discard drafts and undo without losing account builds or leaking names
local FS,A,c=TalentFixture();local P=FS.modules.Profiles
assert(P:Save('Before talents'));A:Select(c.builds[1].id);assert(A:SavePlan('Private build name','Tester','Private note'))
assert(A:SaveBundle('Private profile name'));assert(A:UseBundle(A.profileSelected,false))
local exported=P:Export();assert(not exported:find('Private build name',1,true) and not exported:find('Private profile name',1,true) and not exported:find('Private note',1,true))
assert(P:Save('With talents'));assert(A:NewDraft());A.bundleUndo={}
assert(P:Load('Before talents'));assert(not A.draft and not A.bundleUndo and not A:Selected())
assert(A:Library().builds['my:MAGE:Private build name'])
assert(P:Load('With talents'));assert(A:Selected().name=='Private build name' and not A.draft)

-- TEST: Talent Advisor rejects malformed profile positions weights and misleading metadata before any state changes
local FS,A,c=TalentFixture();A:Select(c.builds[1].id);assert(A:SaveBundle('Safe profile'))
local original=A:Library().profiles[A.profileSelected]
local function reject(change)
    local b=A.Copy(original);change(b)
    assert(not A:DecodeShare('FSTA1:'..FS.Extensions:Encode(b)))
end
reject(function(b) b.layout={Bad={x=99999,y=0,scale=1}} end)
reject(function(b) b.layout={Bad={x=0,y=0,scale=8}} end)
reject(function(b) b.gear.weights={NotAStat=1} end)
reject(function(b) b.plan.author='|Hbad' end)
reject(function(b) b.plan.priority={[2]='Intellect'} end)
reject(function(b) b.plan.optional={[999999]=true} end)
local G=FS.modules.GearAdvisor;local before=G:Data().preset
TEST.combat=true;assert(not A:UseBundle(A.profileSelected,true) and G:Data().preset==before);TEST.combat=false

-- TEST: Native trainer Forever boolean costs exclude new professions and pet training points
local FS,W,b=NativeTrainerFixture();local oldEnum,oldTrainer=Enum,C_Trainer
Enum={TrainerType={Pet=9,Class=1}};C_Trainer={GetTrainerType=function() return 1 end}
TEST.lessons[1].slots=1;FS.Training:Refresh();local entries,total=W:TrainingPlan(W:ReadTrainer())
assert(#entries==1 and entries[1].index==2 and total==150 and b:IsEnabled())
C_Trainer.GetTrainerType=function() return 9 end;FS.Training:Refresh()
entries,total=W:TrainingPlan(W:ReadTrainer());assert(#entries==0 and total==0 and not b:IsEnabled())
TEST.lessons[2].cost=0;entries,total=W:TrainingPlan(W:ReadTrainer());assert(#entries==1 and total==0)
Enum=oldEnum;C_Trainer=oldTrainer

-- TEST: Native trainer repeated events coalesce refreshes and reuse one themed button
local FS,W,b=NativeTrainerFixture();Drain();local U=FS.Training;local refresh=U.Refresh;local calls=0
U.Refresh=function(self,...) calls=calls+1;return refresh(self,...) end
for i=1,20 do U.events.scripts.OnEvent(U.events,'TRAINER_UPDATE') end
assert(calls==0);Drain();assert(calls==1 and ClassTrainerFrame.fsTrainAll==b);U.Refresh=refresh
ClassTrainerFrame:Hide();U:Refresh();assert(not b:IsShown())
ClassTrainerFrame:Show();U:Refresh();assert(b:IsShown() and ClassTrainerFrame.fsTrainAll==b)

-- TEST: Native Talents offers a themed advisor shortcut and decorates only talents in the selected plan
function NativeTalentFixture()
    if PlayerSpellsFrame and PlayerSpellsFrame.fsAdvisorFixture then ForeverSuite.WindowManager.native[PlayerSpellsFrame]=nil;PlayerSpellsFrame:Hide() end
    local FS,A,c=TalentFixture();A:Select(c.builds[1].id)
    local root=CreateFrame('Frame',nil,UIParent);root.fsAdvisorFixture=true;PlayerSpellsFrame=root
    local f=CreateFrame('Frame',nil,root);root.TalentsFrame=f;f.TabSystem=CreateFrame('Frame',nil,f);f.TabSystem:SetSize(340,36)
    f.nodeIDToButton={};f.GetConfigID=function() return 77 end;f.IsInspecting=function() return TEST.nativeInspect end
    f.GetTalentButtonByNodeID=function(self,id) return self.nodeIDToButton[id] end
    f.UpdateAllButtons=function() end;f.RefreshConfigID=function() end
    TEST.nativeClicks=0;TEST.nativeInspect=false
    for id in pairs(c.nodes) do
        local node=CreateFrame('Button',nil,f);node:SetSize(36,36);node:SetScript('OnClick',function() TEST.nativeClicks=TEST.nativeClicks+1 end);f.nodeIDToButton[id]=node
    end
    PlayerSpellsUtil={FrameTabs={ClassTalents=2}};root.TrySetTab=function() return true end
    FS.WindowManager.native[root]={name='PlayerSpellsFrame'}
    A:InstallNative();A:Event('NATIVE_TALENTS');Drain();return FS,A,c,root,f
end
local FS,A,c,root,f=NativeTalentFixture();local p=A:Selected();local ranks=A:Ranks(p.order)
FS.Context:Discover(); A:RefreshNative()
assert(f.fsAdvisorButton:IsShown() and f.fsAdvisorButton:GetText()=='Talent Advisor')
assert(f.fsAdvisorButton.point[1]=='LEFT' and f.fsAdvisorButton.point[2]==FS.Context.hosts[root].button and f.fsAdvisorButton.point[4]==8)
assert(f.fsAdvisorButton:GetParent()==root and f.fsAdvisorButton:IsMouseEnabled() and f.fsAdvisorButton.frameStrata=='DIALOG')
assert(f.fsAdvisorPlan:GetText():find(p.name,1,true))
for id,node in pairs(f.nodeIDToButton) do
    local h=A.nativeHints[node];assert((h and h:IsShown() or false)==(ranks[id]~=nil))
    if h and h:IsShown() then assert(h.rank:GetText()=='P'..ranks[id] and h.fsSuiteStyle and not h:IsMouseEnabled()) end
end
local nextID=A:NextPoint();assert(A.nativeHints[f.nodeIDToButton[nextID]].kind=='next')
local node=f.nodeIDToButton[nextID];local click=node:GetScript('OnClick');node:Click();assert(TEST.nativeClicks==1 and node:GetScript('OnClick')==click)
f.fsAdvisorButton:Click();assert(A.window:IsShown() and root:IsShown() and A.window.fsContextHost==f)
A:OpenGameTalents();f:Hide();f:Show();Drain();assert(root:IsShown() and f.fsAdvisorButton:IsShown())
f:Hide();assert(not f.fsAdvisorButton:IsShown() and not f.fsAdvisorPlan:IsShown())
f:Show();Drain();assert(f.fsAdvisorButton:IsShown())
f.TabSystem:SetFrameLevel(1010);f.SearchBox=CreateFrame('Frame',nil,f);f.SearchBox:SetFrameLevel(2000)
A:RefreshNative();assert(f.fsAdvisorButton:GetFrameLevel()>2000)

-- TEST: Native Talents follows committed points flexible choices staged changes and inactive or inspected trees
local FS,A,c,root,f=NativeTalentFixture();local p=A:Selected();local id=p.order[1];local ranks=A:Ranks(p.order)
TEST.talentRanks[id]=ranks[id];A:Event('TRAIT_CONFIG_UPDATED');Drain()
assert(A.nativeHints[f.nodeIDToButton[id]].kind=='matched')
local flexible;for nid in pairs(ranks) do if nid~=id and nid~=A:NextPoint() then flexible=nid;break end end
assert(A:EditTalent(flexible,false,true));A:Refresh();assert(A.nativeHints[f.nodeIDToButton[flexible]].kind=='flexible')
TEST.talentStaged=true;A:Event('TRAIT_NODE_CHANGED');Drain();assert(not A.currentReady)
for _,h in pairs(A.nativeHints) do if h:IsShown() then assert(h.kind~='next' and h.kind~='matched') end end
TEST.talentStaged=false;f.GetConfigID=function() return 88 end;A:Event('ACTIVE_TALENT_GROUP_CHANGED');Drain()
assert(f.fsAdvisorPlan:GetText():find('inactive',1,true));for _,h in pairs(A.nativeHints) do if h:IsShown() then assert(h.kind~='next') end end
TEST.nativeInspect=true;A:Event('NATIVE_TALENTS');Drain();for _,h in pairs(A.nativeHints) do assert(not h:IsShown()) end
TEST.nativeInspect=false;f.GetConfigID=function() return 77 end;TEST.changedMax=true;A:Event('TRAIT_CONFIG_UPDATED');Drain()
assert(f.fsAdvisorPlan:GetText():find('Update talent data',1,true));for _,h in pairs(A.nativeHints) do assert(not h:IsShown()) end

-- TEST: Native Talents integration coalesces events reuses hints and stops reads when hidden or disabled
local FS,A,c,root,f=NativeTalentFixture();local count=#TEST.frames
for i=1,20 do A:Refresh() end;assert(#TEST.frames==count)
local read=A.ReadCurrent;local calls=0;A.ReadCurrent=function(self,...) calls=calls+1;return read(self,...) end
for i=1,30 do f:UpdateAllButtons() end;assert(calls==0);Drain();assert(calls==1)
root:Hide();calls=0;for i=1,30 do A:Event('TRAIT_NODE_CHANGED') end;Drain();assert(calls==0)
root:Show();f:Hide();f:Show();Drain();assert(calls==1 and f.fsAdvisorButton:IsShown())
FS:SetModuleEnabled('TalentAdvisor',false);assert(not f.fsAdvisorButton:IsShown());for _,h in pairs(A.nativeHints) do assert(not h:IsShown()) end
calls=0;f:UpdateAllButtons();Drain();assert(calls==0)
FS:SetModuleEnabled('TalentAdvisor',true);A:Refresh();assert(f.fsAdvisorButton:IsShown() and not A.events:GetScript('OnUpdate'));A.ReadCurrent=read

-- TEST: Native Talents highlight preference and combat guard leave native input untouched
local FS,A,c,root,f=NativeTalentFixture();A:Data().nativeHighlights=false;A:SettingsChanged()
assert(f.fsAdvisorButton:IsShown());for _,h in pairs(A.nativeHints) do assert(not h:IsShown()) end
A:Data().nativeHighlights=true;A:SettingsChanged();A:Refresh();local id=A:NextPoint();assert(A.nativeHints[f.nodeIDToButton[id]]:IsShown())
TEST.combat=true;A:Event('PLAYER_REGEN_DISABLED');Drain();assert(not f.fsAdvisorButton:IsEnabled())
TEST.combat=false;A:Event('PLAYER_REGEN_ENABLED');Drain();assert(f.fsAdvisorButton:IsEnabled())

-- TEST: Talent and trainer fixtures restore client globals after the advisor checks
-- The game window uses its tab controller rather than showing a child panel over the spellbook.
local FS,A=TalentFixture();local oldFrame,oldUtil=PlayerSpellsFrame,PlayerSpellsUtil
PlayerSpellsFrame=CreateFrame('Frame',nil,UIParent);PlayerSpellsFrame:Hide();PlayerSpellsUtil={FrameTabs={ClassTalents=2}}
local chosen;PlayerSpellsFrame.TrySetTab=function(self,id) chosen=id;return true end
A:ShowWindow();A:OpenGameTalents();assert(chosen==2 and PlayerSpellsFrame:IsShown() and not A.window:IsShown())
PlayerSpellsFrame:Hide();PlayerSpellsFrame.TrySetTab=function() return false end
A:ShowWindow();A:OpenGameTalents();assert(A.window:IsShown() and not PlayerSpellsFrame:IsShown())
PlayerSpellsFrame=oldFrame;PlayerSpellsUtil=oldUtil
if PlayerSpellsFrame and PlayerSpellsFrame.fsAdvisorFixture then ForeverSuite.WindowManager.native[PlayerSpellsFrame]=nil;PlayerSpellsFrame:Hide() end
FS.modules.TalentAdvisor:HideNativeHints();FS.modules.TalentAdvisor.nativeFrame=nil
local FS=ForeverSuite;FS:CloseOtherWindows();if ClassTrainerFrame and ClassTrainerFrame.Hide then ClassTrainerFrame:Hide() end
for key,value in pairs(TEST.advisorOriginal) do if key~='hub' then _G[key]=value end end
-- pairs cannot restore globals whose original value was nil.
for _,key in ipairs({'C_Traits','C_SpecializationInfo','PlayerSpellsFrame','PlayerSpellsUtil','ClassTrainerFrame','GetNumTrainerServices','GetTrainerServiceInfo','GetTrainerServiceCost','GetTrainerServiceTypeFilter','BuyTrainerService','GetMoney'}) do _G[key]=TEST.advisorOriginal[key] end
ForeverSuiteHub=TEST.advisorOriginal.hub;FS.Hub:Initialize();FS.modules.TalentAdvisor.catalog=nil;FS.modules.TalentAdvisor.draft=nil
ResetTest()
