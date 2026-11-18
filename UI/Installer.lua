local _,FS=...
local I={}; FS.Installer=I
local H=FS.HUD
local modules={"ActionBars","UnitFrames","Quests","Map","Chat","Nameplates","Buffs","Cooldowns","Combat"}
local titles={ActionBars="Action bars",UnitFrames="Unit frames",Quests="Quest tracker",Map="Map & navigation",Chat="Chat",Nameplates="Nameplates",Buffs="Buffs",Cooldowns="Cooldowns",Combat="Combat tracking"}
I.themeChoices={{"Classic","Azeroth Heritage"},{"Dark","Obsidian Arcana"},{"Emerald","Verdant Relic"},{"Crimson","Ember Bastion"},{"Sapphire","Celestial Forge"}}
I.layouts={"Minimal","Layout 1","Advanced","Keep current"}
I.preferences={"Casual","PvE","PvP","Custom"}
local preferenceModules={
    Casual={Nameplates=false,Cooldowns=false,Combat=false},
    PvE={},
    PvP={Quests=false},
}
local steps={2,5,4,6}

function I:SelectPreference(name)
    self.draft.preference=name
    local overrides=preferenceModules[name]
    if overrides then
        for _,module in ipairs(modules) do self.draft.modules[module]=overrides[module]~=false end
    end
end
function I:ThemeLabel(theme)
    if not self.themeOnly then
        for _,choice in ipairs(self.themeChoices) do if choice[2]==theme then return choice[1] end end
    end
    return theme
end
function I:LayoutChoices()
    return self.layoutOnly and FS.LayoutPresets.names or self.layouts
end

function I:StepIndex()
    for index, step in ipairs(steps) do if step == self.step then return index end end
    return 1
end

function I:Recommended()
    self:Draft()
    self.draft.layout = "Layout 1"
    self.draft.theme = self.themeChoices[2][2]
    self.draft.style = "Minimal"
    self.draft.scale = 1
    self.draft.preset = "Standard text"
    self:SelectPreference("Casual")
    self.step=6
    self:Refresh()
end
function I:NeedsSetup() return FS.db and not FS.db.setup.completed and not FS.db.setup.dismissed end
function I:Draft()
    self.draft={theme=FS.Themes:Index(FS.db.appearance.theme) and FS.db.appearance.theme or self.themeChoices[2][2],style=FS.db.actionBars.style,scale=math.min(1.2,math.max(.8,FS.db.actionBars.scale)),modules={}}
    for _,name in ipairs(modules) do self.draft.modules[name]=FS:IsModuleEnabled(name) end
    local firstWelcome=FS.firstInstallation and not self.hasOpenedSetup
    self.draft.layout=self:NeedsSetup() and (firstWelcome or next(FS.db.layout.frames)==nil) and "Layout 1" or "Keep current"
    self.draft.nativeLayout=FS.LayoutPresets:NativeAvailable()==true
    self.draft.preference=firstWelcome and "Casual" or "Custom"
    if firstWelcome then self:SelectPreference("Casual") end
end
function I:Dismiss()
    if self.themeOnly or self.layoutOnly then self.window:Hide(); if FS.window then FS:ShowConfig() end; return end
    if FS.firstInstallation then FS.db.patchLog.lastSeenVersion=FS.version end
    FS.db.setup.dismissed=true; FS.db.setup.welcomePending=false; self.window:Hide()
