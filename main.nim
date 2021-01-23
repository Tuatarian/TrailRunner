import raylib, os, lenientops, rayutils, math, strformat, deques, sets, tables

type
    Player = object
        pos : Vector2
        npos : Vector2
        canMove : bool
        dead : bool
        won : bool
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

proc movePlayer(plr : var Player, lfkey : KeyboardKey, numtilesVec : VEctor2) : (KeyboardKey, bool) =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            return (KEY_LEFT, false)
        plr.npos.x += -1
        return (KEY_LEFT, true)
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            return (KEY_RIGHT, false)
        plr.npos.x += 1
        return (KEY_RIGHT, true)
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            return (KEY_UP, false)
        plr.npos.y += -1
        return (KEY_UP, true)
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            return (KEY_DOWN, false)
        plr.npos.y += 1
        return (KEY_DOWN, true)
    plr.npos = clamp(plr.npos, numTilesVec - 1)
    plr.npos = anticlamp(plr.npos, makevec2(0, 0))

func playerAnim(plr : var Player) =
    if plr.pos != plr.npos:
        let dir = plr.npos - plr.pos
        plr.pos += dir / 2

    # ----------------------- #
    #       Pathfinding       #
    # ----------------------- #

func getNeighbors(map : seq[seq[int]], pos : Vector2) : seq[Vector2] =
    if pos.x < float32 map.len - 1:
        if map[pos.y, pos.x + 1] != 4:
            result.add(makevec2(pos.x + 1, pos.y))
    if pos.x > 0:
        if map[pos.y, pos.x - 1] != 4:
            result.add(makevec2(pos.x - 1, pos.y))
    if pos.y < float32 map[1].len - 1:
        if map[pos.y + 1, pos.x] != 4:
            result.add(makevec2(pos.x, pos.y + 1))
    if pos.y > 0:
        if map[pos.y - 1, pos.x] != 4:
            result.add(makevec2(pos.x, pos.y - 1))



proc findPathBfs(start, target : Vector2, map : seq[seq[int]]) : seq[Vector2] =
    var fillEdge : Deque[Vector2]
    fillEdge.addFirst start
    var seen = {start : start}.toTable

    while fillEdge.len > 0:
        var curpos : Vector2 = fillEdge.popFirst
        for v in getNeighbors(map, curpos):
            if v notin seen:
                fillEdge.addLast v
                seen[v] = curpos
                echo curpos, fillEdge.len
        if curpos == target: break
    
    var curpos = target
    var antipath : seq[Vector2]
    while curpos != start:
        antipath.add curpos
        curpos = seen[curpos]
    for i in 1..antipath.len:
        result.add antipath[^i]
    echo result


    # ---------------------------- #
    #       Enemy Management       #
    # ---------------------------- #

proc renderEnemies(enemies : seq[Enemy], enemyTex : Texture, tilesize : int) =
    for e in enemies:
        drawTexCenteredFromGrid enemyTex, e.pos, tilesize, WHITE

proc enemyAnim(enem : var Enemy) =
    echo "out"
    if enem.npos != enem.pos:
        echo "anm"
        let dir = enem.npos - enem.pos
        enem.pos += dir / 2

proc moveEnemies(enemies : var seq[Enemy], plr : Player, map : seq[seq[int]]) =
    for i in 0..<enemies.len:
        echo "mv"
        enemies[i].npos = findPathBfs(roundDown enemies[i].pos, plr.npos, map)[0]
        enemies[i].pos = enemies[i].npos


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
    lfplrpos : Vector2

(plr.pos, elocs) = findFromEmap emap

for loc in elocs:
    enemies.add(Enemy(pos : loc))

func initLevel(emap : seq[seq[int]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], plr : var Player) =
    (plr.pos, enemylocs) = findFromEmap emap
    plr.npos = makevec2(0, 0); plr.canMove = true
    for i in 0..<enemies.len:
        enemies[i].pos = enemylocs[i]


proc loadLevel(lvl : int, map, emap : var seq[seq[int]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], plr : var Player) =
    emap = loadEmap lvl; map = loadMap lvl
    initLevel emap, enemies, enemylocs, plr

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
            initLevel emap, enemies, elocs, plr
            plrPosSeq = @[]
            deathTimer = 0
        else: deathTimer += 1
    
    # Check if player has reached the end goal
    if plr.npos == lvenloc:
        plr.won = true

    if plr.won:
        plr.canMove = false
        if winTimer == 10:
            plr.won = false
            currentlv += 0
            loadLevel currentlv, map, emap, enemies, elocs, plr
            winTimer = 0
        else: winTimer += 1
    

    # Move and Animate Player and Enemies
    var moved : bool
    if plr.canMove: 
        (lastframekey, moved) = movePlayer(plr, lastframekey, numTilesVec)
        if moved: moveEnemies enemies, plr, map
    playerAnim plr


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