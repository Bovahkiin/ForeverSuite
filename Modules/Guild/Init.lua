local _,FS=...
local T=FS.Tools
local G=T:Module("Guild","guild","Guild","Customize Guild & Communities and your searchable guild roster. Select a member to prepare a whisper.",
    {styleWindow=true,onlineOnly=false,onlineFirst=true,sortByName=true,showRank=true,showLevel=true,showClass=true,showZone=true,showNotes=false},
    {"GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","PLAYER_ENTERING_WORLD"})
G.options={{key="styleWindow",label="Style Guild & Communities"},{key="onlineOnly",label="Online members only"},{key="onlineFirst",label="Online members first"},{key="sortByName",label="Sort names alphabetically"},{key="showRank",label="Show guild rank"},{key="showLevel",label="Show level"},{key="showClass",label="Show class"},{key="showZone",label="Show zone"},{key="showNotes",label="Show public member notes"}}
function G:Build()
    self.rows={}; local data=self:Data()
    for i=1,(T:Call(GetNumGuildMembers) or 0) do
        local name,rank,_,level,class,zone,note,officerNote,online=T:Call(GetGuildRosterInfo,i)
        if T:Text(name)~="" then
            online=FS.HUD:Safe(online) and online==true
            if not data.onlineOnly or online then
                local row={index=i,name=name,rank=rank,level=level,class=class,zone=zone,note=note,online=online}
                row.text=T:PlayerCaption(row,data); self.rows[#self.rows+1]=row
            end
        end
    end
    T:SortPlayers(self.rows,data)
    local name=T:Call(GetGuildInfo,"player")
    self.status=name and name.." | "..#self.rows.." members shown. Whisper prepares your message." or "Join a guild to see its members."
end
local base=G.SettingsChanged
function G:SettingsChanged() base(self); if FS.NativeWindows then FS.NativeWindows:Refresh() end end
G.actions={{label="Whisper",run=function(self) if self.selected and self.selected.name then T:Call(ChatFrame_SendTell,self.selected.name) end end},{label="Guild window",run=function() T:Call(ToggleGuildFrame) end},{label="Refresh",run=function() T:Call(C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster) end}}
