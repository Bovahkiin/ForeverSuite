local _,FS=...
local E,T,H=FS.Extensions,FS.Tools,FS.HUD
local W=T:Module('Workbench','workbench','More tools','Search settings, manage profiles and use the new module tools.',{view='Settings'},{}); E.workbench=W
W.views={'Settings','Favorites','Profiles','Accessibility','Alerts','NPC rules','Important casts','Chat keywords','Chat history','Guild notes','Recent groups','Item checklists','Buyback','Loot session','Waypoint queue','Leveling session','Maintenance','Layout presets','Character stock','Trainer preview','Route Library','Gathering runs','Notification Center','Rare sightings','Dungeon preparation'}
W.actions={{label='Open',run=function(self,text) self:Perform(1,text) end},{label='Change',run=function(self,text) self:Perform(2,text) end},{label='Favorite',run=function(self,text) self:Perform(3,text) end},{label='',run=function(self,text) self:Perform(4,text) end}}
W.views[#W.views+1]='Dungeon & Raid Journal'
W.views[#W.views+1]='Gear Wishlist'
W.views[#W.views+1]='Run Notes'
W.views[#W.views+1]='Next steps'
W.views[#W.views+1]='Profession recommendations'
local guideRoot='https://www.wow-professions.com/forever/'
local professionRecommendations={
    {profession='Mining',skill='1-65',zone='Zephras Isle',guide='mining-leveling-guide',
        tip="Gather Copper Ore in the area marked on the guide map. Use the forge at Shen'dar Village to smelt it for additional skill points."},
    {profession='Mining',skill='1-65',zone='Durotar',guide='mining-leveling-guide',
        tip='Follow the copper loop in the guide and use the forge at Razor Hill to turn your ore into bars.'},
    {profession='Mining',skill='1-65',zone='Elwynn Forest',guide='mining-leveling-guide',
        tip='Gather copper along the route shown in the guide. You can skip the cave at low level. Smelt the ore in Goldshire.'},
    {profession='Mining',skill='65-125',zone='Westfall',guide='mining-leveling-guide',
        tip='Train Journeyman Mining, then look for Tin Veins around the cave marked in the guide. Stay outside if the level 13-15 enemies inside are too tough.'},
    {profession='Herbalism',skill='1-70',zone='Zephras Isle',guide='herbalism-leveling-guide',
        tip='Gather Peacebloom and Silverleaf on the island. Add Earthroot when you reach Herbalism 15. The guide includes an island circuit.'},
    {profession='Herbalism',skill='70-115',zone='Silverpine Forest',guide='herbalism-leveling-guide',
        tip='Train Journeyman Herbalism and gather Mageroyal and Briarthorn along the southern loop in the guide. Stranglekelp requires Herbalism 85.'},
    {profession='Skinning',skill='1-75',zone='Zephras Isle',guide='skinning-leveling-guide',
        tip='Skin low-level beasts as you quest in the starting area. Choose Pelt Collecting for Beginners from Harvesting Windstones to learn Skinning.'},
    {profession='Fishing',skill='1-75',zone='Zephras Isle',guide='fishing-and-cooking-leveling-guide',
        tip="Fish in the water by the trainers in Valanaar or Shen'dar Village. Bring a Fishing Pole and Shiny Baubles."},
}
local function setView(self,view,notesInstance)
    local data=self:Data()
    if (data.view~=view or self.notesInstance~=notesInstance) and self.window then
        self.window.search:SetText(''); self.window.input:SetText('')
    end
    data.view=view
    self.notesInstance=view=='Run Notes' and notesInstance or nil
    self.selected=nil; self.page=1
end
function W:NextView()
    for i,v in ipairs(self.views) do
        if v==self:Data().view then setView(self,self.views[i%#self.views+1]); break end
    end
    self:Refresh()
end
function W:Choose(view,notesInstance)
    setView(self,view,notesInstance)
    self:ShowWindow()
end
local create=W.CreateWindow
function W:CreateWindow()
    local f=create(self); if f.section then return f end
    f.section=H:Button(f,'',16,-54,628,function()
        local menu=f.categoryMenu
        if menu:IsShown() then menu:Hide(); return end
        local page=1
        for i,view in ipairs(W.views) do if view==W:Data().view then page=math.ceil(i/12); break end end
        menu:ShowPage(page); menu:Show()
    end)
    f.categoryMenu=CreateFrame('Frame',nil,f,'BackdropTemplate'); H:Skin(f.categoryMenu); f.categoryMenu:SetBackdropColor(.02,.03,.04,1); f.categoryMenu:SetSize(628,350); f.categoryMenu:SetPoint('TOPLEFT',f.section,'BOTTOMLEFT',-42,-4); f.categoryMenu:SetFrameLevel(f:GetFrameLevel()+80); f.categoryMenu:EnableMouse(true); f.categoryMenu.buttons={}
    for _,view in ipairs(self.views) do local chosen=view; local button=H:Button(f.categoryMenu,chosen,0,0,298,function() f.categoryMenu:Hide(); W:Choose(chosen) end); f.categoryMenu.buttons[#f.categoryMenu.buttons+1]=button end
    local menu=f.categoryMenu
    menu.previous=H:Button(menu,'Previous tools',12,0,180,function() menu:ShowPage(menu.page-1) end)
    menu.next=H:Button(menu,'Next tools',436,0,180,function() menu:ShowPage(menu.page+1) end)
    menu.pageLabel=H:Label(menu,'',214,0,200)
    function menu:ShowPage(page)
        local pages=math.ceil(#self.buttons/12)
        self.page=math.max(1,math.min(pages,page))
        local first=(self.page-1)*12+1
        local last=math.min(first+11,#self.buttons)
        local height=0
        for i,button in ipairs(self.buttons) do
            local visible=i>=first and i<=last
            button:SetShown(visible)
            if visible then height=math.max(height,H:FitButton(button,2)+6) end
        end
        for i=first,last do
            local button=self.buttons[i]
            local slot=i-first
            button:ClearAllPoints(); button:SetPoint('TOPLEFT',12+slot%2*312,-12-math.floor(slot/2)*height)
        end
        local y=12+math.ceil((last-first+1)/2)*height
        self.previous:ClearAllPoints(); self.previous:SetPoint('TOPLEFT',12,-y)
        self.next:ClearAllPoints(); self.next:SetPoint('TOPLEFT',436,-y)
        self.pageLabel:ClearAllPoints(); self.pageLabel:SetPoint('TOPLEFT',214,-y-6)
        self.pageLabel:SetText('Tools '..self.page..' / '..pages)
        self.previous:SetEnabled(self.page>1); self.next:SetEnabled(self.page<pages)
        self:SetHeight(y+math.max(H:FitButton(self.previous,2),H:FitButton(self.next,2))+12)
    end
    f.categoryMenu:Hide(); f:HookScript('OnHide',function() f.categoryMenu:Hide() end)
    f:HookScript('OnHide',function() if W.training then W:StopTraining('Preview closed.') end end)
    f.previousSection=H:Button(f,'<',16,-54,34,function()
        for i,v in ipairs(W.views) do
            if v==W:Data().view then setView(W,W.views[(i-2)%#W.views+1]); break end
        end
        W:Refresh()
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
function E:Form(title,fields,save,actionLabel)
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
    f.heading:SetText(title); f.save:SetText(actionLabel or FS.Text.apply); f.status:SetText('')
    local y=math.max(62,20+H:TextHeight(f.heading,672,3)+18)
    for i=1,f.fieldCount do
        local spec=fields[i]
        if not f.labels[i] then f.labels[i]=H:Label(f,'',24,0,672); f.edits[i]=T:Edit(f,24,0,672) end
        local label,edit=f.labels[i],f.edits[i]; label:SetText(spec.label); label:ClearAllPoints(); label:SetPoint('TOPLEFT',24,-y); label:Show(); y=y+H:TextHeight(label,672,2)+8
        FS:ApplyFont(edit); local _,size=edit:GetFont(); edit:SetHeight(math.max(30,(size or 14)+12)); edit:ClearAllPoints(); edit:SetPoint('TOPLEFT',24,-y); edit:SetMaxLetters(spec.limit or 256); edit:SetText(tostring(spec.value or '')); edit:Show(); y=y+edit:GetHeight()+18
    end
    for i=f.fieldCount+1,#f.edits do f.edits[i]:Hide(); f.labels[i]:Hide() end
    f.status:ClearAllPoints(); f.status:SetPoint('TOPLEFT',24,-y); f.status:SetHeight(44); y=y+44
    local height=0; for i,button in ipairs({f.save,f.cancel}) do button:ClearAllPoints(); button:SetPoint('TOPLEFT',i==1 and 24 or 376,-y); height=math.max(height,H:FitButton(button,2)) end
    f:SetHeight(y+height+24); f:SetScale(math.min(1,(UIParent:GetWidth()-32)/720,(UIParent:GetHeight()-32)/f:GetHeight()))
    FS:CloseOtherWindows(f); f:Show(); return f
end
local function settingLabel(key)
    local label=key:gsub('(%l)(%u)','%1 %2')
    return (label:gsub('^%l',string.upper))
end

function E:TextDialog(title,text,readOnly,validate,apply,onReturn,reviewProfile)
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
        function f:UpdateReview()
            local review=self.reviewProfile and self.candidate
            self.reviewText:SetShown(not not review)
            for _,button in ipairs(self.reviewButtons) do button:SetShown(not not review) end
            if not review then return end
            local section=review.sections[self.sectionIndex]
            local count=0
            for _ in pairs(review.selected) do count=count+1 end
            local labels={}
            for i=1,math.min(6,#section.changes) do labels[i]=settingLabel(section.changes[i]) end
            local fields=table.concat(labels,', ')
            if #section.changes>6 then fields=fields..(' and %d more'):format(#section.changes-6) end
            self.reviewText:SetText(('%d / %d  |  %s  |  %d selected\n%s'):format(
                self.sectionIndex,#review.sections,settingLabel(section.key),count,fields~='' and fields or 'Value changed'))
            self.reviewButtons[1]:SetEnabled(self.sectionIndex>1)
            self.reviewButtons[2]:SetText(review.selected[section.key] and 'Included (click to remove)' or 'Include section')
            self.reviewButtons[3]:SetEnabled(self.sectionIndex<#review.sections)
            self.apply:SetEnabled(count>0)
        end
        f.reviewText=H:Label(f,'',24,-480,712)
        f.reviewButtons={
            H:Button(f,'Previous section',24,-500,210,function() f.sectionIndex=f.sectionIndex-1; f:UpdateReview(); f:Layout() end),
            H:Button(f,'Include section',274,-500,210,function()
                local review=f.candidate
                local key=review.sections[f.sectionIndex].key
                review.selected[key]=not review.selected[key] or nil
                f:UpdateReview(); f:Layout()
            end),
            H:Button(f,'Next section',524,-500,210,function() f.sectionIndex=f.sectionIndex+1; f:UpdateReview(); f:Layout() end),
        }
        f.preview=H:Button(f,FS.Text.preview,24,-520,210,function()
            if f.readOnly then edit:SetFocus(); edit:HighlightText(); return end
            local data,message=f.validate(edit:GetText()); f.candidate=data; f.sectionIndex=1
            f.status:SetText(message or 'Invalid import.'); f.apply:SetEnabled(data~=nil); f:UpdateReview(); f:Layout()
        end)
        f.apply=H:Button(f,FS.Text.apply,274,-520,210,function()
            if not E:Allowed() then f.status:SetText(FS.Text.leaveCombat); return end
            local returnAction=f.returnAction
            if not f.candidate or not f.applyAction then return end
            local applied,message=f.applyAction(f.candidate)
            if applied then f:Hide(); if returnAction then returnAction() else W:ShowWindow() end
            elseif message then f.status:SetText(message); f:Layout() end
        end)
        f.cancel=H:Button(f,FS.Text.cancel,524,-520,210,function() local returnAction=f.returnAction; f:Hide(); if returnAction then returnAction() else W:ShowWindow() end end)
        edit:SetScript('OnTextChanged',function()
            if f.clearingText then return end
            f:ResizeText()
            if not f.readOnly then
                f.candidate=nil; f.apply:SetEnabled(false)
                if f.reviewProfile then f.status:SetText('Paste a ForeverSuite export, then click Preview.'); f:UpdateReview(); f:Layout() end
            end
        end)
        function f:Layout()
            self.scrollTop=math.max(60,20+H:TextHeight(self.heading,712,2)+12); self.scroll:ClearAllPoints(); self.scroll:SetPoint('TOPLEFT',24,-self.scrollTop)
            self.status:ClearAllPoints(); self.status:SetPoint('TOPLEFT',24,-self.scrollTop-384)
            local y=self.scrollTop+384+H:TextHeight(self.status,712,4)+16; local height=0
            if self.reviewProfile and self.candidate then
                self.reviewText:ClearAllPoints(); self.reviewText:SetPoint('TOPLEFT',24,-y)
                y=y+H:TextHeight(self.reviewText,712,4)+10
                for i,button in ipairs(self.reviewButtons) do
                    button:ClearAllPoints(); button:SetPoint('TOPLEFT',({24,274,524})[i],-y)
                    height=math.max(height,H:FitButton(button,2))
                end
                y=y+height+14; height=0
            end
            for i,button in ipairs({self.preview,self.apply,self.cancel}) do button:ClearAllPoints(); button:SetPoint('TOPLEFT',({24,274,524})[i],-y); height=math.max(height,H:FitButton(button,2)) end
            self:SetHeight(y+height+24); self:SetScale(math.min(1,(UIParent:GetWidth()-32)/760,(UIParent:GetHeight()-32)/self:GetHeight()))
        end
        f:SetScript('OnHide',function()
            f.candidate=nil; f.validate=nil; f.applyAction=nil; f.returnAction=nil
            f.clearingText=true
            f.edit:SetText('')
            f.clearingText=nil
        end)
        UISpecialFrames[#UISpecialFrames+1]='ForeverSuiteTextDialog'
    end
    f:Hide(); H:Skin(f); f.fsFontModule=W.activeOwner or 'Workbench'; FS:FontTree(f); f.readOnly=readOnly; f.validate=validate; f.applyAction=apply; f.returnAction=onReturn; f.candidate=nil; f.reviewProfile=reviewProfile
    f:SetBackdropBorderColor(unpack(FS.moduleCardColors[W.activeOwner] or {.12,.72,.86})); f.heading:SetText(title); f.edit:SetText(text or '')
    f.status:SetText(readOnly and 'Select all, then Ctrl+C to copy. This window does not send messages.' or 'Paste a ForeverSuite export, then Preview before applying.')
    f.preview:SetText(readOnly and 'Select all' or FS.Text.preview); f.apply:SetShown(not readOnly); f.apply:SetEnabled(false); f.cancel:SetText(readOnly and FS.Text.close or FS.Text.cancel)
    f:ResizeText(); f:UpdateReview(); f:Layout(); if f.scroll.SetVerticalScroll then f.scroll:SetVerticalScroll(0) end
    FS:CloseOtherWindows(f); f:Show(); return f
end
local function row(id,text,kind,data) local r=data or {}; r.id=id; r.text=text; r.kind=kind; return r end
function W:ReadTrainer()
    local frame=ClassTrainerFrame
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or not frame:IsShown() then
        return nil,'Open a class, pet or profession trainer to preview available training.'
    end
    local count=T:Call(GetNumTrainerServices)
    if not T:Number(count) or type(GetTrainerServiceInfo)~='function' then
        return nil,'This trainer does not expose a readable service list.'
    end
    local filter=T:Call(GetTrainerServiceTypeFilter,'available')
    if filter==false or filter==0 then return nil,'Enable Available in the game trainer filters, then refresh the preview.' end
    local data={available={},learned={},total=0,unknown=0,truncated=count>1000}
    for index=1,math.min(1000,count) do
        local name,second,third,_,serviceRank=T:Call(GetTrainerServiceInfo,index)
        local forever=type(third)=='number' or (third==nil and (second=='available' or second=='used'))
        local category=forever and second or third
        local rank=T:Text(forever and serviceRank or second)
        local key=T:Text(name)..'\031'..rank
        if T:Text(name)~='' and category=='available' then
            local cost,talent,profession=T:Call(GetTrainerServiceCost,index)
            local price='Cost unavailable'
            if T:Number(cost) and cost>=0 then
                data.total=data.total+cost
                price=cost==0 and 'Free' or FS.modules.Vendor:Money(cost)
                if T:Number(talent) and talent>0 then price=price..' + '..talent..' talent points' end
                if T:Number(profession) and profession>0 then price=price..' + '..profession..' profession slots' end
            else data.unknown=data.unknown+1 end
            local coinsOnly=(talent==nil or talent==0) and (profession==nil or profession==0)
            data.available[#data.available+1]={
                key=key,index=index,cost=cost,coinsOnly=coinsOnly and T:Number(cost) and cost>=0,
                text=name..(rank~='' and ' ('..rank..')' or '')..' | '..price,
            }
        elseif T:Text(name)~='' and category=='used' then
            data.learned[key]=true
        end
    end
    return data
end
function W:TrainerPreview(rows)
    local data,message=self:ReadTrainer()
    if not data then return message end
    for _,entry in ipairs(data.available) do rows[#rows+1]=row(entry.index,entry.text,'trainer') end
    if #rows==0 then return 'No available training is visible in the current trainer list.' end
    return #rows..' available in the current trainer list. '..((data.unknown>0 or data.truncated) and 'Known coin subtotal: ' or 'Total coin cost: ')..
        FS.modules.Vendor:Money(data.total)..'. Train All covers skills with known coin costs only.'
end
local function trainingPlan(data)
    if not data or data.truncated then return end
    local entries,seen,total={}, {}, 0
    for _,entry in ipairs(data.available) do
        if seen[entry.key] or data.learned[entry.key] then return end
        seen[entry.key]=true
        if entry.coinsOnly then
            entries[#entries+1]=entry
            total=total+entry.cost
        end
    end
    return entries,total
end
function W:StopTraining(message)
    local batch=self.training
    if not batch then return end
    self.training=nil
    FS:Print('Training: '..batch.completed..' confirmed. '..message)
    if self.window and self.window:IsShown() then self:Refresh() end
end
function W:TrainNext(batch)
    if self.training~=batch then return end
    if not E:Allowed() or not self.window:IsShown() or self:Data().view~='Trainer preview' then
        self:StopTraining('Training interrupted.'); return
    end
    local approved=batch.entries[batch.completed+1]
    if not approved then self:StopTraining('Finished.'); return end
    local data=self:ReadTrainer()
    local balance=T:Call(GetMoney)
    if not data or data.truncated or not T:Number(balance) then self:StopTraining('Trainer or funds unavailable.'); return end
    local current
    for _,entry in ipairs(data.available) do
        if entry.key==approved.key then
            if current then self:StopTraining('The trainer list changed.'); return end
            current=entry
        end
    end
    if not current or not current.coinsOnly or current.cost~=approved.cost or balance<approved.cost then
        self:StopTraining('The trainer list, prices or available funds changed.'); return
    end
    local ok,result=pcall(BuyTrainerService,current.index)
    if not ok or result==false then self:StopTraining('The game rejected a training request.'); return end
    local attempts=0
    local function verify()
        if self.training~=batch then return end
        local after=self:ReadTrainer()
        if not E:Allowed() or not after then self:StopTraining('Training interrupted.'); return end
        local stillAvailable=false
        for _,entry in ipairs(after.available) do if entry.key==approved.key then stillAvailable=true; break end end
        local money=T:Call(GetMoney)
        local paid=approved.cost>0 and T:Number(money) and balance-money==approved.cost
        if not stillAvailable and (after.learned[approved.key] or paid) then
            batch.completed=batch.completed+1
            self:TrainNext(batch)
        else
            attempts=attempts+1
            if attempts<20 then C_Timer.After(.15,verify) else self:StopTraining('The last request could not be confirmed. Check the trainer list.'); end
        end
    end
    C_Timer.After(.15,verify)
end
function W:ConfirmTraining()
    if self.training or type(BuyTrainerService)~='function' then self.status='Bulk training is unavailable right now.'; return end
    local entries,total=trainingPlan(self:ReadTrainer())
    if not entries or #entries==0 then self.status='No unambiguous training with a known coin cost is available.'; return end
    local revision=self.trainerRevision
    E:Form(('Train %d skills for %s?'):format(#entries,FS.modules.Vendor:Money(total)),{},function()
        local current=trainingPlan(self:ReadTrainer())
        if self.training or self.trainerRevision~=revision or not current or #current~=#entries then
            return false,'The trainer list changed. Refresh the preview and try again.'
        end
        for index,entry in ipairs(current) do
            if entry.key~=entries[index].key or entry.cost~=entries[index].cost then
                return false,'The trainer list changed. Refresh the preview and try again.'
            end
        end
        local balance=T:Call(GetMoney)
        if not T:Number(balance) or balance<total then return false,'You do not have enough readable coin for this batch.' end
        local batch={entries=entries,completed=0}
        self.training=batch
        C_Timer.After(0,function() self:TrainNext(batch) end)
        return true
    end,'Train skills')
end
function W:WishlistForm(instance,boss,item)
    return E:Form('Add loot goal',{
        {label='Dungeon or raid',value=instance or '',limit=80},
        {label='Boss or loot source (optional)',value=boss or '',limit=80},
        {label='Item ID',value=item or '',limit=9},
    },function(name,source,id) return E:AddWishlistItem(name,source,id) end,'Add to Wishlist')
end
function W:FocusWishlistGoal(key)
    self:Choose('Gear Wishlist')
    for i,entry in ipairs(self.rows) do
        if entry.id==key then
            self.selected=entry
            self.page=math.ceil(i/#self.window.cells)
            self:Render()
            break
        end
    end
end
local function recordedAt(stamp)
    return T:Number(stamp) and stamp>0 and T:Call(date,'%d %b %Y %H:%M',stamp) or 'Date unknown'
end
function W:CharacterRecordText(record)
    local lines={}
    local gear=record.gear
    if type(gear)=='table' and type(gear.items)=='table' then
        lines[#lines+1]='Gear | '..recordedAt(gear.time)
        if T:Number(gear.level) then lines[#lines+1]=('Average item level: %.1f'):format(gear.level) end
        if T:Number(gear.lowest) then lines[#lines+1]=('Lowest durability: %.0f%%'):format(gear.lowest) end
        for _,item in ipairs(gear.items) do
            if type(item)=='table' then
                local name=T:Text(item.name)
                if name=='' then name=T:Number(item.id) and ('Item '..item.id) or 'Item details unavailable' end
                local level=T:Number(item.level) and (' | Item level '..item.level) or ''
                lines[#lines+1]=T:Text(item.slot)..': '..name..level
            end
        end
    else lines[#lines+1]='Gear | No readable record' end
    lines[#lines+1]=''
    local professions=record.professions
    if type(professions)=='table' and type(professions.items)=='table' then
        lines[#lines+1]='Professions | '..recordedAt(professions.time)
        if #professions.items==0 then lines[#lines+1]='No learned professions were reported.' end
        for _,profession in ipairs(professions.items) do
            if type(profession)=='table' and T:Text(profession.name)~='' and T:Number(profession.skill) and T:Number(profession.maximum) then
                lines[#lines+1]=profession.name..': '..profession.skill..' / '..profession.maximum
            end
        end
    else lines[#lines+1]='Professions | No readable record' end
    lines[#lines+1]=''
    if type(record.counts)=='table' then
        lines[#lines+1]='Bags | '..recordedAt(record.bagTime or record.time)
        local items={}
        for id,count in pairs(record.counts) do
            if T:Number(id) and T:Number(count) then
                local name=T:Text(T:Call(C_Item and C_Item.GetItemInfo,id))
                items[#items+1]=(name~='' and name or 'Item '..id)..' x'..count
            end
        end
        table.sort(items)
        if #items==0 then lines[#lines+1]='Bags were empty when recorded.' end
        for _,item in ipairs(items) do lines[#lines+1]=item end
    else lines[#lines+1]='Bags | No readable record' end
    return table.concat(lines,'\n')
end
function W:NextStepRows()
    local d=E:Data()
    local rows={}
    local function add(order,id,text,data)
        data.order=order
        rows[#rows+1]=row(id,text,'next-step',data)
    end
    local auction,professions=FS.modules.AuctionHouse,FS.modules.Professions
    if professions.materials and professions.planRecipe then
        local name=T:Text(professions.planRecipe.name)
        add(1,'craft',name~='' and ('[Crafting] Review materials for '..name) or '[Crafting] Review recipe materials',{module='Professions'})
    end
    for id,count in pairs(auction:Data().shopping) do
        if T:Number(id) and id>0 and T:Number(count) and count>0 then
            local _,missing=auction:ShoppingQuantity(id,count)
            if missing==nil or missing>0 then
                local name,link=T:Call(C_Item and C_Item.GetItemInfo,id)
                add(2,'shopping:'..id,'[Shopping] '..(name or 'Item '..id)..(missing and (' | Need '..missing) or ' | Stock unknown'),
                    {module='AuctionHouse',item=id,link=link})
            end
        end
    end
    for key,goal in pairs(d.wishlist) do
        if not goal.acquired then
            local name,link=T:Call(C_Item and C_Item.GetItemInfo,goal.item)
            add(3,'wanted:'..key,'[Gear] '..(name or 'Item '..goal.item)..' | '..goal.instance..
                (goal.boss~='' and (' / '..goal.boss) or ''),{view='Gear Wishlist',goalKey=key,goal=goal,link=link})
        end
    end
    local activities={}
    for name in pairs(d.preparation) do activities[name]=true end
    for name in pairs(d.checklists) do activities[name]=true end
    for name in pairs(activities) do
        add(4,'prepare:'..name,'[Preparation] '..name,{view='Dungeon preparation',activity=name})
    end
    if #d.waypointQueue>0 then
        add(5,'queue','[Navigation] '..#d.waypointQueue..' stops left | '..d.waypointQueue[1].name,{view='Waypoint queue'})
    elseif next(d.routes) then
        add(5,'routes','[Navigation] Choose a saved route',{view='Route Library'})
    end
    if next(E:StockRecords()) then
        add(6,'alts','[Character stock] Review bags, gear and professions',{view='Character stock'})
    end
    table.sort(rows,function(a,b)
        if a.order~=b.order then return a.order<b.order end
        if a.text~=b.text then return a.text<b.text end
        return a.id<b.id
    end)
    return rows
end
function W:Build()
    E:Normalize(); local d=E:Data(); local view=self:Data().view; local rows={}; local labels={'Open','Change','Favorite'}; local owner='Core'
    local valid=false; for _,v in ipairs(self.views) do if v==view then valid=true end end; if not valid then view='Settings'; self:Data().view=view end
    local entered=self.lastView~=view; self.lastView=view
    if view=='Settings' or view=='Favorites' then
        for _,r in ipairs(E:SettingsIndex()) do if view=='Settings' or d.settingFavorites[r.id] then rows[#rows+1]=r end end
        self.status='Search labels or module names. Open goes to the module; Change cycles a value; Favorite pins it.'
    elseif view=='Profiles' then
        owner='Profiles'; labels={'Open / compare','Use / restore','Assign login'}
        rows={row('export','Export active profile (private notes and chat history excluded)','export'),row('import','Import profile: enter a name below, then open the paste window','import'),row('assignment','Login profile: '..(FS.db.profiles.characters[E:CharacterKey() or ''] or 'Not assigned')..' (Assign login clears this entry)','assignment')}
        for _,name in ipairs(FS.modules.Profiles:Names()) do rows[#rows+1]=row('profile:'..name,'Profile: '..name,'profile',{name=name}) end
        for i,b in ipairs(FS.db.profiles.backups) do rows[#rows+1]=row('backup:'..i,'Backup: '..b.name..' | '..b.reason,'backup',{index=i}) end
        self.status='Name the resulting profile below. Preview compares the export with your active profile before you choose what to apply.'
    elseif view=='Next steps' then
        labels={'Open selected','Mark gear acquired','Refresh','Find gear source'}
        rows=self:NextStepRows()
        self.status=#rows>0 and 'Open an entry to continue. The list updates when you complete goals or change your plans.'
            or 'No open goals. Add items in Gear Wishlist, start a craft plan, or save a route.'
    elseif view=='Run Notes' then
        owner='Map'; labels={'Add note','Edit note','Delete note','Dungeon Journal'}
        local scope=self.notesInstance and self.notesInstance.name
        local filter=scope and scope:lower()
        for key,note in pairs(d.runNotes) do
            if not filter or note.instance:lower()==filter then
                local caption=(filter and '' or (note.instance..' / '))..note.boss..' | '..note.note
                rows[#rows+1]=row(key,caption,'run-note',{note=note})
            end
        end
        table.sort(rows,function(a,b) return a.id<b.id end)
        if scope then
            labels[4]='Back to Journal'
            self.status=scope..(#rows>0 and ' | Private boss notes' or ' | No notes yet. Use Add note to write a boss reminder.')
        else
            self.status='Private notes can appear when the game reports the matching boss encounter. Configure the Run note popup in Alerts.'
        end
    elseif view=='Gear Wishlist' then
        owner='Gear'; labels={'Add item','Toggle acquired','Remove goal','Dungeon Journal'}
        for key,goal in pairs(d.wishlist) do
            local name,link=T:Call(C_Item and C_Item.GetItemInfo,goal.item)
            local source=goal.instance..(goal.boss~='' and ' / '..goal.boss or '')
            rows[#rows+1]=row(key,'['..(goal.acquired and 'Acquired' or 'Wanted')..'] '..(name or 'Item '..goal.item)..' | '..source,
                'wishlist',{goal=goal,link=link})
        end
        table.sort(rows,function(a,b)
            if a.goal.instance~=b.goal.instance then return a.goal.instance<b.goal.instance end
            if a.goal.acquired~=b.goal.acquired then return not a.goal.acquired end
            if a.goal.boss~=b.goal.boss then return a.goal.boss<b.goal.boss end
            return a.id<b.id
        end)
        self.status='Matching boss loot is marked acquired when the game identifies you as the recipient. Toggle acquired also works manually.'
    elseif view=='Dungeon & Raid Journal' then
        owner='Map'
        local instance=self.journalInstance
        if instance then
            labels={'Boss details','Preparation','Back to instances','Add loot goal'}
            if self.selected and self.selected.kind=='journal-notes' then labels[1]='Open notes' end
            rows=E:JournalEncounters(instance)
            local hasBosses=#rows>0
            local loot={}
            for _,boss in ipairs(rows) do
                local ids={}
                for id in pairs(boss.items) do ids[#ids+1]=id end
                table.sort(ids)
                for _,id in ipairs(ids) do
                    local name,link=T:Call(C_Item and C_Item.GetItemInfo,id)
                    local goal,key=E:WishlistGoalForDrop(instance.name,boss.name,id)
                    local state=goal and (goal.acquired and 'Acquired' or 'Wanted') or 'Observed'
                    local rowID='loot:'..boss.id..':'..id
                    local detail=goal and goal.boss=='' and 'Wishlist goal covers any boss in this instance.' or nil
                    loot[#loot+1]=row(rowID,'['..state..'] '..(name or 'Item '..id)..' | '..boss.name,
                        'journal-loot',{item=id,boss=boss.name,link=link,goalKey=key,detailLine=detail})
                    if key and self.selected and self.selected.id==rowID then labels[4]='View goal' end
                end
            end
            for _,drop in ipairs(loot) do rows[#rows+1]=drop end
            rows[#rows+1]=row('run-notes','Open Run Notes for this instance','journal-notes')
            self.status=instance.name..' | '..instance.source..
                (hasBosses and ' | Select a boss for details.' or ' | Boss data is unavailable for this instance.')..
                (#loot>0 and ' Listed loot was observed in game.' or ' No observed loot for this instance yet.')
        else
            labels={'Open instance','Preparation','Filter: '..(self.journalFilter or 'All'),'Wishlist'}
            for _,entry in ipairs(E:JournalInstances()) do
                if not self.journalFilter or self.journalFilter=='All' or entry.kind==self.journalFilter then
                    local levels=entry.minimum and entry.maximum and (' | Lv '..entry.minimum..'-'..entry.maximum) or ''
                    rows[#rows+1]=row(entry.id,'['..entry.kind..'] '..entry.name..levels,'journal-instance',{instance=entry})
                end
            end
            self.status=#rows>0 and 'Browse instances reported by the game journal or Group Finder. Search by instance name.'
                or 'The client returned no instances for this filter.'
        end
    elseif view=='Dungeon preparation' then
        owner='Gear'
        local activity=self.prepActivity
        if activity and (d.preparation[activity] or d.checklists[activity]) then
            labels={'Refresh','Edit targets','Add / edit supply','Activities'}
            rows=E:PreparationRows(activity)
            local review=0
            for _,entry in ipairs(rows) do if entry.status=='Check' or entry.status=='Unknown' then review=review+1 end end
            self.status=activity..' | '..review..' checks need attention. Supplies count carried items.'
        else
            self.prepActivity=nil
            labels={'Open / create','','',''}
            local names,seen={},{}
            for name in pairs(d.preparation) do names[#names+1]=name; seen[name]=true end
            for name in pairs(d.checklists) do if not seen[name] then names[#names+1]=name end end
            table.sort(names)
            for _,name in ipairs(names) do rows[#rows+1]=row(name,name,'prep',{name=name}) end
            self.status='Select an activity or enter a new dungeon or raid name below.'
        end
    elseif view=='Trainer preview' then
        owner='Professions'; labels={'Refresh preview','Train All',self.training and 'Stop' or ''}
        self.status=self:TrainerPreview(rows)
    elseif view=='Character stock' then
        owner='Bags'; labels={'Record character','Show record','Forget record'}
        for key,record in pairs(E:StockRecords()) do
            if type(key)=='string' and type(record)=='table' and T:Number(record.time) then
                rows[#rows+1]=row(key,key..' | Last updated '..recordedAt(record.time),'stock',{record=record})
            end
        end
        table.sort(rows,function(a,b) return a.id<b.id end)
        self.status='Record each character to see its bags, gear and professions. Each section shows its own date. Bag counts exclude the bank.'
    elseif view=='Layout presets' then
        owner='Profiles'; labels={'Save current','Use preset','Delete preset'}
        local names={}
        for name in pairs(d.contexts) do names[#names+1]=name end
        table.sort(names)
        for _,name in ipairs(names) do rows[#rows+1]=row(name,name,'context') end
        self.status='Name a preset such as Leveling or Farming. It stores frame positions, quest tracker and coordinate visibility, and alert sounds.'
    elseif view=='Accessibility' then
        labels={'Apply preset','Next palette','Undo'}
        rows={row('readable','Readable text: size 18 and thin outline','preset',{name='Readable text'}),row('compact','Compact screen: size 12, unit frames at 85%','preset',{name='Compact screen'}),row('palette','Palette: '..d.palette..' | labels remain visible','palette')}
        self.status='Preset changes affect suite text/unit frames, never native action bar geometry. Undo restores the previous settings.'
    elseif view=='Alerts' then
        labels={'Next sound','Next channel','Test sound','Display options'}
        for _,name in ipairs(E.alertCategories) do
            local a=E:AlertOptions(name)
            rows[#rows+1]=row(name,name..' | '..a.sound..' | '..a.channel..' | Popup '..(a.popup and 'On' or 'Off')..' | History '..(a.history and 'On' or 'Off'),'alert',{name=name})
        end
        self.status='Select a notification type to choose its sound, popup and history settings. Repeated notifications have a 10-second cooldown.'
    elseif view=='Rare sightings' then
        local options=d.discovery
        labels={options.enabled and 'Disable tracking' or 'Enable tracking',options.elites and 'Elites: On' or 'Elites: Off',
            'View details',options.portrait and 'Portrait: On' or 'Portrait: Off'}
        for i,sighting in ipairs(E.sightings) do
            rows[#rows+1]=row(i,sighting.kind..': '..sighting.name..' | '..sighting.source,'sighting',{sighting=sighting})
        end
        self.status='Detects NPCs the game exposes through nameplates, target or mouseover. Use Alerts to choose sounds, popups and history.'
    elseif view=='Notification Center' then
        labels={'Alert settings','Clear history','',''}
        for i,notice in ipairs(E.notifications) do
            local stamp=T:Call(date,'%H:%M:%S',notice.time) or ''
            local message=notice.message~='' and (' | '..notice.message) or ''
            rows[#rows+1]=row(i,stamp..' | '..notice.category..message,'notification')
        end
        self.status='Up to 50 notifications from this session. Use search to filter by type.'
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
    elseif view=='Gathering runs' then
        owner='Map'; labels={'Start run','Finish recording','View report','Route Library'}
        local names={}
        for name in pairs(d.routes) do names[#names+1]=name end
        table.sort(names)
        for _,name in ipairs(names) do rows[#rows+1]=row('route:'..name,'Start route: '..name,'gathering-route',{name=name}) end
        for i,run in ipairs(d.gatheringRuns) do
            if type(run)=='table' and type(run.route)=='string' and T:Number(run.duration) and T:Number(run.total) then
                rows[#rows+1]=row('run:'..i,('%s | %dm %02ds | %d looted'):format(run.route,math.floor(run.duration/60),run.duration%60,run.total),'gathering-history',{run=run,index=i})
            end
        end
        local active=E.gathering
        self.status=active and ('Recording '..active.route..'. Finish recording saves the run and keeps navigation active.')
            or 'Select a saved route and start a run. Records your own item loot, including drops.'
    elseif view=='Profession recommendations' then
        owner='Map'; labels={'Read guide','Route Library'}
        for i,entry in ipairs(professionRecommendations) do
            local title=entry.profession..' '..entry.skill..' | '..entry.zone
            rows[#rows+1]=row('recommendation:'..i,title,'profession-recommendation',{
                recommendation=entry,searchText=title..' '..entry.tip,detailLine=entry.tip,
            })
        end
        self.status='Search by profession, zone or material. Read guide shows the gathering area and a link to the source. These guides describe areas and routes without in-game waypoints.'
    elseif view=='Route Library' then
        owner='Map'; labels={'Save queue','Load route','Share / import','Manage route'}
        if self.selected and self.selected.kind=='route-recommendations' then labels[2]='Browse guides' end
        local names={}
        for name in pairs(d.routes) do names[#names+1]=name end
        table.sort(names)
        rows[1]=row('import','Import a route code','route-import')
        rows[2]=row('gather','Open gathering runs','route-gathering')
        rows[3]=row('import-waypoints','Import /way coordinates','route-waypoints')
        rows[4]=row('recommendations','Browse profession recommendations','route-recommendations')
        local mapNames={}
        for _,name in ipairs(names) do
            local stops=d.routes[name]
            local zones,seen,terms={},{},{}
            for _,stop in ipairs(stops) do
                local map=stop.map
                if not mapNames[map] then
                    local info=T:Call(C_Map and C_Map.GetMapInfo,map)
                    local zone=type(info)=='table' and T:Text(info.name) or ''
                    mapNames[map]=zone~='' and zone or ('Map '..map)
                end
                local zone=mapNames[map]
                if not seen[zone] then zones[#zones+1]=zone; seen[zone]=true end
                terms[#terms+1]=stop.name
            end
            local caption=name..' | '..#stops..' stops | '..(zones[1] or 'Unknown zone')
            if #zones>1 then caption=caption..' +'..(#zones-1)..' more' end
            local details=d.routeDetails[name]
            local tags=E:RouteTags(details)
            if tags~='' then caption=caption..' | '..tags end
            terms[#terms+1]=table.concat(zones,' ')
            if details then terms[#terms+1]=details.source end
            terms[#terms+1]=caption
            local source=details and details.source~='' and ('Source: '..details.source) or nil
            rows[#rows+1]=row('route:'..name,caption,'route',{name=name,searchText=table.concat(terms,' '),detailLine=source})
        end
        self.status='Search by route, zone, stop or profession. Use Manage route to set a profession, skill range and source. Loading a route replaces the current queue.'
    elseif view=='Waypoint queue' then
        owner='Map'; labels={'Start / add','Move up','Remove / stop','Route Library'}
        for i,p in ipairs(d.waypointQueue) do rows[#rows+1]=row('queue:'..i,i..'. '..p.name,'queue',{index=i}) end
        for i,p in ipairs(FS.db.map.pins) do rows[#rows+1]=row('pin:'..i,'Saved pin: '..p.name,'pin',{index=i}) end
        self.status='Select a saved pin and Start / add to append it; select a queue entry to start. Arrival advances to the next pin. Direct guidance, not terrain routing.'
    elseif view=='Leveling session' then
        owner='QoL'; labels={'Reset session','Open Leveling','Refresh'}
        local gained,rate,eta=E:XPStats(); rows={row('gained','Session XP gained: '..gained),row('rate',rate and ('XP per hour: '..math.floor(rate)) or 'XP per hour: waiting for observed gains (10 seconds minimum)'),row('eta',eta and ('Estimated minutes to level: '..math.ceil(eta/60)) or 'Time to level: insufficient readable XP data')}
        self.status='Rates use observed XP gains and session time. Reset when starting a new leveling session.'
    else
        labels={'Support report','Clear audit','Undo'}
        for i,r in ipairs(E.audit) do rows[#rows+1]=row(i,r.text,'audit') end
        for _,capability in ipairs(FS:ClientCapabilities()) do rows[#rows+1]=row('API:'..capability.label,capability.label..': '..(capability.available and 'Available' or FS.Text.unavailable),'capability') end
        for _,definition in ipairs(FS.NativeWindows.definitions) do if not _G[definition[1]] then rows[#rows+1]=row(definition[1],definition[4]..': window not loaded; game fallback remains available','missing') end end
        self.status='Preview a support report for troubleshooting. The snapshots below show the last 20 layout events.'
    end
    self.rows=rows; self.activeOwner=owner
    if self.window then
        self.window.section:SetText('Tools: '..view..'  >')
        for i,b in ipairs(self.window.actionButtons) do local label=labels[i] or ''; b:SetText(label); b:SetShown(label~='') end
        self.window.input:SetShown(view=='Profiles' or view=='Layout presets' or view=='Route Library' or (view=='Dungeon preparation' and not self.prepActivity) or view=='NPC rules' or view=='Important casts' or view=='Chat keywords' or view=='Guild notes')
        self.window.input:SetMaxLetters(({Profiles=32,['Layout presets']=32,['Route Library']=40,['Dungeon preparation']=32,['NPC rules']=10,['Important casts']=10,['Chat keywords']=64,['Guild notes']=256})[view] or 256)
        local color=FS.moduleCardColors[owner] or {.12,.72,.86}; self.window:SetBackdropBorderColor(unpack(color))
    end
end
function W:OnSelect(selected)
    if not selected or not self.window then return end
    if selected.kind=='guild' then self.window.input:SetText(E:Data().guildNotes[selected.key] or '') end
    if self:Data().view=='Route Library' then
        self.window.actionButtons[2]:SetText(selected.kind=='route-recommendations' and 'Browse guides' or 'Load route')
    end
    if self:Data().view=='Dungeon & Raid Journal' and self.journalInstance then
        self.window.actionButtons[1]:SetText(selected.kind=='journal-notes' and 'Open notes' or 'Boss details')
        self.window.actionButtons[4]:SetText(selected.goalKey and 'View goal' or 'Add loot goal')
    end
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
            E:TextDialog('Import into profile: '..name,'',false,function(code) return P:ReviewImport(code) end,
                function(review) return P:ImportSelected(name,review) end,nil,true)
        elseif r.kind=='profile' then
            local review,message=P:ReviewSaved(r.name)
            if not review then self.status=message; return end
            local lines={}
            for _,section in ipairs(review.sections) do
                local fields={}
                for i,key in ipairs(section.changes) do fields[i]=settingLabel(key) end
                lines[#lines+1]=settingLabel(section.key)..": "..(#fields>0 and table.concat(fields,", ") or "Value changed")
            end
            E:TextDialog('Differences from active profile: '..r.name,table.concat(lines,'\n'),true)
        end
    elseif view=='Next steps' then
        if action==1 and r then
            if r.module then
                local module=FS.modules[r.module]
                module:ShowWindow()
                if r.item and module.window and module.window:IsShown() then
                    for _,entry in ipairs(module.rows) do if entry.id==r.item then module.selected=entry; break end end
                    module:Render()
                end
            elseif r.view then
                if r.activity then self.prepActivity=r.activity end
                if r.goalKey then
                    self:FocusWishlistGoal(r.goalKey)
                else
                    self:Choose(r.view)
                end
            end
        elseif action==2 and r and r.goal then
            r.goal.acquired=true; self.selected=nil
        elseif action==4 and r and r.goal then
            self.journalInstance=nil; self.journalFilter=nil
            for _,instance in ipairs(E:JournalInstances()) do
                if instance.name:lower()==r.goal.instance:lower() then self.journalInstance=instance; break end
            end
            self:Choose('Dungeon & Raid Journal')
            if not self.journalInstance then self.window.search:SetText(r.goal.instance); self:Render() end
        end
    elseif view=='Run Notes' then
        local scope=self.notesInstance
        if action==1 then
            local fields={
                {label='Boss name as shown in game',limit=80},
                {label='Reminder or assignment',limit=200},
            }
            if scope then
                E:Form('Add run note: '..scope.name,fields,
                    function(boss,note) return E:SaveRunNote(scope.name,boss,note) end,'Save note')
            else
                table.insert(fields,1,{label='Dungeon or raid',limit=80})
                E:Form('Add run note',fields,
                    function(instance,boss,note) return E:SaveRunNote(instance,boss,note) end,'Save note')
            end
        elseif action==2 and r then
            local note=r.note
            E:Form(note.instance..' / '..note.boss,{{label='Reminder or assignment',value=note.note,limit=200}},
                function(text) return E:SaveRunNote(note.instance,note.boss,text) end,'Save note')
        elseif action==3 and r then
            E:Form('Delete note for '..r.note.boss..'?',{},function() d.runNotes[r.id]=nil; self.selected=nil; return true end,'Delete note')
        elseif action==4 then
            self.journalInstance=scope
            self:Choose('Dungeon & Raid Journal')
        end
    elseif view=='Gear Wishlist' then
        if action==1 then self:WishlistForm()
        elseif action==2 and r then r.goal.acquired=not r.goal.acquired
        elseif action==3 and r then d.wishlist[r.id]=nil; self.selected=nil
        elseif action==4 then self:Choose('Dungeon & Raid Journal') end
    elseif view=='Dungeon & Raid Journal' then
        local instance=self.journalInstance or (r and r.instance)
        if action==1 and r and r.kind=='journal-loot' then
            local goal=E:WishlistGoalForDrop(instance.name,r.boss,r.item)
            local hint=goal and 'Use View goal to open this entry in Gear Wishlist.' or 'Use Add loot goal to save this drop.'
            if r.detailLine then hint=r.detailLine..'\n'..hint end
            E:TextDialog('Observed loot',r.text..'\nItem ID: '..r.item..'\n'..hint,true)
        elseif action==1 and r and r.kind=='journal-notes' then
            self:Choose('Run Notes',instance)
        elseif action==1 and self.journalInstance and r and r.name then
            local note=E:RunNote(instance.name,r.name)
            local description=r.description~='' and r.description or 'The client supplied a boss name without a description.'
            if note then description=description..'\n\nYour run note\n'..note.note end
            E:TextDialog(r.name,description,true)
        elseif action==1 and instance then
            self.journalInstance=instance; self.selected=nil; self.page=1; self.window.search:SetText('')
        elseif action==2 and instance then
            local name=instance.name:sub(1,32)
            local d=E:Data()
            if not d.preparation[name] and not d.checklists[name] then
                local target=E:PreparationTargets(name)
                local ok,message=E:SavePreparation(name,target.durability,target.slots,target.itemLevel)
                if not ok then self.status=message; return end
            end
            self.prepActivity=name; self:Choose('Dungeon preparation')
        elseif action==3 then
            if self.journalInstance then self.journalInstance=nil
            else self.journalFilter=({All='Dungeon',Dungeon='Raid',Raid='All'})[self.journalFilter or 'All'] end
            self.selected=nil; self.page=1; self.window.search:SetText('')
        elseif action==4 then
            if self.journalInstance then
                local _,key
                if r and r.kind=='journal-loot' then _,key=E:WishlistGoalForDrop(instance.name,r.boss,r.item) end
                if key then self:FocusWishlistGoal(key)
                else self:WishlistForm(instance.name,r and (r.boss or r.name),r and r.item) end
            else self:Choose('Gear Wishlist') end
        end
    elseif view=='Dungeon preparation' then
        local activity=self.prepActivity
        if not activity and action==1 then
            local name=text:match('^%s*(.-)%s*$')
            if name=='' and r then name=r.name end
            if name and (d.preparation[name] or d.checklists[name]) then
                self.prepActivity=name
            else
                local defaults=E:PreparationTargets(name)
                local ok,message=E:SavePreparation(name,defaults.durability,defaults.slots,defaults.itemLevel)
                if not ok then self.status=message; return end
                self.prepActivity=name
            end
            self.selected=nil; self.page=1; self.window.input:SetText('')
        elseif activity and action==2 then
            local target=E:PreparationTargets(activity)
            E:Form('Preparation targets: '..activity,{
                {label='Minimum durability (%)',value=target.durability,limit=5},
                {label='Minimum free general bag slots',value=target.slots,limit=3},
                {label='Minimum item level (0 = no goal)',value=target.itemLevel,limit=6},
            },function(durability,slots,itemLevel) return E:SavePreparation(activity,durability,slots,itemLevel) end)
        elseif activity and action==3 then
            E:Form('Supplies for '..activity,{
                {label='Item ID',value=r and r.item or '',limit=9},
                {label='Carried quantity to aim for (0 removes the item)',value=r and r.required or 1,limit=6},
            },function(id,count)
                id,count=tonumber(id),tonumber(count)
                local list=d.checklists[activity]
                if count==0 and id and list and list[id] then list[id]=nil; return true end
                return E:Checklist(activity,id,count),'Enter a valid item ID and quantity.'
            end)
        elseif activity and action==4 then
            self.prepActivity=nil; self.selected=nil; self.page=1
        end
    elseif view=='Trainer preview' then
        if action==1 then self:Refresh() end
        if action==2 then self:ConfirmTraining() end
        if action==3 then self:StopTraining('Stopped by player.') end
    elseif view=='Character stock' then
        if action==1 then
            local _,message=E:RecordCharacter()
            self.status=message
        elseif action==2 and r then
            E:TextDialog(r.id,self:CharacterRecordText(r.record),true)
        elseif action==3 and r then
            E:StockRecords()[r.id]=nil
        end
    elseif view=='Layout presets' then
        if action==1 then
            local name=text:match('^%s*(.-)%s*$')
            if E:SaveContext(name) then self.window.input:SetText('') else self.status='Enter a preset name. You can keep up to 12 presets.' end
        elseif r and action==2 then
            if not E:UseContext(r.id) then self.status='This preset could not be applied.' end
        elseif r and action==3 then
            d.contexts[r.id]=nil; FS.modules.Profiles:PersistCurrent()
        end
    elseif view=='Accessibility' then
        if action==3 then E:Undo() elseif action==2 then local values={'Original','Color-friendly','High contrast'}; for i,v in ipairs(values) do if d.palette==v then d.palette=values[i%3+1]; break end end; E:Refresh(); FS.modules.Nameplates:RefreshPlates()
        elseif r and r.kind=='preset' then E:ApplyPreset(r.name); FS.Typography:Apply(); FS.modules.UnitFrames:SettingsChanged() end
    elseif view=='Rare sightings' then
        local options=d.discovery
        if action==1 then options.enabled=not options.enabled; E:SyncDiscovery()
        elseif action==2 then options.elites=not options.elites
        elseif action==4 then options.portrait=not options.portrait
        elseif action==3 and r and r.sighting then
            local sighting=r.sighting
            local stamp=T:Call(date,'%d %b %Y %H:%M:%S',sighting.time) or 'Time unavailable'
            local lines={sighting.kind,'NPC ID: '..sighting.id,'Detected via: '..sighting.source,stamp}
            if sighting.level and sighting.level>0 then lines[#lines+1]='Level: '..sighting.level end
            E:TextDialog(sighting.name,table.concat(lines,'\n'),true)
        end
    elseif view=='Notification Center' then
        if action==1 then self:Choose('Alerts') elseif action==2 then E.notifications={}; self.page=1 end
    elseif view=='Alerts' and r then
        local a=E:AlertOptions(r.name,true)
        if action==3 then self.status=E:Alert(r.name,true) and 'Played on '..a.channel..'; volume follows the game channel.' or 'Silent, or audio API unavailable.'
        elseif action==4 then
            if a.popup then a.history=not a.history end
            a.popup=not a.popup
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
    elseif view=='Gathering runs' then
        if action==1 and r and r.kind=='gathering-route' then
            if E:StartGathering(r.name) then self:Choose('Waypoint queue')
            else self.status='Enable waypoint navigation in Map and finish any active run before starting another.' end
        elseif action==2 then
            if E:FinishGathering('Finished manually') then self.status='Run saved.' end
        elseif action==3 and r and r.run then
            local run=r.run
            local stamp=T:Call(date,'%d %b %Y %H:%M',run.time) or 'Date unavailable'
            local lines={stamp,r.text,T:Text(run.result)}
            if not run.partial and run.duration>0 then
                lines[#lines+1]=('Loot per hour: %.1f items'):format(run.total*3600/run.duration)
            end
            local comparison
            for i=r.index+1,#d.gatheringRuns do
                local previous=d.gatheringRuns[i]
                if not run.partial and type(previous)=='table' and not previous.partial
                    and previous.route==run.route and previous.result==run.result
                    and T:Number(previous.duration) and T:Number(previous.total) then
                    comparison=previous
                    lines[#lines+1]=('Compared with previous run: %+.0f sec | %+.0f items'):format(run.duration-previous.duration,run.total-previous.total)
                    break
                end
            end
            if run.partial then lines[#lines+1]='Some items were omitted after the run reached its item limit.' end
            local items,counts={},{}
            if type(run.items)=='table' then
                for id,count in pairs(run.items) do
                    if T:Number(id) and T:Number(count) then counts[id]=count end
                end
            end
            local priorItems=comparison and type(comparison.items)=='table' and comparison.items
            if priorItems then
                for id,count in pairs(priorItems) do
                    if T:Number(id) and T:Number(count) and not counts[id] then counts[id]=0 end
                end
            end
            for id,count in pairs(counts) do
                local name=T:Text(T:Call(C_Item and C_Item.GetItemInfo,id))
                local prior=priorItems and priorItems[id]
                local delta=priorItems and (' (%+.0f)'):format(count-(T:Number(prior) and prior or 0)) or ''
                items[#items+1]=(name~='' and name or 'Item '..id)..' x'..count..delta
            end
            table.sort(items)
            for _,line in ipairs(items) do lines[#lines+1]=line end
            E:TextDialog('Gathering run: '..run.route,table.concat(lines,'\n'),true)
        elseif action==4 then self:Choose('Route Library') end
    elseif view=='Profession recommendations' then
        if action==1 and r then
            local entry=r.recommendation
            E:TextDialog(r.text,entry.tip..'\n\nSource: WoW-professions (WoW Forever guide)\n'..guideRoot..entry.guide,true)
        elseif action==2 then self:Choose('Route Library') end
    elseif view=='Route Library' then
        local name=r and r.name
        if action==1 then
            local newName=text:match('^%s*(.-)%s*$')
            local ok,message=E:SaveRoute(newName,d.waypointQueue,newName==name)
            self.status=ok and ('Saved route: '..newName) or message
        elseif action==2 then
            if r and r.kind=='route-recommendations' then self:Choose('Profession recommendations')
            elseif name and E:LoadRoute(name) then self:Choose('Waypoint queue') end
        elseif action==3 then
            if name then
                local code=E:Encode({kind='route',version=1,name=name,stops=d.routes[name],details=d.routeDetails[name]})
                E:TextDialog('Share route: '..name,code,true)
            elseif r and r.kind=='route-import' then
                E:TextDialog('Import route','',false,function(code) return E:PreviewRoute(code) end,
                    function(data) return E:SaveRoute(data.name,data.stops,false,data.details) end)
            elseif r and r.kind=='route-waypoints' then
                local newName=text:match('^%s*(.-)%s*$')
                if newName=='' then self.status='Enter a route name before importing /way coordinates.'; return end
                local dialog=E:TextDialog('Import /way coordinates: '..newName,'',false,
                    function(waypoints) return E:PreviewWaypointText(waypoints,newName) end,
                    function(data) return E:SaveRoute(data.name,data.stops) end)
                dialog.status:SetText('Paste one /way waypoint per line, then click Preview. Lines without a zone use the last named zone or your current zone.')
                dialog:Layout()
            elseif r and r.kind=='route-gathering' then self:Choose('Gathering runs')
            end
        elseif action==4 and name then
            local details=d.routeDetails[name] or {}
            E:Form('Manage route: '..name,{
                {label='Route name (clear to delete this route)',value=name,limit=40},
                {label='Profession (optional)',value=details.profession,limit=32},
                {label='Minimum skill (optional)',value=details.minimum,limit=4},
                {label='Maximum skill (optional)',value=details.maximum,limit=4},
                {label='Source or author (included in shared codes)',value=details.source,limit=100},
            },function(newName,profession,minimum,maximum,source)
                return E:RenameRoute(name,newName,{profession=profession,minimum=minimum,maximum=maximum,source=source})
            end)
        end
    elseif view=='Waypoint queue' then
        if action==4 then self:Choose('Route Library')
        elseif E.gathering and action~=1 then self.status='Finish recording the run before editing its stops.'
        elseif E.gathering and r and r.kind=='pin' then self.status='Finish recording the run before adding stops.'
        elseif action==1 then if r and r.kind=='pin' then if #d.waypointQueue<50 then d.waypointQueue[#d.waypointQueue+1]=E.Copy(FS.db.map.pins[r.index]) end else E:StartQueue() end
        elseif action==2 and r and r.kind=='queue' and r.index>1 then local p=table.remove(d.waypointQueue,r.index); table.insert(d.waypointQueue,r.index-1,p); E.queueActive=false
        elseif action==3 then if r and r.kind=='queue' then table.remove(d.waypointQueue,r.index) end; E.queueActive=false; FS.modules.Map:ClearNavigation() end
    elseif view=='Leveling session' then if action==1 then E:ResetXP() elseif action==2 then FS.modules.QoL:ShowWindow() end
    elseif view=='Maintenance' then if action==1 then E:TextDialog('Support report',FS:SupportReport(),true) elseif action==2 then E.audit={} else E:Undo() end end
end

local trainerEvents=CreateFrame('Frame')
FS:RegisterClientEvent(trainerEvents,'TRAINER_SHOW')
FS:RegisterClientEvent(trainerEvents,'TRAINER_UPDATE')
FS:RegisterClientEvent(trainerEvents,'TRAINER_CLOSED')
trainerEvents:SetScript('OnEvent',function(_,event)
    if event~='TRAINER_UPDATE' then
        W.trainerRevision=(W.trainerRevision or 0)+1
        if W.training then W:StopTraining('Trainer changed or closed.') end
    end
    if W.window and W.window:IsShown() and W:Data().view=='Trainer preview' then
        C_Timer.After(0,function()
            if W.window:IsShown() and W:Data().view=='Trainer preview' then W:Refresh() end
        end)
    end
end)
