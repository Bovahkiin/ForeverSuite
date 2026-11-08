local _,FS=...
local P={names={"Layout 1","Compact","Classic","Keep current"}}; FS.LayoutPresets=P
P.descriptions={
    ["Layout 1"]="Your reference layout: player and target above centered bars, pet below player, chat left, minimap and quests right.",
    Compact="Player and target close to the centered bars, with more open space around the character.",
    Classic="Player and target near the upper-left corner, with navigation and quests on the right.",
    ["Keep current"]="Keep all current positions and sizes. No game layout is changed.",
}
local function copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=copy(v) end; return out
end
function P:Valid(name) return self.descriptions[name]~=nil end
function P:Plan(name,w,h)
    if not self:Valid(name) or name=="Keep current" or not FS.Tools:Number(w) or not FS.Tools:Number(h) or w<640 or h<360 then return end
    local s=math.max(.6,math.min(1,w/2133.3333,h/1200)); local frames={}
    local function at(id,x,y,scale) frames[id]={x=w*x,y=h*y,scale=math.max(.6,math.min(1.4,s*(scale or 1)))} end
    at("Unit:player",-.164,.357); at("Unit:target",.164,.357); at("Unit:pet",-.18,.294,.75)
    at("Unit:focus",.164,.42,.85); at("UnitGroup:party",-.39,.50,.85); at("UnitGroup:raid",-.28,.59,.8)
    at("Minimap",.417,.825); at("QuestTracker",.397,.45); at("Coordinates",.417,.694,1.4)
    at("Clock",.417,.66,1.4); at("Waypoint",0,.82,1.1); at("ExperienceBar",0,.982,1.4)
    at("GearButton",.285,.107); at("AddonButtons",.34,.89); at("MainMenu",.35,.018); at("BagsBar",.14,.019)
    at("DamageMeterSessionWindow1",-.405,.94); at("DamageMeter",-.405,.94)
    if name=="Compact" then
        at("Unit:player",-.10,.27,.85); at("Unit:target",.10,.27,.85); at("Unit:pet",-.115,.22,.65)
        at("Unit:focus",.10,.33,.75); at("QuestTracker",.41,.48,.85); at("Minimap",.43,.855,.85)
        at("Coordinates",.43,.746); at("Clock",.43,.717); at("Waypoint",0,.87)
    elseif name=="Classic" then
        at("Unit:player",-.36,.91); at("Unit:target",-.20,.91); at("Unit:pet",-.375,.85,.75)
        at("Unit:focus",-.20,.85,.85); at("UnitGroup:party",-.40,.67,.85)
    end
    local bars={MultiBarRight={.489,.30},MultiBarLeft={.463,.30}}
    local native={}; for id,p in pairs(bars) do native[id]={x=p[1]*w,y=p[2]*h} end
    local base=(name=="Layout 1" and .136 or .08)*h; local gap=math.max(44,50*s)
    for id,row in pairs({MainActionBar=2,MainMenuBar=2,MultiBarBottomLeft=1,MultiBarBottomRight=0,PetActionBar=3,StanceBar=4}) do native[id]={x=id=="PetActionBar" and -.043*w or 0,y=base+row*gap} end
    if name~="Classic" then
        local y=math.max(frames["Unit:player"].y,native.PetActionBar.y+100)
        frames["Unit:player"].y=y; frames["Unit:target"].y=y; frames["Unit:pet"].y=y-78*s
    end
    local menu=FS.Layout.targets.MainMenu; local bags=FS.Layout.targets.BagsBar
    local mw=menu and menu.frame:GetWidth() or 570; local bw=bags and bags.frame:GetWidth() or 320; local pad=12*s
    frames.MainMenu.x=w/2-pad-mw*s/2; frames.BagsBar.x=w/2-pad*2-mw*s-bw*s/2
    native.ChatFrame1={x=-.39*w,y=.215*h}; native.DamageMeterSessionWindow1={x=-.405*w,y=.94*h}; native.DamageMeter=native.DamageMeterSessionWindow1
    return {frames=frames,native=native,width=w,height=h}
end
function P:NativeAvailable()
    return C_EditMode and type(C_EditMode.GetLayouts)=="function" and type(C_EditMode.SaveLayouts)=="function" and type(C_EditMode.SetActiveLayout)=="function"
        and Enum and Enum.EditModeLayoutType and FS.Tools:Number(Enum.EditModeLayoutType.Preset) and FS.Tools:Number(Enum.EditModeLayoutType.Character)
        and EditModePresetLayoutManager and type(EditModePresetLayoutManager.GetCopyOfPresetLayouts)=="function"
