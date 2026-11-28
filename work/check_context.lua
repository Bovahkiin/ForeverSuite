-- TEST: Context fixture restores host ownership before each integration scenario
function ContextFixture()
    local FS=ForeverSuite; local C=FS.Context
    if C.host then C:HideHost(C.host) end
    C:Clear(); ResetTest(); FS.Extensions:Normalize()
    local host=CreateFrame('Frame',nil,UIParent); host:SetSize(600,500); host:SetPoint('CENTER'); host:Show()
    FS.WindowManager.native[host]={name='ContextFixture'}
    C:Attach(host,{entries=function() return {} end})
    return FS,C,host
end

-- TEST: Context tools preserve their native host and use compact paged lists
local FS,C,host=ContextFixture(); local M=FS.modules.Map
FS.db.map.pins={}; for i=1,12 do FS.db.map.pins[i]={map=1,x=.1,y=.2,name='Pin '..i} end
assert(C:Open(host,'Map')); local f=M.window
assert(host:IsShown() and f:IsShown() and f.fsContextHost==host and f.fsContextRows==5)
assert(f:GetWidth()==500 and f.visibleRows==5 and not f.cells[6]:IsShown() and not f.control:IsShown())
f.next:Click(); assert(f.cells[1].row.pin==6 and M.page==2)
assert(not FS.db.layout.frames['Tool:Map']); Drain(); assert(select(2,f:GetPoint())~=f)
FS.WindowManager:NativeShown(host,'ContextFixture'); assert(f:IsShown() and host:IsShown())
host:Hide(); Drain(); assert(not f:IsShown() and not f.fsContextHost and not C.host)
FS.WindowManager.native[host]=nil

-- TEST: Context forms keep the source screen open and return to the same host after saving
local FS,C,host=ContextFixture(); local W=FS.modules.Workbench
assert(C:Open(host,'Workbench','Item checklists'))
C:Run(host,function() C:ItemChecklist(host,{id=123}) end)
local form=FS.Extensions.form
assert(host:IsShown() and form:IsShown() and form.fsContextHost==host)
form.edits[1]:SetText('Test checklist'); form.edits[2]:SetText('4'); form.save:Click()
assert(FS.db.extras.checklists['Test checklist'][123]==4 and host:IsShown() and W.window:IsShown())
assert(W.window.fsContextHost==host); host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context closing and global navigation restore normal tool geometry and all-tools navigation
local FS,C,host=ContextFixture(); local W=FS.modules.Workbench
C:Open(host,'Workbench','Alt Tracker'); local f=W.window
assert(not f.section:IsShown() and not f.previousSection:IsShown())
FS:ShowConfig(); Drain()
assert(not host:IsShown() and not f.fsContextHost and FS.window:IsShown())
W:ShowWindow(); assert(f.control:IsShown() and f.section:IsShown() and f.previousSection:IsShown() and f:GetWidth()==660); f:Hide(); FS.WindowManager.native[host]=nil

