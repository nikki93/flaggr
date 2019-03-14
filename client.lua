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


--- UTIL

function drawPlayer(player, x, y, isOwn)
    local f = player.died and 0.4 or 1
    if player.team == 'A' then
        love.graphics.setColor(0, f, 0)
    end
    if player.team == 'B' then
        love.graphics.setColor(f, f * 0.2, f)
    end
    love.graphics.circle('fill', x + 0.5 * G, y + 0.5 * G, 0.5 * G)
    if isOwn then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('line', x + 0.5 * G, y + 0.5 * G, 0.5 * G - 1)
    end
end

local clientStartTime = love.timer.getTime()


--- CONNECT

function client.connect()
    do -- Walk
        home.walk = { up = false, down = false, left = false, right = false }
    end
end


--- DRAW

local deathFont = love.graphics and love.graphics.newFont('font.ttf', 36)
local scoreFont = love.graphics and love.graphics.newFont('font.ttf', 24)
local instrFont = love.graphics and love.graphics.newFont('font.ttf', 20)

function client.draw()
    if client.connected then
        love.graphics.stacked('all', function()
            do -- Centering
                local w, h = love.graphics.getDimensions()
                local dx, dy = 0.5 * (w - W), 0.5 * (h - H)
                love.graphics.setScissor(dx, dy, W, H)
                love.graphics.translate(dx, dy)
            end

            do -- Waters
                for _, water in pairs(share.waters) do
                    love.graphics.setColor(0, 0, 1)
                    love.graphics.rectangle('fill', 0, water.minY, W, water.maxY - water.minY)
                end
            end

            do -- Dead players
                for clientId, player in pairs(share.players) do
                    if player.died then
                        drawPlayer(player, player.x, player.y, clientId == client.id)
                    end
                end
            end

            do -- Logs
                for logId, log in pairs(share.logs) do
                    love.graphics.setColor(0.65, 0.16, 0.16)
                    love.graphics.rectangle('fill', log.startX + (share.time - log.startTime) * log.xSpeed, log.y, log.length, G)
                end
            end

            do -- Cars
                for carId, car in pairs(share.cars) do
                    love.graphics.setColor(1, 0, 0)
                    love.graphics.rectangle('fill', car.startX + (share.time - car.startTime) * car.xSpeed, car.y, car.length, G)
                end
            end

            do -- Alive players
                local halfPing = math.min(3 * 0.16, 0.5 * client.getPing())
                for clientId, player in pairs(share.players) do
                    if not player.died then
                        local x, y = player.x, player.y
                        if player.xSetTime and player.vx then
                            x = player.x + math.max(0, share.time - halfPing - player.xSetTime) * player.vx
                        end
                        if player.ySetTime and player.vy then
                            y = player.y + math.max(0, share.time - halfPing - player.ySetTime) * player.vy
                        end
                        drawPlayer(player, x, y, clientId == client.id)
                    end
                end
            end

            do -- Flag
                love.graphics.setColor(0.8, 0.8, 0)
                if share.flag.carrierClientId then
                    love.graphics.rectangle('fill',
                        share.flag.x - 0.5 * FLAG_CARRIED_SIZE, share.flag.y - 0.5 * FLAG_CARRIED_SIZE,
                        FLAG_CARRIED_SIZE, FLAG_CARRIED_SIZE)
                else
                    love.graphics.rectangle('fill', share.flag.x, share.flag.y, FLAG_UNCARRIED_SIZE, FLAG_UNCARRIED_SIZE)
                end
            end

            do -- Bombs
                for bombId, bomb in pairs(share.bombs) do
                    love.graphics.setColor(1, 1, 0)
                    local r = BOMB_RADIUS * math.max(0, 1 - (share.time - bomb.startTime) / BOMB_DRAW_TIME)
                    love.graphics.circle('fill', bomb.x, bomb.y, r, r)
                end
            end

            do -- Border
                love.graphics.setColor(1, 1, 1)
                love.graphics.setLineWidth(6)
                love.graphics.line(1, 1, 1, H, W, H, W, 1, 1, 1)
            end

            love.graphics.setScissor()

            do -- Death message
                local myPlayer = share.players[client.id]
                if myPlayer.died then
                    local text = 'DIED, WAIT...'
                    local w, h = deathFont:getWidth(text), deathFont:getHeight()
                    love.graphics.stacked('all', function()
                        love.graphics.setFont(deathFont)
                        love.graphics.print(text, 0.5 * (W - w), H + 5)
                    end)
                end
            end

            do -- Flag reset message
                if share.flag.dropTime then
                    local text = tostring(math.max(0, math.floor(FLAG_DROP_RESET_TIME - (share.time - share.flag.dropTime) + 0.999)))
                    local w, h = scoreFont:getWidth(text), scoreFont:getHeight()
                    love.graphics.stacked('all', function()
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.setFont(scoreFont)
                        love.graphics.print(text, share.flag.x + 0.5 * G - 0.5 * w, share.flag.y + 0.5 * G - 0.5 * h)
                    end)
                end
            end

            do -- Flag score message
                local text = 'FLAGS: ' .. share.score.flags.A .. ', ' .. share.score.flags.B
                local w, h = scoreFont:getWidth(text), scoreFont:getHeight()
                love.graphics.stacked('all', function()
                    love.graphics.setFont(scoreFont)
                    love.graphics.print({
                        { 1, 1, 1 }, 'FLAGS: ' ,
                        { 0, 1, 0 }, tostring(share.score.flags.A) ,
                        { 1, 1, 1 }, ', ' ,
                        { 1, 0.2, 1 }, tostring(share.score.flags.B) ,
                    }, 5, -h - 5)
                end)
            end

            do -- Game score message
                local text = 'GAMES: ' .. share.score.games.A .. ', ' .. share.score.games.B
                local w, h = scoreFont:getWidth(text), scoreFont:getHeight()
                love.graphics.stacked('all', function()
                    love.graphics.setFont(scoreFont)
                    love.graphics.print({
                        { 1, 1, 1 }, 'GAMES: ' ,
                        { 0, 1, 0 }, tostring(share.score.games.A) ,
                        { 1, 1, 1 }, ', ' ,
                        { 1, 0.2, 1 }, tostring(share.score.games.B) ,
                    }, W - w - 5, -h - 5)
                end)
            end

            if love.timer.getTime() - clientStartTime < INSTRUCTIONS_SHOW_TIME then -- Instructions message
                local text = {
                    { 1, 1, 1 }, 'Arrows to move, SPACE to bomb\nFetch ',
                    { 0.8, 0.8, 0 }, 'FLAG',
                    { 1, 1, 1 }, ', bring it back down to score\nScore ' .. tostring(SCORE_FLAGS_PER_GAME) .. ' flags to win a GAME!',
                }
                local textCat = ''
                for _, s in ipairs(text) do
                    if type(s) == 'string' then
                        textCat = textCat .. s
                    end
                end
                local w, h = instrFont:getWidth(textCat), instrFont:getHeight()
                love.graphics.stacked('all', function()
                    love.graphics.setFont(instrFont)
                    love.graphics.printf(text, 0.5 * (W - w), H + 10 + deathFont:getHeight() + 5, w, 'center')
                end)
            end

            if DEBUG then -- Debug
                love.graphics.setLineWidth(1)
                for i = 0, H / G - 1 do
                    love.graphics.print(i, -20, i * G + 4)
                    love.graphics.line(0, i * G, W, i * G)
                end
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

        do -- Log overlaps
            applyLogOverlaps(share, dt)
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

        if key == 'space' then
            client.send('bomb')
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