end
function I:Apply()
    if InCombatLockdown() then FS:Print("Leave combat to finish setup."); return false end
    if FS.modules.Vendor.busy then FS:Print("Finish the current vendor action before applying setup."); return false end
    local d=self.draft; if not d then return false end
    local A=FS.modules.ActionBars
    local valid=false; for _,style in ipairs(A.styles) do if style==d.style then valid=true end end
    if not valid or type(d.scale)~="number" or d.scale<.8 or d.scale>1.2 then return false end
    if not FS.Themes:Index(d.theme) then return false end
    local plan,reason=FS.LayoutPresets:Prepare(d.layout or "Keep current",d.nativeLayout)
    if not plan then FS:Print(reason); return false end
    if not FS.LayoutPresets:Commit(d.layout or "Keep current",plan) then return false end
    FS.db.appearance.theme=d.theme
    FS.db.actionBars.style=d.style
    if d.preset then FS.Extensions:ApplyPreset(d.preset); FS.Typography:Apply() end
    for _,name in ipairs(modules) do
        if FS:IsModuleEnabled(name)~=d.modules[name] then FS:SetModuleEnabled(name,d.modules[name]) end
    end
    if not FS.Themes:Set(d.theme) then return false end
    if FS.firstInstallation then FS.db.patchLog.lastSeenVersion=FS.version end
    FS.db.setup.completed=true; FS.db.setup.dismissed=false; FS.db.setup.welcomePending=false
    FS.Layout:ApplyAll(); FS.modules.Profiles:PersistCurrent()
    self.window:Hide(); FS:ShowConfig()
    if not FS.db.setup.tourCompleted and not FS.db.setup.tourDismissed then FS.Beginner:ShowTour() end
    return true
