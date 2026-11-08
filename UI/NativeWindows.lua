local _,FS=...
local S,H=FS.Style,FS.HUD
local N={windows={},art={},fonts={},controls={},bars={},progress={},geometry={},plainControls=setmetatable({},{__mode="k"})}; FS.NativeWindows=N
N.definitions={
    {"FriendsFrame","Social","Social","Contacts","styleContacts"}, {"ContactsFrame","Social","Social","Contacts","styleContacts"},
    {"ProfessionsBookFrame","Professions","Professions","Professions"},
    {"ProfessionsFrame","Professions","Professions","Professions"}, {"TradeSkillFrame","Professions","Professions","Crafting"}, {"CraftFrame","Professions","Professions","Crafting"},
    {"SpellBookFrame","ActionBars","Spells","Spellbook"}, {"PlayerSpellsFrame","ActionBars","Spells","Spellbook & Talents"},
    {"AchievementFrame","ActionBars","Achievements","Achievements"},
    {"WorldMapFrame","Map","Map","Map & Quest Log"}, {"QuestLogFrame","Quests","Quests","Quest Log"},
    {"LootFrame","Loot","Collections","Loot","styleWindow"},
    {"CommunitiesFrame","Guild","Guild","Guild & Communities","styleWindow"}, {"GuildFrame","Guild","Guild","Guild","styleWindow"},
    {"CollectionsJournal","ActionBars","Collections","Appearances"}, {"WardrobeFrame","ActionBars","Collections","Appearances"},
}
local iconKeys={"icon","Icon","IconTexture","iconTexture","iconTextureUncollected","ItemIcon","SlotIcon","status","Status","gameIcon","ClassIcon","FactionIcon","RewardIcon","SearchIcon","Check","check","CheckMark","ThumbTexture","Thumb","thumb"}
local artKeys={"Background","Bg","BG","Border","BorderArt","NineSlice","Portrait","portrait","PortraitContainer","TitleBg","TopTileStreaks","WaterMark","Watermark","BackgroundTile","Parchment","capLeft","capRight"}
local panels={"Inset","LeftInset","RightInset","CommunitiesList","GuildDetailsFrame","PrimaryProfession1","PrimaryProfession2","SecondaryProfession1","SecondaryProfession2","SecondaryProfession3"}
local roles={CloseButton="X",MaximizeButton="+",MinimizeButton="-",NextPageButton=">",PrevPageButton="<",PreviousPageButton="<",NextButton=">",PreviousButton="<",ScrollUpButton="^",ScrollDownButton="v",IncrementButton="+",DecrementButton="-",FilterButton="",ResetButton="X",ExpansionDropdownButton="v"}
local function forbidden(frame) return frame.IsForbidden and frame:IsForbidden() end
local function own(region) return region.fsSuiteStyle or region.fsCharacterSkin end
local function named(region) return (region.GetName and region:GetName() or ""):lower() end
function N:Art(region,enabled)
    if not region or not region.GetAlpha or forbidden(region) or own(region) then return end
    local state=self.art[region]
    if not state then
        state={alpha=region:GetAlpha()}; self.art[region]=state
        hooksecurefunc(region,"SetAlpha",function(r)
            if state.enabled and not state.setting then state.setting=true; r:SetAlpha(0); state.setting=false end
        end)
    end
    state.enabled=enabled; state.setting=true; region:SetAlpha(enabled and 0 or state.alpha); state.setting=false
end
function N:IsIcon(frame,region)
    if own(region) then return true end
    local progress=self.progress[frame]
    if progress and progress.fill[region] then return true end
    if frame.GetThumbTexture and frame:GetThumbTexture()==region then return true end
    if frame.GetCheckedTexture and frame:GetCheckedTexture()==region then return true end
    for _,key in ipairs(iconKeys) do if frame[key]==region then return true end end
    local name=named(region)
    if name:find("icon",1,true) or name:find("checkmark",1,true) or name:find("status",1,true) then return true end
    local path=region.GetTexture and region:GetTexture()
    local atlas=region.GetAtlas and region:GetAtlas()
    if type(atlas)=="string" and atlas:find("transmog-nav-slot-",1,true)==1 then return true end
    return type(path)=="string" and path:lower():gsub("/","\\"):find("interface\\icons\\",1,true)