-- TEST: Context menus are lazy and repeated discovery does not duplicate buttons or event polling
local FS,C,host=ContextFixture(); local state=C.hosts[host]
assert(state.button and not state.menu)
C:Attach(host,{entries=function() return {} end}); assert(C.hosts[host]==state)
C:Menu(host,{{label='Disabled',owner='GearAdvisor',run=function() error('Must stay disabled') end}})
local menu=state.menu; assert(menu and menu:IsShown())
FS.db.gearAdvisor.enabled=false; C:Menu(host,{}); C:Menu(host,{{label='Disabled',owner='GearAdvisor',run=function() error('Must stay disabled') end}})
assert(not menu.buttons[1]:IsEnabled()); menu.buttons[1]:Click()
assert(not C.events:GetScript('OnUpdate')); FS.db.gearAdvisor.enabled=true
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context screen launchers keep native styling out and chat tools do not live between tabs
local FS,C,host=ContextFixture(); local button=C.hosts[host].button
assert(button.fsSuiteStyle and button.ignoreInLayout)
local old1,old2,oldTab=ChatFrame1,ChatFrame2,ChatFrame1Tab
ChatFrame1=CreateFrame('ScrollingMessageFrame',nil,UIParent); ChatFrame2=nil
ChatFrame1Tab=CreateFrame('Button',nil,UIParent); ChatFrame1Tab:SetPoint('LEFT',UIParent,'LEFT',23,7)
local point={ChatFrame1Tab:GetPoint()}; C:Discover()
local chat=C.hosts[ChatFrame1]; assert(chat.button:GetText()=='Chat tools')
assert(chat.button.point[1]=='BOTTOMRIGHT' and chat.button.point[2]==ChatFrame1 and chat.button.point[3]=='TOPRIGHT')
assert(not C.hosts[ChatFrame1Tab] and ChatFrame1Tab.point[4]==point[4])
ChatFrame1:Hide(); ChatFrame1,ChatFrame2,ChatFrame1Tab=old1,old2,oldTab
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context bag launcher has a visible name and preserves category controls
local FS,C,host=ContextFixture(); local B=FS.modules.Bags
B:SetStorageLayout('Vault')
B:ShowWindow(); C:Discover(); B:Refresh()
assert(B.window.fsContextLauncher:GetText()=='Bag tools' and B.window.sidebarTitle:GetText()=='CATEGORIES')
assert(B.window.fsContextLauncher:GetParent()==B.window and B.window.fsContextLauncher.point[1]=='BOTTOM')
B.window.fsContextLauncher:Click(); assert(C.hosts[B.window].menu:IsShown())
B.window:Hide(); host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Styled native opening stays hidden through late panel positioning and reveals its final anchor
local FS,C,host=ContextFixture(); local W=FS.WindowManager
local f=CreateFrame('Frame',nil,UIParent); f:SetAlpha(.8); local calls=0
assert(W:PrepareOpen(f,function() calls=calls+1; f:ClearAllPoints(); f:SetPoint('CENTER',UIParent,'CENTER',123,45) end))
C_Timer.After(0,function() assert(f:GetAlpha()==0); f:ClearAllPoints(); f:SetPoint('LEFT',UIParent,'LEFT',0,0) end)
Drain(); assert(calls==2 and f:GetAlpha()==.8 and select(4,f:GetPoint())==123)
f:Hide(); host:Hide(); FS.WindowManager.native[host]=nil

