local _,FS=...
local B,T=FS.Beginner,FS.Tools

function B:ShowDirectory(manage,page)
    if not self:Allowed() then return false end
    local center=FS:CreateConfigWindow()
    local f=self:Window("directoryWindow",manage and "Modules" or "What's Included?")
    local names=center.moduleOrder
    local perPage=7
    local pages=math.max(1,math.ceil(#names/perPage))
    page=math.max(1,math.min(pages,page or 1))
    local entries={}
    for i=(page-1)*perPage+1,math.min(page*perPage,#names) do
        local name=names[i]
        local title=self:Title(name)
        local state=FS:IsModuleEnabled(name) and "Enabled" or "Disabled"
        local summary=self.help[name] or FS.modules[name].description or ""
        entries[#entries+1]={
            text=title.."  |  "..state.."\n"..summary,
            run=function()
                if not manage then self:ShowModule(name); return end
                if not self:Allowed() then return end
                FS:SetModuleEnabled(name,not FS:IsModuleEnabled(name))
                FS.modules.Profiles:PersistCurrent()
                self:ShowDirectory(true,page)
            end,
        }
    end
    if page>1 then entries[#entries+1]={text="Previous modules",run=function() self:ShowDirectory(manage,page-1) end} end
    if page<pages then entries[#entries+1]={text="Next modules",run=function() self:ShowDirectory(manage,page+1) end} end
    local hint=manage and "Click a module to enable or disable it." or "Choose a module to see its settings."
    return self:Present(f,entries,hint.."  |  Page "..page.." / "..pages)
end

local optionHelp={
    ActionBars={
        mouseover="Show the action bars when the pointer is over them. Bars stay visible while binding keys or in combat.",
        fade="Sets the opacity of action bars when the pointer is away and mouseover mode is off.",
        menu="Places the main menu in ForeverSuite's menu bar.",
    },
    UnitFrames={
        showPet="Shows your pet's health, power and happiness under the player frame.",
        showFocus="Shows a separate frame for your focus target.",
        showParty="Shows ForeverSuite frames for your party members.",
        showRaid="Shows ForeverSuite frames for your raid members.",
    },
    Chat={timestamps="Shows the time next to messages in chat."},
    Bags={showCooldowns="Shows the remaining cooldown on items in your bags.",showNewLoot="Marks items you received recently."},
    Gear={warn="Shows a reminder when equipped gear falls below the durability threshold."},
    Map={trail="Draws a trail toward the active waypoint on the minimap.",coordinates="Shows your current location below the minimap."},
    Vendor={autoRepair="Repairs equipped gear when you visit a merchant that can repair."},
}
function B:OptionHelp(name,key,option)
    return option.help or (optionHelp[name] and optionHelp[name][key])
end

local resetTables={UnitFrames={player=true,target=true,pet=true,focus=true,party=true,raid=true}}
local resetExtras={Chat={"keywordsEnabled","captureChat"},Social={"trackGroups"},Guild={"showPrivateNotes"}}
local function moduleKey(name)
    local module=FS.modules[name]
    return module and (module.key or ({Bags="bags",Vendor="vendor",Gear="gear"})[name])
end
function B:CanResetModule(name)
    local key=moduleKey(name)
    return key and type(FS.defaults[key])=="table" and (next(FS.defaults[key])~=nil)
end
function B:ResetModule(name)
    if not self:Allowed() or not self:CanResetModule(name) then return false end
    local key=moduleKey(name)
    local settings,defaults=FS.db[key],FS.defaults[key]
    for option,value in pairs(defaults) do
        if option~="enabled" and (type(value)~="table" or (resetTables[name] and resetTables[name][option])) then
            settings[option]=nil
        end
    end
    FS:ApplyDefaults(settings,defaults)
    for _,option in ipairs(resetExtras[name] or {}) do FS.db.extras[option]=FS.defaults.extras[option] end
    if name=="UnitFrames" then
        for _,id in ipairs({"Unit:player","Unit:target","Unit:pet","Unit:focus","UnitGroup:party","UnitGroup:raid"}) do
            FS.db.layout.frames[id]=nil
        end
    end
    local module=FS.modules[name]
    if module.SettingsChanged then module:SettingsChanged()
    elseif module.NormalizeSettings then module:NormalizeSettings() end
    if name=="Bags" then module:Refresh() end
    if name=="Chat" then FS.Extensions:SyncEvents() end
    FS.modules.Profiles:PersistCurrent()
    FS:RefreshConfig()
    return true
end
function B:ConfirmModuleReset(name)
    local title=self:Title(name)
    local f=self:Window("moduleReset","Reset "..title.."?")
    return self:Present(f,{
        {text="Reset "..title,run=function() if self:ResetModule(name) then self:ShowModule(name) end end},
        {text="Cancel",run=function() self:ShowModule(name) end},
    },"Restore the default settings for "..title..". The module stays enabled or disabled as it is now.")
end

local function showNumber(value)
    return T:Number(value) and tostring(value) or "Unavailable"
end
local function characterMoney(copper)
    if not T:Number(copper) or copper<0 then return "Unavailable" end
    return ("%dg %ds %dc"):format(math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end
function B:CharacterSummary()
    local _,equipped=T:Call(GetAverageItemLevel or (C_Item and C_Item.GetAverageItemLevel))
    if not T:Number(equipped) or equipped<=0 then
        local gear=FS.modules.Gear:Snapshot()
        if gear and not gear.incomplete then equipped=gear.averageItemLevel end
    end
    local professions=FS.Extensions:ObservedProfessions()
    local names={}
    for _,entry in ipairs(professions or {}) do
        names[#names+1]=("%s %d/%d"):format(entry.name,entry.skill,entry.maximum)
    end
    local class=T:Text(T:Call(UnitClass,"player"))
    local guild=T:Text(T:Call(GetGuildInfo,"player"))
    return {
        {"Level",showNumber(T:Call(UnitLevel,"player"))},
        {"Class",class~="" and class or "Unavailable"},
        {"Gold",characterMoney(T:Call(GetMoney))},
        {"Professions",#names>0 and table.concat(names,", ") or professions and "None learned" or "Unavailable","Professions"},
        {"Equipped Item Level",T:Number(equipped) and equipped>0 and ("%.1f"):format(equipped) or "Unavailable","Gear"},
        {"Guild",guild~="" and guild or "No guild","Guild"},
    }
end
function B:ShowCharacterOverview()
    if not self:Allowed() then return false end
    local f=self:Window("characterOverview","Character Overview")
    local entries={}
    for _,item in ipairs(self:CharacterSummary()) do
        local module=item[3] and FS.modules[item[3]]
        local canOpen=module and module.ShowWindow and FS:IsModuleEnabled(item[3])
        entries[#entries+1]={text=item[1]..": "..item[2],enabled=not not canOpen,
            run=function() if canOpen then module:ShowWindow() end end}
    end
    return self:Present(f,entries,T:Text(T:Call(UnitName,"player")))
end
