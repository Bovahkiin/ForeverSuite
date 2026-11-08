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
I.window.choices[4]:Click(); assert(I.draft.preset=='Readable text' and FS.db.typography.global.size==old and I.window.preview.player.font[2]==18)
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
W:Choose('Favorites'); assert(#W.rows==1 and W.rows[1].id=='Loot:fast')

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

-- TEST: Disabled generic modules release update scripts and optional subscriptions and restore them on enable
local FS,E=ExtensionFixture(); local C=FS.modules.Chat; C:SettingsChanged()
if C.window then C.window:Hide() end
assert(not C.events:GetScript('OnUpdate'))
FS:SetModuleEnabled('Chat',false); assert(not C.events.events.UPDATE_CHAT_WINDOWS and C.events.events.PLAYER_REGEN_ENABLED)
FS:SetModuleEnabled('Chat',true); assert(C.events.events.UPDATE_CHAT_WINDOWS)
local S=FS.modules.Social; S:ShowWindow(); assert(S.events:GetScript('OnUpdate')); S.window:Hide(); assert(not S.events:GetScript('OnUpdate'))

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
local b=E:Form('Second',{{label='Name',value='B'}},function() return true end); assert(a==b and #b.edits==3 and not b.edits[2]:IsShown())
local t=E:TextDialog('Import','',false,function() return {},'Valid' end,function() return true end); t.preview:Click(); assert(t.candidate)
local other=E:TextDialog('Copy','Read only',true); assert(other==t and not t.candidate and not t.applyAction and not t.apply:IsShown())
t:Hide(); b:Hide()

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
local FS,E=ExtensionFixture(); FS:SettingAction(function() FS.db.gear.warn=false; FS:SettingAction(function() FS.db.loot.fast=true end) end); assert(#E.undo==1)
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
handle.GetCenter=function() return 699.5,399.5 end; FS.db.layout.snap=true; L:Save('GridTest',handle)
assert(FS.db.layout.frames.GridTest.x==32 and FS.db.layout.frames.GridTest.y==384.5)
UIParent:SetSize(800,600); L:UpdateGrid(); assert(#lines==count); L:UpdateGrid(); assert(#lines==count)
UIParent.GetCenter=center; UIParent:SetSize(w,h); L:UpdateGrid(); L.targets.GridTest=nil; L.overlay:Hide()

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
local configure=FS.ConfigureModule; local chosen; FS.ConfigureModule=function(self,n) chosen=n end
f.moduleSearch.scripts.OnEnterPressed(f.moduleSearch); assert(chosen=='Nameplates')
FS:SetModuleFilter('','All'); chosen=nil; f.moduleSearch.scripts.OnEnterPressed(f.moduleSearch); assert(chosen==nil)
FS.ConfigureModule=configure; FS:SetModuleFilter('loot','Disabled'); f.moduleSearch.scripts.OnEscapePressed(f.moduleSearch)
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
assert(searchY>=-f.profiles.point[3]+f.profiles:GetHeight())
assert(-f.cards.Bags.card.point[3]>=searchY+f.moduleSearch:GetHeight())
assert(f.moduleSearch:GetWidth()==460 and f.moduleFilterButton:GetWidth()==260 and f.moduleSearch:GetHeight()>=36)
FS:SetModuleFilter('no-result-zzzz','All'); assert(f:GetHeight()==height and f.emptyModules:IsShown())
FS:ClearModuleFilter(); FS.db.typography.global.size=0; FS.db.typography.global.scale=1; F:Apply(); FS:RefreshConfig()
