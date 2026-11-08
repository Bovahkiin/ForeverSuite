local _,FS=...
local I={}; FS.Installer=I
local H=FS.HUD
local modules={"ActionBars","UnitFrames","Quests","Map","Chat","Nameplates"}
local titles={ActionBars="Action bars",UnitFrames="Unit frames",Quests="Quest tracker",Map="Map & navigation",Chat="Chat",Nameplates="Nameplates"}
function I:NeedsSetup() return FS.db and not FS.db.setup.completed and not FS.db.setup.dismissed end
function I:Draft()
    self.draft={theme=FS.Themes:Index(FS.db.appearance.theme) and FS.db.appearance.theme or FS.Themes.names[1],style=FS.db.actionBars.style,scale=math.min(1.2,math.max(.8,FS.db.actionBars.scale)),modules={}}
    for _,name in ipairs(modules) do self.draft.modules[name]=FS:IsModuleEnabled(name) end
    local firstWelcome=FS.firstInstallation and not self.hasOpenedSetup
    self.draft.layout=self:NeedsSetup() and (firstWelcome or next(FS.db.layout.frames)==nil) and "Layout 1" or "Keep current"
    self.draft.nativeLayout=FS.LayoutPresets:NativeAvailable()==true
end
function I:Dismiss()
    if self.themeOnly then self.window:Hide(); if FS.window then FS:ShowConfig() end; return end
    FS.db.setup.dismissed=true; self.window:Hide()
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
    for _,name in ipairs(modules) do FS:SetModuleEnabled(name,d.modules[name]) end
    FS.db.setup.completed=true; FS.db.setup.dismissed=false
    FS.Themes:Refresh()
    FS.Layout:ApplyAll(); FS.modules.Profiles:PersistCurrent()
    self.window:Hide(); FS:ShowConfig(); return true
