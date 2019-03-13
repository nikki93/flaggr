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

        player.yDir = 'none' -- 'up', 'down' or 'none' depending on current Y stepping direction
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
                    do -- X
                        local vx = 0
                        if walk.left then
                            vx = vx - PLAYER_X_SPEED
                        end
                        if walk.right then
                            vx = vx + PLAYER_X_SPEED
                        end
                        player.x = player.x + vx * dt
                        player.x = math.max(0, math.min(player.x, W - G))
                    end

                    do -- Y
                        if player.yDir == 'none' and walk.up and (not walk.down) then
                            player.yDir = 'up'
                        end
                        if player.yDir == 'none' and walk.down and (not walk.up) then
                            player.yDir = 'down'
                        end

                        if player.yDir ~= 'none' then -- Y stepping
                            if player.yDir == 'up' then
                                local prevStep = math.floor(player.y / G + 0.9999) -- Which grid step were we at?
                                player.y = player.y - PLAYER_Y_SPEED * dt
                                local nextStep = math.floor(player.y / G + 0.9999) -- Which grid step did we get to?
                                if nextStep ~= prevStep then -- Jumped a step, we're done
                                    player.yDir = PLAYER_KEY_DELAY
                                    player.y = (nextStep) * G
                                end
                                player.y = math.max(0, math.min(player.y, H - G))
                                if player.y == 0 or player.y == H - G then
                                    player.yDir = PLAYER_KEY_DELAY
                                end
                            end
                            if player.yDir == 'down' then
                                local prevStep = math.floor(player.y / G + 0.1) -- Which grid step were we at?
                                player.y = player.y + PLAYER_Y_SPEED * dt
                                local nextStep = math.floor(player.y / G + 0.1) -- Which grid step did we get to?
                                if nextStep ~= prevStep or nextStep >= H / G then -- Jumped a step, we're done
                                    player.yDir = PLAYER_KEY_DELAY
                                    player.y = (nextStep) * G
                                end
                                player.y = math.max(0, math.min(player.y, H - G))
                                if player.y == 0 or player.y == H - G then
                                    player.yDir = PLAYER_KEY_DELAY
                                end
                            end

                            if type(player.yDir) == 'number' then
                                player.yDir = player.yDir - dt
                                if player.yDir <= 0 then
                                    player.yDir = 'none'
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
