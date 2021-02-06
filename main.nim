import raylib, os, lenientops, rayutils, math, strformat, deques, sets, tables, random

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

proc checkFreeze(plr : var Player, movecount : var int, actionAmt : var int, spacepressed, altpressed : var bool ) =
    echo actionAmt, " -> ", spacepressed
    if spacepressed and actionAmt > 0:
        plr.kickingEnemies = true
        plr.kickPower = 1
        spacepressed = false
    else:
        if plr.turnsLeftFrozen > 0:
            plr.turnsLeftFrozen += -1
        if spacepressed:
            spacepressed = false
            plr.kickingEnemies = false
            plr.kickPower = 0
        if altpressed:
            altpressed = false


proc movePlayer(plr : var Player, lfkey : var KeyboardKey, numtilesVec : Vector2, mvcount : var int, actionAmt : var int, spacepressed, altpressed : var bool, map : seq[seq[Tile]]) : bool =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            lfkey = KEY_LEFT
            result = false
        elif map[invert anticlamp(clamp(invert makevec2(plr.npos.y, plr.npos.x - 1), numTilesVec - 1), makevec2(0, 0))] != WALL:
            plr.npos.x += -1
            lfkey = KEY_LEFT
            result = true
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            lfkey = KEY_RIGHT
            result = false
        elif map[invert anticlamp(clamp(invert makevec2(plr.npos.y, plr.npos.x + 1), numTilesVec - 1), makevec2(0, 0))] != WALL:
            plr.npos.x += 1
            lfkey = KEY_RIGHT
            result = true
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            lfkey = KEY_UP
            result = false
        elif map[invert anticlamp(clamp(invert makevec2(plr.npos.y - 1, plr.npos.x), numTilesVec - 1), makevec2(0, 0))] != WALL:
            plr.npos.y += -1
            lfkey = KEY_UP
            result = true
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            lfkey = KEY_DOWN
            result = false
        elif map[invert anticlamp(clamp(invert makevec2(plr.npos.y + 1, plr.npos.x), numTilesVec - 1), makevec2(0, 0))] != WALL:
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
        mvcount += 1 
        checkFreeze plr, mvcount, actionAmt, spacepressed, altpressed

    # ----------------------- #
    #       Pathfinding       #
    # ----------------------- #

func getNeighborPos(v : Vector2, map : seq[seq[Tile]]) : seq[Vector2] =
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

func getNeighborTiles[T](map : seq[seq[T]], y, x : int) : seq[T] =
    if y < map.len - 1:
        result.add map[y + 1, x]
    if y > 0:
        result.add map[y - 1, x]
    if x < map[0].len - 1:
        result.add map[y, x + 1]
    if x > 0:
        result.add map[y, x - 1]


proc findPathBFS(start, target : Vector2, map : seq[seq[Tile]], plrPosSeq : seq[Vector2]) : seq[Vector2] =
    var fillEdge : Deque[Vector2]
    fillEdge.addLast start
    var traceTable = toTable {start : start}

    while fillEdge.len > 0:
        let curpos = fillEdge.popFirst
        if curpos == target: break
        for c in getNeighborPos(curpos, map):
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

proc moveEnemT1(enemies : var seq[Enemy], plr : Player, map : seq[seq[Tile]], plrPosSeq : seq[Vector2], mvcount : int) =
    let target = plr.pos
    let ntarget = plr.npos
    for i in 0..<enemies.len:
        let tarpath = findPathBFS(round enemies[i].pos, grEqCeil target, map, plrPosSeq)
        if enemies[i].typeId == 0:
            if tarpath.len > 1 and not enemies[i].kicked:
                let dir = tarpath[1] - enemies[i].pos
                var weight : int
                if mvcount mod 3 == 0: weight = rand(80..100)
                else: weight = rand(100)
                if weight < 84: enemies[i].npos = tarpath[1]
                elif weight < 94:
                    let ntarpath = findPathBFS(round enemies[i].pos, grEqCeil ntarget, map, plrPosSeq)
                    if ntarpath.len > 1:
                        enemies[i].npos = ntarpath[1]
                    else: enemies[i].npos = tarpath[1]
                elif weight < 96:
                    let nposcache = enemies[i].pos - invert dir
                    if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                        enemies[i].npos = nposcache
                    else: weight += 5
                elif weight < 99:
                    let nposcache = enemies[i].pos + invert dir
                    if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                        enemies[i].npos = nposcache

