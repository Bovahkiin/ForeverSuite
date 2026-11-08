"""Offline Lua 5.1 checks with a strict UI stub and asynchronous merchant simulator."""
from pathlib import Path
import os
import sys
import zipfile
package_dir = Path('work/python-packages').resolve()
sys.path.insert(0, str(package_dir))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    # GitHub runners install the pinned dependency with pip. Only local Windows
    # development needs the optional cached-wheel fallback.
    cache = Path(os.environ.get('LOCALAPPDATA', str(Path.home()/'.cache')))/'pip/cache'
    for candidate in cache.rglob('*.body'):
        if zipfile.is_zipfile(candidate):
            with zipfile.ZipFile(candidate) as wheel:
                if any(name.startswith('lupa/lua51') for name in wheel.namelist()):
                    wheel.extractall(package_dir)
                    break
    from lupa.lua51 import LuaRuntime

root = Path('.')
files = [line.strip() for line in (root/'ForeverSuite.toc').read_text().splitlines()
         if line.strip() and not line.startswith('#')]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
TEST = { timers = {}, frames = {}, now = 0, money = 1000000, bags = {}, data = {}, merchant = {}, buyback = {},
    actions = {}, delay = 0.25, guid = 0, repair = 0, guildMoney = 1000000, guildAllowance = 1000000 }
local function copy(t) local v = {}; for k,x in pairs(t) do v[k] = x end; return v end
function After(delay, action)
    table.insert(TEST.timers, {at = TEST.now + delay, action = action})
end
function Drain()
    local steps = 0
    while #TEST.timers > 0 do
        table.sort(TEST.timers, function(a,b) return a.at < b.at end)
        local timer = table.remove(TEST.timers, 1)
        TEST.now = timer.at
        timer.action()
        steps = steps + 1
        assert(steps < 1000, 'Timer loop')
    end
end
C_Timer = {After = After}
local M = {}
function M:SetAttribute(k,v) assert(not TEST.combat, 'Protected attributes cannot change in combat'); self.attributes[k]=v end
function M:GetAttribute(k) return self.attributes[k] end
function RegisterStateDriver(f,state,condition) f.stateDriver=condition end
function EnterCombat()
    TEST.combat=true
    for _,f in ipairs(TEST.frames) do if f.stateDriver and f:GetAttribute('_onstate-combat') then f:Hide() end end
end
function M:SetScript(k,v) self.scripts[k] = v end
function M:GetScript(k) return self.scripts[k] end
function M:HookScript(k, f)
    local old = self.scripts[k]
    self.scripts[k] = function(...) if old then old(...) end; f(...) end