end
function N:Font(region,enabled)
    if not region or not region.GetFont or not region.SetFont or forbidden(region) then return end
    local state=self.fonts[region]
    if not state then
        state={font={region:GetFont()},color=region.GetTextColor and {region:GetTextColor()} or nil}; self.fonts[region]=state
    end
    if enabled then
        FS:ApplyFont(region)
        local c=state.color
        if c and H:Safe(c[1]) and H:Safe(c[2]) and H:Safe(c[3]) and type(c[1])=="number" and type(c[2])=="number" and type(c[3])=="number" and c[1]<.35 and c[2]<.35 and c[3]<.35 then region:SetTextColor(.9,.94,1,c[4] or 1) end
        FS.Themes:Font(region)
    else
        FS.Themes:ReleaseFont(region)
        FS:ReleaseFont(region)
        if state.font[1] then region:SetFont(unpack(state.font)) end
        if state.color then region:SetTextColor(unpack(state.color)) end
    end
end
function N:Control(frame,enabled,glyph)
    local state=self.controls[frame]
    if self.plainControls[frame] then
        if state then state.enabled=false; state.plate:Hide(); state.hover:Hide(); state.flash:Hide(); if state.glyph then state.glyph:Hide() end end
        return
    end
    if not state then
        state={plate=S:Plate(frame)}; self.controls[frame]=state
        state.plate:ClearAllPoints(); state.plate:SetAllPoints(frame); state.plate.gold:Hide(); state.plate.cyan:Hide()
        state.hover=frame:CreateTexture(nil,"HIGHLIGHT"); state.hover.fsSuiteStyle=true; state.hover.ignoreInLayout=true; state.hover:SetAllPoints(); state.hover:SetColorTexture(.12,.72,.86,.16)
        state.flash=frame:CreateTexture(nil,"OVERLAY"); state.flash.fsSuiteStyle=true; state.flash.ignoreInLayout=true; state.flash:SetAllPoints(); state.flash:SetColorTexture(.95,.68,.24,.2); state.flash:Hide()
        state.animation=state.flash:CreateAnimationGroup(); local a=state.animation:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(.18)
        state.animation:SetScript("OnFinished",function() state.flash:Hide() end)
        if not frame.HasScript or frame:HasScript("PostClick") then frame:HookScript("PostClick",function()
            if state.enabled and not InCombatLockdown() then
                state.flash:Show(); state.animation:Stop(); state.animation:Play(); self:Refresh()
            end
        end) end
    end
    state.enabled=enabled; state.plate:SetShown(enabled); state.hover:SetShown(enabled)
    if not enabled then state.flash:Hide() end
    local checked=frame.GetChecked and frame:GetChecked()
    local selected=frame.IsSelected and frame:IsSelected()
    if enabled then
        local active=(H:Safe(checked) and checked) or (H:Safe(selected) and selected)
        local parent=frame.GetParent and frame:GetParent()
        local tab=parent and parent.selectedTab; local id=frame.GetID and frame:GetID()
        if tab and id and H:Safe(tab) and H:Safe(id) and tab==id then active=true end
        local usable=not frame.IsEnabled or frame:IsEnabled()
        if not usable then state.plate:SetBackdropBorderColor(.22,.28,.32,.6)
        elseif active then state.plate:SetBackdropBorderColor(.95,.68,.24,1)
        else state.plate:SetBackdropBorderColor(.12,.55,.65,.8) end
    end
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetCheckedTexture","GetDisabledTexture"}) do
        local r=frame[method] and frame[method](frame)
        if r and not self:IsIcon(frame,r) then self:Art(r,enabled) end
    end
    if glyph and glyph~="" then
        if not state.glyph then state.glyph=FS.Widgets:Label(frame); state.glyph.fsSuiteStyle=true; state.glyph.ignoreInLayout=true; state.glyph:SetPoint("CENTER") end
        state.glyph:SetText(glyph); state.glyph:SetShown(enabled)
    elseif state.glyph then state.glyph:Hide() end
end
function N:Bar(frame,enabled)
    local state=self.bars[frame]
    if not state then
        local t=frame:GetStatusBarTexture(); state={texture=t and t:GetTexture(),plate=S:Plate(frame)}; self.bars[frame]=state
        state.plate:ClearAllPoints(); state.plate:SetAllPoints(frame); state.plate.gold:Hide(); state.plate.cyan:Hide()
    end
    state.plate:SetShown(enabled)
    if enabled then frame:SetStatusBarTexture(H.texture) elseif state.texture then frame:SetStatusBarTexture(state.texture) end
