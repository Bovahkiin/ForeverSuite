local _,FS=...
local T=FS.Tools
local function nativeReportsAvailable()
    return C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterType and Enum.DamageMeterSessionType
end
local events={"PLAYER_REGEN_DISABLED","DAMAGE_METER_COMBAT_SESSION_UPDATED","DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET"}
if not nativeReportsAvailable() then events[#events+1]="COMBAT_LOG_EVENT_UNFILTERED" end
local C=T:Module("Combat","combat","Combat","Group damage, healing, deaths, interrupts and dispels. Forever uses the game's damage-meter data; readable reports update after combat.",{report=true,metric="DamageDone",session="Current",showRates=true,selfOnly=false,maxEntries=100},events)
C.options={{key="report",label="Record combat"},{key="metric",label="Report metric",values={"DamageDone","HealingDone","Deaths","Interrupts","Dispels"}},{key="session",label="Report session",values={"Current","Overall"}},{key="showRates",label="Show amount per second"},{key="selfOnly",label="Only show my character"},{key="maxEntries",label="Maximum report rows",values={10,25,50,100}}}; C.people={}
local legacyMetrics={SWING_DAMAGE="damage",SPELL_DAMAGE="damage",RANGE_DAMAGE="damage",SPELL_PERIODIC_DAMAGE="damage",
    SPELL_HEAL="healing",SPELL_PERIODIC_HEAL="healing",SPELL_INTERRUPT="interrupts",SPELL_DISPEL="dispels",
    SPELL_STOLEN="dispels",UNIT_DIED="deaths"}
local reportMetrics={DamageDone="damage",HealingDone="healing",Deaths="deaths",Interrupts="interrupts",Dispels="dispels"}
local legacySourceLimit=256
function C:Reset() self.people={}; self.peopleCount=0; self.started=nil; self.finished=nil end
function C:Friendly(guid,flags)
    if T:Text(guid)=="" then return false end
    if guid==T:Call(UnitGUID,"player") then return true end
    return bit and bit.band and T:Number(flags) and bit.band(flags,7)~=0
end
function C:Record(_,event,_,source,name,flags,_,dest,destName,destFlags,_,swingAmount,_,_,spellAmount,overheal)
    if not self:Data().report then return end
    local metric=legacyMetrics[T:Text(event)]
    if not metric then return end
    if metric=="deaths" then source,name,flags=dest,destName,destFlags end
    if not self:Friendly(source,flags) then return end
    local amount=1
    if metric=="damage" then
        amount=event=="SWING_DAMAGE" and swingAmount or spellAmount
        if not T:Number(amount) then return end
        amount=math.max(0,amount)
    elseif metric=="healing" then
        if not T:Number(spellAmount) or not T:Number(overheal) then return end
        amount=math.max(0,spellAmount-overheal)
    end
    local player=self.people[source]
    if not player then
        local count=self.peopleCount or 0
        if count>=legacySourceLimit and source~=T:Call(UnitGUID,"player") then return end
        player={name=T:Text(name),damage=0,healing=0,deaths=0,interrupts=0,dispels=0}
        self.people[source]=player; self.peopleCount=count+1
    end
    player[metric]=player[metric]+amount
    if not self.started then self.started=GetTime() end
end
function C:Event(event)
    if nativeReportsAvailable() then return end
    if event=="COMBAT_LOG_EVENT_UNFILTERED" and CombatLogGetCurrentEventInfo then self:Record(T:Call(CombatLogGetCurrentEventInfo))
    elseif event=="PLAYER_REGEN_DISABLED" then self.started=self.started or GetTime(); self.finished=nil
    elseif event=="PLAYER_REGEN_ENABLED" then self.finished=GetTime() end
end
function C:Build()
    if nativeReportsAvailable() then self:BuildNative(); return end
    self.rows={}; local duration=math.max(1,(self.finished or GetTime())-(self.started or GetTime()))
    local data=self:Data()
    local player=data.selfOnly and T:Call(UnitGUID,"player")
    for guid,p in pairs(self.people) do if not data.selfOnly or guid==player then
        local amount=p[reportMetrics[data.metric] or "damage"] or 0
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
    local sources=type(report)=="table" and report.combatSources
    local data=self:Data()
    local player=data.selfOnly and T:Call(UnitGUID,"player")
    if type(sources)=="table" and FS.HUD:Safe(sources) then
        for _,row in ipairs(sources) do
            if type(row)=="table" and FS.HUD:Safe(row) then
                local name=T:Text(row.name); local amount=T:Number(row.totalAmount) and row.totalAmount or nil
                local guid=T:Text(row.sourceGUID)
                if name~="" and amount and (not data.selfOnly or guid~="" and guid==player) then
                    self.rows[#self.rows+1]={id=guid~="" and guid or nil,creature=T:Number(row.sourceCreatureID) and row.sourceCreatureID or nil,amount=amount,text=name.." | "..FS.HUD:Number(amount)..(data.showRates and T:Number(row.amountPerSecond) and " | "..FS.HUD:Number(row.amountPerSecond).."/s" or "")}
                end
            end
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
