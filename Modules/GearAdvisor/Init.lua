local _,FS=...
local T=FS.Tools
local G=T:Module('GearAdvisor','gearAdvisor','Gear Advisor','Stat-weight comparisons for your current gear. Starter presets are estimates: check class requirements, weapon setups, set bonuses and special effects yourself.',
    {preset='Auto',role='Class default',view='Upgrades',tooltips=true,minimum=1,showAll=false,weights={},talentBuild=false}, {'BAG_UPDATE_DELAYED','PLAYER_EQUIPMENT_CHANGED','GET_ITEM_INFO_RECEIVED','PLAYER_LEVEL_UP','ADDON_LOADED'})
G.options={{key='preset',label='Stat scale',values={'Auto','Strength','Agility','Caster','Healer','Tank','Custom'}},
    {key='role',label='My build',values={'Class default','Physical damage','Spell damage','Healer','Tank'}},
    {key='view',label='View',values={'Upgrades','Class guide','Weights'}},{key='tooltips',label='Show scores on item tooltips'},
    {key='minimum',label='Minimum improvement percent',values={0,1,3,5,10}},{key='showAll',label='Also show comparable non-upgrades'},
    {key='talentBuild',label='Follow selected Talent Advisor plan',help='Applies to Auto scales. Custom and manually selected stat scales are preserved.'}}
G.stats={{'Strength','ITEM_MOD_STRENGTH_SHORT'},{'Agility','ITEM_MOD_AGILITY_SHORT'},{'Stamina','ITEM_MOD_STAMINA_SHORT'},
    {'Intellect','ITEM_MOD_INTELLECT_SHORT'},{'Spirit','ITEM_MOD_SPIRIT_SHORT'},{'Armor','RESISTANCE0_NAME'},
    {'AttackPower','ITEM_MOD_ATTACK_POWER_SHORT'},{'RangedAttackPower','ITEM_MOD_RANGED_ATTACK_POWER_SHORT'},
    {'SpellPower','ITEM_MOD_SPELL_POWER_SHORT'},{'Healing','ITEM_MOD_SPELL_HEALING_DONE_SHORT'},
    {'CritRating','ITEM_MOD_CRIT_RATING_SHORT'},{'HitRating','ITEM_MOD_HIT_RATING_SHORT'},
    {'HasteRating','ITEM_MOD_HASTE_RATING_SHORT'},{'DodgeRating','ITEM_MOD_DODGE_RATING_SHORT'},
    {'ParryRating','ITEM_MOD_PARRY_RATING_SHORT'},{'DefenseRating','ITEM_MOD_DEFENSE_SKILL_RATING_SHORT'},
    {'ManaRegen','ITEM_MOD_MANA_REGENERATION_SHORT'},{'Dps','ITEM_MOD_DAMAGE_PER_SECOND_SHORT'}}
G.presets={Strength={Strength=2,Agility=.6,Stamina=.2,AttackPower=1,CritRating=.8,HitRating=1,HasteRating=.7,Dps=5},
    Agility={Agility=2,Strength=.3,Stamina=.2,AttackPower=1,RangedAttackPower=1,CritRating=.8,HitRating=1,HasteRating=.7,Dps=5},
    Caster={Intellect=1,Spirit=.2,Stamina=.15,SpellPower=2,CritRating=.7,HitRating=1,HasteRating=.8},
    Healer={Intellect=1,Spirit=.8,Stamina=.15,SpellPower=1,Healing=2,CritRating=.5,HasteRating=.6,ManaRegen=2},
    Tank={Stamina=2,Armor=.05,Strength=.5,Agility=.5,DefenseRating=2,DodgeRating=1.5,ParryRating=1.5}}