end
function N:Geometry(region,enabled,layout)
    if not region or forbidden(region) then return end
    local state=self.geometry[region]
    if enabled then
        if not state or not state.active then
            state={points=H:SavePoints(region),width=region:GetWidth(),height=region:GetHeight(),active=true}; self.geometry[region]=state
        end
        layout(region)
    elseif state and state.active then
        state.active=false; region:SetSize(state.width,state.height); H:RestorePoints(region,state.points)
    end
end
function N:ProfessionRank(bar,enabled)
    if not bar or forbidden(bar) then return end
    -- Modern rank bars are Frames with a masked Fill, not StatusBars.
    -- Keep the game's fill and rank updates; the trough follows its visual origin.
    local state=self.progress[bar]
    if not state then state={fill={}}; self.progress[bar]=state end
    for _,key in ipairs({"Fill","FillLeft","FillRight","FillMiddle","LeftFill","RightFill"}) do
        local r=bar[key]; if r then state.fill[r]=true end
    end
    if bar.Fill and bar.Fill.GetObjectType then
        local plate=S:Plate(bar); plate:ClearAllPoints()
        plate:SetPoint("TOPLEFT",bar.Fill,"TOPLEFT",0,0)
        plate:SetSize(math.max(1,bar:GetWidth()-8),bar:GetHeight())
        plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
        if bar.Fill:GetObjectType()=="Texture" then
            if not state.visual then
                state.visual=bar:CreateTexture(nil,"ARTWORK"); state.visual.fsSuiteStyle=true; state.visual.ignoreInLayout=true
                state.visual:SetAllPoints(bar.Fill); state.visual:SetColorTexture(.12,.72,.86,1)
            end
            state.visual:SetShown(enabled and bar.Fill:IsShown())
            for fill in pairs(state.fill) do if fill.GetObjectType and fill:GetObjectType()=="Texture" then self:Art(fill,enabled) end end
        end
    end
    -- Forever animates Mask width while Fill stays full width. Share the
    -- original mask so the replacement follows the real skill ratio and easing.
    if state.visual and bar.Mask and state.visual.AddMaskTexture and state.mask~=bar.Mask then
        if state.mask and state.visual.RemoveMaskTexture then state.visual:RemoveMaskTexture(state.mask) end
        state.visual:AddMaskTexture(bar.Mask); state.mask=bar.Mask
    end
    self:Art(bar.Flare,enabled)
    self:Art(bar.Border,enabled); self:Art(bar.Background,enabled)
end
function N:ProfessionScrollBar(bar,enabled)
    if not bar or forbidden(bar) then return end
    local function strip(frame,depth)
        if not frame or forbidden(frame) or own(frame) or depth>3 then return end
        for _,r in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do
            if r.GetObjectType and r:GetObjectType()=="Texture" and not own(r) then self:Art(r,enabled) end
        end
        for _,child in ipairs(frame.GetChildren and {frame:GetChildren()} or {}) do strip(child,depth+1) end
    end
    strip(bar,0)
    local track=bar.Track; if not track or not track.GetFrameLevel then track=bar end
    local plate=S:Plate(track); plate:ClearAllPoints(); plate:SetAllPoints(track)
    plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
    for _,entry in ipairs({{bar.Back or bar.ScrollUpButton,"^"},{bar.Forward or bar.ScrollDownButton,"v"}}) do
        if entry[1] and not forbidden(entry[1]) then self:Control(entry[1],enabled,entry[2]) end
    end
    local thumb=(bar.Track and bar.Track.Thumb) or bar.Thumb or (bar.GetThumbTexture and bar:GetThumbTexture())
    if thumb and not forbidden(thumb) then
        if thumb:GetObjectType()=="Texture" then
            if not thumb.fsProfessionThumb then
                local fill=bar:CreateTexture(nil,"OVERLAY"); fill.fsSuiteStyle=true; fill.ignoreInLayout=true; fill:SetAllPoints(thumb); thumb.fsProfessionThumb=fill
                fill:SetColorTexture(.12,.72,.86,.9)
            end
            thumb.fsProfessionThumb:SetShown(enabled and thumb:IsShown())
        else
            local p=S:Plate(thumb); p:ClearAllPoints(); p:SetAllPoints(thumb); p.gold:Hide(); p.cyan:Hide(); p:SetShown(enabled)
            p:SetBackdropColor(.12,.72,.86,.9)
        end
    end
