import raylib, os, lenientops, rayutils, math, strformat, deques, sets, tables, sugar, random

randomize()

type
    Player = object
        pos : Vector2
        npos : Vector2
        canMove : bool
        dead : bool
        won : bool
        turnsLeftFrozen : int
        kickingEnemies : bool
        kickPower : int
    Enemy = object
        pos : Vector2
        npos : Vector2
        path : seq[Vector2]
        canMove : bool
        dead : bool
        won : bool
        kicked : bool
        typeId : int
    Tile = enum
        GRND, WALL, GOAL
    ETile = enum
        NONE, PLRSPWN, EN1SPWN, EN2SPWN

    # --------------------------- #
    #       Grid Management       #
    # --------------------------- #

func screenToGrid(screencoord : Vector2) : Vector2 =
    return makevec2(grEqCeil screencoord.x, grEqCeil screencoord.y)

func screenToGrid(screencoord : float | int | float32, numXTiles : int | float32) : float | int | float32 =
    return grEqCeil screencoord / numXTiles

func gridToScreen(gridcoord, numXtiles : float | int | float32) : float | int | float32 =
    return gridcoord * numXTiles

func gridToScreen(gridcoord, numTilesVec : Vector2) :  Vector2 =
    return gridcoord * numTilesVec

proc drawTexFromGrid(tex : Texture, pos : Vector2, tilesize : int) =
    DrawTexture(tex, int pos.x * tilesize, int pos.y * tilesize, WHITE)

proc drawTexCenteredFromGrid(tex : Texture, pos : Vector2, tilesize : int, tint : Color) =
    DrawTexture(tex, int32 pos.x * tilesize + (tilesize - tex.width) / 2, int32 pos.y * tilesize + (tilesize - tex.height) / 2, tint)

    # ----------------------------- #
    #       Player Management       #
    # ----------------------------- #

func playerAnim(plr : var Player) =
    if plr.pos != plr.npos:
        let dir = plr.npos - plr.pos
        plr.pos += dir / 2
    if abs(plr.pos - plr.npos) <& 0.1: 
        plr.pos = plr.npos

proc checkFreeze(plr : var Player, movecount : var int, actionFloor : int, spacepressed, altpressed : var bool ) =

    echo movecount, " -> ", actionFloor
    if spacepressed and movecount >= actionFloor:
        plr.kickingEnemies = true
        plr.kickPower = movecount div actionFloor
        movecount = 0
        spacepressed = false
    elif altpressed and movecount >= actionFloor + 2:
        plr.turnsLeftFrozen = 1
        movecount = 0
        altpressed = false
    else:
        if plr.turnsLeftFrozen > 0:
            plr.turnsLeftFrozen += -1
        if spacepressed:
            spacepressed = false
        if altpressed:
            altpressed = false

proc movePlayer(plr : var Player, lfkey : var KeyboardKey, numtilesVec : Vector2, mvcount : var int, spacepressed, altpressed : var bool, freezeMoveFloor : int) : bool =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            lfkey = KEY_LEFT
            result = false
        else:
            plr.npos.x += -1
            lfkey = KEY_LEFT
            result = true
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            lfkey = KEY_RIGHT
            result = false
        else:
            plr.npos.x += 1
            lfkey = KEY_RIGHT
            result = true
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            lfkey = KEY_UP
            result = false
        else:
            plr.npos.y += -1
            lfkey = KEY_UP
            result = true
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            lfkey = KEY_DOWN
            result = false
        else:
            plr.npos.y += 1
            lfkey = KEY_DOWN
            result = true
    elif IsKeyDown(KEY_X):
        if lfkey == KEY_X:
            lfkey = KEY_X
            result = false
        else:
            lfkey = KEY_X
            result = true
    else:
        lfkey = KEY_SCROLL_LOCK
        result = false
    plr.npos = anticlamp(clamp(plr.npos, numTilesVec - 1), makevec2(0, 0))
    if result:
        if plr.turnsLeftFrozen == 0 and plr.kickingEnemies == false: mvcount += 1 
        checkFreeze plr, mvcount, freezeMoveFloor, spacepressed, altpressed

    # ----------------------- #
    #       Pathfinding       #
    # ----------------------- #

proc getNeighbors(v : Vector2, map : seq[seq[Tile]], target : Vector2, plrPosSeq : seq[Vector2]) : seq[Vector2] =
    let v = makevec2(v.y, v.x)
    if v.x < map.len - 1:
        if map[v.x + 1, v.y] != WALL:
            result.add makevec2(v.y, v.x + 1)
    if v.x > 0:
        if map[v.x - 1, v.y] != WALL:
            result.add makevec2(v.y, v.x - 1)
    if v.y < map[0].len - 1:
        if map[v.x, v.y + 1] != WALL:
            result.add makevec2(v.y + 1, v.x)
    if v.y > 0:
        if map[v.x, v.y - 1] != WALL:
            result.add makevec2(v.y - 1, v.x)


