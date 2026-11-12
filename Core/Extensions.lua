local _,FS=...
local E={chat={},loot={items=0,value=0,unknown=0},undo={},alerts={},notifications={},noticeTimes={},audit={}}; FS.Extensions=E
E.alertCategories={'Keyword','Important cast','Waypoint arrival','Low durability','Level up','Low stock','Rare or elite','Run note','Wishlist acquired'}
local alertCategory={}
for _,category in ipairs(E.alertCategories) do alertCategory[category]=true end
local alertDefaults={sound='Silent',channel='SFX',popup=false,history=true}
local runAlertDefaults={sound='Silent',channel='SFX',popup=true,history=false}
FS.Text={tools="More tools",apply="Apply",preview="Preview",cancel="Cancel",clear="Clear",back="Back to Control Center",close="Close",previous="Previous",next="Next",enabled="Enabled",disabled="Disabled",unavailable="Unavailable in this client",leaveCombat="Leave combat before changing these settings."}
FS.defaults.extras={palette="Original",nativeWindows=true,keywordsEnabled=false,captureChat=false,trackGroups=false,showPrivateNotes=false,
    discovery={enabled=false,elites=false,portrait=true},preparation={},wishlist={},runNotes={},encounterLoot={},
    keywords={},guildNotes={},guildFavorites={},recentGroups={},checklists={},npcRules={},importantSpells={},settingFavorites={},alerts={},waypointQueue={},contexts={},routes={},routeDetails={},gatheringRuns={}}
local function copy(v) if type(v)~="table" then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
E.Copy=copy
function E:Allowed() return not InCombatLockdown() and not FS.modules.Vendor.busy end
function E:Data() return FS.db.extras end
local function runNoteKey(instance,boss)
    instance=FS.Tools:Text(instance):match('^%s*(.-)%s*$')
    boss=FS.Tools:Text(boss):match('^%s*(.-)%s*$')
    if instance=='' or boss=='' or #instance>80 or #boss>80 or instance:find('[|%c]') or boss:find('[|%c]') then return end
    return instance:lower()..'\031'..boss:lower(),instance,boss
end
function E:RunNote(instance,boss)
    local key=runNoteKey(instance,boss)
    return key and self:Data().runNotes[key] or nil
end
function E:SaveRunNote(instance,boss,note)
    if not self:Allowed() then return false,'Finish your current action before editing notes.' end
    local key,cleanInstance,cleanBoss=runNoteKey(instance,boss)
    note=FS.Tools:Text(note):match('^%s*(.-)%s*$')
    if not key or note=='' or #note>200 or note:find('[|%c]') then return false,'Enter an instance, boss and a plain-text note of up to 200 characters.' end
    local notes=self:Data().runNotes
    if not notes[key] then
        local count=0
        for _ in pairs(notes) do count=count+1 end
        if count>=100 then return false,'You can keep up to 100 run notes.' end
    end
    notes[key]={instance=cleanInstance,boss=cleanBoss,note=note}
    return true
end
local function wishlistEntry(instance,boss,item)
    instance=FS.Tools:Text(instance):match('^%s*(.-)%s*$')
    boss=FS.Tools:Text(boss):match('^%s*(.-)%s*$')
    if instance=='' or #instance>80 or #boss>80 or instance:find('[|%c]') or boss:find('[|%c]') then return end
    if not FS.Tools:Number(item) or item<1 or item>100000000 or item%1~=0 then return end
    return {instance=instance,boss=boss,item=item},instance:lower()..'\031'..boss:lower()..'\031'..item
end
function E:WishlistGoalForDrop(instance,boss,item)
    local _,key=wishlistEntry(instance,boss,item)
    if not key then return end
    local wishlist=self:Data().wishlist
    local goal=wishlist[key]
    if not goal then
        _,key=wishlistEntry(instance,'',item)
        goal=wishlist[key]
    end
    if goal then return goal,key end
end
function E:AddWishlistItem(instance,boss,item)
    if not self:Allowed() then return false,'Finish your current action before changing the wishlist.' end
    local entry,key=wishlistEntry(instance,boss,tonumber(item))
    if not entry then return false,'Enter an instance name and a valid item ID.' end
    local wishlist=self:Data().wishlist
    if wishlist[key] then return false,'That item is already on the wishlist for this source.' end
    local count=0
    for _ in pairs(wishlist) do count=count+1 end
    if count>=100 then return false,'The wishlist holds up to 100 goals.' end
    entry.acquired=false; wishlist[key]=entry
    return true
end
local function routeName(name)
    if type(name)~="string" then return end
    name=name:match("^%s*(.-)%s*$")
    if #name>0 and #name<=40 and not name:find("[|%c]") then return name end
