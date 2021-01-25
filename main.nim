import raylib, os, lenientops, rayutils, math, strformat, deques, sets, tables

type
    Player = object
        pos : Vector2
        npos : Vector2
        canMove : bool
        dead : bool
        won : bool
        turnsLeftFrozen : int
    Enemy = object
        pos : Vector2
        npos : Vector2
        path : seq[Vector2]
        canMove : bool
        dead : bool
        won : bool

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
    DrawTexture(tex, int pos.x * tilesize + (tilesize - tex.width) / 2, int pos.y * tilesize + (tilesize - tex.height) / 2, tint)

    # ----------------------------- #
    #       Player Management       #
    # ----------------------------- #

func playerAnim(plr : var Player) =
    if plr.pos != plr.npos:
        let dir = plr.npos - plr.pos
        plr.pos += dir / 2

proc checkFreeze(plr : var Player, movecount : var int, spacepressed : var bool, freezeMoveFloor : int) =
    echo spacepressed, " -> ", movecount, " -> ", movecount div freezeMoveFloor, " -> ", plr.turnsLeftFrozen
    if spacepressed and plr.turnsLeftFrozen == 0:
        plr.turnsLeftFrozen = movecount div freezeMoveFloor
        movecount = 0
        spacepressed = false
    elif plr.turnsLeftFrozen > 0:
        plr.turnsLeftFrozen += -1
    elif spacepressed:
        spacepressed = false

proc movePlayer(plr : var Player, lfkey : var KeyboardKey, numtilesVec : Vector2, mvcount : var int, spacepressed : var bool, freezeMoveFloor : int) : bool =
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
        if plr.turnsLeftFrozen == 0: mvcount += 1 
        checkFreeze plr, mvcount, spacepressed, freezeMoveFloor

    # ----------------------- #
    #       Pathfinding       #
    # ----------------------- #

func getNeighbors(v : Vector2, map : seq[seq[int]]) : seq[Vector2] =
    let v = makevec2(v.y, v.x)
    if v.x < map.len - 1:
        if map[v.x + 1, v.y] != 4:
            result.add makevec2(v.y, v.x + 1)
    if v.x > 0:
        if map[v.x - 1, v.y] != 4:
            result.add makevec2(v.y, v.x - 1)
    if v.y < map[0].len - 1:
        if map[v.x, v.y + 1] != 4:
            result.add makevec2(v.y + 1, v.x)
    if v.y > 0:
        if map[v.x, v.y - 1] != 4:
            result.add makevec2(v.y - 1, v.x)      


func findPathBFS(start, target : Vector2, map : seq[seq[int]]) : seq[Vector2] =
    var fillEdge : Deque[Vector2]
    fillEdge.addLast start
    var traceTable = toTable {start : start}

    while fillEdge.len > 0:
        let curpos = fillEdge.popFirst
        if curpos == target: break
        for c in getNeighbors(curpos, map):
            if c notin traceTable:
                traceTable[c] = curpos
                fillEdge.addLast c
    
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

proc renderEnemies(enemies : seq[Enemy], enemyTex : Texture, tilesize : int) =
    for e in enemies:
        drawTexCenteredFromGrid enemyTex, e.pos, tilesize, WHITE

proc enemyAnim(enemies : var seq[Enemy]) =
    for i in 0..<enemies.len:
        if enemies[i].npos != enemies[i].pos:
            let dir = enemies[i].npos - enemies[i].pos
            enemies[i].pos += dir / 2

proc moveEnemies(enemies : var seq[Enemy], target : Vector2, map : seq[seq[int]]) =
    for i in 0..<enemies.len:
        let x = findPathBFS(round enemies[i].pos, grEqCeil target, map)
        if x.len > 1:
            enemies[i].npos = findPathBFS(round enemies[i].pos, grEqCeil target, map)[1]

    # -------------------------- #
    #       Map Management       #
    # -------------------------- #

func parseMapTile(c : char) : int = 
    if c == '-': return 0
    if c == '#': return 1
    if c == '=': return 2

func parseEmapTile(c : char) : int =
    if c == '-': return 0
    if c == '#': return 1
    if c == '*': return 2