proc findPathBFS(start, target : Vector2, map : seq[seq[Tile]], plrPosSeq : seq[Vector2]) : seq[Vector2] =
    var fillEdge : Deque[Vector2]
    fillEdge.addLast start
    var traceTable = toTable {start : start}

    while fillEdge.len > 0:
        let curpos = fillEdge.popFirst
        if curpos == target: break
        for c in getNeighbors(curpos, map, target, plrPosSeq):
            if c notin traceTable:
                traceTable[c] = curpos
                fillEdge.addLast c
    

    if fillEdge.len > 0:
        var antipath = @[target]
        var tracepos = target
        while tracepos != start:
            antipath.add traceTable[tracepos]
            tracepos = traceTable[tracepos]
        for i in 1..antipath.len:
            result.add antipath[^i]
        result.add target

    # ----------------------------- #
    #       Entity Management       #
    # ----------------------------- #

proc renderEnemies(enemies : seq[Enemy], enemyTexArr : openArray[Texture], tilesize : int) =
    for e in enemies:
        echo e.typeId
        drawTexCenteredFromGrid enemyTexArr[e.typeId], e.pos, tilesize, WHITE

proc enemyAnim(enemies : var seq[Enemy]) =
    for i in 0..<enemies.len:
        if enemies[i].kicked:
            let dir = enemies[i].npos - enemies[i].pos
            enemies[i].pos += dir / 2
            if enemies[i].npos == enemies[i].pos:
                enemies[i].kicked = false
        elif enemies[i].npos != enemies[i].pos:
            let dir = enemies[i].npos - enemies[i].pos
            enemies[i].pos += dir / 2
        if abs(enemies[i].pos - enemies[i].npos) <& 0.1:
            enemies[i].pos = enemies[i].npos

proc moveEnemies(enemies : var seq[Enemy], target : Vector2, map : seq[seq[Tile]], plrPosSeq : seq[Vector2]) =
    for i in 0..<enemies.len:
        let x = findPathBFS(round enemies[i].pos, grEqCeil target, map, plrPosSeq)
        if x.len > 1 and not enemies[i].kicked:
            let dir = x[1] - enemies[i].pos
            var weight = rand(100)
            if weight < 85: enemies[i].npos = x[1]
            elif weight < 90:
                let nposcache = enemies[i].pos - dir
                if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                    enemies[i].npos = nposcache
                else: weight += 5
            elif weight < 95:
                let nposcache = enemies[i].pos + invert dir
                if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                    enemies[i].npos = nposcache
                else: weight += 5
            else:
                let nposcache = enemies[i].pos - invert dir
                if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                    enemies[i].npos = nposcache
                else: enemies[i].npos = x[1]

    # -------------------------- #
    #       Map Management       #
    # -------------------------- #

func parseMapTile(c : char) : Tile = 
    if c == '-': return GRND
    if c == '#': return WALL
    if c == '=': return GOAL

func parseEmapTile(c : char) : ETile =
    if c == '-': return NONE
    if c == '#': return PLRSPWN
    if c == '*': return EN1SPWN

proc renderMap(map : seq[seq[Tile]], tileTexTable : Table[Tile, Texture], tilesize : int) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            drawTexFromGrid(tileTexTable[map[i, j]], makevec2(j, i), tilesize)

proc findFromMap(map : seq[seq[Tile]]) : Vector2 =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            if map[i, j] == GOAL:
                result = makevec2(j, i)

proc findFromEmap(emap : seq[seq[Etile]]) : (Vector2, seq[Vector2], seq[int]) =
    for i in 0..<emap.len:
        for j in 0..<emap[i].len:
            if emap[i, j] != NONE:
                if emap[i, j] == PLRSPWN: result[0] = makevec2(j, i)
                if emap[i, j] == EN1SPWN: 
                    result[1].add makevec2(j, i)
                    result[2].add 0
                if emap[i, j] == EN2SPWN:
                    result[1].add makevec2(j, i)
                    result[2].add 1

proc renderTrail(trail : seq[Vector2], trailTex : Texture, tilesize : int) =
    for v in trail:
        drawTexFromGrid trailTex, v, tilesize


    # ----------------------- #
    #       Import Maps       #
    # ----------------------- #

proc loadMap(lvl : int) : seq[seq[Tile]] =
    var lcount = 0
    for line in lines &"assets/maps/levelmaps/lvl{lvl}.txt":
        result.add @[]
        for c in line:
            result[lcount].add parseMapTile c
        lcount += 1

proc loadEmap(lvl : int) : seq[seq[Etile]] =
    var lcount = 0
    for line in lines &"assets/maps/emaps/lvl{lvl}.txt":
        result.add @[]
        for c in line:
            result[lcount].add parseEmapTile c
        lcount += 1


    # -------------------------- #
    #       Initialization       #
    # -------------------------- #

