import raylib, lenientops, rayutils, math, strformat, deques, sets, tables, random, sugar, sequtils

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


proc movePlayer(plr : var Player, lfkey : var KeyboardKey, numtilesVec : Vector2, map : seq[seq[Tile]]) : bool =
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

    # ----------------------- #
    #       Pathfinding       #
    # ----------------------- #

func getNeighborPos[T](map : seq[seq[T]], v : Vector2) : seq[Vector2] =
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


proc findPathBFS(start, target : Vector2, map : seq[seq[Tile]]) : seq[Vector2] =
    var fillEdge : Deque[Vector2]
    fillEdge.addLast start
    var traceTable = toTable {start : start}

    while fillEdge.len > 0:
        let curpos = fillEdge.popFirst
        if curpos == target: break
        for c in map.getNeighborPos(curpos):
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

proc selectRandomDir[T](map : seq[seq[T]], start : Vector2) : Vector2 =
    var weight = rand(100)
    if weight < 25:
        var nposcache = start + makevec2(0, -1)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
            result = nposcache
        else: weight += 25
    if weight < 50:
        var nposcache = start + makevec2(0, 1)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
            result = nposcache
        else: weight += 25
    if weight < 75:
        var nposcache = start + makevec2(1, 0)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
            result = nposcache
        else: weight += 25
    if weight <= 100:
        var nposcache = start + makevec2(-1, 0)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL:
            result = nposcache
        else: result = start

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

proc moveEnemT1(enemies : var seq[Enemy], plr : Player, map : seq[seq[Tile]]) =
    let target = plr.pos
    let ntarget = plr.npos
    for i in 0..<enemies.len:
        let tarpath = findPathBFS(round enemies[i].pos, grEqCeil target, map)
        if tarpath.len > 1:
            let dir = tarpath[1] - enemies[i].pos
            var weight : int
            if rand(3) == 0: weight = rand(80..100)
            else: weight = rand(100)
            if weight < 84: enemies[i].npos = tarpath[1]
            elif weight < 94:
                let ntarpath = findPathBFS(round enemies[i].pos, grEqCeil ntarget, map)
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
        else:
            enemies[i].npos = map.selectRandomDir(enemies[i].pos)

proc moveEnemT2(enemies : var seq[Enemy], plr : Player, map : seq[seq[Tile]]) =
    let target = plr.pos
    for i in 0..<enemies.len:
        let tarpath = findPathBFS(round enemies[i].pos, grEqCeil target, map)
        if enemies[i].typeId == 1:
            if tarpath.len > 1:
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
            else:
                enemies[i].npos = map.selectRandomDir(enemies[i].pos)

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

proc findFromEmap(emap : seq[seq[Etile]]) : (seq[Vector2], seq[int]) =
    for i in 0..<emap.len:
        for j in 0..<emap[i].len:
            if emap[i, j] != NONE:
                if emap[i, j] == EN1SPWN: 
                    result[0].add makevec2(j, i)
                    result[1].add 0
                if emap[i, j] == EN2SPWN:
                    result[0].add makevec2(j, i)
                    result[1].add 1

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
                if (i, j) == (0, 0):
                    result[j, i] = GRND

proc genEmap(en1chance : int, ) : seq[seq[ETile]] =
    result = genSeqSeq(8, 13, NONE)
    let numEnems = int gauss(5, 1)
    debugEcho numEnems
    var elocs : seq[Vector2]
    for i in 0..<numEnems:
        let weight = rand(100)
        var pos = makevec2(rand 7, rand 12)
        while pos in elocs and pos != makevec2(0, 0):
            pos = makevec2(rand 7, rand 12)
        if i == 0:
            result[pos] = EN2SPWN
        elif i == numEnems - 1:
            result[pos] = EN2SPWN
        elif weight < en1chance:
            result[pos] = EN1SPWN
        else:
            result[pos] = EN2SPWN

    # ----------------------- #
    #       Import Maps       #
    # ----------------------- #

proc genMap(iters, wallaciousness : int, goalLoc : Vector2) : seq[seq[Tile]] =
    result = cellAutomaton(iters, wallaciousness)
    if goalLoc.x == -1:
        result[rand(result.len - 1), rand(result[0].len - 1)] = GOAL
    else: result[invert goalLoc] = GOAL

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
    vol = 1.5

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 60
InitAudioDevice()
SetMasterVolume vol

let
    playerTex = LoadTexture "assets/sprites/Player.png"
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", GOAL : LoadTexture "assets/sprites/LvlEndPortal.png", WALL : LoadTexture "assets/sprites/WallTile.png"}
    trailTex = LoadTexture "assets/sprites/WalkedTile.png"
    enemyTexArray = [LoadTexture "assets/sprites/Enemy1.png", LoadTexture "assets/sprites/Enemy2.png"]
    moveOgg = LoadSound "assets/sounds/Move.ogg"
    winOgg = LoadSound "assets/sounds/GenericNotify.ogg"
    loseOgg = LoadSound "assets/sounds/Error.ogg"
    genOgg = LoadSound "assets/sounds/Confirmation.ogg"