end
function M:RegisterEvent(k) self.events[k] = true end
function M:UnregisterEvent(k) self.events[k] = nil end
function M:CreateFontString() return CreateFrame('FontString',nil,self) end
function M:CreateTexture() return CreateFrame('Texture',nil,self) end
function M:AddMaskTexture(mask) self.masks=self.masks or {}; self.masks[mask]=true end
function M:RemoveMaskTexture(mask) if self.masks then self.masks[mask]=nil end end
function M:CreateLine() return CreateFrame('Line',nil,self) end
function M:SetThickness(value) self.thickness=value end
function M:SetStartPoint(...) self.startPoint={...} end
function M:SetEndPoint(...) self.endPoint={...} end
function M:CreateAnimationGroup() return CreateFrame('AnimationGroup',nil,self) end
function M:CreateAnimation() return CreateFrame('Animation',nil,self) end
function M:Play() self.playing = true end
function M:Stop() self.playing = false end
function M:IsPlaying() return self.playing end
function M:SetSize(w,h) self.w,self.h = w,h end
function M:SetWidth(w) self.w = w end
function M:SetHeight(h) self.h = h end
function M:GetWidth() return self.w or 140 end
function M:GetHeight() return self.h or 140 end
function M:GetFrameLevel() return self.frameLevel or 1 end
function M:GetName() return self.name end
function M:GetScale() return self.frameScale or (type(self.scale)=="number" and self.scale) or 1 end
function M:GetAlpha() return self.alpha or 1 end
function M:SetAlpha(value) self.alpha=value end
function M:IsMouseEnabled() return self.mouse ~= false end
function M:EnableMouse(value) self.mouse=value end
function M:EnableKeyboard(value) self.keyboard=value end
function M:SetPropagateKeyboardInput(value) self.propagate=value end
function M:GetNumPoints() return self.point and 1 or 0 end
function M:GetPoint() if self.point then return unpack(self.point) end end
function M:SetStatusBarTexture(value) self.barTexture=value end
function M:GetStatusBarTexture() local t=CreateFrame('Texture'); t:SetTexture(self.barTexture); return t end
function M:GetTexture() return self.texture end
function M:SetStatusBarColor(...) self.barColor={...} end
function M:GetStatusBarColor() return unpack(self.barColor or {0,1,0,1}) end
function M:SetMinMaxValues(lo,hi) self.minimum,self.maximum=lo,hi end
function M:SetValue(value) self.value=value end
function M:SetReverseFill(value) self.reverse=value end
function M:SetTexCoord(...) self.coords={...} end
function M:GetTexCoord() return unpack(self.coords or {0,1,0,1}) end
function M:SetUnit(unit) self.unit=unit end
function M:SetFrameLevel(v) self.frameLevel = v end
function M:SetClipsChildren(value) self.clipsChildren=value end
function M:GetEffectiveScale() return 1 end
function M:GetCenter() return 500,400 end
function M:GetID() return self.id end
function M:GetBagID() return self.bag end
function M:GetParent() return self.parent end
function M:SetParent(parent) assert(not TEST.combat); self.parent=parent end
function M:SetFont(path,size,flags) self.font={path,size,flags} end
function M:GetFont() return unpack(self.font or {'Fonts\\FRIZQT__.TTF',12,''}) end
function M:GetShadowOffset() return unpack(self.shadowOffset or {0,0}) end
function M:SetShadowOffset(x,y) self.shadowOffset={x,y} end
function M:GetObjectType() return self.kind end
function M:GetDrawLayer() return self.layer or 'ARTWORK' end
function M:GetRegions()
    local result={}; for _,f in ipairs(TEST.frames) do if f.parent==self and (f.kind=='Texture' or f.kind=='FontString') then result[#result+1]=f end end
    return unpack(result)
end
function M:GetChildren()
    local result={}; for _,f in ipairs(TEST.frames) do if f.parent==self and f.kind~='Texture' and f.kind~='FontString' then result[#result+1]=f end end
    return unpack(result)
end
function M:Click(mouse)
    if self.enabled==false then return end
    if self.scripts.OnClick then self.scripts.OnClick(self,mouse or 'LeftButton') end
    if self.scripts.PostClick then self.scripts.PostClick(self,mouse or 'LeftButton') end
end
function M:SetID(id) self.id = id end
function M:SetPoint(...) self.point = {...} end
function M:SetText(t) self.text = t; if self.fontString then self.fontString:SetText(t) end end
function M:GetText() return self.text or '' end
function M:GetNormalTexture() return self.normalRegion end
function M:GetPushedTexture() return self.pushedRegion end
function M:GetDisabledTexture() return self.disabledRegion end
function M:GetHighlightTexture() return self.highlightRegion end
function M:IsEnabled() return self.enabled ~= false end
function M:SetDesaturated(value) self.desaturated=value end
function M:SetCooldown(start,duration) self.cooldownStart,self.cooldownDuration=start,duration end
function GetTime() return TEST.now end
C_NewItems={}
function C_NewItems.IsNewItem(bag,slot) return TEST.newItems and TEST.newItems[bag..':'..slot] or false end
function C_NewItems.RemoveNewItem(bag,slot) if TEST.newItems then TEST.newItems[bag..':'..slot]=nil end end
function GetInventoryItemID(unit,slot) local row=TEST.equipment and TEST.equipment[slot]; return row and row.id end
function GetInventoryItemLink(unit,slot) local id=GetInventoryItemID(unit,slot); return id and ('item:'..id) end
function GetInventoryItemTexture(unit,slot) return GetInventoryItemID(unit,slot) and 134400 end
function GetInventoryItemDurability(slot) local row=TEST.equipment and TEST.equipment[slot]; if row then return row.current,row.maximum end end
function M:SetTexture(t) self.texture = t end
function M:SetNormalTexture(t) self.normalTexture = t end
function M:SetVertexColor(...) self.color = {...} end
-- Real frame scale is independent of Lua fields such as settings.scale buttons.
function M:SetScale(v) self.frameScale=v; if type(self.scale)~="table" then self.scale=v end end
function M:SetChecked(v) self.checked = v end
function M:GetChecked() return self.checked end
function M:SetEnabled(v) self.enabled = v end
function M:SetMultiLine(value) assert(self.kind=='EditBox'); self.multiLine=value end
function M:SetScrollChild(child) assert(self.kind=='ScrollFrame' and child.parent==self); self.scrollChild=child end
function M:HighlightText(first,last) self.highlighted={first or 0,last or #self:GetText()} end
function M:HasFocus() return self.focus end
function M:ClearFocus() self.focus = false end
function M:SetFocus() self.focus = true end
function M:Show()
    local changed = not self.shown; self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function M:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function M:SetShown(v) if v then self:Show() else self:Hide() end end
function M:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function M:AddLine(text) self.lines[#self.lines+1] = text end
function M:AddMessage(text) self.lines[#self.lines+1] = text end
function M:SetOwner(owner) self.owner = owner end
for _,k in ipairs({'ClearAllPoints','SetAllPoints','SetFrameStrata','SetClampedToScreen','SetMovable',
    'RegisterForDrag','RegisterForClicks','SetBackdrop','StartMoving','StopMovingOrSizing','SetJustifyH','EnableMouseWheel',
    'SetJustifyV','SetHighlightTexture','SetTextColor','SetAutoFocus','SetColorTexture',
    'SetFontString','SetFontObject','SetTextInsets','SetMaxLetters','SetFocus','SetBackdropColor','SetBackdropBorderColor','SetLooping','SetFromAlpha','SetToAlpha','SetDuration','SetHyperlink'}) do M[k] = function() end end
function M:SetFontString(region) self.fontString=region end
function M:GetFontString() return self.fontString end
function M:SetBackdropBorderColor(...) self.border={...} end
function M:SetBackdropColor(...) self.backdropColor={...} end
function M:SetAllPoints(...) self.allPoints={...} end
function CreateFrame(kind,name,parent,template)
    local f = setmetatable({name=name,kind=kind,template=template,attributes={},scripts={},events={},shown=true,parent=parent,lines={}}, {
        __index = function(t,k) if M[k] then return M[k] end; return nil end})
    if template and template:find('SecureActionButtonTemplate',1,true) then
        f.scripts.OnClick=function(control,mouse,down)
            if control:GetAttribute('type')=='click' and not down then control:GetAttribute('clickbutton'):Click(mouse); return end
            if down or TEST.combat then return end
            local suffix=mouse=='RightButton' and '2' or '1'
            if control:GetAttribute('type'..suffix)=='item' then
                TEST.secureUses=(TEST.secureUses or 0)+1
                TEST.lastSecureItem=control:GetAttribute('item'..suffix)
            end
        end
    end
    if name then _G[name] = f end
    TEST.frames[#TEST.frames+1] = f
    return f
end
UIParent = CreateFrame('Frame'); UIParent:SetSize(1920,1080)
function CreateFont(name) return CreateFrame('Font',name) end
TEST.units={player={name='Player',player=true,class='MAGE',health=80,maxHealth=100,power=50,maxPower=100},target={name='Enemy',enemy=true,health=50,maxHealth=100,power=20,maxPower=100}}
function UnitExists(unit) return TEST.units[unit]~=nil end
function UnitName(unit) return TEST.units[unit] and TEST.units[unit].name end
function UnitIsPlayer(unit) return TEST.units[unit] and TEST.units[unit].player or false end
function UnitClass(unit) return 'Class',TEST.units[unit] and TEST.units[unit].class end
function UnitCanAttack(_,unit) return TEST.units[unit] and TEST.units[unit].enemy or false end
function UnitReaction(unit) return TEST.units[unit] and TEST.units[unit].reaction or 5 end
function UnitHealth(unit) return TEST.units[unit] and TEST.units[unit].health or 0 end
function UnitHealthMax(unit) return TEST.units[unit] and TEST.units[unit].maxHealth or 0 end
function UnitIsDeadOrGhost(unit) return TEST.units[unit] and TEST.units[unit].dead or false end
function UnitPowerType(unit) return 0,'MANA' end
function UnitPower(unit) return TEST.units[unit] and TEST.units[unit].power or 0 end
function UnitPowerMax(unit) return TEST.units[unit] and TEST.units[unit].maxPower or 0 end
function SetPortraitTexture(texture,unit) texture.portraitUnit=unit end
function RegisterUnitWatch(f) assert(not TEST.combat); f.watched=true; f:SetShown(UnitExists(f:GetAttribute('unit'))) end
function UnregisterUnitWatch(f) assert(not TEST.combat); f.watched=false end
function hooksecurefunc(target,name,callback)
    if type(target)=='string' then local old=_G[target]; _G[target]=function(...) local result=old(...); name(...); return result end
    else local old=target[name]; target[name]=function(...) local result=old(...); callback(...); return result end end
end
RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92},WARRIOR={r=.78,g=.61,b=.43}}
PowerBarColor={MANA={r=0,g=.5,b=1}}
PlayerFrame=CreateFrame('Button'); TargetFrame=CreateFrame('Button')
MainActionBar=CreateFrame('Frame','MainActionBar',UIParent); MainActionBar:SetSize(500,40); MainActionBar:SetPoint('BOTTOM',UIParent,'BOTTOM',0,10)
MainActionBar.actionButtons={}; MainActionBar.EndCaps=CreateFrame('Frame',nil,MainActionBar)
for i=1,12 do local b=CreateFrame('Button','ActionButton'..i,MainActionBar); b.icon=b:CreateTexture(); b:SetAttribute('action',i); MainActionBar.actionButtons[i]=b end
C_NamePlate={GetNamePlates=function() return TEST.plates or {} end,GetNamePlateForUnit=function(unit) return TEST.plateMap and TEST.plateMap[unit] end}
Minimap = CreateFrame('Frame')
MerchantFrame = CreateFrame('Frame')
GameTooltip = CreateFrame('Frame')
DEFAULT_CHAT_FRAME = CreateFrame('Frame')
SlashCmdList, UISpecialFrames = {}, {}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
function ReloadUI() TEST.reloads=(TEST.reloads or 0)+1 end
function InCombatLockdown() return TEST.combat or false end
function CursorHasItem() return TEST.cursor ~= nil end
function InRepairMode() return TEST.repairMode or false end
function SpellIsTargeting() return TEST.targeting or false end
function CanSellItems() return TEST.canSell ~= false end
function ClearCursor()
    if TEST.cursor and TEST.cursor.source then
        local item = TEST.bags[TEST.cursor.source.bag][TEST.cursor.source.slot]
        if item then item.stackCount = item.stackCount + TEST.cursor.stackCount end
    end
    TEST.cursor = nil
end
function GetCursorInfo() if TEST.cursor then return 'item',TEST.cursor.itemID,'item:'..TEST.cursor.itemID end end
function GetCursorPosition() return 520,410 end
function GetMoney() return TEST.money end
function date() return '2026-10-04 12:00' end
function issecretvalue() return false end
function IsInGuild() return TEST.inGuild or false end
function CanGuildBankRepair() return TEST.guildCanRepair ~= false end
function GetGuildBankWithdrawMoney() return TEST.guildAllowance end
function GetGuildBankMoney() return TEST.guildMoney end
function CanMerchantRepair() return TEST.canRepair ~= false end
function GetRepairAllCost() return TEST.repair, TEST.repair > 0 end
function RepairAllItems(guild)
    TEST.actions[#TEST.actions+1] = {kind='repair',guild=guild}
    if TEST.failRepair then return end
    After(TEST.delay, function()
        if guild then TEST.guildMoney = TEST.guildMoney - TEST.repair else TEST.money = TEST.money - TEST.repair end
        TEST.repair = 0
    end)
end
C_Container = {}
function C_Container.GetContainerItemCooldown(bag,slot)
    local row=TEST.cooldowns and TEST.cooldowns[bag..':'..slot]
    if row then return row.start,row.duration,row.enabled end
    return 0,0,1
end
function C_Container.GetContainerNumSlots(bag) return TEST.bagSizes and TEST.bagSizes[bag] or (bag == 0 and 16 or 0) end
function C_Container.SortBags() TEST.sortCalls=(TEST.sortCalls or 0)+1 end
function C_Container.GetContainerNumFreeSlots(bag)
    local n = 0
    for slot=1,C_Container.GetContainerNumSlots(bag) do if not TEST.bags[bag] or not TEST.bags[bag][slot] then n=n+1 end end
    return n,0
end
function C_Container.GetContainerItemInfo(bag,slot)
    local item = TEST.bags[bag] and TEST.bags[bag][slot]
    return item and copy(item)
end
function C_Container.GetContainerItemQuestInfo(bag,slot)
    local info = TEST.bags[bag][slot]
    return { isQuestItem = info.quest or false, questID=info.questID }
end
function C_Container.GetContainerItemEquipmentSetInfo(bag,slot) return TEST.bags[bag][slot].inSet or false end
function C_Container.GetContainerItemPurchaseInfo(bag,slot)
    if TEST.bags[bag][slot].refundable then return {refundSeconds=900} end
end
function C_Container.SplitContainerItem(bag,slot,quantity)
    if TEST.failSplit then return end
    local source = TEST.bags[bag][slot]
    assert(not TEST.cursor and quantity > 0 and quantity < source.stackCount)
    TEST.cursor = copy(source)
    TEST.guid = TEST.guid + 1
    TEST.cursor.guid = 'guid-'..TEST.guid
    TEST.cursor.stackCount = quantity
    TEST.cursor.source = {bag=bag,slot=slot}
    source.stackCount = source.stackCount - quantity
end
function C_Container.PickupContainerItem(bag,slot)
    if TEST.failPlace then return end
    TEST.bags[bag] = TEST.bags[bag] or {}
    local previous = TEST.bags[bag][slot]
    TEST.bags[bag][slot] = TEST.cursor
    if TEST.cursor then TEST.cursor.source = nil end
    TEST.cursor = previous
end
function C_Container.UseContainerItem(bag,slot)
    local item = TEST.bags[bag][slot]
    if not MerchantFrame:IsShown() then
        local data=TEST.data[item.itemID]
        assert(data.equippable, 'Only equipment uses the direct container route away from merchants')
        TEST.actions[#TEST.actions+1]={kind='equip',bag=bag,slot=slot,id=item.itemID}
        local function equip()
            if TEST.bags[bag][slot]~=item then return end
            TEST.equippedItem=item; TEST.bags[bag][slot]=nil
        end
        if data.bindOnEquip then TEST.bindPrompt={bag=bag,slot=slot,accept=equip}
        else equip() end
        return
    end
    TEST.actions[#TEST.actions+1] = {kind='sale',id=item.itemID,count=item.stackCount}
    if TEST.failSale then return end
    After(TEST.delay, function()
        if TEST.bags[bag][slot] ~= item then return end
        local price = TEST.data[item.itemID].price * item.stackCount
        TEST.money = TEST.money + price
        table.insert(TEST.buyback,{id=item.itemID,count=item.stackCount,price=price})
        while #TEST.buyback > 12 do table.remove(TEST.buyback,1) end
        TEST.bags[bag][slot] = nil
    end)
end
C_Item = {}
function C_Item.IsEquippableItem(link)
    local id=tonumber(tostring(link):match('item:(%d+)'))
    return TEST.data[id] and TEST.data[id].equippable or false
end
function C_Item.RequestLoadItemDataByID(id) TEST.requested = id end
function C_Item.GetItemInfo(id)
    if type(id)=='string' then id = tonumber(string.match(id,'item:(%d+)')) end
    local d = TEST.data[id]
    if not d or d.pending then return nil end
    return d.name or ('Test item '..id),'item:'..id,d.quality or 0,1,1,'Type','Subtype',d.maxStack or 20,'',134400,d.price or 10,d.classID or 0,d.subclassID
end
function C_Item.GetItemGUID(location)
    return TEST.bags[location.bag] and TEST.bags[location.bag][location.slot] and TEST.bags[location.bag][location.slot].guid
end
ItemLocation = {}
function ItemLocation:CreateFromBagAndSlot(bag,slot) return {bag=bag,slot=slot} end
function GetMerchantNumItems() return #TEST.merchant end
function GetMerchantItemID(i) return TEST.merchant[i].id end
function GetMerchantItemMaxStack(i) return TEST.merchant[i].maxStack or 20 end
C_MerchantFrame = {}
function C_MerchantFrame.GetItemInfo(i)
    local m = TEST.merchant[i]
    return {name='Merchant item',texture=134400,price=m.price,stackCount=m.bundle or 1,
        numAvailable=m.stock or -1,isPurchasable=not m.unavailable,hasExtendedCost=m.extended or false}
end
function AddItem(slot,id,count,props)
    TEST.bags[0] = TEST.bags[0] or {}
    TEST.guid = TEST.guid+1
    local item = {itemID=id,stackCount=count,hyperlink='item:'..id,quality=TEST.data[id].quality or 0,
        iconFileID=134400,isLocked=false,hasLoot=false,hasNoValue=false,guid='guid-'..TEST.guid}
    for k,v in pairs(props or {}) do item[k]=v end
    TEST.bags[0][slot] = item
    return item
end
function BuyMerchantItem(i,count)
    TEST.actions[#TEST.actions+1] = {kind='purchase',index=i,count=count}
    if TEST.failBuy then return end
    local m = TEST.merchant[i]
    local price = count*m.price/(m.bundle or 1)
    assert(count % (m.bundle or 1) == 0 and TEST.money >= price)
    After(TEST.delay,function()
        for slot=1,16 do
            if not TEST.bags[0][slot] then
                AddItem(slot,m.id,count)
                TEST.money=TEST.money-price
                if m.stock and m.stock >= 0 then m.stock=m.stock-count end
                return
            end
        end
    end)
end
function GetNumBuybackItems() return #TEST.buyback end
function GetBuybackItemInfo(i)
    local b = TEST.buyback[i]
    if b then return 'Buyback item',134400,b.price,b.count end
end
function GetBuybackItemLink(i) local b=TEST.buyback[i]; return b and ('item:'..b.id) end
function BuybackItem(i)
    local b=TEST.buyback[i]
    TEST.actions[#TEST.actions+1]={kind='buyback',id=b.id}
    After(TEST.delay,function()
        for slot=1,16 do
            if not TEST.bags[0][slot] then AddItem(slot,b.id,b.count); TEST.money=TEST.money-b.price; table.remove(TEST.buyback,i); return end
        end
    end)
end
function ResetTest()
    ForeverSuite.modules.Vendor:CloseMerchant()
    if ForeverSuite.modules.Vendor.window then ForeverSuite.modules.Vendor.window:Hide() end
    if ForeverSuite.modules.Vendor.glowWindow then ForeverSuite.modules.Vendor.glowWindow:Hide() end
    Drain()
    local B=ForeverSuite.modules.Bags
    if B.window then B.window:Hide(); if B.window.settings then B.window.settings:Hide() end end
    B.search=''; B.selected=nil; B.page=1; B.status=nil; B.collapsed=nil; B.itemOptions=false
    B.newItems=nil; B.recentItems=nil; B.previousTotals=nil; B.sidebarOffset=0; TEST.newItems={}; TEST.cooldowns={}; TEST.equipment={}; TEST.bags={[0]={}}; TEST.data={}; TEST.merchant={}; TEST.buyback={}; TEST.actions={}
    TEST.money=1000000; TEST.repair=0; TEST.guildMoney=1000000; TEST.guildAllowance=1000000
    TEST.combat=false; TEST.targeting=false; TEST.cursor=nil; TEST.repairMode=false
    TEST.failSale=false; TEST.failRepair=false; TEST.failBuy=false; TEST.failSplit=false; TEST.failPlace=false
    TEST.inGuild=false; TEST.canRepair=true; TEST.canSell=true; TEST.delay=0.25
    ForeverSuiteDB={}
    ForeverSuite:InitializeDatabase()
    ForeverSuite:SelectLocale()
    ForeverSuite.modules.Vendor.status=nil
    MerchantFrame:Show()
end
function Open() ForeverSuite.modules.Vendor:OpenMerchant(); Drain() end
function Click(frame) assert(frame:GetScript('OnClick'),'Missing click'); frame:GetScript('OnClick')(frame) end
function FindButton(parent,text)
    for _,frame in ipairs(TEST.frames) do if frame.parent==parent and frame.kind=='Button' and frame.text==text then return frame end end
    error('Button not found: '..text)
end
''')
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e); return f end')
namespace = lua.table()
for file in files:
    path = root/file
    assert path.is_file(), f'Missing TOC file {file}'
    compile_lua(path.read_text(encoding='utf-8'), '@'+file)('ForeverSuite', namespace)
lua.execute("ForeverSuite.events:GetScript('OnEvent')(ForeverSuite.events,'ADDON_LOADED','ForeverSuite'); Drain()")
print(f'PASS: Lua 5.1 syntax and startup in TOC order ({len(files)} files)')

checks = {
    'safe rules, protection priority and reserves across stacks': r'''
ResetTest()
local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; TEST.data[2]={quality=1,price=20}; TEST.data[3]={quality=3,price=30}
AddItem(1,1,20); AddItem(2,1,10); AddItem(3,1,2,{quest=true}); AddItem(4,2,5); AddItem(5,3,1)
V:SetRule(1,true,20,0); V:SetRule(2,true,0,0); V:SetRule(3,true,0,0)
local plan=V:BuildPlan()
assert(plan.units==17 and plan.value==220 and plan.slots==2)
assert(plan.bySlot['0:3'].sellCount==0 and plan.bySlot['0:5'].sellCount==0)
assert(plan.bySlot['0:2'].sellCount==10 and plan.bySlot['0:1'].sellCount==2)
V:KeepItem(2); assert(V:BuildPlan().units==12)
V:SetMode('auto'); assert(V:BuildPlan().units==12)
V:Settings().includeGray=false; assert(V:BuildPlan().units==0)
V:SetMode('custom'); V:Settings().alwaysKeep[2]=nil; assert(V:BuildPlan().units==17)
''',
    'module protection provider and failure handling': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,30); V:SetRule(1,true,0,0)
V:RegisterProtectionProvider('Crafting',function() return nil,24 end)
assert(V:BuildPlan().units==6)
V:RegisterProtectionProvider('Gear',function() return 'Reserved gear' end)
assert(V:BuildPlan().units==0)
V:UnregisterProtectionProvider('Gear')
V:RegisterProtectionProvider('Crafting',function() error('unavailable') end)
assert(V:BuildPlan().units==0)
V:UnregisterProtectionProvider('Crafting'); Drain()
assert(V:BuildPlan().units==30)
''',
    'pending, locked, refundable, lootable and equipment-set items': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; TEST.data[2]={quality=0,price=10,pending=true}
AddItem(1,1,1,{isLocked=true}); AddItem(2,1,1,{refundable=true}); AddItem(3,1,1,{hasLoot=true})
AddItem(4,1,1,{inSet=true}); AddItem(5,2,1)
assert(V:BuildPlan().units==0)
TEST.data[2].pending=false; assert(V:BuildPlan().units==1)
''',
    'manual mode, serialized sales and visit report': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=13}; AddItem(1,1,2); AddItem(2,1,3)
Open(); assert(#TEST.actions==0)
V:StartSelling(); V:StartSelling(); Drain()
assert(#TEST.actions==2 and V:CountItem(1)==0 and V.visit.sold==65 and V.visit.freed==2)
assert(not V.busy)
V:CloseMerchant(); Drain(); assert(#V:Settings().history==1)
assert(string.find(V:Settings().history[1].text,'Sold: 0g 0s 65c',1,true))
''',
    'partial-stack sale preserves quantities and reports zero net freed slots': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,30); V:SetRule(1,true,20,0)
Open(); V:StartSelling(); Drain()
assert(V:CountItem(1)==20 and V.visit.sold==100 and V.visit.freed==0)
assert(TEST.actions[1].count==10 and not TEST.cursor)
''',
    'partial stacks with full bags and failed placement remain intact': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; TEST.data[2]={quality=1,price=10}
AddItem(1,1,30); for i=2,16 do AddItem(i,2,1) end
V:SetRule(1,true,20,0); Open(); V:StartSelling(); Drain()
assert(V:CountItem(1)==30 and #TEST.actions==0 and not V.busy)
TEST.bags[0][16]=nil; TEST.failPlace=true; V:StartSelling(); Drain()
assert(V:CountItem(1)==30 and not TEST.cursor and #TEST.actions==0)
''',
    'failed sales stop rather than retry or inflate the report': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,2); AddItem(2,1,3)
TEST.failSale=true; Open(); V:StartSelling(); Drain()
assert(#TEST.actions==1 and V:CountItem(1)==5 and V.visit.sold==0 and not V.busy)
''',
    'merchant closure cancels queued work': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,1); AddItem(2,1,1)
Open(); V:StartSelling(); V:CloseMerchant(); MerchantFrame:Hide(); Drain()
assert(#TEST.actions==1 and V:CountItem(1)==1 and not V.busy)
assert(#V:Settings().history==1 and string.find(V:Settings().history[1].text,'Sold: 0g 0s 10c',1,true))
''',
    'Stop retains the lock until an issued sale settles': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,1); AddItem(2,1,1)
Open(); V:StartSelling(); V:StopTransactions('Stopped'); V:StartSelling()
assert(#TEST.actions==1 and V.busy)
Drain(); assert(#TEST.actions==1 and V.visit.sold==10 and not V.busy)
V:StartSelling(); Drain(); assert(#TEST.actions==2 and V.visit.sold==20)
''',
    'incomplete inventory data blocks restocking': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,1)
TEST.merchant={{id=1,price=100,bundle=1}}; V:SetRule(1,false,0,5); Open()
local read = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo=function(bag,slot)
    local item=read(bag,slot); if item then item.itemID=0 end; return item
end
V:StartRestock(); Drain(); assert(#TEST.actions==0)
C_Container.GetContainerItemInfo=read
''',
    'rules changing during a split prevent unsafe sale': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,30); V:SetRule(1,true,20,0)
Open(); V:StartSelling(); V:KeepItem(1); Drain()
assert(V:CountItem(1)==30 and #TEST.actions==0 and not V.busy)
''',
    'automatic mode excludes custom white junk; custom mode includes it': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; TEST.data[2]={quality=1,price=10}
AddItem(1,1,1); AddItem(2,2,1); V:SetRule(2,true,0,0); V:SetMode('auto')
Open(); assert(V:CountItem(1)==0 and V:CountItem(2)==1)
V:CloseMerchant(); V:SetMode('custom'); Open(); assert(V:CountItem(2)==0)
''',
    'combat, cursor, repair mode and spell targeting block transactions': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,1); Open()
TEST.combat=true; V:StartSelling(); assert(#TEST.actions==0); TEST.combat=false
TEST.cursor={}; V:StartSelling(); assert(#TEST.actions==0); TEST.cursor=nil
TEST.repairMode=true; V:StartSelling(); assert(#TEST.actions==0); TEST.repairMode=false
TEST.targeting=true; V:StartSelling(); assert(#TEST.actions==0); TEST.targeting=false
''',
    'repair limits, confirmation, personal funds and guild fallback': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
Open(); TEST.repair=60000; V:TryRepair(false)
assert(V.repairConfirmation and #TEST.actions==0)
V:TryRepair(true); Drain(); assert(TEST.repair==0 and V.visit.personalRepair==60000)
TEST.repair=100; V:Settings().repairSource='guild'; V:TryRepair(false)
assert(#TEST.actions==1 and TEST.repair==100)
TEST.inGuild=true; V:TryRepair(false); Drain(); assert(V.visit.guildRepair==100)
TEST.repair=150; TEST.guildAllowance=0; V:Settings().repairSource='guildFirst'
V:TryRepair(false); Drain(); assert(V.visit.personalRepair==60150)
TEST.repair=70000; V:Settings().confirmRepair=false; V:TryRepair(false); Drain(); assert(TEST.repair==70000)
''',
    'restock bundles, total visit budget, carried stock and target protection': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=5}; TEST.data[2]={quality=1,price=5}
TEST.merchant={{id=1,price=100,bundle=5,maxStack=10},{id=2,price=100,bundle=1,extended=true}}
V:SetRule(1,true,0,18); V:SetRule(2,false,0,2); V:Settings().restockBudget=300
Open(); V:StartRestock(); Drain()
assert(V:CountItem(1)==15 and V.visit.restocked==300 and #TEST.actions==2)
assert(V:BuildPlan().units==0)
V:StartRestock(); Drain(); assert(#TEST.actions==2)
assert(V:RestockPlan().items[2].reason=='Currency/token cost or unavailable item')
''',
    'restock uses reserve, stock limits and confirmation before another purchase': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=5}; TEST.merchant={{id=1,price=100,bundle=1,stock=3}}
V:SetRule(1,false,0,10); V:Settings().restockBudget=1000; V:Settings().moneyReserve=999800
Open(); V:StartRestock(); Drain(); assert(V:CountItem(1)==2 and V.visit.restocked==200)
ResetTest(); TEST.data[1]={quality=1,price=5}; TEST.merchant={{id=1,price=100,bundle=1}}
V:SetRule(1,false,0,10); TEST.failBuy=true; Open(); V:StartRestock(); Drain()
assert(#TEST.actions==1 and V.visit.restocked==0 and not V.busy)
''',
    'buyback only current entries; net report includes recovery costs': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,3); Open(); V:StartSelling(); Drain()
local row=V:BuybackList()[1]; V:KeepItem(1); V:BuyBack(row); Drain()
assert(V:CountItem(1)==3 and V.visit.boughtBack==30 and V:BuildPlan().units==0)
V:BuyBack(row); Drain(); assert(#TEST.actions==2)
assert(string.find(V:VisitSummary(V.visit),'Net: +0g 0s 0c',1,true))
''',
    'all UI tabs, editable rules, highlight controls and native bag cleanup': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; TEST.data[2]={quality=0,price=10}
AddItem(1,1,30); AddItem(2,2,1); V:SetRule(1,true,20,0); Open(); V:ShowWindow(false)
for _,tab in ipairs({'Overview','Rules','Supplies','Settings','Buy Back','History'}) do
    V.tab=tab; V.page=1; V:RefreshWindow()
end
local page=V.window.pages.Rules
page.id:SetText('item:1'); page.keep:SetText('20'); page.target:SetText('10')
Click(FindButton(page,'Save as Junk'))
assert(V:Settings().rules[1].junk and V:Settings().rules[1].target==10)
Click(FindButton(page,'Save Stock Only')); assert(not V:Settings().rules[1].junk)
Click(FindButton(page,'Save as Junk'))
page.keep:SetText('-1'); Click(FindButton(page,'Save as Junk')); assert(V:Settings().rules[1].keep==20)
Click(FindButton(page,'Highlight Effect...')); assert(V.glowWindow:IsShown())
V.glowWindow.intensity:SetText('0.5'); Click(FindButton(V.glowWindow,'Save'))
assert(V:Settings().glow.intensity==0.5)
local native=CreateFrame('Button'); native.bag=0; native.id=1
ContainerFrame1={Items={native}}
V:Refresh()
assert(native.fsVendorGlow and native.fsVendorGlow:IsShown() and native.fsVendorGlow.count.text=='x10')
assert(native.fsVendorGlow.edges[1].color[4]==0.5)
V:KeepItem(1); assert(not native.fsVendorGlow:IsShown())
V:Settings().alwaysKeep[1]=nil; V:Refresh(); assert(native.fsVendorGlow:IsShown())
V:Settings().glow.enabled=false; V:Refresh(); assert(not native.fsVendorGlow:IsShown())
V:Settings().glow.enabled=true; V:Settings().glow.pulse=false; V:Refresh()
assert(not native.fsVendorGlow.anim:IsPlaying())
native:Hide(); assert(not native.fsVendorGlow:IsShown())
ContainerFrame1=nil; V.trackedButtons={}
''',
    'SavedVariables migration, settings normalization and core commands': r'''
ResetTest(); local V=ForeverSuite.modules.Vendor
ForeverSuiteDB={language='nlNL',vendor={mode='bad',repairLimit=0/0,glow={intensity=math.huge},
    rules={[1]='bad',[2]={junk=true,keep=-9,target='bad'}},alwaysKeep={[1]=true,[2]='bad'}}}
ForeverSuite:InitializeDatabase(); ForeverSuite:SelectLocale()
assert(ForeverSuite.db.language=='enUS' and V:Settings().mode=='manual')
assert(V:Settings().rules[1]==nil and V:Settings().rules[2].keep==0)
assert(V:Settings().glow.intensity==0.8)
V:ToggleWindow(); assert(V.window:IsShown())
V:ToggleWindow(); assert(not V.window:IsShown())
ForeverSuite:ResetDatabase(); assert(V:Settings().mode=='manual')
''',
}

checks['Bags filters, literal search, view order and free-slot accounting'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
B.search=''; B.selected=nil; ForeverSuite.db.bags.showEmpty=true
TEST.data[1]={quality=1,price=10,classID=2,name='Sword [A]'}
TEST.data[2]={quality=1,price=20,classID=7,name='Copper'}
TEST.data[3]={quality=0,price=3,name='Junk'}
TEST.data[4]={quality=1,price=2,classID=12,name='Quest'}
AddItem(1,1,1); AddItem(2,2,20); AddItem(3,3,2); AddItem(4,4,1)
local view=B:BuildView(); assert(view.free==12 and view.capacity==16 and #view.rows==16)
assert(view.plan.value==6 and view.plan.units==2)
ForeverSuite.db.bags.category='Gear'; view=B:BuildView(); assert(#view.rows==1 and view.rows[1].id==1)
ForeverSuite.db.bags.category='Junk'; view=B:BuildView(); assert(#view.rows==1 and view.rows[1].id==3)
V:KeepItem(3); assert(#B:BuildView().rows==0)
ForeverSuite.db.bags.category='All'; B.search='[A]'; assert(#B:BuildView().rows==1)
B.search='2'; assert(B:BuildView().rows[1].id==2)
B.search='no match'; assert(#B:BuildView().rows==0)
B.search=''; ForeverSuite.db.bags.showEmpty=false; ForeverSuite.db.bags.sort='value'
view=B:BuildView(); assert(#view.rows==4 and view.rows[1].id==1 and view.rows[3].id==2)
"""
checks['Bags stock includes absent items and keeps reserve and target distinct'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
B.search=''; TEST.data[1]={quality=1,price=10}; TEST.data[2]={quality=1,price=10}
AddItem(1,1,5); V:SetRule(1,true,10,8); V:SetRule(2,false,2,20)
ForeverSuite.db.bags.category='Stock'; local view=B:BuildView(); assert(#view.rows==2)
local rows={}; for _,r in ipairs(view.rows) do rows[r.id]=r end
assert(rows[1].count==5 and rows[1].reserve==10 and rows[1].missing==3)
assert(rows[2].count==0 and rows[2].reserve==20 and rows[2].missing==20)
B.selected=rows[2]; B:SaveStock('7','30'); assert(V:Settings().rules[2].keep==7 and V:Settings().rules[2].target==30)
B:SaveStock('-1','30'); assert(V:Settings().rules[2].keep==7)
"""
checks['Bags marks share Vendor protection and preserve stock quantities'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,30); V:SetRule(1,false,10,20)
B.selected=V:ReadItem(0,1); B:Mark('junk')
assert(V:BuildPlan().units==10 and V:Settings().rules[1].target==20)
B:Mark('keep'); assert(V:BuildPlan().units==0)
B:Mark('junk'); assert(V:BuildPlan().units==10 and not V:Settings().alwaysKeep[1])
B:SaveStock('25','0'); assert(V:BuildPlan().units==5)
B:Mark('clear'); assert(not V:Settings().rules[1] and V:BuildPlan().units==0)
AddItem(1,1,30); assert(not B:CurrentItem())
"""
checks['Bags safe selected selling preserves partial stacks and blocks direct merchant use'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,30); V:SetRule(1,true,20,0); Open()
B.selected=V:ReadItem(0,1); B:Action('use'); assert(#TEST.actions==0)
B:Action('sell'); Drain(); assert(V:CountItem(1)==20 and #TEST.actions==1 and TEST.actions[1].count==10)
B.selected=V:ReadItem(0,1); B:Action('sell'); Drain(); assert(V:CountItem(1)==20)
"""
checks['Bags drag placement, stale selection and combat/transaction sorting guards'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=10}; AddItem(1,1,3)
B.selected=V:ReadItem(0,1); TEST.combat=true; B:Action('pickup'); assert(not TEST.cursor)
TEST.combat=false; B:Action('pickup'); assert(TEST.cursor and not TEST.bags[0][1])
B:Action('pickup',{empty=true,bag=0,slot=2}); assert(not TEST.cursor and TEST.bags[0][2].itemID==1)
TEST.sortCalls=0; TEST.combat=true; ForeverSuite.db.bags.category='Other'; B.search='unknown'; B:SortBags()
assert(TEST.sortCalls==0 and ForeverSuite.db.bags.category=='All' and B.search=='')
TEST.combat=false; assert(B:CurrentItem()==nil)

"""
checks['Bags UI pagination, English controls, selection, empty results and live Vendor changes'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
B.search=''; B.selected=nil; B.page=1; ForeverSuite.db.bags.showEmpty=true
TEST.data[1]={quality=0,price=10}; AddItem(1,1,3)
B:ToggleWindow(); local f=B.window; assert(f:IsShown() and #f.cells==132)
local cell; for _,c in ipairs(f.cells) do if c.row and c.row.id==1 then cell=c end end
assert(cell and cell.marker.text=='$' and cell.fsVendorGlow:IsShown())
cell.scripts.OnClick(cell,'LeftButton'); assert(B.selected.id==1 and f.detail.text:find('You have 3',1,true))
Click(FindButton(f.itemPanel,'Never sell')); assert(cell.marker.text=='K' and not cell.fsVendorGlow:IsShown())
f.search:SetText('unmatched'); f.search.scripts.OnTextChanged(f.search); assert(#B.view.rows==0 and not f.cells[1]:IsShown())
f.search:SetText(''); f.search.scripts.OnTextChanged(f.search)
TEST.bagSizes={[0]=16,[1]=200}; TEST.bags[1]={}; V:Refresh(); assert(B.view.capacity==216 and B.view.free==215)
Click(FindButton(f,'Next')); assert(B.page==2)
Click(FindButton(f,'Previous')); assert(B.page==1)
Click(FindButton(f.filterMenu,'Shopping list')); assert(ForeverSuite.db.bags.category=='Stock')
TEST.bagSizes=nil; TEST.bags[1]=nil; B:ToggleWindow(); assert(not f:IsShown())
"""
checks['Bags settings migration and unknown inventory slots fail closed'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags
ForeverSuite.db.bags={category='bad',sort='bad',showEmpty=true,x=0/0,y=math.huge}; B:NormalizeSettings()
assert(ForeverSuite.db.bags.category=='All' and ForeverSuite.db.bags.sort=='category' and ForeverSuite.db.bags.x==0 and ForeverSuite.db.bags.y==0)
B.search=''; TEST.bags[0]={[1]={itemID='unknown',stackCount=1}}; local view=B:BuildView()
assert(view.free==15 and view.unknown==1 and #view.rows==15)
"""


checks['Automatic category grouping, saved assignments and category layout boundaries'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=1,price=1,classID=2,name='Z Gear'}
TEST.data[2]={quality=1,price=200,classID=0,name='A Food'}
TEST.data[3]={quality=1,price=1,classID=7,name='Material'}
AddItem(1,1,1); AddItem(2,2,1); AddItem(3,3,1)
ForeverSuite.db.bags.showEmpty=false; ForeverSuite.db.bags.sort='value'
local view=B:BuildView(); assert(view.rows[1].id==1 and view.rows[2].id==2 and view.rows[3].id==3)
local layouts=B:Layout(view); assert(#layouts[1].headers==4 and layouts[1].headers[1].category=='Favorites' and layouts[1].headers[2].text:find('Equipment',1,true))
B.selected=V:ReadItem(0,2); B:AssignCategory('Gear'); assert(B:Category(B:CurrentItem())=='Gear')
V:SetRule(2,true,0,0); assert(B:Category(V:BuildPlan().bySlot['0:2'])=='Junk')
V:KeepItem(2); assert(B:Category(V:BuildPlan().bySlot['0:2'])=='Gear')
B:AssignCategory('Automatic'); assert(not ForeverSuite.db.bags.categoryOverrides[2])
local rows={}; for i=1,300 do rows[i]={id=1,bag=0,slot=i,count=1,name='Gear',classID=2,sellCount=0} end
layouts=B:Layout({rows=rows}); local seen=0
for _,page in ipairs(layouts) do
    assert(#page.cells<=132 and #page.headers>0)
    for _,entry in ipairs(page.cells) do assert(entry.y+38<=480); seen=seen+1 end
end
assert(seen==300 and #layouts>1)
ForeverSuite.db.bags.categoryOverrides={[1]='bad',[2]='Materials',['bad']='Gear'}; B:NormalizeSettings()
assert(not ForeverSuite.db.bags.categoryOverrides[1] and not ForeverSuite.db.bags.categoryOverrides.bad and ForeverSuite.db.bags.categoryOverrides[2]=='Materials')
"""
checks['Embedded bag settings preserve edits, shared glow and validated budgets'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
B:ShowWindow(); local f=B.window; Click(FindButton(f,'More options')); Click(FindButton(f.options,'Settings')); local settings=ForeverSuite.window.settings
assert(settings:IsShown())
settings.module='Vendor'; settings.advanced=true; B:RefreshSettings(true,settings)
settings.fields.repairLimit:SetText('12.5'); settings.fields.restockBudget:SetText('4'); settings.fields.moneyReserve:SetText('3')
settings.intensity:SetText('0.4'); V:Refresh()
assert(settings.fields.repairLimit:GetText()=='12.5' and settings.fields.restockBudget:GetText()=='4')
Click(FindButton(settings,'Save advanced settings'))
assert(V:Settings().repairLimit==125000 and V:Settings().restockBudget==40000 and V:Settings().moneyReserve==30000 )
settings.module='Bags'; settings.advanced=true; B:RefreshSettings(true,settings); settings.intensity:SetText('0.4')
Click(settings.save); assert(V:Settings().glow.intensity==0.4)
Click(FindButton(settings,'Highlight junk: On')); assert(not V:Settings().glow.enabled)
settings.module='Vendor'; settings.advanced=true; B:RefreshSettings(true,settings); settings.fields.moneyReserve:SetText('-1'); Click(FindButton(settings,'Save advanced settings')); assert(V:Settings().moneyReserve==30000)
Click(FindButton(settings,'Back to Control Center')); assert(not settings:IsShown())
"""
checks['Bags merchant opening, repair confirmation and selected vendor actions stay in Bags'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,2); Open()
assert(B.window:IsShown() and (not V.window or not V.window:IsShown()))
B:VendorAction('sell'); V:ConfirmSaleReview(); Drain(); assert(V:CountItem(1)==0)
TEST.repair=60000; B:VendorAction('repair'); assert(V.repairConfirmation and B.window.repair.text=='Confirm Repair')
assert(not V.window or not V.window:IsShown())
B:VendorAction('repair'); Drain(); assert(TEST.repair==0 and B.window.repair.text=='Repair gear')
V:CloseMerchant(); B:VendorAction('restock'); assert(B.status:find('merchant',1,true))
"""


checks['Bag tools buyback and visit history remain embedded'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,3); Open()
B:VendorAction('sell'); V:ConfirmSaleReview(); Drain(); B:ShowTools(); local tools=B.window.tools
assert(tools:IsShown() and tools.rows[1].item and tools.rows[1].item.count==3)
Click(tools.rows[1].buy); Drain(); assert(V:CountItem(1)==3 and not tools.rows[1].item)
V:CloseMerchant(); Drain(); Click(FindButton(tools,'History'))
assert(tools.rows[1].text:GetText():find('Sold:',1,true))
Click(FindButton(tools,'Back to bags')); assert(not tools:IsShown())
"""
checks['Logo shared across suite and addon notes remain compact'] = r"""
local FS=ForeverSuite
assert(FS.icon=='Interface\\AddOns\\ForeverSuite\\Assets\\Icon-FS.tga')
assert(FS.minimapButton.normalTexture==FS.icon)
"""


checks['Central fs dashboard configures modules in one window with click effects and reload'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
B:ShowWindow(); SlashCmdList.FOREVERSUITE(''); local f=FS.window
assert(f:IsShown() and not B.window:IsShown() and f.cards.Bags and f.cards.Vendor)
Click(f.cards.Bags.card)
assert(f.settings:IsShown() and f.settings.parent==f and f.cards.Bags.animation:IsPlaying())
assert(f.cards.Bags.flash:IsShown() and f.settings.title:GetText()=='Bag settings')
assert(not B.window:IsShown() and (not V.window or not V.window:IsShown()))
Click(f.cards.Vendor.card); assert(f.settings.title:GetText()=='Vendor settings')
local setting=f.settings.fields.restockBudget; setting:SetText('7')
f.settings.fields.repairLimit:SetText('3'); f.settings.fields.moneyReserve:SetText('1'); f.settings.intensity:SetText('0.6')
Click(FindButton(f.settings,'Save advanced settings')); assert(V:Settings().restockBudget==70000)
Click(FindButton(f.settings,'Back to Control Center')); assert(not f.settings:IsShown() and f:IsShown())
TEST.reloads=0; Click(f.reload); assert(TEST.reloads==1)
SlashCmdList.FOREVERSUITE(''); assert(f:IsShown())
"""
checks['Central module disable preserves rules and stops actions, opening and highlights'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,30); V:SetRule(1,true,20,0)
FS:ShowConfig(); local f=FS.window
Click(f.cards.Bags.toggle); assert(not FS:IsModuleEnabled('Bags') and f.cards.Bags.toggle:GetText()=='Disabled')
B:ShowWindow(); assert(not B.window:IsShown())
Open(); assert(not B.window:IsShown())
Click(f.cards.Vendor.toggle); assert(not FS:IsModuleEnabled('Vendor') and not V:CanTransact())
V:StartSelling(); Drain(); assert(V:CountItem(1)==30)
assert(V:Settings().rules[1].keep==20)
Click(f.cards.Bags.toggle); assert(FS:IsModuleEnabled('Bags'))
V:OpenMerchant(); Drain(); assert(B.window:IsShown())
FS:ShowConfig(); Click(f.cards.Vendor.toggle); assert(FS:IsModuleEnabled('Vendor'))
Click(f.cards.Bags.card); assert(f:IsShown() and f.settings:IsShown() and f.settings.module=='Bags')
"""

checks['Beginner bag controls reveal actions only when relevant'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,3); B:ShowWindow(); local f=B.window
assert(not ForeverSuite.db.bags.showEmpty and #B.view.rows==1)
assert(not f.previous:IsShown() and not f.next:IsShown() and not f.pages:IsShown())
assert(not f.filterMenu:IsShown() and not f.itemMore:IsShown())
for _,control in ipairs(f.basic) do assert(not control:IsShown()) end
for _,control in ipairs(f.advanced) do assert(not control:IsShown()) end
for _,control in ipairs(f.merchantButtons) do assert(not control:IsShown()) end
Click(f.cells[1]); assert(f.use:IsShown() and not f.sell:IsShown() and f.itemMore:IsShown())
for _,control in ipairs(f.advanced) do assert(not control:IsShown()) end
Click(f.itemMore); for _,control in ipairs(f.advanced) do assert(control:IsShown()) end
Click(f.cells[1]); for _,control in ipairs(f.advanced) do assert(not control:IsShown()) end
Open(); assert(f.sell:IsShown() and not f.use:IsShown())
V:CloseMerchant(); Drain(); assert(not f.sell:IsShown())
Click(FindButton(f,'More options')); assert(f.options:IsShown())
Click(f.empty); assert(ForeverSuite.db.bags.showEmpty and #B.view.rows==16)
Click(f.empty); assert(not ForeverSuite.db.bags.showEmpty and #B.view.rows==1)
"""
checks['Separate module settings, disabled configuration and return navigation'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
FS:ShowConfig(); local f=FS.window
assert(not f.cards.Bags.open and not f.cards.Vendor.open)
Click(f.cards.Bags.card); local s=f.settings; assert(s.module=='Bags' and not s.advanced and not s.mode:IsShown())
local n=0; for _,entry in ipairs(s.toggles) do if entry.control:IsShown() then n=n+1; assert(entry.key:find('bags.',1,true)==1 or entry.key=='glow.enabled') end end
assert(n==4 and not s.save:IsShown() and not s.launch)
Click(s.more); assert(s.advanced and s.intensity:IsShown() and not s.fields.repairLimit:IsShown())
Click(s.back); assert(f:IsShown() and not s:IsShown())
FS:SetModuleEnabled('Vendor',false); Click(f.cards.Vendor.card)
assert(s.module=='Vendor' and s.mode:IsShown() and not s.advanced)
n=0; for _,entry in ipairs(s.toggles) do if entry.control:IsShown() then n=n+1; assert(not entry.key:find('bags.',1,true) and not entry.key:find('glow.',1,true)) end end
assert(n==4)
FS:SetModuleEnabled('Vendor',true); V:ShowWindow(false); assert(not f:IsShown() and V.window:IsShown())
Click(V.window.tabs.Settings); assert(f:IsShown() and not V.window:IsShown() and s.module=='Vendor')
B:ShowWindow(); assert(not f:IsShown() and not V.window:IsShown())
Click(B.window.back); assert(f:IsShown() and not B.window:IsShown())
V:ShowWindow(false); Click(V.window.back); assert(f:IsShown() and not V.window:IsShown())
"""
checks['Old bag preferences migrate once and preserve saved item rules'] = r"""
ResetTest(); local FS=ForeverSuite
ForeverSuiteDB={bags={showEmpty=true,categoryOverrides={[1]='Materials'}},vendor={rules={[1]={junk=true,keep=2,target=5}}}}
FS:InitializeDatabase(); assert(not FS.db.bags.showEmpty and FS.db.bags.replaceNative and FS.db.bags.uiVersion==1)
assert(FS.db.bags.categoryOverrides[1]=='Materials' and FS.db.vendor.rules[1].keep==2)
FS.db.bags.showEmpty=true; FS:InitializeDatabase(); assert(FS.db.bags.showEmpty)
"""
checks['Native bag hooks toggle once, respect combat and leave bank bags alone'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags
local names={'ToggleAllBags','ToggleBackpack','ToggleBag','OpenAllBags','OpenBackpack','OpenBag','CloseBag','CloseAllBags','CloseBackpack','ContainerFrameCombinedBags','ContainerFrame1','ContainerFrame2','NUM_CONTAINER_FRAMES','ContainerFrame_AllowedToOpenBags','hooksecurefunc'}
local old={}; for _,name in ipairs(names) do old[name]=_G[name] end
ContainerFrameCombinedBags=CreateFrame('Frame'); ContainerFrameCombinedBags:Hide()
ContainerFrame1=CreateFrame('Frame'); ContainerFrame1:SetID(77); ContainerFrame1.bag=0; ContainerFrame1:Hide()
ContainerFrame2=CreateFrame('Frame'); ContainerFrame2:SetID(0); ContainerFrame2.bag=-1; ContainerFrame2:Show(); NUM_CONTAINER_FRAMES=2
function OpenBackpack() if not ContainerFrameCombinedBags:IsShown() then ToggleBackpack() end end
function OpenBag(id) if id>=0 then OpenBackpack() else ContainerFrame2:Show() end end
function CloseBag(id) if id>=0 then CloseBackpack() else ContainerFrame2:Hide() end end
function CloseBackpack() ContainerFrameCombinedBags:Hide(); ContainerFrame1:Hide() end
function OpenAllBags() OpenBackpack() end
function CloseAllBags(owner) if owner=='wrong-owner' then return false end; CloseBackpack(); return true end
function ToggleBackpack() if ContainerFrameCombinedBags:IsShown() then CloseBackpack() else ContainerFrameCombinedBags:Show(); ContainerFrame1:Show() end end
function ToggleBag(id) if id<0 then ContainerFrame2:Show() else ToggleBackpack() end end
function ToggleAllBags() ToggleBackpack() end
function ContainerFrame_AllowedToOpenBags() return TEST.bagsAllowed~=false end
local hookCount=0
function hooksecurefunc(name,callback)
    hookCount=hookCount+1; local original=_G[name]
    _G[name]=function(...) local result={original(...)}; callback(...); return unpack(result) end
end
B.nativeHooks=nil; B.nativeQueued=false; B.nativeIntent=nil; B:InstallNativeHooks(); assert(hookCount==9)
B:InstallNativeHooks(); assert(hookCount==9)
B.window:Hide(); ToggleAllBags(); assert(not ContainerFrameCombinedBags:IsShown() and not ContainerFrame1:IsShown()); Drain()
assert(B.window:IsShown() and not ContainerFrameCombinedBags:IsShown() and not ContainerFrame1:IsShown() and ContainerFrame2:IsShown())
ToggleAllBags(); Drain(); assert(not B.window:IsShown())
OpenAllBags(); Drain(); assert(B.window:IsShown())
OpenBackpack(); Drain(); assert(B.window:IsShown(), 'Outer open must win over the inner ToggleBackpack')
for i=1,100 do ContainerFrameCombinedBags:Show(); assert(not ContainerFrameCombinedBags:IsShown()) end
assert(#TEST.timers==0 and B.window:IsShown(), 'Native re-show must not start a timer loop')
assert(CloseAllBags('wrong-owner')==false); Drain(); assert(B.window:IsShown())
CloseAllBags('correct-owner'); Drain(); assert(not B.window:IsShown())
ContainerFrameCombinedBags:Show(); Drain(); assert(B.window:IsShown() and not ContainerFrameCombinedBags:IsShown())
ToggleBag(-1); OpenBag(-1); Drain(); assert(B.window:IsShown() and ContainerFrame2:IsShown())
EnterCombat(); OpenAllBags(); Drain(); assert(not B.window:IsShown() and ContainerFrameCombinedBags:IsShown())
TEST.combat=false; CloseAllBags(); Drain(); FS.db.bags.replaceNative=false
ToggleAllBags(); Drain(); assert(ContainerFrameCombinedBags:IsShown() and not B.window:IsShown())
FS.db.bags.replaceNative=true; FS:SetModuleEnabled('Bags',false); ToggleAllBags(); ToggleAllBags(); Drain()
assert(ContainerFrameCombinedBags:IsShown() and not B.window:IsShown())
FS:SetModuleEnabled('Bags',true); TEST.bagsAllowed=false; OpenAllBags(); Drain(); assert(not B.window:IsShown())
TEST.bagsAllowed=nil; CloseAllBags(); Drain(); B.nativeHooks=nil
for _,name in ipairs(names) do _G[name]=old[name] end
"""

checks['Sidebar inventory collapses categories and preserves scale and position'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags
TEST.data[1]={quality=1,price=1,classID=2}; TEST.data[2]={quality=1,price=1,classID=7}
AddItem(1,1,1); AddItem(2,2,20); B:ShowWindow(); local f=B.window
assert(f:GetWidth()==820 and f:GetHeight()==500 and f.scale==0.85)
assert(f.point[1]=='BOTTOMRIGHT' and not f.itemPanel:IsShown())
assert(f.cells[1]:GetWidth()==38 and f.cells[1]:GetHeight()==38 and f.cells[1].count:GetText()=='')
local initialHeight=f:GetHeight(); Click(f.headers[2]); assert(B.collapsed.Gear and f:GetHeight()==initialHeight)
assert(f.cells[1].row.id==2); Click(f.headers[2]); assert(not B.collapsed.Gear and f.cells[1].row.id==1)
Click(f.cells[1]); assert(f.itemPanel:IsShown() and f:GetHeight()==initialHeight)
Click(FindButton(f,'More options')); Click(f.size); assert(FS.db.bags.scale==1 and f.scale==1)
local originalCenter=f.GetCenter; f.GetCenter=function() return 800,600 end
f.scripts.OnDragStop(f); local x,y=FS.db.bags.x,FS.db.bags.y; assert(x==300 and y==200); f.GetCenter=originalCenter
FS:InitializeDatabase(); assert(FS.db.bags.scale==1 and FS.db.bags.x==x and FS.db.bags.y==y)
Click(f.size); Click(f.size); assert(FS.db.bags.scale==0.7)
Click(FindButton(f.options,'Reset position')); assert(f.point[1]=='BOTTOMRIGHT' and FS.db.bags.x==0 and FS.db.bags.y==0)
FS.db.bags.scale=0/0; B:NormalizeSettings(); assert(FS.db.bags.scale==0.85)
"""

checks['Secure Hearthstone clicks, item button, stale slots, merchant separation and unique Keep tooltip'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
MerchantFrame:Hide(); TEST.data[6948]={quality=1,price=0}; AddItem(1,6948,1)
B:ShowWindow(); local f=B.window; local c=f.cells[1]
assert(c.template:find('SecureActionButtonTemplate',1,true))
assert(c:GetAttribute('type2')=='item' and c:GetAttribute('item2')=='0 1' and not c:GetAttribute('type1'))
TEST.secureUses=0
c.scripts.PreClick(c,'RightButton'); c.scripts.OnClick(c,'RightButton',false)
assert(TEST.secureUses==1 and TEST.lastSecureItem=='0 1' and #TEST.actions==0)
f.use.scripts.PreClick(f.use,'LeftButton'); Click(f.use); assert(TEST.secureUses==2)
AddItem(1,6948,1); c.scripts.PreClick(c,'RightButton'); assert(not c:GetAttribute('type2'), 'Changed GUID cannot use a stale selection')
B:Refresh(); V:KeepItem(6948); B:Refresh(); GameTooltip.lines={}
c.scripts.OnEnter(c); local n=0; for _,line in ipairs(GameTooltip.lines) do if line=='Always Keep' then n=n+1 end end
assert(n==1)
MerchantFrame:Show(); c.scripts.PreClick(c,'RightButton'); assert(not c:GetAttribute('type2'))
f.use.scripts.PreClick(f.use,'LeftButton'); assert(not f.use:GetAttribute('type1'))
EnterCombat(); assert(not f:IsShown()); B:Refresh(); B:ShowWindow(); FS:ShowConfig()
assert(not f:IsShown()); TEST.combat=false; MerchantFrame:Hide(); B:ShowWindow()
assert(f:IsShown() and c:GetAttribute('type2')=='item')
"""

checks['Bag equipment right-click equips the exact copy once and toolbar uses the same route'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; MerchantFrame:Hide()
TEST.data[600]={quality=1,price=10,equippable=true}; AddItem(1,600,1); AddItem(2,600,1)
B:ShowWindow(); local c=B.window.cells[2]; local row=c.row
local exact=TEST.bags[row.bag][row.slot]; TEST.actions={}; local secure=TEST.secureUses or 0
assert(not c:GetAttribute('type2'), 'Equipment must not also run the generic secure item action')
c.scripts.PreClick(c,'RightButton'); c.scripts.OnClick(c,'RightButton',true)
assert(#TEST.actions==0, 'Mouse-down must not equip')
c.scripts.OnClick(c,'RightButton',false)
assert(#TEST.actions==1 and TEST.actions[1].kind=='equip' and TEST.equippedItem==exact)
assert((TEST.secureUses or 0)==secure and TEST.bags[0][1], 'Other copy stays in the bag')
B.selected=ForeverSuite.modules.Vendor:ReadItem(0,1); B:Refresh(); local use=B.window.use
use.scripts.PreClick(use,'LeftButton'); use:Click('LeftButton')
assert(#TEST.actions==2 and not TEST.bags[0][1])
"""

checks['Bag bind-on-equip leaves confirmation to the client and supports cancel or accept'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; MerchantFrame:Hide(); TEST.bindPrompt=nil; TEST.equippedItem=nil
TEST.data[601]={quality=2,price=10,equippable=true,bindOnEquip=true}; AddItem(1,601,1)
B:ShowWindow(); local c=B.window.cells[1]; local item=TEST.bags[0][1]
c.scripts.PreClick(c,'RightButton'); c.scripts.OnClick(c,'RightButton',false)
assert(TEST.bindPrompt and TEST.bindPrompt.bag==0 and TEST.bindPrompt.slot==1)
assert(TEST.bags[0][1]==item and not TEST.equippedItem, 'Addon must not accept binding')
TEST.bindPrompt=nil -- Player cancels the simulated native dialog.
assert(TEST.bags[0][1]==item)
c.scripts.PreClick(c,'RightButton'); c.scripts.OnClick(c,'RightButton',false)
local prompt=TEST.bindPrompt; TEST.bindPrompt=nil; prompt.accept()
assert(TEST.equippedItem==item and not TEST.bags[0][1])
"""

checks['Bag equip guards block stale locked cursor targeting vendor and combat actions'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local V=ForeverSuite.modules.Vendor; MerchantFrame:Hide()
TEST.data[602]={quality=1,price=10,equippable=true}; AddItem(1,602,1)
local row=V:ReadItem(0,1); TEST.actions={}
TEST.combat=true; B:EquipBagItem(row); TEST.combat=false
V.busy=true; B:EquipBagItem(row); V.busy=false
V.pending={}; B:EquipBagItem(row); V.pending=nil
TEST.cursor={}; B:EquipBagItem(row); TEST.cursor=nil
local repair=InRepairMode; InRepairMode=function() return true end; B:EquipBagItem(row); InRepairMode=repair
local target=SpellIsTargeting; SpellIsTargeting=function() return true end; B:EquipBagItem(row); SpellIsTargeting=target
MerchantFrame:Show(); B:EquipBagItem(row); MerchantFrame:Hide()
TEST.bags[0][1].isLocked=true; B:EquipBagItem(row); TEST.bags[0][1].isLocked=false
AddItem(1,602,1); B:EquipBagItem(row)
assert(#TEST.actions==0, 'Invalid equipment action reached the client')
B:EquipBagItem(V:ReadItem(0,1)); assert(#TEST.actions==1)
"""

checks['Favorites lead categories, seed Hearthstone once and persist explicit removal'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
TEST.data[6948]={quality=1,price=0}; TEST.data[2]={quality=1,price=10,classID=2}
AddItem(1,6948,1); AddItem(2,2,1); B:ShowWindow(); local f=B.window
assert(FS.db.bags.favorites[6948] and B.view.rows[1].id==6948 and f.headers[1].category=='Favorites')
Click(f.cells[2]); Click(f.favorite); assert(FS.db.bags.favorites[2] and B:Category(V:ReadItem(0,2))=='Favorites')
assert(not V:Settings().alwaysKeep[2] and not V:Settings().rules[2])
Click(f.favorite); assert(FS.db.bags.favorites[2]==false)
B.selected=V:ReadItem(0,1); B:ToggleFavorite(); assert(FS.db.bags.favorites[6948]==false)
FS:InitializeDatabase(); assert(FS.db.bags.favorites[6948]==false)
B:Refresh(); assert(f.headers[1].category=='Favorites' and f.headers[1]:GetText():find('(0)',1,true))
B.selected=V:ReadItem(0,2); B:ToggleFavorite(); FS.db.bags.category='Favorites'; B:Refresh()
assert(#B.view.rows==1 and B.view.rows[1].id==2)
FS.db.bags.favorites.bad=true; FS.db.bags.favorites[3]='bad'; B:NormalizeSettings()
assert(FS.db.bags.favorites.bad==nil and FS.db.bags.favorites[3]==nil)
"""

checks['All client item classes and misc subtypes have deterministic automatic categories'] = r"""
ResetTest(); local FS=ForeverSuite; local B=FS.modules.Bags; local V=FS.modules.Vendor
local expected={[0]='Consumables',[1]='Bags',[2]='Gear',[3]='Gems',[4]='Gear',[5]='Materials',[6]='Ammo',[7]='Materials',[8]='Enhancements',[9]='Recipes',[10]='Currency',[11]='Bags',[12]='Quest Items',[13]='Keys',[14]='Other',[15]='Other',[16]='Glyphs',[17]='Pets',[18]='Currency',[19]='Professions',[20]='Housing'}
for class=0,20 do assert(B:Category({id=100+class,classID=class})==expected[class]) end
local misc={[1]='Materials',[2]='Pets',[3]='Holiday',[5]='Mounts',[6]='Enhancements'}
for sub,name in pairs(misc) do assert(B:Category({id=100,classID=15,subclassID=sub})==name) end
assert(B:Category({id=100,classID=0,subclassID=6})=='Enhancements')
assert(B:Category({id=100,classID=99})=='Other')
TEST.data[2512]={quality=1,price=1,classID=6,subclassID=2}; AddItem(1,2512,200)
local row=V:ReadItem(0,1); assert(row.subclassID==2 and B:Category(row)=='Ammo')
B.selected=row; B:AssignCategory('Ammo'); B:NormalizeSettings(); assert(FS.db.bags.categoryOverrides[2512]=='Ammo')
B:AssignCategory('Automatic'); FS.db.bags.category='Ammo'; B:ShowWindow(); assert(#B.view.rows==1 and B.view.rows[1].id==2512)
V:KeepItem(2512); assert(B:Category(V:BuildPlan().bySlot['0:1'])=='Ammo')
FS.db.bags.favorites[2512]=true; assert(B:Category(row)=='Favorites')
FS.db.bags.favorites[2512]=false; row.quest=true; assert(B:Category(row)=='Quest Items')
row.quest=false; row.sellCount=1; assert(B:Category(row)=='Junk')
local rows={}; for class=0,20 do rows[#rows+1]={id=100+class,classID=class,name='Class '..class,bag=0,slot=class+1} end
local order={}; for i,name in ipairs(B.categories) do order[name]=i end
 table.sort(rows,function(a,b) return order[B:Category(a)]<order[B:Category(b)] end)
local seen=0; for _,page in ipairs(B:Layout({rows=rows})) do for _,cell in ipairs(page.cells) do assert(cell.x+38<=536 and cell.y+38<=480); seen=seen+1 end end
assert(seen==21)
"""

checks['Bag cooldowns use exact slots, expire, clear recycled cells and respect preferences'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local FS=ForeverSuite
TEST.data[6948]={quality=1,price=0}; AddItem(1,6948,1)
TEST.cooldowns['0:1']={start=TEST.now,duration=60,enabled=1}; B:ShowWindow(); local c=B.window.cells[1]
assert(c.cooldown:IsShown() and c.cooldown.cooldownDuration==60)
FS.db.bags.showCooldowns=false; B:Refresh(); assert(not c.cooldown:IsShown())
FS.db.bags.showCooldowns=true; B:Refresh(); assert(c.cooldown:IsShown())
TEST.now=TEST.now+61; B:Refresh(); assert(not c.cooldown:IsShown())
TEST.cooldowns['0:1']={start=TEST.now,duration=math.huge,enabled=1}; B:Refresh(); assert(not c.cooldown:IsShown())
TEST.bags[0][1]=nil; B:Refresh(); assert(not c.cooldown:IsShown() and not c.newLoot:IsShown())
"""
checks['New loot follows item GUIDs, survives native flag clearing and is acknowledged on hover'] = r"""
ResetTest(); local B=ForeverSuite.modules.Bags; local FS=ForeverSuite; local V=FS.modules.Vendor
TEST.data[1]={quality=1,price=1}; AddItem(1,1,1); TEST.newItems['0:1']=true
B:ScanNewItems(); TEST.newItems['0:1']=nil; B:ShowWindow(); local c=B.window.cells[1]
assert(c.newLoot:IsShown())
TEST.bags[0][2]=TEST.bags[0][1]; TEST.bags[0][1]=nil; B:ScanNewItems(); B:Refresh(); assert(B:IsNewLoot(V:ReadItem(0,2)))
FS.db.bags.showNewLoot=false; B:Refresh(); assert(not c.newLoot:IsShown())
FS.db.bags.showNewLoot=true; B:Refresh(); c.scripts.OnEnter(c); assert(not c.newLoot:IsShown() and not B:IsNewLoot(c.row))
B:ScanNewItems(); B:Refresh(); assert(not c.newLoot:IsShown())
AddItem(3,1,1); B:ScanNewItems(); assert(not B:IsNewLoot(V:ReadItem(0,3)))
"""
checks['Junk review previews reserved quantities and values, cancels and revalidates changed plans'] = r"""
ResetTest(); local V=ForeverSuite.modules.Vendor; local B=ForeverSuite.modules.Bags
TEST.data[1]={quality=0,price=10}; TEST.data[2]={quality=1,price=100}; AddItem(1,1,30); AddItem(2,2,1)
V:SetRule(1,true,20,0); Open(); B:VendorAction('sell'); local f=V.saleReview
assert(f:IsShown() and #TEST.actions==0 and f.summary:GetText():find('100c',1,true)==nil)
assert(f.summary:GetText():find('10 items',1,true) and f.summary:GetText():find('0g 1s 0c',1,true))
assert(f.rows[1].text:GetText():find('x10',1,true) and f.rows[2].text:GetText()=='')
Click(f.cancel); assert(V:CountItem(1)==30)
V:ReviewSales(); V:SetRule(1,true,25,0); Click(f.confirm); assert(f:IsShown() and #TEST.actions==0 and f.feedback)
Click(f.confirm); Drain(); assert(V:CountItem(1)==25 and not f:IsShown())
V:ReviewSales(); V:CloseMerchant(); Click(f.confirm); assert(not f:IsShown() and V:CountItem(1)==25)
"""
checks['Reviewed sales exclude new junk arriving after confirmation'] = r"""
ResetTest(); local V=ForeverSuite.modules.Vendor
TEST.data[1]={quality=0,price=10}; AddItem(1,1,2); Open(); V:ReviewSales(); V:ConfirmSaleReview()
AddItem(2,1,3); Drain(); assert(V:CountItem(1)==3 and #TEST.actions==1 and TEST.actions[1].count==2)
"""
checks['Gear durability totals, broken slots, empty values and warning rearming'] = r"""
ResetTest(); local G=ForeverSuite.modules.Gear; local FS=ForeverSuite
TEST.data[1]={quality=1,price=10}; TEST.equipment={[1]={id=1,current=20,maximum=100},[5]={id=1,current=0,maximum=50},[2]={id=1}}
local d=G:Snapshot(); assert(d.equipped==3 and d.damaged==2 and d.broken==1 and d.lowest==0)
assert(math.abs(d.percent-20/150*100)<0.001 and #d.items==19)
G.warned=false; local before=#DEFAULT_CHAT_FRAME.lines; G:Refresh(); G:Refresh(); assert(#DEFAULT_CHAT_FRAME.lines==before+1)
TEST.equipment[1].current=100; TEST.equipment[5].current=50; G:Refresh(); assert(not G.warned)
TEST.equipment[1].current=10; G:Refresh(); assert(G.warned and #DEFAULT_CHAT_FRAME.lines==before+2)
TEST.equipment={}; G:Refresh(); assert(G.data.percent==nil and G.indicator:GetText()=='Gear: --')
TEST.equipment={[1]={id=1,current=0/0,maximum=100}}; assert(G:Snapshot().percent==nil)
"""
checks['Gear card opens dedicated settings, indicator opens overview and repairs share Vendor limits'] = r"""
ResetTest(); local FS=ForeverSuite; local G=FS.modules.Gear; local V=FS.modules.Vendor
FS:ShowConfig(); local f=FS.window; assert(f.cards.Gear and not f.cards.Gear.open)
Click(f.cards.Gear.card); assert(f.gearSettings:IsShown() and (not f.settings or not f.settings:IsShown()))
Click(f.gearSettings.threshold); assert(FS.db.gear.warningPercent==50)
Click(f.gearSettings.back); assert(not f.gearSettings:IsShown())
Click(G.indicator); assert(G.window:IsShown() and not f:IsShown())
Click(G.window.settings); assert(f.gearSettings:IsShown() and not G.window:IsShown())
FS:SetModuleEnabled('Gear',false); assert(not G.indicator:IsShown()); Click(f.cards.Gear.card); assert(f.gearSettings:IsShown())
FS:SetModuleEnabled('Gear',true); assert(G.indicator:IsShown())
Open(); TEST.repair=60000; G:ShowWindow(); Click(G.window.repair); assert(V.repairConfirmation and G.window.repair:GetText()=='Confirm Repair')
Click(G.window.repair); Drain(); assert(TEST.repair==0)
G:Refresh(); assert(not G.window.repair:IsShown() or G.window.repair:GetText()=='Repair gear')
FS:InitializeDatabase(); assert(FS.db.gear.warningPercent==50)
"""

checks['Unit frames use class colors, enemy red, health text, power and secure target actions'] = r"""
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames
U:SettingsChanged(); local p,t=U.frames.player,U.frames.target
assert(p:GetAttribute('unit')=='player' and p:GetAttribute('type1')=='target' and t:GetAttribute('type2')=='togglemenu')
assert(p.watched and t.watched and p.health.value==80 and p.value:GetText()=='80 | 80%')
assert(p.health.barColor[1]==.25 and t.health.barColor[1]==.85 and p.power.value==50)
TEST.units.target.player=true; TEST.units.target.class='WARRIOR'; U:RefreshUnit('target')
assert(t.health.barColor[1]==.78)
TEST.units.target.player=false; TEST.units.target.enemy=false; TEST.units.target.reaction=4; U:RefreshUnit('target'); assert(t.health.barColor[1]==.95)
TEST.units.target.dead=true; U:RefreshUnit('target'); assert(t.value:GetText()=='Dead')
TEST.units.target.dead=false; TEST.units.target.enemy=true
TEST.units.target.maxHealth=0; U:RefreshUnit('target'); assert(t.value:GetText()=='')
TEST.units.target.maxHealth=100
assert(PlayerFrame.alpha==0 and not PlayerFrame:IsMouseEnabled())
PlayerFrame:SetAlpha(1); assert(PlayerFrame.alpha==0)
FS:SetModuleEnabled('UnitFrames',false); assert(not p.watched and not p:IsShown() and PlayerFrame.alpha==1 and PlayerFrame:IsMouseEnabled())
FS:SetModuleEnabled('UnitFrames',true); assert(p:IsShown() and p.watched)
"""
checks['Unit frame layout and disable defer combat changes and preserve saved placement'] = r"""
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; U:SettingsChanged()
local before=U.frames.player.point[4]; TEST.combat=true; FS.db.unitFrames.player.x=-500; FS.db.unitFrames.scale=1.2; U:SettingsChanged()
assert(U.pending and U.frames.player.point[4]==before)
TEST.units.player.health=25; U.events.scripts.OnEvent(U.events,'UNIT_HEALTH','player'); assert(U.frames.player.health.value==25)
FS:SetModuleEnabled('UnitFrames',false); assert(U.frames.player.watched)
TEST.combat=false; U.events.scripts.OnEvent(U.events,'PLAYER_REGEN_ENABLED'); assert(not U.pending and not U.frames.player.watched)
FS:SetModuleEnabled('UnitFrames',true); assert(U.frames.player.point[4]==-500 and U.frames.player.scale==1.2)
FS:InitializeDatabase(); assert(FS.db.unitFrames.player.x==-500)
TEST.units.player.health=80
"""
checks['Native bar styling leaves game positions flags actions and paging untouched'] = r"""
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars; local bar=MainActionBar; local point={bar:GetPoint()}; local scale=bar:GetScale()
A:SettingsChanged(); assert(bar.point[4]==point[4] and bar.point[5]==point[5] and bar:GetScale()==scale and bar.EndCaps.alpha==0)
for i,b in ipairs(bar.actionButtons) do assert(b:GetAttribute('action')==i and A.buttons[b].border:IsShown()) end
bar:SetPoint('BOTTOM',UIParent,'BOTTOM',100,5); Drain(); assert(bar.point[4]==100 and bar.point[5]==5)
TEST.combat=true; A:SettingsChanged(); assert(A.pending); TEST.combat=false; A.events.scripts.OnEvent(A.events,'PLAYER_REGEN_ENABLED'); assert(not A.pending and bar.point[4]==100)
FS:SetModuleEnabled('ActionBars',false); assert(bar.point[4]==100 and bar:GetScale()==scale and bar.EndCaps.alpha==1)
for i,b in ipairs(bar.actionButtons) do assert(b:GetAttribute('action')==i and not A.buttons[b].border:IsShown()) end
FS:SetModuleEnabled('ActionBars',true)
"""
checks['Custom main menu icons anchor top-left and preserve native clicks, disabled states and restoration'] = r"""
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
MicroMenuContainer=CreateFrame('Frame'); MicroMenuContainer:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-20,10)
CharacterMicroButton=CreateFrame('Button','CharacterMicroButton',MicroMenuContainer); CharacterMicroButton:SetSize(25,40); CharacterMicroButton:SetPoint('LEFT',MicroMenuContainer,'LEFT',0,0)
CharacterMicroButton.normalRegion=CharacterMicroButton:CreateTexture()
MainMenuMicroButton=CreateFrame('Button','MainMenuMicroButton',MicroMenuContainer); MainMenuMicroButton:SetSize(25,40)
local count=0; CharacterMicroButton:SetScript('OnClick',function() count=count+1 end)
A:SettingsChanged(); assert(MicroMenuContainer.point[1]=='BOTTOMRIGHT' and CharacterMicroButton.point[1]=='TOPLEFT')
local s=A.menuButtons[CharacterMicroButton]; assert(s.proxy==CharacterMicroButton and not s.proxy:GetAttribute('clickbutton') and s.proxy:IsMouseEnabled() and s.icon.texture==FS.menuAtlas)
Click(s.proxy); TEST.combat=true; Click(s.proxy); TEST.combat=false; assert(count==2 and CharacterMicroButton.alpha==1 and CharacterMicroButton:GetWidth()==36)
CharacterMicroButton:SetEnabled(false); s.proxy.scripts.OnUpdate(s.proxy,.3); assert(s.icon.desaturated)
FS.db.actionBars.menu=false; A:SettingsChanged(); assert(not s.icon:IsShown() and CharacterMicroButton:GetWidth()==25 and CharacterMicroButton.alpha==1 and MicroMenuContainer.point[1]=='BOTTOMRIGHT')
FS.db.actionBars.menu=true; A:SettingsChanged(); assert(s.proxy:IsShown())
"""
checks['Custom nameplates hide native visuals, preserve clicks, colors and pooled frame restoration'] = r"""
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
local plate=CreateFrame('Frame'); local native=CreateFrame('Button',nil,plate); plate.UnitFrame=native
native.unit='target'; native.HealthBarsContainer={healthBar=CreateFrame('StatusBar',nil,native)}
local clicks=0; native:SetScript('OnClick',function() clicks=clicks+1 end)
TEST.plates={plate}; TEST.plateMap={target=plate}; N:SettingsChanged()
local saved=N.custom[plate]; local f=saved.canvas
assert(native:GetAlpha()==0 and f:IsShown() and f.health.barColor[1]==.85 and f.icon==nil and f.health:GetWidth()==186)
native:SetAlpha(1); assert(native:GetAlpha()==0); native:Click(); assert(clicks==1)
TEST.units.target.player=true; TEST.units.target.class='WARRIOR'; FS.db.nameplates.enemies=true; FS.db.nameplates.friendlyPlayers=true
N.events.scripts.OnEvent(N.events,'UNIT_FACTION','target'); assert(f.health.barColor[1]==.78)
N.events.scripts.OnEvent(N.events,'NAME_PLATE_UNIT_REMOVED','target'); assert(not saved.unit and not f:IsShown() and native:GetAlpha()==1)
N.events.scripts.OnEvent(N.events,'NAME_PLATE_UNIT_ADDED','target'); assert(saved.unit=='target' and native:GetAlpha()==0)
local replacement=CreateFrame('Button',nil,plate); replacement.unit='target'; plate.UnitFrame=replacement
N:SettingsChanged(); assert(native:GetAlpha()==1 and replacement:GetAlpha()==0 and saved.native==replacement)
native:SetAlpha(.7); assert(native:GetAlpha()==.7)
FS:SetModuleEnabled('Nameplates',false); assert(replacement:GetAlpha()==1 and not f:IsShown())
TEST.units.target.player=false; FS:SetModuleEnabled('Nameplates',true); assert(f.health.barColor[1]==.85)
local forbidden=CreateFrame('Frame'); forbidden.IsForbidden=function() return true end; N:Update(forbidden,'target'); assert(not N.custom[forbidden])
TEST.plates={}; TEST.plateMap={}
"""
checks['HUD Settings cards navigate separately, scale, reset and move outside combat'] = r"""
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); local f=FS.window
for _,name in ipairs({'UnitFrames','ActionBars','Nameplates'}) do
    local m=FS.modules[name]; assert(not f.cards[name].open); Click(f.cards[name].card); assert(m.settings:IsShown())
end
assert(not FS.modules.UnitFrames.settings:IsShown() and not FS.modules.ActionBars.settings:IsShown())
FS:ConfigureModule('UnitFrames'); local U=FS.modules.UnitFrames; Click(U.settings.scale); assert(FS.db.unitFrames.scale==1.1)
Click(U.settings.move); assert(FS.Layout.active and FS.Layout.handles['Unit:player']:IsShown() and not f:IsShown())
FS.Layout:Stop(); assert(not FS.Layout.active)
FS:ConfigureModule('UnitFrames'); Click(U.settings.reset); assert(FS.db.unitFrames.scale==1 and FS.db.unitFrames.player.x==-430)
FS:ConfigureModule('ActionBars'); local A=FS.modules.ActionBars; Click(A.settings.menu); assert(not FS.db.actionBars.menu)
FS:ShowConfig(); assert(not A.settings:IsShown() and not U.settings:IsShown())
"""

checks['Unit cast bars display casts and channels and clear interruption without unsafe timing arithmetic'] = r"""
ResetTest(); local U=ForeverSuite.modules.UnitFrames; U:SettingsChanged()
local cast=true; local channel=false; TEST.now=1
UnitCastingInfo=function(unit) if unit=='target' and cast then return 'Fireball',nil,1,1000,4000 end end
UnitChannelInfo=function(unit) if unit=='target' and channel then return 'Channel',nil,1,1000,6000 end end
U.events.scripts.OnEvent(U.events,'UNIT_SPELLCAST_START','target')
local b=U.frames.target.cast; assert(b:IsShown() and b.label:GetText()=='Fireball' and b.minimum==0 and b.maximum==1 and not b.reverse)
TEST.now=2; b.scripts.OnUpdate(b); assert(math.abs(b.value-1/3)<.00001)
cast=false; U.events.scripts.OnEvent(U.events,'UNIT_SPELLCAST_INTERRUPTED','target'); assert(not b:IsShown())
channel=true; U.events.scripts.OnEvent(U.events,'UNIT_SPELLCAST_CHANNEL_START','target'); assert(b:IsShown() and not b.reverse and b.label:GetText()=='Channel' and b.maximum==1 and math.abs(b.value-.8)<.00001)
channel=false; U.events.scripts.OnEvent(U.events,'UNIT_SPELLCAST_CHANNEL_STOP','target'); assert(not b:IsShown())
UnitCastingInfo=nil; UnitChannelInfo=nil
"""
checks['Restricted health and class values bypass Lua comparisons while native bars still receive them'] = r"""
ResetTest(); local FS=ForeverSuite; local U=FS.modules.UnitFrames; local marker={}
local oldHealth,oldMax,oldClass,oldSecret=UnitHealth,UnitHealthMax,UnitClass,issecretvalue
issecretvalue=function(value) return value==marker end
UnitHealth=function() return marker end; UnitHealthMax=function() return marker end
UnitClass=function() return 'Unknown',marker end
U:RefreshUnit('player'); assert(U.frames.player.health.value==marker and U.frames.player.value:GetText()=='')
UnitHealth,UnitHealthMax,UnitClass,issecretvalue=oldHealth,oldMax,oldClass,oldSecret
U:RefreshUnit('player')
"""

checks['Custom Character shell and six direct page buttons preserve data and restore native pages'] = r"""
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character
CharacterFrame=CreateFrame('Frame'); CharacterFrame:SetSize(700,550); CharacterFrame:SetPoint('CENTER',UIParent,'CENTER',0,0)
CharacterFrame.NineSlice=CreateFrame('Frame',nil,CharacterFrame)
for i,page in ipairs(C.pages) do _G[page.frame]=CreateFrame('Frame',page.frame,CharacterFrame) end
local model=CreateFrame('PlayerModel',nil,PaperDollFrame); local equipment=CreateFrame('Button',nil,PaperDollFrame)
local opened={}
ToggleCharacter=function(page) opened[page]=(opened[page] or 0)+1; CharacterFrame.activeSubframe=page end
C:InstallHooks(); C:Apply(); assert(#C.tabs==6 and C.root:IsShown() and PaperDollFrame:GetAlpha()==0 and C.model~=model)
for i,b in ipairs(C.tabs) do b:Click(); assert(opened[C.pages[i].frame]==1 and C.page==i) end
assert(model.parent==PaperDollFrame and equipment.parent==PaperDollFrame and C.mounted.frame==StatisticsFrame and StatisticsFrame.parent==C.content)
C.tabs[1]:Click(); assert(C.character:IsShown() and not C.content:IsShown() and not C.mounted)
TEST.combat=true; FS:SetModuleEnabled('Character',false); assert(C.pending and C.root:IsShown())
TEST.combat=false; C:Apply(); assert(not C.root:IsShown() and CharacterFrame.NineSlice:GetAlpha()==1 and PaperDollFrame:GetAlpha()==1 and CharacterFrame:GetWidth()==700)
FS:SetModuleEnabled('Character',true); assert(C.root:IsShown())
"""
checks['Move Frames saves snapped positions and scale and cancels changes; nameplates have no handles'] = r"""
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; L:Start()
assert(L.active and L.overlay:IsShown() and not L.targets.NameplatePreview)
local handle=L.handles['Unit:player']
handle.GetCenter=function() return 563,683 end
L:Save('Unit:player',handle,1.2)
local saved=FS.db.layout.frames['Unit:player']; local centerY=UIParent:GetHeight()/2
assert(saved.x==64 and saved.y==centerY+math.floor((683-centerY)/32+.5)*32 and saved.scale==1.2)
L.overlay.close:Click(); assert(not L.active and not FS.db.layout.frames['Unit:player'] and not L.targets.NameplatePreview)
TEST.combat=true; L:Start(); assert(not L.active); TEST.combat=false
L:Start(); L.overlay.done:Click(); assert(not L.active and FS.window:IsShown())
"""
checks['Nameplate debuffs and casting clear recycled displays and stay centered with their own size preference'] = r"""
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
local plate=CreateFrame('Frame'); plate.UnitFrame=CreateFrame('Button',nil,plate); plate.UnitFrame.unit='target'
C_UnitAuras={GetAuraDataByIndex=function(_,i) if i==1 then return {icon=123,duration=10,expirationTime=TEST.now+10} end end}
FS.db.nameplates.scale=1.1
N:Update(plate,'target'); local f=N.custom[plate].canvas
assert(f.auras[1]:IsShown() and f.auras[1].icon.texture==123 and f.auras[1].cooldown:IsShown())
assert(f:GetScale()==1.1 and f.point[4]==0 and f.point[5]==0)
C_UnitAuras=nil; N:Update(plate,'target'); assert(not f.auras[1]:IsShown() and not f.auras[1].cooldown:IsShown())
N:Release(N.custom[plate]); FS.db.layout.frames['Unit:player']=nil
"""
checks['Move Frames follows dragging every frame and snaps only on release'] = r"""
ResetTest(); local FS=ForeverSuite; local L=FS.Layout; L:Start()
local h=L.handles['Unit:player']; local x=563
h.GetCenter=function() return x,683 end
local originalPoint=h.SetPoint; local anchors=0
h.SetPoint=function(...) anchors=anchors+1; originalPoint(...) end
h.scripts.OnDragStart(h); h.scripts.OnUpdate(h,.016)
assert(h.dragging and anchors==0 and FS.db.layout.frames['Unit:player'].x==63)
assert(L.targets['Unit:player'].frame.point[4]==63)
x=571; h.scripts.OnUpdate(h,.016); assert(L.targets['Unit:player'].frame.point[4]==71 and anchors==0)
h.scripts.OnDragStop(h); assert(not h.dragging and anchors==1 and FS.db.layout.frames['Unit:player'].x==64)
h.scripts.OnDragStart(h); L:Stop(); assert(not h.dragging)
h.SetPoint=originalPoint
"""
checks['Bag bar skins all managed buttons and dividers; Gear defaults to its left without overriding custom placement'] = r"""
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
BagsBar=CreateFrame('Frame'); BagsBar.Background=CreateFrame('Texture',nil,BagsBar)
local extra=CreateFrame('Button',nil,BagsBar); extra.icon=extra:CreateTexture(); extra.icon:SetTexture(777)
extra.normalRegion=extra:CreateTexture(); local original=extra:CreateTexture(); original.layer='BORDER'
local divider=CreateFrame('Frame',nil,BagsBar)
local function iterator(value) local emitted=false; return function() if not emitted then emitted=true; return value end end end
BagsBar.HorizontalDividersPool={EnumerateActive=function() return iterator(divider) end}
MainMenuBarBagManager={EnumerateBagButtons=function() local emitted=false; return function() if not emitted then emitted=true; return 1,extra end end end}
function BagsBar:UpdateDividers() divider:SetAlpha(1) end
A:SettingsChanged(); assert(extra.icon.texture==777 and original:GetAlpha()==0 and extra.normalRegion:GetAlpha()==0)
assert(A.bagSkins[extra].border:IsShown() and divider:GetAlpha()==0 and BagsBar.Background:GetAlpha()==0)
BagsBar:UpdateDividers(); assert(divider:GetAlpha()==1); Drain(); assert(divider:GetAlpha()==0)
local gear=FS.modules.Gear.indicator; assert(gear.point[1]=='RIGHT' and gear.point[2]==BagsBar and gear.point[3]=='LEFT')
FS.db.layout.frames.GearButton={x=-400,y=100,scale=1}; FS.Layout:Apply('GearButton'); A:SettingsChanged(); assert(gear.point[1]=='CENTER' and gear.point[4]==-400)
FS:SetModuleEnabled('ActionBars',false); assert(original:GetAlpha()==1 and divider:GetAlpha()==1 and not A.bagSkins[extra].border:IsShown())
MainMenuBarBagManager=nil; FS.db.layout.frames.GearButton=nil; FS:SetModuleEnabled('ActionBars',true)
"""
checks['Nameplate visibility settings distinguish enemies and friendly types, defer combat CVars and remove legacy offsets'] = r"""
ResetTest(); local FS=ForeverSuite; local N=FS.modules.Nameplates
FS.db.layout.frames.NameplatePreview={x=50,y=500,scale=1.4}; N:NormalizeSettings(); assert(not FS.db.layout.frames.NameplatePreview)
TEST.units.target.enemy=true; TEST.units.target.player=false; assert(N:Visible('target'))
TEST.units.target.enemy=false; assert(not N:Visible('target')); FS.db.nameplates.friendlyNPCs=true; assert(N:Visible('target'))
TEST.units.target.player=true; assert(not N:Visible('target')); FS.db.nameplates.friendlyPlayers=true; assert(N:Visible('target'))
FS.db.nameplates.enemies=false; TEST.units.target.enemy=true; assert(not N:Visible('target'))
local vars={nameplateShowEnemies='1',nameplateShowFriends='0',nameplateShowFriendlyPlayers='0',nameplateShowFriendlyNPCs='0'}
GetCVar=function(k) return vars[k] end; local writes=0; SetCVar=function(k,v) assert(not TEST.combat); writes=writes+1; vars[k]=v end
TEST.combat=true; N:SettingsChanged(); assert(writes==0)
TEST.combat=false; N.events.scripts.OnEvent(N.events,'PLAYER_REGEN_ENABLED'); assert(vars.nameplateShowEnemies=='0' and vars.nameplateShowFriends=='1')
FS:SetModuleEnabled('Nameplates',false); assert(vars.nameplateShowEnemies=='1' and vars.nameplateShowFriends=='0')
GetCVar=nil; SetCVar=nil; N.originalCVars=nil
FS:SetModuleEnabled('Nameplates',true); N:CreateSettings(FS.window); assert(N.settings.size and not N.settings.move)
TEST.units.target.enemy=true; TEST.units.target.player=false
"""
checks['Main menu defers native layout and artwork corrections outside the native update stack'] = r"""
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
local native=CharacterMicroButton; local saved=A.menuButtons[native]
A:SettingsChanged(); assert(native:GetParent()==A.menuRoot)
native:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-300,10)
assert(native.point[1]=='BOTTOMRIGHT'); Drain()
assert(native.point[1]=='TOPLEFT' and native.point[2]==A.menuRoot and native.point[4]==saved.slot*41)
native:SetWidth(90); native:SetHeight(80); native:SetScale(1.6)
assert(native:GetWidth()==90 and native:GetScale()==1.6); Drain()
assert(native:GetWidth()==36 and native:GetHeight()==36 and native:GetScale()==1)
for texture in pairs(saved.art) do texture:SetAlpha(1); texture:Show(); assert(texture:GetAlpha()==1); Drain(); assert(texture:GetAlpha()==0) end
native.scripts.OnEnter(native); native.scripts.OnLeave(native)
for texture in pairs(saved.art) do assert(texture:GetAlpha()==0) end
FS.db.actionBars.menu=false; A:SettingsChanged()
assert(native:GetParent()==saved.parent and native:GetWidth()==saved.width and native:GetScale()==saved.scale)
for texture,alpha in pairs(saved.art) do assert(texture:GetAlpha()==alpha) end
FS.db.actionBars.menu=true; A:SettingsChanged(); Drain()
assert(native:GetParent()==A.menuRoot and native:GetWidth()==36)
"""
checks['Forever main menu excludes combined Spells and Talents button while preserving separate disabled Talents'] = r"""
ResetTest(); local FS=ForeverSuite; local A=FS.modules.ActionBars
PlayerSpellsMicroButton=CreateFrame('Button'); SpellbookMicroButton=CreateFrame('Button'); TalentMicroButton=CreateFrame('Button'); TalentMicroButton:SetEnabled(false)
A:SettingsChanged()
assert(not A.menuButtons[PlayerSpellsMicroButton] and PlayerSpellsMicroButton:GetAlpha()==0 and not PlayerSpellsMicroButton:IsMouseEnabled())
assert(A.menuButtons[SpellbookMicroButton] and A.menuButtons[TalentMicroButton] and not TalentMicroButton:IsEnabled())
assert(A.menuButtons[TalentMicroButton].slot==A.menuButtons[SpellbookMicroButton].slot+1)
TalentMicroButton.scripts.OnUpdate(TalentMicroButton,.3); assert(A.menuButtons[TalentMicroButton].icon.desaturated)
FS.db.actionBars.menu=false; A:SettingsChanged(); assert(PlayerSpellsMicroButton:GetAlpha()==1 and PlayerSpellsMicroButton:IsMouseEnabled())
FS.db.actionBars.menu=true; A:SettingsChanged()
"""
checks['Compact current-version patch log, persistent startup preference and Credits footer navigation'] = r"""
ResetTest(); local FS=ForeverSuite; FS.db.setup.completed=true; FS:ShowConfig(); local center=FS.window
assert(center.patchLog:GetText()=='Patch Log' and center.credits:GetText()=='Credits')
center.patchLog:Click(); local f=FS.aboutWindow
assert(f:IsShown() and #FS.patchNotes==1 and FS.patchNotes[1].version==FS.version and f.title:GetText():find(FS.version,1,true))
assert(not f.previous and not f.next and f.hideStartup:IsShown() and not f.body:GetText():find('0.6.6',1,true))
f.hideStartup:SetChecked(true); f.hideStartup:Click(); assert(not FS.db.patchLog.showOnLoad)
FS:InitializeDatabase(); assert(not FS.db.patchLog.showOnLoad)
f.close:Click(); center.patchLog:Click(); assert(f:IsShown() and f.hideStartup:GetChecked())
center.credits:Click(); assert(f.body:GetText():find('DeluxiZ',1,true) and f.body:GetText():find('AI',1,true) and not f.hideStartup:IsShown() and not f.hideStartup.label:IsShown())
f.close:Click(); FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); assert(not f:IsShown())
FS.db.patchLog.showOnLoad=true; FS.events.scripts.OnEvent(FS.events,'PLAYER_LOGIN'); assert(f:IsShown() and FS.aboutMode=='patch')
f.hideStartup:SetChecked(false); f.hideStartup:Click(); assert(FS.db.patchLog.showOnLoad)
f.close:Click()
"""
checks['Custom gear slots support pickup, drag, secure use and combat safety with live stats'] = r"""
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character; C:Apply(); C.tabs[1]:Click()
TEST.equipment={[16]={id=1,current=20,maximum=30}}; C:RefreshCharacter(); local b=C.slots[16]
assert(b.icon.texture==134400 and b:GetAttribute('type2')=='item' and b:GetAttribute('item2')=='16' and b:GetAttribute('target-slot')==16)
local pickups={}; PickupInventoryItem=function(slot) pickups[#pickups+1]=slot end
b:Click('LeftButton'); b.scripts.OnDragStart(b); b.scripts.OnReceiveDrag(b); assert(#pickups==3 and pickups[1]==16)
TEST.combat=true; b:Click('LeftButton'); b.scripts.OnDragStart(b); assert(#pickups==3)
TEST.combat=false; local uses=TEST.secureUses or 0; b:Click('RightButton'); assert(TEST.secureUses==uses+1 and TEST.lastSecureItem=='16')
UnitStat=function(_,i) return i*10,i*10+5 end; UnitArmor=function() return 40,55 end
local stats=C:Stats(); assert(stats[3].text=='Strength:  15' and stats[8].text=='Armor:  55')
TEST.equipment={}; C:RefreshCharacter(); assert(b.icon.texture==C:EmptySlotIcon(16) and b.icon.desaturated and b.empty:GetText()=='')
PickupInventoryItem=nil; UnitStat=nil; UnitArmor=nil
"""
checks['Own Equipment Manager creates unique sets, equips securely and confirms deletion; Titles select real IDs'] = r"""
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character; local sets={[7]={name='Travel',icon=123}}; local created,deleted,title
CharacterFrame:Show(); C:Apply(); C.tabs[1]:Click()
C_EquipmentSet={GetEquipmentSetIDs=function() local ids={}; for id in pairs(sets) do ids[#ids+1]=id end; table.sort(ids); return ids end,
 GetEquipmentSetInfo=function(id) local row=sets[id]; if row then return row.name,row.icon,id,false end end,
 CreateEquipmentSet=function(name,icon) created=name; sets[8]={name=name,icon=icon} end,
 DeleteEquipmentSet=function(id) deleted=id; sets[id]=nil end}
C.sideTabs[2]:Click(); assert(C.sideMode==2 and C.setName:IsShown())
C.rows[1]:Click(); assert(C.selectedSet==7 and C.equip:GetAttribute('equipmentset')=='Travel' and C.equip:IsEnabled())
C.setName:SetText('Travel'); C.createSet:Click(); assert(not created)
C.setName:SetText('Combat'); C.createSet:Click(); assert(created=='Combat' and #C:EquipmentSets()==2)
C.delete:Click(); assert(not deleted and C.confirmAction==7); C.delete:Click(); assert(deleted==7)
GetNumTitles=function() return 2 end; IsTitleKnown=function(i) return i==2 end; GetTitleName=function() return '%s the Brave' end
GetCurrentTitle=function() return title or -1 end; SetCurrentTitle=function(id) title=id end
C.sideTabs[3]:Click(); assert(C.sideMode==3 and not C.setName:IsShown() and not C.equip:IsShown())
C.rows[2]:Click(); assert(title==2); C.rows[1]:Click(); assert(title==-1)
TEST.combat=true; C.sideTabs[1]:Click(); assert(C.sideMode==3); TEST.combat=false
C_EquipmentSet=nil; GetNumTitles=nil; IsTitleKnown=nil; GetTitleName=nil; GetCurrentTitle=nil; SetCurrentTitle=nil
"""
checks['Modal Patch Log and Credits never overlap Control Center and close returns to it'] = r"""
ResetTest(); local FS=ForeverSuite; FS:ShowConfig(); assert(FS.window:IsShown())
FS.window.patchLog:Click(); assert(FS.aboutWindow:IsShown() and not FS.window:IsShown())
FS.aboutWindow.close:Click(); assert(FS.window:IsShown() and not FS.aboutWindow:IsShown())
FS.window.credits:Click(); assert(FS.aboutWindow:IsShown() and not FS.window:IsShown())
FS:ShowConfig(); assert(FS.window:IsShown() and not FS.aboutWindow:IsShown())
FS.modules.Gear:ShowWindow(); assert(FS.modules.Gear.window:IsShown() and not FS.window:IsShown())
FS:ShowConfig(); assert(not FS.modules.Gear.window:IsShown())
"""
checks['Hidden native slot mouse regions are disabled recursively and restored; empty icons match inventory slots'] = r"""
ResetTest(); local FS=ForeverSuite; local C=FS.modules.Character
local original=CreateFrame('Button',nil,PaperDollFrame); original:EnableMouse(true)
C:Apply(); assert(not original:IsMouseEnabled()); original:EnableMouse(true); assert(not original:IsMouseEnabled())
local b=C.slots[11]; assert(b:IsMouseEnabled()); b.scripts.OnEnter(b); assert(GameTooltip.owner==b)
C_PaperDollInfo={GetInventorySlotInfo=function(name) return 1,'empty:'..name end}
TEST.equipment={}; C:RefreshCharacter()
for slot,button in pairs(C.slots) do assert(button.icon.texture=='empty:'..C.slotNames[slot] and button.icon.desaturated and button.empty:GetText()=='') end
TEST.equipment={[11]={id=1}}; C:RefreshCharacter(); assert(b.icon.texture==134400 and not b.icon.desaturated and b.icon:GetAlpha()==1)
TEST.equipment={}; C:RefreshCharacter(); assert(b.icon.texture=='empty:Finger0Slot' and b.icon.desaturated)
FS:SetModuleEnabled('Character',false); assert(original:IsMouseEnabled())
FS:SetModuleEnabled('Character',true); assert(not original:IsMouseEnabled())
C_PaperDollInfo=nil
"""
for section in Path('work/check_expansion.lua').read_text().split('-- TEST: ')[1:]:
    title, script = section.split('\n', 1)
    checks[title] = 'do\n' + script + '\nend'
for section in Path('work/check_trail.lua').read_text().split('-- TEST: ')[1:]:
    title, script = section.split('\n', 1)
    checks[title] = 'do\n' + script + '\nend'
for section in Path('work/check_native_chrome.lua').read_text().split('-- TEST: ')[1:]:
    title, script = section.split('\n', 1)
    checks[title] = 'do\n' + script + '\nend'

for section in Path('work/check_extensions.lua').read_text().split('-- TEST: ')[1:]:
    title, script = section.split('\n', 1)
    checks[title] = 'do\n' + script + '\nend'

for section in Path('work/check_systems.lua').read_text().split('-- TEST: ')[1:]:
    title, script = section.split('\n', 1)
    checks[title] = 'do\n' + script + '\nend'

for name, script in checks.items():
    try:
        lua.execute(script)
        print('PASS:', name)
    except Exception:
        print('FAIL:', name)
        raise
lua.execute('Drain()')
print(f'PASS: {len(checks)} scenario groups')

from PIL import Image
with Image.open('Assets/Icon-FS.tga') as logo:
    assert logo.size == (256, 256) and logo.mode == 'RGBA'
    assert logo.getchannel('A').getextrema() == (0, 255)
    assert all(logo.getpixel(p)[3] == 0 for p in [(0,0),(255,0),(0,255),(255,255)])
assert Path('Assets/Icon-FS.tga').read_bytes()[2] == 2, 'Runtime TGA must be uncompressed true-color'
toc = Path('ForeverSuite.toc').read_text()
assert f'## Version: {lua.eval("ForeverSuite.version")}' in toc
assert '## Notes: Modular UI and everyday tools.' in toc
assert '## IconTexture: Interface\\AddOns\\ForeverSuite\\Assets\\Icon-FS.tga' in toc
print('PASS: logo format, dimensions and addon-list metadata')

with Image.open('Assets/Logo-wordmark.tga') as wordmark:
    assert wordmark.size == (512,128) and wordmark.mode == 'RGBA'
    assert wordmark.getchannel('A').getextrema() == (0,255)
    assert all(wordmark.getpixel(p)[3] == 0 for p in [(0,0),(511,0),(0,127),(511,127)])
assert Path('Assets/Logo-wordmark.tga').read_bytes()[2] == 2
lua.execute("assert(ForeverSuite.window.logo.texture == ForeverSuite.logo)")
print('PASS: wordmark alpha, texture format and central header integration')

menu_icons = list(Path('Assets/Menu').glob('*.tga'))
assert len(menu_icons) == 17
for icon in menu_icons:
    with Image.open(icon) as im:
        assert im.size == ((1024,1024) if icon.stem=='FantasyAtlas' else (64,64)) and im.mode == 'RGBA'
        assert im.getchannel('A').getextrema() == (0,255)
        assert im.getpixel((0,0))[3] == 0
    assert icon.read_bytes()[2] == 2
print('PASS: 16 original menu icons have uncompressed RGBA textures and transparent corners')

bar_art=list(Path('Assets/ActionBars').glob('*.tga'))
assert len(bar_art)==6
for asset in bar_art:
    with Image.open(asset) as im:
        assert im.mode=='RGBA' and im.size==((1024,128) if asset.stem.startswith('Tray') else (128,128))
        assert im.getpixel((0,0))[3]<40 and im.getchannel('A').getextrema()[1]==255
    assert asset.read_bytes()[2]==2
with Image.open('Assets/ActionBars/Tile-Gold.tga') as gold:
    r,g,b,a=gold.getpixel((6,64)); assert r>g>b and a>200
    r,g,b,a=gold.getpixel((64,112)); assert b>r and g>r and a>200
with Image.open('Assets/ActionBars/Tile-Dock.tga') as dock:
    r,g,b,a=dock.getpixel((64,121)); assert g>r+70 and b>r+70 and a>200
print('PASS: six bar artwork textures have transparent corners, bevels, cyan accents and uncompressed RGBA format')

theme_assets=list(Path('Assets/Themes').glob('*.tga'))
assert len(theme_assets)==40
for i in range(1,11):
    for kind in ('Panel','Button','Arrow','Preview'):
        asset=Path('Assets/Themes')/f'{i:02d}-{kind}.tga'
        assert asset.read_bytes()[2]==2, 'Theme textures must be uncompressed TGA'
        size=1024 if kind=='Preview' else 256 if kind=='Arrow' else 512
        with Image.open(asset) as im:
            assert im.mode=='RGBA' and im.size==(size,size)
            assert im.getchannel('A').getextrema()==(0,255)
            if kind=='Preview': assert im.getpixel((512,900))[3]==0
            else: assert im.getpixel((0,0))[3]==0
print('PASS: all ten Blender themes include valid panel, button, arrow and preview textures')