const
    tilesize = 96
    screenHeight = 768
    screenWidth = 1248
    numTilesVec = makevec2(screenWidth div tilesize, screenHeight div tilesize)
    actionFloor = 4

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 75

let
    playerTex = LoadTexture "assets/sprites/Player.png"
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", GOAL : LoadTexture "assets/sprites/LvlEndPortal.png", WALL : LoadTexture "assets/sprites/WallTile.png"}
    trailTex = LoadTexture "assets/sprites/WalkedTile.png"
    enemyTexArray = [LoadTexture "assets/sprites/Enemy1.png"]


var
    plr = Player(canMove : true)
    lastframekey = KEY_F
    plrPosSeq : seq[Vector2]
    currentlv = 1
    deathTimer : int
    winTimer : int
    map = loadMap 1
    emap = loadEmap 1 
    elocs : seq[Vector2]
    lvenloc = findFromMap map
    enemies : seq[Enemy]
    movecount : int
    spacecache : bool
    altcache : bool
    etypes : seq[int]
    timersToReset = @[deathTimer]

(plr.pos, elocs, etypes) = findFromEmap emap

for i, loc in elocs.pairs:
    enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))

func initLevel(emap : seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], etypes : var seq[int], plr : var Player, mvcount : var int, plrPosSeq : var seq[Vector2], timers : var seq[int]) =
    (plr.pos, enemylocs, etypes) = findFromEmap emap
    plr.npos = makevec2(0, 0); plr.canMove = true
    enemies = @[]
    for i, loc in enemylocs.pairs:
        enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))
    for i in 0..<enemies.len:
        enemies[i].pos = enemylocs[i]
        enemies[i].npos = enemylocs[i]
    plr.turnsLeftFrozen = 0
    mvcount = 0
    plrPosSeq = @[]
    for i in 0..<timers.len: timers[i] = 0


proc loadLevel(lvl : int, map : var seq[seq[Tile]], emap : var seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], enemtypes : var seq[int], plr : var Player, mvcount : var int, plrPosSeq : var seq[Vector2], timers : var seq[int]) =
    emap = loadEmap lvl; map = loadMap lvl
    initLevel emap, enemies, enemylocs, enemtypes, plr, movecount, plrPosSeq, timers

while not WindowShouldClose():
    ClearBackground RAYWHITE

    # Check if player walked on trail
    if plrPosSeq.len > 1:
        if plr.npos in plrPosSeq[0..^2]:
            plr.canMove = false
            plr.dead = true
    if plr.npos notin plrPosSeq:
        plrPosSeq.add plr.npos
    
    if not plr.canMove and plr.dead:
        if deathTimer == 5:
            initLevel emap, enemies, elocs, etypes, plr, movecount, plrPosSeq, timersToReset
            deathTimer = 0
        deathTimer += 1
    
    # Check if player has reached the end goal
    if plr.npos == lvenloc:
        plr.won = true

    if plr.won:
        plr.canMove = false
        if winTimer == 10:
            plr.won = false
            currentlv += 0
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, movecount, plrPosSeq, timersToReset
            winTimer = 0
        else: winTimer += 1
    
    # Cache buttons pressed
    if IsKeyDown(KEY_SPACE):
        spacecache = true
    if IsKeyDown(KEY_LEFT_ALT) or IsKeyDown(KEY_RIGHT_ALT):
        altcache = true
    
    # Move and Animate Player and Enemies
    if plr.canMove:
        if movePlayer(plr, lastframekey, numTilesVec, movecount, spacecache, altcache, actionFloor) and plr.turnsLeftFrozen == 0:
            moveEnemies enemies, plr.pos, map, plrPosSeq
    var enemDeleteCache : HashSet[int]
    for i in 0..<enemies.len:
        if enemies[i].pos == plr.pos:
            if plr.kickingEnemies:
                enemies[i].npos = round enemies[i].pos + normalize(plrPosSeq[^1] - plrPosSeq[^2]) * (plr.kickPower + 1) 
                enemies[i].kicked = true
                movecount = 0
                plr.kickingEnemies = false
                plr.kickPower = 0
            else:
                plr.canMove = false
                plr.dead = true
        if map[invert enemies[i].npos] == WALL and enemies[i].pos == enemies[i].npos:
            enemDeleteCache.incl i
    var deletions : int
    for i in enemDeleteCache:
        enemies.delete i - deletions
        deletions += 1 
    playerAnim plr
    enemyAnim enemies


    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()
    renderMap map, tileTexTable, tilesize
    renderTrail plrPosSeq, trailTex, tilesize
    drawTexCenteredFromGrid playerTex, plr.pos, tilesize, WHITE
    renderEnemies enemies, enemyTexArray, tilesize
    EndDrawing()

for t in Tile:
    UnloadTexture tileTexTable[t]
UnloadTexture playertex, trailTex
CloseWindow()