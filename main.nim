import raylib, os, lenientops, rayutils, math, strformat

type
    Player = object
        pos : Vector2
        npos : Vector2
        sprite : Texture2D
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

proc movePlayer(plr : var Player, lfkey : KeyboardKey, numtilesVec : VEctor2) : KeyboardKey =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            return KEY_LEFT
        plr.npos.x += -1
        return KEY_LEFT
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            return KEY_RIGHT
        plr.npos.x += 1
        return KEY_RIGHT
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            return KEY_UP
        plr.npos.y += -1
        return KEY_UP
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            return KEY_DOWN
        plr.npos.y += 1
        return KEY_DOWN
    plr.npos = clamp(plr.npos, numTilesVec - 1)
    plr.npos = anticlamp(plr.npos, makevec2(0, 0))

func playerAnim(plr : var Player) =
    if plr.pos != plr.npos:
        let dir = plr.npos - plr.pos
        plr.pos += dir / 2

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
    for v in trail[0..^1]:
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
    playertex = LoadTexture "assets/sprites/Player.png"
    tileTexArray = [LoadTexture "assets/sprites/BaseTile.png", LoadTexture "assets/sprites/LvlEndPortal.png"]
    trailTex = LoadTexture "assets/sprites/WalkedTile.png"


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

(plr.pos, elocs) = findFromEmap emap

func initLevel(emap : seq[seq[int]], enemylocs : var seq[Vector2], plr : var Player) =
    (plr.pos, enemylocs) = findFromEmap emap
    plr.npos = makevec2(0, 0); plr.canMove = true

proc loadLevel(lvl : int, map, emap : var seq[seq[int]], enemylocs : var seq[Vector2], plr : var Player) =
    emap = loadEmap lvl; map = loadMap lvl
    initLevel emap, enemylocs, plr

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
            initLevel emap, elocs, plr
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
            loadLevel currentlv, map, emap, elocs, plr
            winTimer = 0
        else: winTimer += 1
        


    # Move and Animate Player
    if plr.canMove: lastframekey = movePlayer(plr, lastframekey, numTilesVec)
    playerAnim plr

    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()
    renderMap map, tileTexArray, tilesize
    renderTrail plrPosSeq, trailTex, tilesize 
    drawTexCenteredFromGrid playertex, plr.pos, tilesize, WHITE
    EndDrawing()

for tex in tileTexArray:
    UnloadTexture tex
UnloadTexture playertex, trailTex
CloseWindow()