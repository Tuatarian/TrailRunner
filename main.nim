import raylib, lenientops, rayutils, math, strformat, deques, sets, tables, random, sequtils, strutils, algorithm

template BGREY() : auto = makecolor("282828", 255)
template OFFWHITE() : auto = makecolor(235, 235, 235)

randomize()

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
        if map[v.x + 1, v.y] != WALL and map[v.x + 1, v.y] != GOAL:
            result.add makevec2(v.y, v.x + 1)
    if v.x > 0:
        if map[v.x - 1, v.y] != WALL and map[v.x - 1, v.y] != GOAL:
            result.add makevec2(v.y, v.x - 1)
    if v.y < map[0].len - 1:
        if map[v.x, v.y + 1] != WALL and map[v.x, v.y + 1] != GOAL:
            result.add makevec2(v.y + 1, v.x)
    if v.y > 0:
        if map[v.x, v.y - 1] != WALL and map[v.x, v.y - 1] != GOAL:
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
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL and map[invert nposcache] != GOAL:
            result = nposcache
        else: weight += 25
    if weight < 50:
        var nposcache = start + makevec2(0, 1)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL and map[invert nposcache] != GOAL:
            result = nposcache
        else: weight += 25
    if weight < 75:
        var nposcache = start + makevec2(1, 0)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL and map[invert nposcache] != GOAL:
            result = nposcache
        else: weight += 25
    if weight <= 100:
        var nposcache = start + makevec2(-1, 0)
        if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL and map[invert nposcache] != GOAL:
            result = nposcache
        else: result = start

proc enemyAnim(enemies : var seq[Enemy]) =
    for i in 0..<enemies.len:
        if enemies[i].npos != enemies[i].pos:
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
                if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL and map[invert nposcache] != GOAL:
                    enemies[i].npos = nposcache
                else: weight += 5
            elif weight < 99:
                let nposcache = enemies[i].pos + invert dir
                if nposcache == anticlamp(clamp(nposcache, makevec2(map[1].len - 1, map.len - 1)), makevec2(0, 0)) and map[invert nposcache] != WALL and map[invert nposcache] != GOAL:
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
                    enemies[i].npos = map.selectRandomDir(enemies[i].pos)
                
        enemies[i].npos = round enemies[i].npos

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

func getWallNeighbors*[T](map : seq[seq[T]], y, x : int) : string =
    if y > 0:
        if map[y - 1, x] == WALL: result &= 0
        else: result &= 1
    else: result &= 1
    if x < map[0].len - 1:
        if map[y, x + 1] == WALL: result &= 0
        else: result &= 1
    else: result &= 1
    if y < map.len - 1:
        if map[y + 1, x] == WALL: result &= 0
        else: result &= 1
    else: result &= 1
    if x > 0:
        if map[y, x - 1] == WALL: result &= 0
        else: result &= 1
    else: result &= 1

proc renderMap(map : seq[seq[Tile]], tileTexTable : Table[Tile, Texture], wallTexTable : Table[string, Texture], tilesize : int) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            var liveNeighborsBin = map.getWallNeighbors(i, j)
            if map[i, j] != WALL:
                drawTexFromGrid(tileTexTable[map[i, j]], makevec2(j, i), tilesize)
            else:
                drawTexFromGrid(wallTexTable[liveNeighborsBin], makevec2(j, i), tilesize)

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

proc genEmap(en1chance : int, gaussMu : float = 5) : seq[seq[ETile]] =
    result = genSeqSeq(8, 13, NONE)
    let numEnems = int gauss(5, 1)
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
    result[0, 0] = NONE

    # ----------------------- #
    #       Import Maps       #
    # ----------------------- #

proc genMap(iters, wallaciousness : int, goalLoc : Vector2 = makevec2(-1, -1)) : seq[seq[Tile]] =
    result = cellAutomaton(iters, wallaciousness)
    if goalLoc.x == -1:
        result[rand(result.len - 1), rand(result[0].len - 1)] = GOAL
    else: result[invert goalLoc] = GOAL
    result[0, 0] = GRND

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
    vol = 0.75

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 60
InitAudioDevice()
SetMasterVolume vol

