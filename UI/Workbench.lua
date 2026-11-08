local _,FS=...
local E,T,H=FS.Extensions,FS.Tools,FS.HUD
local W=T:Module('Workbench','workbench','More tools','Search settings, manage profiles and use the new module tools.',{view='Settings'},{}); E.workbench=W
W.views={'Settings','Favorites','Profiles','Accessibility','Alerts','NPC rules','Important casts','Chat keywords','Chat history','Guild notes','Recent groups','Item checklists','Buyback','Loot session','Waypoint queue','Leveling session','Maintenance'}
W.actions={{label='Open',run=function(self,text) self:Perform(1,text) end},{label='Change',run=function(self,text) self:Perform(2,text) end},{label='Favorite',run=function(self,text) self:Perform(3,text) end}}
function W:NextView()
    local d=self:Data(); for i,v in ipairs(self.views) do if v==d.view then d.view=self.views[i%#self.views+1]; break end end
    self.selected=nil; self.page=1; if self.window then self.window.search:SetText(''); self.window.input:SetText('') end; self:Refresh()
end
function W:Choose(view)
    if self:Data().view~=view and self.window then self.window.search:SetText(''); self.window.input:SetText('') end
    self:Data().view=view; self.selected=nil; self.page=1; self:ShowWindow()
end
local create=W.CreateWindow
function W:CreateWindow()
    local f=create(self); if f.section then return f end
    f.section=H:Button(f,'',16,-54,628,function()
        local menu=f.categoryMenu; local height=0
        for _,button in ipairs(menu.buttons) do height=math.max(height,H:FitButton(button,1)+6) end
        for i,button in ipairs(menu.buttons) do button:ClearAllPoints(); button:SetPoint('TOPLEFT',12+(i-1)%2*312,-12-math.floor((i-1)/2)*height) end
        menu:SetHeight(24+math.ceil(#menu.buttons/2)*height); menu:SetShown(not menu:IsShown())
    end)
    f.categoryMenu=CreateFrame('Frame',nil,f,'BackdropTemplate'); H:Skin(f.categoryMenu); f.categoryMenu:SetBackdropColor(.02,.03,.04,1); f.categoryMenu:SetSize(628,350); f.categoryMenu:SetPoint('TOPLEFT',f.section,'BOTTOMLEFT',-42,-4); f.categoryMenu:SetFrameLevel(f:GetFrameLevel()+80); f.categoryMenu:EnableMouse(true); f.categoryMenu.buttons={}
    for _,view in ipairs(self.views) do local chosen=view; local button=H:Button(f.categoryMenu,chosen,0,0,298,function() f.categoryMenu:Hide(); W:Choose(chosen) end); f.categoryMenu.buttons[#f.categoryMenu.buttons+1]=button end
    f.categoryMenu:Hide(); f:HookScript('OnHide',function() f.categoryMenu:Hide() end)
    f.previousSection=H:Button(f,'<',16,-54,34,function()
        for i,v in ipairs(W.views) do if v==W:Data().view then W:Data().view=W.views[(i-2)%#W.views+1]; break end end
        W.selected=nil; W.page=1; f.search:SetText(''); f.input:SetText(''); W:Refresh()
    end)
    f.section:SetWidth(586); f.section:ClearAllPoints(); f.section:SetPoint('TOPLEFT',58,-54)
    local layout=f.LayoutText
    function f:LayoutText()
        layout(self)
        local point={self.search:GetPoint()}; local top=point[5] or point[3]
        self.section:ClearAllPoints(); self.section:SetPoint('TOPLEFT',58,top); H:FitButton(self.section,1,34)
        self.previousSection:ClearAllPoints(); self.previousSection:SetPoint('TOPLEFT',16,top); H:FitButton(self.previousSection,1,34)
        local frames={self.search,self.status,self.pageLabel,self.previous,self.next,self.close,self.input}
        for _,b in ipairs(self.cells) do frames[#frames+1]=b end; for _,b in ipairs(self.actionButtons) do frames[#frames+1]=b end
        for _,r in ipairs(frames) do local p={r:GetPoint()}; if type(p[5])=='number' then p[5]=p[5]-44 elseif type(p[3])=='number' then p[3]=p[3]-44 end; r:ClearAllPoints(); r:SetPoint(unpack(p)) end
        self:SetHeight(self:GetHeight()+44)
        self:SetScale(math.min(1,(UIParent:GetWidth()-32)/660,(UIParent:GetHeight()-32)/self:GetHeight()))
    end
    return f
end
local function toggle(map,key) if map[key] then map[key]=nil else map[key]=true end end
function E:SettingsIndex()
    local rows,seen={},{}; local function caption(owner) return (FS.modules[owner] and FS.modules[owner].title) or ({Gear='Gear & Durability',ActionBars='Action Bars',UnitFrames='Unit Frames',Character='Character Info',Workbench='More tools'})[owner] or owner end
    local function add(owner,key,label,ref,option)
        local id=owner..':'..key; if seen[id] then return end; seen[id]=true
        rows[#rows+1]={id=owner..':'..key,owner=owner,key=key,ref=ref,option=option,label=label,text=caption(owner)..' | '..label..': '..tostring(ref[key])}
    end
    for name,module in pairs(FS.modules) do
        if name~='Workbench' then rows[#rows+1]={id=name..':settings',owner=name,key='',ref={},option={},label='Module settings',text=caption(name)..' | Open module settings'} end
        local ref=module.key and FS.db[module.key]
        if name=='Vendor' then ref=FS.db.vendor elseif name=='Bags' then ref=FS.db.bags elseif name=='Gear' then ref=FS.db.gear end
        if ref and name~='Workbench' then
            for _,o in ipairs(module.options or {}) do add(name,o.key,o.label,ref,o) end
            for _,group in ipairs(module.designGroups or {}) do for _,o in ipairs(group.options) do add(name,o.key,o.label,ref,o) end end
            local explicit={Vendor={{'includeGray','Sell gray junk'},{'autoRepair','Repair automatically'},{'protectRare','Protect rare items'},{'report','Sale reports'}},Bags={{'showCooldowns','Show item cooldowns'},{'showNewLoot','Show NEW markers'},{'showEmpty','Show empty slots'},{'replaceNative','Replace native bags'}},Gear={{'showButton','Show gear button'},{'warn','Low durability warning'}},UnitFrames={{'showPet','Show pet frame'},{'showFocus','Show focus frame'},{'showParty','Show party frames'},{'showRaid','Show raid frames'}},ActionBars={{'menu','Top-left main menu'}}}
            for _,o in ipairs(explicit[name] or {}) do add(name,o[1],o[2],ref,{key=o[1],label=o[2]}) end
            local defaults=FS.defaults[module.key or name:sub(1,1):lower()..name:sub(2)] or {}
            for key,value in pairs(defaults) do if type(value)~='table' and key~='uiVersion' then local label=key:gsub('(%l)(%u)','%1 %2'); label=label:sub(1,1):upper()..label:sub(2); add(name,key,label,ref,{key=key}) end end
        end
    end
    for _,o in ipairs(FS.Typography.options) do add('Typography',o.key,o.label,FS.db.typography.global,o) end
    for _,o in ipairs({{'Chat','keywordsEnabled','Keyword highlights'},{'Chat','captureChat','Capture session chat'},{'Social','trackGroups','Remember recent groups'},{'Guild','showPrivateNotes','Show local guild notes'}}) do add(o[1],o[2],o[3],FS.db.extras,{key=o[2]}) end
    add('Workbench','nativeWindows','Style game popup windows (off restores native art)',FS.db.extras,{key='nativeWindows'})
    table.sort(rows,function(a,b) return a.id<b.id end); return rows
end
function E:Form(title,fields,save)
    if not self:Allowed() then FS:Print(FS.Text.leaveCombat); return end
    local f=self.form
    if not f then
        f=CreateFrame('Frame','ForeverSuiteEditForm',UIParent,'BackdropTemplate'); self.form=f; f:SetSize(720,400); f:SetPoint('CENTER'); f:SetClampedToScreen(true); f:SetFrameStrata('DIALOG'); f:EnableMouse(true)
        f.heading=H:Label(f,'',24,-20,672); f.edits={}; f.labels={}; f.status=H:Label(f,'',24,-300,672)
        f.save=H:Button(f,FS.Text.apply,24,-350,320,function()
            if not E:Allowed() then f.status:SetText(FS.Text.leaveCombat); return end
            local values={}; for i=1,f.fieldCount do values[i]=f.edits[i]:GetText() end
            local ok,message=f.saveAction(unpack(values)); if ok then f:Hide(); W:ShowWindow() else f.status:SetText(message or 'Check the entered values.') end
        end)
        f.cancel=H:Button(f,FS.Text.cancel,376,-350,320,function() f:Hide(); W:ShowWindow() end)
        f:SetScript('OnHide',function() f.saveAction=nil end); UISpecialFrames[#UISpecialFrames+1]='ForeverSuiteEditForm'
    end
    f:Hide(); f.saveAction=save; f.fieldCount=math.min(8,#fields); H:Skin(f); FS:FontTree(f)
    f:SetBackdropBorderColor(unpack(FS.moduleCardColors[W.activeOwner] or {.12,.72,.86}))
    f.heading:SetText(title); f.status:SetText(''); local y=math.max(62,20+H:TextHeight(f.heading,672,3)+18)
    for i=1,f.fieldCount do
        local spec=fields[i]
        if not f.labels[i] then f.labels[i]=H:Label(f,'',24,0,672); f.edits[i]=T:Edit(f,24,0,672) end
        local label,edit=f.labels[i],f.edits[i]; label:SetText(spec.label); label:ClearAllPoints(); label:SetPoint('TOPLEFT',24,-y); label:Show(); y=y+H:TextHeight(label,672,2)+8
        FS:ApplyFont(edit); local _,size=edit:GetFont(); edit:SetHeight(math.max(30,(size or 14)+12)); edit:ClearAllPoints(); edit:SetPoint('TOPLEFT',24,-y); edit:SetText(tostring(spec.value or '')); edit:SetMaxLetters(spec.limit or 256); edit:Show(); y=y+edit:GetHeight()+18
    end
    for i=f.fieldCount+1,#f.edits do f.edits[i]:Hide(); f.labels[i]:Hide() end
    f.status:ClearAllPoints(); f.status:SetPoint('TOPLEFT',24,-y); f.status:SetHeight(44); y=y+44
    local height=0; for i,button in ipairs({f.save,f.cancel}) do button:ClearAllPoints(); button:SetPoint('TOPLEFT',i==1 and 24 or 376,-y); height=math.max(height,H:FitButton(button,2)) end
    f:SetHeight(y+height+24); f:SetScale(math.min(1,(UIParent:GetWidth()-32)/720,(UIParent:GetHeight()-32)/f:GetHeight()))
    FS:CloseOtherWindows(f); f:Show(); return f
end
function E:TextDialog(title,text,readOnly,validate,apply)
    if not self:Allowed() then return end
    local f=self.dialog
    if not f then
        f=CreateFrame('Frame','ForeverSuiteTextDialog',UIParent,'BackdropTemplate'); self.dialog=f; f:SetSize(760,580); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true); f:EnableMouse(true)
        f.heading=H:Label(f,'',24,-20,712); f.scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate'); f.scroll:SetSize(684,370)
        f.measure=f:CreateFontString(nil,'OVERLAY'); f.measure:Hide(); f.measure:SetWidth(678); f.measure:SetHeight(0)
        local edit=CreateFrame('EditBox',nil,f.scroll); f.edit=edit; edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetWidth(678); edit:SetHeight(370); edit:SetMaxLetters(200000); FS:ApplyFont(edit,12); f.scroll:SetScrollChild(edit)
        edit:SetScript('OnEscapePressed',function(b) b:ClearFocus() end); f.status=H:Label(f,'',24,-444,712)
        function f:ResizeText()
            local _,size=self.edit:GetFont(); size=size or 12; local value=self.edit:GetText() or ''; local _,breaks=value:gsub('\n','')
            local height=(math.ceil(#value/math.max(1,math.floor(678/(size*.65))))+breaks+1)*(size+3)
            if self.measure.GetStringHeight then
                self.measure:SetFont(self.edit:GetFont()); self.measure:SetText(value)
                local measured=self.measure:GetStringHeight(); if T:Number(measured) then height=math.max(height,measured+size+8) end
            end
            self.edit:SetHeight(math.max(370,height))
            if self.scroll.UpdateScrollChildRect then self.scroll:UpdateScrollChildRect() end
        end
        f.preview=H:Button(f,FS.Text.preview,24,-520,210,function()
            if f.readOnly then edit:SetFocus(); edit:HighlightText(); return end
            f.candidate=nil; local data,message=f.validate(edit:GetText()); f.candidate=data; f.status:SetText(message or 'Invalid import.'); f.apply:SetEnabled(data~=nil); f:Layout()
        end)
        f.apply=H:Button(f,FS.Text.apply,274,-520,210,function()
            if not E:Allowed() then f.status:SetText(FS.Text.leaveCombat); return end
            if f.candidate and f.applyAction and f.applyAction(f.candidate) then f:Hide(); W:ShowWindow() end
        end)
        f.cancel=H:Button(f,FS.Text.cancel,524,-520,210,function() f:Hide(); W:ShowWindow() end)
        edit:SetScript('OnTextChanged',function() f:ResizeText(); if not f.readOnly then f.candidate=nil; f.apply:SetEnabled(false) end end)
        function f:Layout()
            self.scrollTop=math.max(60,20+H:TextHeight(self.heading,712,2)+12); self.scroll:ClearAllPoints(); self.scroll:SetPoint('TOPLEFT',24,-self.scrollTop)
            self.status:ClearAllPoints(); self.status:SetPoint('TOPLEFT',24,-self.scrollTop-384)
            local y=self.scrollTop+384+H:TextHeight(self.status,712,4)+16; local height=0
            for i,button in ipairs({self.preview,self.apply,self.cancel}) do button:ClearAllPoints(); button:SetPoint('TOPLEFT',({24,274,524})[i],-y); height=math.max(height,H:FitButton(button,2)) end
            self:SetHeight(y+height+24); self:SetScale(math.min(1,(UIParent:GetWidth()-32)/760,(UIParent:GetHeight()-32)/self:GetHeight()))
        end
        f:SetScript('OnHide',function() f.candidate=nil; f.validate=nil; f.applyAction=nil end); UISpecialFrames[#UISpecialFrames+1]='ForeverSuiteTextDialog'
    end
    f:Hide(); H:Skin(f); FS:FontTree(f); f.readOnly=readOnly; f.validate=validate; f.applyAction=apply; f.candidate=nil
    f:SetBackdropBorderColor(unpack(FS.moduleCardColors[W.activeOwner] or {.12,.72,.86})); f.heading:SetText(title); f.edit:SetText(text or '')
    f.status:SetText(readOnly and 'Select all, then Ctrl+C to copy. This window does not send messages.' or 'Paste a ForeverSuite export, then Preview before applying.')
    f.preview:SetText(readOnly and 'Select all' or FS.Text.preview); f.apply:SetShown(not readOnly); f.apply:SetEnabled(false); f.cancel:SetText(readOnly and FS.Text.close or FS.Text.cancel)
    f:ResizeText(); f:Layout(); if f.scroll.SetVerticalScroll then f.scroll:SetVerticalScroll(0) end
    FS:CloseOtherWindows(f); f:Show(); return f
end
local function row(id,text,kind,data) local r=data or {}; r.id=id; r.text=text; r.kind=kind; return r end
function W:Build()
    E:Normalize(); local d=E:Data(); local view=self:Data().view; local rows={}; local labels={'Open','Change','Favorite'}; local owner='Core'
    local valid=false; for _,v in ipairs(self.views) do if v==view then valid=true end end; if not valid then view='Settings'; self:Data().view=view end
    local entered=self.lastView~=view; self.lastView=view
    if view=='Settings' or view=='Favorites' then
        for _,r in ipairs(E:SettingsIndex()) do if view=='Settings' or d.settingFavorites[r.id] then rows[#rows+1]=r end end
        self.status='Search labels or module names. Open goes to the module; Change cycles a value; Favorite pins it.'
    elseif view=='Profiles' then
        owner='Profiles'; labels={'Open / export','Use / restore','Assign login'}
        rows={row('export','Export active profile (private notes and chat history excluded)','export'),row('import','Import profile: enter a name below, then open the paste window','import'),row('assignment','Login profile: '..(FS.db.profiles.characters[E:CharacterKey() or ''] or 'Not assigned')..' (Assign login clears this entry)','assignment')}
        for _,name in ipairs(FS.modules.Profiles:Names()) do rows[#rows+1]=row('profile:'..name,'Profile: '..name,'profile',{name=name}) end
        for i,b in ipairs(FS.db.profiles.backups) do rows[#rows+1]=row('backup:'..i,'Backup: '..b.name..' | '..b.reason,'backup',{index=i}) end
        self.status='Import uses the name entered below. Preview validates data without running code. The last five replaced profiles are backed up.'
    elseif view=='Accessibility' then
        labels={'Apply preset','Next palette','Undo'}
        rows={row('readable','Readable text: size 18 and thin outline','preset',{name='Readable text'}),row('compact','Compact screen: size 12, unit frames at 85%','preset',{name='Compact screen'}),row('palette','Palette: '..d.palette..' | labels remain visible','palette')}
        self.status='Preset changes affect suite text/unit frames, never native action bar geometry. Undo restores the previous settings.'
    elseif view=='Alerts' then
        labels={'Next sound','Next channel','Test sound'}
        for _,name in ipairs({'Keyword','Important cast','Waypoint arrival','Low durability','Level up'}) do local a=d.alerts[name] or {sound='Silent',channel='SFX'}; rows[#rows+1]=row(name,name..' | '..a.sound..' | '..a.channel,'alert',{name=name}) end
        self.status='Silent is the default. Channels use the game volume settings; alerts never change global volume. Repeated alerts have a 10-second cooldown.'
    elseif view=='NPC rules' then
        owner='Nameplates'; labels={'Save target','Update rule','Remove rule'}
        for id in pairs(d.npcRules) do rows[#rows+1]=row(id,'NPC '..id..' | saved nameplate design','npc',{npc=id}) end
        self.status='Set a design in Nameplates first. Save target stores that design for the targeted NPC; alternatively enter its numeric NPC ID below.'
    elseif view=='Important casts' then
        owner='Nameplates'; labels={'Add spell ID','Show settings','Remove'}
        for id in pairs(d.importantSpells) do rows[#rows+1]=row(id,'Spell '..id..' | orange emphasis and ! label','spell',{spell=id}) end
        self.status='Enter a spell ID below. Emphasis uses readable cast IDs only and never casts or interrupts automatically.'
    elseif view=='Chat keywords' then
        owner='Chat'; labels={'Add keyword',d.keywordsEnabled and 'Disable' or 'Enable','Remove'}
        for i,word in ipairs(d.keywords) do rows[#rows+1]=row(i,word,'keyword',{index=i}) end
        self.status='Enter a literal keyword below (2–64 characters). Hyperlinks stay intact. Optional sound is configured in Alerts.'
    elseif view=='Chat history' then
        owner='Chat'; labels={d.captureChat and 'Stop capture' or 'Start capture','Copy history','Clear history'}
        rows={row('capture','Session capture: '..(d.captureChat and 'On' or 'Off')..' | '..#E.chat..' / 200 messages','capture')}
        self.status='Opt-in, session-only capture. Copy opens selectable text; no clipboard or chat sending is automated.'
    elseif view=='Guild notes' then
        owner='Guild'; labels={'Star / unstar','Save note','Clear note'}
        if entered then T:Call(C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster) end
        FS.modules.Guild:Build()
        for _,r in ipairs(FS.modules.Guild.rows) do rows[#rows+1]=row(r.localKey,r.text..(not d.showPrivateNotes and d.guildNotes[r.localKey] and ' | Private: '..d.guildNotes[r.localKey] or ''),'guild',{key=r.localKey}) end
        self.status='Select a guild member and enter a private note below. Notes stay in your SavedVariables and are never sent to the guild.'
    elseif view=='Recent groups' then
        owner='Social'; labels={d.trackGroups and 'Stop tracking' or 'Start tracking','Clear history','Forget member'}
        for key,r in pairs(d.recentGroups) do rows[#rows+1]=row(key,r.name..' | last seen '..(T:Call(date,'%d %b %H:%M',r.time) or tostring(r.time)),'group',{key=key,time=r.time}) end
        table.sort(rows,function(a,b) return a.time>b.time end)
        self.status='Optional group roster history, up to 100 members. Existing party/raid members are recorded after you start tracking.'
    elseif view=='Item checklists' then owner='Bags'; labels={'Add item','Edit goal','Remove item'}; rows=E:ChecklistRows(); for _,r in ipairs(rows) do r.id=r.list..':'..r.id; r.item=tonumber(r.id:match(':(%d+)$')); r.kind='checklist' end
        self.status='Lists show carried/missing stock. Goals never buy, sell or reserve items; Vendor keep-stock rules protect supplies. Select a bag item to prefill its ID.'
    elseif view=='Buyback' then
        owner='Vendor'; labels={'Buy back','Open merchant tools','Refresh'}
        if FS.modules.Vendor.merchantOpen then for i=1,(T:Call(GetNumBuybackItems) or 0) do local name,_,price,count=T:Call(GetBuybackItemInfo,i); if T:Text(name)~='' and T:Number(price) then rows[#rows+1]=row(i,name..' x'..tostring(count or 1)..' | '..FS.modules.Vendor:Money(price),'buyback',{index=i}) end end end
        self.status='Visit a merchant. Select an item and click Buy back to recover it manually; the current price and money are checked again.'
    elseif view=='Loot session' then
        owner='Loot'; labels={'Reset session','Open Loot','Refresh'}
        rows={row('count','Items received: '..E.loot.items),row('value','Known vendor value: '..FS.modules.Vendor:Money(E.loot.value)),row('unknown','Items with unknown vendor value: '..E.loot.unknown)}
        self.status='Session-only summary of your own item loot. Unknown prices are excluded from value totals.'
    elseif view=='Waypoint queue' then
        owner='Map'; labels={'Start / add','Move up','Remove / stop'}
        for i,p in ipairs(d.waypointQueue) do rows[#rows+1]=row('queue:'..i,i..'. '..p.name,'queue',{index=i}) end
        for i,p in ipairs(FS.db.map.pins) do rows[#rows+1]=row('pin:'..i,'Saved pin: '..p.name,'pin',{index=i}) end
        self.status='Select a saved pin and Start / add to append it; select a queue entry to start. Arrival advances to the next pin. Direct guidance, not terrain routing.'
    elseif view=='Leveling session' then
        owner='QoL'; labels={'Reset session','Open Leveling','Refresh'}
        local gained,rate,eta=E:XPStats(); rows={row('gained','Session XP gained: '..gained),row('rate',rate and ('XP per hour: '..math.floor(rate)) or 'XP per hour: waiting for observed gains (10 seconds minimum)'),row('eta',eta and ('Estimated minutes to level: '..math.ceil(eta/60)) or 'Time to level: insufficient readable XP data')}
        self.status='Rates use observed XP gains and session time. Reset when starting a new leveling session.'
    else
        labels={'Client status','Clear audit','Undo'}
        for i,r in ipairs(E.audit) do rows[#rows+1]=row(i,r.text,'audit') end
        for _,capability in ipairs(FS:ClientCapabilities()) do rows[#rows+1]=row('API:'..capability.label,capability.label..': '..(capability.available and 'Available' or FS.Text.unavailable),'capability') end
        for _,definition in ipairs(FS.NativeWindows.definitions) do if not _G[definition[1]] then rows[#rows+1]=row(definition[1],definition[4]..': window not loaded; game fallback remains available','missing') end end
        self.status='Read-only combat/target layout snapshots (last 20). This does not correct secure geometry in combat. /fs status reports client availability.'
    end
    self.rows=rows; self.activeOwner=owner
    if self.window then
        self.window.section:SetText('Tools: '..view..'  >')
        for i,b in ipairs(self.window.actionButtons) do b:SetText(labels[i]) end
        self.window.input:SetShown(view=='Profiles' or view=='NPC rules' or view=='Important casts' or view=='Chat keywords' or view=='Guild notes')
        self.window.input:SetMaxLetters(({Profiles=32,['NPC rules']=10,['Important casts']=10,['Chat keywords']=64,['Guild notes']=256})[view] or 256)
        local color=FS.moduleCardColors[owner] or {.12,.72,.86}; self.window:SetBackdropBorderColor(unpack(color))
    end
end
function W:OnSelect(selected)
    if not selected or not self.window then return end
    if selected.kind=='guild' then self.window.input:SetText(E:Data().guildNotes[selected.key] or '') end
end
function W:Perform(action,text)
    if not E:Allowed() then self.status=FS.Text.leaveCombat; return end
    local r; for _,v in ipairs(self.rows) do if self.selected and v.id==self.selected.id then r=v; break end end
    local view=self:Data().view; local d=E:Data(); text=T:Text(text)
    if view=='Settings' or view=='Favorites' then
        if not r then return end
        if action==3 then toggle(d.settingFavorites,r.id)
        elseif action==1 then
            if r.owner=='Typography' then FS.Typography.scope='All modules'; FS.Typography:Show()
            elseif r.owner=='Workbench' then self:Choose('Maintenance') else FS:ConfigureModule(r.owner) end
        else
            local o=r.option; local current=r.ref[r.key]
            if o.values then local next=o.values[1]; for i,v in ipairs(o.values) do if current==v then next=o.values[i%#o.values+1]; break end end; r.ref[r.key]=next
            elseif o.min then r.ref[r.key]=current+(o.step or 1); if r.ref[r.key]>o.max then r.ref[r.key]=o.min end
            elseif type(current)=='boolean' then r.ref[r.key]=not current else self.status='Open the module to edit this value.'; return end
            if r.key=='enabled' then FS:SetModuleEnabled(r.owner,r.ref[r.key])
            elseif r.owner=='Typography' then FS.Typography:Apply()
            elseif r.owner=='Bags' then FS.modules.Bags:NormalizeSettings(); FS.modules.Bags:Refresh(); FS:RefreshConfig()
            else FS.modules[r.owner]:SettingsChanged() end
            if r.key=='nativeWindows' then FS.NativeWindows:Refresh() end
        end
    elseif view=='Profiles' then
        local P=FS.modules.Profiles; if not r then return end
        if action==3 then P:AssignCharacter(r.kind=='profile' and r.name or nil)
        elseif action==2 then if r.kind=='profile' then P:Load(r.name) elseif r.kind=='backup' then P:RestoreBackup(r.index) end
        elseif r.kind=='export' then local ok,code=pcall(P.Export,P); if ok then E:TextDialog('Export profile',code,true) else self.status=tostring(code) end
        elseif r.kind=='import' then
            local name=text:match('^%s*(.-)%s*$'); if name=='' then name='Imported' end
            E:TextDialog('Import into profile: '..name,'',false,function(code) return P:PreviewImport(code) end,function(data) return P:Import(name,data) end)
        elseif r.kind=='profile' then self.window.input:SetText(r.name) end
    elseif view=='Accessibility' then
        if action==3 then E:Undo() elseif action==2 then local values={'Original','Color-friendly','High contrast'}; for i,v in ipairs(values) do if d.palette==v then d.palette=values[i%3+1]; break end end; E:Refresh(); FS.modules.Nameplates:RefreshPlates()
        elseif r and r.kind=='preset' then E:ApplyPreset(r.name); FS.Typography:Apply(); FS.modules.UnitFrames:SettingsChanged() end
    elseif view=='Alerts' and r then
        local a=d.alerts[r.name] or {sound='Silent',channel='SFX'}; d.alerts[r.name]=a
        if action==3 then self.status=E:Alert(r.name,true) and 'Played on '..a.channel..'; volume follows the game channel.' or 'Silent, or audio API unavailable.'
        else local key=action==1 and 'sound' or 'channel'; local values=action==1 and {'Silent','Bell','Ready','Warning'} or {'SFX','Master','Dialog'}; for i,v in ipairs(values) do if a[key]==v then a[key]=values[i%#values+1]; break end end end
    elseif view=='NPC rules' then
        if action==1 then E:SaveNPCRule(tonumber(text) or E:NPCID('target')) elseif r and action==2 then E:SaveNPCRule(r.npc) elseif r then d.npcRules[r.npc]=nil; FS.modules.Nameplates:RefreshPlates() end
    elseif view=='Important casts' then
        if action==1 then local id=tonumber(text); if T:Number(id) and id>0 then d.importantSpells[math.floor(id)]=true end
        elseif action==2 then FS:ConfigureModule('Nameplates') elseif r then d.importantSpells[r.spell]=nil end
    elseif view=='Chat keywords' then
        if action==1 then if not E:AddKeyword(text) then self.status='Enter a unique keyword of 2–64 characters (maximum 20).' end
        elseif action==2 then d.keywordsEnabled=not d.keywordsEnabled elseif r then table.remove(d.keywords,r.index) end; E:UpdateFilters()
    elseif view=='Chat history' then
        if action==1 then d.captureChat=not d.captureChat; E:UpdateFilters() elseif action==2 then E:TextDialog('Copy chat history',table.concat(E.chat,'\n'),true) else E.chat={} end
    elseif view=='Guild notes' and r then
        if action==1 then toggle(d.guildFavorites,r.key) elseif action==2 then d.guildNotes[r.key]=text~='' and text:sub(1,256) or nil else d.guildNotes[r.key]=nil end
    elseif view=='Recent groups' then
        if action==1 then d.trackGroups=not d.trackGroups; E:GroupChanged() elseif action==2 then d.recentGroups={} elseif r then d.recentGroups[r.key]=nil end
    elseif view=='Item checklists' then
        if action==3 and r then d.checklists[r.list][r.item]=nil
        else E:Form(action==1 and 'Add checklist item' or 'Edit checklist goal',{{label='Checklist name',value=r and r.list or '',limit=32},{label='Item ID',value=(action==1 and FS.modules.Bags.selected and FS.modules.Bags.selected.id) or (r and r.item) or ''},{label='Required quantity',value=r and r.required or 1}},function(name,id,count) return E:Checklist(name,tonumber(id),tonumber(count)) end) end
    elseif view=='Buyback' then
        if action==1 and r then if not E:Buyback(r.index) then self.status='Buyback unavailable, item changed or insufficient money.' end elseif action==2 then FS.modules.Bags:ShowTools() end
    elseif view=='Loot session' then if action==1 then E.loot={items=0,value=0,unknown=0} elseif action==2 then FS.modules.Loot:ShowWindow() end
    elseif view=='Waypoint queue' then
        if action==1 then if r and r.kind=='pin' then if #d.waypointQueue<50 then d.waypointQueue[#d.waypointQueue+1]=E.Copy(FS.db.map.pins[r.index]) end else E:StartQueue() end
        elseif action==2 and r and r.kind=='queue' and r.index>1 then local p=table.remove(d.waypointQueue,r.index); table.insert(d.waypointQueue,r.index-1,p); E.queueActive=false
        elseif action==3 then if r and r.kind=='queue' then table.remove(d.waypointQueue,r.index) end; E.queueActive=false; FS.modules.Map:ClearNavigation() end
    elseif view=='Leveling session' then if action==1 then E:ResetXP() elseif action==2 then FS.modules.QoL:ShowWindow() end
    elseif view=='Maintenance' then if action==1 then FS:PrintClientStatus() elseif action==2 then E.audit={} else E:Undo() end end
end
