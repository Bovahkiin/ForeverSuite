local _,FS=...
local T=FS.Tools
local C=T:Module("Chat","chat","Chat","Customize chat panels, buttons, tabs, input, font, timestamps, fading and history. Changes apply to all normal chat windows.",
    {styleWindow=true,styleTabs=true,styleInput=true,styleButtons=true,fontSize=14,outline=false,backgroundOpacity=.85,borderColor="Cyan",timestamps=false,timestampFormat="24h",fade=false,fadeDelay=120,historyLines=512},
    {"UPDATE_CHAT_WINDOWS","UPDATE_FLOATING_CHAT_WINDOWS","PLAYER_ENTERING_WORLD"})
C.options={{key="styleWindow",label="Style chat panels"},{key="styleTabs",label="Style chat tabs"},{key="styleInput",label="Style message input"},
    {key="styleButtons",label="Style chat buttons"},
    {key="fontSize",label="Text size",values={12,13,14,16,18}}, {key="outline",label="Outlined text"},
    {key="backgroundOpacity",label="Background opacity",values={.55,.7,.85,.95,1},format=function(v) return math.floor(v*100+.5).."%" end},
    {key="borderColor",label="Border color",values={"Cyan","Gold","Violet","Blue","Green","None"}},
    {key="timestamps",label="Chat timestamps"},{key="timestampFormat",label="Timestamp format",values={"24h","24h + seconds","12h"}},
    {key="fade",label="Fade older messages"},{key="fadeDelay",label="Fade delay",values={30,60,120,300},format=function(v) return v.."s" end},
    {key="historyLines",label="Message history",values={128,256,512,1024}}}
C.colors={Cyan={.12,.72,.86},Gold={.95,.68,.24},Violet={.65,.45,.95},Blue={.22,.52,1},Green={.2,.8,.65},None={0,0,0}}
C.original={}
function C:FrameOptions(frame,enabled)
    local state=self.original[frame]
    if not state then
        state={fading=T:Call(frame.GetFading,frame),delay=T:Call(frame.GetTimeVisible,frame),history=T:Call(frame.GetMaxLines,frame)}; self.original[frame]=state
    end
    local data=self:Data()
    local fading=state.fading; if enabled then fading=data.fade end
    if state.fading~=nil then T:Call(frame.SetFading,frame,fading) end
    if state.delay~=nil then T:Call(frame.SetTimeVisible,frame,enabled and data.fadeDelay or state.delay) end
    if state.history~=nil then T:Call(frame.SetMaxLines,frame,enabled and data.historyLines or state.history) end
end
function C:Apply()
    if InCombatLockdown() then return end
    if self.originalTimestamp==nil then self.originalTimestamp=T:Call(GetCVar,"showTimestamps") end
    local formats={["24h"]="%H:%M",["24h + seconds"]="%H:%M:%S",["12h"]="%I:%M %p"}
    T:Call(SetCVar,"showTimestamps",self:Data().timestamps and formats[self:Data().timestampFormat] or "none")
    if FS.Style then FS.Style:Chat() end
end
local base=C.SettingsChanged
function C:SettingsChanged()
    base(self)
    if not InCombatLockdown() and not FS:IsModuleEnabled(self.name) then
        if self.originalTimestamp~=nil then T:Call(SetCVar,"showTimestamps",self.originalTimestamp) end
        if FS.Style then FS.Style:Chat() end
    end
end
function C:ShowWindow()
    if InCombatLockdown() then FS:Print("Leave combat to open Chat settings."); return end
    FS:ConfigureModule(self.name)
end
C.settingsHint="Changes apply to all chat windows and are saved automatically. Use Enter in game to start typing."
C.openLabel="Start typing in chat"
function C:settingsAction()
    local frame=DEFAULT_CHAT_FRAME or ChatFrame1
    local name=T:Text(frame and T:Call(frame.GetName,frame))
    local input=T:Call(ChatEdit_GetActiveWindow) or (frame and (frame.editBox or frame.EditBox)) or (name~="" and _G[name.."EditBox"]) or ChatFrame1EditBox
    if not input then FS:Print("Chat input is not available yet. Press Enter in game to start typing."); return end
    FS:CloseSettingsScreens()
    if FS.window then FS.window:Hide() end
    if type(ChatEdit_ActivateChat)=="function" then local ok=pcall(ChatEdit_ActivateChat,input); if ok then return end end
    T:Call(input.Show,input); T:Call(input.SetFocus,input)
end