end
local function routeStops(stops)
    if type(stops)~="table" or #stops==0 or #stops>50 then return end
    local result={}
    for index,stop in pairs(stops) do
        if type(index)~="number" or index%1~=0 or index<1 or index>#stops or type(stop)~="table"
            or not FS.Tools:Number(stop.map) or stop.map<1 or stop.map%1~=0
            or not FS.Tools:Number(stop.x) or stop.x<0 or stop.x>1
            or not FS.Tools:Number(stop.y) or stop.y<0 or stop.y>1 then return end
        local name=type(stop.name)=="string" and stop.name or ""
        if #name>60 or name:find("[|%c]") then return end
        result[index]={map=stop.map,x=stop.x,y=stop.y,name=name~="" and name or "Waypoint"}
    end
    for i=1,#stops do if not result[i] then return end end
    return result
end
local function routeDetails(raw)
    if type(raw)~="table" then return end
    local function clean(value,limit)
        if value==nil then return "" end
        if type(value)~="string" or #value>limit or value:find("[|%c]") then return end
        return value:match("^%s*(.-)%s*$")
    end
    local profession,source=clean(raw.profession,32),clean(raw.source,100)
    if not profession or not source then return end
    local minimum,maximum=clean(raw.minimum,4),clean(raw.maximum,4)
    if not minimum or not maximum then return end
    if minimum~="" or maximum~="" then
        if profession=="" or not minimum:match("^%d+$") or not maximum:match("^%d+$")
            or tonumber(minimum)<1 or tonumber(maximum)<tonumber(minimum) then return end
        minimum,maximum=tostring(tonumber(minimum)),tostring(tonumber(maximum))
    end
    return {profession=profession,source=source,minimum=minimum,maximum=maximum}
end
function E:RouteTags(details)
    if not details or details.profession=="" then return "" end
    return details.profession..(details.minimum~="" and (" "..details.minimum.."-"..details.maximum) or "")
end
local function storeRouteDetails(entries,name,details)
    if details and (details.profession~="" or details.source~="") then entries[name]=details
    else entries[name]=nil end
end
function E:SaveRoute(name,stops,replace,details)
    if not self:Allowed() then return false,"Finish your current action before saving a route." end
    name=routeName(name)
    if not name then return false,"Enter a route name of 1 to 40 characters." end
    local route=routeStops(stops)
    if not route then return false,"A route needs 1 to 50 valid stops." end
    local data=self:Data()
    local routes=data.routes
    local metadata=details~=nil and routeDetails(details)
    if details~=nil and not metadata then return false,"Invalid profession, skill range or route source." end
    if routes[name] and not replace then return false,"That route name already exists." end
    if not routes[name] then
        local count=0
        for _ in pairs(routes) do count=count+1 end
        if count>=30 then return false,"The library holds up to 30 routes." end
    end
    routes[name]=route
    if metadata then storeRouteDetails(data.routeDetails,name,metadata) end
    return true
end
function E:PreviewRoute(code)
    local payload,message=self:Decode(code)
    if not payload then return nil,message end
    if type(payload)~="table" or payload.kind~="route" or payload.version~=1 then return nil,"Unknown route format." end
    local name,stops=routeName(payload.name),routeStops(payload.stops)
    if not name or not stops then return nil,"The route has an invalid name or stops." end
    local details=payload.details~=nil and routeDetails(payload.details)
    if payload.details~=nil and not details then return nil,"The route has invalid profession or source details." end
    if self:Data().routes[name] then return nil,"That route name already exists. Rename the local route first." end
    local message="Import "..name.." with "..#stops.." stops."
    local tags=self:RouteTags(details or nil)
    if tags~="" then message=message.." "..tags.."." end
    if details and details.source~="" then message=message.." Source listed by the author: "..details.source end
    return {name=name,stops=stops,details=details or nil},message
end
function E:RenameRoute(previous,newName,details)
    if not self:Allowed() then return false,"Finish your current action first." end
    local data=self:Data()
    local routes=data.routes
    local stops=routes[previous]
    if not stops then return false,"That route is no longer available." end
    if newName=="" then routes[previous]=nil; data.routeDetails[previous]=nil; return true end
    newName=routeName(newName)
    if not newName then return false,"Enter a route name of 1 to 40 characters." end
    if newName~=previous and routes[newName] then return false,"That route name already exists." end
    local metadata=details~=nil and routeDetails(details)
    if details~=nil and not metadata then return false,"Enter a profession and two whole skill levels in ascending order, or leave both levels empty. Use plain text for the source." end
    storeRouteDetails(data.routeDetails,newName,metadata or data.routeDetails[previous])
    if newName~=previous then
        routes[newName]=stops
        routes[previous]=nil
        data.routeDetails[previous]=nil
    end
    return true
