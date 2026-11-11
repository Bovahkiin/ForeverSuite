local _,FS=...
local E={chat={},loot={items=0,value=0,unknown=0},undo={},alerts={},audit={}}; FS.Extensions=E
FS.Text={tools="More tools",apply="Apply",preview="Preview",cancel="Cancel",clear="Clear",back="Back to Control Center",close="Close",previous="Previous",next="Next",enabled="Enabled",disabled="Disabled",unavailable="Unavailable in this client",leaveCombat="Leave combat before changing these settings."}
FS.defaults.extras={palette="Original",nativeWindows=true,keywordsEnabled=false,captureChat=false,trackGroups=false,showPrivateNotes=false,
    keywords={},guildNotes={},guildFavorites={},recentGroups={},checklists={},npcRules={},importantSpells={},settingFavorites={},alerts={},waypointQueue={}}
local function copy(v) if type(v)~="table" then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
E.Copy=copy
function E:Allowed() return not InCombatLockdown() and not FS.modules.Vendor.busy end
function E:Data() return FS.db.extras end
function E:Trim(map,limit)
    local keys={}; for key,value in pairs(map) do keys[#keys+1]={key=key,time=type(value)=="table" and tonumber(value.time) or 0} end
    table.sort(keys,function(a,b) if a.time~=b.time then return a.time>b.time end; return tostring(a.key)<tostring(b.key) end)
    for i=limit+1,#keys do map[keys[i].key]=nil end
end
function E:Normalize()
    FS:ApplyDefaults(FS.db.extras,FS.defaults.extras); local d=self:Data()
    if self.dataRef~=d then self.dataRef=d; self.queueActive=false; self.queueTarget=nil end
    if FS.db.workbench then FS.db.workbench.enabled=true end
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
        if category~='Keyword' and category~='Important cast' and category~='Waypoint arrival' and category~='Low durability' and category~='Level up' then d.alerts[category]=nil
        else
            if type(a)~='table' then a={}; d.alerts[category]=a end
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
    if data.extras then data.extras.guildNotes={}; data.extras.recentGroups={} end
    for _,section in pairs(data) do if type(section)=="table" then section.history=nil end end
    return E:Encode({format=1,settings=data})
end
function P:PreviewImport(text)
    local parsed,err=E:Decode(text); if not parsed then return nil,err end
    if type(parsed)~="table" or parsed.format~=1 or type(parsed.settings)~="table" then return nil,"Unknown export format" end
    local count=0
    for key,value in pairs(parsed.settings) do
        if key=="profiles" or key=="setup" or key=="patchLog" or FS.defaults[key]==nil or type(value)~=type(FS.defaults[key]) then return nil,"Invalid settings section: "..tostring(key) end
        count=count+1
    end
    if count==0 then return nil,"Empty profile" end
    local canonical=pcall(E.Encode,E,parsed)
    if not canonical then return nil,'Profile exceeds the supported data limits.' end
    return parsed.settings,"Validated "..count.." settings sections. Import replaces only the named profile; a backup is kept."
end
function P:Import(name,data)
    if not self:Allowed() or type(data)~="table" or type(name)~="string" then return false end
    name=name:match('^%s*(.-)%s*$'); if #name<1 or #name>32 then return false end
    local checked=self:PreviewImport(E:Encode({format=1,settings=data})); if not checked then return false end
    local saved=FS.db.profiles.saved
    if saved[name] and name~=FS.db.profiles.current then self:Backup(name,saved[name],"Before import") else self:Backup(FS.db.profiles.current,self:Snapshot(),"Before import") end
    if checked.extras then checked.extras.guildNotes=copy(FS.db.extras.guildNotes); checked.extras.recentGroups=copy(FS.db.extras.recentGroups) end
    for key,section in pairs(checked) do if type(section)=='table' and type(FS.db[key])=='table' and FS.db[key].history and not section.history then section.history=copy(FS.db[key].history) end end
    saved[name]=copy(checked); return self:Load(name)
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
function E:RememberChange(before)
    if (self.actionDepth or 0)>0 then return end
    if self.skipUndo then self.skipUndo=false; return end
    if not before or self.undoing or not self:Allowed() then return end
    local ok,a,b=pcall(function() return self:Encode(before),self:Encode(self:SettingsSnapshot()) end)
    if ok and a~=b then table.insert(self.undo,1,before); while #self.undo>10 do table.remove(self.undo) end end
end
function FS:SettingAction(callback,...)
    if not callback then return end
    local E=self.Extensions; local before=E and E:SettingsSnapshot()
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
function E:Alert(category,force)
    local data=self:Data().alerts[category]; if type(data)~="table" or data.sound=="Silent" then return false end
    local now=GetTime(); local last=self.alerts[category]
    if not force and last and now-last<10 then return false end
    local kits={Bell=(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856,Ready=(SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960,Warning=(SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959}
    local kit=kits[data.sound]; if not kit then return false end
    local channel=data.channel; if channel~="Master" and channel~="Dialog" then channel="SFX" end
    if type(PlaySound)~="function" then return false end
    PlaySound(kit,channel); self.alerts[category]=now; return true
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
    FS:RefreshConfig()
end
function E:ApplyPreset(name)
    if name=="Standard text" then FS.db.typography.global.size=14; FS.db.typography.global.outline="Thin"
    elseif name=="Readable text" then FS.db.typography.global.size=18; FS.db.typography.global.outline="Thin"
    elseif name=="Compact screen" then FS.db.typography.global.size=12; FS.db.unitFrames.scale=.85 end
    if name=='Compact screen' then for _,unit in ipairs({'player','target','focus'}) do local layout=FS.db.layout.frames['Unit:'..unit]; if layout then layout.scale=.85 end end end
end
