local _,FS=...
local T=FS.Tools
local S=T:Module("Social","social","Social","Customize Contacts and your searchable friends list. Select a friend to prepare a whisper.",
    {styleContacts=true,onlineOnly=false,onlineFirst=true,sortByName=true,showLevel=true,showClass=true,showZone=true,showNotes=false},
    {"FRIENDLIST_UPDATE","PLAYER_ENTERING_WORLD"})
S.options={{key="styleContacts",label="Style Contacts window"},{key="onlineOnly",label="Online friends only"},{key="onlineFirst",label="Online friends first"},{key="sortByName",label="Sort names alphabetically"},{key="showLevel",label="Show level"},{key="showClass",label="Show class"},{key="showZone",label="Show zone"},{key="showNotes",label="Show friend notes"}}
function T:PlayerCaption(info,data)
    local parts={info.name,info.online and "Online" or "Offline"}
    if data.showRank and T:Text(info.rank)~="" then parts[#parts+1]=info.rank end
    if data.showLevel and T:Number(info.level) then parts[#parts+1]="Lv "..info.level end
    if data.showClass and T:Text(info.class)~="" then parts[#parts+1]=info.class end
    if data.showZone and T:Text(info.zone)~="" then parts[#parts+1]=info.zone end
    if data.showNotes and T:Text(info.note)~="" then parts[#parts+1]=info.note end
    return table.concat(parts," | ")
end
function T:SortPlayers(rows,data)
    table.sort(rows,function(a,b)
        if data.onlineFirst and a.online~=b.online then return a.online end
        if data.sortByName and a.name:lower()~=b.name:lower() then return a.name:lower()<b.name:lower() end
        return a.index<b.index
    end)
end
function S:Build()
    self.rows={}; local F=C_FriendList; local data=self:Data()
    for i=1,(T:Call(F and F.GetNumFriends) or T:Call(GetNumFriends) or 0) do
        local info=T:Call(F and F.GetFriendInfoByIndex,i)
        if not info then local name,level,class,area,connected,status,note=T:Call(GetFriendInfo,i); info=name and {name=name,level=level,className=class,connected=connected,area=area,notes=note} end
        if info and T:Text(info.name)~="" then
            local online=FS.HUD:Safe(info.connected) and info.connected==true
            if not data.onlineOnly or online then
                local row={index=i,name=T:Text(info.name),online=online,level=info.level,class=info.className or info.class,zone=info.area,note=info.notes or info.note}
                row.text=T:PlayerCaption(row,data); self.rows[#self.rows+1]=row
            end
        end
    end
    T:SortPlayers(self.rows,data); self.status=#self.rows.." friends. Select a friend; Whisper prepares your message."
end
local base=S.SettingsChanged
function S:SettingsChanged() base(self); if FS.NativeWindows then FS.NativeWindows:Refresh() end end
S.actions={{label="Whisper",run=function(self) if self.selected and self.selected.name then T:Call(ChatFrame_SendTell,self.selected.name) end end},{label="Contacts",run=function() T:Call(ToggleFriendsFrame) end},{label="Refresh",run=function() T:Call(C_FriendList and C_FriendList.ShowFriends or ShowFriends) end}}
