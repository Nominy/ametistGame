local enet = require "enet"
local serpent = require "serpent"
local NetworkManager = {isConnected=false, isHost=false, host=nil, client=nil}
function NetworkManager:connect(mode, address)
    if mode=="host" then
        self.host = enet.host_create("*:6789")
        self.isHost = true
        self.isConnected = true
        print("Hosting on port 6789")
    elseif mode=="client" then
        self.client = enet.host_create()
        self.host = self.client:connect(address..":6789")
        self.isHost = false
        self.isConnected = true
        print("Connecting to server at "..address)
    end
end
function NetworkManager:_getReceiver()
    return self.isHost and self.host or self.client
end
function NetworkManager:send(data)
    if not self.isConnected then return end
    local s = serpent.dump(data)
    if self.isHost then
        self.host:broadcast(s)
    else
        self.host:send(s)
    end
end
function NetworkManager:receive()
    if not self.isConnected then return end
    local e = self:_getReceiver():service(0)
    if e and e.type=="receive" then
        local ok, d = serpent.load(e.data)
        if ok then return d end
    end
end
return NetworkManager
