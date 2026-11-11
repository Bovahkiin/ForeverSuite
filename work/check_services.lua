-- TEST: Mail fixture models asynchronous receipts without sending deleting or paying COD
function MailFixture()
    ResetTest(); local M=ForeverSuite.modules.Mail; M:Stop(); M.atMailbox=true; M.selected=nil
    local rows={}; local actions={}; local pending=false
    GetInboxNumItems=function() return #rows,#rows end
    GetInboxHeaderInfo=function(i)
        local r=rows[i]; if not r then return end
        return nil,nil,r.sender or 'Sender',r.subject or 'Subject',r.money or 0,r.cod or 0,r.days or 20,#(r.items or {}),false,nil,nil,true,r.gm
    end
    GetInboxItemLink=function(i,s) return rows[i] and rows[i].items and rows[i].items[s] end
    GetInboxText=function(i) return 'Message '..i end
    C_Mail={IsCommandPending=function() return pending end}
    C_Container.CalculateTotalNumberOfFreeBagSlots=function() return TEST.mailFree or 10 end
    local function take(i,s)
        assert(not pending and M.atMailbox and not TEST.combat)
        local r=rows[i]; assert(r and not r.gm and (r.cod or 0)==0)
        actions[#actions+1]={row=r,slot=s}; pending=true
        After(.1,function()
            if s then table.remove(r.items,s) else r.money=0 end
            pending=false; M:Event('MAIL_INBOX_UPDATE')
        end)
    end
    TakeInboxMoney=function(i) take(i) end; TakeInboxItem=take
    SendMail=function() error('No mail may be sent') end; DeleteInboxItem=function() error('No mail may be deleted') end
    if M.window then M.window.search:SetText('') end
    return M,rows,actions
end
local M,rows,actions=MailFixture(); rows[1]={money=500,items={'item:1','item:2'}}
M:Collect(true); assert(#actions==1); Drain(); assert(#actions==3 and rows[1].money==0 and #rows[1].items==0 and not M.collecting)

-- TEST: Mail bulk collection skips COD and GM mail and honors money only settings
local M,rows,actions=MailFixture()
rows[1]={money=50,items={'item:1'},cod=100}; rows[2]={money=50,items={'item:2'},gm=true}; rows[3]={money=25,items={'item:3'}}
M:Data().collectItems=false; M:Collect(true); Drain()
assert(#actions==1 and rows[3].money==0 and #rows[3].items==1 and rows[1].money==50 and rows[2].money==50)

-- TEST: Mail collection search remains limited to matching senders and subjects
local M,rows,actions=MailFixture(); M:CreateWindow(); M.window.search:SetText('auction')
rows[1]={sender='Friend',money=50}; rows[2]={sender='Auction House',money=80}
M:Collect(true); Drain(); assert(#actions==1 and rows[1].money==50 and rows[2].money==0)

-- TEST: Selected mail rejects ambiguous or changed identity and tolerates shifted indexes
local M,rows,actions=MailFixture(); rows[1]={subject='First',money=10}; rows[2]={subject='Selected',money=20}
M.selected=M:Header(2); table.remove(rows,1); M:Collect(false); Drain(); assert(#actions==1 and actions[1].row==rows[1])
rows[1].money=10; rows[2]={subject='Selected',money=20}; M:Collect(false); assert(#actions==1 and not M.collecting)

-- TEST: Mail collection stops for full bags mailbox closure combat and stalled server responses
local M,rows,actions=MailFixture(); rows[1]={items={'item:1'}}; TEST.mailFree=0; M:Collect(true); assert(#actions==0 and not M.collecting); TEST.mailFree=nil
M:Collect(true); M:Event('MAIL_CLOSED'); Drain(); assert(#actions==1 and not M.collecting)
M.atMailbox=true; rows[1].items={'item:2'}; TEST.combat=true; M:Collect(true); assert(#actions==1); TEST.combat=false
TakeInboxItem=function() actions[#actions+1]={} end; M:Collect(true); Drain(); assert(#actions==2 and not M.collecting)

-- TEST: Mail stop and immediate restart do not let stale timers stall the new queue
local M,rows,actions=MailFixture(); rows[1]={money=10,items={'item:1','item:2'}}
M:Collect(true); M:Stop(); M:Collect(true); Drain(); assert(#actions==3 and not M.collecting and #rows[1].items==0)
M.atMailbox=false; GetInboxNumItems=nil; GetInboxHeaderInfo=nil; GetInboxItemLink=nil; GetInboxText=nil; C_Mail=nil

-- TEST: Minimap collection preserves original clicks tooltips and complete geometry on exclusion
ResetTest(); local FS=ForeverSuite; local M=FS.modules.MinimapButtons
local b=CreateFrame('Button','LibDBIcon10_ServiceTest',Minimap); b:SetSize(27,29); b:SetScale(.8); b:SetPoint('TOPLEFT',Minimap,'TOPLEFT',-5,6)
local clicks=0; local handler=function() clicks=clicks+1 end; b:SetScript('OnClick',handler); b:Show()
M:Scan(); assert(b:GetParent()==M.tray and b:GetScript('OnClick')==handler); b:Click(); assert(clicks==1)
M:Data().excluded[b:GetName()]=true; M:Scan(); assert(b:GetParent()==Minimap and b:GetWidth()==27 and b:GetHeight()==29 and b:GetScale()==.8 and b.point[4]==-5)
b:Hide()

-- TEST: Minimap collector ignores protected native hidden and already managed buttons
ResetTest(); local M=ForeverSuite.modules.MinimapButtons
local protected=CreateFrame('Button','LibDBIcon10_Protected',Minimap); protected.IsProtected=function() return true end
local native=CreateFrame('Button','MinimapZoomIn',Minimap)
local hidden=CreateFrame('Button','LibDBIcon10_Hidden',Minimap); hidden:Hide()
local managed=CreateFrame('Button','LibDBIcon10_Managed',CreateFrame('Frame'))
M:Scan(); assert(not M.collected[protected] and not M.collected[native] and not M.collected[hidden] and not M.collected[managed])
protected:Hide(); native:Hide(); managed:Hide()

-- TEST: Minimap collection defers combat geometry and restores collected icons when disabled
ResetTest(); local FS=ForeverSuite; local M=FS.modules.MinimapButtons
local b=CreateFrame('Button','LibDBIcon10_CombatTest',Minimap); b:SetSize(25,25); b:Show()
TEST.combat=true; M:Scan(); assert(b:GetParent()==Minimap and M.pending); TEST.combat=false
M:SettingsChanged(); assert(b:GetParent()==M.tray); FS:SetModuleEnabled('MinimapButtons',false); assert(b:GetParent()==Minimap and not M.button:IsShown())
b:Hide(); FS:SetModuleEnabled('MinimapButtons',true)

-- TEST: Every supported class has a beginner guide and a nonempty automatic stat scale
ResetTest(); local G=ForeverSuite.modules.GearAdvisor; local original=UnitClass
for class,guide in pairs(G.classGuides) do
    UnitClass=function() return class,class end; G:Data().preset='Auto'; G:Data().role='Class default'
    local weights,label=G:Weights(); assert(next(weights) and label:find(class,1,true) and #guide[2]>20)
    G:Data().view='Class guide'; G:Build(); assert(#G.rows==6 and G.rows[6].text:find('without editing',1,true))
end
UnitClass=original

-- TEST: Hybrid role choices change the automatic guide while Custom weights remain user owned
ResetTest(); local G=ForeverSuite.modules.GearAdvisor; local original=UnitClass; UnitClass=function() return 'Druid','DRUID' end
G:Data().role='Physical damage'; local weights=G:Weights(); assert(weights.Agility==2)
G:Data().role='Healer'; weights=G:Weights(); assert(weights.Healing==2)
G:Data().role='Tank'; weights=G:Weights(); assert(weights.Stamina==2)
assert(G:SetWeight('Agility','3.5')); G:Data().role='Spell damage'; weights=G:Weights(); assert(G:Data().preset=='Custom' and weights.Agility==3.5)
assert(not G:SetWeight('Agility','nan') and not G:SetWeight('Unknown','1')); UnitClass=original

-- TEST: Gear comparisons use the weaker ring and sum both hands for two handed candidates
function AdvisorFixture()
    ResetTest(); local G=ForeverSuite.modules.GearAdvisor; local data={}; local equipped={}
    UnitLevel=function() return 60 end
    C_Item.GetItemInfo=function(link) local d=data[link]; if d then return link,link,2,10,d.required or 1,'Armor','Type',1,d.loc,1,1,4,1 end end
    C_Item.GetItemStats=function(link) return data[link] and data[link].stats end
    GetInventoryItemLink=function(_,slot) return equipped[slot] end
    C_Item.GetItemUniquenessByID=function() return false end
    G:Data().preset='Custom'; G:Data().weights={Agility=1}; return G,data,equipped
end
local G,data,equipped=AdvisorFixture()
data['item:1']={loc='INVTYPE_FINGER',stats={ITEM_MOD_AGILITY_SHORT=10}}; data['item:2']={loc='INVTYPE_FINGER',stats={ITEM_MOD_AGILITY_SHORT=5}}; data['item:3']={loc='INVTYPE_FINGER',stats={ITEM_MOD_AGILITY_SHORT=8}}
equipped[11]='item:1'; equipped[12]='item:2'; local row=G:Compare('item:3'); assert(row.slot==12 and row.base==5 and row.percent==60 and row.upgrade)
data['item:4']={loc='INVTYPE_2HWEAPON',stats={ITEM_MOD_AGILITY_SHORT=20}}; equipped[16]='item:1'; equipped[17]='item:2'; row=G:Compare('item:4'); assert(row.base==15 and row.delta==5)

-- TEST: Unknown equipped stats restricted values required levels and weapon setup changes never claim upgrades
local G,data,equipped=AdvisorFixture()
data['item:1']={loc='INVTYPE_HEAD',stats={ITEM_MOD_AGILITY_SHORT=10}}; data['item:2']={loc='INVTYPE_HEAD'}; equipped[1]='item:2'; assert(not G:Compare('item:1'))
equipped[1]=nil; data['item:1'].required=1000; assert(not G:Compare('item:1')); data['item:1'].required=1
local secret={}; local previous=issecretvalue; issecretvalue=function(v) return v==secret end; data['item:1'].stats.ITEM_MOD_AGILITY_SHORT=secret; assert(not G:Score('item:1')); issecretvalue=previous
data['item:1']={loc='INVTYPE_WEAPON',stats={ITEM_MOD_AGILITY_SHORT=20}}; data['item:2']={loc='INVTYPE_2HWEAPON',stats={ITEM_MOD_AGILITY_SHORT=5}}; equipped[16]='item:2'; assert(not G:Compare('item:1'))

-- TEST: Stat scale import validates complete input without executing text or mutating on preview
ResetTest(); local G=ForeverSuite.modules.GearAdvisor; local before=G:Data().preset
local weights=G:ParseWeights('Agility=2, Stamina=0.2\nArmor=0.05'); assert(weights.Agility==2 and G:Data().preset==before)
for _,text in ipairs({'Agility=2; print(1)','Agility=2,Agility=3','Agility=nan','Unknown=1','Agility=1001','Agility=2 garbage'}) do assert(not G:ParseWeights(text)) end
assert(G:ImportWeights('Agility=3, Stamina=1')); assert(G:Data().weights.Agility==3 and G:Data().preset=='Custom')
TEST.combat=true; assert(not G:ImportWeights('Agility=1')); TEST.combat=false

-- TEST: New module settings and class guides fit large type and profile snapshots preserve choices
ResetTest(); local FS=ForeverSuite; FS:ShowConfig()
for _,name in ipairs({'Mail','MinimapButtons','GearAdvisor'}) do
    FS:ConfigureModule(name); local M=FS.modules[name]; assert(M.settings:IsShown()); M:ShowWindow(); assert(M.window:IsShown())
    FS.db.typography.global.size=24; FS.Typography:Apply(); M.window:LayoutText()
    for _,button in ipairs(M.window.actionButtons) do assert(-button.point[3]+button:GetHeight()<=M.window:GetHeight()) end
end
local P=FS.modules.Profiles; FS.db.mail.collectItems=false; FS.db.minimapButtons.columns=4; FS.db.gearAdvisor.role='Healer'; P:PersistCurrent()
local saved=FS.db.profiles.saved[FS.db.profiles.current]; assert(not saved.mail.collectItems and saved.minimapButtons.columns==4 and saved.gearAdvisor.role=='Healer')

-- TEST: Letter and class guide dialogs return to the originating module without opening More tools
local M,rows,actions=MailFixture(); rows[1]={subject='Read me'}; M.selected=M:Header(1); M:OnSelect()
local dialog=ForeverSuite.Extensions.dialog; assert(dialog:IsShown() and dialog.edit:GetText()=='Message 1'); dialog.cancel:Click(); assert(M.window:IsShown())
local G=ForeverSuite.modules.GearAdvisor; G:Data().view='Class guide'; G:Build(); G:OnSelect(G.rows[1]); assert(dialog:IsShown()); dialog.cancel:Click(); assert(G.window:IsShown())
M:Event('MAIL_CLOSED')

-- TEST: Gear tooltip scores are deduplicated clear on reuse and disappear when advice is disabled
local G,data,equipped=AdvisorFixture(); data['item:90']={loc='INVTYPE_HEAD',stats={ITEM_MOD_AGILITY_SHORT=20}}
local oldProcessor,oldEnum,oldGet=TooltipDataProcessor,Enum,GameTooltip.GetItem; local callback
TooltipDataProcessor={AddTooltipPostCall=function(kind,fn) assert(kind==1); callback=fn end}; Enum={TooltipDataType={Item=1}}
G.tooltipInstalled=nil; G:InstallTooltip(); assert(callback)
GameTooltip.GetItem=function() return 'Candidate','item:90' end; GameTooltip.lines={}; callback(GameTooltip); assert(#GameTooltip.lines==3)
callback(GameTooltip); assert(#GameTooltip.lines==3)
GameTooltip.scripts.OnTooltipCleared(GameTooltip); GameTooltip.lines={}; callback(GameTooltip); assert(#GameTooltip.lines==3)
G:Data().tooltips=false; GameTooltip.scripts.OnTooltipCleared(GameTooltip); GameTooltip.lines={}; callback(GameTooltip); assert(#GameTooltip.lines==0)
TooltipDataProcessor,Enum,GameTooltip.GetItem=oldProcessor,oldEnum,oldGet

-- TEST: Collector finds nested addon launchers and registered library buttons without stealing map pins
ResetTest(); local M=ForeverSuite.modules.MinimapButtons; local oldLib=LibStub
local wrapper=CreateFrame('Frame',nil,Minimap)
local nested=CreateFrame('Button','NestedAddonMinimapButton',wrapper); nested:SetSize(28,28); nested:Show()
local broker=CreateFrame('Button','UnusualBrokerLauncher',UIParent); broker:SetSize(28,28); broker:Show()
local pin=CreateFrame('Button','QuestMinimapIconPin',wrapper); pin.uiMapID=1; pin:SetSize(28,28); pin:Show()
local library={GetButtonList=function() return {'Broker'} end,GetMinimapButton=function() return broker end}
LibStub=function() return library end
M:Scan(); assert(M.collected[nested] and M.collected[broker] and not M.collected[pin])
M:Restore(nested); M:Restore(broker); assert(nested:GetParent()==wrapper and broker:GetParent()==UIParent)
nested:Hide(); broker:Hide(); pin:Hide(); LibStub=oldLib

-- TEST: Tray is anchored to the collector button and flips above or below near screen edges
ResetTest(); local M=ForeverSuite.modules.MinimapButtons; M:CreateTray(); local b=M.button; local original=b.GetCenter
b.GetCenter=function() return UIParent:GetWidth()-20,UIParent:GetHeight()-20 end; M:AnchorTray()
assert(M.tray.point[1]=='TOPRIGHT' and M.tray.point[2]==b and M.tray.point[3]=='BOTTOMRIGHT')
b.GetCenter=function() return 20,20 end; M:AnchorTray()
assert(M.tray.point[1]=='BOTTOMLEFT' and M.tray.point[2]==b and M.tray.point[3]=='TOPLEFT')
assert(b:GetParent()==UIParent); b.GetCenter=original

-- TEST: Direct collector dragging saves a persistent position without self anchoring or reopening the tray
ResetTest(); local FS=ForeverSuite; local M=FS.modules.MinimapButtons; local b=M.button
local originalCenter,originalPoint=b.GetCenter,b.SetPoint
b.GetCenter=function() return 700,500 end
b.SetPoint=function(self,point,relative,...) assert(relative~=self,'A dragged frame must not anchor to itself'); return originalPoint(self,point,relative,...) end
b.scripts.OnDragStart(b); assert(b.fsDirectDragging and M.dragging)
FS.Layout:Apply('AddonButtons'); b.scripts.OnDragStop(b)
assert(not b.fsDirectDragging and not M.dragging and FS.db.layout.frames.AddonButtons and M.suppressClick)
local position=FS.db.layout.frames.AddonButtons; assert(position.y==500)
b.scripts.OnClick(b); assert(M.suppressClick); Drain(); FS.Layout:Apply('AddonButtons'); assert(FS.db.layout.frames.AddonButtons.y==500)
b.GetCenter=originalCenter; b.SetPoint=originalPoint

-- TEST: A competing collector prompts before changing addon state and switches only after explicit choice
ResetTest(); local FS=ForeverSuite; local M=FS.modules.MinimapButtons; local oldAddons,oldReload=C_AddOns,ReloadUI
local enabled=true; local reloads=0; local disabled={}
C_AddOns={IsAddOnLoaded=function(name) return name=='MinimapButtonButton' end,
    DisableAddOn=function(name,character) disabled[#disabled+1]=name; enabled=false end,
    GetAddOnEnableState=function() return enabled and 2 or 0 end}
ReloadUI=function() reloads=reloads+1 end
M:Scan(); M:ToggleTray(); assert(M.conflict:IsShown() and #disabled==0 and reloads==0 and not M.tray:IsShown())
TEST.combat=true; assert(not M:ChooseCollector(true) and #disabled==0); TEST.combat=false
assert(M:ChooseCollector(true)); assert(#disabled==1 and disabled[1]=='MinimapButtonButton' and reloads==1)
C_AddOns,ReloadUI=oldAddons,oldReload

-- TEST: A failed collector switch never reloads or disables unrelated addons
ResetTest(); local M=ForeverSuite.modules.MinimapButtons; local oldAddons,oldReload=C_AddOns,ReloadUI
C_AddOns={IsAddOnLoaded=function(name) return name=='MinimapButtonButton' end,DisableAddOn=function() error('Denied') end}
local reloads=0; ReloadUI=function() reloads=reloads+1 end
assert(not M:ChooseCollector(true) and reloads==0)
C_AddOns,ReloadUI=oldAddons,oldReload

-- TEST: Gear advice has green up gray equal and red down indicators with floating point tolerance
ResetTest(); local G=ForeverSuite.modules.GearAdvisor
local icon,label,r,g,b=G:Indicator({delta=2,score=12,base=10}); assert(icon:find('Gear-Up',1,true) and label=='Upgrade' and g>r)
icon,label,r,g,b=G:Indicator({delta=0,score=10,base=10}); assert(icon:find('|cff999999-',1,true) and label=='Equal' and r==g and g==b)
icon,label,r,g,b=G:Indicator({delta=-2,score=8,base=10}); assert(icon:find('Gear-Down',1,true) and label=='Downgrade' and r>g)
icon,label=G:Indicator({delta=1e-10,score=10,base=10}); assert(label=='Equal')

-- TEST: Equal equipped links and lower scoring candidates get matching tooltip indicators
local G,data,equipped=AdvisorFixture(); data['item:1']={loc='INVTYPE_HEAD',stats={ITEM_MOD_AGILITY_SHORT=10}}; data['item:2']={loc='INVTYPE_HEAD',stats={ITEM_MOD_AGILITY_SHORT=5}}; equipped[1]='item:1'
local row=G:Compare('item:1'); assert(row and row.delta==0 and select(2,G:Indicator(row))=='Equal')
local previous=GameTooltip.GetItem; GameTooltip.GetItem=function() return 'Item','item:2' end
G:Data().tooltips=true; GameTooltip.fsAdvisorLink=nil; GameTooltip.lines={}; G:Tooltip(GameTooltip)
assert(GameTooltip.lines[2]:find('Gear-Down',1,true) and GameTooltip.lines[2]:find('Downgrade',1,true))
GameTooltip.GetItem=previous

-- TEST: Active pet character tab shows the pet model and hides player equipment controls
function CharacterPetFixture()
    ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character
    CharacterFrame=CharacterFrame or CreateFrame('Frame','CharacterFrame',UIParent)
    for _,p in ipairs(C.pages) do _G[p.frame]=_G[p.frame] or CreateFrame('Frame',p.frame,CharacterFrame) end
    CharacterFrame:Show(); CharacterFrame.activeSubframe='PaperDollFrame'; C.sideMode=1; C.modelUnit=nil
    TEST.units.pet={name='Crab',health=120,maxHealth=150,power=60,maxPower=100}; TEST.petXP=40; TEST.petNeeded=100; TEST.petMood=3
    UnitExists=function(unit) return TEST.units[unit]~=nil end
    UnitName=function(unit) return TEST.units[unit] and TEST.units[unit].name or 'Player' end
    HasPetUI=function() return UnitExists('pet'),true end
    UnitLevel=function(unit) return unit=='pet' and 12 or 60 end
    UnitCreatureFamily=function() return 'Crab' end; UnitArmor=function() return 50,70 end
    UnitDamage=function() return 10,15 end; UnitAttackSpeed=function() return 2 end
    GetPetExperience=function() return TEST.petXP,TEST.petNeeded end
    C_PetInfo={GetPetHappiness=function() return TEST.petMood,125 end,GetPetLoyalty=function() return 'Best Friend' end,
        GetPetTrainingPoints=function() return 20,6 end,GetPetFoodTypes=function() return {'Fish','Bread'} end}
    C:Apply(); C.model.SetFacing=function(frame,value) frame.facing=value end
    return C
end
local C=CharacterPetFixture(); assert(C.sideTabs[4]:IsShown()); C.sideTabs[4]:Click()
assert(C.sideMode==4 and C.model.unit=='pet' and C.petXP:IsShown() and C.petXP.value==40 and C.petXP.maximum==100)
for _,slot in pairs(C.slots) do assert(not slot:IsShown() and slot:GetAttribute('type2')=='item') end
local rows=C:PetStats(); local joined=''; for _,r in ipairs(rows) do joined=joined..r.text..'\n' end
assert(joined:find('Best Friend',1,true) and joined:find('14',1,true) and joined:find('Fish, Bread',1,true))

-- TEST: Returning from pet view restores the player model equipment and independent rotation
local C=CharacterPetFixture(); C.sideTabs[1]:Click(); C:RotateModel(.35); local playerFacing=C.model.facing
C.sideTabs[4]:Click(); C:RotateModel(-.7); assert(C.model.facing==-.7)
C.sideTabs[1]:Click(); assert(C.model.unit=='player' and C.model.facing==playerFacing and not C.petXP:IsShown() and not C.petMood:IsShown())
for _,slot in pairs(C.slots) do assert(slot:IsShown()) end

-- TEST: Pet experience and happiness events update the open character panel without recreating the model
local C=CharacterPetFixture(); C.sideTabs[4]:Click(); TEST.petXP=75; TEST.petMood=1
local original=C.model.SetUnit; local changes=0; C.model.SetUnit=function(...) changes=changes+1; return original(...) end
C.events.scripts.OnEvent(C.events,'UNIT_PET_EXPERIENCE','pet'); assert(C.petXP.value==75 and C.petMood.icon.atlas=='UI-PetMad' and changes==0)
C.model.SetUnit=original

-- TEST: Dismissing a pet during combat avoids secure visibility writes and restores the player after combat
local C=CharacterPetFixture(); C.sideTabs[4]:Click(); TEST.combat=true; TEST.units.pet=nil
local originals={}; for _,slot in pairs(C.slots) do originals[slot]=slot.SetShown; slot.SetShown=function() error('Secure visibility write in combat') end end
C.events.scripts.OnEvent(C.events,'UNIT_PET','player'); assert(C.sideMode==4 and not C.petXP:IsShown() and not C.petMood:IsShown())
for slot,fn in pairs(originals) do slot.SetShown=fn end
TEST.combat=false; C.events.scripts.OnEvent(C.events,'PLAYER_REGEN_ENABLED'); assert(C.sideMode==1 and C.model.unit=='player' and not C.sideTabs[4]:IsShown())

-- TEST: Unavailable restricted or non hunter pet data never fabricates experience or happiness
local C=CharacterPetFixture(); C.sideTabs[4]:Click(); TEST.petXP=nil; TEST.petNeeded=nil; TEST.petMood=nil; C:RefreshCharacter()
assert(not C.petXP:IsShown() and not C.petMood:IsShown())
HasPetUI=function() return true,false end; TEST.petMood=3; C:RefreshCharacter(); assert(not C.petMood:IsShown())
local secret={}; local old=issecretvalue; issecretvalue=function(v) return v==secret end; TEST.petXP=secret; TEST.petNeeded=100; C:RefreshCharacter(); assert(not C.petXP:IsShown()); issecretvalue=old

-- TEST: Four character subtabs and pet rows fit large fonts and full row tooltips remain readable
local C=CharacterPetFixture(); local FS=ForeverSuite; C.sideTabs[4]:Click(); FS.db.typography.modules.Character={size=24,scale=1}; FS.Typography:Apply(); C:RefreshCharacter()
for _,tab in ipairs(C.sideTabs) do assert(tab:IsShown() and tab.fsLabel:GetHeight()+28<=tab:GetHeight()) end
for _,row in ipairs(C.rows) do if row:IsShown() then assert(-row.point[3]+row:GetHeight()<352) end end
assert(C.next:IsEnabled()); C.rows[1].scripts.OnEnter(C.rows[1]); assert(#GameTooltip.lines>0)
TEST.units.pet=nil; HasPetUI=nil; C_PetInfo=nil; GetPetExperience=nil; UnitCreatureFamily=nil; UnitDamage=nil; UnitAttackSpeed=nil; UnitArmor=nil
FS.db.typography.modules.Character=nil; FS.Typography:Apply(); C:RefreshCharacter(); assert(not C.sideTabs[4]:IsShown())

-- TEST: Clean first login waits for startup handlers and opens Welcome before patch notes
function StartupFixture()
    ResetTest(); local FS=ForeverSuite; FS.Installer:Create(); FS:CreateAboutWindow()
    for _,f in ipairs({FS.Installer.window,FS.aboutWindow,FS.window,FS.Typography.window}) do if f then f:Hide() end end
    FS.installerReturn=false; FS.startupHandled=nil; FS.startupPending=nil; FS.startupQueued=nil
    return FS,FS.Installer
end
local FS,I=StartupFixture(); ForeverSuiteDB=nil; FS:InitializeDatabase()
FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); FS.events.scripts.OnEvent(FS.events,'PLAYER_ENTERING_WORLD')
assert(FS.startupQueued and not I.window:IsShown()); Drain()
assert(I.window:IsShown() and I.step==1 and not FS.aboutWindow:IsShown() and not FS.db.setup.completed)
assert(I.window.description:GetText():find(FS.version,1,true) and I.window.patch:IsShown())
assert(FS.startupHandled and not FS.startupPending)

-- TEST: Partial settings never imply completed setup and existing appearance and layouts survive
local FS,I=StartupFixture(); ForeverSuiteDB={typography={global={size=18}},layout={frames={Clock={x=11,y=22,scale=1}}}}
FS:InitializeDatabase(); assert(I:NeedsSetup() and FS.db.typography.global.size==18 and FS.db.layout.frames.Clock.x==11)
FS.events.scripts.OnEvent(FS.events,'PLAYER_ENTERING_WORLD'); Drain()
assert(I.window:IsShown() and not FS.db.setup.completed and FS.db.layout.frames.Clock.y==22)

-- TEST: World entry recovers a missed login and later world entries preserve the active setup step
local FS,I=StartupFixture(); FS.events.scripts.OnEvent(FS.events,'PLAYER_ENTERING_WORLD'); Drain()
assert(I.window:IsShown()); I.window.next:Click(); I.draft.theme='Royal Aether'
FS.events.scripts.OnEvent(FS.events,'PLAYER_ENTERING_WORLD'); FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); Drain()
assert(I.step==5 and I.draft.theme=='Royal Aether')

-- TEST: Startup in combat remains pending and opens welcome automatically after combat
local FS,I=StartupFixture(); TEST.combat=true
FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); Drain()
assert(FS.startupPending and not FS.startupHandled and not I.window:IsShown())
TEST.combat=false; FS.events.scripts.OnEvent(FS.events,'PLAYER_REGEN_ENABLED'); Drain()
assert(FS.startupHandled and I.window:IsShown() and I.step==1)

-- TEST: Loading the addon after login still schedules first run onboarding
local FS,I=StartupFixture(); local old=IsLoggedIn; IsLoggedIn=function() return true end
FS.events.scripts.OnEvent(FS.events,'ADDON_LOADED','ForeverSuite'); IsLoggedIn=old
assert(FS.startupQueued); Drain(); assert(I.window:IsShown() and I.step==1)

-- TEST: Explicitly dismissed setup remains dismissed and can be reopened without resetting settings
local FS,I=StartupFixture(); FS.db.setup.dismissed=true; FS.db.patchLog.showOnLoad=false; FS.db.actionBars.style='Floating'
FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); Drain()
assert(FS.startupHandled and not I.window:IsShown() and not FS.aboutWindow:IsShown())
assert(I:Show() and I.step==1 and I.draft.style=='Floating' and not FS.db.setup.completed)
I.window:Hide()

-- TEST: Completed setup shows preferred patch notes once without repeating them on zone changes
local FS,I=StartupFixture(); FS.db.setup.completed=true; FS.db.patchLog.showOnLoad=true
FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); Drain()
assert(FS.aboutWindow:IsShown() and not I.window:IsShown()); FS.aboutWindow:Hide()
FS.events.scripts.OnEvent(FS.events,'PLAYER_ENTERING_WORLD'); Drain()
assert(not FS.aboutWindow:IsShown() and FS.db.setup.completed)

-- TEST: A pending automatic welcome preserves a manually opened draft and patch log return
local FS,I=StartupFixture(); FS:QueueStartup(); assert(I:Show()); I.step=2; I.draft.theme='Verdant Relic'; I:Refresh(); Drain()
assert(I.step==2 and I.draft.theme=='Verdant Relic' and FS.startupHandled)
FS.startupHandled=nil; FS:QueueStartup(); I.step=1; I:Refresh(); I.window.patch:Click(); Drain()
assert(FS.aboutWindow:IsShown() and FS.installerReturn and not I.window:IsShown())
FS.aboutWindow.close:Click(); assert(I.window:IsShown() and I.step==1 and I.draft.theme=='Verdant Relic')
I.window:Hide()

-- TEST: Move Frames Save persists current profile and establishes a new cancel checkpoint
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; L:Stop(); local frame=CreateFrame('Frame',nil,UIParent)
frame:SetSize(120,40); frame:SetPoint('CENTER',UIParent,'CENTER',0,0); L:Register('SavePreview',frame,'Save preview')
L:Start(); FS.db.layout.frames.SavePreview={x=72,y=320,scale=1.1}; L:Apply('SavePreview'); L.overlay.save:Click()
assert(L.active and L.overlay:IsShown() and FS.db.profiles.saved[FS.db.profiles.current].layout.frames.SavePreview.x==72)
FS.db.layout.frames.SavePreview={x=100,y=400,scale=1.3}; L:Apply('SavePreview'); L.overlay.close:Click()
assert(not L.active and FS.db.layout.frames.SavePreview.x==72 and frame:GetScale()==1.1)
FS:InitializeDatabase(); assert(FS.db.layout.frames.SavePreview.y==320 and FS.db.layout.frames.SavePreview.scale==1.1)
L.targets.SavePreview=nil; L.handles.SavePreview=nil; FS.db.layout.frames.SavePreview=nil; frame:Hide()

-- TEST: Save and close persists layout while combat and vendor guards leave the editing state unchanged
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; L:Stop(); L:Start()
FS.db.layout.frames.Clock={x=18,y=280,scale=1.2}; TEST.combat=true
assert(not L:SaveChanges(false) and L.active); TEST.combat=false; FS.modules.Vendor.busy=true
assert(not L:SaveChanges(true) and L.active); FS.modules.Vendor.busy=false
L.overlay.done:Click(); assert(not L.active and FS.window:IsShown() and FS.db.profiles.saved[FS.db.profiles.current].layout.frames.Clock.x==18)

-- TEST: Disable all modules includes every page preserves custom settings and has a single undo action
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; local E=FS.Extensions; E.undo={}
FS.db.map.enabled=false; FS.db.chat.historyLines=1024; local before={}; for _,name in ipairs(f.moduleOrder) do before[name]=FS:IsModuleEnabled(name) end
local profile=FS.db.profiles.current; f.disableAll:Click()
for _,name in ipairs(f.moduleOrder) do assert(not FS:IsModuleEnabled(name),name) end
assert(FS.db.chat.historyLines==1024 and FS.db.profiles.current==profile and #E.undo==1 and FS.window:IsShown())
f.undo:Click(); for name,value in pairs(before) do assert(FS:IsModuleEnabled(name)==value,name) end
assert(FS.db.chat.historyLines==1024)

-- TEST: Disable all modules blocks combat and active vendor actions before changing any module
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local before={}; for _,name in ipairs(FS.window.moduleOrder) do before[name]=FS:IsModuleEnabled(name) end
TEST.combat=true; assert(not FS:DisableAllModules()); TEST.combat=false; FS.modules.Vendor.busy=true
assert(not FS:DisableAllModules()); FS.modules.Vendor.busy=false
for name,value in pairs(before) do assert(FS:IsModuleEnabled(name)==value,name) end

-- TEST: Save toolbar and bulk module control remain inside their panels with large fonts and small viewports
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; FS:ShowConfig(); FS.db.typography.global.size=24; FS.Typography:Apply(); L:Start()
for _,b in ipairs({L.overlay.save,L.overlay.done,L.overlay.snap,L.overlay.reset,L.overlay.close}) do
    assert(-b.point[3]+b:GetHeight()+10<=L.overlay.toolbar:GetHeight())
    assert(b.fsLabel:GetHeight()+10<=b:GetHeight())
end
local f=FS.window; assert(-f.disableAll.point[3]+f.disableAll:GetHeight()+10<f.bodyContent:GetHeight())
local width=UIParent:GetWidth(); UIParent:SetWidth(640); L:UpdateToolbar(); assert(L.overlay.toolbar:GetWidth()*L.overlay.toolbar:GetScale()<=616)
UIParent:SetWidth(width); FS.db.typography.global.size=0; FS.Typography:Apply(); L:Stop()

-- TEST: Every module toggle updates both the button and visible caption across all dashboard pages
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; FS:ClearModuleFilter()
for _,name in ipairs(f.moduleOrder) do
    FS:SetModuleEnabled(name,true); f.cardPage=f.cards[name].page; FS:RefreshConfig(); local b=f.cards[name].toggle
    b:Click(); assert(not FS:IsModuleEnabled(name) and b:GetText()=='Disabled' and b.fsLabel:GetText()=='Disabled',name)
    b:Click(); assert(FS:IsModuleEnabled(name) and b:GetText()=='Enabled' and b.fsLabel:GetText()=='Enabled',name)
end

-- TEST: Visible module captions recover native text caching failed module refresh and external state changes
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; local b=f.cards.Chat.toggle; local setter=b.SetText
b.SetText=function(frame,text) frame.text=text end; FS:SetModuleEnabled('Chat',false)
assert(b.fsLabel:GetText()=='Disabled'); b.SetText=setter; FS:SetModuleEnabled('Chat',true)
local C=FS.modules.Chat; local refresh=C.SettingsChanged; C.SettingsChanged=function() error('simulated module refresh failure') end
local ok=pcall(FS.SetModuleEnabled,FS,'Chat',false); assert(not ok and b.fsLabel:GetText()=='Disabled' and not FS:IsModuleEnabled('Chat'))
C.SettingsChanged=refresh; FS:SetModuleEnabled('Chat',true)
FS.db.loot.enabled=false; f.scripts.OnUpdate(f,.25); assert(f.cards.Loot.toggle.fsLabel:GetText()=='Disabled')
FS:SetModuleEnabled('Loot',true)

-- TEST: Welcome and text size previews stay populated with every live module disabled
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:DisableAllModules(); local I=FS.Installer
I:Show(); local f=I.window
for _,step in ipairs({1,3}) do
    I.step=step; I:Refresh()
    for _,id in ipairs({'Unit:player','Unit:target','Unit:pet','QuestTracker','ChatFrame1','MainActionBar','Waypoint'}) do assert(f.layoutPreview.parts[id].frame:IsShown()) end
end
local bar=f.layoutPreview.parts.MainActionBar.frame; local height=bar:GetHeight()
f.choices[3]:Click(); assert(math.abs(bar:GetHeight()-height*1.2)<.01)
f.choices[4]:Click(); assert(f.layoutPreview.parts['Unit:player'].frame.label.font[2]==13 and FS.db.typography.global.size==0)
for _,name in ipairs(FS.window.moduleOrder) do assert(not FS:IsModuleEnabled(name),name) end
f:Hide()

-- TEST: Module selection previews honor staged choices and explain the all off state without mutating live modules
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:DisableAllModules(); local I=FS.Installer; I:Show(); I.step=4; I:Refresh(); local f=I.window
assert(f.preview.empty:IsShown() and not f.preview.player:IsShown() and not f.preview.tiles[1]:IsShown())
f.choices[2]:Click(); assert(I.draft.modules.UnitFrames and f.preview.player:IsShown() and not f.preview.empty:IsShown())
assert(not f.preview.quest:IsShown() and not FS:IsModuleEnabled('UnitFrames'))
I.step=3; I:Refresh(); assert(f.layoutPreview:IsShown() and not I.draft.modules.Quests)
f.previous:Click(); assert(I.step==2 and f.layoutPreview:IsShown())
f:Hide()

-- TEST: All ten style images and preset previews remain available while live modules stay off
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:DisableAllModules(); local I=FS.Installer; I:Show(); local f=I.window
I.step=2; I:Refresh()
for i,name in ipairs(FS.Themes.names) do
    f.choices[i]:Click(); assert(f.layoutPreview:IsShown() and FS.Themes.frames[f.layoutPreview].parts[1].texture==FS.Themes:Asset(i,'Panel'))
    f.next:Click(); assert(I.step==3 and f.layoutPreview.parts['Unit:player'].frame:IsShown() and f.layoutPreview.parts.MainActionBar.frame:IsShown())
    f.choices[5]:Click(); assert(f.layoutPreview.parts['Unit:player'].frame.label.font[2]==9 and not FS.db.setup.completed)
    f.previous:Click()
end
for _,name in ipairs(FS.window.moduleOrder) do assert(not FS:IsModuleEnabled(name),name) end
f:Hide()

-- TEST: Fresh installs recommend Layout 1 while existing mover placements default to Keep current
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show(); assert(I.draft.layout=='Layout 1')
FS.db.layout.frames.Clock={x=10,y=300,scale=1}; I:Show(); assert(I.draft.layout=='Keep current')
I.window:Hide()

-- TEST: Layout choices and neutral schematic preview never write live positions before finish
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show(); I.window.next:Click()
assert(I.step==5 and I.window.next:GetText()=='Next' and I.window.layoutPreview:IsShown())
for i,name in ipairs(FS.LayoutPresets.names) do
    I.window.choices[i]:Click(); assert(I.draft.layout==name and next(FS.db.layout.frames)==nil)
    local preview=I.window.layoutPreview; assert(not preview.notice:IsShown())
    if name~='Keep current' then assert(preview.parts['Unit:player'].frame:IsShown() and preview.parts['Unit:target'].frame:IsShown()) end
end
I:Dismiss(); assert(next(FS.db.layout.frames)==nil)

-- TEST: Layout 1 follows the reference and every preset fits supported viewport scales without stacked game bars
ResetTest(); local FS=ForeverSuite; local P=FS.LayoutPresets
local reference=P:Plan('Layout 1',2133.3333,1200)
assert(math.abs(reference.frames['Unit:player'].x+349.86)<1 and math.abs(reference.frames['Unit:target'].y-428.4)<1)
assert(reference.frames['Unit:pet'].y<reference.frames['Unit:player'].y and reference.native.ChatFrame1.x<0)
for _,size in ipairs({{1280,720},{1920,1080},{3440,1440},{640,360}}) do
    for _,name in ipairs({'Layout 1','Compact','Classic'}) do
        local plan=P:Plan(name,size[1],size[2]); assert(plan)
        for _,p in pairs(plan.frames) do assert(p.scale>=.6 and p.scale<=1.4 and p.y>0 and p.y<size[2]) end
        assert(plan.native.MainActionBar.y-plan.native.MultiBarBottomLeft.y>=43.999)
        assert(plan.native.MultiBarBottomLeft.y-plan.native.MultiBarBottomRight.y>=43.999)
    end
end
assert(not P:Plan('invalid',1920,1080) and not P:Plan('Layout 1',0,0))

-- TEST: Game layout creation uses copied public data and never writes native frame anchors or runtime flags
function NativeLayoutFixture()
    local FS=ForeverSuite; local old={api=C_EditMode,presets=EditModePresetLayoutManager,enum=Enum,constants=Constants,frames={}}
    Enum=Enum or {}; old.types=Enum.EditModeLayoutType; Enum.EditModeLayoutType={Preset=0,Account=1,Character=2}
    Constants=Constants or {}; old.limits=Constants.EditModeConsts; Constants.EditModeConsts={EditModeMaxLayoutsPerType=5}
    local systems={}; local names={'MainActionBar','MultiBarBottomLeft','MultiBarBottomRight','PetActionBar','ChatFrame1'}
    for i,name in ipairs(names) do
        old.frames[name]=_G[name] or false; local f=CreateFrame('Frame',nil,UIParent); _G[name]=f
        f.system=0; f.systemIndex=i; f.systemInfo={untouched=true}; f.SetPoint=function() error('Native anchor write') end
        systems[#systems+1]={system=0,systemIndex=i,settings={{setting=1,value=100}},isInDefaultPosition=true,anchorInfo={point='CENTER',relativeTo='UIParent',relativePoint='CENTER',offsetX=0,offsetY=0}}
    end
    local preset={layoutName='Modern',layoutType=0,systems=systems}; local custom={layoutName='Personal',layoutType=2,systems={}}
    local data={activeLayout=2,layouts={custom}}; local state={saves=0,activations=0,preset=preset,data=data}
    EditModePresetLayoutManager={GetCopyOfPresetLayouts=function() return {preset} end}
    C_EditMode={GetLayouts=function() return data end,SaveLayouts=function(value) state.saves=state.saves+1; state.saved=value; return not state.failSave end,
        SetActiveLayout=function(index) state.activations=state.activations+1; state.active=index; if state.failActivate and index~=2 then return false end end}
    function state.restore()
        C_EditMode=old.api; EditModePresetLayoutManager=old.presets
        Enum.EditModeLayoutType=old.types; Enum=old.enum; Constants.EditModeConsts=old.limits; Constants=old.constants
        for name,f in pairs(old.frames) do _G[name]=f or nil end
    end
    return state
end
ResetTest(); local FS=ForeverSuite; local P=FS.LayoutPresets; local state=NativeLayoutFixture()
local plan,reason=P:Prepare('Layout 1',true); assert(plan,reason); assert(state.saves==0 and #state.data.layouts==1 and state.preset.systems[1].isInDefaultPosition)
assert(P:Commit('Layout 1',plan) and state.saves==1 and state.active==3)
assert(state.saved.layouts[2].layoutName=='Personal' and state.saved.layouts[3].layoutName=='ForeverSuite Layout 1')
assert(not state.saved.layouts[3].systems[1].isInDefaultPosition and MainActionBar.systemInfo.untouched)
assert(state.preset.systems[1].anchorInfo.relativePoint=='CENTER'); state.restore()

-- TEST: Failed game layout saves and activation preserve existing addon positions and restore the previous game choice
ResetTest(); local FS=ForeverSuite; local P=FS.LayoutPresets; local state=NativeLayoutFixture()
FS.db.layout.frames.Clock={x=17,y=300,scale=1}; local plan=P:Prepare('Compact',true); state.failSave=true
assert(not P:Commit('Compact',plan) and FS.db.layout.frames.Clock.x==17 and state.activations==0)
state.failSave=false; state.failActivate=true; assert(not P:Commit('Compact',plan) and FS.db.layout.frames.Clock.x==17 and state.active==2)
state.restore()

-- TEST: Game layout availability slot limits and combat guards fail before applying any staged settings
ResetTest(); local FS=ForeverSuite; local P=FS.LayoutPresets; local state=NativeLayoutFixture()
Constants.EditModeConsts.EditModeMaxLayoutsPerType=1; assert(not P:Prepare('Classic',true))
Constants.EditModeConsts.EditModeMaxLayoutsPerType=5; local plan=P:Prepare('Classic',true); TEST.combat=true
assert(not P:Commit('Classic',plan) and state.saves==0); TEST.combat=false; FS.modules.Vendor.busy=true
assert(not P:Commit('Classic',plan) and state.saves==0); FS.modules.Vendor.busy=false
state.restore(); local api=C_EditMode; C_EditMode=nil; assert(not P:Prepare('Classic',true)); assert(P:Prepare('Classic',false)); C_EditMode=api

-- TEST: Finishing a selected layout saves fitted addon positions in the current profile and Keep current preserves them
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show(); I.step=5; I.draft.layout='Layout 1'; I.draft.nativeLayout=false
I.step=3; I:Refresh(); I.window.next:Click(); assert(FS.db.setup.completed and FS.db.layout.preset=='Layout 1')
local frames=FS.db.profiles.saved[FS.db.profiles.current].layout.frames; assert(frames['Unit:player'] and frames['Unit:target'])
local x=FS.db.layout.frames['Unit:player'].x; FS:InitializeDatabase(); assert(FS.db.layout.frames['Unit:player'].x==x)
I:Show(); assert(I.draft.layout=='Keep current'); I.draft.nativeLayout=true; assert(I:Apply())
assert(FS.db.layout.frames['Unit:player'].x==x)

-- TEST: Five installer steps and layout controls fit large text and never include personal screenshot data
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:Show(); FS.db.typography.global.size=24; FS.Typography:Apply()
for step=1,5 do I.step=step; I:Refresh(); local f=I.window; assert(f:GetHeight()*f:GetScale()<=UIParent:GetHeight()-47) end
local f=I.window; assert(f.nativeLayout:IsShown() and -f.next.point[3]+f.next:GetHeight()<f:GetHeight())
local allowed={Player=true,Target=true,Pet=true,Map=true,Quests=true,Chat=true,Meter=true,Menu=true,Bags=true,XP=true,Waypoint=true,['1 2 3 4 5 6 7 8 9 0']=true,['Action bar 2']=true,['Action bar 3']=true}
for _,part in pairs(f.layoutPreview.parts) do assert(allowed[part.frame.label:GetText()]) end
FS.db.typography.global.size=0; FS.Typography:Apply(); f:Hide()

-- TEST: Applying a setup theme never reads dimensions from native anchored secret skins
ResetTest(); local FS=ForeverSuite; local frame=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
frame.GetWidth=function() error('Secret skin width must not be read') end
frame.GetHeight=function() error('Secret skin height must not be read') end
FS.HUD:Skin(frame,true); assert(frame.fsThemeBorderOnly and FS.Themes.frames[frame])
FS.db.appearance.theme='Celestial Forge'; assert(FS.Themes:Refresh() and frame.fsFlatSkin)
FS.db.appearance.theme='Legacy'; assert(FS.Themes:Refresh())

-- TEST: Automatic menu avoidance on a first install does not suppress the recommended starter layout
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; local oldFresh,oldOpened=FS.firstInstallation,I.hasOpenedSetup
FS.firstInstallation=true; I.hasOpenedSetup=nil; FS.db.layout.frames.MainMenu={x=400,y=30,scale=1}
I:Show(); assert(I.draft.layout=='Layout 1')
FS.db.layout.frames['Unit:player']={x=-200,y=300,scale=1}; I:Show(); assert(I.draft.layout=='Keep current')
FS.firstInstallation=oldFresh; I.hasOpenedSetup=oldOpened; I.window:Hide()

-- TEST: Saved Control Center scale and large text fit the viewport without overwriting mover preferences
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; local oldW,oldH=UIParent:GetWidth(),UIParent:GetHeight()
UIParent:SetSize(1280,720); FS.db.layout.frames.ControlCenter={x=500,y=700,scale=1.4}
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply(); FS.Layout:Apply('ControlCenter')
assert(f:GetWidth()*f:GetScale()<=1248.001 and f:GetHeight()*f:GetScale()<=688.001 and f.scrollMaximum>0)
assert(FS.db.layout.frames.ControlCenter.scale==1.4 and FS.db.layout.frames.ControlCenter.x==500 and FS.db.layout.frames.ControlCenter.y==700)
assert(f.cards.Bags.heading.font[2]==36 and f.profiles:GetParent()==f and f.reload:GetParent()==f)
UIParent:SetSize(oldW,oldH); FS.db.layout.frames.ControlCenter=nil; FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.Typography:Apply()

-- TEST: Wheel arrows and scrollbar reach the bottom actions while header profile and footer stay fixed
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; FS.db.typography.global.size=24; FS.Typography:Apply()
local profilePoint={f.profiles:GetPoint()}; local reloadPoint={f.reload:GetPoint()}; assert(f.scrollMaximum>0)
f.bodyScroll.scripts.OnMouseWheel(f.bodyScroll,-100); assert(f.scrollOffset==f.scrollMaximum and f.bodyScroll:GetVerticalScroll()==f.scrollMaximum)
assert(-f.disableAll.point[3]+f.disableAll:GetHeight()-f.scrollOffset<=f.bodyScroll:GetHeight())
assert(f.profiles.point[3]==profilePoint[3] and f.reload.point[3]==reloadPoint[3])
f.scrollUp:Click(); assert(f.scrollOffset<f.scrollMaximum); f.bodyScrollbar.scripts.OnValueChanged(f.bodyScrollbar,0); assert(f.scrollOffset==0)
FS:ScrollConfig(-100); assert(f.scrollOffset==0); FS.db.typography.global.size=0; FS.Typography:Apply()

-- TEST: Viewport reflow is stable on narrow screens and font reset clamps scrolling cleanly
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window; local w,h=UIParent:GetWidth(),UIParent:GetHeight()
UIParent:SetSize(640,360); FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply()
local height,content,scale=f:GetHeight(),f.bodyContent:GetHeight(),f:GetScale()
FS:RefreshConfig(); FS.Typography:Apply(); assert(f:GetHeight()==height and f.bodyContent:GetHeight()==content and f:GetScale()==scale)
assert(f:GetWidth()*scale<=608.001 and height*scale<=328.001)
FS:ScrollConfig(100000); UIParent:SetSize(w,h); FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.Typography:Apply()
assert(f.scrollOffset<=f.scrollMaximum)

-- TEST: Paging and search scroll results into view without losing module choices or footer callbacks
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); FS:ClearModuleFilter(); local f=FS.window; local reload=f.reload:GetScript('OnClick'); f.cardPage=1; FS:RefreshConfig()
FS:SetModuleEnabled('Chat',false); FS:ScrollConfig(100000); f.nextModules:Click(); assert(f.scrollOffset==0 and f.cardPage==2)
FS:ScrollConfig(100000); FS:SetModuleFilter('chat panels','All'); assert(f.scrollOffset==0 and f.filteredCount==1 and not FS:IsModuleEnabled('Chat'))
assert(f.reload:GetScript('OnClick')==reload); FS:ClearModuleFilter()

-- TEST: All themes reach native anchored decorations using fixed geometry without reading restricted dimensions
ResetTest(); local FS=ForeverSuite; local frame=CreateFrame('Frame',nil,UIParent,'BackdropTemplate'); FS.HUD:Skin(frame,true)
frame.GetWidth=function() error('Restricted themed width') end; frame.GetHeight=function() error('Restricted themed height') end
for i,name in ipairs(FS.Themes.names) do
    assert(FS.Themes:Set(name)); local state=FS.Themes.frames[frame]
    assert(state.parts[1]:IsShown() and state.parts[1].texture==FS.Themes:Asset(i,'Panel') and state.corner==2)
end
assert(FS.Themes:Set('Legacy')); for _,part in ipairs(FS.Themes.frames[frame].parts) do assert(not part:IsShown()) end

-- TEST: Guided setup finish applies the chosen theme to live UI and active profile with explicit dashboard feedback
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local I=FS.Installer; local f=FS.window
I:Show(); I.step=2; I:Refresh(); I.window.choices[4]:Click(); assert(FS.db.appearance.theme=='Legacy')
I.draft.layout='Keep current'; I.step=3; I:Refresh(); I.window.next:Click()
assert(not I.window:IsShown() and FS.db.appearance.theme=='Verdant Relic' and f.appearance:GetText()=='Theme: Verdant Relic')
assert(FS.Themes.frames[f].parts[1].texture==FS.Themes:Asset(4,'Panel'))
assert(FS.db.profiles.saved[FS.db.profiles.current].appearance.theme=='Verdant Relic')

-- TEST: Theme-only apply updates live artwork and profile while cancellation keeps the previous choice
ResetTest(); local FS=ForeverSuite; local I=FS.Installer; I:ShowThemes(); I.window.choices[8]:Click(); I.window.next:Click()
assert(FS.db.appearance.theme=='Astral Glass' and FS.db.profiles.saved[FS.db.profiles.current].appearance.theme=='Astral Glass')
I:ShowThemes(); I.window.choices[10]:Click(); I.window.later:Click(); assert(FS.db.appearance.theme=='Astral Glass')
assert(FS.Themes:Set('Legacy'))
