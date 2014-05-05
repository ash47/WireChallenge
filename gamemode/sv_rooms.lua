print("\n\nLoading rooms!\n\n")

--[[
    Rooms Class
]]
Rooms = Rooms or {}

function Rooms:New()
    local r = {
        ["players"] = {},
        ["running"] = false,
        ["ents"] = {}
    }
    setmetatable(r, {__index = Rooms})
    return r
end

-- Adds a player to a room
function Rooms:AddPlayer(ply)
    -- Check if the player is already in a room
    local oldRoom = ply:GetRoom()
    if oldRoom then
        -- Remove them from that room
        oldRoom:RemovePlayer(ply)
    end

    -- Add them to this room
    table.insert(self.players, ply)

    -- Store this room as their room on the player
    ply:SetRoom(self)

    -- Send them the room's running state
    net.Start("roomRunning")
    net.WriteBit(self.running)
    net.Send(ply)
end

-- Removes a player from a room
function Rooms:RemovePlayer(ply)
    for k,v in pairs(self.players) do
        if ply == v then
            table.remove(self.players, k)
            return true
        end
    end

    return false
end

-- Adds an entity to a room
function Rooms:AddEnt(ent)
    -- Check if the player is already in a room
    local oldRoom = ent:GetRoom()
    if oldRoom then
        -- Remove them from that room
        oldRoom:RemoveEnt(ent)
    end

    -- Add them to this room
    table.insert(self.ents, ent)

    -- Store this room as their room on the player
    ent:SetRoom(self)
end

-- Removes an entity from a room
function Rooms:RemoveEnt(ent)
    for k,v in pairs(self.ents) do
        if ent == v then
            table.remove(self.ents, k)
            return true
        end
    end

    return false
end

-- Gets a save of the current room
function Rooms:GetSave()
    -- Create new save
    local save = {}

    -- Copy all ents
    for k,v in pairs(self.ents) do
        if v:IsValid() then
            -- Get key info
            local ent = {
                ["class"] = v:GetClass(),
                ["pos"] = v:GetPos(),
                ["angles"] = v:GetAngles(),
                ["model"] = v:GetModel()
            }

            -- Store ent
            table.insert(save, ent)
        end
    end

    -- Return the save
    return save
end

-- Removes all ents in a room
function Rooms:Cleanup()
    for k,v in pairs(self.ents) do
        if v:IsValid() then
            v:Remove()
        end
    end

    self.ents = {}
end

-- Starts simulating a room
function Rooms:Start()
    -- Create a save of this room
    self.save = self:GetSave()

    -- Clean the room up
    self:Cleanup()

    -- Enable running
    self:SetRunning(true)

    -- Load the room
    self:LoadRoom(self.save)
end

-- Stops simulating a room
function Rooms:Stop()
    -- Cleanup the room
    self:Cleanup()

    -- Stop running
    self:SetRunning(false)

    -- Load the room
    self:LoadRoom(self.save)
end

function Rooms:SetRunning(state)
    -- Check if it even changed
    if self.running ~= state then
        -- Store change
        self.running = state

        -- Start net message
        net.Start("roomRunning")
        net.WriteBit(state)

        -- Update players
        for k,v in pairs(self.players) do
            if v:IsValid() then
                -- Send to this player
                net.Send(v)
            end
        end
    end
end

-- Loads a room
function Rooms:LoadRoom(save)
    for k,v in pairs(save) do
        -- Create the entity
        local ent = ents.Create(v.class)
        ent:SetPos(v.pos)
        ent:SetAngles(v.angles)
        ent:SetModel(v.model)
        ent:Spawn()

        -- Add entity to this room
        self:AddEnt(ent)

        -- Freeze the ent if we're not running
        if not self.running then
            freezeEntity(ent)
        end
    end
end

-- Hook entity creation
local oldAdd = oldAdd or cleanup.Add
function cleanup.Add(ply, Type, ent)
    -- Make sure the player is in a room
    local room = ply:GetRoom()
    if not room then
        ent:Remove()
        return false
    end

    -- Check if the room is running
    if room.running then
        ent:Remove()
        return false
    end

    -- Validate what they are creating

    -- Add it to this room
    room:AddEnt(ent)

    -- Freeze it
    freezeEntity(ent)

    -- Add it to the list of deletables
    return oldAdd(ply, Type, ent)
end

--[[
    Extend entity class to interact with rooms
]]
local Entity = FindMetaTable("Entity")

function Entity:GetRoom()
    return self.wc_room
end

function Entity:SetRoom(room)
    self.wc_room = room
end

print("Done loading rooms!")