end
function E:SaveContext(name)
    if not self:Allowed() or name=="" or #name>32 or name:find("[|%c]") then return false end
    local contexts=self:Data().contexts
    if not contexts[name] then
        local count=0
        for _ in pairs(contexts) do count=count+1 end
        if count>=12 then return false end
    end
    contexts[name]={
        layout=copy(FS.db.layout), alerts=copy(self:Data().alerts),
        tracker=FS.db.quests.tracker, coordinates=FS.db.map.coordinates,
    }
    FS.modules.Profiles:PersistCurrent()
    return true
end
function E:UseContext(name)
    if not self:Allowed() then return false end
    local preset=self:Data().contexts[name]
    if type(preset)~="table" or type(preset.layout)~="table" or type(preset.layout.frames)~="table"
        or type(preset.alerts)~="table" or type(preset.tracker)~="boolean" or type(preset.coordinates)~="boolean" then return false end
    local layout=FS.Layout
    layout:Stop()
    local previous=FS.db.layout.frames
    FS.db.layout=copy(preset.layout)
    FS:ApplyDefaults(FS.db.layout,FS.defaults.layout)
    layout:Normalize()
    self:Data().alerts=copy(preset.alerts)
    FS.db.quests.tracker=preset.tracker
    FS.db.map.coordinates=preset.coordinates
    self:Normalize()
    for id in pairs(previous) do
        if not FS.db.layout.frames[id] then layout:RestoreTarget(id) end
    end
    FS.modules.Quests:SettingsChanged()
    FS.modules.Map:SettingsChanged()
    layout:ApplyAll()
    FS.modules.Profiles:PersistCurrent()
    return true
