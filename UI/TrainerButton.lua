local _,FS=...
local U={};FS.Training=U
local H,T=FS.HUD,FS.Tools
FS.defaults.qol.trainAllButton=true
local Q=FS.modules.QoL
Q.options[#Q.options+1]={key='trainAllButton',label='Train all in trainer windows',help='Review the coin cost and train approved lessons at class and profession trainers. Skills that consume profession slots, talent points or pet training points are excluded.'}
function U:Allowed(frame)
    return FS.initialized and FS:IsModuleEnabled('QoL') and FS.db.qol.trainAllButton and not InCombatLockdown()
        and frame and frame==ClassTrainerFrame and frame:IsShown() and not (frame.IsForbidden and frame:IsForbidden())
end
function U:Refresh()
    local frame=ClassTrainerFrame
    if not frame or not frame.GetFrameLevel or (frame.IsForbidden and frame:IsForbidden()) then return end
    local button=frame.fsTrainAll
    if not self:Allowed(frame) then if button then button:Hide() end;return end
    if not button then
        button=H:Button(UIParent,'Train all',0,0,128,function()
            local W=FS.modules.Workbench
            if W.training and W.training.owner==frame then W:StopTraining('Stopped by player.') else W:ConfirmTraining(frame) end
            U:Refresh()
        end)
        frame.fsTrainAll=button;button:SetFrameLevel(frame:GetFrameLevel()+8)
        frame:HookScript('OnHide',function()
            button:Hide()
            local W=FS.modules.Workbench
            if W.training and W.training.owner==frame then W:StopTraining('Trainer closed.') end
        end)
        H:SetHelp(button,'Review the total cost, then train the approved lessons. New lessons unlocked during the batch require a new approval.')
    end
    local W=FS.modules.Workbench
    if W.training and W.training.owner==frame then
        button:SetText('Stop training');button:SetEnabled(true)
        H:SetHelp(button,'Confirmed lessons: '..W.training.completed..' / '..#W.training.entries..'. Click to stop.')
    else
        local data,why=W:ReadTrainer();local entries,total=W:TrainingPlan(data);total=total or 0;local count=entries and #entries or 0
        local balance=T:Call(GetMoney)
        button:SetText('Train all')
        button:SetEnabled(count>0 and T:Number(balance) and balance>=total and type(BuyTrainerService)=='function')
        H:SetHelp(button,why or count..' lessons | '..FS.modules.Vendor:Money(total)..'. Click to review; no training is purchased until you confirm.')
    end
    local context=FS.Context and FS.Context.hosts[frame]
    local tools=context and context.button
    button:SetShown(H:DockServiceAction(frame,button,2,2,tools))
    if tools and context.update then context.update() end
end
local events=CreateFrame('Frame');U.events=events
for _,event in ipairs({'TRAINER_SHOW','TRAINER_UPDATE','TRAINER_CLOSED','PLAYER_MONEY','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','ADDON_LOADED'}) do FS:RegisterClientEvent(events,event) end
events:SetScript('OnEvent',function(_,event)
    if not FS.initialized then return end
    if event=='PLAYER_REGEN_DISABLED' and FS.modules.Workbench.training then FS.modules.Workbench:StopTraining('Entered combat.') end
    if U.queued then return end;U.queued=true
    C_Timer.After(0,function() U.queued=nil;U:Refresh() end)
end)
local changed=Q.SettingsChanged
function Q:SettingsChanged(...) changed(self,...);if FS.initialized then U:Refresh() end end
