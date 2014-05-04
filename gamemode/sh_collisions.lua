AddCSLuaFile()

--[[hook.Add("ShouldCollide", "StopPlayerCollisions", function(ent1, ent2)
    -- Players collide with nothing
    if ent1:IsPlayer() or ent2:IsPlayer() then
        return false
    end
end )]]