end
function N:ProfessionFilters(list,enabled)
    if not list or forbidden(list) then return end
    local filter=list.FilterDropdown or list.FilterButton
    local search=list.SearchBox or list.SearchBoxTemplate or list.Search
    if filter and not forbidden(filter) then
        self:Geometry(filter,enabled,function(f)
            f:ClearAllPoints(); f:SetPoint("TOPRIGHT",list,"TOPRIGHT",-24,-8); f:SetSize(104,24)
        end)
        self:Control(filter,enabled,"")
        local label=filter.Text or (filter.GetFontString and filter:GetFontString())
        self:Geometry(label,enabled,function(t)
            t:ClearAllPoints(); t:SetPoint("LEFT",filter,"LEFT",8,0); t:SetPoint("RIGHT",filter,"RIGHT",-22,0)
        end)
        if not filter.fsProfessionCaret then
            local caret=FS.Widgets:Label(filter); caret.fsSuiteStyle=true; caret.ignoreInLayout=true; caret:SetText("v"); caret:SetPoint("RIGHT",filter,"RIGHT",-7,0); FS:ApplyFont(caret,12)
            filter.fsProfessionCaret=caret
        end
        filter.fsProfessionCaret:SetShown(enabled)
        local reset=filter.ResetButton
        self:Geometry(reset,enabled,function(b)
            b:ClearAllPoints(); b:SetPoint("RIGHT",filter,"LEFT",-5,0); b:SetSize(18,18)
        end)
        if reset and not forbidden(reset) then self:Control(reset,enabled,"X") end
        self:Geometry(search,enabled,function(s)
            s:ClearAllPoints(); s:SetPoint("TOPLEFT",list,"TOPLEFT",8,-8); s:SetPoint("RIGHT",filter,"LEFT",-30,0); s:SetHeight(24)
        end)
    end
    self:ProfessionScrollBar(list.ScrollBar or list.scrollBar,enabled)
end
function N:ProfessionTabs(frame,enabled)
    local tabs,seen={},{}
    local function add(tab)
        if tab and tab.GetNormalTexture and not forbidden(tab) and not seen[tab] then seen[tab]=true; tabs[#tabs+1]=tab end
    end
    add(frame.ProfessionsOverviewTab)
    for _,tab in ipairs(frame.rightProfessionTabs or {}) do add(tab) end
    for _,tab in ipairs(frame.ProfessionTabs or {}) do add(tab) end
    for index,tab in ipairs(tabs) do
        self:Geometry(tab,enabled,function(b)
            b:ClearAllPoints(); b:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-40-(index-1)*42); b:SetSize(36,36)
        end)
        self:Tree(tab,enabled,frame)
        local state=self.controls[tab]
        if state then
            if not state.professionIcon then
                local r=tab:CreateTexture(nil,"OVERLAY"); r.fsSuiteStyle=true; r.ignoreInLayout=true; r:SetPoint("CENTER"); r:SetSize(28,28)
                state.professionIcon=r
            end
            local icon=tab.Icon or tab.icon or tab.IconTexture or tab:GetNormalTexture()
            local texture=icon and icon.GetTexture and icon:GetTexture()
            local atlas=icon and icon.GetAtlas and icon:GetAtlas()
            local r=state.professionIcon
            if atlas and r.SetAtlas then r:SetAtlas(atlas) elseif texture then r:SetTexture(texture) else FS:SetMenuIcon(r,"Professions") end
            for _,r in ipairs({tab:GetRegions()}) do if r.GetObjectType and r:GetObjectType()=="Texture" and not own(r) then self:Art(r,enabled) end end
            state.professionIcon:SetShown(enabled)
        end
    end
end
function N:Professions(frame,enabled)
    local page=frame.CraftingPage or frame
    if forbidden(page) then return end
    local legacy=frame==TradeSkillFrame and _G.TradeSkillRankFrame or frame==CraftFrame and _G.CraftRankFrame
    self:ProfessionRank(page.RankBar or page.RankFrame or legacy,enabled)
    self:ProfessionFilters(page.RecipeList or frame.RecipeList,enabled)
    self:ProfessionTabs(frame,enabled)
