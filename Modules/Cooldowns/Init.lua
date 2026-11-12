local _,FS=...
local T=FS.Tools
local C=T:Module("Cooldowns","cooldowns","Cooldowns","Track your spells and group interrupts or defensives. Enter a spell ID to add it; select a spell to change its group.",{spells={},showReady=true,showCharges=true,groupFilter="All",sort="Group",knownOnly=false},{"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES","PLAYER_ENTERING_WORLD"})
C.options={{key="showReady",label="Show ready spells"},{key="showCharges",label="Show spell charges"},{key="groupFilter",label="Spell group",values={"All","General","Interrupt","Defensive"}},{key="sort",label="Sort spells",values={"Group","Name","Remaining"}},{key="knownOnly",label="Only show learned spells"}}
C.defaultsByClass={WARRIOR={{6552,"Interrupt"},{871,"Defensive"},{2565,"Defensive"}},PALADIN={{642,"Defensive"},{1022,"Defensive"}},HUNTER={{19263,"Defensive"}},ROGUE={{1766,"Interrupt"},{5277,"Defensive"},{1856,"Defensive"}},PRIEST={{17,"Defensive"},{586,"Defensive"}},SHAMAN={{8042,"Interrupt"}},MAGE={{2139,"Interrupt"},{45438,"Defensive"}},WARLOCK={{19647,"Interrupt"}},DRUID={{22812,"Defensive"},{5211,"Interrupt"}}}
function C:Build()
    self.rows={}
    local data,now=self:Data(),GetTime()
    for id,category in pairs(data.spells) do
        if T:Number(id) and type(category)=="string" and (data.groupFilter=="All" or data.groupFilter==category) then
            local known=not data.knownOnly or T:Call(IsSpellKnown,id) or T:Call(IsPlayerSpell,id)
                or T:Call(C_SpellBook and C_SpellBook.IsSpellKnown,id,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)
            if known then
                local cooldown=T:Call(C_Spell and C_Spell.GetSpellCooldown,id)
                local start,duration
                if type(cooldown)=="table" then start,duration=cooldown.startTime,cooldown.duration else start,duration=T:Call(GetSpellCooldown,id) end
                local remaining=T:Number(start) and T:Number(duration) and math.max(0,start+duration-now) or nil
                if remaining==nil or remaining>0 or data.showReady then
                    local name=T:Text(T:Call(C_Spell and C_Spell.GetSpellName,id))
                    if name=="" then name=T:Text(T:Call(GetSpellInfo,id)) end
                    if name=="" then name="Spell "..id end
                    local charge=data.showCharges and T:Call(C_Spell and C_Spell.GetSpellCharges,id)
                    local status=remaining and (remaining>0 and math.ceil(remaining).."s" or "Ready") or "Cooldown unavailable"
                    if type(charge)=="table" and T:Number(charge.currentCharges) and T:Number(charge.maxCharges) then status=status.." | "..charge.currentCharges.."/"..charge.maxCharges.." charges" end
                    self.rows[#self.rows+1]={id=id,name=name,remaining=remaining or math.huge,text="["..category.."] "..name.." - "..status}
                end
            end
        end
    end
    table.sort(self.rows,function(a,b)
        if data.sort=="Remaining" and a.remaining~=b.remaining then return a.remaining<b.remaining end
        if data.sort=="Name" or data.sort=="Remaining" then return a.name<b.name end
        return a.text<b.text
    end)
    self.status="Own spell cooldowns only. Select a spell, then Group or Remove."
end
function C:Event(event)
    if event~="PLAYER_ENTERING_WORLD" or self:Data().seeded then return end
    local _,class=T:Call(UnitClass,"player")
    for _,entry in ipairs(self.defaultsByClass[class] or {}) do
        local known=T:Call(IsSpellKnown,entry[1]) or T:Call(IsPlayerSpell,entry[1]) or T:Call(C_SpellBook and C_SpellBook.IsSpellKnown,entry[1],Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)
        if known then self:Data().spells[entry[1]]=entry[2] end
    end
    self:Data().seeded=true
end
C.actions={{label="Track",run=function(self,text) local id=tonumber(text); if T:Number(id) and id>0 and id==math.floor(id) then self:Data().spells[id]="General" end end},{label="Group",run=function(self) local row=self.selected; if row then local nextGroup={General="Interrupt",Interrupt="Defensive",Defensive="General"}; self:Data().spells[row.id]=nextGroup[self:Data().spells[row.id]] or "General" end end},{label="Remove",run=function(self) if self.selected then self:Data().spells[self.selected.id]=nil end end}}
