local _,FS=...
local T=FS.Tools
local Q=T:Module("QoL","qol","Leveling & QoL","Level progress, invite tools and optional dismount assistance. Type a player name before inviting.",{autoDismount=false,showXP=true,showToNext=true,showRested=true,showQuestTip=true},{"PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","UI_ERROR_MESSAGE"})
Q.options={{key="autoDismount",label="Dismount after a mounted-action error"},{key="showXP",label="Show experience summary"},{key="showToNext",label="Show experience to next level"},{key="showRested",label="Show rested experience"},{key="showQuestTip",label="Show quest settings reminder"}}
function Q:Event(event,code,text)
    if event~="UI_ERROR_MESSAGE" or not self:Data().autoDismount or InCombatLockdown() then return end
    if T:Text(text)~="" and (text==ERR_ATTACK_MOUNTED or text==ERR_NOT_WHILE_MOUNTED) then
        if T:Call(IsMounted) and not T:Call(IsFlying) then T:Call(Dismount) end
    end
end
function Q:Build()
    self.rows={}; local xp,maximum,rested=T:Call(UnitXP,"player"),T:Call(UnitXPMax,"player"),T:Call(GetXPExhaustion)
    if T:Number(xp) and T:Number(maximum) and maximum>0 then
        if self:Data().showXP then self.rows[#self.rows+1]={text="Experience: "..xp.." / "..maximum.." ("..math.floor(xp/maximum*100).."%)"} end
        if self:Data().showToNext then self.rows[#self.rows+1]={text="To next level: "..(maximum-xp)} end
    elseif self:Data().showXP or self:Data().showToNext then self.rows[#self.rows+1]={text="Experience progress is unavailable or you are at maximum level."} end
    if self:Data().showRested then self.rows[#self.rows+1]={text="Rested experience: "..(T:Number(rested) and rested or 0)} end
    if self:Data().showQuestTip then self.rows[#self.rows+1]={text="Quest convenience options are in the Quests module."} end
    self.status="Invites are sent only when you click Invite. Dismount assistance stays off during combat or flight."
end
Q.actions={{label="Invite",run=function(_,text) text=T:Text(text):match("^%s*(.-)%s*$"); if text~="" and #text<=80 and not InCombatLockdown() then T:Call(C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit,text) end end},{label="Dismount",run=function() if not InCombatLockdown() and not T:Call(IsFlying) then T:Call(Dismount) end end},{label="Quests",run=function() FS.modules.Quests:ShowWindow() end}}