end
function N:Achievements(frame,enabled)
    local header=frame.Header or _G.AchievementFrameHeader
    if header then
        self:Geometry(header,enabled,function(h) h:ClearAllPoints(); h:SetPoint("TOP",frame,"TOP",0,-2); h:SetSize(math.max(180,frame:GetWidth()-100),28) end)
        self:Geometry(header.Title,enabled,function(t) t:ClearAllPoints(); t:SetPoint("CENTER",header,"CENTER",0,0); t:SetWidth(math.max(150,frame:GetWidth()-240)); t:SetHeight(24) end)
        self:Geometry(header.Points,enabled,function(t) t:ClearAllPoints(); t:SetPoint("RIGHT",header,"RIGHT",-24,0); t:SetHeight(24) end)
        if header.Shield then self:Geometry(header.Shield,enabled,function(t) t:ClearAllPoints(); t:SetPoint("LEFT",header.Points or header,"RIGHT",3,0); t:SetSize(14,14) end) end
    end
    local categories=frame.Categories or _G.AchievementFrameCategories
    if categories then
        for _,key in ipairs({"Background","BG","Bg"}) do self:Art(categories[key],enabled) end
        for _,suffix in ipairs({"BG","Bg","Background"}) do self:Art(_G["AchievementFrameCategories"..suffix],enabled) end
        local plate=S:Plate(categories); plate:ClearAllPoints(); plate:SetAllPoints(categories); plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
    end
end
function N:Tree(frame,enabled,root,depth,deco,role)
    if not frame or forbidden(frame) or own(frame) then return end
    depth=depth or 0; if depth>14 then return end
    -- Map tiles, labels and both native and addon pins live in the canvas subtree.
    if root==WorldMapFrame and frame==root.ScrollContainer then return end
    if frame.widgetSetID or frame.GetWidgetSetID then return end
    local kind=frame.GetObjectType and frame:GetObjectType()
    if kind=="PlayerModel" or kind=="DressUpModel" or kind=="ModelScene" then return end
    if kind=="StatusBar" then self:Bar(frame,enabled) end
    local name=named(frame); local glyph=role
    if name:find("closebutton",1,true) then glyph="X"
    elseif name:find("nextpage",1,true) then glyph=">"
    elseif name:find("prevpage",1,true) or name:find("previouspage",1,true) then glyph="<"
    elseif name:find("scrollup",1,true) then glyph="^"
    elseif name:find("scrolldown",1,true) then glyph="v" end
    if root==WorldMapFrame then
        local border=root.BorderFrame
        local primary=border and border.CloseButton or root.CloseButton
        -- Map overlays reuse close-button art for unrelated navigation controls.
        -- Keep those native rather than manufacturing extra window-close glyphs.
        if frame==root.SidePanelToggle then glyph=QuestMapFrame and QuestMapFrame:IsShown() and "<" or ">"
        elseif glyph=="X" and frame~=primary then
            self:Control(frame,false)
            for _,r in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do if r.GetObjectType and r:GetObjectType()=="Texture" then self:Art(r,false) end end
            return
        end
    end
    if (kind=="Button" or kind=="CheckButton") and not glyph then
        local normal=frame.GetNormalTexture and frame:GetNormalTexture()
        local art=normal and ((normal.GetAtlas and normal:GetAtlas()) or (normal.GetTexture and normal:GetTexture()))
        art=type(art)=="string" and art:lower() or ""
        if art:find("close",1,true) and root~=WorldMapFrame then glyph="X"
        elseif art:find("nextpage",1,true) or art:find("rightarrow",1,true) then glyph=">"
        elseif art:find("prevpage",1,true) or art:find("leftarrow",1,true) then glyph="<"
        elseif art:find("uparrow",1,true) then glyph="^"
        elseif art:find("downarrow",1,true) or art:find("dropdown",1,true) then glyph="v"
        elseif name:find("helpbutton",1,true) or name:find("tutorialbutton",1,true) then glyph="?" end
    end
    if kind=="Button" or kind=="CheckButton" then self:Control(frame,enabled,glyph)
    elseif kind=="EditBox" then
        local p=S:Plate(frame); p:ClearAllPoints(); p:SetAllPoints(frame); p.gold:Hide(); p.cyan:Hide(); p:SetShown(enabled); self:Font(frame,enabled)
    end
    local barTexture=kind=="StatusBar" and frame:GetStatusBarTexture()
    for _,r in ipairs(frame.GetRegions and {frame:GetRegions()} or {}) do
        if not own(r) then
            if r.GetObjectType and r:GetObjectType()=="FontString" then self:Font(r,enabled)
            elseif r.GetObjectType and r:GetObjectType()=="Texture" and r~=barTexture and (glyph and glyph~="" or not self:IsIcon(frame,r)) then
                local layer=r.GetDrawLayer and r:GetDrawLayer(); local rn=named(r)
                local keyed=false; for _,key in ipairs(artKeys) do if frame[key]==r then keyed=true; break end end
                local achievementArt=root==AchievementFrame and (kind=="StatusBar" or rn:match("bg$") or rn:match("left$") or rn:match("right$") or rn:match("middle$"))
                if deco or keyed or achievementArt or kind=="Button" or kind=="CheckButton" or layer=="BACKGROUND" or layer=="BORDER" or rn:find("border",1,true) or rn:find("background",1,true) or rn:find("watermark",1,true) then self:Art(r,enabled) end
            end
        end
    end
    for _,key in ipairs(artKeys) do
        local r=frame[key]
        if r and r.GetObjectType and r:GetObjectType()=="Texture" then self:Art(r,enabled) end
    end
    for _,key in ipairs(panels) do
        local p=frame[key]
        if p and p.GetFrameLevel and not forbidden(p) then
            local plate=S:Plate(p); plate:ClearAllPoints(); plate:SetAllPoints(p); plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
        end
    end
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do
        local decorative=deco or child==frame.NineSlice or child==frame.PortraitContainer
        local childRole; for key,value in pairs(roles) do if child==frame[key] then childRole=value; break end end
        self:Tree(child,enabled,root,depth+1,decorative,childRole)
    end end
