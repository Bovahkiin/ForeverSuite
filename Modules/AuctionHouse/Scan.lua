local _,FS=...
local A,T,H=FS.modules.AuctionHouse,FS.Tools,FS.HUD
FS.defaults.auctionHouse.tooltips=true
FS.defaults.auctionHouse.disenchant=true
table.insert(A.options,{key="tooltips",label="Auction prices in item tooltips",help="Last observed buyout prices for this realm and faction; not live prices or guaranteed sale values."})
table.insert(A.options,{key="disenchant",label="Disenchant value for enchanters",help="A possible material-value range using scanned prices. Unknown material prices never count as zero."})
A.description="Scan at an auctioneer, then see cached prices in item tooltips anywhere. Prices are past observations; buying and selling stay in the auction window."
local oldEvent,oldApply,oldSettings=A.Event,A.Apply,A.SettingsChanged
function A:ScanStatus(message)
    self.scanMessage=message; self.status=message
    if self.scanStatus then self.scanStatus:SetText(message) end
    if self.scanButton then self.scanButton:SetText(self.fullScan and "Stop scan" or "Scan all") end
end
function A:StopCapture(reason)
    self.fullScan=nil
    self:ScanStatus(reason or "Scan stopped. Previous prices kept.")
end
function A:StartFullScan()
    if self.fullScan then self:StopCapture(); return false end
    local API=C_AuctionHouse
    local function refuse(message) self:ScanStatus(message); return false end
    if not FS:IsModuleEnabled(self.name) or not self.open then return refuse("Open the auction house first.") end
    if InCombatLockdown() then return refuse("Leave combat before scanning.") end
    if not FS.Hub:Writable() or FS.databaseReadOnly then return refuse("Saved data is read-only. Update ForeverSuite before scanning.") end
    if not API or not API.ReplicateItems or not API.GetNumReplicateItems or not API.GetReplicateItemInfo then
        return refuse("Full scans are unavailable on this client. Browsing still records loaded results.")
    end
    if API.IsThrottledMessageSystemReady and T:Call(API.IsThrottledMessageSystemReady)~=true then return refuse("Auction House is busy. Try again shortly.") end
    local now=time and time() or 0
    local hub=FS.Hub:Data(); hub.auctionScanRequests=hub.auctionScanRequests or {}
    local scope=self:Scope(); local previous=hub.auctionScanRequests[scope]
    if T:Number(previous) and now>=previous and now-previous<900 then
        return refuse("Scan cooldown: try again in "..math.ceil((900-now+previous)/60).." min.")
    end
    local job={scope=scope,db=FS.db,hub=hub,prices={},stamp=now,read=0,unique=0}
    self.fullScan=job; hub.auctionScanRequests[scope]=now
    self:ScanStatus("Requesting all auction listings...")
    local ok=pcall(API.ReplicateItems)
    if not ok then self:StopCapture("Scan request failed. Previous prices kept."); return false end
    C_Timer.After(90,function()
        if self.fullScan==job then self:StopCapture("No scan response. The server may be on cooldown; try again later.") end
    end)
    return true
end
function A:ConsumeFullScan()
    local job=self.fullScan
    if not job or job.processing then return end
    local API=C_AuctionHouse
    local total=T:Call(API and API.GetNumReplicateItems)
    if not T:Number(total) or total<0 or total>500000 or total%1~=0 then self:StopCapture("Scan size unavailable or too large. Previous prices kept."); return end
    job.processing=true; job.total=total
    local function read(index)
        local _,_,quantity,_,_,_,_,_,_,buyout,_,_,_,_,_,_,id=API.GetReplicateItemInfo(index)
        return id,quantity,buyout
    end
    local function batch()
        if self.fullScan~=job then return end
        if not self.open or InCombatLockdown() or not FS:IsModuleEnabled(A.name) or not FS.Hub:Writable()
            or FS.databaseReadOnly or FS.db~=job.db or FS.Hub:Data()~=job.hub or self:Scope()~=job.scope then
            self:StopCapture("Scan stopped after the auction house or setup changed. Previous prices kept."); return
        end
        for index=job.read+1,math.min(total,job.read+200) do
            local id,quantity,buyout=T:Call(read,index)
            if T:Number(id) and id>0 and id%1==0 and T:Number(quantity) and quantity>0 and T:Number(buyout) and buyout>0 then
                local row=job.prices[id]; local unit=buyout/quantity
                if not row then
                    job.unique=job.unique+1
                    if job.unique>20000 then self:StopCapture("More than 20,000 distinct items. Scan not saved; previous prices kept."); return end
                    job.prices[id]={price=unit,time=job.stamp,kind="per item"}
                elseif unit<row.price then row.price=unit end
            end
            job.read=index
        end
        self:ScanStatus("Scanning "..job.read.." / "..total.." listings")
        if job.read<total then C_Timer.After(0,batch); return end
        -- Keep observations for absent items, with their original timestamps.
        self:StoreScan(job.prices); self.fullScan=nil
        self:ScanStatus("Scan complete: "..job.unique.." item prices saved.")
        if self.window and self.window:IsShown() then self:Refresh() end
    end
    batch()
