-- TEST: Loot feed fixture starts with empty bounded session state and known client formats
function LootFeedFixture()
    local FS=ForeverSuite; local F=FS.modules.LootFeed
    F:StopCapture(); if F.window then F.window:Hide() end
    ResetTest(); F.history={}; F.factions=nil; F.skillInfo=nil; F:SettingsChanged()
    -- This fixture owns its item-cache simulator; unrelated advisor fixtures
    -- can replace the public item API while exercising their own catalogs.
    C_Item.GetItemInfo=function(id)
        if type(id)=='string' then id=tonumber(id:match('item:(%d+)')) end
        local d=TEST.data[id]; if not d or d.pending then return end
        return d.name or ('Loot '..id),'item:'..id,d.quality or 0,1,1,'Type','Subtype',d.maxStack or 20,'',134400,d.price or 10,d.classID or 0,d.subclassID
    end
    C_Item.RequestLoadItemDataByID=function(id) TEST.requested=id end
    LOOT_ITEM_SELF='You receive loot: %s.'; LOOT_ITEM_SELF_MULTIPLE='You receive loot: %sx%d.'
    LOOT_ITEM_PUSHED_SELF='You receive item: %s.'; LOOT_ITEM_PUSHED_SELF_MULTIPLE='You receive item: %sx%d.'
    LOOT_ITEM_CREATED_SELF='You create: %s.'; LOOT_ITEM_CREATED_SELF_MULTIPLE='You create: %sx%d.'
    CURRENCY_GAINED='You receive currency: %s.'; CURRENCY_GAINED_MULTIPLE='You receive currency: %sx%d.'
    FACTION_STANDING_INCREASED='Reputation with %s increased by %d.'; SKILL_RANK_UP='Your skill in %s has increased to %d.'
    return FS,F
end
function FeedItem(id,count)
    TEST.data[id]={name='Loot '..id,quality=2,price=15}
    return 'You receive loot: |cff1eff00|Hitem:'..id..':0|h[Loot '..id..']|hx'..(count or 1)..'.'
end

