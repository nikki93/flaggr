cs = require 'https://raw.githubusercontent.com/castle-games/share.lua/bitser/cs.lua'


--- CONSTANTS

W, H = 560, 560 -- Game width, game height
G = 28 -- Grid size

EASINESS = 0.92

PLAYER_X_SPEED = 250
PLAYER_Y_SPEED = 365
PLAYER_KEY_DELAY = 0.09
PLAYER_COL_X_EPS = 0.2 * G
PLAYER_COL_Y_EPS = 0.2 * G
PLAYER_DEATH_RESET_TIME = 1

BOMB_RADIUS = 2.5 * G
BOMB_DRAW_TIME = 0.2

FLAG_UNCARRIED_SIZE = G
FLAG_CARRIED_SIZE = 0.4 * G
FLAG_DROP_RESET_TIME = 10

SCORE_FLAGS_PER_GAME = 10

INSTRUCTIONS_SHOW_TIME = 15

SPAWN_BUFFER = 3 * G

CAR_SPAWNS = {
    -- Bottom cars
    {
        y = 18 * G,
        xSpeed = EASINESS * 180,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
        spriteNames = {
            'car1-224x122.png',
            'car1-224x122.png',
            'car2-224x122.png',
            'car3-224x122.png',
        }
    },
    {
        y = 17 * G,
        xSpeed = EASINESS * 180,
        dir = 'left',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 3 * G,
        spriteNames = {
            'car1-336x122.png',
            'car2-336x122.png',
        }
    },
    {
        y = 16 * G,
        xSpeed = EASINESS * 400,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
        spriteNames = {
            'car1-224x122.png',
            'car2-224x122.png',
            'car2-224x122.png',
            'car3-224x122.png',
            'car3-224x122.png',
        }
    },

    -- Trains
    {
        y = 14 * G,
        xSpeed = EASINESS * 800,
        dir = 'right',
        timerMin = (1 / EASINESS) * 5,
        timerMax = (1 / EASINESS) * 8,
        length = 20 * G,
        spriteNames = {
            'car1-2240x122.png',
        }
    },
    {
        y = 13 * G,
        xSpeed = EASINESS * 800,
        dir = 'left',
        timerMin = (1 / EASINESS) * 5,
        timerMax = (1 / EASINESS) * 8,
        length = 20 * G,
        spriteNames = {
            'car1-2240x122.png',
        }
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
        spriteNames = {
            'log1.png',
            'log2.png',
        },
    },
    {
        y = 11 * G,
        xSpeed = EASINESS * 180,
        dir = 'left',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2 * G,
        spriteNames = {
            'log1.png',
            'log2.png',
        },
    },
    {
        y = 10 * G,
        xSpeed = EASINESS * 250,
        dir = 'right',
        timerMin = (1 / EASINESS) * 0.8,
        timerMax = (1 / EASINESS) * 2,
        length = 2.7 * G,
        spriteNames = {
            'log1.png',
            'log2.png',
        },
    },
    {
        y = 9 * G,
        xSpeed = EASINESS * 250,
        dir = 'left',
        timerMin = (1 / EASINESS) * 0.2,
        timerMax = (1 / EASINESS) * 0.8,
        length = 1.6 * G,
        spriteNames = {
            'log1.png',
            'log2.png',
        },
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

function applyLogOverlaps(share, dt)
    for clientId, player in pairs(share.players) do
        if not player.died then
            local minYDiff
            local minYDiffXSpeed
            player.onLog = false
            for logId, log in pairs(share.logs) do
                local logX = log.startX + (share.time - log.startTime) * log.xSpeed
                if player.x + 0.2 * PLAYER_COL_X_EPS <= logX + log.length and player.x + G >= logX + 0.2 * PLAYER_COL_X_EPS and
                    player.y + 0.2 * PLAYER_COL_Y_EPS < log.y + G and player.y + G > log.y + 0.2 * PLAYER_COL_Y_EPS then
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
