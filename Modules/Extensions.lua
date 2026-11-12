local _,FS=...
local E,T=FS.Extensions,FS.Tools
local function npcID(guid)
    local parts={}; for part in guid:gmatch('[^-]+') do parts[#parts+1]=part end
    if parts[1]~="Creature" and parts[1]~="Vehicle" then return end
    local id=tonumber(parts[6]); return T:Number(id) and id>0 and id or nil
end
function E:NPCID(unit) return npcID(T:Text(T:Call(UnitGUID,unit))) end
local classificationNames={rare='Rare',rareelite='Rare elite',elite='Elite',worldboss='World boss'}
E.sightings={}
function E:ObserveNPC(unit,source)
    local options=self:Data().discovery
    if not options.enabled or T:Call(UnitIsDeadOrGhost,unit)==true or T:Call(UnitPlayerControlled,unit)==true then return false end
    local kind=T:Text(T:Call(UnitClassification,unit))
    if not classificationNames[kind] or (not options.elites and kind~='rare' and kind~='rareelite') then return false end
    local guid=T:Text(T:Call(UnitGUID,unit))
    local id=npcID(guid)
    local name=T:Text(T:Call(UnitName,unit)):gsub('[|%c]',''):sub(1,100)
    if not id or name=='' then return false end
    local now=GetTime()
    for _,sighting in ipairs(self.sightings) do
        if sighting.id==id and now-sighting.seen<180 then return false end
    end
    local level=T:Call(UnitLevel,unit)
    local entry={id=id,name=name,kind=classificationNames[kind],source=source,seen=now,
        level=T:Number(level) and level or nil,time=time and time() or 0}
    table.insert(self.sightings,1,entry)
    while #self.sightings>40 do table.remove(self.sightings) end
    self:Alert('Rare or elite',false,entry.kind..': '..name..' ('..source..')',options.portrait and unit or nil)
    local workbench=self.workbench
    if workbench and workbench.window and workbench.window:IsShown() and workbench:Data().view=='Rare sightings' then workbench:Refresh() end
    return true
end
local discoveryEvents=CreateFrame('Frame')
local discoverySources={NAME_PLATE_UNIT_ADDED='Nameplate',PLAYER_TARGET_CHANGED='Target',UPDATE_MOUSEOVER_UNIT='Mouseover'}
function E:SyncDiscovery()
    local enabled=self:Data().discovery.enabled
    if self.discoveryEnabled==enabled then return end
    self.discoveryEnabled=enabled
    for event in pairs(discoverySources) do
        if enabled then FS:RegisterClientEvent(discoveryEvents,event) else discoveryEvents:UnregisterEvent(event) end
    end
end
discoveryEvents:SetScript('OnEvent',function(_,event,unit)
    if event=='PLAYER_TARGET_CHANGED' then unit='target' elseif event=='UPDATE_MOUSEOVER_UNIT' then unit='mouseover' end
    if type(unit)=='string' then E:ObserveNPC(unit,discoverySources[event]) end
end)
function E:SaveNPCRule(id)
    if not self:Allowed() or not T:Number(id) or id<1 or id>100000000 or id~=math.floor(id) then return false end
    local rule={}; for key in pairs(FS.modules.Nameplates.designDefaults) do rule[key]=self.Copy(FS.db.nameplates[key]) end
    rule.scale=FS.db.nameplates.scale; self:Data().npcRules[math.floor(id)]=rule; self:Trim(self:Data().npcRules,64); FS.modules.Nameplates:RefreshPlates(); return true
end
local N=FS.modules.Nameplates
function N:UnitDesign(unit)
    local base=self:Design(); local id=E:NPCID(unit); local rule=id and E:Data().npcRules[id]
    if type(rule)~="table" then return base end
    self.ruleCache=self.ruleCache or setmetatable({},{__mode='k'}); local cached=self.ruleCache[rule]
    if cached and cached.base==base then return cached.design end
    local result=self:CopyDesign(base)
    for _,group in ipairs(self.designGroups) do for _,option in ipairs(group.options) do
        local v=rule[option.key]
        if option.min and T:Number(v) and v>=option.min and v<=option.max then result[option.key]=v
        elseif option.values then for _,choice in ipairs(option.values) do if v==choice then result[option.key]=v end end
        elseif type(v)=="boolean" then result[option.key]=v end
    end end
    if T:Number(rule.scale) then result.scale=math.max(.6,math.min(1.4,rule.scale)) end
    for part in pairs(self.designDefaults.positions) do for _,axis in ipairs({'x','y'}) do
        local p=type(rule.positions)=='table' and rule.positions[part]; local v=type(p)=='table' and p[axis]
        if T:Number(v) and v>=-300 and v<=300 then result.positions[part][axis]=v end
    end end
    self.ruleCache[rule]={base=base,design=result}
    return result
end
local nameplateSettings=N.SettingsChanged
function N:SettingsChanged() self.ruleCache=setmetatable({},{__mode='k'}); return nameplateSettings(self) end
local cast=N.CastAppearance
function N:CastAppearance(frame,unit,db)
    cast(self,frame,unit,db)
    if not frame.cast:IsShown() then return end
    local info={T:Call(UnitCastingInfo,unit)}; local id=info[9]
    if not info[1] then info={T:Call(UnitChannelInfo,unit)}; id=info[8] end
    if T:Number(id) and E:Data().importantSpells[id] then
        frame.cast:SetStatusBarColor(1,.55,.08)
        local text=T:Text(frame.cast.label:GetText()); if text~="" and text:sub(1,2)~="! " then frame.cast.label:SetText('! '..text) end
        E:Alert("Important cast")
    end
end
local health=N.HealthColor
function N:HealthColor(unit,threat,db)
    if E:Data().palette~="Original" then
        local enemy=T:Call(UnitCanAttack,"player",unit)
        if enemy==true then return 1,.55,.08 elseif enemy==false then return .1,.65,1 end
    end
    return health(self,unit,threat,db)
end
function E:AddKeyword(word)
    word=T:Text(word):match('^%s*(.-)%s*$')
    if #word<2 or #word>64 or word:find('|',1,true) or #self:Data().keywords>=20 then return false end
    for _,v in ipairs(self:Data().keywords) do if v:lower()==word:lower() then return false end end
    table.insert(self:Data().keywords,word); self:Data().keywordsEnabled=true; self:UpdateFilters(); return true
end
function E:Highlight(message)
    if T:Text(message)=="" then return message,false end
    local words=self:Data().keywords
    local function plain(segment)
        local lower=segment:lower(); local out={}; local at=1; local found=false
        while at<=#segment do
            local first,last
            for _,word in ipairs(words) do local a,b=lower:find(word:lower(),at,true); if a and (not first or a<first or (a==first and b>last)) then first,last=a,b end end
            if not first then out[#out+1]=segment:sub(at); break end
            found=true; out[#out+1]=segment:sub(at,first-1); out[#out+1]='|cffffce52'..segment:sub(first,last)..'|r'; at=last+1
        end
        return table.concat(out),found
    end
    local out={}; local at=1; local found=false
    -- Preserve hyperlink and texture payloads exactly, including displayed links.
    while at<=#message do
        local a,b=message:find('|H.-|h.-|h',at)
        for _,pattern in ipairs({'|T.-|t','|A.-|a','|c%x%x%x%x%x%x%x%x','|r'}) do local ta,tb=message:find(pattern,at); if ta and (not a or ta<a) then a,b=ta,tb end end
        if not a then local text,match=plain(message:sub(at)); out[#out+1]=text; found=found or match; break end
        local text,match=plain(message:sub(at,a-1)); out[#out+1]=text; found=found or match; out[#out+1]=message:sub(a,b); at=b+1
    end
    return table.concat(out),found
end
E.chatEvents={"CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_CHANNEL","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER"}
function E:FilterAPI()
    if ChatFrameUtil and type(ChatFrameUtil.AddMessageEventFilter)=='function' and type(ChatFrameUtil.RemoveMessageEventFilter)=='function' then return ChatFrameUtil.AddMessageEventFilter,ChatFrameUtil.RemoveMessageEventFilter end
    return ChatFrame_AddMessageEventFilter,ChatFrame_RemoveMessageEventFilter
end
function E:ChatMessage(event,message,sender,lineID)
    if not FS:IsModuleEnabled('Chat') or T:Text(message)=="" then return message end
    if not self:Data().captureChat and not self:Data().keywordsEnabled then return message end
    local key=event..':'..(T:Number(lineID) and tostring(lineID) or T:Text(sender)..':'..message..':'..math.floor(GetTime()))
    local duplicate=self.lastChatKey==key; self.lastChatKey=key
    if self:Data().captureChat and not duplicate then
        local clean=message:gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t','[icon]')
        self.chat[#self.chat+1]=((T:Text(sender)~="" and sender..': ' or '')..clean):sub(1,1024)
        while #self.chat>200 do table.remove(self.chat,1) end
    end
    if self:Data().keywordsEnabled then local out,found=self:Highlight(message); if found and not duplicate then self:Alert('Keyword') end; return out end
    return message
end
function E:UpdateFilters()
    local wanted=FS:IsModuleEnabled('Chat') and (self:Data().captureChat or self:Data().keywordsEnabled)
    if wanted==self.filtersInstalled then return end
    if not wanted and not self.filtersInstalled then self.filtersInstalled=false; return end
    self.filter=self.filter or function(_,event,message,...)
        local sender=select(1,...); local lineID=select(10,...)
        return false,E:ChatMessage(event,message,sender,lineID),...
    end
    local add,remove=self:FilterAPI()
    if wanted and type(add)=='function' and type(remove)=='function' then
        for _,event in ipairs(self.chatEvents) do add(event,self.filter) end; self.filterRemove=remove; self.filtersInstalled=true
    elseif not wanted and self.filtersInstalled and type(self.filterRemove or remove)=='function' then
        for _,event in ipairs(self.chatEvents) do (self.filterRemove or remove)(event,self.filter) end; self.filtersInstalled=false; self.filterRemove=nil
    end
end
function E:PlayerKey(name)
    if T:Text(name)=="" then return end
    if name:find('-',1,true) then return name end
    return name..'-'..(T:Call(GetNormalizedRealmName) or T:Call(GetRealmName) or 'Realm')
end
function E:GroupChanged()
    if not self:Data().trackGroups or not FS:IsModuleEnabled('Social') then return end
    local raid=T:Call(IsInRaid); local max=raid and 40 or 4; local prefix=raid and 'raid' or 'party'
    for i=1,max do local unit=prefix..i
        if T:Call(UnitExists,unit) and not T:Call(UnitIsUnit,unit,'player') then
            local name,realm=T:Call(UnitName,unit); local key=T:Text(name)~="" and self:PlayerKey(name..(T:Text(realm)~="" and '-'..realm or ''))
            if key then self:Data().recentGroups[key]={name=key,time=T:Call(time) or 0} end
        end
    end; self:Trim(self:Data().recentGroups,100)
end
function E:SyncEvents()
    if not self.events then return end
    self.subscriptionState=self.subscriptionState or {}
    local wanted={GROUP_ROSTER_UPDATE=self:Data().trackGroups and FS:IsModuleEnabled('Social'),PLAYER_XP_UPDATE=FS:IsModuleEnabled('QoL'),PLAYER_LEVEL_UP=FS:IsModuleEnabled('QoL')}
    for event,enabled in pairs(wanted) do if self.subscriptionState[event]~=enabled then
        self.subscriptionState[event]=enabled
        if enabled then FS:RegisterClientEvent(self.events,event) else self.events:UnregisterEvent(event) end
    end end
end
local G=FS.modules.Guild; local guild=G.Build
function G:Build()
    guild(self)
    for _,row in ipairs(self.rows) do
        local key=E:PlayerKey(row.name); row.localKey=key
        row.favorite=key and E:Data().guildFavorites[key] or false
        if row.favorite then row.text='[Star] '..row.text end
        if E:Data().showPrivateNotes and key and E:Data().guildNotes[key] then row.text=row.text..' | Private: '..E:Data().guildNotes[key] end
    end
    table.sort(self.rows,function(a,b)
        if a.favorite~=b.favorite then return a.favorite==true end
        if self:Data().onlineFirst and a.online~=b.online then return a.online==true end
        if self:Data().sortByName then return a.name:lower()<b.name:lower() end; return a.index<b.index
    end)
end
function E:Checklist(name,id,count)
    if not self:Allowed() then return false end
    name=T:Text(name):match('^%s*(.-)%s*$'); if #name<1 or #name>32 or not T:Number(id) or id<1 or id>100000000 or id~=math.floor(id) or not T:Number(count) or count<1 or count>100000 or count~=math.floor(count) then return false end
    local lists=self:Data().checklists
    if not lists[name] then local n=0; for _ in pairs(lists) do n=n+1 end; if n>=20 then return false end; lists[name]={} end
    lists[name][math.floor(id)]=math.floor(count); self:Trim(lists[name],100); return true
end
function E:ChecklistRows()
    local rows={}; local totals=select(2,FS.modules.Vendor:Snapshot())
    for name,list in pairs(self:Data().checklists) do for id,required in pairs(list) do
        local item=T:Call(C_Item and C_Item.GetItemInfo,id); local owned=totals[id] or 0
        rows[#rows+1]={list=name,id=id,required=required,owned=owned,text=name..' | '..(item or 'Item '..id)..' | '..owned..' / '..required..' | Missing '..math.max(0,required-owned)}
    end end
    table.sort(rows,function(a,b) if a.list~=b.list then return a.list<b.list end; return a.id<b.id end); return rows
end
local prepDefaults={durability=75,slots=4,itemLevel=0}
function E:PreparationTargets(name)
    local raw=self:Data().preparation[name] or {}
    local vendor=FS.modules.Vendor
    return {
        durability=vendor:ValidNumber(raw.durability,0,100) or prepDefaults.durability,
        slots=vendor:ValidNumber(raw.slots,0,200) or prepDefaults.slots,
        itemLevel=vendor:ValidNumber(raw.itemLevel,0,1000) or prepDefaults.itemLevel,
    }
end
function E:SavePreparation(name,durability,slots,itemLevel)
    name=T:Text(name):match('^%s*(.-)%s*$')
    if not self:Allowed() or #name==0 or #name>32 or name:find('[|%c]') then return false,'Enter an activity name of 1 to 32 characters.' end
    local vendor=FS.modules.Vendor
    durability=vendor:ValidNumber(tonumber(durability),0,100)
    slots=vendor:ValidNumber(tonumber(slots),0,200)
    itemLevel=vendor:ValidNumber(tonumber(itemLevel),0,1000)
    if not durability or not slots or not itemLevel or slots%1~=0 then return false,'Use durability 0–100, whole bag slots 0–200, and item level 0–1000.' end
    local all=self:Data().preparation
    if not all[name] then
        local count=0
        for _ in pairs(all) do count=count+1 end
        if count>=20 then return false,'You can keep up to 20 preparation activities.' end
    end
    all[name]={durability=durability,slots=slots,itemLevel=itemLevel}
    return true
end
local function instanceContext()
    local name,kind,_,_,_,_,_,map=T:Call(GetInstanceInfo)
    name=T:Text(name)
    if name=='' or (kind~='party' and kind~='raid') then return end
    return name,kind=='raid' and 'Raid' or 'Dungeon',map
end
E.recentEncounters={}
function E:RememberEncounter(id,boss)
    local instance,kind,map=instanceContext()
    boss=T:Text(boss)
    if not instance or not T:Number(id) or id<1 or id%1~=0 or boss=='' then return end
    self.recentEncounters[id]={instance=instance,kind=kind,map=map,boss=boss,time=GetTime(),profile=FS.db.profiles.current}
    self:Trim(self.recentEncounters,30)
end
local function isPlayerRecipient(recipient)
    recipient=T:Text(recipient):lower()
    if recipient=='' then return false end
    local unitName=UnitFullName or UnitName
    local player,realm=T:Call(unitName,'player')
    player=T:Text(player):lower()
    if player=='' then return false end
    if recipient~=player then
        realm=T:Text(realm)
        if realm=='' then realm=T:Text(T:Call(GetNormalizedRealmName)) end
        return realm~='' and recipient:gsub('%s','')==player..'-'..realm:gsub('%s',''):lower()
    end
    local count=T:Call(GetNumGroupMembers)
    if not T:Number(count) or count<0 or count>40 or count%1~=0 then return false end
    if count==0 then return true end
    local raid=T:Call(IsInRaid)
    if type(raid)~='boolean' then return false end
    local matches=raid and 0 or 1
    for index=1,raid and count or count-1 do
        local name=T:Text(T:Call(unitName,(raid and 'raid' or 'party')..index)):lower()
        if name=='' then return false end
        if name==player then matches=matches+1 end
    end
    return matches==1
end
function E:CompleteWishlistDrop(context,itemID,recipient)
    if not next(self:Data().wishlist) or not isPlayerRecipient(recipient) then return false end
    local changed=false
    local instance,boss=context.instance:lower(),context.boss:lower()
    for _,goal in pairs(self:Data().wishlist) do
        if not goal.acquired and goal.item==itemID and goal.instance:lower()==instance
            and (goal.boss=='' or goal.boss:lower()==boss) then
            goal.acquired=true
            changed=true
        end
    end
    if changed then
        local item=T:Text(T:Call(C_Item and C_Item.GetItemInfo,itemID))
        self:Alert('Wishlist acquired',false,(item~='' and item or ('Item '..itemID))..' from '..context.boss)
    end
    return changed
end
function E:ObserveEncounterLoot(encounterID,itemID,recipient)
    if not T:Number(encounterID) or not T:Number(itemID) or itemID<1 or itemID>100000000 or itemID%1~=0 then return false end
    local context=self.recentEncounters[encounterID]
    if not context or context.profile~=FS.db.profiles.current or GetTime()-context.time>600 then return false end
    local instance,kind,map=instanceContext()
    if instance~=context.instance or kind~=context.kind or map~=context.map then return false end
    local records=self:Data().encounterLoot
    local key=kind..'\031'..instance:lower()..'\031'..encounterID
    local record=records[key]
    if type(record)~='table' or type(record.items)~='table' then
        record={instance=instance,kind=kind,boss=context.boss,map=map,items={}}
        records[key]=record
    end
    local new=not record.items[itemID]
    record.time=time and time() or 0
    record.items[itemID]=true
    self:Trim(record.items,100)
    self:Trim(records,100)
    local acquired=self:CompleteWishlistDrop(context,itemID,recipient)
    local workbench=self.workbench
    if workbench and workbench.window and workbench.window:IsShown() then
        local view=workbench:Data().view
        if ((new or acquired) and view=='Dungeon & Raid Journal')
            or (acquired and (view=='Gear Wishlist' or view=='Next steps')) then
            workbench:Refresh()
        end
    end
    return true
end
function E:JournalInstances()
    local rows,seen={},{}
    local function add(name,kind,source,journalID,mapID,minimum,maximum)
        name=T:Text(name)
        if name=='' then return end
        local key=kind..':'..name:lower()
        local entry=seen[key]
        if not entry then
            entry={id=key,name=name,kind=kind,source=source,journalID=journalID}
            seen[key]=entry; rows[#rows+1]=entry
        end
        if not entry.mapID and T:Number(mapID) and mapID>0 then entry.mapID=mapID end
        if not entry.minimum and T:Number(minimum) and minimum>0 then entry.minimum=minimum end
        if not entry.maximum and T:Number(maximum) and maximum>0 then entry.maximum=maximum end
    end
    for _,raid in ipairs({false,true}) do
        local kind=raid and 'Raid' or 'Dungeon'
        if type(EJ_GetInstanceByIndex)=='function' then
            for index=1,500 do
                local id,name,_,_,_,_,_,_,_,_,map=T:Call(EJ_GetInstanceByIndex,index,raid)
                if not T:Number(id) or id<=0 then break end
                add(name,kind,'Game journal',id,map)
            end
        end
        local api=C_LFGList
        local category=raid and (GROUP_FINDER_CATEGORY_ID_RAIDS or 3) or (GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2)
        if api then
            for _,id in ipairs(T:Call(api.GetAvailableActivities,category) or {}) do
                local entry=T:Call(api.GetActivityInfoTable,id)
                if type(entry)=='table' then
                    add(entry.fullName,kind,'Group Finder',nil,entry.mapID,entry.minLevelSuggestion,entry.maxLevelSuggestion)
                end
            end
        end
    end
    local name,kind,map=instanceContext()
    if name then add(name,kind,'Current instance',nil,map) end
    for _,record in pairs(self:Data().encounterLoot) do
        if type(record)=='table' and (record.kind=='Dungeon' or record.kind=='Raid') then
            add(record.instance,record.kind,'Observed encounters',nil,record.map)
        end
    end
    table.sort(rows,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end; return a.name<b.name end)
    return rows
end
function E:JournalEncounters(instance)
    local rows,bosses={},{}
    local function add(name,description,id)
        local key=name:lower()
        if not bosses[key] then
            local boss={id=id,name=name,text=name,description=description,items={}}
            bosses[key]=boss; rows[#rows+1]=boss
        end
        return bosses[key]
    end
    if instance.journalID and type(EJ_GetEncounterInfoByIndex)=='function' then
        for index=1,100 do
            local name,description,id=T:Call(EJ_GetEncounterInfoByIndex,index,instance.journalID)
            if T:Text(name)=='' or not T:Number(id) or id<=0 then break end
            add(name,T:Text(description),id)
        end
    end
    for key,record in pairs(self:Data().encounterLoot) do
        if type(record)=='table' and record.kind==instance.kind and T:Text(record.instance):lower()==instance.name:lower()
            and T:Text(record.boss)~='' and type(record.items)=='table' then
            local boss=add(record.boss,'This encounter was reported by the game. Its loot list contains observed drops.',key)
            for id in pairs(record.items) do if T:Number(id) and id>0 then boss.items[id]=true end end
        end
    end
    return rows
end
function E:EncounterRunNote(boss)
    local instance,kind=T:Call(GetInstanceInfo)
    if kind~='party' and kind~='raid' then return false end
    local note=self:RunNote(instance,boss)
    if not note then return false end
    self:Alert('Run note',false,note.boss..': '..note.note)
    return true
end
function E:PreparationRows(name)
    local rows={}
    local function add(id,label,status,detail)
        rows[#rows+1]={id=id,text='['..status..'] '..label..' | '..detail,status=status}
        return rows[#rows]
    end
    local target=self:PreparationTargets(name)
    local vendor=FS.modules.Vendor
    local gear=FS.modules.Gear:Snapshot()
    local lowest,level=gear.lowest,gear.averageItemLevel
    if T:Number(lowest) then
        add('durability','Durability',(gear.broken>0 or lowest<target.durability) and 'Check' or 'Ready',
            ('Lowest %.0f%% / goal %.0f%% | %d broken'):format(lowest,target.durability,gear.broken))
    else add('durability','Durability','Unknown','No readable durability data') end
    if T:Number(level) then
        add('gear','Average equipped item level',target.itemLevel==0 and 'Info' or level>=target.itemLevel and 'Ready' or 'Check',
            ('%.1f%s'):format(level,target.itemLevel>0 and (' / goal '..target.itemLevel) or ''))
    else add('gear','Average equipped item level','Unknown','No readable item levels') end
    local free=0
    for bag=0,vendor:BagLimit() do
        local slots,family=T:Call(C_Container and C_Container.GetContainerNumFreeSlots,bag)
        if not T:Number(slots) or (slots>0 and not T:Number(family)) then free=nil; break end
        if family==0 then free=free+slots end
    end
    if free then add('bags','Free general bag slots',free>=target.slots and 'Ready' or 'Check',free..' / goal '..target.slots)
    else add('bags','Free general bag slots','Unknown','Bag space is unreadable') end
    local list=self:Data().checklists[name] or {}
    if next(list) then
        local ok,_,totals,unknown=pcall(vendor.Snapshot,vendor)
        local ids={}
        for id in pairs(list) do ids[#ids+1]=id end
        table.sort(ids)
        for _,id in ipairs(ids) do
            local required=list[id]
            local owned=ok and type(totals)=='table' and (totals[id] or 0)
            local item,link=T:Call(C_Item and C_Item.GetItemInfo,id)
            local known=T:Number(owned) and (owned>=required or unknown==0)
            local line=add('supply:'..id,item or 'Item '..id,known and (owned>=required and 'Ready' or 'Check') or 'Unknown',
                known and (owned..' / '..required..' carried') or ('Stock unreadable / goal '..required))
            line.item=id; line.link=link; line.required=required
        end
    end
    return rows
end
function E:Buyback(index)
    local V=FS.modules.Vendor
    if not self:Allowed() or not V:CanTransact() or type(BuybackItem)~="function" or not T:Number(index) then return false end
    local count=T:Call(GetNumBuybackItems) or 0; if index<1 or index>count then return false end
    local name,_,price=T:Call(GetBuybackItemInfo,index); local money=T:Call(GetMoney)
    if T:Text(name)=="" or not T:Number(price) or not T:Number(money) or price<0 or price>money then return false end
    BuybackItem(index); return true
end
local L=FS.modules.Loot; local loot=L.Event
local function ownLoot(message,includeCrafted)
    if T:Text(message)=="" or not L:OwnMessage(message,includeCrafted) then return end
    local link=message:match('(|Hitem:.-|h.-|h)'); if not link then return end
    local count=tonumber(message:match('|h|r?%s*x(%d+)')) or tonumber(message:match('x(%d+)%s*%.?$')) or 1; count=math.min(100000,math.max(1,count))
    return link,count
end
function E:RecordLoot(message)
    local link,count=ownLoot(message)
    if not link then return end
    local price=select(11,T:Call(C_Item and C_Item.GetItemInfo,link))
    self.loot.items=self.loot.items+count
    if T:Number(price) and price>=0 then self.loot.value=self.loot.value+price*count else self.loot.unknown=self.loot.unknown+count end
end
function L:Event(event,...)
    if event=='CHAT_MSG_LOOT' then E:RecordLoot(...) end
    return loot(self,event,...)
end
function E:ResetXP()
    self.xp={start=GetTime(),gained=0,current=T:Call(UnitXP,'player'),maximum=T:Call(UnitXPMax,'player'),level=T:Call(UnitLevel,'player')}
end
function E:ObserveXP()
    if not self.xp then self:ResetXP(); return end
    local x=self.xp; local now,max,level=T:Call(UnitXP,'player'),T:Call(UnitXPMax,'player'),T:Call(UnitLevel,'player')
    if not T:Number(now) or not T:Number(max) or not T:Number(level) then return end
    if T:Number(x.current) and T:Number(x.level) then
        if level==x.level and now<x.current then return end
        local delta=now-x.current
        if level==x.level+1 and T:Number(x.maximum) then delta=x.maximum-x.current+now
        elseif level~=x.level then delta=0 end
        if delta>0 then x.gained=x.gained+delta end
    end
    x.current,x.maximum,x.level=now,max,level
end
function E:XPStats()
    if not self.xp then self:ResetXP() end
    local x=self.xp; local elapsed=GetTime()-x.start; local rate=elapsed>=10 and x.gained>0 and x.gained*3600/elapsed or nil
    local remaining=T:Number(x.maximum) and x.maximum>0 and T:Number(x.current) and math.max(0,x.maximum-x.current)
    return x.gained,rate,rate and remaining and remaining/rate*3600 or nil
end
local M=FS.modules.Map
local function waypointMapID(id)
    return T:Number(id) and id>0 and id<=2147483647 and id%1==0
end
local function waypointMapNames(current)
    local maps=C_Map or {}
    local names={}
    local function add(info,id)
        if type(info)~='table' or not waypointMapID(id) then return end
        local key=T:Text(info.name):lower()
        if key=='' then return end
        if names[key]==nil then names[key]=id
        elseif names[key]~=id then names[key]=false end
    end
    local children=T:Call(maps.GetMapChildrenInfo,946,nil,true)
    if type(children)~='table' or #children==0 then children=T:Call(maps.GetMapChildrenInfo,947,nil,true) end
    if type(children)=='table' then
        for _,info in ipairs(children) do
            if type(info)=='table' then add(info,info.mapID) end
        end
    end
    if current then add(T:Call(maps.GetMapInfo,current),current) end
    return names
end
local wayCoordinates='(%d+%.?%d*)%s+(%d+%.?%d*)%s+(.-)%s*$'
function E:PreviewWaypointText(text,name)
    text=T:Text(text)
    name=T:Text(name):match('^%s*(.-)%s*$')
    if #name==0 or #name>40 or name:find('[|%c]') then return nil,'Enter a route name of 1 to 40 characters.' end
    if #text>12000 then return nil,'Waypoint text is too long.' end
    local maps=C_Map or {}
    local current=T:Call(maps.GetBestMapForUnit,'player')
    if not waypointMapID(current) then current=nil end
    local map,names,stops=current,nil,{}
    local lineNumber=0
    for line in (text..'\n'):gmatch('([^\n]*)\n') do
        lineNumber=lineNumber+1
        line=line:match('^%s*(.-)%s*$')
        if line~='' then
            if #stops>=50 then return nil,'A route can contain up to 50 stops.' end
            local prefix='Line '..lineNumber..': '
            local body=line:match('^/[Ww][Aa][Yy]%s+(.+)$')
            if not body or #line>300 then return nil,prefix..'enter a /way line with two coordinates.' end
            body=body..' '
            local x,y,label=body:match('^'..wayCoordinates)
            if not x then
                local id
                id,x,y,label=body:match('^#(%d+)%s+'..wayCoordinates)
                if id then
                    map=tonumber(id)
                    local info=waypointMapID(map) and T:Call(maps.GetMapInfo,map)
                    if type(info)~='table' then
                        return nil,prefix..'this map ID is unavailable in the game client.'
                    end
                else
                    local zone
                    zone,x,y,label=body:match('^([^#].-)%s+'..wayCoordinates)
                    if not zone then return nil,prefix..'enter two coordinates separated by a space.' end
                    names=names or waypointMapNames(current)
                    map=names[zone:lower()]
                    if not map then return nil,prefix..'use an exact zone name from your game client or #MapID.' end
                end
            end
            if not map then return nil,prefix..'include a zone name or #MapID.' end
            x,y=tonumber(x),tonumber(y)
            if x>100 or y>100 then return nil,prefix..'coordinates must be between 0 and 100.' end
            if #label>60 or label:find('[|%c]') then return nil,prefix..'use a plain label of up to 60 characters.' end
            stops[#stops+1]={map=map,x=x/100,y=y/100,name=label}
        end
    end
    if #stops==0 then return nil,'Paste at least one /way line.' end
    return self:PreviewRoute(self:Encode({kind='route',version=1,name=name,stops=stops}))
end
local gatheringEvents=CreateFrame('Frame')
gatheringEvents:SetScript('OnEvent',function(_,_,message)
    local run=E.gathering
    if not run then return end
    local link,count=ownLoot(message,false)
    if not link then return end
    local id=FS.modules.Vendor:ItemID(link)
    if not id then return end
    if run.items[id]==nil then
        if run.distinct>=200 then run.partial=true; return end
        run.distinct=run.distinct+1
    end
    run.items[id]=(run.items[id] or 0)+count
    run.total=run.total+count
end)
function E:StartGathering(name)
    if self.gathering or not self:Allowed() or not FS:IsModuleEnabled('Map') or not M:Data().navigation then return false end
    if not self:Data().routes[name] or not FS:RegisterClientEvent(gatheringEvents,'CHAT_MSG_LOOT') then return false end
    if not self:LoadRoute(name) or not self:StartQueue() then gatheringEvents:UnregisterEvent('CHAT_MSG_LOOT'); return false end
    self.gathering={route=name,start=GetTime(),total=0,distinct=0,items={}}
    return true
end
function E:StopGatheringCapture()
    self.gathering=nil
    gatheringEvents:UnregisterEvent('CHAT_MSG_LOOT')
end
function E:FinishGathering(reason)
    local run=self.gathering
    if not run then return false end
    self:StopGatheringCapture()
    run.duration=math.max(0,math.floor(GetTime()-run.start))
    run.start=nil
    run.time=time and time() or 0
    run.result=reason
    local history=self:Data().gatheringRuns
    table.insert(history,1,run)
    while #history>20 do table.remove(history) end
    return true
end
function E:LoadRoute(name)
    local stops=self:Data().routes[name]
    if not self:Allowed() or not stops or self.gathering then return false end
    local target,manual=self.queueActive and self.queueTarget,M.manualTarget
    self.queueActive=false; self.queueTarget=nil
    if target and manual and target.map==manual.map and target.x==manual.x and target.y==manual.y then
        M:ClearNavigation()
    end
    self:Data().waypointQueue=self.Copy(stops)
    return true
end
function E:StartQueue()
    local next=self:Data().waypointQueue[1]; if not next or not FS:IsModuleEnabled('Map') then return false end
    M:SetNavigation(next); self.queueActive=true; self.queueTarget=self.Copy(next); return true
end
function E:QueueArrival()
    if not self.queueActive or M.navUpdating then return end
    local p=M.destination; local target=self.queueTarget
    if not p or not target or p.map~=target.map or p.x~=target.x or p.y~=target.y then
        self.queueActive=false; self:FinishGathering('Navigation changed'); return
    end
    local east,north=M:NavigationVector(p)
    if not T:Number(east) or not T:Number(north) or east*east+north*north>M:Data().arrival^2 then return end
    table.remove(self:Data().waypointQueue,1); self:Alert('Waypoint arrival',false,target.name)
    self.queueActive=false
    if self:Data().waypointQueue[1] then self:StartQueue()
    else self.queueTarget=nil; self:FinishGathering('Route completed'); M:ClearNavigation() end
end
local render=M.RenderNavigation
function M:RenderNavigation() render(self); E:QueueArrival() end
local clearNavigation=M.ClearNavigation
function M:ClearNavigation()
    if E.gathering then E:FinishGathering('Navigation stopped') end
    return clearNavigation(self)
end
function E:Audit(event)
    local rows={}; for _,name in ipairs({'MainActionBar','MultiBarBottomLeft','MultiBarBottomRight'}) do
        local f=_G[name]
        if f then local p={T:Call(f.GetPoint,f)}; local parts={name,tostring(T:Call(f.GetWidth,f)),tostring(T:Call(f.GetHeight,f)),tostring(T:Call(f.GetScale,f))}; for _,v in ipairs(p) do parts[#parts+1]=tostring(v) end; rows[#rows+1]=table.concat(parts,' / ') end
    end
    self.audit[#self.audit+1]={text=event..' | '..table.concat(rows,' | '),time=GetTime()}; while #self.audit>20 do table.remove(self.audit,1) end
end
function E:Initialize()
    self:Normalize(); self:ResetXP(); self:Refresh()
    local assigned=FS.db.profiles.characters[self:CharacterKey() or '']
    if assigned and assigned~=FS.db.profiles.current and FS.db.profiles.saved[assigned] then FS.modules.Profiles:Load(assigned) end
    if self.events then return end; self.events=CreateFrame('Frame')
    for _,event in ipairs({'GROUP_ROSTER_UPDATE','PLAYER_XP_UPDATE','PLAYER_LEVEL_UP','PLAYER_ENTERING_WORLD','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_TARGET_CHANGED','ENCOUNTER_START','ENCOUNTER_END','ENCOUNTER_LOOT_RECEIVED'}) do FS:RegisterClientEvent(self.events,event) end
    self.events:SetScript('OnEvent',function(_,event,unit,encounterName,_,_,recipient)
        if event=='GROUP_ROSTER_UPDATE' then self:GroupChanged()
        elseif event=='PLAYER_XP_UPDATE' and (not unit or unit=='player') and FS:IsModuleEnabled('QoL') then self:ObserveXP()
        elseif event=='PLAYER_LEVEL_UP' then if FS:IsModuleEnabled('QoL') then self:Alert('Level up') end
        elseif event=='ENCOUNTER_START' then self:RememberEncounter(unit,encounterName); self:EncounterRunNote(encounterName)
        elseif event=='ENCOUNTER_END' then self:RememberEncounter(unit,encounterName)
        elseif event=='ENCOUNTER_LOOT_RECEIVED' then self:ObserveEncounterLoot(unit,encounterName,recipient)
        elseif event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_REGEN_ENABLED' then self:UpdateFilters()
        end
        if event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_REGEN_ENABLED' or event=='PLAYER_TARGET_CHANGED' then self:Audit(event) end
    end)
    self:SyncEvents()
end
