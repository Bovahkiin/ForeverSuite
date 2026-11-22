local _,FS=...
local A,T=FS.modules.TalentAdvisor,FS.Tools
local function text(s,limit,empty)
    return type(s)=='string' and #s<=limit and (empty or #s>0) and not s:find('[|%c]')
end
local function bounded(t,limit)
    if type(t)~='table' then return false end
    local count=0; for _ in pairs(t) do count=count+1; if count>limit then return false end end; return true
end
function A:CleanPlan(p)
    local valid,why=self:ValidatePlan(p); if not valid then return nil,why end
    if not text(p.name,64) or not text(p.author or '',64,true) or not text(p.notes or '',600,true) then return nil,'Invalid build name, author or notes.' end
    local allowedGoal={Leveling=true,Dungeons=true,Raids=true,PvP=true,PvE=true}
    if not allowedGoal[p.goal] or not FS.modules.GearAdvisor.presets[p.scale] then return nil,'Choose a supported activity and stat scale.' end
    if not bounded(p.optional or {},64) then return nil,'Too many flexible talents.' end
    local out={name=p.name,author=p.author or '',notes=p.notes or '',class=p.class,version=p.version,goal=p.goal,scale=p.scale,
        order=self.Copy(p.order),optional={}}
    local reference=p.source or p.reference
    if reference then
        if not text(reference,240) or not reference:match('^https://www%.icy%-veins%.com/wow%-forever/[%w%-%/]+$') then return nil,'Invalid guide reference.' end
        out.reference=reference
    end
    if p.priority then
        if type(p.priority)~='table' or #p.priority>20 then return nil,'Invalid stat priorities.' end
        out.priority={};local count=0
        for index,label in pairs(p.priority) do
            count=count+1;if not T:Number(index) or index%1~=0 or index<1 or index>#p.priority or not text(label,50) then return nil,'Invalid stat priorities.' end
            out.priority[index]=label
        end
        if count~=#p.priority then return nil,'Incomplete stat priorities.' end
    end
    for id,on in pairs(p.optional or {}) do
        if not T:Number(id) or not valid[id] or on~=true then return nil,'Flexible choices must be talents in this build.' end
        out.optional[id]=true
    end
    if p.weights then
        if not bounded(p.weights,30) then return nil,'Invalid stat weights.' end
        local known={}; for _,s in ipairs(FS.modules.GearAdvisor.stats) do known[s[1]]=true end
        out.weights={}; for key,value in pairs(p.weights) do
            if not known[key] or not T:Number(value) or math.abs(value)>1000 then return nil,'Invalid stat weight.' end
            out.weights[key]=value
        end
    end
    return out
end
function A:ExportPlan()
    local p,why=self:CleanPlan(self:Selected()); if not p then return nil,why end
    return 'FSTA1:'..FS.Extensions:Encode({kind='build',plan=p})
end
function A:DecodeShare(code)
    if type(code)~='string' or #code>60000 or code:sub(1,6)~='FSTA1:' then return nil,'Paste a ForeverSuite Talent Advisor share code (up to 60 KB).' end
    local decoded,why=FS.Extensions:Decode(code:sub(7))
    if type(decoded)~='table' or (decoded.kind~='build' and decoded.kind~='profile') then return nil,why or 'Not a Talent Advisor build or profile.' end
    local p,message=self:CleanPlan(decoded.plan); if not p then return nil,message end
    local out={kind=decoded.kind,plan=p}
    if decoded.kind=='profile' then
        if decoded.name and not text(decoded.name,64) then return nil,'Invalid build profile name.' end
        out.name=decoded.name or p.name
        local gear=decoded.gear
        if type(gear)~='table' then return nil,'Missing gear preferences.' end
        local G=FS.modules.GearAdvisor
        local validPreset={Auto=true,Custom=true}; for key in pairs(G.presets) do validPreset[key]=true end
        local roles={['Class default']=true,['Physical damage']=true,['Spell damage']=true,Healer=true,Tank=true}
        if not validPreset[gear.preset] or not roles[gear.role] or type(gear.talentBuild)~='boolean' then return nil,'Invalid gear preferences.' end
        local clean,err=self:CleanPlan(setmetatable({weights=gear.weights or {}},{__index=p}))
        if not clean then return nil,err end
        out.gear={preset=gear.preset,role=gear.role,talentBuild=gear.talentBuild,weights=clean.weights or {}}
        if decoded.layout then
            if not bounded(decoded.layout,100) then return nil,'Too many layout positions.' end
            out.layout={}
            for id,position in pairs(decoded.layout) do
                if not text(id,100) or type(position)~='table' or not T:Number(position.x) or not T:Number(position.y)
                    or math.abs(position.x)>10000 or math.abs(position.y)>10000 or not T:Number(position.scale) or position.scale<.4 or position.scale>2 then return nil,'Invalid layout position.' end
                out.layout[id]={x=position.x,y=position.y,scale=position.scale}
            end
        end
    end
    return out