let
    playerTex = LoadTexture "assets/sprites/Player.png"
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", GOAL : LoadTexture "assets/sprites/LvlEndPortal.png"}
    trailTex = LoadTexture "assets/sprites/WalkedTile.png"
    enemyTexArray = [LoadTexture "assets/sprites/Enemy1.png", LoadTexture "assets/sprites/Enemy2.png"]
    moveOgg = LoadSound "assets/sounds/Move.ogg"
    winOgg = LoadSound "assets/sounds/GenericNotify.ogg"
    loseOgg = LoadSound "assets/sounds/Error.ogg"
    genOgg = LoadSound "assets/sounds/Confirmation.ogg"
    cogTex = LoadTexture "assets/sprites/settingsicon.png"

genOgg.SetSoundVolume 1.85
moveOgg.SetSoundVolume 0.6

var
    plr = Player(canMove : true)
    lastframekey = KEY_F
    plrPosSeq : seq[Vector2]
    currentlv = 1
    deathTimer : int
    winTimer : int
    map = genMap(20, 30)
    emap = genEmap(80)
    elocs : seq[Vector2]
    lvenloc = findFromMap map
    enemies : seq[Enemy]
    spacecache : bool
    spacecache2 : bool
    altcache : bool
    genTimer : int
    rcache, rcache2 : bool
    rcount : int
    etypes : seq[int]
    timersToReset = @[deathTimer, genTimer]
    score : int
    interscore : int
    musicArr = [LoadMusicStream "assets/sounds/music/NeonHighway.mp3", LoadMusicStream "assets/sounds/music/SnowyStreets.mp3", LoadMusicStream "assets/sounds/music/CrystalClear.mp3", LoadMusicStream "assets/sounds/music/RhythmOfTime.mp3", LoadMusicStream "assets/sounds/music/Cavalier.mp3", LoadMusicStream "assets/sounds/music/Athena.mp3", LoadMusicStream "assets/sounds/music/Nimbus.mp3", LoadMusicStream "assets/sounds/music/No Strings Attached.mp3", LoadMusicStream "assets/sounds/music/Kanundrum.mp3"]
    lastSong = -1
    wallTexTable : Table[string, Texture]
    screenId = 0
    buttonColors = [OFFWHITE, OFFWHITE, OFFWHITE, OFFWHITE, OFFWHITE]
    hiscores : seq[int]
    escache, escache2 : bool
    tutstage : int

for i in 0..<16:
    wallTexTable[toBin(i, 4)] = LoadTexture &"assets/sprites/walls/{toBin(i, 4)}.png"

musicArr.iterIt(SetMusicVolume(it, 0.85))
musicArr[0].SetMusicVolume 1
musicArr[2].SetMusicVolume 0.35
musicArr[3].SetMusicVolume 3.5
musicArr[4].SetMusicVolume 3.5
musicArr[6].SetMusicVolume 0.70
musicArr[7].SetMusicVolume 0.70

(elocs, etypes) = findFromEmap emap

for i, loc in elocs.pairs:
    enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))


proc initLevel(emap : var seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], etypes : var seq[int], plr : var Player, lvenloc : Vector2, timers : var seq[int]) =
    map = genMap(20, 30)
    emap = genEmap(80)
    (enemylocs, etypes) = findFromEmap emap
    plr.pos = makevec2(0, 0); plr.npos = makevec2(0, 0); plr.canMove = true
    enemies = @[]
    for i, loc in enemylocs.pairs:
        enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))
    for i in 0..<enemies.len:
        enemies[i].pos = enemylocs[i]
        enemies[i].npos = enemylocs[i]
    plrPosSeq = @[]
    for i in 0..<timers.len: timers[i] = 0


proc loadLevel(lvl : int, map : var seq[seq[Tile]], emap : var seq[seq[Etile]], enemies : var seq[Enemy], enemylocs : var seq[Vector2], enemtypes : var seq[int], plr : var Player, timers : var seq[int], lvenloc : var Vector2) =
    initLevel(emap, enemies, enemylocs, enemtypes, plr, lvenloc, timers)
    lvenloc = findFromMap map

