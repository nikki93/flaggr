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
end


--- CONNECT

function server.connect(clientId)
    do -- New player
        share.players[clientId] = {}
        local player = share.players[clientId]
        resetPlayer(player)
    end
end


--- DISCONNECT

function server.disconnect(clientId)
    do -- Remove player
        share.players[clientId] = nil
    end
end


--- UPDATE

function server.update(dt)
    do -- Time
        share.time = love.timer.getTime()
    end

    do -- Players
        for clientId, player in pairs(share.players) do
            do -- Walk
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
                playerApplyWalk(player, dt)
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
            for carId, car in pairs(share.cars) do
                local carX = car.startX + (share.time - car.startTime) * car.xSpeed
                if player.x <= carX + car.length and player.x + G >= carX and
                    player.y + PLAYER_COL_Y_EPS < car.y + G and player.y + G > car.y + PLAYER_COL_Y_EPS then
                    player.died = true
                end
            end
        end
    end

    do -- Log overlap
        for clientId, player in pairs(share.players) do
            local moved = false
            player.onLog = false
            for logId, log in pairs(share.logs) do
                local logX = log.startX + (share.time - log.startTime) * log.xSpeed
                if player.x <= logX + log.length and player.x + G >= logX and
                    player.y + PLAYER_COL_Y_EPS < log.y + G and player.y + G > log.y + PLAYER_COL_Y_EPS then
                    player.onLog = true
                    if not moved and math.abs(player.y - log.y) < 0.5 then
                        player.x = player.x + log.xSpeed * dt
                        player.x = math.max(0, math.min(player.x, W - G))
                        moved = true
                    end
                end
            end
        end
    end

    do -- Water drown
        for clientId, player in pairs(share.players) do
            for waterId, water in pairs(share.waters) do
                if not player.onLog and player.y + PLAYER_COL_Y_EPS < water.maxY and player.y + G > water.minY + PLAYER_COL_Y_EPS then
                    player.died = true
                end
            end
        end
    end

    do -- Death
        for clientId, player in pairs(share.players) do
            if player.died then
                resetPlayer(player)
            end
        end
    end
end