G.classGuides={
    WARRIOR={'Strength','Strength helps physical attacks. Keep some Stamina for survival. Choose Tank for a defensive build.'},
    PALADIN={'Strength','Strength is a starting point for melee damage. Choose Healer for healing or Tank for defensive equipment.'},
    HUNTER={'Agility','Agility and ranged attack power are useful starting points for ranged damage. Your pet and special effects also matter.'},
    ROGUE={'Agility','Agility and attack power are a starting point for physical damage. Compare weapon types and special effects separately.'},
    PRIEST={'Caster','Intellect and spell power are a starting point for spell damage. Choose Healer if healing is your main role.'},
    DEATHKNIGHT={'Strength','Strength and attack power support physical damage. Choose Tank for a defensive build.'},
    SHAMAN={'Caster','Start with spell power and Intellect for casting. Choose Physical damage for a melee build or Healer for healing.'},
    MAGE={'Caster','Spell power and Intellect support spell damage. Hit and critical ratings can also help; this guide does not model caps.'},
    WARLOCK={'Caster','Spell power and Intellect support casting. Pet damage, spell interactions and special effects need a separate comparison.'},
    DRUID={'Caster','Start with Intellect and spell power for casting. Choose Physical damage for feral damage, Tank for defense or Healer for healing.'},
    MONK={'Agility','Agility is a starting point for physical damage. Choose Tank or Healer if that is your role.'},
    DEMONHUNTER={'Agility','Agility is a starting point for physical damage. Choose Tank for a defensive build.'},
    EVOKER={'Caster','Intellect and spell power are a starting point for casting. Choose Healer for a healing build.'}}
function G:ClassGuide()
    local localized,class=T:Call(UnitClass,'player')
    return self.classGuides[class],localized or class or 'Your class',class
end
G.slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},
    INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},
    INVTYPE_CLOAK={15},INVTYPE_WEAPON={16},INVTYPE_WEAPONMAINHAND={16},INVTYPE_2HWEAPON={16,17},INVTYPE_WEAPONOFFHAND={17},
    INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18}}
function G:Normalize()
    local d=self:Data(); if type(d.weights)~='table' then d.weights={} end
    for key,value in pairs(d.weights) do
        local known=false; for _,s in ipairs(self.stats) do if s[1]==key then known=true; break end end
        if not known or not T:Number(value) or math.abs(value)>1000 then d.weights[key]=nil end
    end
end
function G:Weights()
    local name=self:Data().preset
    if name=='Custom' then return self:Data().weights,'Custom' end
    if name=='Auto' then
        local advisor=FS.modules.TalentAdvisor
        if self:Data().talentBuild and advisor and FS:IsModuleEnabled('TalentAdvisor') then
            local weights,label=advisor:GearWeights()
            if weights then return weights,label..' (planned build starter estimate)' end
        end
        local guide,label,class=self:ClassGuide()
        name=guide and guide[1] or 'Strength'
        local role=self:Data().role
        if role=='Healer' or role=='Tank' then name=role
        elseif role=='Spell damage' then name='Caster'
        elseif role=='Physical damage' then name=(class=='WARRIOR' or class=='PALADIN' or class=='DEATHKNIGHT') and 'Strength' or 'Agility' end
        return self.presets[name],label..' - '..(role=='Class default' and name or role)..' (basic guide)'
    end
    return self.presets[name] or self.presets.Strength,name..' (starter estimate)'
end
function G:Score(link,weights)
    if type(link)~='string' or not C_Item then return end
    local stats=T:Call(C_Item.GetItemStats or GetItemStats,link)
    if type(stats)~='table' then return end
    weights=weights or self:Weights()
    local total=0
    for _,s in ipairs(self.stats) do
        local value=stats[s[2]]; local weight=weights[s[1]] or 0
        if value~=nil then
            if not T:Number(value) then return end
            total=total+value*weight
        end
    end
    return total
end
function G:Item(link)
    if (type(link)~='string' and not T:Number(link)) or not C_Item then return end
    local name,full,quality,level,required,kind,subtype,stack,location,icon,price,classID,subclassID,bind,expansion,setID=T:Call(C_Item.GetItemInfo,link)
    if T:Text(name)=='' then return nil,true end
    if not FS.HUD:Safe(location) or not self.slots[location] then return end
    local itemLink=T:Text(full)
    if itemLink=='' then itemLink=type(link)=='number' and 'item:'..link or link end
    return {name=name,link=itemLink,location=location,required=required,setID=setID,subclassID=subclassID,classID=classID}
