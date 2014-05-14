--[[function GM:OnEntityCreated( ent )
    local phys = ent:GetPhysicsObject()

    ent.Initialize = function()
        print( "asd" )
    end

    print("Called")
    print( phys )

    if phys and phys:IsValid() then
        print("Done!")
        phys:EnableMotion( false )
    end
end]]

-- Freezes an entity, and all attached entities
function freezeEntity(ent)
    local phys = ent:GetPhysicsObject()

    if phys and phys:IsValid() then
        phys:EnableMotion( false )
    end
end

function GM:PhysgunPickup(ply, ent)
    -- Make sure the player is in a room
    local plyRoom = ply:GetRoom()
    if not plyRoom then return false end

    -- Make sure the ent is in a room
    local entRoom = ent:GetRoom()
    if not ent:GetRoom() then return false end

    -- Make sure they are in the same room
    if plyRoom != entRoom then return false end

    -- Make sure the game isn't running
    if plyRoom.running then return false end

    -- Allowed to pickup
    return true
end

function GM:PhysgunDrop(ply, ent)
    freezeEntity(ent)
end

function GM:OnPhysgunReload(ply, ent)
end

--[[
    Extend entity class to add useful stuff
]]

local Entity = FindMetaTable("Entity")

-- Spawn the filter
local filterName = 'WireChallengeDamageFilter'
hook.Add('InitPostEntity', 'CreateDamagefilter', function()
    -- Create the damage filter
    local filter = ents.Create('filter_activator_name')
    filter:SetKeyValue('targetname', filterName)
    filter:SetKeyValue('negated', '1')
    filter:Spawn()
end)

-- Stops an entity from taking damage
function Entity:disableDamage()
    self:Fire('setdamagefilter', filterName, 0)
end

-- Allows an entity to take damage
function Entity:enableDamage()
    self:Fire('setdamagefilter', '', 0)
end