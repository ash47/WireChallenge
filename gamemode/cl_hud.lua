AddCSLuaFile()

if(SERVER) then return end

-- Hud sizing
local hudMargin = 4                     -- Margin around the edge of the hud
local hudWidth = 384                    -- Width of the hud
local hudHeight = 216                   -- Height of the hud
local hudCornerRadius = 4               -- Radius of the corner
local hudOutlineWidth = 1               -- Width of the outline on the hud
local hudOutlineColor = Color(0, 0, 0)  -- Color of the outline
local hudBGOffColor = Color(255, 0, 0)  -- Color of the BG when not running

function GM:HUDPaint()
    draw.RoundedBox(hudCornerRadius, hudMargin, ScrH()-hudHeight-hudMargin, hudWidth, hudHeight, hudOutlineColor)
    draw.RoundedBox(hudCornerRadius, hudMargin+hudOutlineWidth, ScrH()-hudHeight-hudMargin+hudOutlineWidth, hudWidth-hudOutlineWidth*2, hudHeight-hudOutlineWidth*2, hudBGOffColor)
end

-- Hide HL2 hud elements
local toHide = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true
}
function GM:HUDShouldDraw(name)
    if toHide[name] then
        return false
    end

    return true
end
