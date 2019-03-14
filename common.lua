cs = require 'cs'


--- CONSTANTS

W, H = 560, 560 -- Game width, game height
G = 28 -- Grid size

EASINESS = 0.85

PLAYER_X_SPEED = 250
PLAYER_Y_SPEED = 320
PLAYER_KEY_DELAY = 0.04
PLAYER_COL_X_EPS = 0.1 * G
PLAYER_COL_Y_EPS = 0.1 * G
PLAYER_DEATH_RESET_TIME = 1

BOMB_RADIUS = 2.5 * G
BOMB_DRAW_TIME = 0.2

FLAG_UNCARRIED_SIZE = G
FLAG_CARRIED_SIZE = 0.4 * G
FLAG_DROP_RESET_TIME = 10

SCORE_FLAGS_PER_GAME = 10

INSTRUCTIONS_SHOW_TIME = 15

CAR_SPAWNS = {
    -- Bottom cars
    {
        y = 18 * G,
        xSpeed = EASINESS * 180,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
    },
    {
        y = 17 * G,
        xSpeed = EASINESS * 180,
        dir = 'left',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 3 * G,
    },
    {
        y = 16 * G,
        xSpeed = EASINESS * 400,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
    },

    -- Trains
    {
        y = 14 * G,
        xSpeed = EASINESS * 800,
        dir = 'right',
        timerMin = (1 / EASINESS) * 5,
        timerMax = (1 / EASINESS) * 8,
        length = 20 * G,
    },
    {
        y = 13 * G,
        xSpeed = EASINESS * 800,
        dir = 'left',
        timerMin = (1 / EASINESS) * 5,
        timerMax = (1 / EASINESS) * 8,
        length = 20 * G,
    },
}

WATERS = {
    {
        minY = 9 * G,
        maxY = 13 * G,
    },
}

LOG_SPAWNS = {
    {
        y = 12 * G,
        xSpeed = EASINESS * 180,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
    },
    {
        y = 11 * G,
        xSpeed = EASINESS * 180,
        dir = 'left',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
    },
    {
        y = 10 * G,
        xSpeed = EASINESS * 250,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2.7 * G,
    },
    {
        y = 9 * G,
        xSpeed = EASINESS * 250,
        dir = 'left',
        timerMin = (1 / EASINESS) * 0.2,
        timerMax = (1 / EASINESS) * 0.8,
        length = 1.6 * G,
    },
}

DEBUG = false


--- GRAPHICS UTILS

if love.graphics then
    -- `love.graphics.stacked([arg], func)` calls `func` between `love.graphics.push([arg])` and
    -- `love.graphics.pop()` while being resilient to errors
    function love.graphics.stacked(argOrFunc, funcOrNil)
        love.graphics.push(funcOrNil and argOrFunc)
        local succeeded, err = pcall(funcOrNil or argOrFunc)
        love.graphics.pop()
        if not succeeded then
            error(err, 0)
        end
    end
end


--- COMMON LOGIC

function applyPlayerWalk(share, player, dt)
    if player.died then
        return
    end

    walk = player.walk
    if not walk then
        return
    end

    local oldX, oldY = player.x, player.y

    do -- x
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

    do -- y
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

    do -- vx, vy
        player.vx = (player.x - oldX) / dt
        if player.vx ~= 0 then
            player.xSetTime = share.time
        end
        player.vy = (player.y - oldY) / dt
        if player.vy ~= 0 then
            player.ySetTime = share.time
        end
    end
end

function applyLogOverlaps(share, dt)
    for clientId, player in pairs(share.players) do
        if not player.died then
            local minYDiff
            local minYDiffXSpeed
            player.onLog = false
            for logId, log in pairs(share.logs) do
                local logX = log.startX + (share.time - log.startTime) * log.xSpeed
                if player.x + PLAYER_COL_X_EPS <= logX + log.length and player.x + G >= logX + PLAYER_COL_X_EPS and
                    player.y + PLAYER_COL_Y_EPS < log.y + G and player.y + G > log.y + PLAYER_COL_Y_EPS then
                    player.onLog = true
                    local yDiff = math.abs(player.y - log.y)
                    if not minYDiff or yDiff < minYDiff then
                        minYDiff = yDiff
                        minYDiffXSpeed = log.xSpeed
                    end
                end
            end
            if minYDiffXSpeed then
                player.x = player.x + minYDiffXSpeed * dt
                player.x = math.max(0, math.min(player.x, W - G))
            end
        end
    end
end