hiscores = readFile("hiscores.txt").splitLines().toSeq.mapIt(parseInt it).sorted(Descending)
SetExitKey KEY_PAGE_UP

while not WindowShouldClose():
    ClearBackground BGREY

    musicArr.iterIt(UpdateMusicStream(it))

    let nimp = not musicArr.mapIt(it.IsMusicPlaying()).foldl(a or b)

    if IsKeyDown(KEY_SPACE):
        if not spacecache2:
            (spacecache, spacecache2) = (true, true)
    else: spacecache2 = false

    if nimp or spacecache == true:
        spacecache = false
        musicArr.iterIt(it.StopMusicStream)
        let inx = rand(musicArr.len - 1)
        echo inx
        PlayMusicStream(musicArr[inx])

    if screenId == 0:
        if GetMousePosition() in makerect(makevec2(52, 313), makevec2(379, 313), makevec2(379, 451), makevec2(52, 451)):
            if IsMouseButtonReleased(MOUSE_LEFT_BUTTON): screenId = 3
            buttonColors[0] = WHITE
        else: buttonColors[0] = OFFWHITE
        if GetMousePosition() in makerect(makevec2(424, 231), makevec2(828, 231), makevec2(828, 535), makevec2(424, 535)):
            if IsMouseButtonReleased(MOUSE_LEFT_BUTTON):
                screenId = 1
            buttonColors[1] = WHITE
        else: buttonColors[1] = OFFWHITE 
        if GetMousePosition() in makerect(makevec2(863, 313), makevec2(1192, 313), makevec2(1192, 451), makevec2(863, 451)):
            if IsMouseButtonReleased(MOUSE_LEFT_BUTTON): screenId = 2
            buttonColors[2] = WHITE
        else: buttonColors[2] = OFFWHITE
        # if GetMousePosition() in makerect(1104, 17, 128, 128):
        #     if IsMouseButtonReleased(MOUSE_LEFT_BUTTON):
        #         screenId = 3
        #     buttonColors[4] = WHITE
        # else: buttonColors[4] = OFFWHITE

        BeginDrawing()
        drawTriangleFan makevec2(52, 313), makevec2(52, 451), makevec2(379, 451), makevec2(379, 313), buttonColors[0]
        DrawText "Tutorial", 69, 352, 70, BGREY
        drawTriangleFan makevec2(424, 231), makevec2(828, 231), makevec2(828, 535), makevec2(424, 535), buttonColors[1]
        drawTriangleFan makevec2(554, 292), makevec2(692, 385), makevec2(554, 475), BGREY
        drawTriangleFan makevec2(863, 313), makevec2(1192, 313), makevec2(1192, 451), makevec2(863, 451), buttonColors[2]
        DrawText "Scores", 903, 352, 70, BGREY
        # DrawTexture cogTex, 1104, 17, buttonColors[4]
        EndDrawing()

        if escache:
            escache = false
    elif screenId == 3:
        if tutstage == 0:
            emap = genSeqSeq(8, 13, NONE)
            map = genSeqSeq(8, 13, GRND)
            map[invert lvenloc] = GOAL
        if tutstage == 1:
            map = loadMap 1
            lvenloc = findFromMap map
        if tutstage >= 2:
            if IsKeyDown(KEY_R):
                if not rcache2:
                    rcache = true
                    rcache2 = true
            else: rcache2 = false

            if rcache:
                if not IsSoundPlaying genOgg:
                    PlaySound genOgg
                if genTimer >= 3:
                    genTimer = 0
                    map = genMap(25, 30, lvenloc)
                    rcache = false
                    plr.canMove = true
                else: 
                    gentimer += 1
                    map = genMap(25, 30, lvenloc)
        # Check if player has reached the end goal
        if plr.npos == lvenloc:
            plr.won = true

        if plr.won:
            deathTimer = 0
            plr.canMove = false
            if winTimer == 7:
                tutstage += 1
                if tutstage == 1:
                    map = loadMap 1
                    lvenloc = findFromMap map
                elif tutstage == 2:
                    map = genMap(25, 30)
                    lvenloc = findFromMap map
                elif tutstage == 3:
                    map = genMap(25, 30)
                    lvenloc = findFromMap map
                    emap = genEmap(80, 4)
                    (elocs, etypes) = findFromEmap emap
                    plr.pos = makevec2(0, 0); plr.npos = makevec2(0, 0); plr.canMove = true
                    enemies = @[]
                    for i, loc in elocs.pairs:
                        enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))
                    for i in 0..<enemies.len:
                        enemies[i].pos = elocs[i]
                        enemies[i].npos = elocs[i]
                elif tutstage == 4:
                    escache = true
                PlaySound winOgg
                plr.pos = makevec2(0, 0)
                plr.npos = makevec2(0, 0)
                plr.canMove = true
                plr.won = false
                winTimer = 0
            else: winTimer += 1

        if not plr.canMove and plr.dead:
            if deathTimer == 5:
                PlaySound loseOgg
                map = genMap(25, 30)
                lvenloc = findFromMap map
                emap = genEmap(80, 4)
                plr.won = false
                plr.dead = false
                plr.canMove = true
                (elocs, etypes) = findFromEmap emap
                plr.pos = makevec2(0, 0); plr.npos = makevec2(0, 0); plr.canMove = true
                enemies = @[]
                for i, loc in elocs.pairs:
                    enemies.add(Enemy(pos : loc, npos : loc, typeId : etypes[i]))
                for i in 0..<enemies.len:
                    enemies[i].pos = elocs[i]
                    enemies[i].npos = elocs[i]
                deathTimer = 0
            deathTimer += 1

        if enemies.mapIt(it.pos == plr.pos).foldl(a or b) and tutstage == 3:
            plr.canMove = false
            plr.dead = true

        # Move and Animate Player and Enemies
        if plr.canMove:
            if movePlayer(plr, lastframekey, numTilesVec, map):
                PlaySound moveOgg
                moveEnemT1 enemies, plr, map 
                moveEnemT2 enemies, plr, map 
        playerAnim plr
        enemyAnim enemies

        if escache:
            screenId = 0
            currentlv = 0
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, timersToReset, lvenloc
            (score, interscore) = (0, 0)
            deathTimer = 0
            rcount = 0
            tutstage = 0
            rcache = false

        BeginDrawing()
        renderMap map, tileTexTable, wallTexTable, tilesize
        # renderTrail plrPosSeq, trailTex, tilesize
        drawTexCenteredFromGrid playerTex, plr.pos, tilesize, WHITE
        if tutstage == 3: renderEnemies enemies, enemyTexArray, tilesize
        if tutstage == 0:
            drawTextCenteredX "Arrow keys to move", screenWidth div 2 + 3, 53, 80, RED
            drawTextCenteredX "Arrow keys to move", screenWidth div 2, 50, 80, WHITE
        if tutstage == 1:
            drawTextCenteredX "Those are walls", screenWidth div 2 + 3, 53, 80, RED
            drawTextCenteredX "Those are walls", screenWidth div 2, 50, 80, WHITE
        if tutstage == 2:
            drawTextCenteredX "Press R to swap level", screenWidth div 2 + 3, 53, 80, RED
            drawTextCenteredX "Press R to swap level", screenWidth div 2, 50, 80, WHITE
        if tutstage == 3:
            drawTextCenteredX "Don't run into an enemy", screenWidth div 2 + 3, 53, 80, RED
            drawTextCenteredX "Don't run into an enemy", screenWidth div 2, 50, 80, WHITE           
        EndDrawing()
    elif screenId == 2:
        if GetMousePosition().in(makevec2(143, 145), makevec2(56, 90), makevec2(143, 38)):
            if IsMouseButtonReleased(MOUSE_LEFT_BUTTON): screenId = 0
            buttonColors[3] = WHITE
        else: buttonColors[3] = OFFWHITE
        if escache: screenId = 0; escache = false

        BeginDrawing()
        drawTextCenteredX "High Scores", screenWidth div 2 + 3, 53, 80, RED
        drawTextCenteredX "High Scores", screenWidth div 2, 50, 80, WHITE

        drawTextCenteredX "1.", screenWidth div 14 + 3, 213, 60, RED
        drawTextCenteredX "1.", screenWidth div 14, 210, 60, WHITE
        drawTextCenteredX $hiscores[0], screenWidth div 2 + 3, 213, 60, RED
        drawTextCenteredX $hiscores[0], screenWidth div 2, 210, 60, WHITE

        drawTextCenteredX "2.", screenWidth div 14 + 3, 313, 60, RED
        drawTextCenteredX "2.", screenWidth div 14, 310, 60, WHITE
        drawTextCenteredX $hiscores[1], screenWidth div 2 + 3, 313, 60, RED
        drawTextCenteredX $hiscores[1], screenWidth div 2, 310, 60, WHITE

        drawTextCenteredX "3.", screenWidth div 14 + 3, 413, 60, RED
        drawTextCenteredX "3.", screenWidth div 14, 410, 60, WHITE
        drawTextCenteredX $hiscores[2], screenWidth div 2 + 3, 413, 60, RED
        drawTextCenteredX $hiscores[2], screenWidth div 2, 410, 60, WHITE

        drawTextCenteredX "4.", screenWidth div 14 + 3, 513, 60, RED
        drawTextCenteredX "4.", screenWidth div 14, 510, 60, WHITE
        drawTextCenteredX $hiscores[3], screenWidth div 2 + 3, 513, 60, RED
        drawTextCenteredX $hiscores[3], screenWidth div 2, 510, 60, WHITE

        drawTextCenteredX "5.", screenWidth div 14 + 3, 613, 60, RED
        drawTextCenteredX "5.", screenWidth div 14, 610, 60, WHITE
        drawTextCenteredX $hiscores[4], screenWidth div 2 + 3, 613, 60, RED
        drawTextCenteredX $hiscores[4], screenWidth div 2, 610, 60, WHITE

        drawTriangleFan(makevec2(56, 90), makevec2(145, 145), makevec2(145, 38), buttonColors[3])

        EndDrawing()
    elif screenId == 1:
        if not plr.canMove and plr.dead:
            if deathTimer == 5:
                PlaySound loseOgg
                currentlv = 0
                if score > hiscores[4]:
                    hiscores[4] = score; hiscores = hiscores.sorted(Descending)
                    writeFile("hiscores.txt", hiscores.mapIt($it).foldl(&"{$a}\n{$b}"))
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
                plr.won = false
                currentlv += 1
                loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, timersToReset, lvenloc
                winTimer = 0
                rcount = 0
            else: winTimer += 1
        
        # Cache buttons pressed
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
        if enemies.mapIt(it.pos == plr.pos).foldl(a or b):
            plr.canMove = false
            plr.dead = true
        playerAnim plr
        enemyAnim enemies

        # ---------------- #
        #       DRAW       #
        # ---------------- #

        BeginDrawing()
        renderMap map, tileTexTable, wallTexTable, tilesize
        # renderTrail plrPosSeq, trailTex, tilesize
        drawTexCenteredFromGrid playerTex, plr.pos, tilesize, WHITE
        renderEnemies enemies, enemyTexArray, tilesize
        DrawText $interscore, screenWidth - 118, 42, 40, RED
        DrawText $interscore, screenWidth - 120, 40, 40, WHITE
        EndDrawing()

        if escache:
            currentlv = 0
            if score > hiscores[4]:
                hiscores[4] = score; hiscores = hiscores.sorted(Descending)
            loadLevel currentlv, map, emap, enemies, elocs, etypes, plr, timersToReset, lvenloc
            (score, interscore) = (0, 0)
            deathTimer = 0
            rcount = 0
            escache = false
            screenId = 0
    if IsKeyDown(KEY_ESCAPE):
        if not escache2:
            (escache, escache2) = (true, true)
    else: escache2= false

for t in tileTexTable.values:
    UnloadTexture t
for t in wallTexTable.values:
    UnloadTexture t
UnloadTexture playertex, trailTex
UnloadMusicStream musicArr
CloseAudioDevice()
UnloadSound loseOgg, moveOgg, winOgg, genOgg
CloseWindow()