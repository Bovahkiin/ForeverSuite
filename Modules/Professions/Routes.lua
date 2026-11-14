local _,FS=...
local P,T=FS.modules.Professions,FS.Tools
local branches={"Apprentice","Journeyman","Expert","Artisan"}
local gathering={
    [182]={
        {70,"Peacebloom and Silverleaf | Starting zones or Zephras Isle"},
        {115,"Mageroyal and Briarthorn | Darkshore"},
        {170,"Bruiseweed and Wild Steelbloom | Hillsbrad Foothills"},
        {205,"Kingsblood and Goldthorn | Arathi Highlands"},
        {230,"Firebloom and Purple Lotus | Tanaris"},
        {270,"Sungrass | The Hinterlands"},
        {300,"Dreamfoil and Gromsblood | Felwood"},
    },
    [186]={
        {65,"Copper Veins | Starting zones or Zephras Isle"},
        {125,"Tin Veins | Westfall or Silverpine Forest"},
        {175,"Iron Deposits | Arathi Highlands"},
        {245,"Mithril Deposits | The Hinterlands"},
        {275,"Small Thorium Veins | Un'Goro Crater"},
        {300,"Rich Thorium Veins | Burning Steppes"},
    },
    [356]={
        {75,"Fish in your starting zone, such as Mulgore or Zephras Isle"},
        {150,"Fish in accessible capital waters, such as Thunder Bluff"},
        {225,"Fish in a zone your skill can support; use a lure if fish escape"},
        {300,"Continue in reliable waters after unlocking Artisan Fishing"},
    },
    [393]={
        {75,"Skin starter beasts | Durotar or Elwynn Forest"},
        {125,"Skin level 16–17 beasts | Loch Modan or the Barrens"},
        {150,"Skin lower-level raptors in the Barrens or Wetlands"},
        {225,"Skin beasts in Duskwood or Hillsbrad Foothills"},
        {280,"Skin yetis in Feralas"},
        {300,"Skin dinosaurs in Un'Goro Crater"},
    },
}
local rankGuides={
    [129]={
        [3]={125,0,"Read Expert First Aid - Under Wraps. Deneb Walker and Balai Lok'Wein sell it."},
        [4]={225,35,"Complete Triage with Doctor Gregory Victor (Horde) or Doctor Gustaf VanHowzen (Alliance)."},
    },
    [164]={[4]={200,35,"Brikk Keencraft teaches Artisan Blacksmithing in Booty Bay."}},
    [165]={[4]={200,35,"Visit Hahrana Ironhide in Feralas (Horde) or Drakk Stonehand in the Hinterlands (Alliance)."}},
    [171]={[4]={200,35,"Visit Rogvar in Stonard (Horde) or Kylanna Windwhisper in Feralas (Alliance)."}},
    [185]={
        [3]={125,0,"Read Expert Cookbook from Wulan (Horde) or Shandrina (Alliance)."},
        [4]={225,35,"Complete Clamlette Surprise with Dirge Quikcleave in Gadgetzan."},
    },
    [197]={[4]={200,35,"Visit Daryl Stack in Hillsbrad Foothills (Horde) or Timothy Worthington in Theramore (Alliance)."}},
    [202]={[4]={200,35,"Buzzek Bracketswing teaches Artisan Engineering in Gadgetzan."}},
    [333]={[4]={200,35,"Annora teaches Artisan Enchanting inside Uldaman."}},
    [356]={
        [3]={125,20,"Read Expert Fishing - The Bass and You, sold by Old Man Heming in Booty Bay."},
        [4]={225,35,"Complete Nat Pagle, Angler Extreme in Dustwallow Marsh."},
    },
}

function P:LoadProfessionCatalog()
    if not FS.ProfessionCatalog and not self.professionCatalogAttempted and not InCombatLockdown() then
        self.professionCatalogAttempted=true
        T:Call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,"ForeverSuite_ProfessionData")
    end
    return FS.ProfessionCatalog
end