end
local plannerSlots={[1]='Head',[2]='Neck',[3]='Shoulders',[5]='Chest',[6]='Waist',[7]='Legs',
    [8]='Feet',[9]='Wrists',[10]='Hands',[11]='Ring',[13]='Trinket',[15]='Back',[16]='Main hand',
    [17]='Off hand',[18]='Ranged'}
function G:LoadGearCatalog()
    if not FS.GearCatalog and not self.catalogAttempted and not InCombatLockdown() then
        self.catalogAttempted=true
        T:Call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,'ForeverSuite_GearData')
    end
    return FS.GearCatalog
end
function G:QueuePlannerRefresh(w)
    if self.plannerRefresh then return end
    self.plannerRefresh=true
    C_Timer.After(.2,function()
        self.plannerRefresh=nil
        if w.window:IsShown() and w:Data().view=='Gear Planner' then w:Refresh() end
    end)
end
function G:PlannerRows(targetLevel,query)
    local candidates,pending={},{}
    local equipped={}
    for slot=1,18 do
        local id=T:Call(GetInventoryItemID,'player',slot)
        if T:Number(id) then equipped[id]=true end
    end
    local function add(id,instance,boss,kind)
        if not T:Number(id) or id<1 or id>100000000 or id%1~=0 or T:Text(instance)=='' then return end
        boss=T:Text(boss)
        local candidate=candidates[id]
        if not candidate then
            candidate={sources={},seen={}}
            candidates[id]=candidate
        end
        local key=(instance..(boss~='' and (' / '..boss) or '')):lower()
        if not candidate.seen[key] then
            candidate.seen[key]=true
            local label=(kind=='Boss' and 'Boss: ' or '')..instance..(boss~='' and (' / '..boss) or '')
            candidate.sources[#candidate.sources+1]={instance=instance,boss=boss,label=label}
        end
    end
    local extras=FS.Extensions:Data()
    for _,drop in pairs(extras.encounterLoot) do
        if type(drop)=='table' and type(drop.items)=='table' then
            for id in pairs(drop.items) do add(id,drop.instance,drop.boss) end
        end
    end
    for _,goal in pairs(extras.wishlist) do add(goal.item,goal.instance,goal.boss) end
    for id in pairs(equipped) do
        if not candidates[id] then candidates[id]={sources={},seen={}} end
    end
    local catalog=self:LoadGearCatalog()
    local _,_,classID=T:Call(UnitClass,'player')
    local classBit=T:Number(classID) and classID>=1 and classID<=32 and 2^(classID-1)
    if catalog then
        for id,item in pairs(catalog.items) do
            if item[1]<=targetLevel and (not classBit or math.floor(item[2]/classBit)%2==1) then
                for _,index in ipairs(item[3]) do
                    local source=catalog.sources[index]
                    if source[4]<=targetLevel then
                        local kind,name,boss=source[1],source[2],source[3]
                        local location=kind=='Boss' and name or (kind..': '..name)
                        add(id,location,boss,kind)
                        candidates[id].catalog=true
                    end
                end
            end
        end
    end
    local slots={}
    local weights=self:Weights()
    local remaining,more=72,false
    local cache=self.plannerItemCache or {}
    self.plannerItemCache=cache
    query=(query or ''):lower()
    for id,entry in pairs(candidates) do
        local record
        if entry.catalog then
            record=cache[id]
            if not record then
                if remaining>0 then
                    remaining=remaining-1
                    local item,loading=self:Item(id)
                    record={item=item,loading=loading}
                    cache[id]=record
                else
                    more=true
                end
            end
        else
            local item,loading=self:Item(id)
            record={item=item,loading=loading}
        end
        local item,loading=record and record.item,record and record.loading
        if loading then
            pending[id]=true
        elseif item and T:Number(item.required) and item.required>=0 and item.required<=targetLevel then
            if record.weights~=weights then
                record.score=self:Score(item.link,weights)
                record.weights=weights
            end
            local score=record.score
            local slot=self.slots[item.location][1]
            if T:Number(score) and (score>0 or equipped[id]) and plannerSlots[slot] then
                local slotName=plannerSlots[slot]
                local matches=query=='' or (slotName..' | '..item.name):lower():find(query,1,true)
                if not matches then
                    for _,source in ipairs(entry.sources) do
                        if source.label:lower():find(query,1,true) then matches=true; break end
                    end
                end
                if matches then
                    slots[slot]=slots[slot] or {}
                    slots[slot][#slots[slot]+1]={id=id,score=score,item=item,sources=entry.sources,slot=slot,slotName=slotName}
                end
            end
        end
    end
    local rows={}
    for slot=1,18 do
        local items=slots[slot]
        if items then
            table.sort(items,function(a,b) if a.score~=b.score then return a.score>b.score end; return a.id<b.id end)
            for rank=1,math.min(6,#items) do
                local row=items[rank]
                row.name,row.link,row.required=row.item.name,row.item.link,row.item.required
                row.equipped=equipped[row.id]
                row.text=row.slotName..' | '..(rank==1 and 'Top pick' or ('Alt '..(rank-1)))..' | '..row.name
                    ..(row.equipped and ' (equipped)' or '')
                table.sort(row.sources,function(a,b) return a.label<b.label end)
                local terms={row.text}
                for _,source in ipairs(row.sources) do terms[#terms+1]=source.label end
                row.searchText=table.concat(terms,' ')
                local source=row.sources[1]
                row.detailLine=('Requires level %d | %.1f points | %s'):format(row.required,row.score,source and source.label or 'Source unknown')
                rows[#rows+1]=row
            end
        end
    end
    return rows,pending,catalog and catalog.build,more
end
function G:Compare(link)
    if type(GetInventoryItemLink)~='function' then return end
    local item=self:Item(link); if not item then return end
    local score=self:Score(link); if not T:Number(score) then return end
    local playerLevel=T:Call(UnitLevel,'player')
    if T:Number(item.required) and T:Number(playerLevel) and item.required>playerLevel then return end
    local base,bestSlot
    local main=T:Call(GetInventoryItemLink,'player',16); local mainItem=main and self:Item(main)
    if item.location~='INVTYPE_2HWEAPON' and (self.slots[item.location][1]==16 or self.slots[item.location][1]==17)
        and mainItem and mainItem.location=='INVTYPE_2HWEAPON' then return end
    local unique=T:Call(C_Item.GetItemUniquenessByID,link)
    for _,slot in ipairs(self.slots[item.location]) do
        local equipped=T:Call(GetInventoryItemLink,'player',slot)
        if equipped==link then base=score; bestSlot=slot; break end
        if unique and equipped and equipped:match('item:(%d+)')==link:match('item:(%d+)') then return end
        local current=0; if equipped then current=self:Score(equipped) end
        if not T:Number(current) then return end
        if item.location=='INVTYPE_2HWEAPON' then base=(base or 0)+current; bestSlot=16
        elseif base==nil or current<base then base=current; bestSlot=slot end
    end
    local delta=score-base; local percent=base>0 and delta/base*100 or nil
    item.score=score; item.base=base; item.delta=delta; item.percent=percent; item.slot=bestSlot
    item.upgrade=delta>0 and (percent==nil or percent>=self:Data().minimum)
    return item
end
function G:Indicator(row)
    if not row or not T:Number(row.delta) then return '' end
    local tolerance=.000001*math.max(1,math.abs(row.score or 0),math.abs(row.base or 0))
    if math.abs(row.delta)<=tolerance then return '|cff999999-|r','Equal',.6,.6,.6 end
    if row.delta>0 then return '|TInterface\\AddOns\\ForeverSuite\\Assets\\Indicators\\Gear-Up.tga:16:16|t','Upgrade',.2,1,.35 end
    return '|TInterface\\AddOns\\ForeverSuite\\Assets\\Indicators\\Gear-Down.tga:16:16|t','Downgrade',1,.25,.25
end
function G:Build()
    self.rows={}; local weights,scale=self:Weights()
    if self:Data().view=='Class guide' then
        local guide,label=self:ClassGuide()
        self.rows={{text=label..': '..(guide and guide[2] or 'Select a role in settings to match your build.')},
            {text='Automatic class advice is on by default. Choose My build in settings if you play a different role.'},
            {text='A + percentage compares only the stats in this guide with your equipped item. It is not a damage simulation.'},
            {text='Check required level, class and armor/weapon proficiency before equipping.'},
            {text='Procs, sockets, set bonuses and unusual WoW Forever effects are not included.'},
            {text='You can use this basic guide without editing any stat weights.'}}
        self.status=scale; return
    end
    if self:Data().view=='Weights' then
        for _,s in ipairs(self.stats) do self.rows[#self.rows+1]={id=s[1],stat=s[1],text=s[1]..' = '..(weights[s[1]] or 0)} end
        self.status=scale..'. Select a stat, enter a weight below, then Save weight. Editing starts a Custom scale.'; return
    end
    local V=FS.modules.Vendor; local unknown=0; local seen={}
    for bag=0,V:BagLimit() do
        local count=T:Call(C_Container and C_Container.GetContainerNumSlots,bag)
        if T:Number(count) then for slot=1,count do
            local info=T:Call(C_Container.GetContainerItemInfo,bag,slot)
            if type(info)=='table' and FS.HUD:Safe(info.hyperlink) and type(info.hyperlink)=='string' and not seen[info.hyperlink] then
                seen[info.hyperlink]=true
                if T:Call(C_Item and C_Item.IsEquippableItem,info.hyperlink) then
                    local row=self:Compare(info.hyperlink)
                    if row and (row.upgrade or self:Data().showAll) then
                        row.id=info.hyperlink; row.bag=bag; row.bagSlot=slot
                        local indicator=self:Indicator(row)
                        row.text=indicator..' '..row.name..' | '..string.format('%.1f',row.score)..' points | '..
                            (row.percent and string.format('%+.1f%%',row.percent) or (row.delta>0 and 'Empty slot' or 'No improvement'))
                        self.rows[#self.rows+1]=row
                    elseif not row then unknown=unknown+1 end
                end
            end
        end end
    end
    table.sort(self.rows,function(a,b) if a.delta~=b.delta then return a.delta>b.delta end; return a.name<b.name end)
    self.status=scale..'. '..unknown..' items need data or manual comparison. Scores exclude procs, set bonuses and class restrictions.'
end
function G:SetWeight(stat,text)
    local known=false; for _,s in ipairs(self.stats) do if s[1]==stat then known=true; break end end
    local value=tonumber(text)
    if not known or not T:Number(value) or math.abs(value)>1000 then self.status='Select a stat and enter a number between -1000 and 1000.'; return false end
    if InCombatLockdown() then return false end
    local weights=self:Weights(); local copy={}; for key,v in pairs(weights) do copy[key]=v end
    copy[stat]=value; self:Data().weights=copy; self:Data().preset='Custom'; self:SettingsChanged(); return true
end
function G:ParseWeights(text)
    if type(text)~='string' or #text>12000 then return false,'Scale text is too long.' end
    local weights={}; local known={}; for _,s in ipairs(self.stats) do known[s[1]]=true end
    local count=0
    for part in (text:gsub('\r','')..','):gmatch('(.-)[,\n]') do
        if part:match('%S') then
        local key,value=part:match('^%s*([%a]+)%s*=%s*([+-]?[%d%.]+)%s*$')
        if not key then return false,'Use only Stat=number entries separated by commas or new lines.' end
        if not known[key] then return false,'Unsupported stat: '..key end
        value=tonumber(value)
        if not T:Number(value) or math.abs(value)>1000 then return false,'Invalid weight.' end
        if weights[key]~=nil then return false,'Duplicate stat: '..key end
        weights[key]=value; count=count+1
        end
    end
    if count==0 then return false,'Use Stat=number entries, for example Agility=2, Stamina=0.2.' end
    return weights
end
function G:ImportWeights(text)
    if InCombatLockdown() then return false,'Leave combat first.' end
    local weights,message=self:ParseWeights(text); if not weights then return false,message end
    self:Data().weights=weights; self:Data().preset='Custom'; self:SettingsChanged(); return true
end
function G:EditScale()
    local weights=self:Weights(); local values={}
    for _,s in ipairs(self.stats) do values[#values+1]=s[1]..'='..(weights[s[1]] or 0) end
    if not FS.Extensions.TextDialog then return end
    FS.Extensions:TextDialog('Gear Advisor stat weights',table.concat(values,'\n'),false,function(text)
        local weights,message=self:ParseWeights(text)
        return weights and text or nil,message or 'Weights are valid. Apply to save this Custom scale.'
    end,function(text) return self:ImportWeights(text) end,function() self:ShowWindow() end)
end
G.actions={{label='View',run=function(self) local nextView={Upgrades='Class guide',['Class guide']='Weights',Weights='Upgrades'}; self:Data().view=nextView[self:Data().view]; self.selected=nil; self.page=1; self:SettingsChanged() end},
    {label='Save weight',run=function(self,text) self:SetWeight(self.selected and self.selected.stat,text) end},
    {label='Edit scale',run=function(self) self:EditScale() end},
    {label='Gear planner',run=function() FS.modules.Workbench:Choose('Gear Planner') end}}
function G:Tooltip(tooltip)
    if not FS:IsModuleEnabled(self.name) or not self:Data().tooltips or not tooltip or not tooltip.GetItem then return end
    local _,link=T:Call(tooltip.GetItem,tooltip)
    if type(link)~='string' or tooltip.fsAdvisorLink==link then return end
    local row=self:Compare(link); if not row then return end
    tooltip.fsAdvisorLink=link
    local _,scale=self:Weights()
    tooltip:AddLine('ForeverSuite '..scale..': '..string.format('%.1f points',row.score),.71,.87,.49)
    local indicator,label,r,g,b=self:Indicator(row)
    tooltip:AddLine(indicator..' '..label..(row.percent and string.format(' (%+.1f%% stat score)',row.percent) or ''),r,g,b)
    tooltip:AddLine('Estimate only: check requirements, procs and set bonuses.',.7,.7,.7,true)
end
function G:InstallTooltip()
    if self.tooltipInstalled then return end
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=='function' and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(t) self:Tooltip(t) end)
    elseif GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript('OnTooltipSetItem') then
        GameTooltip:HookScript('OnTooltipSetItem',function(t) self:Tooltip(t) end)
    else return end
    self.tooltipInstalled=true
    for _,tip in ipairs({GameTooltip,ItemRefTooltip}) do tip:HookScript('OnTooltipCleared',function(t) t.fsAdvisorLink=nil end) end
end
function G:Apply() self:InstallTooltip() end
function G:Event(event,id,success)
    if event=='ADDON_LOADED' then self:InstallTooltip(); return end
    local w=FS.modules.Workbench
    if not w or not w.window or not w.window:IsShown() or w:Data().view~='Gear Planner' then return end
    if event=='PLAYER_REGEN_ENABLED' or event=='PLAYER_LEVEL_UP' or event=='PLAYER_EQUIPMENT_CHANGED' then
        self:QueuePlannerRefresh(w)
    elseif event=='GET_ITEM_INFO_RECEIVED' and T:Number(id) and w.plannerPending and w.plannerPending[id] then
        local cache=self.plannerItemCache
        if cache and cache[id] then
            if success==true then cache[id]=nil else cache[id]={} end
        elseif success~=true then return end
        self:QueuePlannerRefresh(w)
    end
end
local render=G.Render
function G:Render()
    render(self)
    local f=self.window; if not f then return end
    local editing=self:Data().view=='Weights'
    f.input:SetShown(editing); f.actionButtons[2]:SetShown(editing)
    f.actionButtons[1]:SetText('View: '..self:Data().view)
    for _,button in ipairs(f.cells) do if button.row then button:SetText(button.row.text) end end
    if f.LayoutText then f:LayoutText() end
end
function G:OnSelect(row)
    if self:Data().view=='Class guide' and row and FS.Extensions.TextDialog then
        FS.Extensions:TextDialog('Gear Advisor - Class guide',row.text,true,nil,nil,function() self:ShowWindow() end)
    end
end
