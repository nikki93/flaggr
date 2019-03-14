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


--- CONNECT

function client.connect()
    do -- Walk
        home.walk = { up = false, down = false, left = false, right = false }
    end
end


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

            do -- Cars
                for carId, car in pairs(share.cars) do
                    love.graphics.setColor(1, 0, 0)
                    love.graphics.rectangle('fill', car.startX + (share.time - car.startTime) * car.xSpeed, car.y, car.length, G)
                end
            end

            do -- Border
                love.graphics.setColor(1, 1, 1)
                love.graphics.setLineWidth(6)
                love.graphics.line(1, 1, 1, H, W, H, W, 1, 1, 1)
            end

            love.graphics.setScissor()

            if DEBUG then -- Debug
                love.graphics.setLineWidth(1)
                for i = 0, H / G - 1 do
                    love.graphics.print(i, -20, i * G + 4)
                    love.graphics.line(0, i * G, W, i * G)
                end

                love.graphics.print(share.players[1].yDir, 0, -30)
            end
        end)
    else
        love.graphics.print('connecting', 20, 20)
    end
end


--- UPDATE

function client.update(dt)
    if client.connected then
        do -- Time
            share.time = share.time + dt
        end

        do -- Our player
            -- playerApplyWalk(share.players[client.id], dt)
        end
    end
end


--- CHANGING

function client.changing(diff)
    if diff.time and share.time then -- Make sure time only goes forward
        diff.time = math.max(share.time, diff.time)
    end
end


--- KEYBOARD

function client.keypressed(key)
    do -- Player
        if key == 'left' then
            home.walk.left = true
        end
        if key == 'right' then
            home.walk.right = true
        end
        if key == 'up' then
            home.walk.up = true
        end
        if key == 'down' then
            home.walk.down = true
        end
    end
end

function client.keyreleased(key)
    do -- Player
        if key == 'left' then
            home.walk.left = false
        end
        if key == 'right' then
            home.walk.right = false
        end
        if key == 'up' then
            home.walk.up = false
        end
        if key == 'down' then
            home.walk.down = false
        end
    end
end