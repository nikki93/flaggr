cs = require 'cs'


--- CONSTANTS

W, H = 560, 560 -- Game width, game height
G = 28 -- Grid size

PLAYER_X_SPEED = 250
PLAYER_Y_SPEED = 320
PLAYER_KEY_DELAY = 0.04
PLAYER_COL_Y_EPS = 0.01
PLAYER_DEATH_RESET_TIME = 1

BOMB_RADIUS = 2.5 * G
BOMB_DRAW_TIME = 0.2

FLAG_UNCARRIED_SIZE = G
FLAG_CARRIED_SIZE = 0.4 * G
FLAG_DROP_RESET_TIME = 10

CAR_SPAWNS = {
    -- Bottom cars
    {
        y = 18 * G,
        xSpeed = 180,
        dir = 'right',
        timerMin = 0.8,
        timerMax = 2,
        length = 2 * G,
    },
    {
        y = 17 * G,
        xSpeed = 180,
        dir = 'left',
        timerMin = 0.8,
        timerMax = 2,
        length = 3 * G,
    },
    {
        y = 16 * G,
        xSpeed = 400,
        dir = 'right',
        timerMin = 0.8,
        timerMax = 2,
        length = 2 * G,
    },

    -- Trains
    {
        y = 14 * G,
        xSpeed = 800,
        dir = 'right',
        timerMin = 5,
        timerMax = 8,
        length = 20 * G,
    },
    {
        y = 13 * G,
        xSpeed = 800,
        dir = 'left',
        timerMin = 5,
        timerMax = 8,
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
        xSpeed = 180,
        dir = 'right',
        timerMin = 0.8,
        timerMax = 2,
        length = 2 * G,
    },
    {
        y = 11 * G,
        xSpeed = 180,
        dir = 'left',
        timerMin = 0.8,
        timerMax = 2,
        length = 2 * G,
    },
    {
        y = 10 * G,
        xSpeed = 250,
        dir = 'right',
        timerMin = 0.8,
        timerMax = 2,
        length = 2.7 * G,
    },
    {
        y = 9 * G,
        xSpeed = 250,
        dir = 'left',
        timerMin = 0.2,
        timerMax = 0.8,
        length = 1.6 * G,
    },
}

DEBUG = true


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

function playerApplyWalk(player, dt)
    if player.died then
        return
    end

    walk = player.walk
    if not walk then
        return
    end

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