proc moveEnemT2(enemies : var seq[Enemy], plr : Player, map : seq[seq[Tile]], plrPosSeq : seq[Vector2], mvcount : int) =
    let target = plr.pos
    for i in 0..<enemies.len:
        let tarpath = findPathBFS(round enemies[i].pos, grEqCeil target, map, plrPosSeq)
        if enemies[i].typeId == 1:
            if tarpath.len > 1 and not enemies[i].kicked:
                var weight = rand(100)
                if weight < 30:
                    enemies[i].npos = tarpath[1]
                if weight < 46: 
                    let nposcache = enemies[i].pos + makevec2(0, 1)
                    if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                        enemies[i].npos = nposcache
                    else: weight += 16
                elif weight < 62:
                    let nposcache = enemies[i].pos - makevec2(0, 1)
                    if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                        enemies[i].npos = nposcache
                    else: weight += 16
                elif weight < 78:
                    let nposcache = enemies[i].pos + makevec2(1, 0)
                    if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                        enemies[i].npos = nposcache
                    else: weight += 16
                elif weight < 94:
                    let nposcache = enemies[i].pos - makevec2(1, 0)
                    if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
                        enemies[i].npos = nposcache 

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
    if c == '1': return EN1SPWN
    if c == '2': return EN2SPWN

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

    # -------------------------- #
    #       Map Generation       #
    # -------------------------- #

proc cellAutomaton(iters : int, wallaciousness : int) : seq[seq[Tile]] =
    result = genSeqSeq(8, 13, GRND)
    for j in 0..<result.len:
        for i in 0..<result[j].len:
            let weight = rand(100)
            if weight < wallaciousness:
                result[j, i] = WALL
    for itr in 0..iters:
        for j in 0..<result.len:
            for i in 0..<result[j].len:
                var liveNeighbors : int
                for c in result.getNeighborTiles(j, i):
                    if c != WALL: liveNeighbors += 1
                if liveNeighbors in 2..3:
                    if result[j, i] != WALL:
                        discard
                    elif liveNeighbors == 3:
                        result[j, i] = WALL
                elif result[j, i] == WALL:
                    result[j, i] = GRND



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
    actionFloor = 10

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 75

let
    playerTex = LoadTexture "assets/sprites/Player.png"
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", GOAL : LoadTexture "assets/sprites/LvlEndPortal.png", WALL : LoadTexture "assets/sprites/WallTile.png"}
    trailTex = LoadTexture "assets/sprites/WalkedTile.png"
    enemyTexArray = [LoadTexture "assets/sprites/Enemy1.png", LoadTexture "assets/sprites/Enemy2.png"]

proc genMap(iters, wallaciousness : int, goalLoc : Vector2) : seq[seq[Tile]] =
    result = cellAutomaton(iters, wallaciousness)
    if goalLoc.x == -1:
        result[rand(result.len - 1), rand(result[0].len - 1)] = GOAL
    else: result[invert goalLoc] = GOAL

var
    plr = Player(canMove : true)
    lastframekey = KEY_F
    plrPosSeq : seq[Vector2]
    currentlv = 1
    deathTimer : int
    winTimer : int
    map = genMap(20, 30, makevec2(-1, -1))
    emap = loadEmap 1 
    elocs : seq[Vector2]
    lvenloc = findFromMap map
    enemies : seq[Enemy]
    movecount : int
    spacecache : bool
    altcache : bool
    genTimer : int
    rcache : bool
    etypes : seq[int]
    timersToReset = @[deathTimer, genTimer]
    finalmvcnt : int
    actionAmt = 3

(plr.pos, elocs, etypes) = findFromEmap emap

for i, loc in elocs.pairs:
    enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))