end
function I:Create()
    if self.window then return end
    local f=CreateFrame("Frame","ForeverSuiteInstaller",UIParent,"BackdropTemplate"); self.window=f
    H:Skin(f); f:SetBackdropColor(.018,.027,.038,1); f:SetSize(760,680); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
    local logo=f:CreateTexture(nil,"ARTWORK"); logo:SetTexture(FS.logo); logo:SetSize(310,78); logo:SetPoint("TOP",0,-12)
    f.title=H:Label(f,"",24,-100,712); f.description=H:Label(f,"",24,-140,712)
    f.choices={}; for index=1,math.max(#FS.Themes.names,#I.preferences+#modules,#FS.LayoutPresets.names) do
        local button=H:Button(f,"",0,0,344,function()
            if self.step==2 then self.draft.theme=self.themeOnly and FS.Themes.names[index] or self.themeChoices[index][2]
            elseif self.step==3 then
                if index<=3 then self.draft.scale=({.8,1,1.2})[index]; self.draft.preset=nil
                else
                    self.draft.preset=({[4]='Readable text',[5]='Compact screen',[6]='Standard text'})[index]
                    self.draft.scale=index==4 and 1.2 or index==5 and .8 or 1
                end
            elseif self.step==4 then
                if self.preferences[index] then self:SelectPreference(self.preferences[index])
                else local name=modules[index-#self.preferences]; self.draft.modules[name]=not self.draft.modules[name] end
            elseif self.step==5 then self.draft.layout=self:LayoutChoices()[index] end
            self:Refresh()
        end); f.choices[index]=button
    end
    f.previewTitle=H:Label(f,"Preview",24,-280,712)
    f.preview=CreateFrame("Frame",nil,f,"BackdropTemplate"); H:Skin(f.preview); f.preview:SetSize(712,220); f.preview:SetBackdropColor(.04,.07,.075,1)
    f.layoutPreview=FS.LayoutPresets:CreatePreview(f)
    f.nativeLayout=H:Button(f,"",24,-260,712,function() self.draft.nativeLayout=not self.draft.nativeLayout; self:Refresh() end)
    f.layoutHelp=H:Label(f,"",24,-260,712); f.layoutHelp:SetHeight(60)
    f.design=CreateFrame("Frame",nil,f); f.design:SetSize(712,445); f.design:EnableMouse(false)
    f.design.image=f.design:CreateTexture(nil,"ARTWORK"); f.design.image:SetAllPoints(); f.design.image:SetTexCoord(0,1,0,.625)
    f.themeSample=CreateFrame("Frame",nil,f); f.themeSample:SetSize(712,44); f.themeSample:EnableMouse(false)
    f.themeSample.button=H:Button(f.themeSample,"Button preview",0,-5,185)
    f.themeSample.button:EnableMouse(false)
    f.themeSample.arrow=f.themeSample:CreateTexture(nil,"ARTWORK"); f.themeSample.arrow:SetSize(38,38)
    f.themeSample.arrow:SetPoint("LEFT",205,0)
    H:Label(f.themeSample,"Waypoint arrow",250,-13,200)
    f.themeSample.icons = {}
    for index, name in ipairs({"Character", "Bags", "Map"}) do
        local badge = f.themeSample:CreateTexture(nil, "ARTWORK")
        badge:SetSize(28, 28)
        badge:SetPoint("LEFT", 488 + (index - 1) * 37, 0)
        f.themeSample.icons[name] = badge
    end
    H:Label(f.themeSample, "Icons", 608, -13, 100)
    f.preview.player=H:Label(f.preview,"Player  |  100%",18,-20,210)
    f.preview.target=H:Label(f.preview,"Target  |  100%",470,-20,210)
    f.preview.quest=H:Label(f.preview,"Quest objectives\nFollow your waypoint",470,-62,215)
    f.preview.chat=H:Label(f.preview,"[Guild] Welcome to ForeverSuite!",18,-66,230)
    f.preview.nameplate=H:Label(f.preview,"Enemy  |  100%",270,-60,190)
    f.preview.waypoint=H:Label(f.preview,"^  Quest destination  |  150 yards",230,-102,300)
    f.preview.activity=H:Label(f.preview,"",20,-194,672)
    f.preview.activity:SetJustifyH("CENTER"); f.preview.activity:SetHeight(20)
    f.preview.empty=H:Label(f.preview,"All preview modules are off. Enable a module above to see its example.",40,-75,632)
    f.preview.empty:SetJustifyH("CENTER"); f.preview.empty:SetHeight(80); f.preview.empty:Hide()
    f.preview.health={}
    for index,x in ipairs({18,470}) do
        local bar=f.preview:CreateTexture(nil,"ARTWORK"); bar:SetColorTexture(index==1 and .3 or .8,index==1 and .75 or .15,.22,1)
        bar:SetSize(210,8); bar:SetPoint("TOPLEFT",x,-43); f.preview.health[index]=bar
    end
    f.preview.tray=CreateFrame("Frame",nil,f.preview,"BackdropTemplate"); H:Skin(f.preview.tray)
    f.preview.tray.gold=f.preview.tray:CreateTexture(nil,"ARTWORK"); f.preview.tray.gold:SetColorTexture(.95,.68,.24,1); f.preview.tray.gold:SetSize(24,2); f.preview.tray.gold:SetPoint("TOPLEFT",3,-2)
    f.preview.tray.cyan=f.preview.tray:CreateTexture(nil,"ARTWORK"); f.preview.tray.cyan:SetColorTexture(.12,.72,.86,1); f.preview.tray.cyan:SetHeight(2); f.preview.tray.cyan:SetPoint("BOTTOMLEFT",3,1); f.preview.tray.cyan:SetPoint("BOTTOMRIGHT",-3,1)
    f.preview.tiles={}
    local icons={[1]="INV_Weapon_Bow_07",[2]="INV_Sword_04",[3]="Ability_Hunter_AimedShot",[11]="Spell_Shadow_LifeDrain02",[12]="Spell_Nature_Cyclone"}
    for index=1,12 do
        local tile=CreateFrame("Frame",nil,f.preview,"BackdropTemplate"); tile:EnableMouse(false)
        tile.icon=tile:CreateTexture(nil,"ARTWORK"); tile.icon:SetPoint("TOPLEFT",3,-3); tile.icon:SetPoint("BOTTOMRIGHT",-3,3)
        if icons[index] then tile.icon:SetTexture("Interface\\Icons\\"..icons[index]) else tile.icon:Hide() end
        tile.key=tile:CreateFontString(nil,"OVERLAY"); tile.key:SetFont(FS.font,12,"OUTLINE"); tile.key:SetPoint("TOPRIGHT",-3,-2); tile.key:SetText(index==10 and "0" or index==11 and "-" or index==12 and "=" or tostring(index))
        f.preview.tiles[index]=tile
    end
    f.status=H:Label(f,"",24,-560,712)
    f.patch=H:Button(f,"Patch Log",24,-560,180,function() self.window:Hide(); FS:ShowPatchLog(true); FS.aboutReturn=false end)
    f.recommended=H:Button(f,"Use recommended settings",24,-560,344,function() self:Recommended() end)
    f.customize=H:Button(f,"Text and bar preview",392,-560,344,function() self.step=3; self:Refresh() end)
    f.previous=H:Button(f,"Back",24,-620,170,function()
        self.step=self.step==3 and 6 or steps[math.max(1,self:StepIndex()-1)]; self:Refresh()
    end)
    f.later=H:Button(f,"Set up later",205,-620,220,function() self:Dismiss() end)
    f.next=H:Button(f,FS.Text.next,530,-620,206,function()
        if self.themeOnly then
            if FS.Themes:Set(self.draft.theme) then FS.modules.Profiles:PersistCurrent(); self.window:Hide(); if FS.window then FS:ShowConfig() end end
        elseif self.layoutOnly then
            local plan,reason=FS.LayoutPresets:Prepare(self.draft.layout,self.draft.nativeLayout)
            if not plan then FS:Print(reason); return end
            if FS.LayoutPresets:Commit(self.draft.layout,plan) then
                FS.modules.Profiles:PersistCurrent(); self.window:Hide(); FS:ShowConfig()
            end
        elseif self.step==3 then self.step=6; self:Refresh()
        elseif self.step==6 then self:Apply()
        else self.step=steps[math.min(#steps,self:StepIndex()+1)]; self:Refresh() end
    end)
    UISpecialFrames[#UISpecialFrames+1]="ForeverSuiteInstaller"
    f:Hide()
end
function I:Refresh()
    local f=self.window; local d=self.draft; if not f or not d then return end
    local titlesByStep={[2]="Choose your theme",[3]="Text and bar preview",[4]="Choose how you play",[5]="Choose your layout",[6]="Review your setup"}
    local descriptions={
        [2]=self.themeOnly and "Preview frames, buttons, icons and the waypoint arrow." or "Welcome to ForeverSuite "..FS.version.."! Choose a theme to preview it. Created by DeluxiZ.",
        [3]="Preview text and action bar sizes. Text presets are saved when you finish setup.",
        [4]=d.preference=="Custom" and "Choose which modules to turn on." or "Casual keeps everyday tools handy. PvE adds combat tracking. PvP prioritizes buffs, cooldowns and nameplates.",
        [5]="Preview where your frames will be placed. Layouts fit the size of your screen.",
        [6]="Theme: "..self:ThemeLabel(d.theme).."\nLayout: "..(FS.LayoutPresets.labels[d.layout] or d.layout).."\nProfile: "..d.preference
    }
    f.title:SetText(titlesByStep[self.step]); f.description:SetText(descriptions[self.step])
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
    local y=100+H:TextHeight(f.title,712,2)+14; at(f.description,24,y); y=y+H:TextHeight(f.description,712,4)+20
    local count=self.step==2 and (self.themeOnly and #FS.Themes.names or #self.themeChoices) or self.step==3 and 6
        or self.step==4 and (#self.preferences+(d.preference=="Custom" and #modules or 0))
        or self.step==5 and #self:LayoutChoices() or 0
    local rowHeight=36
    for index,button in ipairs(f.choices) do
        button:SetShown(index<=count)
        if index<=count then
            local caption,selected
            if self.step==2 then
                local name=self.themeOnly and FS.Themes.names[index] or self.themeChoices[index][2]
                caption=self:ThemeLabel(name); selected=d.theme==name
            elseif self.step==3 then caption=({"Compact bars preview (80%)","Standard bars preview (100%)","Large bars preview (120%)","Readable text (18)","Compact text (12)","Standard text (14)"})[index]; selected=index<=3 and not d.preset and d.scale==({.8,1,1.2})[index] or index==4 and d.preset=='Readable text' or index==5 and d.preset=='Compact screen' or index==6 and d.preset=='Standard text'
            elseif self.step==4 then
                local preference=self.preferences[index]
                if preference then caption=preference; selected=d.preference==preference
                else local name=modules[index-#self.preferences]; caption=titles[name]..": "..(d.modules[name] and "On" or "Off"); selected=d.modules[name] end
            else
                local name=self:LayoutChoices()[index]
                caption=FS.LayoutPresets.labels[name] or name
                selected=d.layout==name
            end
            button:SetText((selected and "[x] " or "")..caption); button:SetBackdropBorderColor(selected and .95 or .12,selected and .68 or .55,selected and .24 or .65,1)
            rowHeight=math.max(rowHeight,H:FitButton(button,2)+10)
        end
    end
    for index=1,count do at(f.choices[index],24+(index-1)%2*368,y+math.floor((index-1)/2)*rowHeight) end
    y=y+math.ceil(count/2)*rowHeight
    f.nativeLayout:SetShown(self.step==5); f.layoutHelp:SetShown(self.step==5)
    if self.step==5 then
        f.nativeLayout:SetText("Game bars and chat: "..(d.layout=="Keep current" and "Unchanged" or d.nativeLayout and "Use this layout" or "Keep current game positions"))
        f.nativeLayout:SetEnabled(FS.LayoutPresets:NativeAvailable()==true and d.layout~="Keep current")
        at(f.nativeLayout,24,y); y=y+H:FitButton(f.nativeLayout,2)+10
        f.layoutHelp:SetText(FS.LayoutPresets.descriptions[d.layout] or "Choose a layout.")
        at(f.layoutHelp,24,y); y=y+H:TextHeight(f.layoutHelp,712,3)+12
    end
    at(f.previewTitle,24,y); y=y+H:TextHeight(f.previewTitle,712,1)+8; at(f.preview,24,y)
    local theme=FS.Themes:Index(d.theme) or 1
    f.design:Hide(); f.preview:SetShown(self.step==4); f.layoutPreview:SetShown(self.step~=4)
    if self.step~=4 then
        at(f.layoutPreview,24,y)
        FS.LayoutPresets:Preview(f.layoutPreview,d.layout)
        FS.Themes:Register(f.layoutPreview,"Panel",theme)
        for _, item in pairs(f.layoutPreview.parts) do
            FS.Themes:Register(item.frame,"Panel",theme)
            item.frame.label:SetFont(FS.font,d.preset=='Readable text' and 13 or d.preset=='Compact screen' and 9 or 10,"")
        end
        local factor=d.scale or 1
        for _,id in ipairs({"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight"}) do
            local item=f.layoutPreview.parts[id]
            item.frame:SetHeight(item.frame:GetHeight()*factor)
        end
    end
    at(f.design,24,y); f.design.image:SetTexture(FS.Themes:Asset(theme,"Preview"))
    local preview=f.preview
    -- Welcome and text/size examples must work even when live modules are off.
    -- Only the module-choice page filters the illustration by the staged choices.
    local function show(name) return self.step~=4 or d.modules[name]==true end
    preview.player:SetShown(show("UnitFrames")); preview.target:SetShown(show("UnitFrames"))
    preview.quest:SetShown(show("Quests")); preview.chat:SetShown(show("Chat"))
    preview.nameplate:SetShown(show("Nameplates")); preview.waypoint:SetShown(show("Map"))
    for _,bar in ipairs(preview.health) do bar:SetShown(show("UnitFrames")) end
    local any=false; for _,name in ipairs(modules) do any=any or d.modules[name]==true end
    local extras={}
    for _,name in ipairs({"Buffs","Cooldowns","Combat"}) do
        if d.modules[name] then extras[#extras+1]=titles[name] end
    end
    preview.activity:SetText(table.concat(extras,"  |  "))
    preview.activity:SetShown(self.step==4 and #extras>0)
    preview.empty:SetShown(self.step==4 and not any)
    for _,region in ipairs({preview.player,preview.target,preview.quest,preview.chat,preview.nameplate,preview.waypoint}) do region:SetFont(FS.font,d.preset=='Readable text' and 18 or d.preset=='Compact screen' and 12 or 13,""); region:SetHeight(44) end
    local size=36*d.scale; local gap=d.style=="Floating" and 5 or 2; local width=12*size+11*gap; local x=(712-width)/2
    for index,tile in ipairs(preview.tiles) do
        tile:SetSize(size,size); at(tile,x+(index-1)*(size+gap),140); tile:SetShown(show("ActionBars"))
        FS.modules.ActionBars:StyleTile(tile,d.style,true)
        FS.Themes:Register(tile,"Button",theme)
        if tile.styleTexture then tile.styleTexture:Hide() end
        FS.modules.ActionBars:StyleIcon(tile.icon,tile,d.style,true)
    end
    preview.tray:ClearAllPoints(); preview.tray:SetPoint("TOPLEFT",x-5,-135); preview.tray:SetSize(width+10,size+10)
    preview.tray:SetFrameLevel(preview:GetFrameLevel()+1)
    for _,tile in ipairs(preview.tiles) do tile:SetFrameLevel(preview:GetFrameLevel()+2) end
    FS.modules.ActionBars:StyleTray(preview.tray,d.style,show("ActionBars"))
    y=y+(self.step==4 and preview:GetHeight() or f.layoutPreview:GetHeight())+16
    f.themeSample:SetShown(self.step==2)
    if self.step==2 then
        at(f.themeSample,24,y)
        FS.Themes:Register(f.themeSample.button,"Button",theme)
        FS.Themes:Font(f.themeSample.button.fsLabel,theme)
        f.themeSample.arrow:SetTexture(FS.Themes:Asset(theme,"Arrow"))
        for name, badge in pairs(f.themeSample.icons) do
            FS:SetMenuIcon(badge, name, theme)
        end
        f.themeSample:SetHeight(math.max(44,H:FitButton(f.themeSample.button,2)+10))
        y=y+f.themeSample:GetHeight()+8
    end
    local first=self.step==2 and not self.themeOnly
    f.recommended:SetShown(first); f.patch:SetShown(first); f.customize:SetShown(self.step==6)
    if first then
        at(f.recommended,24,y); at(f.patch,392,y)
        y=y+math.max(H:FitButton(f.recommended,2),H:FitButton(f.patch,2))+12
    elseif self.step==6 then
        at(f.customize,24,y); y=y+H:FitButton(f.customize,2)+10
    end
    local summary=FS.LayoutPresets.labels[d.layout] or d.layout
    local status=self.themeOnly and "Apply style saves this appearance to your current profile."
        or self.layoutOnly and "Layout: "..summary
        or self.step==3 and "Optional preview"
        or "Step "..self:StepIndex().." / 4"
    f.status:SetText(status); at(f.status,24,y); y=y+H:TextHeight(f.status,712,3)+16
    f.later:SetText((self.themeOnly or self.layoutOnly) and "Cancel" or "Set up later")
    f.previous:SetEnabled((self:StepIndex()>1 or self.step==3) and not self.themeOnly and not self.layoutOnly)
    f.next:SetText(self.themeOnly and "Apply style" or self.layoutOnly and "Apply layout" or self.step==6 and "Apply & finish" or self.step==3 and "Back to review" or FS.Text.next)
    local footer=0; for _,b in ipairs({f.previous,f.later,f.next}) do footer=math.max(footer,H:FitButton(b,2)) end
    at(f.previous,24,y); at(f.later,205,y); at(f.next,530,y); f:SetHeight(y+footer+24)
    f:SetScale(math.min(1,(UIParent:GetWidth()-48)/760,(UIParent:GetHeight()-48)/f:GetHeight()))
end
function I:Show()
    if InCombatLockdown() then FS:Print("Leave combat to open setup."); return false end
    self:Create(); self:Draft(); self.hasOpenedSetup=true; self.themeOnly=false; self.layoutOnly=false; self.step=2; FS.installerReturn=false
    FS:CloseOtherWindows(self.window); self:Refresh(); self.window:Show(); return true
end
function I:ShowThemes()
    if not self:Show() then return false end
    self.themeOnly=true; self.step=2; self:Refresh(); return true
end
function I:ShowLayouts()
    if not self:Show() then return false end
    self.layoutOnly=true; self.step=5; self.draft.layout="Keep current"; self.draft.nativeLayout=false
    self:Refresh(); return true
end
