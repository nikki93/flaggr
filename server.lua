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


--- UTIL

local nextId = 1
function genId()
    local id = nextId
    nextId = nextId + 1
    return id
end

function resetPlayer(player)
    player.died = false
    player.y = H - G
    player.x = (W - G) * math.random()
    player.yDir = 'none' -- 'up', 'down' or 'none' depending on current Y stepping direction
    player.onLog = false
    player.deathTime = nil
    player.carrying = false -- Whether carrying flag
    player.vx, player.vy = 0, 0
    player.xSetTime, player.ySetTime = nil, nil
end

function dropFlag()
    share.flag.carrierClientId = nil
    share.flag.dropTime = share.time
    share.flag.x = math.max(0, math.min(share.flag.x, W - FLAG_UNCARRIED_SIZE))
    share.flag.y = math.max(0, math.min(share.flag.y, H - FLAG_UNCARRIED_SIZE))
end

function resetFlag()
    share.flag.x = 0.5 * (W - FLAG_UNCARRIED_SIZE)
    share.flag.y = 0
    share.flag.carrierClientId = nil
    share.flag.dropTime = nil -- `share.time` when flag was droppped, watch to reset
end


--- LOAD

function server.load()
    do -- Time
        share.time = love.timer.getTime()
    end

    do -- Players
        share.players = {}
    end

    do -- Cars
        share.cars = {}
    end

    do -- Waters
        share.waters = WATERS
    end

    do -- Logs
        share.logs = {}
    end

    do -- Bombs
        share.bombs = {}
    end

    do -- Flag
        share.flag = {}
        resetFlag()
    end

    do -- Score
        share.score = {
            flags = {
                A = 0,
                B = 0,
            },
            games = {
                A = 0,
                B = 0,
            },
        }
    end
end


--- CONNECT

function server.connect(clientId)
    do -- New player
        local team
        do -- Pick team
            local nPlayers = { A = 0, B = 0 }
            for clientId, player in pairs(share.players) do
                nPlayers[player.team] = nPlayers[player.team] + 1
            end
            if nPlayers.A > nPlayers.B then
                team = 'B'
            end
            if nPlayers.A < nPlayers.B then
                team = 'A'
            end
            if nPlayers.A == nPlayers.B then
                team = math.random() <= 0.5 and 'A' or 'B'
            end
        end

        share.players[clientId] = {}
        local player = share.players[clientId]
        player.team = team

        resetPlayer(player)
    end
end


--- DISCONNECT

function server.disconnect(clientId)
    do -- Remove player
        local player = share.players[clientId]
        if player.carrying then
            dropFlag()
        end
        share.players[clientId] = nil
    end
end


--- RECEIVE

function server.receive(clientId, msg)
    local player = share.players[clientId]
    do -- Bomb
        if msg == 'bomb' and player and not player.died then
            player.died = true

            local id = genId()
            share.bombs[id] = {}
            local bomb = share.bombs[id]

            bomb.x, bomb.y = player.x + 0.5 * G, player.y + 0.5 * G
            bomb.startTime = share.time

            -- Destroy nearby cars, logs, players
            for carId, car in pairs(share.cars) do
                local carX = car.startX + (share.time - car.startTime) * car.xSpeed
                local x = math.max(carX, math.min(bomb.x, carX + car.length))
                local y = math.max(car.y, math.min(bomb.y, car.y + G))
                local dx, dy = bomb.x - x, bomb.y - y
                if dx * dx + dy * dy < BOMB_RADIUS * BOMB_RADIUS then
                    share.cars[carId] = nil
                end
            end
            for logId, log in pairs(share.logs) do
                local logX = log.startX + (share.time - log.startTime) * log.xSpeed
                local x = math.max(logX, math.min(bomb.x, logX + log.length))
                local y = math.max(log.y, math.min(bomb.y, log.y + G))
                local dx, dy = bomb.x - x, bomb.y - y
                if dx * dx + dy * dy < BOMB_RADIUS * BOMB_RADIUS then
                    share.logs[logId] = nil
                end
            end
            for playerId, player2 in pairs(share.players) do
                if not player2.died then
                    local x = math.max(player2.x, math.min(bomb.x, player2.x + G))
                    local y = math.max(player2.y, math.min(bomb.y, player2.y + G))
                    local dx, dy = bomb.x - x, bomb.y - y
                    if dx * dx + dy * dy < BOMB_RADIUS * BOMB_RADIUS then
                        player2.died = true
                    end
                end
            end
        end
    end
end


--- UPDATE

