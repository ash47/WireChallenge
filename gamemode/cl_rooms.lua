AddCSLuaFile()

if(SERVER) then return end

-- Store info on the current room
myRoom = myRoom or {
    ["running"] = false
}

net.Receive("roomRunning", function(len)
    -- Read running state
    myRoom.running = net.ReadBit() == 1
end)