proc renderMap(map : seq[seq[int]], tileTexArray : openArray[Texture], tilesize : int) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            if map[i][j] != 0:
                drawTexFromGrid(tileTexArray[map[i][j] - 1], makevec2(j, i), tilesize)

proc findFromMap(map : seq[seq[int]]) : Vector2 =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            if map[i][j] == 2:
                result = makevec2(j, i)

proc findFromEmap(map : seq[seq[int]]) : (Vector2, seq[Vector2]) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            if map[i][j] != 0:
                if map[i][j] == 1: result[0] = makevec2(j, i)
                if map[i][j] == 2: result[1].add makevec2(j, i)

proc renderTrail(trail : seq[Vector2], trailTex : Texture, tilesize : int) =
    for v in trail:
        drawTexFromGrid trailTex, v, tilesize


    # ----------------------- #
    #       Import Maps       #
    # ----------------------- #

proc loadMap(lvl : int) : seq[seq[int]] =
    var lcount = 0
    for line in lines &"assets/maps/levelmaps/lvl{lvl}.txt":
        result.add @[]
        for c in line:
            result[lcount].add parseMapTile c
        lcount += 1

proc loadEmap(lvl : int) : seq[seq[int]] =
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
    freezeMoveFloor = 4

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 75

let
    playerTex = LoadTexture "assets/sprites/Player.png"
    tileTexArray = [LoadTexture "assets/sprites/BaseTile.png", LoadTexture "assets/sprites/LvlEndPortal.png"]
    trailTex = LoadTexture "assets/sprites/WalkedTile.png"
    enemyTex = LoadTexture "assets/sprites/Enemy.png"


var
    plr = Player(pos : makevec2(0, 0), canMove : true)
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
    timersToReset = @[deathTimer]

(plr.pos, elocs) = findFromEmap emap

for loc in elocs:
    enemies.add(Enemy(pos : loc, npos : loc))

func initLevel(emap : seq[seq[int]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], plr : var Player, mvcount : var int, plrPosSeq : var seq[Vector2], timers : var seq[int]) =
    (plr.pos, enemylocs) = findFromEmap emap
    plr.npos = makevec2(0, 0); plr.canMove = true
    for i in 0..<enemies.len:
        enemies[i].pos = enemylocs[i]
        enemies[i].npos = enemylocs[i]
    plr.turnsLeftFrozen = 0
    mvcount = 0
    plrPosSeq = @[]
    for i in 0..<timers.len: timers[i] = 0


proc loadLevel(lvl : int, map, emap : var seq[seq[int]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], plr : var Player, mvcount : var int, plrPosSeq : var seq[Vector2], timers : var seq[int]) =
    emap = loadEmap lvl; map = loadMap lvl
    initLevel emap, enemies, elocs, plr, movecount, plrPosSeq, timers

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
            initLevel emap, enemies, elocs, plr, movecount, plrPosSeq, timersToReset
    
    # Check if player has reached the end goal
    if plr.npos == lvenloc:
        plr.won = true

    if plr.won:
        plr.canMove = false
        if winTimer == 10:
            plr.won = false
            currentlv += 0
            loadLevel currentlv, map, emap, enemies, elocs, plr, movecount, plrPosSeq, timersToReset
            winTimer = 0
        else: winTimer += 1
    
    # Cache buttons pressed
    if IsKeyDown(KEY_SPACE):
        spacecache = true
    
    # Move and Animate Player and Enemies
    if plr.canMove:
        if movePlayer(plr, lastframekey, numTilesVec, movecount, spacecache, freezeMoveFloor) and plr.turnsLeftFrozen == 0:
            moveEnemies enemies, plr.pos, map
    for e in enemies:
        if round(e.pos) == plr.pos:
            initLevel emap, enemies, elocs, plr, movecount, plrPosSeq, timersToReset
    playerAnim plr
    enemyAnim enemies


    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()
    renderMap map, tileTexArray, tilesize
    renderTrail plrPosSeq, trailTex, tilesize
    drawTexCenteredFromGrid playerTex, plr.pos, tilesize, WHITE
    renderEnemies enemies, enemyTex, tilesize
    EndDrawing()

for tex in tileTexArray:
    UnloadTexture tex
UnloadTexture playertex, trailTex
CloseWindow()