end
function A:ImportShare(code)
    if not self:Allowed() or not FS.Hub:Writable() then return false,'Build storage is unavailable or read-only.' end
    local data,why=self:DecodeShare(code); if not data then return false,why end
    local lib=self:Library(); local store=data.kind=='profile' and lib.profiles or lib.builds
    local p=data.plan; local id='community:'..p.class..':'..(data.kind=='profile' and data.name or p.name)
    local count=0; for _ in pairs(store) do count=count+1 end
    if store[id] then return false,'A build with this name already exists. Rename it before importing a replacement.' end
    if count>=40 then return false,'Keep up to 40 entries in this library.' end
    p.id=id; p.origin='community'; p.received=time and time() or 0
    if data.kind=='profile' then data.id=id; store[id]=data; self.profileSelected=id
    else store[id]=p; self:Data().selected=id; self:Data().activeBundle=''; self.draft=nil end
    self.gearWeights=nil; return true
end
function A:ReviewBuild()
    local p=self:Selected()
    if not p or p.origin~='community' or not self:Allowed() or not FS.Hub:Writable() then return false end
    if not self:ValidatePlan(p) then return false end
    p.reviewedAt=time and time() or 0; self.message='Marked reviewed by you. This is not a community rating.'; return true
end
function A:SaveBundle(name)
    if not self:Allowed() or not FS.Hub:Writable() then return false,'Build storage is unavailable or read-only.' end
    local plan,why=self:CleanPlan(self:Selected()); if not plan then return false,why end
    if not text(name,64) then return false,'Use a profile name up to 64 characters.' end
    local lib=self:Library().profiles; local id='profile:'..plan.class..':'..name
    local count=0; for _ in pairs(lib) do count=count+1 end; if not lib[id] and count>=40 then return false,'Keep up to 40 build profiles.' end
    local G=FS.modules.GearAdvisor:Data()
    local bundle={kind='profile',id=id,name=name,plan=plan,gear={preset=G.preset,role=G.role,weights=self.Copy(G.weights),talentBuild=G.talentBuild==true}}
    if self:Data().includeLayout then bundle.layout=self.Copy(FS.db.layout.frames) end
    local clean,err=self:DecodeShare('FSTA1:'..FS.Extensions:Encode(bundle)); if not clean then return false,err end
    clean.id=id; clean.name=name; lib[id]=clean; self.profileSelected=id; return true
end
function A:UseBundle(id,useLayout)
    if not self:Allowed() or FS.Layout.active or not FS.Hub:Writable() then return false,'Finish Move Frames or the current action first.' end
    local bundle=self:Library().profiles[id]
    if not bundle then return false,'Select a build profile.' end
    local b,why=self:DecodeShare('FSTA1:'..FS.Extensions:Encode(bundle)); if not b then return false,why end
    -- Keep one local undo point before replacing build, gear or layout preferences.
    self.bundleUndo={selected=self:Data().selected,activeBundle=self:Data().activeBundle,draft=self.draft,gear=self.Copy(FS.modules.GearAdvisor:Data()),layout=self.Copy(FS.db.layout.frames)}
    self:Data().activeBundle=id;self:Data().selected='';self.draft=nil;self.gearWeights=nil
    local g=FS.modules.GearAdvisor:Data(); for key,value in pairs(b.gear) do g[key]=self.Copy(value) end
    FS.modules.GearAdvisor:SettingsChanged()
    if useLayout and b.layout then
        local old=FS.db.layout.frames; FS.db.layout.frames=self.Copy(b.layout); FS.Layout:Normalize()
        for key in pairs(old) do if not FS.db.layout.frames[key] then FS.Layout:RestoreTarget(key) end end
        FS.Layout:ApplyAll()
    end
    self.message='Build plan and gear preferences loaded. Your learned talents have not been changed.'; return true
end
function A:UndoBundle()
    if not self.bundleUndo or not self:Allowed() or FS.Layout.active then return false end
    local b=self.bundleUndo; self.bundleUndo=nil; self:Data().selected=b.selected; self:Data().activeBundle=b.activeBundle or '';self.draft=b.draft
    FS.db.gearAdvisor=self.Copy(b.gear); local old=FS.db.layout.frames; FS.db.layout.frames=self.Copy(b.layout)
    for key in pairs(old) do if not FS.db.layout.frames[key] then FS.Layout:RestoreTarget(key) end end
    FS.Layout:ApplyAll(); self.gearWeights=nil; FS.modules.GearAdvisor:SettingsChanged(); self.message='Build profile changes undone.'; return true
end