end
function I:Create()
    if self.window then return end
    local f=CreateFrame("Frame","ForeverSuiteInstaller",UIParent,"BackdropTemplate"); self.window=f
    H:Skin(f); f:SetBackdropColor(.018,.027,.038,1); f:SetSize(760,680); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
    local logo=f:CreateTexture(nil,"ARTWORK"); logo:SetTexture(FS.logo); logo:SetSize(310,78); logo:SetPoint("TOP",0,-12)
    f.title=H:Label(f,"",24,-100,712); f.description=H:Label(f,"",24,-140,712)
    f.choices={}; for index=1,10 do
        local button=H:Button(f,"",0,0,344,function()
            if self.step==2 then self.draft.theme=FS.Themes.names[index]
            elseif self.step==3 then
                if index<=3 then self.draft.scale=({.8,1,1.2})[index]; self.draft.preset=nil
                else self.draft.preset=index==4 and 'Readable text' or 'Compact screen'; self.draft.scale=index==4 and 1.2 or .8 end
            elseif self.step==4 then local name=modules[index]; self.draft.modules[name]=not self.draft.modules[name]
            elseif self.step==5 then self.draft.layout=FS.LayoutPresets.names[index] end
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
    f.preview.player=H:Label(f.preview,"Player  |  100%",18,-20,210)
    f.preview.target=H:Label(f.preview,"Target  |  100%",470,-20,210)
    f.preview.quest=H:Label(f.preview,"Quest objectives\nFollow your waypoint",470,-62,215)
    f.preview.chat=H:Label(f.preview,"[Guild] Welcome to ForeverSuite!",18,-66,230)
    f.preview.nameplate=H:Label(f.preview,"Enemy  |  100%",270,-60,190)
    f.preview.waypoint=H:Label(f.preview,"^  Quest destination  |  150 yards",230,-102,300)
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
    f.previous=H:Button(f,"Back",24,-620,170,function() self.step=math.max(1,self.step-1); self:Refresh() end)
    f.later=H:Button(f,"Set up later",205,-620,220,function() self:Dismiss() end)
    f.next=H:Button(f,FS.Text.next,530,-620,206,function()
        if self.themeOnly then
            if FS.Themes:Set(self.draft.theme) then self.window:Hide(); if FS.window then FS:ShowConfig() end end
        elseif self.step==5 then self:Apply() else self.step=self.step+1; self:Refresh() end
    end)
    UISpecialFrames[#UISpecialFrames+1]="ForeverSuiteInstaller"
    f:Hide()
end
function I:Refresh()
    local f=self.window; local d=self.draft; if not f or not d then return end
    local titlesByStep={"Welcome to ForeverSuite","Choose your appearance","Text and screen presets","Choose your modules","Choose your layout"}
    local descriptions={"ForeverSuite  |  v"..FS.version.."\nCreated by DeluxiZ\nA few quick choices to make your UI feel like yours.","Ten Blender styles. Select one to see its panel, button and arrow design. Gameplay positions stay unchanged.","Bar size buttons affect this preview only. Readable text stages size 18 and outlines; Compact screen stages size 12 and 85% unit frames. Apply & finish saves the preset.","Choose what ForeverSuite manages. Other modules keep their current settings."}
    descriptions[5]="Choose a screen arrangement. Layout 1 follows DeluxiZ's reference; the preview uses neutral labels only. Positions are fitted to your screen when you finish."
    f.title:SetText(titlesByStep[self.step]); f.description:SetText(descriptions[self.step])
    local function at(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y) end
    local y=100+H:TextHeight(f.title,712,2)+14; at(f.description,24,y); y=y+H:TextHeight(f.description,712,4)+20
    local count=self.step==2 and 10 or self.step==3 and 5 or self.step==4 and 6 or self.step==5 and 4 or 0
    local rowHeight=36
    for index,button in ipairs(f.choices) do
        button:SetShown(index<=count)
        if index<=count then
            local caption,selected
            if self.step==2 then caption=string.format("%02d  %s",index,FS.Themes.names[index]); selected=d.theme==FS.Themes.names[index]
            elseif self.step==3 then caption=({"Compact bars preview (80%)","Standard bars preview (100%)","Large bars preview (120%)","Readable text preset","Compact screen preset"})[index]; selected=index<=3 and not d.preset and d.scale==({.8,1,1.2})[index] or index==4 and d.preset=='Readable text' or index==5 and d.preset=='Compact screen'
            elseif self.step==4 then local name=modules[index]; caption=titles[name]..": "..(d.modules[name] and "On" or "Off"); selected=d.modules[name]
            else caption=FS.LayoutPresets.names[index]; selected=d.layout==caption end
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
    f.design:SetShown(self.step==2); f.preview:SetShown(self.step~=2 and self.step~=5); f.layoutPreview:SetShown(self.step==5)
    if self.step==5 then at(f.layoutPreview,24,y); FS.LayoutPresets:Preview(f.layoutPreview,d.layout) end
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
    y=y+(self.step==2 and f.design:GetHeight() or self.step==5 and f.layoutPreview:GetHeight() or preview:GetHeight())+16
    f.patch:SetShown(self.step==1)
    if self.step==1 then at(f.patch,24,y); y=y+H:FitButton(f.patch,2)+14 end
    f.status:SetText(self.themeOnly and "Preview only — Apply style saves this appearance to your current profile." or "Step "..self.step.." / 5  |  Preview only — changes are saved when you finish."); at(f.status,24,y); y=y+H:TextHeight(f.status,712,2)+16
    f.later:SetText(self.themeOnly and "Cancel" or "Set up later")
    f.previous:SetEnabled(self.step>1 and not self.themeOnly); f.next:SetText(self.themeOnly and "Apply style" or self.step==5 and "Apply & finish" or FS.Text.next)
    local footer=0; for _,b in ipairs({f.previous,f.later,f.next}) do footer=math.max(footer,H:FitButton(b,2)) end
    at(f.previous,24,y); at(f.later,205,y); at(f.next,530,y); f:SetHeight(y+footer+24)
    f:SetScale(math.min(1,(UIParent:GetWidth()-48)/760,(UIParent:GetHeight()-48)/f:GetHeight()))
end
function I:Show()
    if InCombatLockdown() then FS:Print("Leave combat to open setup."); return false end
    self:Create(); self:Draft(); self.hasOpenedSetup=true; self.themeOnly=false; self.step=1; FS.installerReturn=false
    FS:CloseOtherWindows(self.window); self:Refresh(); self.window:Show(); return true
end
function I:ShowThemes()
    if not self:Show() then return false end
    self.themeOnly=true; self.step=2; self:Refresh(); return true
end