function server.update(dt)
    do -- Time
        share.time = love.timer.getTime()
    end

    do -- Player walks
        for clientId, player in pairs(share.players) do
            if not player.died then
                local walk = homes[clientId].walk
                player.walk = walk
                if walk then
                    if player.yDir == 'none' and walk.up and (not walk.down) then
                        player.yDir = 'up'
                    end
                    if player.yDir == 'none' and walk.down and (not walk.up) then
                        player.yDir = 'down'
                    end
                end
                applyPlayerWalk(share, player, dt)
            end
        end
    end

    do -- Car spawns
        for i, spawn in ipairs(CAR_SPAWNS) do
            -- Reset timer?
            if not spawn.timer then
                spawn.timer = spawn.timerMin + (spawn.timerMax - spawn.timerMin) * math.random()
            end

            -- Tick the timer!
            spawn.timer = spawn.timer - dt

            -- Timer fired? Spawn a car!
            if spawn.timer <= 0 then
                spawn.timer = nil

                local id = genId()
                share.cars[id] = {}
                local car = share.cars[id]

                car.y = spawn.y
                car.length = spawn.length
                car.startTime = share.time
                if spawn.dir == 'right' then
                    car.startX = -car.length
                    car.xSpeed = spawn.xSpeed
                end
                if spawn.dir == 'left' then
                    car.startX = W
                    car.xSpeed = -spawn.xSpeed
                end
            end
        end
    end

    do -- Log spawns
        for i, spawn in ipairs(LOG_SPAWNS) do
            -- Reset timer?
            if not spawn.timer then
                spawn.timer = spawn.timerMin + (spawn.timerMax - spawn.timerMin) * math.random()
            end

            -- Tick the timer!
            spawn.timer = spawn.timer - dt

            -- Timer fired? Spawn a log!
            if spawn.timer <= 0 then
                spawn.timer = nil

                local id = genId()
                share.logs[id] = {}
                local log = share.logs[id]

                log.y = spawn.y
                log.length = spawn.length
                log.startTime = share.time
                if spawn.dir == 'right' then
                    log.startX = -log.length
                    log.xSpeed = spawn.xSpeed
                end
                if spawn.dir == 'left' then
                    log.startX = W
                    log.xSpeed = -spawn.xSpeed
                end
            end
        end
    end

    do -- Car collisions
        for clientId, player in pairs(share.players) do
            if not player.died then
                for carId, car in pairs(share.cars) do
                    local carX = car.startX + (share.time - car.startTime) * car.xSpeed
                    if player.x + PLAYER_COL_X_EPS <= carX + car.length and player.x + G >= carX + PLAYER_COL_X_EPS and
                        player.y + PLAYER_COL_Y_EPS < car.y + G and player.y + G > car.y + PLAYER_COL_Y_EPS then
                        player.died = true
                    end
                end
            end
        end
    end

    do -- Log overlap
        applyLogOverlaps(share, dt)
    end

    do -- Water drown
        for clientId, player in pairs(share.players) do
            if not player.died then
                for waterId, water in pairs(share.waters) do
                    if not player.onLog and player.y + PLAYER_COL_Y_EPS < water.maxY and player.y + G > water.minY + PLAYER_COL_Y_EPS then
                        player.died = true
                    end
                end
            end
        end
    end

    do -- Death
        for clientId, player in pairs(share.players) do
            if player.died then
                if not player.deathTime then -- New death!
                    player.deathTime = share.time
                    if player.carrying then -- Flag drop
                        player.carrying = false
                        dropFlag()
                    end
                elseif share.time - player.deathTime >= 1 then
                    resetPlayer(player)
                end
            end
        end
    end

    do -- Flag reset
        if not share.flag.carrierClientId and share.flag.dropTime then
            if share.time - share.flag.dropTime >= FLAG_DROP_RESET_TIME then
                resetFlag()
            end
        end
    end

    do -- Flag pickup
        if not share.flag.carrierClientId then
            local flagX, flagY = share.flag.x, share.flag.y
            local minSqDist
            local minDistClientId
            for clientId, player in pairs(share.players) do
                if not player.died then
                    if player.x + PLAYER_COL_X_EPS <= flagX + FLAG_UNCARRIED_SIZE and player.x + G >= flagX + PLAYER_COL_X_EPS and
                        player.y + PLAYER_COL_Y_EPS < flagY + FLAG_UNCARRIED_SIZE and player.y + G > flagY + PLAYER_COL_Y_EPS then
                        local dx, dy = player.x - flagX, player.y - flagY
                        local sqDist = dx * dx + dy * dy
                        if not minSqDist or sqDist < minSqDist then
                            minSqDist = sqDist
                            minDistClientId = clientId
                        end
                    end
                end
            end
            if minSqDist then
                local carrierPlayer = share.players[minDistClientId]
                carrierPlayer.carrying = true
                resetFlag()
                share.flag.carrierClientId = minDistClientId
            end
        end
    end

    do -- Flag carry
        if share.flag.carrierClientId then
            local carrierPlayer = share.players[share.flag.carrierClientId]
            share.flag.x, share.flag.y = carrierPlayer.x, carrierPlayer.y
        end
    end

    do -- Flag scoring
        if share.flag.carrierClientId then
            local carrierPlayer = share.players[share.flag.carrierClientId]
            if carrierPlayer.y + PLAYER_COL_Y_EPS >= H - G then
                share.score.flags[carrierPlayer.team] = share.score.flags[carrierPlayer.team] + 1

                if share.score.flags[carrierPlayer.team] >= SCORE_FLAGS_PER_GAME then
                    share.score.games[carrierPlayer.team] = share.score.games[carrierPlayer.team] + 1
                    share.score.flags.A = 0
                    share.score.flags.B = 0
                end

                resetFlag()
            end
        end
    end
end
