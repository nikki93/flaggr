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
    do -- Players
        for clientId, player in pairs(share.players) do
            do -- Walk
                local walk = homes[clientId].walk
                if walk then
                    local vx, vy = 0, 0
                    if walk.left then
                        vx = vx - WALK_SPEED
                    end
                    if walk.right then
                        vx = vx + WALK_SPEED
                    end
                    if walk.up then
                        vy = vy - WALK_SPEED
                    end
                    if walk.down then
                        vy = vy + WALK_SPEED
                    end
                    player.x, player.y = player.x + vx * dt, player.y + vy * dt
                    player.x = math.max(0, math.min(player.x, W - G))
                    player.y = math.max(0, math.min(player.y, H - G))
                end
            end
        end
    end
end