proc initLevel(emap : seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], etypes : var seq[int], plr : var Player, mvcount : var int, lvenloc : Vector2, plrPosSeq : var seq[Vector2], timers : var seq[int]) =
    map = genMap(20, 30, makevec2(-1, -1))
    (plr.pos, enemylocs, etypes) = findFromEmap emap
    plr.npos = makevec2(0, 0); plr.canMove = true
    enemies = @[]
    for i, loc in enemylocs.pairs:
        enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))
    for i in 0..<enemies.len:
        enemies[i].pos = enemylocs[i]
        enemies[i].npos = enemylocs[i]
    plr.turnsLeftFrozen = 0
    plrPosSeq = @[]
    for i in 0..<timers.len: timers[i] = 0


proc loadLevel(lvl : int, map : var seq[seq[Tile]], emap : var seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], enemtypes : var seq[int], plr : var Player, mvcount : var int, plrPosSeq : var seq[Vector2], timers : var seq[int], lvenloc : var Vector2) =
    emap = loadEmap lvl
    initLevel(emap, enemies, enemylocs, enemtypes, plr, movecount, lvenloc, plrPosSeq, timers)
    lvenloc = findFromMap map
while not WindowShouldClose():
    ClearBackground RAYWHITE
        

    # Check if player walked on trail
    # if plrPosSeq.len > 1:
    #     if plr.npos in plrPosSeq[0..^2]:
    #         plr.canMove = false
    #         plr.dead = true
    if plr.npos notin plrPosSeq:
        plrPosSeq.add plr.npos
    
    if not plr.canMove and plr.dead:
        finalmvcnt = movecount
        if deathTimer == 5:
            echo &"Run ended! Score : {currentlv} | {finalmvcnt}"
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, movecount, plrPosSeq, timersToReset, lvenloc
            movecount = 0
            deathTimer = 0
            actionAmt = 3
        deathTimer += 1
    
    # Check if player has reached the end goal
    if plr.npos == lvenloc:
        plr.won = true

    if plr.won:
        deathTimer = 0
        plr.canMove = false
        if winTimer == 10:
            plr.won = false
            if currentlv < 2: currentlv += 1
            else: currentlv += -1
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, movecount, plrPosSeq, timersToReset, lvenloc
            winTimer = 0
            finalmvcnt = 0
            actionAmt = 3
        else: winTimer += 1
    
    # Cache buttons pressed
    if IsKeyDown(KEY_SPACE):
        spacecache = true
    if IsKeyDown(KEY_LEFT_ALT) or IsKeyDown(KEY_RIGHT_ALT):
        altcache = true
    
    if IsKeyDown(KEY_R):
        rcache = true
    
    if rcache:
        if genTimer >= 5:
            map = genMap(25, 30, lvenloc)
            movecount = 0
            deathTimer = 0
            actionAmt = 3
            rcache = false
        else: gentimer += 1

    # Move and Animate Player and Enemies
    if plr.canMove:
        if movePlayer(plr, lastframekey, numTilesVec, movecount, actionAmt, spacecache, altcache, map):
            moveEnemT1 enemies, plr, map, plrPosSeq, movecount
            moveEnemT2 enemies, plr, map, plrPosSeq, movecount
    var kicked : bool
    var enemDeleteCache : HashSet[int]
    for i in 0..<enemies.len:
        if enemies[i].pos == plr.pos:
            if plr.kickingEnemies:
                discard
                # kicked = true
                # echo "k => ", i
                # enemies[i].npos = round enemies[i].pos + normalize(plrPosSeq[^1] - plrPosSeq[^2]) * (plr.kickPower + 1) 
                # enemies[i].kicked = true
                # plr.kickPower = 0
            else:
                plr.canMove = false
                plr.dead = true
        if map[invert enemies[i].pos] == WALL and enemies[i].pos == roundDown enemies[i].pos:
            enemDeleteCache.incl i
    if kicked:
        actionAmt += -1
        plr.kickingEnemies = false
    var deletions : int
    # for i in enemDeleteCache:
    #     enemies.delete i - deletions
    #     deletions += 1 
    playerAnim plr
    enemyAnim enemies


    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()
    renderMap map, tileTexTable, tilesize
    # renderTrail plrPosSeq, trailTex, tilesize
    drawTexCenteredFromGrid playerTex, plr.pos, tilesize, WHITE
    renderEnemies enemies, enemyTexArray, tilesize
    EndDrawing()

for t in Tile:
    UnloadTexture tileTexTable[t]
UnloadTexture playertex, trailTex
CloseWindow()