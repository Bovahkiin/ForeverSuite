-- TEST: Nameplate reaction colors distinguish attackable neutral NPCs while preserving class and threat priorities
ResetTest();local FS=ForeverSuite;local N=FS.modules.Nameplates;local db=FS.db.nameplates
TEST.units.target.enemy=true;TEST.units.target.player=false;TEST.units.target.reaction=4
local r,g,b=N:HealthColor('target',0,db);assert(r==1 and g==.82 and b==0)
TEST.units.target.reaction=3;r,g,b=N:HealthColor('target',0,db);assert(r==.85 and g==.12)
TEST.units.target.enemy=false;TEST.units.target.reaction=5;r,g,b=N:HealthColor('target',0,db);assert(r==.18 and g==.75)
TEST.units.target.enemy=true;TEST.units.target.reaction=4;db.threatColors=true
r,g,b=N:HealthColor('target',3,db);assert(r==.85 and g==.12)
db.threatColors=false;db.neutralColor='Blue';r,g,b=N:HealthColor('target',0,db);assert(r==.22 and b==1)
TEST.units.target.player=true;TEST.units.target.class='WARRIOR';r,g,b=N:HealthColor('target',0,db);assert(r==.78)
local original=UnitReaction;UnitReaction=function() error('Unreadable reaction') end
TEST.units.target.player=false;r,g,b=N:HealthColor('target',0,db);assert(r==.85 and g==.12);UnitReaction=original

