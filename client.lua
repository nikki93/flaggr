require 'common'

local moonshine = require 'https://raw.githubusercontent.com/nikki93/moonshine/9e04869e3ceaa76c42a69c52a954ea7f6af0469c/init.lua'


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
        love.graphics.setLineWidth(4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('line', x + 0.5 * G, y + 0.5 * G, 0.5 * G - 2)
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

local deathFont = love.graphics and love.graphics.newFont('fonts/font.ttf', 36)
local scoreFont = love.graphics and love.graphics.newFont('fonts/font.ttf', 24)
local flagResetFont = love.graphics and love.graphics.newFont('fonts/font.ttf', 20)
local instrFont = love.graphics and love.graphics.newFont('fonts/font.ttf', 20)

local sprites = {}

if love.graphics then
    sprites['car1-224x122.png'] = love.graphics.newImage('sprites/car1-224x122.png')
    sprites['car2-224x122.png'] = love.graphics.newImage('sprites/car2-224x122.png')
    sprites['car3-224x122.png'] = love.graphics.newImage('sprites/car3-224x122.png')
    sprites['car1-336x122.png'] = love.graphics.newImage('sprites/car1-336x122.png')
    sprites['car2-336x122.png'] = love.graphics.newImage('sprites/car2-336x122.png')
    sprites['car1-2240x122.png'] = love.graphics.newImage('sprites/car1-2240x122.png')

    sprites['log1.png'] = love.graphics.newImage('sprites/log1.png')
    sprites['log2.png'] = love.graphics.newImage('sprites/log2.png')
end

local bgrImg = love.graphics and love.graphics.newImage('sprites/bgr.png')

local effect

if love.graphics then
    effect = effect or moonshine(moonshine.effects.glow)
        .chain(moonshine.effects.godsray)
        .chain(moonshine.effects.pixelate)
        .chain(moonshine.effects.filmgrain)
        .chain(moonshine.effects.crt)

    effect.pixelate.size = {1.2, 1.2}
    effect.pixelate.feedback = 0.0
    effect.glow.strength = 1
    effect.filmgrain.size = 5.0
    effect.filmgrain.opacity = 0.1
    effect.crt.x = 1.05
    effect.crt.y = 1.05
    effect.crt.feather = 0.1

    effect.godsray.exposure = 0.0
end

function client.resize(w, h)
    effect.resize(w, h)
end

function client.draw()
    if client.connected then
        local myPlayer = share.players[client.id]
        if myPlayer.died then
            local timeSinceDeath = share.time - myPlayer.deathTime
            if timeSinceDeath < 0.3 then
                effect.godsray.exposure = math.max(0, 0.2 * (0.3 - timeSinceDeath))
            end
        else
            effect.godsray.exposure = 0.0
        end

        effect(function()
        love.graphics.stacked('all', function()
            do -- Centering
                local w, h = love.graphics.getDimensions()
                local dx, dy = 0.5 * (w - W), 0.5 * (h - H)
                love.graphics.setScissor(dx, dy, W, H)
                love.graphics.translate(dx, dy)
            end

            do -- Background
                love.graphics.draw(bgrImg, 0, 0, 0, 0.3333333333)
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
                love.graphics.setColor(1, 1, 1)
                for logId, log in pairs(share.logs) do
                    local sprite = sprites[log.spriteName]
                    love.graphics.draw(sprite,
                        log.startX + (share.time - log.startTime) * log.xSpeed, log.y,
                        0,
                        log.length / sprite:getWidth(),
                        G / sprite:getHeight())
                end
            end

            do -- Cars
                love.graphics.setColor(1, 1, 1)
                for carId, car in pairs(share.cars) do
                    local sprite = sprites[car.spriteName]
                    local flip = car.xSpeed < 0
                    love.graphics.draw(sprite,
                        car.startX + (share.time - car.startTime) * car.xSpeed + (flip and car.length or 0), car.y,
                        0,
                        (flip and -1 or 1) * car.length / sprite:getWidth(),
                        G / sprite:getHeight())
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
                love.graphics.setColor(1, 1, 0)
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
                        love.graphics.print(text, 0.5 * (W - w), H + 10)
                    end)
                end
            end

            do -- Flag reset message
                if share.flag.dropTime then
                    local text = tostring(math.max(0, math.floor(FLAG_DROP_RESET_TIME - (share.time - share.flag.dropTime) + 0.999)))
                    local w, h = flagResetFont:getWidth(text), flagResetFont:getHeight()
                    love.graphics.stacked('all', function()
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.setFont(flagResetFont)
                        love.graphics.print(text, share.flag.x + 0.5 * G - 0.5 * w + 2, share.flag.y + 0.5 * G - 0.5 * h + 2)
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
                    { 1, 1, 0 }, 'FLAG',
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