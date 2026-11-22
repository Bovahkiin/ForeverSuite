local _,FS=...
local N,T=FS.modules.Nameplates,FS.Tools
local function plain(text)
    return T:Text(text):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
end
function N:QuestObjectives()
    if self.questObjectives then return self.questObjectives,self.questTitles end
    local objectives,titles={},{}
    local API=C_QuestLog
    local count=T:Call(API and API.GetNumQuestLogEntries) or 0
    for i=1,T:Number(count) and count or 0 do
        local info=T:Call(API and API.GetInfo,i)
        if type(info)=="table" and FS.HUD:Safe(info.isHeader) and not info.isHeader and T:Number(info.questID) then
            titles[plain(info.title)]=true
            for _,o in ipairs(T:Call(API.GetQuestObjectives,info.questID) or {}) do
                if type(o)=="table" and FS.HUD:Safe(o.finished) then
                    local text=plain(o.text)
                    if text~="" then objectives[text]=objectives[text] or o.finished~=true end
                end
            end
        end
    end
    self.questObjectives,self.questTitles=objectives,titles
    return objectives,titles
end
function N:UpdateQuestMarker(f,unit,db)
    if not db.showQuest or T:Call(UnitCanAttack,"player",unit)~=true then f.quest:Hide(); return end
    local guid=T:Call(UnitGUID,unit) or unit
    local revision=self.questRevision or 0
    if f.fsQuestGUID~=guid or f.fsQuestRevision~=revision then
        f.fsQuestGUID,f.fsQuestRevision=guid,revision
        local needed,known=false,false
        local data=T:Call(C_TooltipInfo and C_TooltipInfo.GetUnit,unit)
        local kinds=Enum and Enum.TooltipDataLineType
        if type(data)=="table" and type(data.lines)=="table" and kinds then
            local objectives,titles=self:QuestObjectives()
            local own=false
            for _,line in ipairs(data.lines) do
                if type(line)=="table" and T:Number(line.type) then
                    local text=plain(line.leftText)
                    if line.type==kinds.QuestTitle then own=titles[text]==true
                    elseif line.type==kinds.QuestObjective then
                        local match=objectives[text]
                        if match~=nil then known=true; needed=needed or match
                        elseif own then
                            local have,need=text:match("(%d+)%s*/%s*(%d+)")
                            if have then known=true; needed=needed or tonumber(have)<tonumber(need) end
                        end
                    end
                end
            end
        end
        -- The native flag is a fallback on clients without structured progress.
        if not known then needed=T:Call(UnitIsQuestBoss,unit)==true end
        f.fsQuestNeeded=needed
    end
    f.quest:SetShown(f.fsQuestNeeded==true)
end