-- TEST: Loot feed captures self drops and crafts without recording party loot or inventing quantity
local FS,F=LootFeedFixture()
F:Event('CHAT_MSG_LOOT',FeedItem(101,3))
assert(#F.entries==1 and F.entries[1].quantity==3 and F.entries[1].id==101 and #F.history==1)
F:Event('CHAT_MSG_LOOT','Someone receives loot: |Hitem:101|h[Loot 101]|hx5.')
assert(#F.entries==1 and F.entries[1].quantity==3)
F:Event('CHAT_MSG_LOOT','You create: |Hitem:102|h[Made item]|hx2.')
assert(#F.history==2 and F.entries[1].quantity==2)
FS.db.lootFeed.crafted=false
F:Event('CHAT_MSG_LOOT','You create: |Hitem:102|h[Made item]|hx2.')
assert(#F.history==2)
assert(not F:Parse('CHAT_MSG_LOOT','You receive loot: |Hitem:101|h[Loot]|hx0.'))
assert(not F:Parse('CHAT_MSG_LOOT','You receive loot: |Hitem:101|h[Loot]|hx999999999999999.'))

-- TEST: Loot feed matches localized positional item reputation and skill formats exactly
local FS,F=LootFeedFixture()
LOOT_ITEM_SELF_MULTIPLE='Ontvangen: %2$d keer %1$s.'
local e=F:Parse('CHAT_MSG_LOOT','Ontvangen: 1.200 keer |Hitem:101|h[Linnen]|h.')
assert(e and e.quantity==1200 and e.name=='Linnen')
FACTION_STANDING_INCREASED='%2$d reputatie bij %1$s.'
e=F:Parse('CHAT_MSG_COMBAT_FACTION_CHANGE','75 reputatie bij Orgrimmar.')
assert(e and e.name=='Orgrimmar' and e.quantity==75)
assert(not F:Parse('CHAT_MSG_COMBAT_FACTION_CHANGE','-75 reputatie bij Orgrimmar.'))
SKILL_RANK_UP='%1$s is nu %2$d.'
assert(F:Parse('CHAT_MSG_SKILL','Leatherworking is nu 54.').rank==54)

-- TEST: Loot feed merges exact item variants within a short window and keeps real repeated gains
local FS,F=LootFeedFixture()
F:Event('CHAT_MSG_LOOT',FeedItem(103,2)); F:Event('CHAT_MSG_LOOT',FeedItem(103,4))
assert(#F.entries==1 and F.entries[1].quantity==6 and #F.history==1)
F:Event('CHAT_MSG_LOOT','You receive loot: |Hitem:103:7|h[Different variant]|hx1.')
assert(#F.entries==2)
TEST.now=TEST.now+3; F:Event('CHAT_MSG_LOOT',FeedItem(103,1)); assert(#F.entries==3)

-- TEST: Loot feed idle work stops completely and the row pool stays bounded after repeated bursts
local FS,F=LootFeedFixture(); assert(not F.events:GetScript('OnUpdate'))
FS.db.lootFeed.visible=3; FS.db.lootFeed.merge=false; F:SettingsChanged()
for i=1,100 do F:Event('CHAT_MSG_LOOT',FeedItem(200+i,1)) end
assert(#F.entries==3 and #F.queue==40 and #F.history==43 and #F.pool<=7)
for i=1,18 do TEST.now=TEST.now+20; F:Animate(20) end
assert(#F.entries==0 and #F.queue==0 and not F.feed:IsShown() and not F.feed:GetScript('OnUpdate'))
for i=1,70 do F:Event('CHAT_MSG_LOOT',FeedItem(500+i,1)); F:Dismiss(F.entries[1]) end
assert(#F.history==60 and #F.pool<=7 and not F.feed:GetScript('OnUpdate'))
assert(not FS.db.lootFeed.history and not FS.db.lootFeed.queue)

-- TEST: Loot feed quality delays are bounded and unknown or failed items are not hidden from chat
local FS,F=LootFeedFixture(); FS.db.lootFeed.quality='Rare+'
local message=FeedItem(601,2); TEST.data[601].pending=true
assert(F:Eligible(F:Parse('CHAT_MSG_LOOT',message))==nil)
F:Event('CHAT_MSG_LOOT',message); assert(#F.pending==1 and #F.entries==0 and TEST.requested==601)
TEST.data[601].pending=nil; TEST.data[601].quality=3; F:Event('GET_ITEM_INFO_RECEIVED',601,true)
assert(#F.pending==0 and #F.entries==1 and F.entries[1].quantity==2)
F:Event('CHAT_MSG_LOOT',FeedItem(602,1)); assert(#F.history==1)
for i=1,25 do local msg=FeedItem(610+i,1); TEST.data[610+i].pending=true; F:Event('CHAT_MSG_LOOT',msg) end
assert(#F.pending==20)
TEST.now=TEST.now+6; F:Event('GET_ITEM_INFO_RECEIVED',611,false); assert(#F.pending==0)

-- TEST: Loot feed chat filters are side effect free across windows and preserve unknown disabled and overflow messages
local FS,F=LootFeedFixture(); local old=ChatFrameUtil; local installed,removed={},0
ChatFrameUtil={AddMessageEventFilter=function(event,fn) installed[event]=fn end,RemoveMessageEventFilter=function(event,fn) assert(installed[event]==fn); installed[event]=nil; removed=removed+1 end}
FS.db.lootFeed.hideChat=true; F:SettingsChanged()
local msg=FeedItem(701,2); local filter=installed.CHAT_MSG_LOOT; assert(type(filter)=='function')
assert(filter(nil,'CHAT_MSG_LOOT',msg) and #F.entries==0)
UIParent:Hide(); assert(not filter(nil,'CHAT_MSG_LOOT',msg)); UIParent:Show()
F:Event('CHAT_MSG_LOOT',msg)
assert(filter(ChatFrame1,'CHAT_MSG_LOOT',msg) and filter(ChatFrame2,'CHAT_MSG_LOOT',msg))
assert(#F.history==1 and F.entries[1].quantity==2)
assert(not filter(nil,'CHAT_MSG_LOOT','Someone receives loot: |Hitem:701|h[Test]|hx2.'))
FS.db.lootFeed.items=false; assert(not filter(nil,'CHAT_MSG_LOOT',msg)); FS.db.lootFeed.items=true
FS.db.lootFeed.quality='Epic+'; assert(not filter(nil,'CHAT_MSG_LOOT',msg)); FS.db.lootFeed.quality='All'
FS.db.lootFeed.merge=false
for i=1,60 do F:Event('CHAT_MSG_LOOT',FeedItem(710+i,1)) end
assert(not filter(nil,'CHAT_MSG_LOOT',FeedItem(999,1)))
FS.db.lootFeed.hideChat=false; F:SettingsChanged(); assert(removed==5 and not F.filterAdd)
assert(not filter(nil,'CHAT_MSG_LOOT',msg)); ChatFrameUtil=old

-- TEST: Loot feed currency caps and reputation progress use client values without duplicate currency events
local FS,F=LootFeedFixture(); local oldCurrency,oldRep=C_CurrencyInfo,C_Reputation
C_CurrencyInfo={GetCurrencyInfo=function(id) assert(id==42); return {name='Tokens',quantity=75,maxQuantity=100,iconFileID=133784,quantityEarnedThisWeek=12,maxWeeklyQuantity=50} end}
F:Event('CHAT_MSG_CURRENCY','You receive currency: |Hcurrency:42|h[Tokens]|hx5.')
assert(#F.history==1 and F.entries[1].quantity==5 and F.entries[1].progress==75 and F.entries[1].maximum==100)
F:Event('CURRENCY_DISPLAY_UPDATE',42,75,5); assert(#F.history==1 and F.entries[1].quantity==5)
C_Reputation={GetNumFactions=function() return 1 end,GetFactionDataByIndex=function() return {name='Orgrimmar',factionID=76,reaction=5,currentStanding=4200,currentReactionThreshold=3000,nextReactionThreshold=9000} end}
F:Event('CHAT_MSG_COMBAT_FACTION_CHANGE','Reputation with Orgrimmar increased by 75.')
assert(F.entries[1].kind=='reputation' and F.entries[1].progress==1200 and F.entries[1].maximum==6000)
F:Event('CHAT_MSG_COMBAT_FACTION_CHANGE','Reputation with Orgrimmar decreased by 75.'); assert(#F.history==2)
C_CurrencyInfo,C_Reputation=oldCurrency,oldRep

-- TEST: Loot feed profession ranks and money use localized reported gains without counting purchases
local FS,F=LootFeedFixture(); local oldCount,oldSkill=GetNumSkillLines,GetSkillLineInfo
GetNumSkillLines=function() return 1 end; GetSkillLineInfo=function() return 'Leatherworking',false,false,54,0,0,75 end
F:Event('CHAT_MSG_SKILL','Your skill in Leatherworking has increased to 54.')
assert(F.entries[1].rank==54 and F.entries[1].maximum==75)
F:Event('CHAT_MSG_SKILL','Your skill in Leatherworking has increased to 55.')
assert(#F.entries==1 and F.entries[1].rank==55)
F:Event('CHAT_MSG_MONEY','You loot 1 Gold, 2 Silver, 3 Copper.')
assert(F.entries[1].kind=='money' and F.entries[1].quantity==10203)
F:Event('CHAT_MSG_MONEY','You spent 1 Gold.'); assert(#F.history==2)
GetNumSkillLines,GetSkillLineInfo=oldCount,oldSkill

-- TEST: Loot feed uses labeled unit price providers and never multiplies an unknown listing price
local FS,F=LootFeedFixture(); local A=FS.modules.AuctionHouse; local oldAuctionator,oldTSM=Auctionator,TSM_API
F:Event('CHAT_MSG_LOOT',FeedItem(801,3)); local entry=F.entries[1]
A:Prices()[801]={kind='lowest listing',price=999,time=1}; FS.db.lootFeed.prices='ForeverSuite AH'
assert(F:ItemValue(entry)==nil)
A:Prices()[801]={kind='per item',price=100,time=1}
local value,provider=F:ItemValue(entry); assert(value==100 and provider=='AH')
FS.db.lootFeed.prices='Auctionator'; Auctionator={API={v1={GetAuctionPriceByItemID=function(caller,id) assert(caller=='ForeverSuite' and id==801); return 200 end}}}
value,provider=F:ItemValue(entry); assert(value==200 and provider=='Auctionator')
FS.db.lootFeed.prices='TSM market'; TSM_API={ToItemString=function() return 'i:801' end,GetCustomPriceValue=function(source,item) assert(source=='DBMarket' and item=='i:801'); return 300 end}
value,provider=F:ItemValue(entry); assert(value==300 and provider=='TSM market')
TSM_API.GetCustomPriceValue=function() error('Provider unavailable') end; assert(not F:ItemValue(entry))
FS.db.lootFeed.prices='None'; F:Context(entry,true); assert(not entry.price)
Auctionator,TSM_API=oldAuctionator,oldTSM

-- TEST: Loot feed owned counts update on bag events and its settings remain separate from loot history
local FS,F=LootFeedFixture(); local old=C_Item.GetItemCount; local total=12
C_Item.GetItemCount=function(id,bank) assert(id==901 and bank==false); return total end
F:Event('CHAT_MSG_LOOT',FeedItem(901,2)); assert(F.entries[1].owned==12)
total=15; F:Event('BAG_UPDATE_DELAYED'); assert(F.entries[1].owned==15 and #F.history==1)
local history=FS.db.loot.history; F:Clear(); assert(FS.db.loot.history==history and #F.history==1)
C_Item.GetItemCount=old

-- TEST: Loot feed pauses hovered entries and supports safe item clicks dismissal and combat disable
local FS,F=LootFeedFixture(); F:Event('CHAT_MSG_LOOT',FeedItem(902,1)); local entry=F.entries[1]; local row=entry.row
row.scripts.OnEnter(row); TEST.now=TEST.now+20; F:Animate(20); assert(row.entry==entry and F.hovered==row)
row.scripts.OnLeave(row); assert(entry.expires>TEST.now)
local old=SetItemRef; local clicked
SetItemRef=function(link) clicked=link end; row.scripts.OnClick(row,'LeftButton'); assert(clicked:find('item:902',1,true))
row.scripts.OnClick(row,'RightButton'); assert(#F.entries==0 and not F.feed:GetScript('OnUpdate')); SetItemRef=old
F:Event('CHAT_MSG_LOOT',FeedItem(903,1)); FS.db.lootFeed.showInCombat=false; TEST.combat=true; F:Event('PLAYER_REGEN_DISABLED')
assert(not F.feed:IsShown() and not F.feed:GetScript('OnUpdate'))
F:Event('CHAT_MSG_LOOT',FeedItem(904,1)); assert(#F.entries==0)
TEST.combat=false; F:Event('CHAT_MSG_LOOT',FeedItem(904,1)); assert(#F.entries==1)
FS:SetModuleEnabled('LootFeed',false); assert(not F.feed:IsShown() and not F.filterAdd)
FS:SetModuleEnabled('LootFeed',true)

-- TEST: Loot feed fits large text and small viewports without rewriting saved mover scale
local FS,F=LootFeedFixture(); local width,height=UIParent:GetWidth(),UIParent:GetHeight()
FS.db.lootFeed.visible=7; FS.db.lootFeed.textSize=17; F:Preview()
local textSize=FS.db.typography.global.size; FS.db.typography.global.size=24; FS.Typography:Apply()
assert(F.feed.header:GetHeight()>=36 and F.feed.header.settings:GetWidth()>=100)
FS.db.layout.frames.LootFeed={x=100,y=200,scale=1.4}
UIParent:SetSize(420,320); F:Event('DISPLAY_SIZE_CHANGED'); Drain()
assert(F.feed:GetWidth()*F.feed:GetScale()<=UIParent:GetWidth()-31)
assert(F.feed:GetHeight()*F.feed:GetScale()<=UIParent:GetHeight()-31)
assert(FS.db.layout.frames.LootFeed.scale==1.4 and #F.entries<=7)
UIParent:SetSize(width,height); FS.db.layout.frames.LootFeed=nil; FS.db.typography.global.size=textSize; FS.Typography:Apply(); F:LayoutFeed(); F:Clear()

-- TEST: Loot feed previews themes row reuse and optional Masque without recording samples as loot
local FS,F=LootFeedFixture(); local oldLib=LibStub; local add,remove=0,0
LibStub=function(name,silent) assert(name=='Masque' and silent); return {Group=function(_,addon,group)
    assert(addon=='ForeverSuite' and group=='Loot Feed'); return {
        AddButton=function(_,button,regions,kind,strict) assert(regions.Icon and kind=='Item' and strict); add=add+1 end,
        RemoveButton=function() remove=remove+1 end}
end} end
FS.db.lootFeed.masque=true; F:SettingsChanged(); F:Preview(); assert(#F.history==0 and F.previewing and add>0)
for _,theme in ipairs(FS.Themes.names) do FS.db.appearance.theme=theme; FS.Themes:Refresh(); assert(F.feed.header:IsShown()) end
FS.db.lootFeed.growth='Up'; F:LayoutFeed(); assert(F.feed.header.point[1]=='BOTTOMRIGHT')
local row=F.entries[1].row; local iconCount=#F.pool
F:Event('CHAT_MSG_LOOT',FeedItem(905,1)); assert(not F.previewing and #F.history==1 and #F.entries==1 and #F.pool==iconCount)
assert(F.entries[1].row.icon.texture==134400)
FS.db.lootFeed.masque=false; F:SkinIcons(); assert(remove>0)
F:Clear(); FS.db.appearance.theme='Legacy'; LibStub=oldLib; F.masqueGroup=nil

-- TEST: Vendor launcher avoids the native footer on both sides and falls back above when necessary
ResetTest(); local FS=ForeverSuite; local C=FS.Context
C:Discover(); local state=C.hosts[MerchantFrame]; assert(state and state.button)
local b=state.button; assert(b:GetParent()==UIParent and b:IsShown())
local oldScale,oldRect=MerchantFrame.GetEffectiveScale,MerchantFrame.GetRect
MerchantFrame.GetEffectiveScale=function() return .75 end
MerchantFrame.GetRect=function() return 30,100,338,400 end
state.update(); assert(b:GetScale()==.75 and b:GetFrameStrata()=='DIALOG')
assert(b.point[1]=='TOPLEFT' and b.point[2]==MerchantFrame and b.point[3]=='TOPRIGHT' and b.point[4]>0)
MerchantFrame.GetRect=function() return UIParent:GetWidth()/.75-360,100,338,400 end
state.update(); assert(b.point[1]=='TOPRIGHT' and b.point[3]=='TOPLEFT' and b.point[4]<0)
MerchantFrame.GetRect=function() return 4,100,(UIParent:GetWidth()-8)/.75,400 end
state.update(); assert(b.point[1]=='BOTTOMLEFT' and b.point[3]=='TOPLEFT' and b.point[5]>0)
b:Click(); assert(state.menu:IsShown()); MerchantFrame:Hide(); assert(not b:IsShown() and not state.menu:IsShown())
MerchantFrame:Show(); assert(b:IsShown())
MerchantFrame.GetEffectiveScale,MerchantFrame.GetRect=oldScale,oldRect; state.update()

-- TEST: Loot feed resumes after UI visibility changes and stops immediately on disabled combat state
local FS,F=LootFeedFixture(); F:Event('CHAT_MSG_LOOT',FeedItem(950,1))
F.feed:Hide(); assert(not F.feed:GetScript('OnUpdate'))
F.feed:Show(); assert(F.feed:GetScript('OnUpdate'))
TEST.now=TEST.now+30; F:Animate(30); assert(not F.feed:IsShown() and not F.feed:GetScript('OnUpdate'))
F:Event('CHAT_MSG_LOOT',FeedItem(951,1)); TEST.combat=true; FS:SetModuleEnabled('LootFeed',false)
F:Animate(.05); assert(#F.entries==0 and not F.feed:IsShown())
TEST.combat=false; F.events.scripts.OnEvent(F.events,'PLAYER_REGEN_ENABLED'); assert(not F.filterAdd)
FS:SetModuleEnabled('LootFeed',true)

-- TEST: Loot feed repeated receipts reuse every row and do not grow frame or saved-data state
local FS,F=LootFeedFixture(); local msg=FeedItem(970,1)
F:Event('CHAT_MSG_LOOT',msg); local frames=#TEST.frames
for i=1,5000 do F:Event('CHAT_MSG_LOOT',msg) end
assert(#TEST.frames==frames and #F.entries==1 and F.entries[1].quantity==5001 and #F.history==1)
assert(not FS.db.lootFeed.history and not FS.db.lootFeed.pending)
F:Clear(); assert(not F.feed:GetScript('OnUpdate'))

-- TEST: Loot feed stays visible while dragging or arranging frames and preserves the preferred scale
local FS,F=LootFeedFixture(); F:Event('CHAT_MSG_LOOT',FeedItem(980,1))
FS.db.layout.frames.LootFeed={x=0,y=400,scale=1.2}; local header=F.feed.header
header.scripts.OnDragStart(header); assert(F.dragging and F.feed.fsDirectDragging)
TEST.now=TEST.now+30; F:Animate(30); assert(#F.entries==1 and F.feed:IsShown())
header.scripts.OnDragStop(header); assert(not F.dragging and not F.feed.fsDirectDragging)
assert(FS.db.layout.frames.LootFeed.scale==1.2 and select(2,F.feed:GetPoint())~=F.feed)
FS.Layout.active=true; TEST.now=TEST.now+30; F:Animate(30); assert(#F.entries==1)
FS.Layout.active=false; F:Animate(.1); assert(#F.entries==0)
