local _,FS=...
FS.client={unsupportedEvents={},frameEvents=setmetatable({},{__mode="k"})}

function FS:RefreshClient()
    local client=self.client
    if type(GetBuildInfo)=="function" then
        local ok,version,build,_,interface=pcall(GetBuildInfo)
        if ok then client.version=version; client.build=build; client.interface=interface end
    end
    client.isForever=type(client.interface)=="number" and math.floor(client.interface/100)==160
    return client
end

-- Forever shares modern UI APIs with other clients, but not every event.
-- Check each event individually so an unavailable optional event does not
-- prevent the rest of the module from registering its supported events.
function FS:RegisterClientEvent(frame,event)
    local reason
    if C_EventUtils and type(C_EventUtils.IsEventValid)=="function" then
        local ok,valid=pcall(C_EventUtils.IsEventValid,event)
        if ok and not valid then reason="Not exposed by this client" end
    end
    if not reason then
        local ok,message=pcall(frame.RegisterEvent,frame,event)
        if ok then
            self.client.unsupportedEvents[event]=nil
            local events=self.client.frameEvents[frame] or {}; self.client.frameEvents[frame]=events; events[event]=true
            return true
        end
        reason=tostring(message)
    end
    self.client.unsupportedEvents[event]=reason
    return false
end

function FS:PrintClientStatus()
    local client=self:RefreshClient()
    self:Print("v"..self.version.." | Client "..tostring(client.version or "unknown").." | Build "..tostring(client.build or "unknown").." | Interface "..tostring(client.interface or "unknown"))
    self:Print(client.isForever and "WoW Forever detected. Live install folder: _forever_/Interface/AddOns/ForeverSuite." or "This release targets WoW Forever, Interface 16001.")
    local names={}; for event in pairs(client.unsupportedEvents) do names[#names+1]=event end; table.sort(names)
    self:Print(#names==0 and "All requested client events registered." or "Unavailable client events: "..table.concat(names,", "))
    local missing={}; for _,entry in ipairs(self:ClientCapabilities()) do if not entry.available then missing[#missing+1]=entry.label end end
    if #missing>0 then self:Print('Unavailable client APIs: '..table.concat(missing,', ')) end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded)=="function" then
        for _,entry in ipairs({{"Baganator","Bags"},{"Chattynator","Chat"},{"Platynator","Nameplates"}}) do
            local ok,loaded=pcall(C_AddOns.IsAddOnLoaded,entry[1])
            if ok and loaded and self.db and self:IsModuleEnabled(entry[2]) then
                self:Print(entry[1].." and ForeverSuite "..entry[2].." both manage the same UI. Choose one in the addon list or Control Center.")
            end
        end
    end
end
function FS:ClientCapabilities()
    local function fn(value) return type(value)=='function' end
    return {
        {label='Inventory',available=C_Container and fn(C_Container.GetContainerItemInfo)},
        {label='Item information',available=C_Item and fn(C_Item.GetItemInfo)},
        {label='Map position',available=C_Map and fn(C_Map.GetPlayerMapPosition)},
        {label='Nameplates',available=C_NamePlate and fn(C_NamePlate.GetNamePlateForUnit)},
        {label='Recipes',available=(C_TradeSkillUI and (fn(C_TradeSkillUI.GetAllRecipeIDs) or fn(C_TradeSkillUI.GetFilteredRecipeIDs))) or fn(GetNumTradeSkills)},
        {label='Chat filters',available=(ChatFrameUtil and fn(ChatFrameUtil.AddMessageEventFilter) and fn(ChatFrameUtil.RemoveMessageEventFilter)) or (fn(ChatFrame_AddMessageEventFilter) and fn(ChatFrame_RemoveMessageEventFilter))},
        {label='Audio alerts',available=fn(PlaySound)},
        {label='Buyback',available=fn(BuybackItem) and fn(GetNumBuybackItems)},
    }
end
