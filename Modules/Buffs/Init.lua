local _,FS=...
local T=FS.Tools
local B=T:Module("Buffs","buffs","Buffs","See buffs, debuffs and weapon enchants. Add a spell ID below to remind you when that buff is missing.",{reminders={},showReminder=true,showBuffs=true,showDebuffs=true,showEnchants=true,showDuration=true,hideReminderCombat=false,reminderWidth=260},{"UNIT_AURA","PLAYER_EQUIPMENT_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED"})
B.options={{key="showReminder",label="Show missing buff reminders"},{key="showBuffs",label="Show buffs in overview"},{key="showDebuffs",label="Show debuffs in overview"},{key="showEnchants",label="Show weapon enchants"},{key="showDuration",label="Show remaining duration"},{key="hideReminderCombat",label="Hide reminder during combat"},{key="reminderWidth",label="Reminder width",values={260,360,480}}}
local auraFilters={"HELPFUL","HARMFUL"}
function B:Aura(unit,index,filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then return T:Call(C_UnitAuras.GetAuraDataByIndex,unit,index,filter) end
    local fn=filter=="HARMFUL" and UnitDebuff or UnitBuff
    local name,icon,count,kind,duration,expiration,source,_,_,spellID=T:Call(fn,unit,index)
    if name then return {name=name,icon=icon,applications=count,duration=duration,expirationTime=expiration,spellId=spellID} end
end
function B:ScanAuras(rows,reminders)
    local present={}
    local data=self:Data()
    local now=rows and GetTime()
    for _,filter in ipairs(auraFilters) do
        local show=rows and (filter=="HELPFUL" and data.showBuffs or filter=="HARMFUL" and data.showDebuffs)
        if show or reminders then
            for i=1,40 do
                local aura=self:Aura("player",i,filter); if not aura then break end
                if type(aura)=="table" and T:Text(aura.name)~="" then
                    if reminders and T:Number(aura.spellId) and reminders[aura.spellId] then present[aura.spellId]=true end
                    if show then
                        local remaining=data.showDuration and T:Number(aura.expirationTime) and aura.expirationTime>0
                            and math.max(0,math.ceil(aura.expirationTime-now))
                        rows[#rows+1]={text=(filter=="HARMFUL" and "[Debuff] " or "[Buff] ")..aura.name..(remaining and " - "..remaining.."s" or "")}
                    end
                end
            end
        end
    end
    return present
end
function B:MissingReminders(reminders,present,rows)
    local missing={}
    for id in pairs(reminders) do
        if T:Number(id) and not present[id] then
            local name=T:Text(T:Call(C_Spell and C_Spell.GetSpellName,id))
            if name=="" then name=T:Text(T:Call(GetSpellInfo,id)) end
            if name=="" then name="Spell "..id end
            missing[#missing+1]=name
            if rows then rows[#rows+1]={id=id,text="[Missing] "..name} end
        end
    end
    return missing
end
function B:Build()
    self.rows={}
    local data=self:Data()
    local present=self:ScanAuras(self.rows,next(data.reminders) and data.reminders)
    if data.showEnchants then
        local main,mainTime,_,_,off,offTime=T:Call(GetWeaponEnchantInfo)
        self.rows[#self.rows+1]={text="Main-hand enchant: "..(main and (data.showDuration and T:Number(mainTime) and (math.ceil(mainTime/1000).."s remaining") or "Active") or "None")}
        self.rows[#self.rows+1]={text="Off-hand enchant: "..(off and (data.showDuration and T:Number(offTime) and (math.ceil(offTime/1000).."s remaining") or "Active") or "None")}
    end
    self:MissingReminders(data.reminders,present,self.rows)
    self.status="Enter a buff spell ID and click Remind. Select a missing buff and Remove to stop its reminder."
end
function B:UpdateReminder()
    local data=self:Data()
    if not data.showReminder or (data.hideReminderCombat and InCombatLockdown()) or not next(data.reminders) then
        if self.reminder then self.reminder:Hide() end
        return
    end
    local missing=self:MissingReminders(data.reminders,self:ScanAuras(nil,data.reminders))
    if #missing==0 then
        if self.reminder then self.reminder:Hide() end
        return
    end
    if not self.reminder then
        local f=CreateFrame("Frame","ForeverSuiteBuffReminder",UIParent,"BackdropTemplate"); self.reminder=f; FS.HUD:Skin(f); f:SetSize(260,54); f:SetPoint("TOP",0,-100); f:EnableMouse(false)
        f.text=FS.HUD:Label(f,"",8,-10,244); f.text:SetHeight(40); FS.Layout:Register("BuffReminder",f,"Buff Reminders")
    end
    local f=self.reminder
    f.text:SetText("Missing buff: "..table.concat(missing,", "))
    f:SetWidth(data.reminderWidth)
    f:SetHeight(FS.HUD:TextHeight(f.text,data.reminderWidth-16,4)+20)
    f:Show()
end
function B:Event(event,unit)
    if event=="UNIT_AURA" and T:Text(unit)~="player" then return end
    if event~="PLAYER_EQUIPMENT_CHANGED" then self:UpdateReminder() end
end
function B:Apply() self:UpdateReminder() end
local base=B.SettingsChanged
function B:SettingsChanged() base(self); if self.reminder and not FS:IsModuleEnabled(self.name) then self.reminder:Hide() end end
B.actions={{label="Remind",run=function(self,text) local id=tonumber(text); if T:Number(id) and id>0 and id==math.floor(id) then self:Data().reminders[id]=true; self:UpdateReminder() end end},{label="Remove",run=function(self) if self.selected and self.selected.id then self:Data().reminders[self.selected.id]=nil; self:UpdateReminder() end end}}
