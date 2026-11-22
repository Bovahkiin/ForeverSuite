local _,FS=...
local T=FS.Tools
local A=T:Module('TalentAdvisor','talentAdvisor','Talent Advisor','Plan talents, compare your current build and match Gear Advisor to your play style.',
    {goal='All',library='All',selected='',activeBundle='',includeLayout=false,nativeHighlights=true},
    {'PLAYER_LEVEL_UP','PLAYER_TALENT_UPDATE','TRAIT_CONFIG_UPDATED','TRAIT_NODE_CHANGED','ACTIVE_TALENT_GROUP_CHANGED','PLAYER_EQUIPMENT_CHANGED','ADDON_LOADED','PLAYER_ENTERING_WORLD','PLAYER_REGEN_DISABLED'})
FS.TalentCatalogLoaders={}
A.options={{key='goal',label='Activity',values={'All','Leveling','Dungeons','Raids','PvP'}},
    {key='library',label='Build library',values={'All','Guides','My builds','Community'}},
    {key='includeLayout',label='Include layout when saving build profiles',help='Optional: save frame positions with a build and gear priorities. Loading a profile previews these choices before applying.'},
    {key='nativeHighlights',label='Show build highlights in game Talents',help='Marks the selected build in the normal Talents screen. Gold: next point. Blue: planned. Green: matched. Purple: flexible. P is the planned rank.'}}
A.current={}; A.dirty=true
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
A.Copy=copy
function A:Allowed()
    return FS.modules.Profiles:Allowed() and FS:IsModuleEnabled(self.name)
end
function A:Catalog()
    local _,class=T:Call(UnitClass,'player')
    if self.catalog and self.catalog.class==class then return self.catalog end
    local load=FS.TalentCatalogLoaders[class]
    self.catalog=load and load() or nil
    self.dirty=true; self.gearWeights=nil
    return self.catalog
end
function A:Normalize()
    local d=self:Data()
    if type(d.selected)~='string' then d.selected='' end
    if type(d.activeBundle)~='string' then d.activeBundle='' end
end
function A:Library()
    local hub=FS.Hub:Data()
    local lib=hub.talents
    if type(lib)~='table' or type(lib.builds)~='table' or type(lib.profiles)~='table' then
        if not FS.Hub:Writable() then self.emptyLibrary=self.emptyLibrary or {builds={},profiles={}}; return self.emptyLibrary end
        lib={builds={},profiles={}}; hub.talents=lib
    end
    return lib
end
function A:Ranks(order,limit)
    local out={}; for i,id in ipairs(order or {}) do if not limit or i<=limit then out[id]=(out[id] or 0)+1 end end; return out
end
function A:CanAdd(id,ranks)
    local c=self:Catalog(); local n=c and c.nodes[id]
    if not n then return false,'Talent is not in this class data.' end
    if (ranks[id] or 0)>=n.max then return false,'Maximum rank reached.' end
    local spent=0; for nid,r in pairs(ranks) do local other=c.nodes[nid]; if other and other.group==n.group then spent=spent+r end end
    if spent<n.gate then return false,'Requires '..n.gate..' points in '..c.groups[n.group]..'.' end
    if (ranks[n.pre] or 0)<n.preRank then return false,'Requires '..n.preRank..' ranks in '..c.nodes[n.pre].name..'.' end
    return true
end
function A:ValidatePlan(plan)
    local c=self:Catalog()
    if not c then return nil,'This class is not supported by the Forever catalog.' end
    if type(plan)~='table' or plan.class~=c.class then return nil,'This build belongs to another class.' end
    if plan.version~=c.version then return nil,'This build uses different talent data. Update its source before importing it.' end
    if type(plan.order)~='table' or #plan.order>51 then return nil,'A build may contain up to 51 talent points.' end
    local ranks,count={},0
    for k,id in pairs(plan.order) do
        count=count+1
        if not T:Number(k) or k%1~=0 or k<1 or k>#plan.order or not T:Number(id) or not c.nodes[id] then return nil,'Invalid talent point list.' end
    end
    if count~=#plan.order then return nil,'The talent point list is incomplete.' end
    for _,id in ipairs(plan.order) do local ok,why=self:CanAdd(id,ranks); if not ok then return nil,why end; ranks[id]=(ranks[id] or 0)+1 end
    return ranks