genOgg.SetSoundVolume 1.5

var
    plr = Player(canMove : true)
    lastframekey = KEY_F
    plrPosSeq : seq[Vector2]
    currentlv = 1
    deathTimer : int
    winTimer : int
    map = genMap(20, 30, makevec2(-1, -1))
    emap = genEmap(80)
    elocs : seq[Vector2]
    lvenloc = findFromMap map
    enemies : seq[Enemy]
    spacecache : bool
    altcache : bool
    genTimer : int
    rcache : bool
    rcache2 : bool
    rcount : int
    etypes : seq[int]
    timersToReset = @[deathTimer, genTimer]
    score : int
    interscore : int
    musicArr = [LoadMusicStream "assets/sounds/music/NeonHighway.mp3"]

for m in musicArr:
    m.SetMusicVolume 1

(elocs, etypes) = findFromEmap emap

for i, loc in elocs.pairs:
    enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))


proc initLevel(emap : var seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], etypes : var seq[int], plr : var Player, lvenloc : Vector2, timers : var seq[int]) =
    map = genMap(20, 30, makevec2(-1, -1))
    emap = genEmap(80)
    (enemylocs, etypes) = findFromEmap emap
    plr.pos = makevec2(0, 0); plr.npos = makevec2(0, 0); plr.canMove = true
    enemies = @[]
    for i, loc in enemylocs.pairs:
        enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))
    for i in 0..<enemies.len:
        enemies[i].pos = enemylocs[i]
        enemies[i].npos = enemylocs[i]
    plr.turnsLeftFrozen = 0
    plrPosSeq = @[]
    for i in 0..<timers.len: timers[i] = 0


proc loadLevel(lvl : int, map : var seq[seq[Tile]], emap : var seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], enemtypes : var seq[int], plr : var Player, timers : var seq[int], lvenloc : var Vector2) =
    initLevel(emap, enemies, enemylocs, enemtypes, plr, lvenloc, timers)
    lvenloc = findFromMap map
while not WindowShouldClose():
    ClearBackground RAYWHITE
    var imp : bool
    for m in musicArr:
        if IsMusicPlaying m: imp = true
    
    if not imp:
        echo "not imp"
        echo rand(musicArr.len - 1)
        PlayMusicStream(musicArr[rand(musicArr.len - 1)])

    if plr.npos notin plrPosSeq:
        plrPosSeq.add plr.npos
    
    if not plr.canMove and plr.dead:
        if deathTimer == 5:
            PlaySound loseOgg
            score = interscore
            echo &"Run ended! Score : {score} | {currentlv}"
            currentlv = 0
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, timersToReset, lvenloc
            (score, interscore) = (0, 0)
            deathTimer = 0
            rcount = 0
        deathTimer += 1
    
    # Check if player has reached the end goal
    if plr.npos == lvenloc:
        plr.won = true

    if plr.won:
        deathTimer = 0
        plr.canMove = false
        if winTimer == 7:
            PlaySound winOgg
            score = interscore + 1000
            interscore = score
            echo &"Wcore : {score}"
            plr.won = false
            currentlv += 1
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, timersToReset, lvenloc
            winTimer = 0
            rcount = 0
        else: winTimer += 1
    
    # Cache buttons pressed
    if IsKeyDown(KEY_SPACE):
        spacecache = true
    if IsKeyDown(KEY_LEFT_ALT) or IsKeyDown(KEY_RIGHT_ALT):
        altcache = true
    if IsKeyDown(KEY_R):
        if not rcache2:
            rcache = true
            rcache2 = true
    else: rcache2 = false
    
    if rcache:
        if not IsSoundPlaying genOgg:
            PlaySound genOgg
        if genTimer >= 3:
            rcount += 1
            let rscore = int sigmoid(rcount, a = 2, k = -1, h = -1/7) * 500
            interscore = int(score - rscore)
            echo &"Score : {interscore}"
            genTimer = 0
            map = genMap(25, 30, lvenloc)
            rcache = false
            plr.canMove = true
        else: 
            gentimer += 1
            map = genMap(25, 30, lvenloc)

    # Move and Animate Player and Enemies
    if plr.canMove:
        if movePlayer(plr, lastframekey, numTilesVec, map):
            PlaySound moveOgg
            moveEnemT1 enemies, plr, map 
            moveEnemT2 enemies, plr, map 
    for i in 0..<enemies.len:
        if enemies[i].pos == plr.pos:
            plr.canMove = false
            plr.dead = true
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
CloseAudioDevice()
UnloadSound loseOgg, moveOgg, winOgg, genOgg
CloseWindow()