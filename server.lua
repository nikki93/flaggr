require 'common'


--- SERVER

local server = cs.server

if USE_CASTLE_CONFIG then
    server.useCastleConfig()
else
    server.enabled = true
    server.start('22122')
end

local share = server.share
local homes = server.homes


--- LOAD

function server.load()
    do -- Players
        share.players = {}
    end
end


--- CONNECT

function server.connect(clientId)
    do -- New player
        share.players[clientId] = {}
        local player = share.players[clientId]

        player.y = H - G
        player.x = (W - G) * math.random()
    end
end


--- DISCONNECT

function server.disconnect(clientId)
    print('client ' .. id .. ' disconnected')
end


--- UPDATE

function server.update(dt)
end