end
function A:Builds()
    local c=self:Catalog(); if not c then return {} end
    local out={}; for _,b in ipairs(c.builds) do out[#out+1]=b end
    for id,b in pairs(self:Library().builds) do if type(b)=='table' and b.id==id and b.class==c.class then out[#out+1]=b end end
    return out
end
function A:Selected()
    if self.draft then return self.draft end
    local active=self:Library().profiles[self:Data().activeBundle]
    if type(active)=='table' and type(active.plan)=='table' and self:Catalog() and active.plan.class==self.catalog.class then return active.plan end
    local id=self:Data().selected
    local c=self:Catalog()
    for _,b in ipairs(c and c.builds or {}) do if b.id==id then return b end end
    local b=self:Library().builds[id]
    if type(b)=='table' and b.id==id and c and b.class==c.class then return b end
end
function A:AsDraft(plan)
    plan=copy(plan)
    plan.reference=plan.source or plan.reference;plan.source=nil;plan.checked=nil;plan.reviewedAt=nil;plan.updated=nil
    if plan.origin~='personal' then plan.author=T:Text(T:Call(UnitName,'player')) end
    plan.origin='personal'
    return plan
end
function A:Select(id)
    if not self:Allowed() then return false end
    for _,b in ipairs(self:Builds()) do if b.id==id then
        local valid,why=self:ValidatePlan(b); if not valid then self.message=why; return false end
        self:Data().selected=id; self:Data().activeBundle=''; self.draft=nil; self.gearWeights=nil; self.message='Selected '..b.name..'.'; self:Refresh(); return true
    end end
    return false
end
function A:NewDraft()
    local c=self:Catalog(); if not c or not self:Allowed() then return false end
    local guide=FS.modules.GearAdvisor.classGuides[c.class]
    self.draft={name='My talent build',class=c.class,version=c.version,goal='Leveling',order={},optional={},scale=guide and guide[1] or 'Caster',origin='personal',author=T:Text(T:Call(UnitName,'player'))}
    self.gearWeights=nil; self.tab='Talents'; return true
end
function A:EditTalent(id,remove,optional)
    if not self:Allowed() then return false end
    local selected=self:Selected(); if not selected then self:NewDraft(); selected=self.draft end
    if not selected then return false end
    local plan=self:AsDraft(selected); plan.optional=plan.optional or {}; local ranks=self:Ranks(plan.order)
    if optional then
        if not ranks[id] then self.message='Add this talent before marking it flexible.'; return false end
        plan.optional[id]=not plan.optional[id] or nil
    elseif remove then
        local at; for i=#plan.order,1,-1 do if plan.order[i]==id then at=i; break end end
        if not at then return false end
        table.remove(plan.order,at)
        local valid,why=self:ValidatePlan(plan); if not valid then self.message='Keep required points: '..why; return false end
        if not valid[id] then plan.optional[id]=nil end
    else
        if #plan.order>=51 then self.message='All 51 points are planned.'; return false end
        local ok,why=self:CanAdd(id,ranks); if not ok then self.message=why; return false end
        plan.order[#plan.order+1]=id
    end
    plan.orderKind='Your point order'
    self.draft=plan; self.gearWeights=nil; self.message='Draft updated. Save it to keep this variation.'; return true
end
function A:SavePlan(name,author,notes)
    if not self:Allowed() then return false,'Leave combat or finish the current action first.' end
    if not FS.Hub:Writable() then return false,'Character data is read-only. Update the addon before saving builds.' end
    local p=self:Selected(); local valid,why=self:ValidatePlan(p); if not valid then return false,why end
    name=T:Text(name):match('^%s*(.-)%s*$'); author=T:Text(author); notes=T:Text(notes)
    if name=='' or #name>64 or #author>64 or #notes>600 or (name..author..notes):find('[|%c]') then return false,'Use a short name, author and notes without formatting codes.' end
    local saved=self:Library().builds; local id='my:'..p.class..':'..name
    local count=0; for _ in pairs(saved) do count=count+1 end
    if not saved[id] and count>=40 then return false,'Keep up to 40 saved builds.' end
    p=self:AsDraft(p); p.id=id; p.name=name; p.author=author; p.notes=notes
    saved[id]=p; self:Data().selected=id; self:Data().activeBundle=''; self.draft=nil; self.gearWeights=nil; return true
end
function A:ReadCurrent()
    self.currentReady=false
    local c=self:Catalog(); if not c then return nil,'Talent data is unavailable for this class.' end
    local api=C_Traits; local spec=C_SpecializationInfo
    local group=T:Call(spec and spec.GetActiveSpecGroup)
    local config=group and T:Call(spec and spec.GetCombatConfigIDForSpecGroup,group) or T:Call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    if not T:Number(config) or not api then return nil,'Open the game Talents window once, then Refresh.' end
    if T:Call(api.ConfigHasStagedChanges,config)~=false then return nil,'Apply or cancel pending changes in the game Talents window first.' end
    local info=T:Call(api.GetConfigInfo,config)
    if type(info)~='table' or type(info.treeIDs)~='table' then return nil,'The active talent tree is not ready.' end
    local ranks,known,spent,available={}, {},0,0; local seenTree={}
    for _,tree in ipairs(info.treeIDs) do
        if not T:Number(tree) or seenTree[tree] then return nil,'Talent tree data is incomplete.' end; seenTree[tree]=true
        local nodes=T:Call(api.GetTreeNodes,tree); if type(nodes)~='table' or #nodes>256 then return nil,'Talent nodes are unavailable.' end
        for _,id in ipairs(nodes) do
            if not T:Number(id) or id%1~=0 then return nil,'A talent ID could not be read.' end
            local n=T:Call(api.GetNodeInfo,config,id)
            if type(n)~='table' or not T:Number(n.ranksPurchased) or not T:Number(n.maxRanks) or n.ranksPurchased<0 or n.ranksPurchased>n.maxRanks then return nil,'A talent node could not be read.' end
            if c.nodes[id] then
                if n.maxRanks~=c.nodes[id].max then return nil,'Talent ranks changed in the client. Update ForeverSuite before using advice.' end
                local matches=false
                for _,entryID in ipairs(type(n.entryIDs)=='table' and n.entryIDs or {}) do
                    local entry=T:Call(api.GetEntryInfo,config,entryID)
                    local definition=type(entry)=='table' and T:Call(api.GetDefinitionInfo,entry.definitionID)
                    if type(definition)=='table' then for _,spell in ipairs(c.nodes[id].spells) do
                        if T:Number(definition.spellID) and definition.spellID==spell or T:Number(definition.overriddenSpellID) and definition.overriddenSpellID==spell then matches=true end
                    end end
                end
                if not matches then return nil,'A live talent spell differs from this catalog. Update ForeverSuite before using advice.' end
                ranks[id]=n.ranksPurchased; known[id]=true; spent=spent+n.ranksPurchased
            elseif n.ranksPurchased>0 then return nil,'Your build contains new talents outside this catalog. Update ForeverSuite.' end
        end
        local currencies=T:Call(api.GetTreeCurrencyInfo,config,tree,true)
        if type(currencies)=='table' then for _,currency in ipairs(currencies) do if T:Number(currency.quantity) then available=available+math.max(0,currency.quantity) end end end
    end
    for id in pairs(c.nodes) do if not known[id] then return nil,'The live tree differs from this catalog. Update the talent data.' end end
    self.current=ranks; self.currentSpent=spent; self.available=available; self.currentConfig=config; self.currentReady=true; self.currentError=nil; self.dirty=false
    return ranks
end
function A:NextPoint()
    local p=self:Selected(); if not p or not self.currentReady then return nil end
    local target=self:ValidatePlan(p); if not target then return nil end
    for id,r in pairs(self.current) do if r>(target[id] or 0) then return nil,'Your current build differs. Compare it before following the plan.' end end
    local used={}; for _,id in ipairs(p.order) do
        used[id]=(used[id] or 0)+1
        if used[id]>(self.current[id] or 0) then
            local ok,why=self:CanAdd(id,self.current)
            return ok and id or nil,ok and (p.optional and p.optional[id] and 'Flexible choice in your selected plan.' or 'Next legal point in your selected plan.') or why
        end
    end
    return nil,'Your current talents match the complete plan.'
end
function A:GearWeights()
    local p=self:Selected(); if not p then return end
    if self.gearWeights and self.gearPlan==p then return self.gearWeights,p.name end
    if not self:ValidatePlan(p) then return end
    local G=FS.modules.GearAdvisor; local weights=copy(G.presets[p.scale] or G.presets.Caster)
    -- Priority order alone cannot establish comparable numeric values across stats.
    -- Keep the role's existing scale; explicit custom weights may be shared separately.
    if type(p.weights)=='table' then weights=copy(p.weights) end
    self.gearWeights=weights; self.gearPlan=p
    return weights,p.name
end
function A:LinkGear()
    if not self:Allowed() or not self:Selected() then return false end
    local G=FS.modules.GearAdvisor; local d=G:Data()
    if d.preset=='Custom' then return false,'Custom weights are preserved. Choose Auto in Gear Advisor before linking a talent plan.' end
    d.preset='Auto'; d.talentBuild=true; G:SettingsChanged(); self.message='Gear Advisor now uses the selected plan\'s starter stat scale.'; return true
end
function A:GearNotes()
    local p=self:Selected(); local c=self:Catalog(); local out={}
    if not p or not c then return out end
    local ranks=self:Ranks(p.order)
    local rules={['Mental Dexterity']='Intellect can contribute to melee attack power through this talent.',
        ['Elemental Weapons']='Weapon imbues matter alongside raw item stats.', ['Dagger Specialization']='Compare daggers as well as their raw stats.',
        ['Shield Specialization']='This talent depends on using a shield.', ['Dual Wield Specialization']='Off-hand weapons matter to this build.',
        ['Two-Handed Weapon Specialization']='Compare suitable two-handed weapons.', ['Ranged Weapon Specialization']='Compare ranged weapons for this build.',
        ['Nature\'s Swiftness']='Keep an accessible binding for the ability unlocked by this talent.'}
    for id in pairs(ranks) do local n=c.nodes[id]; if n and rules[n.name] then out[#out+1]=n.name..': '..rules[n.name] end end
    table.sort(out); return out
end
function A:Event(event)
    if self.InstallNative and (event=='ADDON_LOADED' or event=='PLAYER_ENTERING_WORLD') then self:InstallNative() end
    self.dirty=true
    if event=='PLAYER_EQUIPMENT_CHANGED' then self.gearWeights=nil end
    local visible=self.window and self.window:IsShown() or self.NativeVisible and self:NativeVisible()
    if visible and not self.readPending then
        self.readPending=true; C_Timer.After(0,function()
            self.readPending=nil
            if FS:IsModuleEnabled(self.name) and (self.window and self.window:IsShown() or self.NativeVisible and self:NativeVisible()) then self:Refresh() end
        end)
    end
end
function A:Refresh()
    if self.dirty then local data,why=self:ReadCurrent(); if not data then self.currentReady=false; self.currentError=why; self.dirty=false end end
    if self.RenderAdvisor then self:RenderAdvisor() end
    if self.RefreshNative then self:RefreshNative() end
end
-- This module has event-driven updates only, including while its window is open.
function A:SyncLifecycle()
    if not self.events or InCombatLockdown() then return end
    local active=FS:IsModuleEnabled(self.name)
    for event in pairs(FS.client.frameEvents[self.events] or {}) do
        if active then FS:RegisterClientEvent(self.events,event) elseif event~='PLAYER_REGEN_ENABLED' then self.events:UnregisterEvent(event) end
    end
    self.events:SetScript('OnUpdate',nil)
end
local initialize=A.Initialize
local settingsChanged=A.SettingsChanged
function A:SettingsChanged(...)
    if self.profileData~=self:Data() then
        self.profileData=self:Data();self.draft=nil;self.bundleUndo=nil;self.profileSelected=nil;self.gearWeights=nil;self.message=nil;self.dirty=true
    end
    settingsChanged(self,...)
    if self.InstallNative then self:InstallNative();self:RefreshNative() end
end
function A:Initialize()
    initialize(self)
    self.events:SetScript('OnEvent',function(_,event,...)
        if event=='PLAYER_REGEN_ENABLED' and self.pending then self:SettingsChanged() end
        if FS:IsModuleEnabled(self.name) then self:Event(event,...) end
    end)
end
