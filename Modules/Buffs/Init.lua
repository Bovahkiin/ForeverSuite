local _,FS=...
local T=FS.Tools
local B=T:Module("Buffs","buffs","Buffs","See buffs, debuffs and weapon enchants. Add a spell ID below to remind you when that buff is missing.",{reminders={},showReminder=true,showBuffs=true,showDebuffs=true,showEnchants=true,showDuration=true,hideReminderCombat=false,reminderWidth=260},{"UNIT_AURA","PLAYER_EQUIPMENT_CHANGED","PLAYER_ENTERING_WORLD"})
B.options={{key="showReminder",label="Show missing buff reminders"},{key="showBuffs",label="Show buffs in overview"},{key="showDebuffs",label="Show debuffs in overview"},{key="showEnchants",label="Show weapon enchants"},{key="showDuration",label="Show remaining duration"},{key="hideReminderCombat",label="Hide reminder during combat"},{key="reminderWidth",label="Reminder width",values={260,360,480}}}
function B:Aura(unit,index,filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then return T:Call(C_UnitAuras.GetAuraDataByIndex,unit,index,filter) end
    local fn=filter=="HARMFUL" and UnitDebuff or UnitBuff
    local name,icon,count,kind,duration,expiration,source,_,_,spellID=T:Call(fn,unit,index)
    if name then return {name=name,icon=icon,applications=count,duration=duration,expirationTime=expiration,spellId=spellID} end
end
function B:Build()
    self.rows={}; local present={}
    for _,filter in ipairs({"HELPFUL","HARMFUL"}) do
        for i=1,40 do
            local aura=self:Aura("player",i,filter); if not aura then break end
            if T:Text(aura.name)~="" then
                if T:Number(aura.spellId) then present[aura.spellId]=true end
                local remaining=T:Number(aura.expirationTime) and aura.expirationTime>0 and math.max(0,math.ceil(aura.expirationTime-GetTime())) or nil
                if (filter=="HELPFUL" and self:Data().showBuffs) or (filter=="HARMFUL" and self:Data().showDebuffs) then self.rows[#self.rows+1]={text=(filter=="HARMFUL" and "[Debuff] " or "[Buff] ")..aura.name..(remaining and self:Data().showDuration and " - "..remaining.."s" or "")} end
            end
        end
    end
    local main,mainTime,_,_,off,offTime=T:Call(GetWeaponEnchantInfo)
    if self:Data().showEnchants then
    self.rows[#self.rows+1]={text="Main-hand enchant: "..(main and (self:Data().showDuration and (math.ceil((mainTime or 0)/1000).."s remaining") or "Active") or "None")}
    self.rows[#self.rows+1]={text="Off-hand enchant: "..(off and (self:Data().showDuration and (math.ceil((offTime or 0)/1000).."s remaining") or "Active") or "None")}
    end
    self.missing={}
    for id in pairs(self:Data().reminders) do
        if T:Number(id) and not present[id] then
            local name=T:Call(C_Spell and C_Spell.GetSpellName,id) or T:Call(GetSpellInfo,id) or "Spell "..id
            self.missing[#self.missing+1]=name; self.rows[#self.rows+1]={id=id,text="[Missing] "..name}
        end
    end
    self.status="Enter a buff spell ID and click Remind. Select a missing buff and Remove to stop its reminder."
end
function B:Tick()
    if not self:Data().showReminder or (self:Data().hideReminderCombat and InCombatLockdown()) or not next(self:Data().reminders) then if self.reminder then self.reminder:Hide() end; return end
    self:Build()
    if not self.reminder then
        local f=CreateFrame("Frame","ForeverSuiteBuffReminder",UIParent,"BackdropTemplate"); self.reminder=f; FS.HUD:Skin(f); f:SetSize(260,54); f:SetPoint("TOP",0,-100); f:EnableMouse(false)
        f.text=FS.HUD:Label(f,"",8,-10,244); f.text:SetHeight(40); FS.Layout:Register("BuffReminder",f,"Buff Reminders")
    end
    self.reminder:SetShown(#self.missing>0)
    self.reminder.text:SetText("Missing buff: "..table.concat(self.missing,", "))
    self.reminder:SetWidth(self:Data().reminderWidth)
    self.reminder:SetHeight(FS.HUD:TextHeight(self.reminder.text,self:Data().reminderWidth-16,4)+20)
end
local base=B.SettingsChanged
function B:SettingsChanged() base(self); if self.reminder and not FS:IsModuleEnabled(self.name) then self.reminder:Hide() end end
B.actions={{label="Remind",run=function(self,text) local id=tonumber(text); if T:Number(id) and id>0 and id==math.floor(id) then self:Data().reminders[id]=true end end},{label="Remove",run=function(self) if self.selected and self.selected.id then self:Data().reminders[self.selected.id]=nil end end}}
