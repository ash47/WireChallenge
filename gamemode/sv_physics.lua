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

local oldAdd = oldAdd or cleanup.Add
function cleanup.Add(ply, Type, ent)
    local phys = ent:GetPhysicsObject()

    if phys and phys:IsValid() then
        phys:EnableMotion( false )
    end

    return oldAdd(ply, Type, ent)
end

function GM:PhysgunDrop(ply, ent)
    local phys = ent:GetPhysicsObject()

    if phys and phys:IsValid() then
        phys:EnableMotion( false )
    end
end

function GM:OnPhysgunReload(ply, ent)
end