-- TEST: Meter reports are separate from native headers and a container does not duplicate session tools
local FS,C,host=ContextFixture(); local old,oldSession=DamageMeter,DamageMeterSessionWindow1
DamageMeter=CreateFrame('Frame',nil,UIParent); DamageMeterSessionWindow1=CreateFrame('Frame',nil,DamageMeter)
DamageMeterSessionWindow1:SetSize(400,130); C:Discover()
local root=C.hosts[DamageMeter].button; local button=C.hosts[DamageMeterSessionWindow1].button
assert(not root:IsShown() and button:GetText()=='Report' and button.point[1]=='BOTTOMRIGHT' and button.point[5]==6)
DamageMeterSessionWindow1:Hide(); DamageMeter:Hide(); DamageMeter,DamageMeterSessionWindow1=old,oldSession
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Native guild styling preserves click scripts compact text native tab anchors and member detail backgrounds
local FS,C,host=ContextFixture(); local N=FS.NativeWindows; local old=CommunitiesFrame
local f=CreateFrame('Frame',nil,UIParent); CommunitiesFrame=f; f:SetSize(814,426)
f.ChatTab=CreateFrame('CheckButton',nil,f); f.ChatTab:SetSize(28,26); f.ChatTab:SetPoint('TOPLEFT',f,'TOPRIGHT',0,-36)
f.GuildMemberListDropdown=CreateFrame('DropdownButton',nil,f); local dropdown=f.GuildMemberListDropdown
dropdown:SetSize(180,22); dropdown.Text=dropdown:CreateFontString(); dropdown.Text:SetFont('native',11,''); dropdown.Text:SetText('Guild')
local clicks=0; dropdown:SetScript('OnClick',function() clicks=clicks+1 end)
f.GuildMemberDetailFrame=CreateFrame('Frame',nil,f); f.GuildMemberDetailFrame:SetFrameLevel(1000)
f.GuildMemberDetailFrame.Name=f.GuildMemberDetailFrame:CreateFontString(); f.GuildMemberDetailFrame.Name:SetText('Member')
FS.db.typography.global.size=24; N:Refresh(f)
assert(select(2,dropdown.Text:GetFont())==11 and N.controls[dropdown].glyph:GetText()=='v')
assert(f.ChatTab.point[4]==0 and f.ChatTab.point[5]==-36 and f.ChatTab:GetWidth()==28)
dropdown:Click(); assert(clicks==1)
assert(FS.Style.plates[f.GuildMemberDetailFrame]:IsShown())
FS.db.typography.global.size=0; f:Hide(); CommunitiesFrame=old; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Native guild rich text never enters plain font APIs during open deferred placement or discovery
local FS,C,host=ContextFixture(); local N,W=FS.NativeWindows,FS.WindowManager
local old=CommunitiesFrame
local f=CreateFrame('Frame',nil,UIParent); CommunitiesFrame=f; f:SetSize(814,426); f:SetAlpha(.75)
f.GuildDetailsFrame=CreateFrame('Frame',nil,f)
local html=CreateFrame('SimpleHTML',nil,f.GuildDetailsFrame); local calls=0
html.GetFont=function(_,textType) calls=calls+1; assert(textType,'SimpleHTML GetFont requires textType'); return 'native-html',13,'' end
html.SetFont=function(_,textType,path,height) calls=calls+1; assert(textType and path and height,'SimpleHTML SetFont requires textType') end
html.GetTextColor=function(_,textType) calls=calls+1; assert(textType,'SimpleHTML GetTextColor requires textType'); return 1,1,1,1 end
local clicked=function() end; html:SetScript('OnHyperlinkClick',clicked)
local label=f.GuildDetailsFrame:CreateFontString(); label:SetFont('native-label',12,''); label:SetText('Guild information')
N:Refresh(f); assert(not N.refreshing and N.fonts[label] and not N.fonts[html] and calls==0)
assert(W:PrepareOpen(f,function() N:Refresh(f) end)); Drain()
assert(f:GetAlpha()==.75 and not W.openingFrames[f])
FS.Style:Discover(); N:Refresh(); N:NativeFont(html,false)
assert(calls==0 and html:GetScript('OnHyperlinkClick')==clicked and not N.refreshing)
FS.db.guild.styleWindow=false; N:Refresh(f); assert(calls==0)
FS.db.guild.styleWindow=true; f:Hide(); CommunitiesFrame=old; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Native guild tab changes keep the current position synchronously without an opening fade or delayed layout
local FS,C,host=ContextFixture(); local N,W,L=FS.NativeWindows,FS.WindowManager,FS.Layout
local old,position,target=CommunitiesFrame,FS.db.layout.frames.CommunitiesFrame,L.targets.CommunitiesFrame
local f=CreateFrame('Frame',nil,UIParent); f:Hide(); f:SetSize(814,426); f:SetPoint('CENTER',UIParent,'CENTER',44,33); f:SetAlpha(.8)
f.SetDisplayMode=function(self)
    self:ClearAllPoints(); self:SetScale(.9); self:SetPoint('TOPLEFT',UIParent,'TOPLEFT',20,-80)
end
CommunitiesFrame=f; FS.db.layout.frames.CommunitiesFrame=nil
W:Install(); N:Refresh(f); f:Show()
assert(f:GetAlpha()==.8 and not W.openingFrames[f] and W.native[f].guildPoints)
Drain(); local expected={f:GetPoint()}; local scale=f:GetScale()
for i=1,20 do
    f:SetDisplayMode()
    assert(f:GetAlpha()==.8 and select(4,f:GetPoint())==expected[4] and select(5,f:GetPoint())==expected[5])
    assert(f:GetScale()==scale and not N.guildPending[f] and not L.queued.CommunitiesFrame)
end
FS.db.layout.frames.CommunitiesFrame={x=200,y=600,scale=.85}; L:Apply('CommunitiesFrame')
expected={f:GetPoint()}; f:SetDisplayMode()
assert(f:GetScale()==.85 and select(4,f:GetPoint())==expected[4] and select(5,f:GetPoint())==expected[5])
C:Discover(); local button=C.hosts[f].button
assert(button.point[1]=='TOPRIGHT' and button.point[2]==f and button.point[3]=='BOTTOMRIGHT' and button.point[5]<0)
f:Hide(); assert(not W.native[f].guildPoints)
CommunitiesFrame=old; FS.db.layout.frames.CommunitiesFrame=position; L.targets.CommunitiesFrame=target
host:Hide(); Drain(); W.native[host]=nil

