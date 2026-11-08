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
