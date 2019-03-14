local state = require 'state'


local enet = require 'enet' -- Network
local marshal = require 'marshal' -- Serialization
local serpent = require 'https://raw.githubusercontent.com/pkulchenko/serpent/522a6239f25997b101c585c0daf6a15b7e37fad9/src/serpent.lua'


local MAX_MAX_CLIENTS = 64


local server = {}
do
    server.enabled = false
    server.started = false
    server.maxClients = MAX_MAX_CLIENTS
    server.isAcceptingClients = true

    local share = state.new()
    share:__autoSync(true)
    server.share = share
    local homes = {}
    server.homes = homes

    local host
    local peerToId = {}
    local idToPeer = {}
    local nextId = 1
    local numClients = 0

    function server.useCastleConfig()
        if castle then
            function castle.startServer(port)
                server.enabled = true
                server.start(port)
            end
        end
    end

    local useCompression = true
    function server.disableCompression()
        useCompression = false
    end

    function server.start(port)
        host = enet.host_create('*:' .. tostring(port or '22122'), MAX_MAX_CLIENTS)
        if host == nil then
            error("couldn't start server -- is port in use?")
        end
        if useCompression then
            host:compress_with_range_coder()
        end
        server.started = true
    end

    function server.send(id, ...)
        local data = marshal.encode({ message = { nArgs = select('#', ...), ... } })
        if id == 'all' then
            host:broadcast(data)
        else
            assert(idToPeer[id], 'no connected client with this `id`'):send(data)
        end
    end

    function server.kick(id)
        assert(idToPeer[id], 'no connected client with this `id`'):disconnect()
    end

    function server.getPing(id)
        return assert(idToPeer[id], 'no connected client with this `id`'):round_trip_time()
    end

    function server.preupdate()
        -- Process network events
        if host then
            while true do
                local event = host:service(0)
                if not event then break end

                -- Someone connected?
                if event.type == 'connect' then
                    if numClients < server.maxClients then
                        local id = nextId
                        nextId = nextId + 1
                        peerToId[event.peer] = id
                        idToPeer[id] = event.peer
                        homes[id] = {}
                        numClients = numClients + 1
                        if CASTLE_SERVER then
                            castle.setIsAcceptingClients(server.isAcceptingClients and
                                    numClients < server.maxClients)
                        end
                        if server.connect then
                            server.connect(id)
                        end
                        event.peer:send(marshal.encode({
                            id = id,
                            exact = share:__diff(id, true),
                        }))
                    else
                        event.peer:send(marshal.encode({ full = true }))
                        event.peer:disconnect_later()
                    end
                end

                -- Someone disconnected?
                if event.type == 'disconnect' then
                    local id = peerToId[event.peer]
                    if id then
                        if server.disconnect then
                            server.disconnect(id)
                        end
                        homes[id] = nil
                        idToPeer[id] = nil
                        peerToId[event.peer] = nil
                        numClients = numClients - 1
                        if CASTLE_SERVER then
                            castle.setIsAcceptingClients(server.isAcceptingClients and
                                    numClients < server.maxClients)
                        end
                    end
                end

                -- Received a request?
                if event.type == 'receive' then
                    local id = peerToId[event.peer]
                    if id then
                        local request = marshal.decode(event.data)

                        -- Message?
                        if request.message and server.receive then
                            server.receive(id, unpack(request.message, 1, request.message.nArgs))
                        end

                        -- Diff / exact?
                        if request.diff then
                            if server.changing then
                                server.changing(id, request.diff)
                            end
                            assert(state.apply(homes[id], request.diff) == homes[id])
                            if server.changed then
                                server.changed(id, request.diff)
                            end
                        end
                        if request.exact then -- `state.apply` may return a new value
                            if server.changing then
                                server.changing(id, request.exact)
                            end
                            local home = homes[id]
                            local new = state.apply(home, request.exact)
                            for k, v in pairs(new) do
                                home[k] = v
                            end
                            for k in pairs(home) do
                                if not new[k] then
                                    home[k] = nil
                                end
                            end
                            if server.changed then
                                server.changed(id, request.exact)
                            end
                        end
                    end
                end
            end
        end
    end

    function server.postupdate()
        -- Send state updates to everyone
        for peer, id in pairs(peerToId) do
            local diff = share:__diff(id)
            if diff ~= nil then -- `nil` if nothing changed
                peer:send(marshal.encode({ diff = diff }))
            end
        end
        share:__flush() -- Make sure to reset diff state after sending!

        if host then
            host:flush() -- Tell ENet to send outgoing messages
        end

        if CASTLE_SERVER then -- On dedicated servers we need to periodically say we're alive
            castle.heartbeat(numClients)
        end
    end
end