end
function E:Trim(map,limit)
    local count=0
    for _ in pairs(map) do
        count=count+1
        if count>limit then break end
    end
    if count<=limit then return end
    local keys={}; for key,value in pairs(map) do keys[#keys+1]={key=key,time=type(value)=="table" and tonumber(value.time) or 0} end
    table.sort(keys,function(a,b) if a.time~=b.time then return a.time>b.time end; return tostring(a.key)<tostring(b.key) end)
    for i=limit+1,#keys do map[keys[i].key]=nil end
end
function E:Normalize()
    FS:ApplyDefaults(FS.db.extras,FS.defaults.extras); local d=self:Data()
    if self.dataRef~=d then
        self.dataRef=d; self.queueActive=false; self.queueTarget=nil
        if self.gathering then self:StopGatheringCapture() end
        for name,stops in pairs(d.routes) do
            d.routes[name]=routeName(name)==name and routeStops(stops) or nil
        end
        self:Trim(d.routes,30)
        local details={}
        for name in pairs(d.routes) do
            storeRouteDetails(details,name,routeDetails(d.routeDetails[name]))
        end
        d.routeDetails=details
        local wishlist={}
        for _,raw in pairs(d.wishlist) do
            if type(raw)=='table' then
                local entry,key=wishlistEntry(raw.instance,raw.boss,raw.item)
                if entry then entry.acquired=raw.acquired==true; wishlist[key]=entry end
            end
        end
        self:Trim(wishlist,100); d.wishlist=wishlist
        local notes={}
        for _,raw in pairs(d.runNotes) do
            if type(raw)=='table' then
                local key,instance,boss=runNoteKey(raw.instance,raw.boss)
                if key and type(raw.note)=='string' and #raw.note>0 and #raw.note<=200 and not raw.note:find('[|%c]') then
                    notes[key]={instance=instance,boss=boss,note=raw.note}
                end
            end
        end
        self:Trim(notes,100); d.runNotes=notes
    end
    if FS.db.workbench then FS.db.workbench.enabled=true end
    for name,preset in pairs(d.contexts) do
        if type(name)~="string" or #name==0 or #name>32 or name:find("[|%c]") or type(preset)~="table" then d.contexts[name]=nil end
    end
    self:Trim(d.contexts,12)
    if d.palette~="Original" and d.palette~="Color-friendly" and d.palette~="High contrast" then d.palette="Original" end
    for _,key in ipairs({"guildNotes","guildFavorites","recentGroups","checklists","npcRules","importantSpells","settingFavorites","alerts"}) do
        for id,value in pairs(d[key]) do if type(id)~="string" and type(id)~="number" then d[key][id]=nil
            elseif type(value)~="string" and type(value)~="boolean" and type(value)~="table" then d[key][id]=nil end end
        self:Trim(d[key],key=="settingFavorites" and 100 or 200)
    end
    for id,note in pairs(d.guildNotes) do if type(note)~="string" then d.guildNotes[id]=nil else d.guildNotes[id]=note:sub(1,256) end end
    for _,key in ipairs({'guildFavorites','settingFavorites'}) do for id,value in pairs(d[key]) do if value~=true or type(id)~='string' then d[key][id]=nil end end end
    for id,r in pairs(d.recentGroups) do
        if type(id)~='string' or type(r)~='table' or type(r.name)~='string' or type(r.time)~='number' or r.time~=r.time or r.time<0 then d.recentGroups[id]=nil else r.name=r.name:sub(1,100) end
    end
    for category,a in pairs(d.alerts) do
        if not alertCategory[category] then d.alerts[category]=nil
        else
            if type(a)~='table' then a={}; d.alerts[category]=a end
            FS:ApplyDefaults(a,category=='Run note' and runAlertDefaults or alertDefaults)
            if a.sound~='Bell' and a.sound~='Ready' and a.sound~='Warning' then a.sound='Silent' end
            if a.channel~='Master' and a.channel~='Dialog' then a.channel='SFX' end
        end
    end
    for id,rule in pairs(d.npcRules) do if type(id)~="number" or id<1 or type(rule)~="table" then d.npcRules[id]=nil end end
    self:Trim(d.npcRules,64); self:Trim(d.recentGroups,100)
    for id,value in pairs(d.importantSpells) do if type(id)~="number" or id<1 or value~=true then d.importantSpells[id]=nil end end
    local keywords={}; for _,word in ipairs(d.keywords) do if type(word)=="string" and #word>=2 and #word<=64 and not word:find('|',1,true) and #keywords<20 then keywords[#keywords+1]=word end end; d.keywords=keywords
    local queue={}; for _,p in ipairs(d.waypointQueue) do if type(p)=="table" and type(p.map)=="number" and type(p.x)=="number" and type(p.y)=="number" and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 and #queue<50 then queue[#queue+1]={map=p.map,x=p.x,y=p.y,name=type(p.name)=="string" and p.name:sub(1,60) or "Waypoint"} end end; d.waypointQueue=queue
    for name,list in pairs(d.checklists) do
        if type(name)~="string" or #name>32 or type(list)~="table" then d.checklists[name]=nil
        else self:Trim(list,100); for id,count in pairs(list) do if type(id)~="number" or id<1 or type(count)~="number" or count<1 or count>100000 then list[id]=nil else list[id]=math.floor(count) end end end
    end; self:Trim(d.checklists,20)
    for name,target in pairs(d.preparation) do
        if type(name)~='string' or #name==0 or #name>32 or name:find('[|%c]') or type(target)~='table' then d.preparation[name]=nil end
    end
    self:Trim(d.preparation,20)
    local manager=FS.db.profiles
    if type(manager.backups)~="table" then manager.backups={} end
    if type(manager.characters)~="table" then manager.characters={} end
    for i=#manager.backups,1,-1 do local b=manager.backups[i]; if type(b)~='table' or type(b.name)~='string' or type(b.data)~='table' or type(b.reason)~='string' then table.remove(manager.backups,i) end end
    for key,name in pairs(manager.characters) do if type(key)~='string' or type(name)~='string' then manager.characters[key]=nil end end
    while #manager.backups>5 do table.remove(manager.backups) end
end
-- Length-delimited data, not executable Lua. Parser limits protect pasted imports.
function E:Encode(value)
    local count=0
    local function encode(v,depth)
        count=count+1; assert(depth<=20 and count<=50000,"Profile too complex")
        local t=type(v)
        if t=="string" then assert(#v<=16384,"String too long"); return 's'..#v..':'..v end
        if t=="boolean" then return v and 'b1' or 'b0' end
        if t=="number" then assert(v==v and math.abs(v)<1e12,"Invalid number"); return 'n'..string.format('%.17g',v)..';' end
        assert(t=="table","Unsupported profile value")
        local keys={}; for k in pairs(v) do assert(type(k)=="number" or type(k)=="string","Invalid key"); keys[#keys+1]=k end
        table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)<type(b) end; return a<b end)
        local out={'t'..#keys..':'}; for _,k in ipairs(keys) do out[#out+1]=encode(k,depth+1); out[#out+1]=encode(v[k],depth+1) end; return table.concat(out)
    end
    local out='FS1:'..encode(value,0); assert(#out<=200000,"Profile exceeds 200 KB"); return out
end
function E:Decode(text)
    local ok,value=pcall(function()
        assert(type(text)=="string" and #text<=200000 and text:sub(1,4)=='FS1:',"Not a ForeverSuite export")
        local at,nodes=5,0
        local function amount(delimiter,maximum)
            local endAt=text:find(delimiter,at,true); assert(endAt,"Truncated data")
            local digits=text:sub(at,endAt-1); assert(digits:match('^%d+$'),"Invalid length")
            local n=tonumber(digits); assert(n and n<=maximum,"Data limit exceeded"); at=endAt+1; return n
        end
        local function read(depth)
            nodes=nodes+1; assert(depth<=20 and nodes<=50000,"Profile too complex")
            local tag=text:sub(at,at); at=at+1
            if tag=='s' then local n=amount(':',16384); assert(at+n-1<=#text,"Truncated string"); local s=text:sub(at,at+n-1); at=at+n; return s end
            if tag=='b' then local b=text:sub(at,at); assert(b=='0' or b=='1',"Invalid boolean"); at=at+1; return b=='1' end
            if tag=='n' then local e=text:find(';',at,true); assert(e,"Invalid number"); local n=tonumber(text:sub(at,e-1)); assert(n and n==n and math.abs(n)<1e12,"Invalid number"); at=e+1; return n end
            assert(tag=='t',"Unknown data tag"); local n=amount(':',10000); local result,seen={},{}
            for _=1,n do local k=read(depth+1); assert((type(k)=='number' or type(k)=='string') and not seen[k],"Invalid or duplicate key"); seen[k]=true; result[k]=read(depth+1) end; return result
        end
        local result=read(0); assert(at==#text+1,"Trailing data"); return result
    end)
    if ok then return value end; return nil,tostring(value)
end
local P=FS.modules.Profiles
function P:Backup(name,data,reason)
    FS.db.profiles.backups=FS.db.profiles.backups or {}; local list=FS.db.profiles.backups
    table.insert(list,1,{name=name,data=copy(data),reason=reason or "Replaced",time=time and time() or 0})
    while #list>5 do table.remove(list) end
end
function P:Export()
    local data=self:Snapshot()
    if data.extras then
        data.extras.guildNotes={}; data.extras.recentGroups={}; data.extras.gatheringRuns=nil
        data.extras.runNotes=nil; data.extras.encounterLoot=nil
    end
    for _,section in pairs(data) do if type(section)=="table" then section.history=nil end end
    return E:Encode({format=1,settings=data})
end
function P:PreviewImport(text)
    local parsed,err=E:Decode(text); if not parsed then return nil,err end
    if type(parsed)~="table" or parsed.format~=1 or type(parsed.settings)~="table" then return nil,"Unknown export format" end
    local count=0
    for key,value in pairs(parsed.settings) do
        if key=="profiles" or key=="setup" or key=="patchLog" or key=="compatibility" or FS.defaults[key]==nil or type(value)~=type(FS.defaults[key]) then return nil,"Invalid settings section: "..tostring(key) end
        count=count+1
    end
    if count==0 then return nil,"Empty profile" end
    local canonical=pcall(E.Encode,E,parsed)
    if not canonical then return nil,'Profile exceeds the supported data limits.' end
    return parsed.settings,"Validated "..count.." settings sections. Import replaces only the named profile; a backup is kept."
end
local function saveImport(self,name,data)
    if not self:Allowed() or type(data)~="table" or type(name)~="string" then return false end
    name=name:match('^%s*(.-)%s*$'); if #name<1 or #name>32 then return false end
    local checked=copy(data)
    local saved=FS.db.profiles.saved
    if saved[name] and name~=FS.db.profiles.current then self:Backup(name,saved[name],"Before import") else self:Backup(FS.db.profiles.current,self:Snapshot(),"Before import") end
    if checked.extras then
        checked.extras.guildNotes=copy(FS.db.extras.guildNotes)
        checked.extras.recentGroups=copy(FS.db.extras.recentGroups)
        checked.extras.gatheringRuns=copy(FS.db.extras.gatheringRuns)
        checked.extras.runNotes=copy(FS.db.extras.runNotes)
        checked.extras.encounterLoot=copy(FS.db.extras.encounterLoot)
    end
    for key,section in pairs(checked) do if type(section)=='table' and type(FS.db[key])=='table' and FS.db[key].history and not section.history then section.history=copy(FS.db[key].history) end end
    saved[name]=copy(checked); return self:Load(name)
end
function P:Import(name,data)
    local ok,code=pcall(E.Encode,E,{format=1,settings=data})
    local checked=ok and self:PreviewImport(code)
    if not checked then return false end
    return saveImport(self,name,checked)
end

local function sameValue(left,right)
    if left==right then return true end
    if type(left)~="table" or type(right)~="table" then return false end
    for key,value in pairs(left) do if not sameValue(value,right[key]) then return false end end
    for key in pairs(right) do if left[key]==nil then return false end end
    return true
end

function P:ReviewImport(code)
    local incoming,message=self:PreviewImport(code)
    if not incoming then return nil,message end
    return self:ReviewSections(incoming,"This export matches your current settings.")
end
function P:ReviewSaved(name)
    if name==FS.db.profiles.current then return nil,"This profile is already active." end
    local saved=FS.db.profiles.saved[name]
    if not saved then return nil,"This profile is no longer available." end
    return self:ReviewSections(copy(saved),"This profile matches your current settings.")
end
function P:ReviewSections(incoming,unchanged)
    local baseline=self:Snapshot()
    incoming.schemaVersion=nil
    local sections={}
    for key,value in pairs(incoming) do
        local current=baseline[key]
        if type(value)=="table" then
            value.history=type(current)=="table" and copy(current.history) or nil
            if key=="extras" then
                value.guildNotes=copy(FS.db.extras.guildNotes)
                value.recentGroups=copy(FS.db.extras.recentGroups)
                value.gatheringRuns=copy(FS.db.extras.gatheringRuns)
                value.runNotes=copy(FS.db.extras.runNotes)
                value.encounterLoot=copy(FS.db.extras.encounterLoot)
            end
            if type(FS.defaults[key])=="table" then FS:ApplyDefaults(value,FS.defaults[key]) end
        end
        if not sameValue(current,value) then
            local changes={}
            if type(current)=="table" and type(value)=="table" then
                for field,setting in pairs(value) do
                    if not sameValue(current[field],setting) then changes[#changes+1]=tostring(field) end
                end
                for field in pairs(current) do
                    if value[field]==nil then changes[#changes+1]=tostring(field) end
                end
                table.sort(changes)
            end
            sections[#sections+1]={key=key,changes=changes}
        end
    end
    if #sections==0 then return nil,unchanged end
    table.sort(sections,function(a,b) return a.key<b.key end)
    return {incoming=incoming,sections=sections,selected={},profile=FS.db.profiles.current},
        "Compared with your active profile. Select the sections to copy into the named profile."
end

function P:ImportSelected(name,review)
    if FS.db.profiles.current~=review.profile then
        return false,"Your active profile changed. Click Preview to compare again."
    end
    if #name>32 then return false,"Use a profile name of 32 characters or fewer." end
    local data=self:Snapshot()
    local included=false
    for _,section in ipairs(review.sections) do
        if review.selected[section.key] then
            local incoming=copy(review.incoming[section.key])
            local current=data[section.key]
            if type(incoming)=="table" then incoming.history=type(current)=="table" and copy(current.history) or nil end
            data[section.key]=incoming
            included=true
        end
    end
    if not included then return false,"Select at least one section." end
    if not self:Allowed() then return false,"Finish your current action before applying the profile." end
    return saveImport(self,name,data)
end
function P:RestoreBackup(index)
    local item=FS.db.profiles.backups[index]; if not item then return false end
    if not self:Allowed() then return false end
    local name,data=item.name,copy(item.data); self:Backup(FS.db.profiles.current,self:Snapshot(),'Before restore')
    FS.db.profiles.saved[name]=data; return self:Load(name)
end
function E:CharacterKey()
    local name=FS.Tools:Call(UnitName,"player"); local realm=FS.Tools:Call(GetNormalizedRealmName) or FS.Tools:Call(GetRealmName) or "Realm"
    return type(name)=="string" and name..'-'..realm or nil
end
function E:StockRecords()
    if type(ForeverSuiteStock)~="table" then ForeverSuiteStock={} end
    return ForeverSuiteStock
end
function E:RecordStock()
    if not self:Allowed() then return false end
    local key=self:CharacterKey()
    if not key or not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then return false end
    local ok,_,counts,unknown=pcall(FS.modules.Vendor.Snapshot,FS.modules.Vendor)
    if not ok or type(counts)~="table" or unknown~=0 then return false end
    local records=self:StockRecords()
    local record=type(records[key])=="table" and records[key] or {}
    local stamp=time and time() or 0
    record.counts=counts; record.bagTime=stamp; record.time=stamp
    records[key]=record
    self:Trim(records,50)
    return true
end
local function observedProfessions()
    if type(GetProfessions)~="function" or type(GetProfessionInfo)~="function" then return end
    local values={pcall(GetProfessions)}
    if not values[1] then return end
    local rows,seen={},{}
    for index=2,9 do
        local id=values[index]
        if not FS.HUD:Safe(id) or (id~=nil and not FS.Tools:Number(id)) then return end
        if id and id>0 and not seen[id] then
            local name,_,skill,maximum=FS.Tools:Call(GetProfessionInfo,id)
            if FS.Tools:Text(name)=="" or not FS.Tools:Number(skill) or not FS.Tools:Number(maximum) or skill<0 or maximum<skill then return end
            seen[id]=true
            rows[#rows+1]={name=name,skill=skill,maximum=maximum}
        end
    end
    table.sort(rows,function(a,b) return a.name<b.name end)
    return rows
end
function E:RecordCharacter()
    if not self:Allowed() then return false,"Leave combat or finish the current vendor action before recording." end
    local key=self:CharacterKey()
    if not key then return false,"The current character is unavailable." end
    local bags=self:RecordStock()
    local records=self:StockRecords()
    local record=type(records[key])=="table" and records[key] or {}
    if record.counts and record.bagTime==nil then record.bagTime=record.time end
    local stamp=time and time() or 0
    local professions=observedProfessions()
    if professions then record.professions={items=professions,time=stamp} end
    local ok,gear=pcall(FS.modules.Gear.Snapshot,FS.modules.Gear)
    local gearRead=ok and type(gear)=="table" and not gear.incomplete and FS.Tools:Number(gear.equipped) and gear.equipped>0 and type(gear.items)=="table"
    if gearRead then
        local items={}
        for _,row in ipairs(gear.items) do
            if row.equipped then
                items[#items+1]={slot=row.label,id=FS.Tools:Number(row.id) and row.id or nil,
                    name=FS.Tools:Text(row.name),level=row.itemLevel}
            end
        end
        record.gear={items=items,level=gear.averageItemLevel,lowest=gear.lowest,time=stamp}
    end
    local recorded={}
    if bags then recorded[#recorded+1]="bags" end
    if professions then recorded[#recorded+1]="professions" end
    if gearRead then recorded[#recorded+1]="gear" end
    if #recorded==0 then return false,"No readable sections. Previous records were kept." end
    record.time=stamp; records[key]=record; self:Trim(records,50)
    local partial=#recorded<3 and " Previous records were kept for unreadable sections." or ""
    return true,"Updated "..table.concat(recorded,", ").."."..partial
end
function E:ObservedStock(id,sameRealmOnly)
    local total=0
    local current=self:CharacterKey()
    if not current then return total end
    local realm=current:match("^[^-]+%-(.+)$")
    for key,record in pairs(self:StockRecords()) do
        if type(key)=="string" and key~=current and (not sameRealmOnly or (realm and key:match("^[^-]+%-(.+)$")==realm))
            and type(record)=="table" and type(record.counts)=="table" then
            local count=record.counts[id]
            if FS.Tools:Number(count) and count>0 then total=total+count end
        end
    end
    return total
end
function P:AssignCharacter(name)
    if not E:Allowed() or (name and not FS.db.profiles.saved[name]) then return false end
    local key=E:CharacterKey(); if not key then return false end
    FS.db.profiles.characters[key]=name; return true
end
function E:SettingsSnapshot()
    if not FS.db then return end
    local out={}
    for key,value in pairs(FS.db) do
        if key~="profiles" and key~="patchLog" and key~="setup" and key~="workbench" and key~="compatibility" then
            if type(value)~="table" then out[key]=value
            else local section={}; out[key]=section
                for k,v in pairs(value) do if type(v)~="table" then section[k]=v end end
            end
        end
    end
    out.typography=copy(FS.db.typography); out.layout=copy(FS.db.layout); out.nameplates.positions=copy(FS.db.nameplates.positions)
    for _,key in ipairs({'keywords','checklists','npcRules','importantSpells','settingFavorites','alerts','guildFavorites','guildNotes'}) do out.extras[key]=copy(FS.db.extras[key]) end
    return out
end
local function sameSettings(left,right)
    if left==right then return true end
    if type(left)~='table' or type(right)~='table' then return false end
    for key,value in pairs(left) do
        if not sameSettings(value,right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key]==nil then return false end
    end
    return true
end
function E:RememberChange(before)
    if (self.actionDepth or 0)>0 then return end
    if self.skipUndo then self.skipUndo=false; return end
    if not before or self.undoing or not self:Allowed() then return end
    if not sameSettings(before,self:SettingsSnapshot()) then
        table.insert(self.undo,1,before)
        if #self.undo>10 then table.remove(self.undo) end
    end
end
function FS:SettingAction(callback,...)
    if not callback then return end
    local E=self.Extensions
    local before=E and (E.actionDepth or 0)==0 and E:SettingsSnapshot()
    if E then E.actionDepth=(E.actionDepth or 0)+1 end
    local result={pcall(callback,...)}
    if E then E.actionDepth=E.actionDepth-1 end
    if not result[1] then error(result[2],0) end; table.remove(result,1)
    if E then E:RememberChange(before); if E.UpdateFilters and FS.db then E:UpdateFilters() end; if E.SyncEvents and FS.db then E:SyncEvents() end end; return unpack(result)
end
function E:Undo()
    if not self:Allowed() then FS:Print(FS.Text.leaveCombat); return false end
    if not self.undo[1] then FS:Print('No settings change to undo.'); return false end
    local snapshot=table.remove(self.undo,1); self.undoing=true
    local previousFrames=FS.db.layout.frames
    for key,value in pairs(snapshot) do
        if type(value)=="table" then for k,v in pairs(value) do FS.db[key][k]=copy(v) end else FS.db[key]=value end
    end
    for _,module in pairs(FS.modules) do if module.SettingsChanged then module:SettingsChanged() end end
    for id in pairs(previousFrames) do
        if not FS.db.layout.frames[id] then FS.Layout:RestoreTarget(id) end
    end
    FS.Layout:ApplyAll()
    FS.Typography:Apply(); FS.Themes:Refresh(); self:Refresh(); FS:RefreshConfig()
    self.undoing=false; self.skipUndo=(self.actionDepth or 0)>0; return true
end
function E:AlertOptions(category,edit)
    local data=self:Data().alerts[category]
    if type(data)=="table" then return data end
    local defaults=category=='Run note' and runAlertDefaults or alertDefaults
    if not edit then return defaults end
    data=copy(defaults)
    self:Data().alerts[category]=data
    return data
end
function E:Alert(category,force,detail,portraitUnit)
    if not alertCategory[category] then return false end
    local data=self:AlertOptions(category)
    local now=GetTime(); local last=self.alerts[category]
    local kits={Bell=(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856,Ready=(SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960,Warning=(SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959}
    local kit=kits[data.sound]
    local played=kit~=nil and type(PlaySound)=="function" and (force or not last or now-last>=10)
    if played then
        local channel=data.channel
        if channel~="Master" and channel~="Dialog" then channel="SFX" end
        local ok,result=pcall(PlaySound,kit,channel)
        played=ok and result~=false
    end
    if played and not force then self.alerts[category]=now end
    local previous=self.noticeTimes[category]
    local ready=not previous or now-previous>=10
    if not force and (ready or category=='Rare or elite') then
        local message=FS.Tools:Text(detail):gsub('[|%c]',''):sub(1,category=='Run note' and 240 or 150)
        local history=data.history~=false
        if history then
            table.insert(self.notifications,1,{category=category,message=message,time=time and time() or 0})
            while #self.notifications>50 do table.remove(self.notifications) end
            local workbench=self.workbench
            if workbench and workbench.window and workbench.window:IsShown() and workbench:Data().view=='Notification Center' then
                workbench:Refresh()
            end
        end
        if ready and data.popup then self:ShowAlertPopup(category,message,portraitUnit) end
        if ready and (history or data.popup) then self.noticeTimes[category]=now end
    end
    return played
end
function E:ShowAlertPopup(category,message,portraitUnit)
    local f=self.alertPopup
    if not f then
        f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
        self.alertPopup=f
        FS.HUD:Skin(f)
        f:SetFrameStrata('HIGH'); f:SetPoint('TOP',UIParent,'TOP',0,-112)
        f:SetWidth(460); f:EnableMouse(false)
        f.label=FS.HUD:Label(f,'',16,-12,428)
        f.portrait=f:CreateTexture(nil,'ARTWORK')
        f.portrait:SetSize(40,40); f.portrait:SetPoint('LEFT',12,0)
    end
    local portrait=portraitUnit and type(SetPortraitTexture)=='function' and pcall(SetPortraitTexture,f.portrait,portraitUnit)
    f.portrait:SetShown(not not portrait)
    local width=portrait and 380 or 428
    f.label:ClearAllPoints(); f.label:SetPoint('TOPLEFT',portrait and 64 or 16,-12); f.label:SetWidth(width)
    f.label:SetText(message~='' and (category..' | '..message) or category)
    f:SetHeight(math.max(portrait and 56 or 0,FS.HUD:TextHeight(f.label,width,category=='Run note' and 6 or 3)+24))
    f:SetScale(math.min(1,math.max(.2,(UIParent:GetWidth()-24)/460)))
    f:Show()
    local token={}
    f.token=token
    C_Timer.After(category=='Run note' and 8 or 4,function() if f.token==token then f:Hide() end end)
end
function E:ApplyPalette()
    self.originalColors=self.originalColors or copy(FS.moduleCardColors)
    local palette=self:Data().palette
    local colors={{.15,.65,.90},{.95,.60,.10},{.80,.45,.70},{.10,.70,.50},{.95,.85,.25},{.40,.65,.95}}
    local names={}; for name in pairs(self.originalColors) do names[#names+1]=name end; table.sort(names)
    for i,name in ipairs(names) do
        local c=palette=="Original" and self.originalColors[name] or colors[(i-1)%#colors+1]
        FS.moduleCardColors[name]=copy(c)
        if FS.window and FS.window.cards[name] then local card=FS.window.cards[name]; if card.rail then card.rail:SetColorTexture(unpack(c)) end end
    end
end
function E:Refresh()
    self:Normalize(); self:ApplyPalette()
    if self.UpdateFilters then self:UpdateFilters() end
    if self.SyncEvents then self:SyncEvents() end
    if self.SyncDiscovery then self:SyncDiscovery() end
    FS:RefreshConfig()
end
function E:ApplyPreset(name)
    if name=="Standard text" then FS.db.typography.global.size=14; FS.db.typography.global.outline="Thin"
    elseif name=="Readable text" then FS.db.typography.global.size=18; FS.db.typography.global.outline="Thin"
    elseif name=="Compact screen" then FS.db.typography.global.size=12; FS.db.unitFrames.scale=.85 end
    if name=='Compact screen' then for _,unit in ipairs({'player','target','focus'}) do local layout=FS.db.layout.frames['Unit:'..unit]; if layout then layout.scale=.85 end end end
end