local function trainerDetails(catalog,ids)
    if #ids==0 then return end
    local locations={}
    for i=1,math.min(3,#ids) do
        local npc=catalog.trainers[ids[i]]
        if npc then
            local zone=npc[2]>0 and T:Call(C_Map and C_Map.GetMapInfo,npc[2])
            local name=npc[1]
            if type(zone)=="table" and T:Text(zone.name)~="" then
                name=("%s (%s %.1f, %.1f)"):format(name,zone.name,npc[3]*100,npc[4]*100)
            end
            locations[#locations+1]=name
        end
    end
    if #locations>0 then return table.concat(locations,"; ") end
end

local function trainingStep(catalog,profession,tier,rank)
    local text=branches[tier].." training | Cap "..tier*75
    local trainers=rank and trainerDetails(catalog,rank[4])
    local guide=rankGuides[profession] and rankGuides[profession][tier]
    local skill=rank and rank[2]>0 and rank[2] or guide and guide[1]
    local player=rank and rank[3]>0 and rank[3] or guide and guide[2]
    local level=player and player>0 and (" | Character level "..player) or ""
    local requirement=skill and skill>0 and (" | Skill "..skill) or ""
    return {text=text..requirement..level,
        detailLine=trainers and ("Observed trainers: "..trainers) or guide and ("Guide reference: "..guide[3])
            or "Check the acquisition source for this rank in game."}
end

function P:RecipeReferences()
    local catalog=self:LoadProfessionCatalog()
    if not catalog then return end
    local found={}
    for _,profession in pairs(catalog.professions) do
        for _,recipe in ipairs(profession.recipes) do found[recipe[1]]=recipe end
    end
    return found
end

function P:KnownRecipeSource(recipe)
    if not recipe then return end
    local trainers=trainerDetails(FS.ProfessionCatalog,recipe[9])
    if trainers then return "Observed trainers: "..trainers end
    if recipe[7]==1 then return "Client marks this recipe as learned automatically." end
end

local function recipeInputs(recipe,prices)
    local price,quantity=0,0
    for i=1,#recipe[8],2 do
        local id,count=recipe[8][i],recipe[8][i+1]
        local observed=P:UnitPrice(prices,id)
        quantity=quantity+count
        if price and observed then
            price=price+observed*count
        else
            price=nil
        end
    end
    return {recipe=recipe,price=price,quantity=quantity}
end

local function recipePriority(candidate,current)
    local recipe=candidate.recipe
    local yellow,gray=recipe[4],recipe[5]
    local color=current<yellow and 0 or current<(yellow+gray)/2 and 1 or 2
    local source=recipe[7]>0 and 0 or 3
    return source+color,color
end

function P:BuildProfessionRoute(professionID,first,last)
    local catalog=self:LoadProfessionCatalog()
    local profession=catalog and catalog.professions[professionID]
    if not profession then return end
    local plan={profession=professionID,first=first,last=last,rows={},materials={},unverified=false,gaps=false}
    local prices=FS.modules.AuctionHouse:Prices()
    local options,ingredients,itemIDs={},{},{}
    local function row(text,detail)
        plan.rows[#plan.rows+1]={text=text,detailLine=detail}
    end
    for _,recipe in ipairs(profession.recipes) do
        options[#options+1]=recipeInputs(recipe,prices)
    end
    local skill,tier=first,nil
    local segment
    local function finishSegment()
        if not segment then return end
        local recipe=segment.recipe
        if recipe then
            local source=self:KnownRecipeSource(recipe)
            if recipe[7]==0 then
                source="Estimated unlock skill. Confirm the recipe source before buying materials."
                plan.unverified=true
            end
            local caption=("%d–%d | %s | %d+ crafts"):format(segment.first,segment.last,recipe[2],segment.crafts)
            if recipe[7]==0 then caption=caption.." | Check source" end
            if segment.color>0 then caption=caption.." | Variable gains" end
            row(caption,source)
            for i=1,#recipe[8],2 do
                local id,count=recipe[8][i],recipe[8][i+1]*segment.crafts
                if not ingredients[id] then itemIDs[#itemIDs+1]=id end
                ingredients[id]=(ingredients[id] or 0)+count
            end
        else
            plan.gaps=true
            row(("%d–%d | Find a skill-up recipe in game"):format(segment.first,segment.last))
        end
        segment=nil
    end
    while skill<last do
        local nextTier=math.floor(skill/75)+1
        if nextTier~=tier then
            finishSegment()
            tier=nextTier
            plan.rows[#plan.rows+1]=trainingStep(catalog,professionID,tier,profession.ranks[tier])
        end
        local cap=math.min(last,tier*75)
        if profession.gathering then
            for _,stage in ipairs(gathering[professionID]) do
                if skill<stage[1] then
                    local nextSkill=math.min(cap,stage[1])
                    row(("%d–%d | %s"):format(skill,nextSkill,stage[2]))
                    skill=nextSkill
                    break
                end
            end
        else
            local best,bestPriority,bestColor,bestPrice,bestQuantity
            for _,candidate in ipairs(options) do
                local recipe=candidate.recipe
                if recipe[3]<=skill and skill<recipe[5] then
                    local priority,color=recipePriority(candidate,skill)
                    local price=(candidate.price or math.huge)/recipe[6]
                    local quantity=candidate.quantity/recipe[6]
                    if not best or priority<bestPriority or priority==bestPriority and
                        (price<bestPrice or price==bestPrice and quantity<bestQuantity) then
                        best,bestPriority,bestColor,bestPrice,bestQuantity=recipe,priority,color,price,quantity
                    end
                end
            end
            if not segment or segment.recipe~=best or segment.color~=bestColor then
                finishSegment()
                segment={recipe=best,color=bestColor,first=skill,crafts=0}
            end
            local points=best and math.min(best[6],best[5]-skill) or 1
            skill=math.min(skill+points,cap)
            segment.last=skill; segment.crafts=segment.crafts+1
        end
    end
    finishSegment()
    table.sort(itemIDs)
    for _,id in ipairs(itemIDs) do plan.materials[#plan.materials+1]={id=id,required=ingredients[id]} end
    return plan
end

function P:ShowLevelRoute(profession,text)
    if not profession then self.status="Choose a profession first."; return end
    local first,last=text:match("^%s*(%d+)%s+(%d+)%s*$")
    if not first then first,last=1,text:match("^%s*(%d+)%s*$") end
    if text:match("^%s*$") then first,last=1,300 end
    first,last=tonumber(first),tonumber(last)
    if not first or not last or first<1 or last<=first or last>300 then
        self.status="Enter a target skill or a range such as 40 300."
        return
    end
    local route=self:BuildProfessionRoute(profession,first,last)
    if not route then self.status="ForeverSuite Profession Data could not load."; return end
    self.levelRoute=route
    self.selected=nil; self.page=1
    if self.window then self.window.search:SetText("") end
    self:Refresh()
end

function P:BuildLevelRoutes()
    local catalog=self:LoadProfessionCatalog()
    if not catalog then
        self.status="Enable ForeverSuite Profession Data in your AddOns list to use level routes."
        return
    end
    local route=self.levelRoute
    if route then
        self.rows=route.rows
        local profession=catalog.professions[route.profession]
        self.status=("%s %d–%d. Enter a new range, or use Back to choose another profession."):format(profession.name,route.first,route.last)
        if profession.gathering then return end
        self.status=self.status.." Shopping uses the minimum direct reagents."
        if route.unverified then self.status=self.status.." Verify estimated recipe sources." end
        if route.gaps then self.status=self.status.." Some skill ranges need another recipe." end
        return
    end
    for id,profession in pairs(catalog.professions) do
        self.rows[#self.rows+1]={id=id,profession=id,text=profession.name..(profession.gathering and " | Gathering" or " | Crafting")}
    end
    table.sort(self.rows,function(a,b) return a.text<b.text end)
    self.status="Choose a profession for a 1–300 plan. Use Plan range to start from your current skill."
end
