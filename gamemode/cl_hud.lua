AddCSLuaFile()

if(SERVER) then return end

function GM:HUDPaint()
    surface.SetDrawColor(255, 0, 0, 255)
    surface.DrawRect(0 , ScrH()-50, ScrW(), 50)
end
