local _,FS=...
local T,H=FS.Tools,FS.HUD
local M=T:Module('Mail','mail','Mail','Read your inbox and collect mail at a mailbox. COD and GM mail are always left for manual handling.',
    {autoOpen=true,styleWindow=true,collectMoney=true,collectItems=true,sort='Newest',showExpiry=true},
    {'MAIL_SHOW','MAIL_CLOSED','MAIL_INBOX_UPDATE','MAIL_FAILED','PLAYER_REGEN_DISABLED'})
M.options={{key='autoOpen',label='Open Mail tools at a mailbox'},{key='styleWindow',label='Theme the game mailbox'},
    {key='collectMoney',label='Collect attached money'},{key='collectItems',label='Collect attached items'},
    {key='sort',label='Inbox order',values={'Newest','Sender','Expiry'}},{key='showExpiry',label='Show days until expiry'}}
local function num(value) return T:Number(value) and value>=0 and value or 0 end
function M:Header(index)
    local _,_,sender,subject,money,cod,days,count,read,returned,created,reply,gm=T:Call(GetInboxHeaderInfo,index)
    if type(sender)~='string' or type(subject)~='string' then return end
    if not T:Number(money) or not T:Number(cod) or not T:Number(days) then return end
    if count~=nil and not T:Number(count) then return end
    return {index=index,sender=sender,subject=subject,money=money,cod=cod,days=days,count=num(count),gm=gm==true,
        identity=sender..'\031'..subject..'\031'..math.floor(days*24),unread=not read}
