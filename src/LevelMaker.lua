--[[
    GD50
    Super Mario Bros. Remake

    -- LevelMaker Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

LevelMaker = Class{}

function LevelMaker.generate(width, height)
    local tiles = {}
    local entities = {}
    objects = {}
    levelWidth = width
    levelHeight = height

    local tileID = TILE_ID_GROUND
    
    -- whether we should draw our tiles with toppers
    local topper = true
    local tileset = math.random(20)
    local topperset = math.random(20)

    local xLockBlock = math.min(math.random(math.max(2, levelWidth *3/4)) + 1, levelWidth-2)
    local xKey = math.min(math.random(math.max(2, levelWidth *3/4)) + 1, levelWidth-2)

    local lockBlockColor = math.random(4)


    floorLevel = 7
    -- insert blank tables into tiles for later access
    for x = 1, levelHeight do
        table.insert(tiles, {})
    end

    -- ensure first tile is always floor for the player
    -- lay out the empty space
    for y = 1, 6 do
        table.insert(tiles[y],
            Tile(1, y, TILE_ID_EMPTY, nil, tileset, topperset))
    end
    -- lay out the floor
    for y = floorLevel, levelHeight do
        table.insert(tiles[y],
            Tile(1, y, TILE_ID_GROUND, y == floorLevel and topper or nil, tileset, topperset))
    end

    -- column by column generation instead of row; sometimes better for platformers
    for x = 2, levelWidth -2 do
        local tileID = TILE_ID_EMPTY
        
        -- lay out the empty space
        for y = 1, 6 do
            table.insert(tiles[y],
                Tile(x, y, tileID, nil, tileset, topperset))
        end

        -- chance to just be emptiness
        if math.random(7) == 1 and x ~= xLockBlock and x ~= xKey then
            for y = floorLevel, levelHeight do
                table.insert(tiles[y],
                    Tile(x, y, tileID, nil, tileset, topperset))
            end
        else
            tileID = TILE_ID_GROUND

            -- height at which we would spawn a potential jump block
            local blockHeight = 4

            for y = 7, levelHeight do
                table.insert(tiles[y],
                    Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
            end

            if x == xLockBlock or x == xKey then
                if x == xLockBlock then
                    LevelMaker.spawnLockBlock(x, blockHeight, lockBlockColor)
                end
                if x == xKey then
                    LevelMaker.spawnKey(x, floorLevel-1, lockBlockColor)
                end
                goto continue
            end

            -- chance to generate a pillar
            if math.random(8) == 1 then
                blockHeight = 2
                
                -- chance to generate bush on pillar
                if math.random(8) == 1 then
                    table.insert(objects,
                        GameObject {
                            texture = 'bushes',
                            x = (x - 1) * TILE_SIZE,
                            y = (4 - 1) * TILE_SIZE,
                            width = 16,
                            height = 16,
                            
                            -- select random frame from bush_ids whitelist, then random row for variance
                            frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7,
                            collidable = false
                        }
                    )
                end
                
                -- pillar tiles
                tiles[5][x] = Tile(x, 5, tileID, topper, tileset, topperset)
                tiles[6][x] = Tile(x, 6, tileID, nil, tileset, topperset)
                tiles[7][x].topper = nil
            
            -- chance to generate bushes
            elseif math.random(8) == 1 then
                table.insert(objects,
                    GameObject {
                        texture = 'bushes',
                        x = (x - 1) * TILE_SIZE,
                        y = (6 - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7,
                        collidable = false
                    }
                )
            end

            -- chance to spawn a block
            if math.random(10) == 1 then
                table.insert(objects,

                    -- jump block
                    GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (blockHeight - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,

                        -- make it a random variant
                        frame = math.random(#JUMP_BLOCKS),
                        collidable = true,
                        hit = false,
                        solid = true,

                        -- collision function takes itself
                        onCollide = function(obj)

                            -- spawn a gem if we haven't already hit the block
                            if not obj.hit then

                                -- chance to spawn gem, not guaranteed
                                if math.random(5) == 1 then

                                    -- maintain reference so we can set it to nil
                                    local gem = GameObject {
                                        texture = 'gems',
                                        x = (x - 1) * TILE_SIZE,
                                        y = (blockHeight - 1) * TILE_SIZE - 4,
                                        width = 16,
                                        height = 16,
                                        frame = math.random(#GEMS),
                                        collidable = true,
                                        consumable = true,
                                        solid = false,

                                        -- gem has its own function to add to the player's score
                                        onConsume = function(player, object)
                                            gSounds['pickup']:play()
                                            player.score = player.score + 100
                                        end
                                    }
                                    
                                    -- make the gem move up from the block and play a sound
                                    Timer.tween(0.1, {
                                        [gem] = {y = (blockHeight - 2) * TILE_SIZE}
                                    })
                                    gSounds['powerup-reveal']:play()

                                    table.insert(objects, gem)
                                end

                                obj.hit = true
                            end

                            gSounds['empty-block']:play()
                        end
                    }
                )
            end

            ::continue::
        end
    end

    -- ensure last two tile is always floor for the flag
    -- lay out the empty space
    for x = levelWidth-1, levelWidth do
        for y = 1, 6 do
            table.insert(tiles[y],
                Tile(x, y, TILE_ID_EMPTY, nil, tileset, topperset))
        end
        -- lay out the floor
        for y = floorLevel, levelHeight do
            table.insert(tiles[y],
                Tile(x, y, TILE_ID_GROUND, y == floorLevel and topper or nil, tileset, topperset))
        end
    end

    local map = TileMap(levelWidth, levelHeight)
    map.tiles = tiles
    
    return GameLevel(entities, objects, map)
end

function LevelMaker.spawnLockBlock(x, y, color)
    local lockBlock = GameObject {
        texture = 'lock-blocks',
        x = (x - 1) * TILE_SIZE,
        y = (y - 1) * TILE_SIZE,
        width = 16,
        height = 16,

        -- make it a random variant
        frame = color + 4,
        collidable = true,
        hit = false,
        solid = true,

        -- collision function takes itself
        onCollide = function(object, player)

            -- unlock the block
            if player.hasKey then
                objects['lock-block'] = nil
                gSounds['pickup']:play()
                LevelMaker.spawnGoalFlag()
            else
                gSounds['empty-block']:play()
            end

        end
    }

    objects['lock-block'] = lockBlock
end

function LevelMaker.spawnKey(x, y, color)
    
    -- maintain reference so we can set it to nil
    local key = GameObject {
        texture = 'lock-blocks',
        x = (x - 1) * TILE_SIZE,
        y = (y - 1) * TILE_SIZE - 4,
        width = 16,
        height = 16,
        frame = color,
        collidable = true,
        consumable = true,
        solid = false,

        -- player obtains the key
        onConsume = function(player, object)
            gSounds['pickup']:play()
            player.hasKey = true
        end
    }

    table.insert(objects, key)
end


function LevelMaker.spawnGoalFlag()
    local flagpoleColor = math.random(POLE_COLORS)
    local flagColor = math.random(FLAG_COLORS) - 1

    local flagsSpritesheetWidth = 9
    local goalFlagX = levelWidth - 2
    local goalFlagY = floorLevel - 2

    local flagpoleTop = GameObject {
        texture = 'flags',
        x = goalFlagX * TILE_SIZE,
        y = (goalFlagY - 2) * TILE_SIZE,
        width = 16,
        height = 16,
        frame = flagpoleColor,
        collidable = true,
        consumable = false,
        solid = false,

        -- collision function takes itself
        onCollide = function(object, player)
            gSounds['pickup']:play()
            LevelMaker.nextLevel(player)
        end
    }
    
    local flagpoleCenter = GameObject {
        texture = 'flags',
        x = goalFlagX * TILE_SIZE,
        y = (goalFlagY - 1) * TILE_SIZE,
        width = 16,
        height = 16,
        frame = flagpoleColor + flagsSpritesheetWidth,
        collidable = true,
        consumable = false,
        solid = false,

        -- collision function takes itself
        onCollide = function(object, player)
            gSounds['pickup']:play()
            LevelMaker.nextLevel(player)
        end
    }

    local flagpoleBase = GameObject {
        texture = 'flags',
        x = goalFlagX * TILE_SIZE,
        y = (goalFlagY) * TILE_SIZE,
        width = 16,
        height = 16,
        frame = flagpoleColor + flagsSpritesheetWidth * 2,
        collidable = true,
        consumable = false,
        solid = false,

        -- collision function takes itself
        onCollide = function(object, player)
            gSounds['pickup']:play()
            LevelMaker.nextLevel(player)
        end
    }

    local flag = GameObject {
        texture = 'flags',
        x = goalFlagX * TILE_SIZE + 8,
        y = (goalFlagY - 2) * TILE_SIZE + 4,
        width = 16,
        height = 16,
        frame = flagColor * flagsSpritesheetWidth + POLE_COLORS + 1,
        collidable = false,
        consumable = false,
        solid = false,
    }

    table.insert(objects, flagpoleBase)
    table.insert(objects, flagpoleCenter)
    table.insert(objects, flagpoleTop)
    table.insert(objects, flag)
end

function LevelMaker.nextLevel(player)
    gStateMachine:change('play', {
        score = player.score,
        width = levelWidth + NEXT_LEVEL_INCREMENT, height = LEVEL_HEIGHT
    })
end
