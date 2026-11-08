local _, FS = ...
local U, H = FS.modules.UnitFrames, FS.HUD
function U:CreateCast(f)
    local bar = CreateFrame("StatusBar", nil, f, "BackdropTemplate"); H:Skin(bar)
    bar:SetSize(270, 18); bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -4)
    bar:SetStatusBarTexture(H.texture); bar:SetStatusBarColor(0.12, 0.72, 0.86)
    bar.label = H:Label(bar, "", 5, -3, 260); bar.label:SetHeight(14)
    bar:SetScript("OnUpdate", function(b) U:UpdateCastProgress(b) end)
    bar:EnableMouse(false); bar:Hide(); f.cast = bar
end
function U:UpdateCastProgress(bar)
    if bar.startSeconds then
        local elapsed=GetTime()-bar.startSeconds
        local progress=math.max(0,math.min(1,elapsed/bar.durationSeconds))
        -- This value already advances every rendered frame. Native smoothing
        -- would continually chase it, making the fill lag or jump on refresh.
        local immediate=Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
        if immediate then bar:SetValue(bar.channel and (1-progress) or progress,immediate)
        else bar:SetValue(bar.channel and (1-progress) or progress) end
        if elapsed>=bar.durationSeconds then bar:Hide() end
    else
        -- Restricted timestamps go directly to the widget, without arithmetic.
        bar:SetValue(GetTime()*1000)
    end
end
function U:RefreshCast(unit, frame)
    local f = frame or self.frames[unit]; if not f or not f.cast then return end
    local name, startTime, endTime, channel
    if UnitCastingInfo then
        local text, _, _, startMS, endMS = UnitCastingInfo(unit)
        name, startTime, endTime = text, startMS, endMS
    end
    if H:Safe(name) and not name and UnitChannelInfo then
        local text, _, _, startMS, endMS = UnitChannelInfo(unit)
        name, startTime, endTime, channel = text, startMS, endMS, true
    end
    -- No restricted timing values are used in Lua arithmetic.
    local validStart = not H:Safe(startTime) or type(startTime) == "number"
    local validEnd = not H:Safe(endTime) or type(endTime) == "number"
    if H:Safe(name) and name and validStart and validEnd then
        local bar=f.cast; bar.channelEnd=nil; bar.label:SetText(name)
        if H:Safe(startTime) and H:Safe(endTime) then
            local duration=(endTime-startTime)/1000
            if duration<=0 then bar.startSeconds=nil; bar:Hide(); return end
            local start=startTime/1000
            if bar.startSeconds~=start or bar.durationSeconds~=duration or bar.channel~=(channel==true) then
                bar:SetMinMaxValues(0,1); bar:SetReverseFill(false)
            end
            bar.startSeconds,bar.durationSeconds,bar.channel=start,duration,channel==true
        else
            bar.startSeconds=nil; bar.durationSeconds=nil; bar.channel=nil
            bar:SetMinMaxValues(startTime,endTime); bar:SetReverseFill(channel==true)
        end
        bar:Show(); self:UpdateCastProgress(bar)
    else f.cast.channelEnd=nil; f.cast.startSeconds=nil; f.cast.durationSeconds=nil; f.cast:Hide() end
end
