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