-- TEST: Native guild styling skips hidden page trees and styles them once their display mode becomes visible
local FS,C,host=ContextFixture(); local N=FS.NativeWindows; local old=CommunitiesFrame
local f=CreateFrame('Frame',nil,UIParent); CommunitiesFrame=f
f.GuildDetailsFrame=CreateFrame('Frame',nil,f); local page=f.GuildDetailsFrame; page:Hide()
local children=page.GetChildren; page.GetChildren=function() error('Hidden page traversed') end
local label=page:CreateFontString(); label:SetFont('native-page',12,''); label:SetText('Guild information')
f.SetDisplayMode=function() page:Show() end
N:Refresh(f); assert(not N.fonts[label])
page.GetChildren=children; f:SetDisplayMode(); assert(N.fonts[label] and not N.guildPending[f])
f:Hide(); CommunitiesFrame=old; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Native talent search keeps its handler and exposes the search options caret and help
local FS,C,host=ContextFixture(); local N=FS.NativeWindows; local old=PlayerSpellsFrame
local f=CreateFrame('Frame',nil,UIParent); PlayerSpellsFrame=f; f:SetSize(1218,708)
f.TalentsFrame=CreateFrame('Frame',nil,f); local talents=f.TalentsFrame
talents.SearchOptionsDropdown=CreateFrame('DropdownButton',nil,talents); talents.SearchOptionsDropdown:SetSize(24,24)
local clicks=0; talents.SearchOptionsDropdown:SetScript('OnClick',function() clicks=clicks+1 end)
talents.ClassBackground=talents:CreateTexture(); talents.ClassBackground:SetAlpha(.8)
N:Refresh(f); local control=N.controls[talents.SearchOptionsDropdown]
assert(control.glyph:IsShown() and control.glyph:GetText()=='v')
assert(talents.SearchOptionsDropdown.fsHelp:find('passive',1,true)); talents.SearchOptionsDropdown:Click(); assert(clicks==1)
assert(talents.ClassBackground:GetAlpha()==.22 and N.windows[f].watermark:IsShown())
FS.db.extras.nativeWindows=false; N:Refresh(f)
assert(not control.glyph:IsShown() and talents.ClassBackground:GetAlpha()==.8 and not N.windows[f].watermark:IsShown())
FS.db.extras.nativeWindows=true; f:Hide(); PlayerSpellsFrame=old; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Control Center repaint retains hidden cards and window visibility and reuses its decoration
local FS,C,host=ContextFixture(); FS:ShowWorkspacePage('home'); local f=FS.window
FS:RefreshConfig(); local rule=f.headerRule; assert(rule and f.brandWatermark)
for _,card in pairs(f.cards) do assert(not card.card:IsShown()) end
f:Hide(); FS:PaintControlCenter(); assert(not f:IsShown() and f.headerRule==rule)
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context surface repaint keeps the nine-slice continuous and uses a white base for header gradients
local FS,C,host=ContextFixture(); local N,T=FS.NativeWindows,FS.Themes
local oldTheme=FS.db.appearance.theme; assert(T:Set('Celestial Forge'))
local plate=FS.Style:Plate(host); N:Surface(plate,true)
local parts=T.frames[plate].parts; assert(#parts==9)
for _,part in ipairs(parts) do assert(part:GetAlpha()==parts[1]:GetAlpha() and part:GetAlpha()>=.5) end
assert(plate.fsFlatSkin.background.color[1]>=.09 and plate.fsFlatSkin.background.color[4]==1)
FS:ShowConfig(); local f=FS.window; local oldGradient,oldColor=f.headerFill.SetGradient,CreateColor
CreateColor=function(r,g,b,a) return {r,g,b,a} end
f.headerFill.SetGradient=function(self,direction,first,last)
    assert(self.color[1]==1 and self.color[2]==1 and self.color[3]==1,'Gradient base was tinted dark')
    assert(direction=='VERTICAL' and first[1]>=.1 and last[1]>=.1)
end
FS:PaintControlCenter(); f.headerFill.SetGradient=oldGradient; CreateColor=oldColor
assert(f.brandWatermark and f.brandWatermark:GetAlpha()>0)
f:Hide(); assert(T:Set(oldTheme)); host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context native dropdowns share the button skin with one caret and retain their original input
local FS,C,host=ContextFixture(); local N=FS.NativeWindows; local button=CreateFrame('Button',nil,host); button:SetSize(24,24)
button.Arrow=button:CreateTexture(); button.Arrow:SetAtlas('UI-Common-Dropdown-Arrow'); button.Arrow:SetAlpha(.7)
local clicks=0; button:SetScript('OnClick',function() clicks=clicks+1 end)
N:Dropdown(button,true,'Search options'); local control=N.controls[button]
assert(FS.Themes.frames[control.plate].kind=='Button' and button.Arrow:GetAlpha()==0 and control.glyph:IsShown())
button:Click(); assert(clicks==1)
N:Dropdown(button,false); assert(button.Arrow:GetAlpha()==.7 and not control.glyph:IsShown())
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context profession overview keeps progress and uses one background instead of five nested panels
local FS,C,host=ContextFixture(); local N=FS.NativeWindows; local old=ProfessionsBookFrame
local f=CreateFrame('Frame',nil,UIParent); ProfessionsBookFrame=f
for _,key in ipairs({'PrimaryProfession1','PrimaryProfession2','SecondaryProfession1','SecondaryProfession2','SecondaryProfession3'}) do
    f[key]=CreateFrame('Frame',nil,f); f[key]:SetSize(250,130)
end
local bar=CreateFrame('StatusBar',nil,f.PrimaryProfession1); bar:SetStatusBarTexture('native-progress'); bar:SetMinMaxValues(0,75); bar:SetValue(53)
N:Refresh(f); assert(N.windows[f].watermark:IsShown() and bar:GetValue()==53)
for _,key in ipairs({'PrimaryProfession1','PrimaryProfession2','SecondaryProfession1','SecondaryProfession2','SecondaryProfession3'}) do assert(not FS.Style.plates[f[key]]:IsShown()) end
assert(f.PrimaryProfession1.fsProfessionRule:IsShown() and f.PrimaryProfession2.fsProfessionRule:IsShown())
f:Hide(); ProfessionsBookFrame=old; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context bank grids retain their own inventory layout when opened beside another screen
local FS,C,host=ContextFixture(); local K=FS.modules.Bank
K.open=true
C:Open(host,'Bank')
assert(K.window:IsShown() and K.window.fsContextHost==host and K.window.grid and not K.window.fsContextRows)
K.window:LayoutText(); assert(host:IsShown() and #K.window.cells==0)
host:Hide(); Drain(); K.open=false; FS.WindowManager.native[host]=nil

-- TEST: Context guild recipient labels and actions use the same last selected member
local FS,C,host=ContextFixture()
C.nativeGuildHost=host; C.nativeGuildName='Fresh-Realm'; FS.modules.Guild.selected={name='Stale-Realm'}
local entries=C:GuildEntries(host); assert(entries[3].label=='Whisper Fresh-Realm')
C.playerSelection={host=host,kind='Guild',name='Panel-Realm'}
entries=C:GuildEntries(host); assert(entries[3].label=='Whisper Panel-Realm')
local tell,old=ChatFrame_SendTell,FS.modules.Guild.selected
ChatFrame_SendTell=function(name) assert(name=='Panel-Realm') end
C:Run(host,function() entries[3].run(host) end)
ChatFrame_SendTell=tell; FS.modules.Guild.selected=nil; C.nativeGuildHost=nil; C.nativeGuildName=nil
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context temporary child hosts close attached tools when their native tab disappears
local FS,C,host=ContextFixture(); local tab=CreateFrame('Frame',nil,host); tab:Show()
C:Open(tab,'Workbench','Alt Tracker'); assert(FS.modules.Workbench.window:IsShown())
tab:Hide(); Drain(); assert(not FS.modules.Workbench.window:IsShown() and not C.host)
host:Hide(); FS.WindowManager.native[host]=nil

-- TEST: Context inventory and bank menus never reuse a stale selection from another container
local FS,C,host=ContextFixture(); local B,K=FS.modules.Bags,FS.modules.Bank
local old=B.selected; local bankWindow=K:CreateWindow(); K.selected=nil; B.selected={id=55}
assert(C:SelectedItem(bankWindow)==nil and C:SelectedItem(B.window)==B.selected)
K.selected={id=66}; assert(C:SelectedItem(bankWindow).id==66)
B.selected=old; K.selected=nil; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context opening global screens closes HUD popovers as well as attached tool panels
local FS,C,host=ContextFixture(); C:Menu(host,{{label='Read only',run=function() end}})
assert(C.hosts[host].menu:IsShown()); FS:ShowConfig(); assert(not C.hosts[host].menu:IsShown())
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context docked tools retain native ancestors when their launcher belongs to a map canvas
local FS,C,host=ContextFixture(); local canvas=CreateFrame('Frame',nil,host); canvas:Show()
C:Open(canvas,'Workbench','Route Library')
assert(host:IsShown() and canvas:IsShown() and FS.modules.Workbench.window.fsContextHost==canvas)
canvas:Hide(); C:HideHost(canvas); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context equipment middle-click plans one slot without changing secure item actions
local FS,C,host=ContextFixture(); local character=FS.modules.Character; local advisor=FS.modules.GearAdvisor
local oldSlots,oldCharacter,oldPlanner,oldLevel=character.slots,CharacterFrame,advisor.PlannerRows,UnitLevel
CharacterFrame=host; local button=CreateFrame('Button',nil,host); button.slot=16
button:SetAttribute('type2','item'); button:SetAttribute('item2','16'); character.slots={[16]=button}
UnitLevel=function() return 60 end
advisor.PlannerRows=function() return {{id=1,slot=16,text='Weapon'},{id=2,slot=1,text='Helmet'}},{},'test',false end
C:Discover(); button:Click('MiddleButton')
assert(FS.modules.Workbench.contextSlot==16 and #FS.modules.Workbench.rows==1 and FS.modules.Workbench.rows[1].id==1)
assert(button:GetAttribute('type2')=='item' and button:GetAttribute('item2')=='16')
host:Hide(); Drain(); character.slots,CharacterFrame,advisor.PlannerRows,UnitLevel=oldSlots,oldCharacter,oldPlanner,oldLevel
FS.WindowManager.native[host]=nil

-- TEST: Context native guild selection focuses the correct private-note record instead of a stale row
local FS,C,host=ContextFixture(); local G=FS.modules.Guild; local build=G.Build
local wanted=FS.Extensions:PlayerKey('Wanted-Realm')
G.Build=function(self) self.rows={{name='Wanted-Realm',localKey=wanted,text='Wanted'}} end
C.nativeGuildHost=host; C.nativeGuildName='Wanted-Realm'; G.selected={name='Old-Realm'}
C:Run(host,function() C:GuildNotes(host) end)
assert(FS.modules.Workbench.selected and FS.modules.Workbench.selected.id==wanted and host:IsShown())
G.Build=build; G.selected=nil; C.nativeGuildName=nil; C.nativeGuildHost=nil
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context menus clamp large text to a small viewport and preserve saved mover positions
local FS,C,host=ContextFixture(); local width,height=UIParent:GetWidth(),UIParent:GetHeight()
UIParent:SetSize(800,600); FS.db.layout.frames['Tool:Map']={x=25,y=300,scale=1}
FS.db.typography.global.size=24; FS.db.typography.global.scale=1.5; FS.Typography:Apply()
C:Open(host,'Map'); local f=FS.modules.Map.window
assert(f:GetHeight()*f:GetScale()<=UIParent:GetHeight()-32 and f:GetWidth()*f:GetScale()<=UIParent:GetWidth()-32)
Drain(); assert(FS.db.layout.frames['Tool:Map'].x==25 and FS.db.layout.frames['Tool:Map'].y==300)
host:Hide(); Drain(); UIParent:SetSize(width,height)
FS.db.typography.global.size=0; FS.db.typography.global.scale=1; FS.Typography:Apply(); FS.WindowManager.native[host]=nil

-- TEST: Context native-screen menu entries expose existing tools with working owners and callbacks
local FS,C,host=ContextFixture()
for _,spec in ipairs(C.nativeSpecs) do
    local entries=spec.entries(host); assert(#entries>0,spec.name)
    for _,entry in ipairs(entries) do
        assert(type(entry.label)=='string' and entry.label~='')
        if entry.enabled~=false then assert(type(entry.run)=='function',entry.label) end
        if entry.owner then assert(FS.modules[entry.owner],entry.label) end
    end
end
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context actions refuse combat and preserve the previous screen if an action fails
local FS,C,host=ContextFixture(); TEST.combat=true
assert(not C:Open(host,'Map') and not C.host); TEST.combat=false
C:Open(host,'Map'); local ok=pcall(function() C:Run(host,function() error('Context test failure') end) end)
assert(not ok and host:IsShown() and not C.host and not FS.modules.Map.window.fsContextHost)
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context auction shopping uses the shared goals without changing profile filters
local FS,C,host=ContextFixture(); local A=FS.modules.AuctionHouse
FS.db.auctionHouse.shoppingOnly=false; FS.db.auctionHouse.shopping[42]=3
A:StoreScan({[43]={price=10,time=1,kind='per item'}})
C:Shopping(host); assert(#A.rows==1 and A.rows[1].id==42 and not FS.db.auctionHouse.shoppingOnly)
host:Hide(); Drain(); A:Build(); assert(#A.rows==2 and not A.contextShoppingOnly)
FS.WindowManager.native[host]=nil

-- TEST: Context selected-item shopping requests quantity only and preserves the mailbox or inventory host
local FS,C,host=ContextFixture()
C:Run(host,function() C:ItemShopping(host,{id=77}) end)
local form=FS.Extensions.form; assert(form.fieldCount==1 and host:IsShown())
form.edits[1]:SetText('8'); form.save:Click()
assert(FS.db.auctionHouse.shopping[77]==8 and host:IsShown() and FS.modules.AuctionHouse.window.fsContextHost==host)
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context profession tools carry the selected native recipe into the existing material planner
local FS,C,host=ContextFixture(); local P=FS.modules.Professions
local oldRoot,oldBuild,oldSelect=ProfessionsFrame,P.Build,P.OnSelect; local selected
ProfessionsFrame={CraftingPage={SchematicForm={GetRecipeInfo=function() return {recipeID=99} end}}}
P.Build=function(self) self.rows={{id=99,name='Native recipe',modern=true}} end
P.OnSelect=function(self,row,quantity) selected=row.id; self.materials={}; self.quantity=quantity end
C:Profession(host,1,true)
assert(selected==99 and P.quantity==1 and host:IsShown() and P.window.fsContextHost==host)
ProfessionsFrame,P.Build,P.OnSelect=oldRoot,oldBuild,oldSelect
P:ClearPlan(); host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context spell menu uses a hovered spell ID and keeps reminders in the existing module store
local FS,C,host=ContextFixture(); C.spellID=1459; C.spellHost=host
local entries=C:SpellEntries(host); assert(entries[3].label:find('Track cooldown',1,true))
C:Run(host,function() entries[3].run(host) end)
assert(FS.db.cooldowns.spells[1459]=='General' and host:IsShown())
host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context tracker right-click actions retain normal left-click and add only known destinations
local FS,C,host=ContextFixture(); local Q,M=FS.modules.Quests,FS.modules.Map
local button=CreateFrame('Button',nil,host); local clicks=0; button:SetScript('OnClick',function() clicks=clicks+1 end)
local old=M.QuestDestination; M.QuestDestination=function() return {map=1,x=.2,y=.3,name='Quest'} end
local quest={id=17,title='Quest'}; C:BindExisting(host,button,function(h) return C:QuestEntries(h,quest) end)
button:Click(); assert(clicks==1)
button:Click('RightButton'); assert(clicks==1 and C.hosts[host].menu:IsShown())
C.hosts[host].menu.buttons[2]:Click(); assert(#FS.db.extras.waypointQueue==1 and FS.db.extras.waypointQueue[1].map==1)
M.QuestDestination=old; host:Hide(); Drain(); FS.WindowManager.native[host]=nil

-- TEST: Context action bar quick settings use supported percent values and the existing preference fields
local FS,C,host=ContextFixture(); FS.db.actionBars.fade=100
local entries=C:ActionBarEntries(); C:Run(host,function() entries[3].run(host) end)
assert(FS.db.actionBars.fade==50); entries[3].run(host); assert(FS.db.actionBars.fade==10)
entries[3].run(host); assert(FS.db.actionBars.fade==100)
host:Hide(); Drain(); FS.WindowManager.native[host]=nil