end
-- Native map controls have fixed client layouts; fit only their compact
-- navigation text and separate the search field from its quest counter.
function N:MapChrome(frame,enabled)
    -- Work around the canvas: map tiles and quest/player pins keep their art.
    local function strip(node,depth)
        if not node or forbidden(node) or own(node) or depth>2 then return end
        for _,r in ipairs(node.GetRegions and {node:GetRegions()} or {}) do
            if r.GetObjectType and r:GetObjectType()=="Texture" and not own(r) then self:Art(r,enabled) end
        end
        for _,child in ipairs(node.GetChildren and {node:GetChildren()} or {}) do strip(child,depth+1) end
    end
    local function button(b,glyph)
        if not b or forbidden(b) or not b.GetFrameLevel then return end
        self:Control(b,enabled,glyph); strip(b,0)
        local state=self.controls[b]
        if state and state.glyph and glyph=="v" and b:GetWidth()>60 then
            state.glyph:ClearAllPoints(); state.glyph:SetPoint("RIGHT",b,"RIGHT",-8,0)
        end
        if state then FS.Themes:Register(state.plate,"Button") end
        if b.ResetButton then button(b.ResetButton,"R") end
    end
    local nav=frame.NavBar
    if nav then
        strip(nav,0)
        button(nav.CloseButton,"<"); button(nav.DropdownButton,"v"); button(nav.OverflowButton,"v")
    end
    local border=frame.BorderFrame
    if border then button(border.Tutorial,"?"); button(border.HelpButton,"?") end
    button(frame.TrackingOptionsButton,"..."); button(frame.TrackingOptionsDropdown,"...")
    button(frame.SidePanelToggle,frame.QuestLog and frame.QuestLog:IsShown() and "<" or ">")
    button(frame.QuestLogToggleButton,"?"); button(frame.QuestLogToggle,"?")
    local function visit(node,depth)
        if not node or forbidden(node) or own(node) or depth>12 or node==frame.ScrollContainer then return end
        local kind=node.GetObjectType and node:GetObjectType()
        if kind=="DropdownButton" then button(node,node.ResetButton and "..." or "v") end
        for _,key in ipairs({"SettingsButton","SettingsDropdown","SettingsDropdownButton","OptionsButton","OptionsDropdown","QuestOptionsButton"}) do button(node[key],"...") end
        for _,key in ipairs({"FilterButton","FilterDropdown","DropdownButton"}) do button(node[key],"v") end
        local bar=node.ScrollBar or node.scrollBar
        if bar then self:ProfessionScrollBar(bar,enabled) end
        for _,r in ipairs(node.GetRegions and {node:GetRegions()} or {}) do
            if r.GetObjectType and r:GetObjectType()=="Texture" and not own(r) then
                local art=(r.GetAtlas and r:GetAtlas()) or (r.GetTexture and r:GetTexture()) or ""
                local name=named(r).." "..(type(art)=="string" and art:lower() or "")
                if name:find("divider",1,true) or name:find("devider",1,true) or name:find("separator",1,true) or name:find("ornament",1,true) or name:find("filigree",1,true) then self:Art(r,enabled) end
            end
        end
        for _,child in ipairs(node.GetChildren and {node:GetChildren()} or {}) do visit(child,depth+1) end
    end
    visit(frame,0)
    -- Overlay dropdowns are direct canvas-container children. Inspect just
    -- these controls, never descend into its map/pin child.
    local canvas=frame.ScrollContainer
    for _,child in ipairs(canvas and canvas.GetChildren and {canvas:GetChildren()} or {}) do
        if child.GetObjectType and child:GetObjectType()=="DropdownButton" then button(child,child.ResetButton and "..." or "v") end
    end
    local quest=frame.QuestLog or QuestMapFrame
    if quest and quest:GetParent()~=frame then visit(quest,0) end
