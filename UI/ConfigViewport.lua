local _,FS=...
function FS:CreateConfigViewport(f)
    local scroll=CreateFrame("ScrollFrame",nil,f); f.bodyScroll=scroll
    scroll:EnableMouseWheel(true); scroll:SetClipsChildren(true)
    local content=CreateFrame("Frame",nil,scroll); f.bodyContent=content; content:SetWidth(940); content:SetPoint("TOPLEFT",0,0); scroll:SetScrollChild(content)
    f.bodyNodes={f.moduleSearch,f.clearModuleSearch,f.moduleFilterButton,f.emptyModules,f.previousModules,f.nextModules,f.modulePage,
        f.general,f.minimap,f.welcome,f.help,f.typography,f.setup,f.appearance,f.tools,f.undo,f.addons,f.recovery,f.tour,f.workbench,f.disableAll,f.favorites,f.nextSteps}
    for _,card in pairs(f.cards) do f.bodyNodes[#f.bodyNodes+1]=card.card end
    for _,node in ipairs(f.bodyNodes) do node:SetParent(content) end
    scroll:SetScript("OnMouseWheel",function(_,delta) self:ScrollConfig((f.scrollOffset or 0)-delta*(f.scrollStep or 60)) end)
    local bar=CreateFrame("Slider",nil,f,"BackdropTemplate"); f.bodyScrollbar=bar; self.HUD:Skin(bar)
    bar:SetWidth(12); bar:SetOrientation("VERTICAL"); bar:SetMinMaxValues(0,1); bar:SetValueStep(1); bar:SetObeyStepOnDrag(true)
    bar:SetThumbTexture(self.HUD.texture); local thumb=bar:GetThumbTexture(); thumb:SetSize(10,36); thumb:SetVertexColor(.12,.72,.86,1)
    bar:SetScript("OnValueChanged",function(_,value) if not f.updatingScrollbar then self:ScrollConfig(value) end end)
    bar:EnableMouseWheel(true); bar:SetScript("OnMouseWheel",scroll:GetScript("OnMouseWheel"))
    f.scrollUp=self.HUD:Button(f,"^",922,-200,14,function() self:ScrollConfig((f.scrollOffset or 0)-(f.scrollStep or 60)) end)
    f.scrollDown=self.HUD:Button(f,"v",922,-700,14,function() self:ScrollConfig((f.scrollOffset or 0)+(f.scrollStep or 60)) end)
end
function FS:ScrollConfig(value)
    local f=self.window; if not f or not f.bodyScroll then return end
    value=math.max(0,math.min(f.scrollMaximum or 0,value or 0)); f.scrollOffset=value
    f.bodyScroll:SetVerticalScroll(value)
    f.updatingScrollbar=true; f.bodyScrollbar:SetValue(value); f.updatingScrollbar=false
    f.scrollUp:SetEnabled(value>0); f.scrollDown:SetEnabled(value<(f.scrollMaximum or 0))
end
function FS:FitConfigViewport(bodyTop,contentBottom,footer,naturalHeight)
    local f=self.window; if not f or not f.bodyScroll then return end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight(); local saved=self.db.layout.frames.ControlCenter
    local requested=saved and saved.scale or 1
    local scale=math.min(requested,(w-32)/940)
    local minimum=bodyTop+footer+48+120
    scale=math.max(.1,math.min(scale,(h-32)/minimum))
    local height=math.min(naturalHeight,(h-32)/scale)
    f:SetHeight(height); f:SetScale(scale)
    local viewport=math.max(1,height-bodyTop-footer-48)
    f.bodyTop=bodyTop
    f.bodyScroll:ClearAllPoints(); f.bodyScroll:SetPoint("TOPLEFT",0,-bodyTop); f.bodyScroll:SetSize(940,viewport)
    f.bodyContent:SetSize(940,math.max(1,contentBottom-bodyTop+12))
    if f.bodyScroll.UpdateScrollChildRect then f.bodyScroll:UpdateScrollChildRect() end
    for _,node in ipairs(f.bodyNodes) do
        local p={node:GetPoint()}; local x,y=p[4] or p[2],p[5] or p[3]
        node:ClearAllPoints(); node:SetPoint(p[1],x,y+bodyTop)
    end
    f.scrollMaximum=math.max(0,f.bodyContent:GetHeight()-viewport)
    local bar=f.bodyScrollbar; bar:ClearAllPoints(); bar:SetPoint("TOPLEFT",922,-bodyTop-25); bar:SetHeight(math.max(1,viewport-50)); bar:SetMinMaxValues(0,f.scrollMaximum)
    f.scrollUp:ClearAllPoints(); f.scrollUp:SetPoint("TOPLEFT",922,-bodyTop); f.scrollUp:SetHeight(22)
    f.scrollDown:ClearAllPoints(); f.scrollDown:SetPoint("TOPLEFT",922,-bodyTop-viewport+22); f.scrollDown:SetHeight(22)
    for _,b in ipairs({f.scrollUp,f.scrollDown}) do
        b.fsLabel:SetFont(self.font,12,""); b.fsLabel:SetWidth(14); b.fsLabel:SetHeight(16)
    end
    for _,control in ipairs({bar,f.scrollUp,f.scrollDown}) do control:SetShown(f.scrollMaximum>0) end
    local _,size=f.cards.Bags.heading:GetFont(); f.scrollStep=math.max(40,(size or 14)*3)
    self:ScrollConfig(f.scrollOffset)
    local hw,hh=940*scale/2,height*scale/2
    local x=saved and saved.x or self.db.window.x; local y=saved and saved.y or h/2+self.db.window.y
    x=math.max(-w/2+hw+16,math.min(w/2-hw-16,x)); y=math.max(hh+16,math.min(h-hh-16,y))
    f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"BOTTOM",x/scale,y/scale)
end