end
function A:InstallScanButton()
    local root=AuctionHouseFrame or AuctionFrame
    if not root or type(root.GetFrameLevel)~="function" or (root.IsForbidden and root:IsForbidden()) then return end
    if self.scanRoot==root then return end
    if self.scanButton then self.scanButton:Hide(); self.scanStatus:Hide() end
    self.scanRoot=root
    local b=H:Button(root,"Scan all",0,0,124,function() self:StartFullScan() end)
    self.scanButton=b; b:ClearAllPoints(); b:SetPoint("TOPRIGHT",root,"TOPRIGHT",-48,-2); b:SetHeight(24)
    b:SetFrameStrata("DIALOG"); b:SetFrameLevel(root:GetFrameLevel()+100); b:EnableMouse(true); b:RegisterForClicks("LeftButtonUp")
    H:SetHelp(b,"Request all auction listings once. Server cooldown: about 15 minutes. Click again to stop; no purchases are made.")
    self.scanStatus=H:Label(root,"",0,0,420); self.scanStatus:ClearAllPoints()
    self.scanStatus:SetPoint("BOTTOMLEFT",root,"TOPLEFT",12,8)
    self.scanStatus:SetTextColor(1,.82,0)
    self:ScanStatus(self.scanMessage or "Scan here to see prices in item tooltips.")
end
function A:Apply()
    if oldApply then oldApply(self) end
    self:InstallScanButton(); self:InstallPriceTooltips()
    if self.scanButton then self.scanButton:SetShown(FS:IsModuleEnabled(self.name)) end
end
function A:SettingsChanged()
    if self.fullScan then self:StopCapture("Scan stopped after settings changed. Previous prices kept.") end
    oldSettings(self)
    if self.scanButton then self.scanButton:SetShown(FS:IsModuleEnabled(self.name)) end
    if self.scanStatus then self.scanStatus:SetShown(FS:IsModuleEnabled(self.name)) end
end
function A:Event(event,...)
    if event=="REPLICATE_ITEM_LIST_UPDATE" then self:ConsumeFullScan(); return end
    if event=="SKILL_LINES_CHANGED" or event=="SPELLS_CHANGED" or event=="PLAYER_ENTERING_WORLD" then self.enchanter=nil; return end
    if event=="PLAYER_REGEN_DISABLED" then if self.fullScan then self:StopCapture("Scan stopped on entering combat. Previous prices kept.") end; return end
    if event=="ADDON_LOADED" then self:Apply(); return end
    if event=="AUCTION_HOUSE_CLOSED" and self.fullScan then self:StopCapture("Auction house closed. Previous prices kept.") end
    if self.fullScan then return end
    oldEvent(self,event,...)
    if event=="AUCTION_HOUSE_SHOW" then self:InstallScanButton() end
end
function A:RefreshOnTick() return false end
local oldInitialize=A.Initialize
function A:Initialize()
    oldInitialize(self)
    for _,event in ipairs({"REPLICATE_ITEM_LIST_UPDATE","ADDON_LOADED","SKILL_LINES_CHANGED","SPELLS_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED"}) do FS:RegisterClientEvent(self.events,event) end
    self.lifecycleActive=nil
    self:SyncLifecycle()
end
