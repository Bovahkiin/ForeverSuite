local _, FS = ...

FS.menuAtlas = "Interface\\AddOns\\ForeverSuite\\Assets\\Menu\\FantasyAtlas.tga"
local CELL, COLUMNS, ATLAS_SIZE = 36, 27, 1024
local names = {
    "Character", "Professions", "Spells", "Talents", "Achievements", "Quests",
    "Guild", "Social", "Groups", "PVP", "Collections", "Guide", "Map", "Store",
    "Menu", "Help", "Legacy", "Housing", "Reputation", "Skills", "Currency",
    "Statistics", "Enemy", "Equipment", "Friendly", "Bags", "Vendor", "Gear",
    "UnitFrames", "ActionBars", "Nameplates", "Loot", "Buffs", "Cooldowns",
    "Combat", "AuctionHouse", "Chat", "QoL", "Bank", "Bindings", "Mail",
    "MinimapButtons", "GearAdvisor", "Pet",
    "Grid", "Star", "Potion", "Ammo", "Gem", "Junk", "Stock", "Keys", "Mounts", "Category",
}
local columns = {}
for index, name in ipairs(names) do
    columns[name] = index - 1
end
columns.TalentAdvisor=columns.Talents

-- Only ForeverSuite's decorative regions are registered here.
local icons = setmetatable({}, { __mode = "k" })

local function paint(texture, state, theme)
    if state.paintedTheme == theme then return end
    local x = state.index % COLUMNS * CELL
    local y = (theme * 2 + math.floor(state.index / COLUMNS)) * CELL
    texture:SetTexCoord(
        (x + .5) / ATLAS_SIZE, (x + CELL - .5) / ATLAS_SIZE,
        (y + .5) / ATLAS_SIZE, (y + CELL - .5) / ATLAS_SIZE
    )
    state.paintedTheme = theme
end

function FS:SetMenuIcon(texture, name, previewTheme)
    local index = columns[name] or columns.Menu
    local state = icons[texture]
    if not state then
        state = {}
        icons[texture] = state
        texture:SetTexture(FS.menuAtlas)
    end
    if state.index ~= index then
        state.index = index
        state.paintedTheme = nil
    end
    state.preview = previewTheme
    paint(texture, state, previewTheme or self.Themes:Current() or 0)
end

function FS:ClearMenuIcon(texture)
    if not icons[texture] then return end
    icons[texture] = nil
    texture:SetTexCoord(0, 1, 0, 1)
end

function FS:RefreshMenuIcons(theme)
    for texture, state in pairs(icons) do
        if not state.preview then
            paint(texture, state, theme or 0)
        end
    end
end