end
function N:MapText(frame,enabled)
    local function fit(region,width)
        if not enabled or not region or not region.GetFont or not region.GetText or forbidden(region) then return end
        local value=region:GetText(); if not H:Safe(value) or type(value)~="string" then return end
        local path,size,flags=region:GetFont(); if not size or width<=0 then return end
        local measured=region.GetUnboundedStringWidth and region:GetUnboundedStringWidth() or #value*size*.65
        if measured>width then region:SetFont(path,math.max(8,size*width/measured),flags) end
    end
    local function nav(node,depth)
        if not node or depth>6 or forbidden(node) then return end
        for _,region in ipairs({node:GetRegions()}) do fit(region,math.max(1,node:GetWidth()-14)) end
        for _,child in ipairs({node:GetChildren()}) do nav(child,depth+1) end
    end
    if frame.NavBar then nav(frame.NavBar,0) end
    local quest=QuestMapFrame; if not quest or forbidden(quest) then return end
    local search,count
    local function find(node,depth)
        if depth>5 or forbidden(node) then return end
        local name=node.GetName and node:GetName() or ""
        if node.GetObjectType and node:GetObjectType()=="EditBox" and (node==quest.SearchBox or tostring(name):lower():find("search",1,true)) then search=node end
        for _,region in ipairs({node:GetRegions()}) do
            local value=region.GetText and region:GetText()
            if H:Safe(value) and type(value)=="string" and value:match("%d+%s*/%s*%d+") and value:lower():find("quests",1,true) then count=region end
        end
        for _,child in ipairs({node:GetChildren()}) do find(child,depth+1) end
    end
    find(quest,0)
    if search and count then
        local _,size=count:GetFont(); local value=count:GetText() or ""
        local counterWidth=count.GetUnboundedStringWidth and count:GetUnboundedStringWidth() or #value*(size or 14)*.65
        counterWidth=math.min(quest:GetWidth()*.48,math.max(80,counterWidth+8))
        self:Geometry(count,enabled,function(r) r:ClearAllPoints(); r:SetPoint("TOPRIGHT",quest,"TOPRIGHT",-34,-8); r:SetSize(counterWidth,math.max(24,(size or 14)+6)) end)
        self:Geometry(search,enabled,function(r) r:ClearAllPoints(); r:SetPoint("TOPLEFT",quest,"TOPLEFT",8,-5); r:SetWidth(math.max(60,quest:GetWidth()-counterWidth-54)) end)
        fit(count,counterWidth)
        if enabled then
            local path,fontSize,flags=search:GetFont()
            if fontSize then search:SetFont(path,math.min(fontSize,math.max(10,search:GetHeight()-8)),flags) end
            for _,region in ipairs({search:GetRegions()}) do fit(region,search:GetWidth()-24) end
        end
    end
end
function N:Collections(frame,enabled)
    if not self.collectionEventHook and EventRegistry and EventRegistry.RegisterCallback then
        self.collectionEventHook=true
        EventRegistry:RegisterCallback("CollectionsJournal.TabSet",function() C_Timer.After(0,function() self:Refresh() end) end,self)
    end
    -- Inline mount information extends beyond its native button's hit rectangle.
    -- A full button plate there overlaps the icon/name; keep that content plain.
    local display=MountJournal and MountJournal.MountDisplay
    local info=display and display.InfoButton
    if info then self.plainControls[info]=true; self:Control(info,false) end
    local toggle=display and display.ModelScene and display.ModelScene.TogglePlayer
    if toggle then self:Control(toggle,enabled); self:Font(toggle.TogglePlayerText,enabled) end
    local container=frame.TabContainer
    for _,tab in ipairs(container and container.Tabs or {}) do
        if not forbidden(tab) then
            self:Control(tab,enabled)
            for _,r in ipairs(tab.GetRegions and {tab:GetRegions()} or {}) do
                if r.GetObjectType and r:GetObjectType()=="Texture" and not self:IsIcon(tab,r) then self:Art(r,enabled) end
            end
        end
    end
