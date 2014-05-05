function GM:PlayerInitialSpawn(ply)
    -- Allocate this player a room
    local room = Rooms:New()
    room:AddPlayer(ply)
end

function GM:PlayerSpawn(ply)
    self.BaseClass:PlayerSpawn(ply)

    -- Enable God Mode
    ply:GodEnable()

    --ply:SetCustomCollisionCheck(true)
end

function GM:ShowSpare2(ply)
    -- Grab the player's room
    local room = ply:GetRoom()
    if room then
        if room.running then
            room:Stop()
        else
            room:Start()
        end
    end
end