-- TEST: Nameplate faction events recolor reused neutral plates without changing their targeting or allocating frames
ResetTest();local FS=ForeverSuite;local N=FS.modules.Nameplates
local plate=CreateFrame('Frame');plate.UnitFrame=CreateFrame('Button',nil,plate);plate.UnitFrame.unit='target'
TEST.units.target.enemy=true;TEST.units.target.player=false;TEST.units.target.reaction=4
local oldPlateAPI=C_NamePlate;C_NamePlate={GetNamePlates=function() return {plate} end,GetNamePlateForUnit=function(unit) return unit=='target' and plate end}
N:SettingsChanged()
local f=N.custom[plate].canvas;assert(f.health.barColor[1]==1 and f.health.barColor[2]==.82)
local count=#TEST.frames;TEST.units.target.reaction=3;N.events.scripts.OnEvent(N.events,'UNIT_FACTION','target')
assert(f.health.barColor[1]==.85 and #TEST.frames==count and plate.UnitFrame:GetAlpha()==0)
TEST.units.target.reaction=4;N.events.scripts.OnEvent(N.events,'UNIT_FACTION','target');assert(f.health.barColor[2]==.82)
N:Release(N.custom[plate]);C_NamePlate=oldPlateAPI

-- TEST: Nameplate neutral settings migrate save search and preview without changing live reaction preferences
ResetTest();local FS=ForeverSuite;local N=FS.modules.Nameplates;local db=FS.db.nameplates
db.neutralColor=nil;db.enemyColor='Purple';db.friendlyColor='Blue';N:NormalizeSettings()
assert(db.neutralColor=='Yellow' and db.enemyColor=='Purple' and db.friendlyColor=='Blue')
local found=false;for _,row in ipairs(FS.Beginner:Options('Nameplates')) do if row.key=='neutralColor' then found=true end end;assert(found)
N:ShowWindow();N:EditorGroup(3);local f=N.editor;assert(f.preview.health.barColor[1]==.65)
f.reactionPreview:Click();assert(f.preview.health.barColor[1]==1 and f.preview.health.barColor[2]==.82 and db.neutralColor=='Yellow')
f.reactionPreview:Click();assert(f.preview.health.barColor[3]==1 and db.friendlyColor=='Blue')
f.reactionPreview:Click();assert(f.preview.health.barColor[1]==.65)
assert(FS.modules.Profiles:Save('Reaction colors'));db.neutralColor='Pink';assert(FS.modules.Profiles:Load('Reaction colors') and FS.db.nameplates.neutralColor=='Yellow')
f:Hide()

-- TEST: Nameplate aura restrictions skip queries and clear stale aura icons until access returns
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
local plate=CreateFrame('Frame'); plate.UnitFrame=CreateFrame('Button',nil,plate); plate.UnitFrame.unit='target'
local oldAuras,oldSecrets=C_UnitAuras,C_Secrets; local restricted=false; local calls=0
C_Secrets={ShouldAurasBeSecret=function() return restricted end}
C_UnitAuras={GetAuraDataByIndex=function(_,i) calls=calls+1; assert(not restricted); if i==1 then return {icon=123,duration=10,expirationTime=TEST.now+10} end end}
N:Update(plate,'target'); local f=N.custom[plate].canvas; assert(calls>0 and f.auras[1]:IsShown())
calls=0; restricted=true; TEST.combat=true
for i=1,20 do N:Update(plate,'target') end
assert(calls==0 and not f.auras[1]:IsShown() and not f.auras[1].cooldown:IsShown() and f:IsShown())
restricted=false; TEST.combat=false; N:Update(plate,'target'); assert(calls>0 and f.auras[1]:IsShown())
C_UnitAuras.GetAuraDataByIndex=function() error('Client denied aura access') end
N:Update(plate,'target'); assert(not f.auras[1]:IsShown() and f:IsShown())
C_UnitAuras,C_Secrets=oldAuras,oldSecrets; N:Release(N.custom[plate])

-- TEST: Unit events never query nameplate API with target-of-target or secret tokens
ResetTest(); local N=ForeverSuite.modules.Nameplates; local old=C_NamePlate; C_NamePlate={}; local calls={}
C_NamePlate.GetNamePlateForUnit=function(unit) assert(unit=='target' or unit=='focus' or unit:match('^nameplate%d+$')); calls[#calls+1]=unit end
for _,unit in ipairs({'targettarget','pettarget','party1target','player','pet'}) do N.events.scripts.OnEvent(N.events,'UNIT_HEALTH',unit) end
assert(#calls==0)
for _,unit in ipairs({'target','focus','nameplate1'}) do N.events.scripts.OnEvent(N.events,'UNIT_HEALTH',unit) end
assert(#calls==3)
local marker={}; local oldSecret=issecretvalue; issecretvalue=function(value) return value==marker end
N.events.scripts.OnEvent(N.events,'UNIT_HEALTH',marker); assert(#calls==3)
issecretvalue=oldSecret; C_NamePlate=old

-- TEST: Native anchored skin renders fixed edges without reading secret frame dimensions
ResetTest(); local H=ForeverSuite.HUD; local frame=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
frame.GetWidth=function() error('Secret width must not be read') end
frame.GetHeight=function() error('Secret height must not be read') end
local calls=0; frame.SetBackdrop=function(_,value) assert(value==nil); calls=calls+1 end
H:Skin(frame,true); assert(calls==1 and #frame.fsFlatSkin.edges==4)
H:Skin(frame,true); assert(calls==1)
frame:SetBackdropColor(.1,.2,.3,.4); frame:SetBackdropBorderColor(.4,.3,.2,.1)
assert(frame.fsFlatSkin.background.color[1]==.1 and frame.fsFlatSkin.edges[1].color[1]==.4)

-- TEST: Generic module settings avoid arithmetic on the relative anchor string
ResetTest(); local FS=ForeverSuite; local module=FS.modules.Loot
module:CreateSettings(FS.window); local f=module.settings
f.description.GetPoint=function() return 'TOPLEFT',f,'TOPLEFT',20,-65 end
f:LayoutText(); assert(f:GetHeight()>=420)

-- TEST: Feed Pet left-click targets the exact food stack once and bypasses the item options panel
ResetTest(); local B=ForeverSuite.modules.Bags; MerchantFrame:Hide()
TEST.data[710]={quality=1,price=1,petFood=true}; AddItem(1,710,3); AddItem(2,710,2)
B:ShowWindow(); local c=B.window.cells[2]; local row=c.row; local before=TEST.bags[row.bag][row.slot].stackCount
local uses=TEST.secureUses or 0; TEST.targeting=true
c.scripts.PreClick(c,'LeftButton'); c.scripts.OnClick(c,'LeftButton',true); assert(#TEST.actions==0)
c.scripts.OnClick(c,'LeftButton',false)
assert(#TEST.actions==1 and TEST.actions[1].kind=='spell-target' and TEST.actions[1].bag==row.bag and TEST.actions[1].slot==row.slot)
assert(TEST.bags[row.bag][row.slot].stackCount==before-1 and TEST.bags[0][1].stackCount==3)
assert(not TEST.targeting and not B.selected and not B.window.itemPanel:IsShown() and (TEST.secureUses or 0)==uses)
B:Refresh(); Click(B.window.cells[1]); assert(B.window.itemPanel:IsShown(), 'Ordinary left-click still opens options')

-- TEST: Invalid food stays under client validation while stale locked empty and transaction-owned slots cannot be targeted
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor; MerchantFrame:Hide()
TEST.data[711]={quality=1,price=1}; AddItem(1,711,2); B:ShowWindow(); local c=B.window.cells[1]; local row=c.row
TEST.targeting=true; c.scripts.PreClick(c,'LeftButton'); c.scripts.OnClick(c,'LeftButton',false)
assert(#TEST.actions==1 and TEST.targeting and TEST.bags[0][1].stackCount==2 and not B.window.itemPanel:IsShown())
TEST.actions={}; TEST.bags[0][1].isLocked=true; assert(B:TargetBagItem(row)); TEST.bags[0][1].isLocked=false
V.busy=true; B:TargetBagItem(row); V.busy=false; V.pending={}; B:TargetBagItem(row); V.pending=nil
TEST.combat=true; B:TargetBagItem(row); TEST.combat=false; TEST.repairMode=true; B:TargetBagItem(row); TEST.repairMode=false
TEST.cursor={}; B:TargetBagItem(row); TEST.cursor=nil
B:TargetBagItem({empty=true}); B:TargetBagItem({stock=true}); B:TargetBagItem(nil)
AddItem(1,711,2); B:TargetBagItem(row); assert(#TEST.actions==0 and TEST.targeting)
TEST.targeting=false

-- TEST: Unit spell cursors never use inventory items and item-ID targeting takes priority over merchant selling
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[712]={quality=1,price=1,petFood=true}; AddItem(1,712,2); B:ShowWindow(); local row=V:ReadItem(0,1)
local oldItem,oldID=SpellCanTargetItem,SpellCanTargetItemID
SpellCanTargetItem=function() return false end; SpellCanTargetItemID=function() return false end
TEST.targeting=true; assert(B:TargetBagItem(row)); assert(#TEST.actions==0 and TEST.targeting)
SpellCanTargetItemID=function() return true end; assert(B:TargetBagItem(row))
assert(#TEST.actions==1 and TEST.actions[1].kind=='spell-target' and TEST.bags[0][1].stackCount==1 and not B.window.itemPanel:IsShown())
SpellCanTargetItem,SpellCanTargetItemID=oldItem,oldID; TEST.targeting=false

-- TEST: Hunter pet happiness shows the three real mood atlases updates on events and explains feeding in its tooltip
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; local oldAPI,oldUI=C_PetInfo,HasPetUI
TEST.units.pet={name='Crab',health=80,maxHealth=100,power=35,maxPower=100,level=9}; local mood=1
C_PetInfo={GetPetHappiness=function() return mood,75,0 end,GetPetFoodTypes=function() return {'Fish','Bread'} end}
HasPetUI=function() return true,true end; U:SettingsChanged(); local badge=U.frames.pet.happiness
assert(badge and badge:IsShown() and badge.icon.atlas=='UI-PetMad')
GameTooltip.lines={}; badge.scripts.OnEnter(badge); assert(table.concat(GameTooltip.lines,' '):find('Feed your pet',1,true) and table.concat(GameTooltip.lines,' '):find('Fish, Bread',1,true))
TEST.combat=true; mood=2; U.events.scripts.OnEvent(U.events,'UNIT_HAPPINESS','pet'); assert(badge.icon.atlas=='UI-PetNeutral')
mood=3; U.events.scripts.OnEvent(U.events,'PET_UI_UPDATE'); assert(badge.icon.atlas=='UI-PetHappiness' and badge.mood==3)
TEST.combat=false; TEST.units.pet=nil; U.events.scripts.OnEvent(U.events,'UNIT_PET','player'); assert(not badge:IsShown() and not badge.mood)
C_PetInfo,HasPetUI=oldAPI,oldUI

-- TEST: Happiness hides for non-hunter pets unavailable data and restricted values without inventing a mood
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; local oldAPI,oldUI,oldLegacy=C_PetInfo,HasPetUI,GetPetHappiness
TEST.units.pet={name='Pet',health=80,maxHealth=100,power=35,maxPower=100}; local mood=3
C_PetInfo={GetPetHappiness=function() return mood end}; HasPetUI=function() return true,false end
U:SettingsChanged(); local badge=U.frames.pet.happiness; assert(not badge:IsShown())
HasPetUI=function() return true,true end; mood=nil; U:RefreshPetHappiness(); assert(not badge:IsShown())
local token={}; local oldSecret=issecretvalue; issecretvalue=function(v) return v==token end
mood=token; U:RefreshPetHappiness(); assert(not badge:IsShown()); issecretvalue=oldSecret
C_PetInfo=nil; GetPetHappiness=nil; U:RefreshPetHappiness(); assert(not badge:IsShown())
GetPetHappiness=function() return 2 end; U:RefreshPetHappiness(); assert(badge:IsShown() and badge.mood==2)
C_PetInfo,HasPetUI,GetPetHappiness=oldAPI,oldUI,oldLegacy; TEST.units.pet=nil; U:RefreshPetHappiness()

-- TEST: Default pet frame is compact and follows the customized player frame without creating saved positions
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; local L=FS.Layout
FS.db.layout.frames['Unit:player']={x=-260,y=510,scale=1.2}; U:SettingsChanged()
local pet,player=U.frames.pet,U.frames.player; local point,relative,anchor,x,y=pet:GetPoint()
assert(point=='TOPLEFT' and relative==player and anchor=='BOTTOMLEFT' and x==0 and y==-36)
assert(math.abs(pet:GetScale()/player:GetScale()-.75)<.00001 and pet:GetWidth()==270)
assert(not FS.db.layout.frames['Unit:pet'] and FS.db.unitFrames.pet.x==-430 and FS.db.unitFrames.pet.y==150)
FS.db.layout.frames['Unit:player']={x=100,y=600,scale=.8}; L:Apply('Unit:player')
assert(math.abs(pet:GetScale()-.6)<.00001 and select(2,pet:GetPoint())==player)

-- TEST: Customized pet positions and sizes survive the new default across serialized reloads
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames
FS.db.layout.frames['Unit:pet']={x=150,y=350,scale=1.1}; U:SettingsChanged()
local pet=U.frames.pet; assert(pet:GetScale()==1.1 and select(2,pet:GetPoint())==UIParent)
local E=FS.Extensions; ForeverSuiteDB=assert(E:Decode(E:Encode(FS.db))); FS:InitializeDatabase(); U:SettingsChanged()
assert(pet:GetScale()==1.1 and FS.db.layout.frames['Unit:pet'].x==150 and select(2,pet:GetPoint())==UIParent)
FS.db.layout.frames['Unit:pet']=nil; FS.db.unitFrames.pet={x=-300,y=260}; U:SettingsChanged()
assert(select(2,pet:GetPoint())==UIParent and FS.db.unitFrames.pet.x==-300)

-- TEST: Compact pet placement defers protected layout changes until combat ends
ResetTest(); local U=ForeverSuite.modules.UnitFrames; U:SettingsChanged(); local pet=U.frames.pet
local point={pet:GetPoint()}; local scale=pet:GetScale(); TEST.combat=true
U.frames.player:SetScale(1.4); U:ApplyPetDefault(); U:SettingsChanged()
assert(U.pending and pet:GetScale()==scale and select(2,pet:GetPoint())==point[2])
TEST.combat=false; U.events.scripts.OnEvent(U.events,'PLAYER_REGEN_ENABLED')
assert(not U.pending and math.abs(pet:GetScale()-.75)<.00001)

-- TEST: Pet frame tracks summoned pets health power portrait levels and secure visibility without moving in combat
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames
TEST.units.pet={name='Hunter companion',health=80,maxHealth=100,power=35,maxPower=100,level=10}
local previous=UnitLevel; UnitLevel=function(unit) return TEST.units[unit] and TEST.units[unit].level or 1 end
U:SettingsChanged(); local f=U.frames.pet
assert(f and f.watched and f:GetAttribute('unit')=='pet' and f:GetAttribute('type1')=='target')
assert(f.name:GetText()=='Hunter companion' and f.level:GetText()=='10' and FS.Layout.targets['Unit:pet'].frame==f)
local point={f:GetPoint()}; TEST.combat=true; TEST.units.pet.name='New companion'
U.events.scripts.OnEvent(U.events,'UNIT_PET','player'); assert(f.name:GetText()=='New companion')
TEST.units.pet.level=11; U.events.scripts.OnEvent(U.events,'UNIT_LEVEL','pet'); assert(f.level:GetText()=='11')
local after={f:GetPoint()}; assert(after[4]==point[4] and after[5]==point[5])
FS.db.unitFrames.showPet=false; U:SettingsChanged(); assert(U.pending and f.watched)
TEST.combat=false; U.events.scripts.OnEvent(U.events,'PLAYER_REGEN_ENABLED'); assert(not f.watched and not f:IsShown())
FS.db.unitFrames.showPet=true; TEST.units.pet=nil; U:SettingsChanged(); assert(f.watched and not f:IsShown())
UnitLevel=previous

-- TEST: Profession replacement fill shares the native animated mask instead of rendering the whole bar full
ResetTest(); local N=ForeverSuite.NativeWindows
local bar=CreateFrame('Frame',nil,UIParent); bar:SetSize(750,26)
bar.Fill=bar:CreateTexture(); bar.Fill:SetSize(750,26)
bar.Mask=CreateFrame('MaskTexture',nil,bar); bar.Mask:SetWidth(750*40/75)
bar.Flare=bar:CreateTexture(); bar.Flare:SetAlpha(.8)
N:ProfessionRank(bar,true); local state=N.progress[bar]; local fill=state.visual
assert(fill.masks[bar.Mask] and state.mask==bar.Mask and fill.allPoints[1]==bar.Fill)
assert(bar.Mask:GetWidth()==400 and bar.Fill:GetWidth()==750 and bar.Flare:GetAlpha()==0)
bar.Mask:SetWidth(410); N:ProfessionRank(bar,true); assert(state.visual==fill and bar.Mask:GetWidth()==410)
N:ProfessionRank(bar,false); assert(not fill:IsShown() and bar.Flare:GetAlpha()==.8)

-- TEST: Player target and focus levels update on unit and player-level events without moving frames
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; local previous=UnitLevel
UnitLevel=function(unit) return TEST.units[unit] and TEST.units[unit].level or -1 end
TEST.units.player.level=11; TEST.units.target.level=17; U:SettingsChanged()
local player,target=U.frames.player,U.frames.target; local point={player:GetPoint()}
assert(player.level:GetText()=='11' and target.level:GetText()=='17' and U.frames.focus.level)
TEST.units.player.level=12; U.events.scripts.OnEvent(U.events,'PLAYER_LEVEL_UP',12); assert(player.level:GetText()=='12')
TEST.combat=true; TEST.units.target.level=18; U.events.scripts.OnEvent(U.events,'UNIT_LEVEL','target'); assert(target.level:GetText()=='18')
TEST.units.target.level=-1; U:RefreshUnit('target'); assert(target.level:GetText()=='??')
local token={}; local secret=issecretvalue; issecretvalue=function(v) return v==token end
TEST.units.target.level=token; U:RefreshUnit('target'); assert(target.level:GetText()=='??')
issecretvalue=secret; TEST.units.target.level=nil; TEST.units.player.level=nil; UnitLevel=previous; TEST.combat=false
local after={player:GetPoint()}; assert(point[1]==after[1] and point[4]==after[4] and point[5]==after[5])

-- TEST: Level text reserves room beside long names and follows unit-frame typography
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; U:SettingsChanged(); local f=U.frames.target
FS.db.typography.modules.UnitFrames={family='Arial Bold',size=18,scale=1.5,weight='Default',outline='Thin',shadow='Off'}
FS.Typography:Apply(); local path,size=f.level:GetFont()
assert(path==FS.Typography.families['Arial Bold'] and size==27)
assert(f.name:GetWidth()+f.level:GetWidth()+18<=f.health:GetWidth()+.01)
local _,relative=f.level:GetPoint(); assert(relative==f.health)
FS.db.typography.modules.UnitFrames=nil; FS.Typography:Apply()

-- TEST: Typography edits immediately update only the active saved profile and keep the selected scope
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles; local F=FS.Typography
P:Save('Other text'); P:Save('Active text'); local other=FS.Extensions:Encode(FS.db.profiles.saved['Other text'].typography)
F.scope='All modules'; F:Show(); F:Edit('family'); F:Edit('family'); F:Edit('weight'); F:Edit('weight'); F:Edit('size')
local stored=FS.db.profiles.saved['Active text'].typography
assert(stored.global.family=='Friz Quadrata' and stored.global.weight=='Bold' and stored.global.size==10)
assert(FS.Extensions:Encode(FS.db.profiles.saved['Other text'].typography)==other)
F.scope='Gear'; F:Show(); assert(FS.db.typography.scope=='Gear')
F.scope=nil; F:Show(); assert(F.scope=='Gear' and F.window.reset:GetText()=='Follow global text settings')
F.scope='All modules'; F:Show(); assert(F.window.reset:GetText()=='Reset global text settings'); F.window:Hide()

-- TEST: Text choices survive serialized logout data profile initialization and reapplication
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles; local F=FS.Typography; local E=FS.Extensions
E:Normalize()
P:Save('Persistent fonts'); P:AssignCharacter('Persistent fonts')
FS.db.typography.global={family='Friz Quadrata',size=16,scale=1.1,weight='Normal',outline='Thin',shadow='On'}
FS.db.typography.modules.UnitFrames={family='Arial Bold',size=14,scale=1,weight='Bold',outline='Thick',shadow='Off'}
F:Apply(); local encoded=E:Encode(FS.db.typography)
FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGOUT')
ForeverSuiteDB=assert(E:Decode(E:Encode(FS.db))); FS:InitializeDatabase(); E:Initialize(); F:Apply()
assert(E:Encode(FS.db.typography)==encoded and FS.db.profiles.saved['Persistent fonts'].typography.global.family=='Friz Quadrata')
local path,size=FS.modules.UnitFrames.frames.player.level:GetFont(); assert(path==F.families['Arial Bold'] and size==14)
ResetTest(); F:Apply()

-- TEST: Bag button borders use the selected art style as independent decorations
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
local oldBar,oldButton=BagsBar,CharacterBag0Slot
if not BagsBar then BagsBar=CreateFrame('Frame','TestBagsBar',UIParent); BagsBar:SetSize(200,40) end
if not CharacterBag0Slot then CharacterBag0Slot=CreateFrame('Button',nil,BagsBar); CharacterBag0Slot.icon=CharacterBag0Slot:CreateTexture() end
A:SettingsChanged()
local count=0
for button,state in pairs(A.bagSkins) do
    count=count+1; local icon=button.icon or button.Icon; local texture=icon and icon:GetTexture()
    assert(state.border:GetParent()==UIParent and state.border.fsActionDecoration)
    for _,style in ipairs(A.styles) do
        FS.db.actionBars.style=style; A:ApplyAppearance()
        assert(state.border.fsTileStyle==style and (not icon or icon:GetTexture()==texture))
    end
end
assert(count>0); FS.db.actionBars.style='Minimal'; A:SettingsChanged()
BagsBar,CharacterBag0Slot=oldBar,oldButton

-- TEST: Addon choice fixture
function SystemsFixture()
    ResetTest(); local FS=ForeverSuite; local C=FS.Compatibility
    local saved={C_AddOns=C_AddOns,LibStub=LibStub,Zygor=ZygorGuidesViewer,TomTom=TomTom}
    local addons={RXPGuides=true,ZygorGuidesViewer=true,TomTom=true,Plater=true,Platynator=true,Kui_Nameplates=true,Kui_Nameplates_Core=true}
    local loaded={}; for name in pairs(addons) do loaded[name]=true end
    local changed={}
    C_AddOns={
        DoesAddOnExist=function(name) return addons[name]~=nil end,
        IsAddOnLoaded=function(name) return loaded[name]==true end,
        GetAddOnEnableState=function(name) return addons[name] and 2 or 0 end,
        EnableAddOn=function(name,character) assert(character=='Player'); addons[name]=true; changed[#changed+1]={name,true} end,
        DisableAddOn=function(name,character) assert(character=='Player'); addons[name]=false; changed[#changed+1]={name,false} end,
        GetAddOnDependencies=function(name) if name=='Kui_Nameplates' then return 'Kui_Nameplates_Core' end end,
    }
    local rxp={settings={profile={disableArrow=false}},arrowFrame=CreateFrame('Frame'),guide=CreateFrame('Frame')}
    rxp.arrowFrame.IsFeatureEnabled=function() return not rxp.settings.profile.disableArrow end
    rxp.DrawArrow=function() end
    LibStub=function() return {GetAddon=function(_,name) if name=='RXPGuides' then return rxp end end} end
    local z={db={profile={arrowshow=true}},Pointer={ArrowFrame=CreateFrame('Frame')},Frame=CreateFrame('Frame')}
    z.Pointer.UpdateArrowVisibility=function(self) self.ArrowFrame:SetShown(z.db.profile.arrowshow) end; ZygorGuidesViewer=z
    local tom={db={profile={arrow={enable=true}}},arrow=CreateFrame('Frame')}
    tom.ShowHideCrazyArrow=function(self) self.arrow:SetShown(self.db.profile.arrow.enable) end; TomTom=tom
    C.snoozed={}; FS.db.setup.completed=true
    local function restore()
        if C.window then C.window:Hide() end
        C_AddOns,LibStub,ZygorGuidesViewer,TomTom=saved.C_AddOns,saved.LibStub,saved.Zygor,saved.TomTom
        C.snoozed={}; FS.db.compatibility.characters={}; FS.db.map.navigation=true; FS.db.nameplates.enabled=true
    end
    return FS,C,addons,rxp,z,tom,changed,restore
end

-- TEST: Multiple waypoint providers prompt without side effects and a choice controls only arrows
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
assert(C:NeedsChoice('waypoints')); C:Scan(); assert(C.window:IsShown() and C.category=='waypoints')
assert(not rxp.settings.profile.disableArrow and z.db.profile.arrowshow and tom.db.profile.arrow.enable and #changed==0)
assert(C:ApplyWaypoints('Zygor',true))
assert(not FS.db.map.navigation and rxp.settings.profile.disableArrow and z.db.profile.arrowshow and not tom.db.profile.arrow.enable)
assert(rxp.guide:IsShown() and z.Frame:IsShown() and C:Data().waypoints=='Zygor' and not C:NeedsChoice('waypoints'))
assert(C:ApplyWaypoints('ForeverSuite',true))
assert(FS.db.map.navigation and rxp.settings.profile.disableArrow and not z.db.profile.arrowshow and not tom.db.profile.arrow.enable and #changed==0)
restore()

-- TEST: Remembered navigation choices reapply and remain separate from UI profiles and undo
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
assert(C:ApplyWaypoints('RXPGuides',true)); local key=C:Character()
FS.modules.Profiles:Save('One UI'); FS.modules.Profiles:Save('Two UI')
assert(not FS.modules.Profiles:Snapshot().compatibility and not FS.Extensions:SettingsSnapshot().compatibility)
assert(FS.modules.Profiles:Load('One UI')); assert(C:Data().waypoints=='RXPGuides' and not FS.db.map.navigation)
rxp.settings.profile.disableArrow=true; z.db.profile.arrowshow=true; tom.db.profile.arrow.enable=true
C:Scan(); assert(not rxp.settings.profile.disableArrow and not z.db.profile.arrowshow and not tom.db.profile.arrow.enable)
assert(FS.db.compatibility.characters[key].waypoints=='RXPGuides'); restore()

-- TEST: Nameplate choice preserves unrelated addons and dependency settings then reloads only on explicit apply
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
assert(C:ApplyNameplates('Kui'))
assert(not FS.db.nameplates.enabled and addons.Kui_Nameplates and addons.Kui_Nameplates_Core and not addons.Plater and not addons.Platynator)
assert(addons.RXPGuides and addons.ZygorGuidesViewer and addons.TomTom)
C:Show('nameplates'); C.selected='ForeverSuite'; local before=TEST.reloads or 0
C.window.apply:Click(); assert(TEST.reloads==before+1 and FS.db.nameplates.enabled)
assert(not addons.Plater and not addons.Platynator and not addons.Kui_Nameplates and not addons.Kui_Nameplates_Core)
assert(C:Data().nameplates=='ForeverSuite'); restore()

-- TEST: Choosing later combat and unsupported arrow APIs do not change addon flags or navigation
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
C:Show('waypoints',true); C.window.later:Click()
assert(C.snoozed.waypoints and not C:Data().waypoints and not rxp.settings.profile.disableArrow and #changed==0)
TEST.combat=true; assert(not C:ApplyWaypoints('Zygor',true) and not C:ApplyNameplates('Plater'))
assert(FS.db.map.navigation and #changed==0); TEST.combat=false
local profile=tom.db.profile; tom.db.profile=nil
assert(not C:ApplyWaypoints('TomTom',true)); assert(not C:Data().waypoints and not rxp.settings.profile.disableArrow)
tom.db.profile=profile; restore()

-- TEST: Required nameplate frameworks do not cause repeated conflict prompts
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
addons.TidyPlates=true; addons.ThreatPlates=true
local deps=C_AddOns.GetAddOnDependencies
C_AddOns.GetAddOnDependencies=function(name) if name=='ThreatPlates' then return 'TidyPlates' else return deps(name) end end
assert(C:ApplyNameplates('ThreatPlates'))
assert(addons.ThreatPlates and addons.TidyPlates and not addons.Plater and not FS.db.nameplates.enabled)
assert(not C:NeedsChoice('nameplates')); restore()

-- TEST: Failed third-party arrow updates roll back the earlier provider flags
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
local original=z.Pointer.UpdateArrowVisibility
z.Pointer.UpdateArrowVisibility=function() error('Simulated arrow API failure') end
assert(not C:ApplyWaypoints('TomTom',true))
assert(not rxp.settings.profile.disableArrow and z.db.profile.arrowshow and tom.db.profile.arrow.enable)
assert(FS.db.map.navigation and not C:Data().waypoints)
z.Pointer.UpdateArrowVisibility=original; restore()

-- TEST: Failed addon enablement restores prior flags without saving a new provider
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
local original=C_AddOns.DisableAddOn
C_AddOns.DisableAddOn=function(name,character) if name=='Platynator' then error('Simulated client failure') end; original(name,character) end
assert(not C:ApplyNameplates('Plater'))
assert(addons.Plater and addons.Platynator and addons.Kui_Nameplates and addons.Kui_Nameplates_Core)
assert(FS.db.nameplates.enabled and not C:Data().nameplates); restore()

-- TEST: Addon-choice window fits maximum text size inside small viewports
local FS,C,addons,rxp,z,tom,changed,restore=SystemsFixture()
local width,height=UIParent:GetWidth(),UIParent:GetHeight(); UIParent:SetSize(800,600)
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply()
C:Show('nameplates'); local f=C.window
assert(f:GetWidth()*f:GetScale()<=776.01 and f:GetHeight()*f:GetScale()<=576.01)
for i=2,#C:Candidates('nameplates') do assert(-f.rows[i].point[3]>=-f.rows[i-1].point[3]+f.rows[i-1]:GetHeight()) end
assert(-f.apply.point[3]+f.apply:GetHeight()<=f:GetHeight())
UIParent:SetSize(width,height); restore(); FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.Typography:Apply()

-- TEST: Sell item sells unmarked ordinary equipment without marking it as junk or selling other stacks
ResetTest(); local FS=ForeverSuite; local V=FS.modules.Vendor; local B=FS.modules.Bags
TEST.data[401]={quality=2,price=20,classID=4}; TEST.data[402]={quality=0,price=1}
AddItem(1,401,1); AddItem(2,402,1); V:OpenMerchant(); B:ShowWindow(); B.selected=V:ReadItem(0,1); B:Refresh()
assert(not V:AvailableSale(B.selected) and B.window.detail:GetText():find('No junk marking needed',1,true))
B.window.sell:Click(); Drain()
assert(not TEST.bags[0][1] and TEST.bags[0][2] and not V:Settings().rules[401])
local sales=0; for _,a in ipairs(TEST.actions) do if a.kind=='sale' then sales=sales+1; assert(a.id==401) end end
assert(sales==1 and not V.busy)

-- TEST: Explicit unmarked sales split reserves and preserve Never Sell and rare protections
ResetTest(); local FS=ForeverSuite; local V=FS.modules.Vendor
TEST.data[403]={quality=1,price=10}; AddItem(1,403,10); V:SetRule(403,false,3,0); V:OpenMerchant()
local allowed=assert(V:AvailableSale(V:ReadItem(0,1),true)); assert(allowed.sellCount==7)
V:StartSelling(allowed); Drain(); local total=0
for _,item in pairs(TEST.bags[0]) do total=total+item.stackCount end
assert(total==3 and not V:Settings().rules[403].junk)
V:KeepItem(403); assert(not V:AvailableSale(V:ReadItem(0,1),true))
TEST.data[404]={quality=3,price=50}; AddItem(2,404,1); assert(not V:AvailableSale(V:ReadItem(0,2),true))

-- TEST: Invalid explicit sales never fall through to a different junk item
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[405]={quality=1,price=10}; TEST.data[406]={quality=0,price=1}
AddItem(1,405,1); AddItem(2,406,1); V:OpenMerchant(); local selected=V:ReadItem(0,1)
AddItem(1,405,1); V:StartSelling(selected); Drain()
for _,a in ipairs(TEST.actions) do assert(a.kind~='sale') end
assert(TEST.bags[0][1] and TEST.bags[0][2])

-- TEST: Protection changes after manual splitting abort and item options show blocked reasons
ResetTest(); local FS=ForeverSuite; local V=FS.modules.Vendor; local B=FS.modules.Bags
TEST.data[407]={quality=1,price=10}; AddItem(1,407,10); V:SetRule(407,false,3,0); V:OpenMerchant()
V:StartSelling(assert(V:AvailableSale(V:ReadItem(0,1),true))); V:KeepItem(407); Drain()
for _,a in ipairs(TEST.actions) do assert(a.kind~='sale') end
B:ShowWindow(); B.selected=V:ReadItem(0,1); B:Refresh(); B.window.sell:Click()
assert(B.window.detail:GetText():find('Always Keep',1,true))

-- TEST: Appearance slot atlas icons and checkbox indicators remain visible with unchanged native actions
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows
local f=CreateFrame('Frame',nil,UIParent); local b=CreateFrame('Button',nil,f); b.slot='HEADSLOT'
b.normalRegion=b:CreateTexture(); b.normalRegion:SetTexture(123456); b.normalRegion.GetAtlas=function() return 'transmog-nav-slot-head' end
local calls=0; local click=function() calls=calls+1 end; b:SetScript('OnClick',click)
N:Tree(f,true,f); assert(b.normalRegion:GetAlpha()==1 and b:GetScript('OnClick')==click)
b:Click(); assert(calls==1)
local check=CreateFrame('CheckButton',nil,f); check.checkedRegion=check:CreateTexture(); check.GetCheckedTexture=function(self) return self.checkedRegion end
N:Tree(f,true,f); assert(check.checkedRegion:GetAlpha()==1)
N:Tree(f,false,f); assert(b.normalRegion:GetAlpha()==1 and not N.controls[b].plate:IsShown())
f:Hide()

-- TEST: Mount info remains unframed collection side tabs are styled and model geometry stays unchanged
ResetTest(); local FS=ForeverSuite; local N=FS.NativeWindows; local old=MountJournal
local root=CreateFrame('Frame',nil,UIParent); root.TabContainer=CreateFrame('Frame',nil,root); root.TabContainer.Tabs={}
local tab=CreateFrame('Frame',nil,root.TabContainer); root.TabContainer.Tabs[1]=tab
tab.HasScript=function(_,script) return script~='PostClick' end
tab.Icon=tab:CreateTexture(); tab.Icon:SetTexture(789); tab.Background=tab:CreateTexture(); tab.Background:SetTexture('gold-tab-art')
local mouse=function() TEST.collectionMouse=true end; tab:SetScript('OnMouseUp',mouse)
MountJournal=CreateFrame('Frame',nil,root); MountJournal.MountDisplay=CreateFrame('Frame',nil,MountJournal)
local display=MountJournal.MountDisplay; display.InfoButton=CreateFrame('Button',nil,display)
display.InfoButton.Icon=display.InfoButton:CreateTexture(); display.InfoButton.Icon:SetTexture(987)
display.ModelScene=CreateFrame('ModelScene',nil,display); local model=display.ModelScene; model:SetSize(500,600); model:SetPoint('CENTER',root,'CENTER',12,-45)
model.TogglePlayer=CreateFrame('CheckButton',nil,model)
local point={model:GetPoint()}; N:Collections(root,true); N:Tree(root,true,root); N:Collections(root,true)
assert(not N.controls[display.InfoButton] or not N.controls[display.InfoButton].plate:IsShown())
assert(N.controls[tab].plate:IsShown() and tab.Icon:GetAlpha()==1 and tab.Background:GetAlpha()==0)
assert(tab:GetScript('OnMouseUp')==mouse and not tab:GetScript('PostClick') and N.controls[model.TogglePlayer].plate:IsShown())
local current={model:GetPoint()}; assert(current[4]==point[4] and current[5]==point[5] and model:GetWidth()==500 and model:GetHeight()==600)
N:Collections(root,false); N:Tree(root,false,root); assert(tab.Background:GetAlpha()==1 and not N.controls[tab].plate:IsShown())
root:Hide(); MountJournal=old

-- TEST: Modules iterate in a stable registration order that covers every registered module
local FS=ForeverSuite; local first,count={},0
for name,module in FS:EachModule() do first[#first+1]=name; assert(FS.modules[name]==module) end
for _ in pairs(FS.modules) do count=count+1 end
assert(#first==count and #FS.moduleOrder==count)
local seen={}; for i,name in ipairs(first) do assert(not seen[name],name); seen[name]=true end
local second={}; for name in FS:EachModule() do second[#second+1]=name end
for i=1,#first do assert(first[i]==second[i]) end

-- TEST: Every module keeps its enabled state under its own settings key, including Bags, Vendor and Gear
ResetTest(); local FS=ForeverSuite; FS:ShowConfig()
local expected={Bags='bags',Vendor='vendor',Gear='gear',UnitFrames='unitFrames',ActionBars='actionBars',Nameplates='nameplates',Character='character'}
for name,key in pairs(expected) do assert(FS.modules[name].key==key,name) end
for _,name in ipairs({'Bags','Vendor','Gear'}) do
    local key=expected[name]
    FS:SetModuleEnabled(name,false); assert(FS.db[key].enabled==false and not FS:IsModuleEnabled(name),name)
    FS:SetModuleEnabled(name,true); assert(FS.db[key].enabled==true and FS:IsModuleEnabled(name),name)
end
for name,module in FS:EachModule() do
    local data=module.key and FS.db[module.key]
    if data then
        local saved=data.enabled
        data.enabled=false; assert(FS:IsModuleEnabled(name)==false,name)
        data.enabled=true; assert(FS:IsModuleEnabled(name)==true,name)
        data.enabled=saved
    end
end
local shared,old=FS.db.modules,FS.db.modules.Profiles
shared.Profiles=false; assert(FS:IsModuleEnabled('Profiles')==false)
shared.Profiles=nil; assert(FS:IsModuleEnabled('Profiles')==true)
shared.Profiles=old

-- TEST: Settings are normalized exactly once per module when the database loads
local FS=ForeverSuite; local calls,originals={},{}
for name,module in FS:EachModule() do
    if module.key and module.NormalizeSettings then
        local original=module.NormalizeSettings; originals[name]=original
        module.NormalizeSettings=function(self,...) calls[name]=(calls[name] or 0)+1; return original(self,...) end
    end
end
FS:InitializeDatabase()
for name,original in pairs(originals) do FS.modules[name].NormalizeSettings=original end
assert(calls.Bags==1 and calls.Vendor==1 and calls.Gear==1)
for name,count in pairs(calls) do assert(count==1,name) end

-- TEST: Saved-data migrations run once in order, restore data on failure and leave newer data untouched
local FS=ForeverSuite
assert(FS.schemaVersion==3 and FS.db.schemaVersion==3 and next(FS.migrations)==nil and FS.defaults.schemaVersion==3)
local order={}
FS:RegisterMigration(4,'first',function(d) order[#order+1]=4; d.added=1 end)
FS:RegisterMigration(5,'second',function(d) order[#order+1]=5; d.added=d.added+1 end)
assert(not pcall(FS.RegisterMigration,FS,3,'baseline',function() end))
assert(not pcall(FS.RegisterMigration,FS,4,'duplicate',function() end))
assert(not pcall(FS.RegisterMigration,FS,6,'not a function'))
local data={schemaVersion=3,profiles={current='Main',saved={},backups={}},keep={a=1}}
local ok,ran=FS:MigrateData(data,5)
assert(ok==true and #ran==2 and data.schemaVersion==5 and data.added==2 and order[1]==4 and order[2]==5)
local backup=data.profiles.backups[1]
assert(backup.name=='Main' and backup.data.schemaVersion==3 and backup.data.added==nil and backup.data.keep.a==1 and backup.data.profiles==nil)
order={}; ok,ran=FS:MigrateData(data,5)
assert(ok==true and #ran==0 and #order==0 and #data.profiles.backups==1)
local legacy={keep=1}; FS:MigrateData(legacy,4); assert(legacy.schemaVersion==4 and legacy.added==1)
local gap={schemaVersion=4,added=1}; assert(FS:MigrateData(gap,7)==true and gap.schemaVersion==7 and gap.added==2)
FS.migrations[5].run=function(d) d.added=99; error('boom') end
local broken={schemaVersion=3,keep={a=1}}
local failed,info=FS:MigrateData(broken,5)
assert(failed==false and info.version==5 and info.name=='second' and info.message:find('boom',1,true))
assert(broken.schemaVersion==3 and broken.added==nil and broken.keep.a==1)
local newer={schemaVersion=9,keep=1}; local result,stored=FS:MigrateData(newer,5)
assert(result=='newer' and stored==9 and newer.schemaVersion==9 and newer.added==nil)
local P=FS.modules.Profiles; FS.schemaVersion=5
local sections,message=P:ReviewSections({schemaVersion=9,gear={}},'same')
assert(sections==nil and message:find('newer ForeverSuite',1,true))
FS.migrations[5].run=function() error('boom') end
sections,message=P:ReviewSections({schemaVersion=3,gear={}},'same')
assert(sections==nil and message:find('could not be upgraded',1,true))
FS.schemaVersion=3
for key in pairs(FS.migrations) do FS.migrations[key]=nil end

-- TEST: Loading the database upgrades older saved data, keeps a backup and reports a failed upgrade
local FS=ForeverSuite
local count=#(ForeverSuiteDB.profiles.backups or {}); local errorsBefore=#(FS.runtimeErrors or {})
FS.schemaVersion=4; FS:RegisterMigration(4,'probe',function(d) d.probe=true end)
ForeverSuiteDB.schemaVersion=3; FS:InitializeDatabase()
assert(FS.db.schemaVersion==4 and FS.db.probe==true and #FS.db.profiles.backups==count+1)
assert(FS.db.profiles.backups[1].data.schemaVersion==3 and FS.db.profiles.backups[1].data.probe==nil)
FS:InitializeDatabase(); assert(#FS.db.profiles.backups==count+1)
FS.db.probe=nil; table.remove(FS.db.profiles.backups,1)
FS.migrations[4].run=function(d) d.probe=true; error('failed probe') end
FS.db.schemaVersion=3; FS:InitializeDatabase()
assert(FS.db.schemaVersion==3 and FS.db.probe==nil and FS.migrationFailure.version==4 and #FS.db.profiles.backups==count)
assert(#FS.runtimeErrors==errorsBefore+1 and FS.runtimeErrors[#FS.runtimeErrors]:find('failed probe',1,true))
ForeverSuiteDB.schemaVersion=9; FS:InitializeDatabase(); assert(FS.db.schemaVersion==9 and FS.newerData==9)
FS.migrations[4]=nil; FS.schemaVersion=3; ForeverSuiteDB.schemaVersion=3; FS.migrationFailure=nil; FS.newerData=nil
table.remove(FS.runtimeErrors); if #FS.runtimeErrors==0 then FS.runtimeErrors=nil end
FS:InitializeDatabase(); assert(FS.db.schemaVersion==3 and #FS.db.profiles.backups==count)

-- TEST: A separate saved table registers its own migration store with its own version and backup hook
local FS=ForeverSuite
assert(FS.migrationStores.db and FS.migrations==FS.migrationStores.db.migrations and next(FS.migrations)==nil)
local owner,calls={schemaVersion=2},{}
local migrations=FS:RegisterMigrationStore('probeStore',owner,'schemaVersion',1,'Probe data',function(data,before,from,target)
    calls[#calls+1]={from=from,target=target,old=before.value,new=data.value}
end)
assert(not pcall(FS.RegisterMigrationStore,FS,'probeStore',owner,'schemaVersion',1))
assert(not pcall(FS.RegisterMigration,FS,1,'baseline',function() end,'probeStore'))
assert(not pcall(FS.RegisterMigration,FS,2,'unknown store',function() end,'missingStore'))
FS:RegisterMigration(2,'double',function(d) d.value=d.value*2 end,'probeStore')
assert(next(FS.migrations)==nil and migrations[2].name=='double')
local data={schemaVersion=1,value=21}
local ok,ran=FS:MigrateData(data,nil,'probeStore')
assert(ok==true and ran[1]==2 and data.schemaVersion==2 and data.value==42)
assert(#calls==1 and calls[1].from==1 and calls[1].target==2 and calls[1].old==21 and calls[1].new==42)
local again,none=FS:MigrateData(data,nil,'probeStore'); assert(again==true and #none==0 and #calls==1)
migrations[2].run=function(d) d.value=0; error('probe failure') end
local broken={schemaVersion=1,value=21}; local result,info=FS:MigrateData(broken,nil,'probeStore')
assert(result==false and info.store=='probeStore' and info.label=='Probe data' and info.version==2)
assert(broken.value==21 and broken.schemaVersion==1 and #calls==1)
FS:ReportMigrationFailure(info); assert(FS.runtimeErrors[#FS.runtimeErrors]:find('Probe data upgrade to version 2',1,true))
table.remove(FS.runtimeErrors); if #FS.runtimeErrors==0 then FS.runtimeErrors=nil end; FS.migrationFailure=nil
local newer={schemaVersion=5}; assert(FS:MigrateData(newer,nil,'probeStore')=='newer' and newer.schemaVersion==5)
FS.migrationStores.probeStore=nil
assert(FS.migrationStores.probeStore==nil and next(FS.migrations)==nil and FS.schemaVersion==3)

-- TEST: DataHub starts empty, imports the old character stock once and leaves it untouched
local FS,H=ForeverSuite,ForeverSuite.Hub
local savedHub,savedStock=ForeverSuiteHub,ForeverSuiteStock
ForeverSuiteHub=nil; ForeverSuiteStock=nil
H:Initialize()
assert(ForeverSuiteHub.schemaVersion==1 and next(ForeverSuiteHub.characters)==nil and H:Writable())
assert(ForeverSuiteHub.legacy.imported==true and ForeverSuiteHub.legacy.count==0)
ForeverSuiteHub=nil
ForeverSuiteStock={
    ['Crafter-Realm']={counts={[42]=7},bagTime=900,time=1000,professions={items={{name='Mining',skill=40,maximum=75}},time=950},gear={items={},level=22,lowest=60,time=980}},
    ['Alt-Azjol-Nerub']={time=500},
    Broken='text',[5]={time=1},
}
H:Initialize()
local chars=ForeverSuiteHub.characters
local crafter=chars['Crafter-Realm']
assert(crafter.name=='Crafter' and crafter.realm=='Realm' and crafter.time==1000)
assert(crafter.bags.counts[42]==7 and crafter.bags.time==900 and crafter.professions.time==950 and crafter.gear.level==22)
assert(chars['Alt-Azjol-Nerub'].name=='Alt' and chars['Alt-Azjol-Nerub'].realm=='Azjol-Nerub' and chars['Alt-Azjol-Nerub'].bags==nil)
assert(chars.Broken==nil and chars[5]==nil and ForeverSuiteHub.legacy.count==2)
crafter.bags.counts[42]=99
assert(ForeverSuiteStock['Crafter-Realm'].counts[42]==7 and ForeverSuiteStock['Crafter-Realm'].bagTime==900)
ForeverSuiteStock['New-Realm']={time=5}; H:Initialize()
assert(chars['New-Realm']==nil and ForeverSuiteHub.legacy.count==2 and ForeverSuiteHub.schemaVersion==1)
ForeverSuiteHub=nil; ForeverSuiteStock={['Old-Realm']={counts={[1]=1},time=300}}; H:Initialize()
assert(ForeverSuiteHub.characters['Old-Realm'].bags.time==300)
ForeverSuiteHub,ForeverSuiteStock,H.locked=savedHub,savedStock,nil

-- TEST: DataHub repairs damaged saved data, holds back newer data and keeps a backup when it upgrades
local FS,H=ForeverSuite,ForeverSuite.Hub
local savedHub,savedStock,savedErrors=ForeverSuiteHub,ForeverSuiteStock,FS.runtimeErrors
ForeverSuiteStock=nil
ForeverSuiteHub='damaged'; H:Initialize()
assert(type(ForeverSuiteHub)=='table' and ForeverSuiteHub.schemaVersion==1 and H:Writable())
ForeverSuiteHub={schemaVersion=1,characters='damaged',legacy={imported=true}}; H:Initialize()
assert(type(ForeverSuiteHub.characters)=='table')
ForeverSuiteHub={characters={['A-B']={time=1}}}; H:Initialize()
assert(ForeverSuiteHub.schemaVersion==1 and ForeverSuiteHub.characters['A-B'].time==1)
ForeverSuiteHub={schemaVersion=9,characters={['A-B']={time=1}}}; ForeverSuiteStock={['C-D']={time=2}}
H:Initialize()
assert(H:Writable()==false and ForeverSuiteHub.schemaVersion==9 and ForeverSuiteHub.characters['C-D']==nil and ForeverSuiteHub.legacy==nil)
assert(FS.Extensions:RecordStock()==false and ForeverSuiteHub.characters['A-B'].time==1)
ForeverSuiteStock=nil
FS.runtimeErrors=nil
H.schemaVersion=2; FS:RegisterMigration(2,'probe',function(d) d.probe=true; error('hub probe') end,'hub')
ForeverSuiteHub={schemaVersion=1,characters={['A-B']={time=1}}}; H:Initialize()
assert(H:Writable()==false and ForeverSuiteHub.schemaVersion==1 and ForeverSuiteHub.probe==nil and ForeverSuiteHub.characters['A-B'].time==1)
assert(FS.migrationFailure.store=='hub' and #FS.runtimeErrors==1 and FS.runtimeErrors[1]:find('Character data upgrade to version 2',1,true))
FS.migrationFailure=nil
FS.migrationStores.hub.migrations[2].run=function(d) d.upgraded=true end
ForeverSuiteHub={schemaVersion=1,characters={['A-B']={time=1}}}; H:Initialize()
assert(H:Writable() and ForeverSuiteHub.schemaVersion==2 and ForeverSuiteHub.upgraded==true)
assert(ForeverSuiteHub.backup.from==1 and ForeverSuiteHub.backup.target==2 and ForeverSuiteHub.backup.data.schemaVersion==1 and ForeverSuiteHub.backup.data.upgraded==nil)
H.schemaVersion=3; FS:RegisterMigration(3,'again',function(d) d.again=true end,'hub')
H:Initialize()
assert(ForeverSuiteHub.schemaVersion==3 and ForeverSuiteHub.backup.from==2 and ForeverSuiteHub.backup.data.backup==nil)
FS.migrationStores.hub.migrations[2]=nil; FS.migrationStores.hub.migrations[3]=nil
H.schemaVersion=1; H.locked=nil; FS.runtimeErrors=savedErrors
ForeverSuiteHub,ForeverSuiteStock=savedHub,savedStock
assert(next(FS.migrationStores.hub.migrations)==nil and next(FS.migrations)==nil)

-- TEST: DataHub records level, class, faction and last seen without counting as a character-stock record
local FS,H=ForeverSuite,ForeverSuite.Hub
local oldHub,oldName,oldRealm,oldLevel,oldClass,oldFaction,oldTime=ForeverSuiteHub,UnitName,GetNormalizedRealmName,UnitLevel,UnitClass,UnitFactionGroup,time
ForeverSuiteHub={characters={}}
local stamp=1000
UnitName=function() return 'Mage' end; GetNormalizedRealmName=function() return 'Realm' end
UnitLevel=function() return 12 end; UnitClass=function() return 'Mage','MAGE' end; UnitFactionGroup=function() return 'Alliance','Alliance' end
time=function() return stamp end
assert(H:RecordIdentity()==true)
local record=H:Characters()['Mage-Realm']
assert(record.name=='Mage' and record.realm=='Realm' and record.level==12 and record.class=='MAGE' and record.faction=='Alliance' and record.lastSeen==1000)
assert(record.time==nil and H:HasRecords()==false)
record.bags={counts={[1]=2},time=500}; record.time=500
stamp=2000; UnitLevel=function() return 13 end
assert(H:RecordIdentity()==true and record.level==13 and record.lastSeen==2000 and record.time==500 and record.bags.counts[1]==2 and H:HasRecords()==true)
assert(H:RecordIdentity(14)==true and record.level==14)
assert(H:RecordIdentity(3)==true and record.level==13)
UnitLevel=function() return nil end; UnitClass=function() return 'Mage','mage' end; UnitFactionGroup=function() return '' end
assert(H:RecordIdentity()==true and record.level==13 and record.class=='MAGE' and record.faction=='Alliance')
UnitLevel=function() return 0 end; assert(H:RecordIdentity()==true and record.level==13)
UnitName=function() return nil end; assert(H:RecordIdentity()==false)
UnitName=function() return 'Mage' end; H.locked=true; stamp=3000
assert(H:RecordIdentity()==false and record.lastSeen==2000)
H.locked=nil
ForeverSuiteHub,UnitName,GetNormalizedRealmName,UnitLevel,UnitClass,UnitFactionGroup,time=oldHub,oldName,oldRealm,oldLevel,oldClass,oldFaction,oldTime

-- TEST: Newer saved settings remain untouched through normalization and logout profile persistence
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles
local saved=ForeverSuiteDB
local future={schemaVersion=99,language='future-language',bags={uiVersion=99,showEmpty=true},marker={keep=7}}
ForeverSuiteDB=future; FS:InitializeDatabase()
assert(FS.databaseReadOnly and FS.newerData==99 and FS.db~=future and FS.db.bags~=future.bags)
assert(future.setup==nil and future.profiles==nil and future.bags.uiVersion==99 and future.bags.showEmpty==true and future.language=='future-language')
FS.db.marker.keep=8; P:PersistCurrent()
assert(future.marker.keep==7 and future.profiles==nil and not P:Save('Do not persist'))
ForeverSuiteDB=saved; FS:InitializeDatabase(); assert(not FS.databaseReadOnly and not FS.newerData)

-- TEST: Failed database upgrades preserve raw saved settings while the session uses a temporary copy
ResetTest(); local FS=ForeverSuite
local saved,errorsBefore=ForeverSuiteDB,#(FS.runtimeErrors or {})
local raw={schemaVersion=3,language='original',bags={uiVersion=77},marker={keep=7}}
FS.schemaVersion=4
FS:RegisterMigration(4,'release rollback probe',function(data) data.marker.keep=99; data.added=true; error('rollback probe') end)
ForeverSuiteDB=raw; FS:InitializeDatabase()
assert(FS.databaseReadOnly and FS.db~=raw and raw.schemaVersion==3 and raw.marker.keep==7 and raw.added==nil)
assert(raw.setup==nil and raw.language=='original' and raw.bags.uiVersion==77)
FS.db.marker.keep=8; FS.modules.Profiles:PersistCurrent(); assert(raw.marker.keep==7 and raw.profiles==nil)
FS.migrations[4]=nil; FS.schemaVersion=3; FS.migrationFailure=nil
while #(FS.runtimeErrors or {})>errorsBefore do table.remove(FS.runtimeErrors) end
ForeverSuiteDB=saved; FS:InitializeDatabase(); assert(not FS.databaseReadOnly)

-- TEST: Direct profile loading rejects newer or failed migrations before replacing the active settings
ResetTest(); local FS=ForeverSuite; local P=FS.modules.Profiles
local active=FS.db; local current=active.profiles.current; local saved=ForeverSuiteDB
active.profiles.saved.Future={schemaVersion=99,gear={enabled=false}}
assert(P:Load('Future')==false and FS.db==active and ForeverSuiteDB==saved and active.profiles.current==current)
FS.schemaVersion=4; local errorsBefore=#(FS.runtimeErrors or {})
FS:RegisterMigration(4,'profile failure probe',function(data) data.changed=true; error('profile probe') end)
active.profiles.saved.Broken={schemaVersion=3,gear={enabled=false}}
assert(P:Load('Broken')==false and FS.db==active and ForeverSuiteDB==saved and active.profiles.current==current)
assert(active.profiles.saved.Broken.changed==nil and active.profiles.saved.Broken.schemaVersion==3)
local runs=0; FS.migrations[4].run=function(data) runs=runs+1; data.upgraded=true end
assert(P:Load('Broken')==true and FS.db.schemaVersion==4 and FS.db.upgraded and runs==1)
FS.schemaVersion=3; FS.migrations[4]=nil; FS.migrationFailure=nil
while #(FS.runtimeErrors or {})>errorsBefore do table.remove(FS.runtimeErrors) end
ForeverSuiteDB=saved; saved.profiles.saved.Future=nil; saved.profiles.saved.Broken=nil; saved.profiles.current=current
FS:InitializeDatabase()

-- TEST: Read-only DataHub records cannot be repaired trimmed or deleted through Character stock
ResetTest(); local FS=ForeverSuite; local H=FS.Hub; local W=FS.modules.Workbench
local saved=ForeverSuiteHub
ForeverSuiteHub={schemaVersion=99,characters='future-format'}; H:Initialize()
assert(H.locked and next(H:Characters())==nil and ForeverSuiteHub.characters=='future-format')
H:Trim(); assert(ForeverSuiteHub.characters=='future-format' and H:RemoveCharacter('A-Realm')==false)
ForeverSuiteHub={schemaVersion=99,characters={['A-Realm']={time=1}}}; H:Initialize()
W:Choose('Character stock'); W.selected={id='A-Realm'}; W:Perform(3,'')
assert(ForeverSuiteHub.characters['A-Realm'].time==1 and W.status:find('read-only',1,true))
W.window:Hide(); ForeverSuiteHub=saved; H:Initialize()
H:Characters()['Delete-Realm']={time=1}; assert(H:RemoveCharacter('Delete-Realm') and H:Characters()['Delete-Realm']==nil)

-- TEST: DataHub keeps the most recently seen or recorded characters when it trims
local FS,H=ForeverSuite,ForeverSuite.Hub
local saved=ForeverSuiteHub; ForeverSuiteHub={characters={}}
local chars=H:Characters()
for i=1,50 do chars['Old'..i..'-Realm']={time=i} end
chars['Seen-Realm']={lastSeen=1000}; chars['Recorded-Realm']={time=2000,lastSeen=10}; chars['Stale-Realm']={}
H:Trim()
local count=0; for _ in pairs(chars) do count=count+1 end
assert(count==50 and chars['Seen-Realm'] and chars['Recorded-Realm'] and chars['Old3-Realm'])
assert(chars['Stale-Realm']==nil and chars['Old1-Realm']==nil and chars['Old2-Realm']==nil)
H:Trim(); count=0; for _ in pairs(chars) do count=count+1 end; assert(count==50)
ForeverSuiteHub=saved

-- TEST: Login, level-up and logout refresh the current character and a failing client call never breaks them
local FS,H=ForeverSuite,ForeverSuite.Hub
local oldHub,oldName,oldRealm,oldLevel,oldClass,oldFaction,oldTime=ForeverSuiteHub,UnitName,GetNormalizedRealmName,UnitLevel,UnitClass,UnitFactionGroup,time
ForeverSuiteHub={characters={}}
local stamp=1000
UnitName=function() return 'Mage' end; GetNormalizedRealmName=function() return 'Realm' end
UnitLevel=function() return 12 end; UnitClass=function() return 'Mage','MAGE' end; UnitFactionGroup=function() return 'Horde','Horde' end
time=function() return stamp end
local function fire(event,...) FS.events.scripts.OnEvent(FS.events,event,...) end
fire('PLAYER_ENTERING_WORLD')
local record=H:Characters()['Mage-Realm']
assert(record.level==12 and record.class=='MAGE' and record.faction=='Horde' and record.lastSeen==1000 and record.time==nil)
stamp=2000; fire('PLAYER_LEVEL_UP',13)
assert(record.level==13 and record.lastSeen==2000)
stamp=3000; fire('PLAYER_LOGOUT')
assert(record.lastSeen==3000 and FS.Hub:Writable())
UnitClass=function() error('client call failed') end; stamp=4000
fire('PLAYER_ENTERING_WORLD'); fire('PLAYER_LEVEL_UP',14)
assert(record.lastSeen==4000 and record.class=='MAGE' and record.level==14)
H.locked=true; stamp=5000; fire('PLAYER_ENTERING_WORLD'); assert(record.lastSeen==4000); H.locked=nil
ForeverSuiteHub,UnitName,GetNormalizedRealmName,UnitLevel,UnitClass,UnitFactionGroup,time=oldHub,oldName,oldRealm,oldLevel,oldClass,oldFaction,oldTime