end
function N:Window(frame,definition)
    if forbidden(frame) then return end
    local state=self.windows[frame]
    local enabled=FS:IsModuleEnabled(definition[2]) and (not FS.db.extras or FS.db.extras.nativeWindows~=false)
    if definition[5] then local module=FS.modules[definition[2]]; enabled=enabled and module:Data()[definition[5]] end
    if state and not frame:IsShown() and state.enabled==enabled then return end
    if not state then
        state={definition=definition,plate=S:Plate(frame)}; self.windows[frame]=state
        state.plate:SetBackdropColor(.018,.027,.038,.98)
        state.header=CreateFrame("Frame",nil,frame); state.header.fsSuiteStyle=true; state.header.ignoreInLayout=true; state.header:EnableMouse(false)
        state.header:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
        state.header:SetPoint("TOPLEFT",0,0); state.header:SetPoint("TOPRIGHT",0,0); state.header:SetHeight(30)
        state.fill=state.header:CreateTexture(nil,"BACKGROUND"); state.fill:SetAllPoints(); state.fill:SetColorTexture(.025,.045,.06,.95)
        state.line=state.header:CreateTexture(nil,"ARTWORK"); state.line:SetColorTexture(.95,.68,.24,.65); state.line:SetHeight(1); state.line:SetPoint("BOTTOMLEFT",8,0); state.line:SetPoint("BOTTOMRIGHT",-8,0)
        state.icon=state.header:CreateTexture(nil,"OVERLAY"); state.icon:SetSize(26,26); state.icon:SetPoint("TOPLEFT",6,-2); FS:SetMenuIcon(state.icon,definition[3])
        FS.Layout:Register(definition[1],frame,definition[4])
        frame:HookScript("OnShow",function() self:Refresh() end)
        if definition[2]=="Professions" then frame:HookScript("OnSizeChanged",function() self:Refresh() end) end
    end
    state.enabled=enabled
    state.plate:SetShown(enabled); state.header:SetShown(enabled)
    if FS.Themes:Current()==10 then state.fill:SetColorTexture(.48,.37,.21,.98)
    else state.fill:SetColorTexture(.025,.045,.06,.95) end
    if definition[2]=="Professions" then self:Professions(frame,enabled) end
    if definition[1]=="CollectionsJournal" or definition[1]=="WardrobeFrame" then self:Collections(frame,enabled) end
    self:Tree(frame,enabled,frame)
    -- Generic traversal precedes the final targeted pass so scroll arrows and
    -- reset controls retain their glyphs even when they have unnamed children.
    if definition[2]=="Professions" then self:Professions(frame,enabled) end
    if definition[1]=="CollectionsJournal" or definition[1]=="WardrobeFrame" then self:Collections(frame,enabled) end
    local portrait=_G[definition[1].."Portrait"]; if portrait then self:Art(portrait,enabled) end
    if definition[1]=="ProfessionsBookFrame" then
        for _,name in ipairs({"PrimaryProfession1","PrimaryProfession2","SecondaryProfession1","SecondaryProfession2","SecondaryProfession3"}) do
            local p=_G[name]
            if p and not forbidden(p) then
                local plate=S:Plate(p); plate:ClearAllPoints(); plate:SetAllPoints(p); plate.gold:Hide(); plate.cyan:Hide(); plate:SetShown(enabled)
                self:Tree(p,enabled,frame)
            end
        end
    end
    if definition[1]=="WorldMapFrame" then self:MapChrome(frame,enabled); self:MapText(frame,enabled) end
    if definition[1]=="AchievementFrame" then
        self:Achievements(frame,enabled)
        for _,suffix in ipairs({"MetalBorderTop","MetalBorderBottom","MetalBorderLeft","MetalBorderRight","MetalBorderTopLeft","MetalBorderTopRight","MetalBorderBottomLeft","MetalBorderBottomRight","WoodBorderTopLeft","WoodBorderTopRight","WoodBorderBottomLeft","WoodBorderBottomRight","WaterMark","StatsBG"}) do self:Art(_G["AchievementFrame"..suffix],enabled) end
    end
end
function N:Refresh()
    if self.refreshing or not FS.initialized or not FS.db or InCombatLockdown() then return end
    self.refreshing=true
    for _,definition in ipairs(self.definitions) do
        local f=_G[definition[1]]
        if f then
            local parent=f.GetParent and f:GetParent(); local nested=false
            while parent do if self.windows[parent] then nested=true; break end; parent=parent.GetParent and parent:GetParent() end
            if not nested then self:Window(f,definition) end
        end
    end
    self.refreshing=false
end
