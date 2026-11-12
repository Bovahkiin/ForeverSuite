local _,FS=...
local T=FS.Tools
local Q=T:Module("Quests","quests","Quests","Follow quest objectives. Automatic dialogue is optional; hold Shift to pause it.",{tracker=true,accept=false,turnIn=false,minimap=true,worldMap=true,nearby=true,hideComplete=false,collapsed={}},{"QUEST_LOG_UPDATE","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ZONE_CHANGED_NEW_AREA","QUEST_POI_UPDATE","QUEST_WATCH_UPDATE","SUPER_TRACKING_CHANGED"})
Q.options={{key="tracker",label="Show quest tracker"},{key="minimap",label="Quest icons on minimap"},{key="worldMap",label="Quest icons on world map"},{key="nearby",label="Nearest quests first"},{key="hideComplete",label="Hide completed quests in tracker"},{key="accept",label="Auto accept quests"},{key="turnIn",label="Auto turn in without reward choices"}}
function Q:Build()
    self.rows={}
    self.byID={}
    self.pinLocations=nil
    local count=T:Call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or T:Call(GetNumQuestLogEntries) or 0
    for i=1,T:Number(count) and count or 0 do
        local info=T:Call(C_QuestLog and C_QuestLog.GetInfo,i)
        if not info and GetQuestLogTitle then
            local title,level,_,header,_,complete,_,id=T:Call(GetQuestLogTitle,i)
            info=title and {title=title,level=level,isHeader=header,isComplete=complete==1,questID=id}
        end
        if type(info)=="table" and FS.HUD:Safe(info.isHeader) and FS.HUD:Safe(info.isHidden) and not info.isHeader and not info.isHidden and T:Text(info.title)~="" then
            local id=T:Number(info.questID) and info.questID or nil
            local objectives=id and T:Call(C_QuestLog and C_QuestLog.GetQuestObjectives,id)
            local parts, details={},{}
            if type(objectives)=="table" then for _,o in ipairs(objectives) do if type(o)=="table" and FS.HUD:Safe(o) and T:Text(o.text)~="" then
                parts[#parts+1]=o.text
                details[#details+1]={text=o.text,done=FS.HUD:Safe(o.finished) and o.finished==true,
                    have=T:Number(o.numFulfilled) and o.numFulfilled or nil,need=T:Number(o.numRequired) and o.numRequired or nil,kind=T:Text(o.type)}
            end end
            elseif GetNumQuestLeaderBoards then
                for j=1,(T:Call(GetNumQuestLeaderBoards,i) or 0) do local text,kind,done=T:Call(GetQuestLogLeaderBoard,j,i); if T:Text(text)~="" then parts[#parts+1]=text; details[#details+1]={text=text,kind=T:Text(kind),done=done==true} end end
            end
            local distance=id and T:Call(C_QuestLog and C_QuestLog.GetDistanceSqToQuest,id)
            local ready=id and T:Call(C_QuestLog and C_QuestLog.IsComplete,id)
            local complete=ready==true or (FS.HUD:Safe(info.isComplete) and info.isComplete==true)
            local row={id=id,index=i,title=info.title,objectives=parts,details=details,complete=complete,
                distance=T:Number(distance) and distance>=0 and math.sqrt(distance) or nil,text=(complete and "[Ready] " or "")..info.title..(#parts>0 and " - "..table.concat(parts,"; ") or "")}
            self.rows[#self.rows+1]=row
            if T:Number(row.id) then self.byID[row.id]=row end
        end
    end
    self.status=#self.rows.." quests in your log. Select a quest to open its details."
end
function Q:OnSelect(row)
    if not row or InCombatLockdown() then return end
    if QuestMapFrame_OpenToQuestDetails and row.id then T:Call(QuestMapFrame_OpenToQuestDetails,row.id)
    elseif QuestLog_SetSelection then T:Call(QuestLog_SetSelection,row.index); T:Call(ToggleQuestLog) end
end
function Q:Event(event)
    if InCombatLockdown() or (IsShiftKeyDown and IsShiftKeyDown()) then return end
    if event=="QUEST_DETAIL" and self:Data().accept then T:Call(AcceptQuest)
    elseif event=="QUEST_PROGRESS" and self:Data().turnIn and T:Call(IsQuestCompletable) then T:Call(CompleteQuest)
    elseif event=="QUEST_COMPLETE" and self:Data().turnIn then
        local choices=T:Call(GetNumQuestChoices)
        -- A reward choice is always left to the player.
        if choices==0 then T:Call(GetQuestReward,0) end
    end
    self:Apply(); self:NativeTracker()
end
function Q:Apply()
    local data=self:Data()
    if data.tracker or data.minimap or data.worldMap then self:Build() end
    self:UpdateTracker(true); self:UpdateQuestPins()
end
function Q:NativeTracker()
    if InCombatLockdown() then return end
    self.nativeTrackers=self.nativeTrackers or {}
    for _,name in ipairs({"ObjectiveTrackerFrame","QuestWatchFrame"}) do
        local f=_G[name]
        if f and not (f.IsForbidden and f:IsForbidden()) then
            local state=self.nativeTrackers[f]
            if not state then
                state={alpha=f:GetAlpha()}; self.nativeTrackers[f]=state
                hooksecurefunc(f,"SetAlpha",function(frame) if state.hidden and not state.setting then state.setting=true; frame:SetAlpha(0); state.setting=false end end)
            end
            state.hidden=FS:IsModuleEnabled(self.name) and self:Data().tracker
            state.setting=true; f:SetAlpha(state.hidden and 0 or state.alpha); state.setting=false
            FS.modules.Character:NativeMouse(f,state.hidden)
        end
    end
end
function Q:Normalize()
    local db=self:Data(); db.collapsed=type(db.collapsed)=="table" and db.collapsed or {}
    for id,value in pairs(db.collapsed) do if not T:Number(id) or type(value)~="boolean" then db.collapsed[id]=nil end end
end
function Q:Tick()
    self:UpdateTracker(); self:UpdateQuestPins()
end
local base=Q.SettingsChanged
function Q:SettingsChanged() base(self); if self.tracker then self.tracker:SetShown(FS:IsModuleEnabled(self.name) and self:Data().tracker) end; self:NativeTracker(); self:UpdateQuestPins() end
Q.actions={{label="Quest log",run=function() T:Call(ToggleQuestLog) end}}
