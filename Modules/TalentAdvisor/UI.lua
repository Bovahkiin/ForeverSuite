local _,FS=...
local A,H,T=FS.modules.TalentAdvisor,FS.HUD,FS.Tools
local tabs={'Overview','Builds','Talents','Gear','Profiles'}
local function hide(frame) if frame then frame:Hide() end end
local function safe(s) return T:Text(s) end
function A:Form(title,fields,save,label)
    return FS.Extensions:Form(title,fields,save,label,function() A:ShowWindow() end,'TalentAdvisor')
end
function A:ShowSource()
    local p=self:Selected(); if not p then return end
    local lines={p.name,'Author: '..safe(p.author),'Talent data: '..safe(p.version)}
    if p.origin=='guide' then
        lines[#lines+1]='Checked: '..safe(p.checked); lines[#lines+1]=safe(p.orderKind)
        lines[#lines+1]=safe(p.source)
    else lines[#lines+1]=p.reviewedAt and 'Reviewed locally by you.' or 'Not reviewed locally.' end
    if p.origin~='guide' and (p.source or p.reference) then lines[#lines+1]='Guide reference: '..(p.source or p.reference) end
    if p.notes and p.notes~='' then lines[#lines+1]=''; lines[#lines+1]=p.notes end
    FS.Extensions:TextDialog('Build details',table.concat(lines,'\n'),true,nil,nil,function() A:ShowWindow() end,nil,'TalentAdvisor')
end
function A:SaveForm()
    local p=self:Selected(); if not p then self:NewDraft();p=self:Selected() end
    if not p then return end
    return self:Form('Save talent build',{{label='Build name',value=p.name,limit=64},{label='Author',value=p.origin=='guide' and T:Text(T:Call(UnitName,'player')) or p.author or '',limit=64},{label='Short notes',value=p.notes or '',limit=600}},
        function(name,author,notes) return A:SavePlan(name,author,notes) end,'Save build')
end
function A:ImportForm()
    return FS.Extensions:TextDialog('Import talent build or profile','',false,function(code)
        local value,why=A:DecodeShare(code); return value and code or nil,why or 'Valid build. Import keeps it in your community library.'
    end,function(code) return A:ImportShare(code) end,function() A:ShowWindow() end,nil,'TalentAdvisor')
end
function A:ExportForm(profile)
    local code,why
    if profile then
        local p=self:Library().profiles[self.profileSelected]
        if p then code='FSTA1:'..FS.Extensions:Encode(p) else why='Select a build profile.' end
    else code,why=self:ExportPlan() end
    if not code then self.message=why;self:Refresh(); return end
    FS.Extensions:TextDialog('Share via Discord or copy to another installation',code,true,nil,nil,function() A:ShowWindow() end,nil,'TalentAdvisor')
end
function A:CreateWindow()
    if self.window then return self.window end
    local f=CreateFrame('Frame','ForeverSuiteTalentAdvisor',UIParent,'BackdropTemplate'); self.window=f
    f.fsFontModule='TalentAdvisor';H:Skin(f);f:SetSize(980,760);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:EnableMouse(true)
    f:SetMovable(true);f:RegisterForDrag('LeftButton');f:SetScript('OnDragStart',function() if not InCombatLockdown() then f:StartMoving() end end);f:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
    f.logo=f:CreateTexture(nil,'ARTWORK');f.logo:SetSize(32,32);f.logo:SetPoint('TOPLEFT',22,-20);FS:SetMenuIcon(f.logo,'Talents')
    f.heading=H:Label(f,'Talent Advisor',64,-23,470)
    f.control=H:Button(f,'Control Center',754,-20,204,function() FS:ShowConfig() end)
    f.state=H:Label(f,'',24,-66,932);f.nav={}
    for i,tab in ipairs(tabs) do local name=tab;f.nav[i]=H:Button(f,name,24+(i-1)*188,-106,180,function() A.tab=name;A.page=1;A.message=nil;A:Refresh() end) end
    f.note=H:Label(f,'',24,-150,932)
    f.rows={}
    for i=1,6 do
        local b=H:Button(f,'',24,-190-(i-1)*50,932,function()
            local row=f.rows[i].row;if row and row.run then row.run() end
        end)
        b.fsLabel:SetJustifyH('LEFT');H:SetHelp(b,'Click to select.');f.rows[i]=b
    end
    f.talentButtons={};f.treeLabels={}
    for g=1,3 do f.treeLabels[g]=H:Label(f,'',24+(g-1)*316,-192,300) end
    f.detail=H:Label(f,'',24,-510,932);f.message=H:Label(f,'',24,-552,932)
    f.actions={}
    for i=1,7 do f.actions[i]=H:Button(f,'',24+(i-1)%3*316,-606-math.floor((i-1)/3)*40,300,function()
        local action=A.actionList and A.actionList[i];if action and action.run then action.run();A:Refresh() end
    end) end
    f.previous=H:Button(f,'Previous',24,-714,150,function() A.page=math.max(1,(A.page or 1)-1);A:RenderAdvisor() end)
    f.page=H:Label(f,'',196,-720,460)
    f.next=H:Button(f,'Next',640,-714,150,function() A.page=(A.page or 1)+1;A:RenderAdvisor() end)
    f.close=H:Button(f,'Close',808,-714,148,function() f:Hide() end)
    f.LayoutText=function() A:LayoutAdvisor() end
    f:HookScript('OnShow',function() A:SyncLifecycle() end);f:HookScript('OnHide',function() A:SyncLifecycle() end)
    UISpecialFrames[#UISpecialFrames+1]=f:GetName();f:Hide();FS.Layout:Register('Tool:TalentAdvisor',f,'Talent Advisor');return f
end
function A:LayoutAdvisor()
    local f=self.window;if not f then return end
    local function at(r,x,y) r:ClearAllPoints();r:SetPoint('TOPLEFT',x,-y) end
    local header=math.max(44,H:TextHeight(f.heading,470,2)+12,H:FitButton(f.control,2)+8)
    local y=24+header;at(f.state,24,y);y=y+H:TextHeight(f.state,932,2)+14
    local nh=30;for _,b in ipairs(f.nav) do nh=math.max(nh,H:FitButton(b,2)) end
    for i,b in ipairs(f.nav) do at(b,24+(i-1)*188,y);b:SetHeight(nh) end;y=y+nh+14
    at(f.note,24,y);y=y+H:TextHeight(f.note,932,2)+14
    if self.tab=='Talents' then
        for g,label in ipairs(f.treeLabels) do at(label,24+(g-1)*316,y) end;y=y+38
        for id,b in pairs(f.talentButtons) do
            if b:IsShown() then local n=b.talent;at(b,32+(n.group-1)*316+n.column*72,y+n.row*55) end
        end
        y=y+7*55+10
    else
        for _,b in ipairs(f.rows) do if b:IsShown() then at(b,24,y);y=y+H:FitButton(b,2,38)+8 end end
    end
    at(f.detail,24,y);y=y+H:TextHeight(f.detail,932,3)+12
    at(f.message,24,y);y=y+H:TextHeight(f.message,932,2)+12
    local max=30;local count=0
    for _,b in ipairs(f.actions) do if b:IsShown() then max=math.max(max,H:FitButton(b,2));count=count+1 end end
    for i,b in ipairs(f.actions) do if b:IsShown() then at(b,24+(i-1)%3*316,y+math.floor((i-1)/3)*(max+8));b:SetHeight(max) end end
    y=y+math.ceil(count/3)*(max+8)+14
    for i,b in ipairs({f.previous,f.next,f.close}) do at(b,({24,640,808})[i],y) end
    at(f.page,196,y+6);local fh=30;for _,b in ipairs({f.previous,f.next,f.close}) do fh=math.max(fh,H:FitButton(b,2)) end
    f:SetHeight(y+fh+24);local saved=FS.db.layout.frames['Tool:TalentAdvisor']
    f:SetScale(math.min(saved and saved.scale or 1,(UIParent:GetWidth()-32)/980,(UIParent:GetHeight()-32)/f:GetHeight()))
end
function A:DrawTalents()
    local f=self.window;local c=self:Catalog();if not c then return end
    local p=self:Selected();local target=p and self:Ranks(p.order) or {};local nextID=self:NextPoint()
    for g,label in ipairs(f.treeLabels) do label:SetText(c.groups[g]);label:Show() end
    for id,n in pairs(c.nodes) do
        local b=f.talentButtons[id]
        if not b then
            b=CreateFrame('Button',nil,f,'BackdropTemplate');H:Skin(b);b:SetSize(48,48);b:RegisterForClicks('LeftButtonUp','RightButtonUp')
            b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',3,-3);b.icon:SetPoint('BOTTOMRIGHT',-3,3);b.icon:SetTexture(n.icon)
            b.rank=H:Label(b,'',0,-32,48);b.rank:SetJustifyH('CENTER');FS:ApplyFont(b.rank,11,'OUTLINE')
            b.talent=n;b:SetScript('OnClick',function(_,button)
                A:EditTalent(id,button=='RightButton',T:Call(IsShiftKeyDown)==true);A:Refresh()
            end)
            b:SetScript('OnEnter',function()
                local active=A:Selected();local target=active and A:Ranks(active.order) or {}
                GameTooltip:SetOwner(b,'ANCHOR_RIGHT');GameTooltip:AddLine(n.name)
                GameTooltip:AddLine('Learned '..(A.currentReady and (A.current[id] or 0) or '?')..' / Planned '..(target[id] or 0)..' / Max '..n.max,1,1,1,true)
                if n.gate>0 then GameTooltip:AddLine('Requires '..n.gate..' points in '..c.groups[n.group],.8,.8,.8,true) end
                if n.pre~=0 then GameTooltip:AddLine('Requires '..n.preRank..' ranks in '..c.nodes[n.pre].name,.8,.8,.8,true) end
                local desc=T:Text(T:Call(C_Spell and C_Spell.GetSpellDescription,n.spells[1]));if desc~='' then GameTooltip:AddLine(desc,1,1,1,true) end
                GameTooltip:AddLine('Left-click: plan a point | Right-click: remove | Shift-click: flexible',.5,.85,1,true);GameTooltip:Show()
            end);b:SetScript('OnLeave',function() GameTooltip:Hide() end)
            f.talentButtons[id]=b
        end
        b.rank:SetText((self.currentReady and (self.current[id] or 0) or '?')..' > '..(target[id] or 0))
        b.icon:SetDesaturated(not target[id]);b:SetBackdropBorderColor(nextID==id and 1 or p and p.optional and p.optional[id] and .65 or .2,nextID==id and .82 or .65,nextID==id and .2 or .9,1)
        b:Show()
    end
end
function A:RenderAdvisor()
    local f=self.window;if not f or not f:IsShown() then return end
    self.tab=self.tab or 'Overview';self.page=self.page or 1
    local c=self:Catalog();local p=self:Selected();local rows,actions={},{}
    local function add(label,run) rows[#rows+1]={text=label,run=run} end
    local function action(label,run,enabled) actions[#actions+1]={label=label,run=run,enabled=enabled~=false} end
    f.state:SetText((c and c.class or 'Unsupported class')..'  |  '..(p and p.name or 'Choose a build')..'  |  '..(self.currentReady and ((self.currentSpent or 0)..' learned / '..(self.available or 0)..' unspent points') or 'Live talents unavailable'))
    for _,b in ipairs(f.rows) do b:Hide() end;for _,b in pairs(f.talentButtons) do b:Hide() end;for _,l in ipairs(f.treeLabels) do l:Hide() end
    f.detail:SetText('');f.note:SetText('')
    if not c then add('This class is not available in the WoW Forever talent catalog.')
    elseif self.tab=='Overview' then
        f.note:SetText('Your next point and the differences that matter. Advice does not spend talents for you.')
        local id,reason=self:NextPoint();add(id and ('Next point: '..c.nodes[id].name..(self.available>0 and ' — point available' or ' — when you earn a point')) or (reason or 'Choose a build and read your current talents.'))
        if p then
            local target,why=self:ValidatePlan(p)
            if target then
                local differences=0;for nid in pairs(c.nodes) do if (self.current[nid] or 0)~=(target[nid] or 0) then differences=differences+1 end end
                add(#p.order..' planned points  |  '..p.goal..'  |  '..(self.currentReady and differences..' differing talents' or 'Read current talents to compare'),function() A.tab='Talents';A:Refresh() end)
                add('Gear scale: '..p.scale..' — starter estimate',function() A.tab='Gear';A:Refresh() end)
                add('Source: '..(p.origin=='guide' and 'Icy Veins' or p.origin=='community' and 'Community' or 'Your build')..'  |  '..safe(p.author),function() A:ShowSource() end)
            else add(why) end
        end
        action('Choose build',function() A.tab='Builds';A.page=1 end)
        action('Refresh live talents',function() A.dirty=true end)
        action('Open game Talents',function() A:OpenGameTalents() end)
        action('Save variation',function() A:SaveForm() end,p~=nil)
        action('Build details',function() A:ShowSource() end,p~=nil)
        action('Compare point order',function() A:ShowPointOrder() end,p~=nil)
    elseif self.tab=='Builds' then
        f.note:SetText(self:Data().goal..' activities  |  '..self:Data().library..' sources. Click a build to select it.')
        local entries=self:Builds();table.sort(entries,function(a,b)return a.name<b.name end)
        for _,b in ipairs(entries) do
            local d=self:Data();local activity=d.goal=='All' or b.goal==d.goal or b.goal=='PvE' and (d.goal=='Dungeons' or d.goal=='Raids')
            local library=d.library=='All' or d.library=='Guides' and b.origin=='guide' or d.library=='My builds' and b.origin=='personal' or d.library=='Community' and b.origin=='community'
            if activity and library then local id=b.id
                local status=b.origin=='guide' and 'Icy Veins · '..safe(b.checked) or b.origin=='community' and (b.reviewedAt and 'Reviewed by you' or 'Not reviewed') or 'Personal'
                add(b.name..'  |  '..#b.order..' points  |  '..status,function() A:Select(id);A.tab='Overview';A.page=1 end)
            end
        end
        action('Activity: '..self:Data().goal,function() A:Cycle('goal') end)
        action('Library: '..self:Data().library,function() A:Cycle('library') end)
        action('New build',function() A:NewDraft() end)
        action('Import shared build',function() A:ImportForm() end)
        action('Share selected build',function() A:ExportForm() end,p~=nil)
        action('Mark reviewed by me',function() A:ReviewBuild() end,p and p.origin=='community')
        if p and p.id and self:Library().builds[p.id] then action('Delete saved build',function()
            local id=p.id
            A:Form('Delete '..p.name..'?',{},function()
                if not FS.Hub:Writable() then return false,'Character data is read-only.' end
                A:Library().builds[id]=nil;A:Data().selected='';A.draft=nil;A.gearWeights=nil;return true
            end,'Delete build')
        end) end
    elseif self.tab=='Talents' then
        f.note:SetText('Learned > Planned. Left-click adds, right-click removes; Shift-click marks a flexible choice. Gold marks the next point.')
        self:DrawTalents();f.detail:SetText(p and (#p.order..' / 51 planned points. '..safe(p.orderKind)..'. Changes are a draft until saved.') or 'Start a draft or choose a guide build.')
        action('Save build',function() A:SaveForm() end,p~=nil)
        action('Point-by-point route',function() A:ShowPointOrder() end,p~=nil)
        action('Discard draft',function() A.draft=nil;A.gearWeights=nil end,self.draft~=nil)
        action('Activity: '..(p and p.goal or 'Leveling'),function() A:CycleDraftGoal() end,p~=nil)
        action('Stat scale: '..(p and p.scale or 'Caster'),function() A:CycleDraftScale() end,p~=nil)
        action('Open game Talents',function() A:OpenGameTalents() end)
    elseif self.tab=='Gear' then
        f.note:SetText('Gear Advisor can follow this plan. Scores are starter stat estimates; procs, set bonuses and caps need separate checks.')
        if p then
            add('Selected plan: '..p.name..'  |  Stat scale: '..p.scale)
            if p.priority and #p.priority>0 then add('PvE stat reference: '..table.concat(p.priority,' / ')) end
            local notes=self:GearNotes();for _,line in ipairs(notes) do add(line) end
            add(FS.modules.GearAdvisor:Data().preset=='Custom' and 'Your Custom stat weights are preserved.' or 'Uses the build role\'s starter scale. Check the guide for stat caps and situational priorities.')
        else add('Choose a talent build before linking gear advice.') end
        action('Link Gear Advisor',function() local ok,why=A:LinkGear();if not ok then A.message=why end end,p~=nil)
        action('Open Gear Advisor',function() FS.modules.GearAdvisor:ShowWindow() end)
        action('Open Gear Planner',function() FS.modules.Workbench:Choose('Gear Planner') end)
        action('Build abilities',function() A:ShowAbilities() end,p~=nil)
        action('Key bindings',function() FS.modules.Bindings:ShowWindow() end)
        action('Build details',function() A:ShowSource() end,p~=nil)
    elseif self.tab=='Profiles' then
        f.note:SetText('A build profile combines a talent plan, gear preferences and optional layout. Learned talents stay under your control.')
        for id,b in pairs(self:Library().profiles) do if type(b)=='table' and b.plan and b.plan.class==c.class then local key=id;add((id==self.profileSelected and '> ' or '')..b.name..(b.layout and '  |  Includes layout' or ''),function() A.profileSelected=key end) end end
        table.sort(rows,function(a,b)return a.text<b.text end)
        action('Save build profile',function() A:Form('Save build profile',{{label='Profile name',value=p and p.name or 'My build',limit=64}},function(name) return A:SaveBundle(name) end,'Save profile') end,p~=nil)
        action('Preview / load',function() A:PreviewBundle() end,self.profileSelected~=nil)
        action('Undo profile load',function() A:UndoBundle() end,self.bundleUndo~=nil)
        action('Include layout: '..(self:Data().includeLayout and 'On' or 'Off'),function() A:Data().includeLayout=not A:Data().includeLayout end)
        action('Share profile',function() A:ExportForm(true) end,self.profileSelected~=nil)
        action('Import build / profile',function() A:ImportForm() end)
        if self.profileSelected and self:Library().profiles[self.profileSelected] then action('Delete build profile',function()
            local id=A.profileSelected
            A:Form('Delete this build profile?',{},function()
                if not FS.Hub:Writable() then return false,'Character data is read-only.' end
                A:Library().profiles[id]=nil;if A:Data().activeBundle==id then A:Data().activeBundle='' end;A.profileSelected=nil;A.gearWeights=nil;return true
            end,'Delete profile')
        end) end
    end
    local pages=math.max(1,math.ceil(#rows/6));self.page=math.max(1,math.min(pages,self.page))
    for i,b in ipairs(f.rows) do local row=rows[(self.page-1)*6+i];b.row=row
        if row then b:SetText(row.text);b:SetEnabled(row.run~=nil);b:Show();H:SetHelp(b,row.text) end
    end
    if #rows==0 and self.tab~='Talents' then f.detail:SetText('No entries in this view. Change filters or add your first build.') end
    self.actionList=actions
    for i,b in ipairs(f.actions) do local action=actions[i];b:SetShown(action~=nil);if action then b:SetText(action.label);b:SetEnabled(action.enabled) end end
    f.message:SetText(self.message or (not self.currentReady and self.currentError) or '')
    f.previous:SetEnabled(self.page>1);f.next:SetEnabled(self.page<pages);f.page:SetText(self.tab..'  |  '..self.page..' / '..pages)
    self:LayoutAdvisor()
end
function A:ShowAbilities()
    local p=self:Selected();local c=self:Catalog();if not p or not c then return end
    local lines={p.name,'Active talents in this plan. Visit a class trainer for other skill ranks; Train all is available in the trainer window.'}
    local names={}
    for id in pairs(self:Ranks(p.order)) do
        local n=c.nodes[id];local spell=n.spells[1]
        if T:Call(C_Spell and C_Spell.IsSpellPassive,spell)==false then
            local known=T:Call(IsPlayerSpell,spell)
            names[#names+1]=n.name..' | '..(known==true and 'Learned' or known==false and 'Not learned' or 'Check spellbook')..' | Spell '..spell
        end
    end
    table.sort(names);for _,name in ipairs(names) do lines[#lines+1]=name end
    if #names==0 then lines[#lines+1]='Active talent spell information is not available from this client yet.' end
    FS.Extensions:TextDialog('Build abilities',table.concat(lines,'\n'),true,nil,nil,function() A:ShowWindow() end,nil,'TalentAdvisor')
end
function A:Cycle(key)
    if not self:Allowed() then return end
    for _,option in ipairs(self.options) do if option.key==key then
        for i,v in ipairs(option.values) do if self:Data()[key]==v then self:Data()[key]=option.values[i%#option.values+1];break end end
    end end;self.page=1
end
function A:CycleDraftGoal()
    if not self:Allowed() then return end
    local p=self:Selected();if not p then return end
    local values={'Leveling','Dungeons','Raids','PvP'};local next=1;for i,v in ipairs(values) do if p.goal==v then next=i%#values+1 end end
    self.draft=self:AsDraft(p);self.draft.goal=values[next];self.gearWeights=nil
end
function A:CycleDraftScale()
    if not self:Allowed() then return end
    local p=self:Selected();if not p then return end
    local values={'Strength','Agility','Caster','Healer','Tank'};local next=1;for i,v in ipairs(values) do if p.scale==v then next=i%#values+1 end end
    self.draft=self:AsDraft(p);self.draft.scale=values[next];self.draft.priority=nil;self.draft.weights=nil;self.gearWeights=nil
end
function A:ShowPointOrder()
    local p=self:Selected();local c=self:Catalog();if not p or not c then return end
    local lines={p.name,safe(p.orderKind),'Level estimates use earned live points when readable; future levels assume one point per level.'}
    local ranks={};local level=T:Call(UnitLevel,'player') or 1
    local budget=self.currentReady and ((self.currentSpent or 0)+(self.available or 0)) or math.max(0,level-9)
    for i,id in ipairs(p.order) do
        ranks[id]=(ranks[id] or 0)+1;local expected=math.max(5,level+i-budget)
        lines[#lines+1]=string.format('%02d | Level ~%d | %s %d/%d%s',i,expected,c.nodes[id].name,ranks[id],c.nodes[id].max,p.optional and p.optional[id] and ' (flexible)' or '')
    end
    FS.Extensions:TextDialog('Talent leveling route',table.concat(lines,'\n'),true,nil,nil,function() A:ShowWindow() end,nil,'TalentAdvisor')
end
function A:PreviewBundle()
    local b=self:Library().profiles[self.profileSelected];if not b then return end
    local id=self.profileSelected
    self:Form('Load '..b.name..'? '..#b.plan.order..' planned talents, '..b.gear.preset..' gear scale'..(b.layout and ', saved layout' or ''),{},
        function() return A:UseBundle(id,b.layout~=nil) end,'Load build profile')
end
function A:OpenGameTalents()
    if not self:Allowed() then return end
    local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn;T:Call(load,'Blizzard_PlayerSpells')
    local frame=PlayerSpellsFrame
    local tab=PlayerSpellsUtil and PlayerSpellsUtil.FrameTabs and PlayerSpellsUtil.FrameTabs.ClassTalents
    if frame and tab and type(frame.TrySetTab)=='function' then
        if not T:Call(frame.TrySetTab,frame,tab) then self.message='The game Talents tab is not available for this character yet.';return end
        FS:CloseOtherWindows(frame)
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
    else self.message='Open the game Talents window using its normal keybind.' end
end
function A:ShowWindow()
    if not self:Allowed() then return end
    local f=self:CreateWindow();FS:CloseOtherWindows(f);f:Show();self.dirty=true;self:Refresh()
end

-- Native Talents integration is decorative only. The game owns all talent input.
function A:NativeVisible()
    local f=self.nativeFrame
    return f and not (f.IsForbidden and f:IsForbidden()) and f:IsShown()
end
function A:HideNativeHints()
    for _,hint in pairs(self.nativeHints or {}) do hint:Hide();hint.nodeID=nil end
end
function A:InstallNative()
    if not FS.initialized or not FS:IsModuleEnabled(self.name) then return end
    local root=PlayerSpellsFrame;local f=root and root.TalentsFrame
    if not f or (f.IsForbidden and f:IsForbidden()) then return end
    if self.nativeFrame~=f then
        if self.nativeFrame and self.nativeFrame.fsAdvisorButton then self.nativeFrame.fsAdvisorButton:Hide() end
        self:HideNativeHints();self.nativeFrame=f
    end
    if f.fsAdvisorHooked or InCombatLockdown() then return end
    f.fsAdvisorHooked=true
    local function queue() if FS:IsModuleEnabled(A.name) then A:Event('NATIVE_TALENTS') end end
    f:HookScript('OnShow',queue)
    f:HookScript('OnHide',function()
        if f.fsAdvisorButton then f.fsAdvisorButton:Hide() end
        A:HideNativeHints()
    end)
    for _,method in ipairs({'UpdateAllButtons','InstantiateTalentButton','RefreshConfigID','UpdateInspecting','UpdateTreeCurrencyInfo'}) do
        if type(f[method])=='function' then hooksecurefunc(f,method,queue) end
    end
    if not f.fsAdvisorButton then
        -- The native talent canvas has high-level input layers. Keep this
        -- header control on the window root, above those layers and outside
        -- the talent canvas's hit-test/clipping hierarchy.
        local b=H:Button(root,'Talent Advisor',0,0,184,function()
            if not A:Selected() then A.tab='Builds';A.page=1 end
            A:ShowWindow()
        end)
        f.fsAdvisorButton=b;b.fsSuiteStyle=true;b.fsFontModule='TalentAdvisor';b.fsLabel.fsSuiteStyle=true
        b:SetFrameStrata('DIALOG');b:EnableMouse(true);b:RegisterForClicks('LeftButtonUp')
        b:ClearAllPoints()
        b:SetPoint('TOPLEFT',root,'TOPLEFT',184,-4)
        H:FitButton(b,2,28)
        f.fsAdvisorPlan=H:Label(b,'',0,0,270);f.fsAdvisorPlan.fsSuiteStyle=true;f.fsAdvisorPlan.fsFontModule='TalentAdvisor'
        f.fsAdvisorPlan:SetWordWrap(false)
        f.fsAdvisorPlan:ClearAllPoints()
        if f.TabSystem then f.fsAdvisorPlan:SetPoint('LEFT',f.TabSystem,'RIGHT',16,0)
        else f.fsAdvisorPlan:SetPoint('TOPLEFT',f,'TOPLEFT',420,0) end
    end
    self:RefreshNative()
end
function A:NativeHint(node)
    self.nativeHints=self.nativeHints or setmetatable({},{__mode='k'})
    local hint=self.nativeHints[node]
    if hint then return hint end
    if InCombatLockdown() then return end
    hint=CreateFrame('Frame',nil,node);hint.fsSuiteStyle=true;hint.ignoreInLayout=true;hint:EnableMouse(false)
    hint:SetPoint('TOPLEFT',node,'TOPLEFT',-3,3);hint:SetPoint('BOTTOMRIGHT',node,'BOTTOMRIGHT',3,-3)
    hint.edges={}
    for i=1,4 do local edge=hint:CreateTexture(nil,'OVERLAY');edge.fsSuiteStyle=true;hint.edges[i]=edge end
    local top,bottom,left,right=unpack(hint.edges)
    top:SetPoint('TOPLEFT');top:SetPoint('TOPRIGHT');top:SetHeight(3)
    bottom:SetPoint('BOTTOMLEFT');bottom:SetPoint('BOTTOMRIGHT');bottom:SetHeight(3)
    left:SetPoint('TOPLEFT');left:SetPoint('BOTTOMLEFT');left:SetWidth(3)
    right:SetPoint('TOPRIGHT');right:SetPoint('BOTTOMRIGHT');right:SetWidth(3)
    hint.rank=H:Label(hint,'',0,0,30);hint.rank.fsSuiteStyle=true;hint.rank:ClearAllPoints()
    hint.rank:SetPoint('BOTTOMLEFT',hint,'TOPLEFT',0,0);FS:ApplyFont(hint.rank,10,'OUTLINE')
    hint:Hide();self.nativeHints[node]=hint;return hint
end
function A:RefreshNative()
    local f=self.nativeFrame;if not f then return end
    self:HideNativeHints()
    local enabled=FS.initialized and FS:IsModuleEnabled(self.name) and self:NativeVisible()
    if not f.fsAdvisorButton then return end
    local b=f.fsAdvisorButton;b:SetShown(enabled);f.fsAdvisorPlan:SetShown(enabled)
    if not enabled then return end
    local level=0
    for _,owner in ipairs({PlayerSpellsFrame,f,f.TabSystem,f.SearchBox}) do
        local value=T:Call(owner.GetFrameLevel,owner);if T:Number(value) then level=math.max(level,value) end
    end
    if not InCombatLockdown() then b:SetFrameLevel(level+30) end
    b:SetEnabled(not InCombatLockdown() and not FS.databaseReadOnly and not FS.modules.Vendor.busy)
    if InCombatLockdown() then return end
    local context=FS.Context and FS.Context.hosts[PlayerSpellsFrame]
    b:ClearAllPoints()
    if context and context.button then b:SetPoint('LEFT',context.button,'RIGHT',8,0)
    else b:SetPoint('TOPLEFT',PlayerSpellsFrame,'TOPLEFT',184,-4) end
    H:FitButton(b,2,28);H:TextHeight(f.fsAdvisorPlan,270,1)
    local p=self:Selected();local c=self:Catalog();local ranks=p and self:ValidatePlan(p)
    local inspect=T:Call(f.IsInspecting,f)==true
    local viewed=T:Call(f.GetConfigID,f)
    local active=self.currentReady and T:Number(viewed) and viewed==self.currentConfig
    local nextID=active and self:NextPoint() or nil
    f.fsAdvisorPlan:SetText(p and ('Following: '..p.name) or 'Choose a build')
    H:SetHelp(f.fsAdvisorPlan,p and p.name or 'Open Talent Advisor to choose a guide or a saved build.')
    if f.fsAdvisorPlan.fsHelpFrame then f.fsAdvisorPlan.fsHelpFrame.fsSuiteStyle=true end
    H:SetHelp(b,'Choose or edit your talent plan. Gold: next point. Blue: planned. Green: matched. Purple: flexible. P = planned rank. You spend points in the game as usual.')
    if inspect then f.fsAdvisorPlan:SetText('Your build is hidden while inspecting.');return end
    if not ranks or not c or not self:Data().nativeHighlights then return end
    if self.currentError and (self.currentError:find('catalog',1,true) or self.currentError:find('Update ForeverSuite',1,true)) then
        f.fsAdvisorPlan:SetText('Update talent data before following this plan.');return
    end
    if not active then
        f.fsAdvisorPlan:SetText(self.currentReady and viewed~=self.currentConfig and 'Plan only: viewed talents are inactive.' or 'Plan only: live talents unavailable.')
        H:SetHelp(f.fsAdvisorPlan,p.name..'\n'..(self.currentError or 'Select the active talent group to see your next point.'))
    end
    for id,rank in pairs(ranks) do
        local node=T:Call(f.GetTalentButtonByNodeID,f,id) or type(f.nodeIDToButton)=='table' and f.nodeIDToButton[id]
        if node and node.IsShown and node:IsShown() and not (node.IsForbidden and node:IsForbidden()) then
            local hint=self:NativeHint(node)
            if hint then
                local current=active and (self.current[id] or 0) or 0
                local color=id==nextID and {1,.8,.12} or active and current>=rank and {.2,.85,.4}
                    or p.optional and p.optional[id] and {.72,.42,1} or {.15,.75,1}
                local level=T:Call(node.GetFrameLevel,node);if T:Number(level) then hint:SetFrameLevel(level+12) end
                for _,edge in ipairs(hint.edges) do edge:SetColorTexture(color[1],color[2],color[3],1) end
                hint.nodeID=id;hint.kind=id==nextID and 'next' or active and current>=rank and 'matched' or p.optional and p.optional[id] and 'flexible' or 'planned'
                hint.rank:SetText('P'..rank);hint.rank:SetTextColor(color[1],color[2],color[3],1);hint:Show()
            end
        end
    end
end
