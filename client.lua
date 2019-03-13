require 'common'

--- CLIENT

local client = cs.client

if USE_CASTLE_CONFIG then
    client.useCastleConfig()
else
    client.enabled = true
    client.start('127.0.0.1:22122')
end

local share = client.share
local home = client.home

--- DRAW

function client.draw()
    if client.connected then
        love.graphics.stacked('all', function()
            do -- Centering
                local w, h = love.graphics.getDimensions()
                local dx, dy = 0.5 * (w - W), 0.5 * (h - H)
                love.graphics.setScissor(dx, dy, W, H)
                love.graphics.translate(dx, dy)
            end

            do -- Players
                for clientId, player in pairs(share.players) do
                    love.graphics.setColor(0, 1, 0)
                    love.graphics.rectangle('fill', player.x, player.y, G, G)
                end
            end

            do -- Border
                love.graphics.setColor(1, 1, 1)
                love.graphics.setLineWidth(6)
                love.graphics.line(0, 1, 0, H, W - 1, H, W - 1, 1, 0, 1)
            end
        end)
    else
        love.graphics.print('connecting', 20, 20)
    end
end
