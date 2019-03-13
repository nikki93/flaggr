cs = require 'https://raw.githubusercontent.com/castle-games/share.lua/937295335d122a85f12b03a6880d76b711a81c09/cs.lua'


--- CONSTANTS

W, H = 560, 840 -- Game width, game height
G = 28 -- Grid size

PLAYER_X_SPEED = 200
PLAYER_Y_SPEED = 200

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