end
function M:Inbox()
    local rows={}; local count=num(T:Call(GetInboxNumItems))
    for i=1,math.min(100,count) do local row=self:Header(i); if row then rows[#rows+1]=row end end
    return rows
end
function M:Signature(rows)
    local parts={}
    for _,r in ipairs(rows or self:Inbox()) do
        parts[#parts+1]=r.identity..':'..r.money..':'..r.count
        local found=0
        for slot=1,16 do
            if found>=r.count then break end
            local link=T:Text(T:Call(GetInboxItemLink,r.index,slot))
            if link~='' then parts[#parts+1]=slot..':'..link; found=found+1 end
        end
    end
    return table.concat(parts,'|')
end
function M:Matches(row,query)
    return (row.sender..' '..row.subject):lower():find((query or ''):lower(),1,true)~=nil
end
function M:Build()
    self.rows={}
    if not self.atMailbox then self.status='Visit a mailbox to read or collect mail.'; return end
    self.rows=self:Inbox()
    table.sort(self.rows,function(a,b)
        local sort=self:Data().sort
        if sort=='Sender' and a.sender~=b.sender then return a.sender<b.sender end
        if sort=='Expiry' and a.days~=b.days then return a.days<b.days end
        return a.index<b.index
    end)
    for _,r in ipairs(self.rows) do
        r.text=(r.unread and '* ' or '')..r.sender..' - '..r.subject..' | '..r.count..' items'
        if r.money>0 then r.text=r.text..' | '..FS.modules.Vendor:Money(r.money) end
        if r.cod>0 then r.text=r.text..' | COD (manual)' end
        if r.gm then r.text=r.text..' | GM (manual)' end
        if self:Data().showExpiry then r.text=r.text..' | '..math.floor(r.days)..' days' end
    end
    self.status=self.collecting and 'Collecting... Stop cancels the remaining queue.' or 'Select mail to read. Collect all uses the current search and collection settings.'
end
function M:SelectedHeader()
    if not self.selected then return end
    local result
    for _,r in ipairs(self:Inbox()) do
        if r.identity==self.selected.identity then if result then return end; result=r end
    end
    return result
end
function M:OnSelect()
    local row=self:SelectedHeader(); if not row then return end
    local body=T:Text(T:Call(GetInboxText,row.index))
    if FS.Extensions.TextDialog then
        FS.Extensions:TextDialog(row.sender..' - '..row.subject,body~='' and body or '(No message text)',true,nil,nil,function() if self.atMailbox then self:ShowWindow() end end)
    end
end
function M:Stop(message)
    self.collecting=nil; self.waiting=nil; self.scheduled=nil; self.pendingSince=nil; self.generation=(self.generation or 0)+1
    if message then self.notice=message; self.noticeUntil=GetTime()+8 end
end
function M:Schedule()
    if not self.collecting or self.scheduled==self.generation then return end
    local generation=self.generation; self.scheduled=generation
    C_Timer.After(.4,function()
        if self.scheduled==generation then self.scheduled=nil end
        if generation==self.generation and self.collecting then self:Step() end
    end)
end
function M:Step()
    if not self.collecting then return end
    if not self.atMailbox or InCombatLockdown() or not FS:IsModuleEnabled(self.name) then self:Stop('Mail collection stopped.'); return end
    local now=GetTime()
    if self.waiting and now-self.waiting.at>10 then self:Stop('Mail did not update. Try again after the mailbox responds.'); return end
    if T:Call(C_Mail and C_Mail.IsCommandPending) then
        self.pendingSince=self.pendingSince or now
        if now-self.pendingSince>10 then self:Stop('The mailbox is still busy. Try again after it responds.')
        else self:Schedule() end
        return
    end
    self.pendingSince=nil
    local rows=self:Inbox()
    local signature
    if self.waiting then
        signature=self:Signature(rows)
        if signature==self.waiting.signature then self:Schedule(); return end
        self.waiting=nil
    end
    local candidates=rows
    if self.collecting.identity then
        local matches={}; for _,r in ipairs(rows) do if r.identity==self.collecting.identity then matches[#matches+1]=r end end
        if #matches~=1 then self:Stop('Selected mail changed or is ambiguous. Select it again.'); return end
        candidates=matches
    end
    for i=#candidates,1,-1 do
        local r=candidates[i]
        if not r.gm and r.cod==0 and self:Matches(r,self.collecting.query) then
            local action,slot
            if self:Data().collectMoney and r.money>0 then action=TakeInboxMoney
            elseif self:Data().collectItems and r.count>0 then
                local free=T:Call(C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots)
                if not T:Number(free) then self:Stop('Free bag space is unavailable.'); return end
                if free<=0 then self:Stop('Your bags are full. Free space before collecting more.'); return end
                for j=16,1,-1 do if T:Call(GetInboxItemLink,r.index,j) then action=TakeInboxItem; slot=j; break end end
            end
            if type(action)=='function' then
                self.waiting={at=now,signature=signature or self:Signature(rows)}
                local ok,accepted=pcall(action,r.index,slot)
                if not ok or accepted==false then self:Stop('The game could not collect this attachment.'); return end
                self:Schedule(); return
            end
        end
    end
    self:Stop('Collection finished. COD and GM mail were left untouched.'); self:Refresh()
end
function M:Collect(all)
    if not self.atMailbox or InCombatLockdown() or not FS:IsModuleEnabled(self.name) then self.status='Visit a mailbox outside combat first.'; return end
    if self.collecting then return end
    local r=not all and self:SelectedHeader()
    if not all and not r then self.status='Select an unambiguous mail first.'; return end
    self.generation=(self.generation or 0)+1
    self.collecting={identity=r and r.identity,query=all and (self.window and self.window.search:GetText() or '') or ''}
    self:Step()
end
M.actions={{label='Collect',run=function(self) self:Collect(false) end},{label='Collect all',run=function(self) self:Collect(true) end},{label='Stop',run=function(self) self:Stop('Collection stopped.') end}}
function M:Event(event)
    if event=='MAIL_SHOW' then self.atMailbox=true; self:Apply(); self.selected=nil; if self:Data().autoOpen then self:ShowWindow() end
    elseif event=='MAIL_CLOSED' then self.atMailbox=false; self:Stop(); if self.window then self.window:Hide() end
    elseif event=='MAIL_FAILED' or event=='PLAYER_REGEN_DISABLED' then self:Stop('Collection stopped. Check mailbox, bag space and game messages.')
    elseif event=='MAIL_INBOX_UPDATE' then self:Schedule() end
end
function M:Apply()
    if not FS:IsModuleEnabled(self.name) then self:Stop(); self.atMailbox=false; if self.mailButton then self.mailButton:Hide() end; return end
    self.atMailbox=MailFrame and MailFrame:IsShown() or self.atMailbox
    if MailFrame and not self.mailButton then
        self.mailButton=H:Button(MailFrame,'Mail tools',12,-32,140,function() self:ShowWindow() end)
        self.mailButton.fsFontModule=self.name; self.mailButton:SetFrameLevel(MailFrame:GetFrameLevel()+10)
    end
    if self.mailButton then self.mailButton:Show() end
end
function M:StopCapture()
    self:Stop(); self.atMailbox=false
    if self.mailButton then self.mailButton:Hide() end
end
local render=M.Render
function M:Render() render(self); if self.window then self.window.input:Hide() end end
