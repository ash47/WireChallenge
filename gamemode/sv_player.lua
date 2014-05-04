function GM:PlayerInitialSpawn(ply)
end

function GM:PlayerSpawn(ply)
    self.BaseClass:PlayerSpawn(ply)

    -- Enable God Mode
    ply:GodEnable()

    --ply:SetCustomCollisionCheck(true)
end

