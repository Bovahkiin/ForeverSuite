local _,FS=...
local P={samples={}}
FS.Performance=P

local function number(value)
    if FS.Tools:Number(value) and value>=0 then return value end
end

function P:Now()
    return number(FS.Tools:Call(debugprofilestop))
end

function P:FinishStartup(started)
    local finished=self:Now()
    if started and finished and finished>=started then self.startupMS=finished-started end
end

local function display(value,pattern)
    return value and pattern:format(value) or "unavailable"
end

function P:Describe(sample)
    return ("%s | Recent CPU/frame %s | Session CPU peak %s | Addon memory %s | %s"):format(
        sample.label,display(sample.average,"%.3f ms"),display(sample.peak,"%.3f ms"),
        display(sample.memory,"%.2f MiB"),display(sample.fps,"%.0f FPS"))
end

function P:Capture(label)
    local T=FS.Tools
    label=label:match("^%s*(.-)%s*$")
    if label=="" or #label>48 or label:find("[%c|]") then
        FS:Print("Use a short label, e.g. /fs perf Busy city.")
        return
    end

    local sample={label=label}
    local api=C_AddOnProfiler
    local metrics=Enum and Enum.AddOnProfilerMetric
    if api and metrics and T:Call(api.IsEnabled)~=false then
        if metrics.RecentAverageTime~=nil then
            sample.average=number(T:Call(api.GetAddOnMetric,FS.name,metrics.RecentAverageTime))
        end
        if metrics.PeakTime~=nil then
            sample.peak=number(T:Call(api.GetAddOnMetric,FS.name,metrics.PeakTime))
        end
    end
    if type(UpdateAddOnMemoryUsage)=="function" then
        local ok=pcall(UpdateAddOnMemoryUsage)
        if ok then
            local kb=number(T:Call(GetAddOnMemoryUsage,FS.name))
            if kb then sample.memory=kb/1024 end
        end
    end
    sample.fps=number(T:Call(GetFramerate))
    table.insert(self.samples,1,sample)
    if #self.samples>6 then table.remove(self.samples) end
    FS:Print(self:Describe(sample))
end

function P:Show()
    FS:Print("Initialization callback: "..display(self.startupMS,"%.2f ms")..".")
    if #self.samples==0 then FS:Print("Capture CPU and memory with /fs perf Busy city."); return end
    for i=#self.samples,1,-1 do FS:Print(self:Describe(self.samples[i])) end
end
