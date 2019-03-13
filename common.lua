cs = require 'https://raw.githubusercontent.com/castle-games/share.lua/937295335d122a85f12b03a6880d76b711a81c09/cs.lua'


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