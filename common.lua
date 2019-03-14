cs = require 'cs'


--- CONSTANTS

W, H = 560, 840 -- Game width, game height
G = 28 -- Grid size

PLAYER_X_SPEED = 250
PLAYER_Y_SPEED = 320
PLAYER_KEY_DELAY = 0.04
PLAYER_COL_Y_EPS = 0.01

CAR_SPAWNS = {
    {
        y = 26 * G,
        xSpeed = 180,
        dir = 'right',
        timerMin = 0.8,
        timerMax = 2,
        length = 2 * G,
    },
    {
        y = 25 * G,
        xSpeed = 180,
        dir = 'left',
        timerMin = 0.8,
        timerMax = 2,
        length = 2 * G,
    }
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


--- LOGIC

function playerApplyWalk(player, dt)
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
