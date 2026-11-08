local _,FS=...
local T=FS.Tools
local C=T:Module("Combat","combat","Combat","Group damage, healing, deaths, interrupts and dispels. Forever uses the game's damage-meter data; readable reports update after combat.",{report=true,metric="DamageDone",session="Current",showRates=true,selfOnly=false,maxEntries=100},{"COMBAT_LOG_EVENT_UNFILTERED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","DAMAGE_METER_COMBAT_SESSION_UPDATED","DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET"})
C.options={{key="report",label="Record combat"},{key="metric",label="Report metric",values={"DamageDone","HealingDone","Deaths","Interrupts","Dispels"}},{key="session",label="Report session",values={"Current","Overall"}},{key="showRates",label="Show amount per second"},{key="selfOnly",label="Only show my character"},{key="maxEntries",label="Maximum report rows",values={10,25,50,100}}}; C.people={}
function C:Reset() self.people={}; self.started=nil; self.finished=nil; self.deaths={}; self.totalDamage=0; self.totalHealing=0 end
function C:Friendly(guid,flags)
    if not guid then return false end
    if guid==T:Call(UnitGUID,"player") then return true end
    return bit and bit.band and T:Number(flags) and bit.band(flags,7)~=0
end
function C:Record(...)
    if not self:Data().report then return end
    local args={...}; local event=args[2]; if T:Text(event)=="" then return end
    local source,name,flags,dest,destName,destFlags=args[4],args[5],args[6],args[8],args[9],args[10]
    if not FS.HUD:Safe(source) or not FS.HUD:Safe(dest) then return end
    if event=="UNIT_DIED" and self:Friendly(dest,destFlags) then
        self.people[dest]=self.people[dest] or {name=T:Text(destName),damage=0,healing=0,deaths=0,interrupts=0,dispels=0}
        self.people[dest].deaths=self.people[dest].deaths+1; return
    end
    if not source or not self:Friendly(source,flags) then return end
    local player=self.people[source] or {name=T:Text(name),damage=0,healing=0,deaths=0,interrupts=0,dispels=0}; self.people[source]=player
    local amount
    if event=="SWING_DAMAGE" then amount=args[12]
    elseif event=="SPELL_DAMAGE" or event=="RANGE_DAMAGE" or event=="SPELL_PERIODIC_DAMAGE" then amount=args[15]
    elseif event=="SPELL_HEAL" or event=="SPELL_PERIODIC_HEAL" then
        if T:Number(args[15]) and T:Number(args[16]) then player.healing=player.healing+math.max(0,args[15]-args[16]) end
    elseif event=="SPELL_INTERRUPT" then player.interrupts=player.interrupts+1
    elseif event=="SPELL_DISPEL" or event=="SPELL_STOLEN" then player.dispels=player.dispels+1 end
    if T:Number(amount) then player.damage=player.damage+math.max(0,amount) end
    if not self.started then self.started=GetTime() end
end
function C:Event(event)
    if event=="COMBAT_LOG_EVENT_UNFILTERED" and CombatLogGetCurrentEventInfo then self:Record(T:Call(CombatLogGetCurrentEventInfo))
    elseif event=="PLAYER_REGEN_DISABLED" then self.started=self.started or GetTime(); self.finished=nil
    elseif event=="PLAYER_REGEN_ENABLED" then self.finished=GetTime() end
end
function C:Build()
    if C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterType and Enum.DamageMeterSessionType then self:BuildNative(); return end
    self.rows={}; local duration=math.max(1,(self.finished or GetTime())-(self.started or GetTime()))
    for guid,p in pairs(self.people) do if not self:Data().selfOnly or guid==T:Call(UnitGUID,"player") then
        local keys={DamageDone="damage",HealingDone="healing",Deaths="deaths",Interrupts="interrupts",Dispels="dispels"}
        local amount=p[keys[self:Data().metric] or "damage"] or 0
        self.rows[#self.rows+1]={id=guid,text=p.name.." | Damage "..FS.HUD:Number(p.damage)..(self:Data().showRates and (" ("..math.floor(p.damage/duration).."/s)") or "").." | Heal "..FS.HUD:Number(p.healing).." | Deaths "..p.deaths.." | Interrupts "..p.interrupts.." | Dispels "..p.dispels,damage=amount} end end
    table.sort(self.rows,function(a,b) return a.damage>b.damage end)
    while #self.rows>self:Data().maxEntries do table.remove(self.rows) end
    self.status=CombatLogGetCurrentEventInfo and "Current report: "..math.floor(duration).." seconds. Healing excludes overhealing." or "This client does not expose a readable combat log to addons."
end
function C:BuildNative()
    self.rows={}
    if InCombatLockdown() then self.status="Your readable combat report updates after combat ends."; return end
    local available,reason=T:Call(C_DamageMeter.IsDamageMeterAvailable)
    if available==false then self.status=reason or "Damage-meter data is unavailable here."; return end
    local metric=Enum.DamageMeterType[self:Data().metric]; local session=Enum.DamageMeterSessionType[self:Data().session]
    if metric==nil or session==nil then self.status="This metric is unavailable in this client."; return end
    local report=T:Call(C_DamageMeter.GetCombatSessionFromType,session,metric)
    for _,row in ipairs(report and report.combatSources or {}) do
        local name=T:Text(row.name); local amount=T:Number(row.totalAmount) and row.totalAmount or nil
        if name~="" and amount and (not self:Data().selfOnly or row.sourceGUID==T:Call(UnitGUID,"player")) then
            self.rows[#self.rows+1]={id=row.sourceGUID,creature=row.sourceCreatureID,amount=amount,text=name.." | "..FS.HUD:Number(amount)..(self:Data().showRates and T:Number(row.amountPerSecond) and " | "..FS.HUD:Number(row.amountPerSecond).."/s" or "")}
        end
    end
    table.sort(self.rows,function(a,b) return a.amount>b.amount end)
    while #self.rows>self:Data().maxEntries do table.remove(self.rows) end
    self.status=self:Data().session.." / "..self:Data().metric..". Reports use the game's recorded data."
    if self.resetConfirm and GetTime()<self.resetConfirm then self.status="Click Reset again to clear all recorded game combat sessions." end
end
function C:Apply()
    if InCombatLockdown() or not SetCVar or not C_DamageMeter then return end
    if self.originalMeter==nil then self.originalMeter=T:Call(GetCVar,"damageMeterEnabled") end
    if self:Data().report then T:Call(SetCVar,"damageMeterEnabled","1") elseif self.originalMeter then T:Call(SetCVar,"damageMeterEnabled",self.originalMeter) end
end
local changed=C.SettingsChanged
function C:SettingsChanged() changed(self); if not InCombatLockdown() and not FS:IsModuleEnabled(self.name) and self.originalMeter then T:Call(SetCVar,"damageMeterEnabled",self.originalMeter) end end
C.actions={{label="Reset",run=function(self)
    if InCombatLockdown() then return end
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
        if self.resetConfirm and GetTime()<self.resetConfirm then T:Call(C_DamageMeter.ResetAllCombatSessions); self.resetConfirm=nil else self.resetConfirm=GetTime()+10 end
    else self:Reset() end
end},{label="Metric",run=function(self)
    local metrics={"DamageDone","HealingDone","Deaths","Interrupts","Dispels"}; local index=1
    for i,name in ipairs(metrics) do if name==self:Data().metric then index=i%#metrics+1 end end
    self:Data().metric=metrics[index]
end},{label="Session",run=function(self) self:Data().session=self:Data().session=="Current" and "Overall" or "Current" end}}