local client = {}
do
    client.enabled = false
    client.connected = false
    client.id = nil

    local share = {}
    client.share = share
    local home = state.new()
    home:__autoSync(true)
    client.home = home

    local host
    local peer

    function client.useCastleConfig()
        if castle then
            function castle.startClient(address)
                client.enabled = true
                client.start(address)
            end
        end
    end

    local useCompression = true
    function client.disableCompression()
        useCompression = false
    end

    function client.start(address)
        host = enet.host_create()
        if useCompression then
            host:compress_with_range_coder()
        end
        host:connect(address or '127.0.0.1:22122')
    end

    function client.send(...)
        assert(peer, 'client is not connected'):send(marshal.encode({
            message = { nArgs = select('#', ...), ... },
        }))
    end

    function client.kick()
        assert(peer, 'client is not connected'):disconnect()
        host:flush()
    end

    function client.getPing()
        return assert(peer, 'client is not connected'):round_trip_time()
    end

    function client.preupdate(dt)
        -- Process network events
        if host then
            while true do
                if not host then break end
                local event = host:service(0)
                if not event then break end

                -- Server connected?
                if event.type == 'connect' then
                    -- Ignore this, wait till we receive id (see below)
                end

                -- Server disconnected?
                if event.type == 'disconnect' then
                    if client.disconnect then
                        client.disconnect()
                    end
                    client.connected = false
                    client.id = nil
                    for k in pairs(share) do
                        share[k] = nil
                    end
                    for k in pairs(home) do
                        home[k] = nil
                    end
                    host = nil
                    peer = nil
                end

                -- Received a request?
                if event.type == 'receive' then
                    local request = marshal.decode(event.data)

                    -- Message?
                    if request.message then
                        if client.receive then
                            client.receive(unpack(request.message, 1, request.message.nArgs))
                        end
                    end

                    -- Diff / exact? (do this first so we have it in `.connect` below)
                    if request.diff then
                        if client.changing then
                            client.changing(request.diff)
                        end
                        assert(state.apply(share, request.diff) == share)
                        if client.changed then
                            client.changed(request.diff)
                        end
                    end
                    if request.exact then -- `state.apply` may return a new value
                        if client.changing then
                            client.changing(request.exact)
                        end
                        local new = state.apply(share, request.exact)
                        for k, v in pairs(new) do
                            share[k] = v
                        end
                        for k in pairs(share) do
                            if not new[k] then
                                share[k] = nil
                            end
                        end
                        if client.changed then
                            client.changed(request.exact)
                        end
                    end

                    -- Id?
                    if request.id then
                        peer = event.peer
                        client.connected = true
                        client.id = request.id
                        if client.connect then
                            client.connect()
                        end
                        peer:send(marshal.encode({ exact = home:__diff(0, true) }))
                    end

                    -- Full?
                    if request.full then
                        if client.full then
                            client.full()
                        end
                        if castle and castle.connectionFailed then
                            castle.connectionFailed('full')
                        end
                    end
                end
            end
        end
    end

    function client.postupdate(dt)
        -- Send state updates to server
        if peer then
            local diff = home:__diff(0)
            if diff ~= nil then -- `nil` if nothing changed
                peer:send(marshal.encode({ diff = diff }))
            end
        end
        home:__flush() -- Make sure to reset diff state after sending!

        if host then
            host:flush() -- Tell ENet to send outgoing messages
        end
    end
end


local loveCbs = {
    load = { server = true, client = true },
    lowmemory = { server = true, client = true },
    quit = { server = true, client = true },
    threaderror = { server = true, client = true },
    update = { server = true, client = true },
    directorydropped = { client = true },
    draw = { client = true },
    --    errhand = { client = true },
    --    errorhandler = { client = true },
    filedropped = { client = true },
    focus = { client = true },
    keypressed = { client = true },
    keyreleased = { client = true },
    mousefocus = { client = true },
    mousemoved = { client = true },
    mousepressed = { client = true },
    mousereleased = { client = true },
    resize = { client = true },
    --    run = { client = true },
    textedited = { client = true },
    textinput = { client = true },
    touchmoved = { client = true },
    touchpressed = { client = true },
    touchreleased = { client = true },
    visible = { client = true },
    wheelmoved = { client = true },
    gamepadaxis = { client = true },
    gamepadpressed = { client = true },
    gamepadreleased = { client = true },
    joystickadded = { client = true },
    joystickaxis = { client = true },
    joystickhat = { client = true },
    joystickpressed = { client = true },
    joystickreleased = { client = true },
    joystickremoved = { client = true },
}

local firing = 1

for cbName, where in pairs(loveCbs) do
    love[cbName] = function(...)
        if where.server and server.enabled then
            if (firing == 1) and cbName == 'update' then
                server.preupdate(...)
            end
            local serverCb = server[cbName]
            if serverCb then
                serverCb(...)
            end
            if (firing == 1) and cbName == 'update' then
                server.postupdate(...)
            end
        end
        if where.client and client.enabled then
            if (firing == 1) and cbName == 'update' then
                client.preupdate(...)
            end
            local clientCb = client[cbName]
            if clientCb then
                clientCb(...)
            end
            if (firing == 1) and cbName == 'update' then
                client.postupdate(...)
            end
            if cbName == 'quit' and client.connected then
                client.kick()
            end
        end
        -- if cbName == 'update' then
        --     firing = (firing + 1) % 2
        -- end
    end
end

function castle.backgroundupdate(...)
    if server.enabled then
        server.preupdate(...)
        if server.backgroundupdate then
            server.backgroundupdate(...)
        end
        server.postupdate(...)
    end
    if client.enabled then
        client.preupdate(...)
        if client.backgroundupdate then
            client.backgroundupdate(...)
        end
        client.postupdate(...)
    end
end

return {
    server = server,
    client = client,
    DIFF_NIL = state.DIFF_NIL,
}