end
function P:BuildNative(name,plan)
    if not self:NativeAvailable() then return nil,"The game's layout system is unavailable. Use Keep current or disable game-bar layout." end
    local ok,raw=pcall(C_EditMode.GetLayouts)
    if not ok or type(raw)~="table" or type(raw.layouts)~="table" then return nil,"The game layout is not ready yet. Try again after loading." end
    local info=copy(raw); local presetType=Enum.EditModeLayoutType.Preset; local characterType=Enum.EditModeLayoutType.Character
    local presets=EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    if type(presets)~="table" or not presets[1] or type(presets[1].systems)~="table" then return nil,"The game's default layout is not ready yet." end
    if not info.layouts[1] or info.layouts[1].layoutType~=presetType then
        local combined=copy(presets); for _,v in ipairs(info.layouts) do combined[#combined+1]=v end; info.layouts=combined
    end
    local previous=copy(info); local label="ForeverSuite "..name; local index; local count=0
    for i,v in ipairs(info.layouts) do
        if v.layoutType==characterType then count=count+1; if v.layoutName==label then index=i end end
    end
    local maximum=Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType or 5
    if not index and count>=maximum then return nil,"No free character game-layout slot. Free a slot or disable game-bar layout." end
    local layout=copy(presets[1]); layout.layoutName=label; layout.layoutType=characterType
    local matched=0
    for id,position in pairs(plan.native) do
        local frame=_G[id]
        if frame and FS.Tools:Number(frame.system) then
            for _,system in ipairs(layout.systems) do
                if system.system==frame.system and system.systemIndex==frame.systemIndex then
                    system.anchorInfo={point="CENTER",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=position.x,offsetY=position.y}
                    system.isInDefaultPosition=false; matched=matched+1; break
                end
            end
        end
    end
    if matched==0 then return nil,"Game bars are not ready yet. Try again after loading or disable game-bar layout." end
    index=index or #info.layouts+1; info.layouts[index]=layout; info.activeLayout=index
    return {info=info,previous=previous,index=index,name=label}
end
function P:Prepare(name,native)
    if name=="Keep current" then return {keep=true} end
    local plan=self:Plan(name,UIParent:GetWidth(),UIParent:GetHeight())
    if not plan then return nil,"Choose a valid layout on a screen of at least 640 by 360 UI units." end
    if native then local data,reason=self:BuildNative(name,plan); if not data then return nil,reason end; plan.game=data end
    return plan
end
function P:Commit(name,plan)
    if not plan or InCombatLockdown() or FS.modules.Vendor.busy then return false end
    if plan.keep then return true end
    if plan.game then
        local g=plan.game; local ok,result=pcall(C_EditMode.SaveLayouts,g.info)
        if not ok or result==false then FS:Print("Could not save the game layout; no addon positions were changed."); return false end
        ok,result=pcall(C_EditMode.SetActiveLayout,g.index)
        if not ok or result==false then
            local restored,value=pcall(C_EditMode.SaveLayouts,g.previous)
            local active,activated=pcall(C_EditMode.SetActiveLayout,g.previous.activeLayout)
            if restored and value~=false and active and activated~=false then FS:Print("Could not activate the game layout; the previous layout was restored.")
            else FS.db.layout.previousNative=g.previous; FS:Print("Game layout activation failed. A copy of the previous game layout was retained in your profile data.") end
            return false
        end
    end
    local profiles=FS.modules.Profiles
    if profiles.Backup then profiles:Backup(FS.db.profiles.current,profiles:Snapshot(),"Before layout preset") end
    local db=FS.db.layout; db.previousPreset={frames=copy(db.frames),preset=db.preset,native=plan.game and plan.game.previous or nil}
    for id,p in pairs(plan.frames) do db.frames[id]=copy(p) end
    db.preset=name; db.nativePreset=plan.game and plan.game.name or nil
    FS.Layout:Collect()
    for id in pairs(plan.frames) do FS.Layout:ConstrainSaved(id) end
    FS.Layout:ApplyAll(); return true
end
-- Schematic only: contains no screenshot, chat messages, player names or guild data.
function P:CreatePreview(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); FS.HUD:Skin(f); f:SetSize(712,400); f:EnableMouse(false); f.parts={}
    local items={{"Player","Unit:player",282,55,.25,.7,.4},{"Target","Unit:target",282,55,.8,.25,.25},{"Pet","Unit:pet",282,55,.25,.7,.4},
        {"Map","Minimap",256,256,.12,.72,.86},{"Quests","QuestTracker",300,380,.9,.7,.2},{"Chat","ChatFrame1",410,280,.45,.55,.65},
        {"Meter","DamageMeterSessionWindow1",405,140,.5,.55,.7},{"Menu","MainMenu",570,36,.7,.6,.3},{"Bags","BagsBar",320,40,.7,.6,.3},
        {"XP","ExperienceBar",790,8,.12,.72,.86},{"Waypoint","Waypoint",250,48,.12,.72,.86},{"1 2 3 4 5 6 7 8 9 0","MainActionBar",560,44,.12,.72,.86},
        {"Action bar 2","MultiBarBottomLeft",560,44,.12,.72,.86},{"Action bar 3","MultiBarBottomRight",560,44,.12,.72,.86}}
    for _,item in ipairs(items) do
        local b=CreateFrame("Frame",nil,f,"BackdropTemplate"); FS.HUD:Skin(b); b:EnableMouse(false); b:SetBackdropColor(item[5]*.3,item[6]*.3,item[7]*.3,1)
        b.label=FS.HUD:Label(b,item[1],2,-2,100); b.label:SetJustifyH("CENTER"); b.label:ClearAllPoints(); b.label:SetPoint("CENTER"); b.label:SetFont(FS.font,10,"")
        f.parts[item[2]]={frame=b,width=item[3],height=item[4]}
    end
    f.notice=FS.HUD:Label(f,"Current positions will be kept.",100,-160,512); f.notice:SetJustifyH("CENTER"); f:Hide(); return f
end
function P:Preview(frame,name)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight(); local plan=self:Plan(name,w,h)
    frame:SetHeight(712*math.max(.40,math.min(.70,h/w)))
    frame.notice:SetShown(not plan)
    for id,item in pairs(frame.parts) do
        local p=plan and (plan.frames[id] or plan.native[id]); local b=item.frame; b:SetShown(p~=nil)
        if p then
            local ratio=712/w; local scale=p.scale or math.max(.6,math.min(1,w/2133.3333,h/1200))
            b:SetSize(math.max(6,item.width*scale*ratio),math.max(5,item.height*scale*ratio))
            b:ClearAllPoints(); b:SetPoint("CENTER",frame,"BOTTOMLEFT",(p.x+w/2)/w*712,p.y/h*frame:GetHeight())
            b.label:SetWidth(math.max(1,b:GetWidth()-4)); b.label:SetHeight(14); b.label:SetShown(b:GetHeight()>=14)
        end
    end
end
