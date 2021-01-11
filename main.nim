import raylib, os, lenientops, rayutils, math
type
    Player = object
        pos : Vector2
        sprite : Texture2D

    # --------------------------- #
    #       Grid Management       #
    # --------------------------- #

func screenToGrid(screencoord : Vector2) : Vector2 =
    return makevec2(grEqCeil screencoord.x, grEqCeil screencoord.y)

func screenToGrid(screencoord : float | int | float32, numXTiles : int | float32) : float | int | float32 =
    return grEqCeil screencoord / numXTiles

proc drawTexFromGrid(tex : Texture, pos : Vector2, tilesize : int) =
    DrawTexture(tex, int pos.x * tilesize, int pos.y * tilesize, WHITE)

proc drawTexCenteredFromGrid(tex : Texture, pos : Vector2, tilesize : int, tint : Color) =
    DrawTexture(tex, int pos.x + (tilesize - tex.width) / 2, int pos.y + (tilesize - tex.height) / 2, tint)

    # ----------------------------- #
    #       Player Management       #
    # ----------------------------- #

proc movePlayer(plr : Player) : Vector2 =
    if IsKeyDown(KEY_A or KEY_LEFT):
        result.x += -1.float32
    elif IsKeyDown(KEY_D or KEY_RIGHT):
        result.x += 1.float32
    elif IsKeyDown(KEY_W or KEY_UP):
        result.y += -1.float32
    elif IsKeyDown(KEY_S or KEY_DOWN):
        result.y += 1.float32

    # -------------------------- #
    #       Map Management       #
    # -------------------------- #

func parseMapTile(c : char) : int =
    if c == '-': return 0
    if c == '#': return 1

proc renderMap(map : seq[seq[int]], tileTexArray : openArray[Texture], tilesize : int) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            if map[i][j] != 0:
                drawTexFromGrid(tileTexArray[map[i][j] - 1], makevec2(j, i), tilesize)

    # ----------------------- #
    #       Import Maps       #
    # ----------------------- #

var maps : seq[seq[seq[int]]]
var fcount = 0
for file in walkDir("assets/maps/levelmaps"):
    maps.add @[]
    var lcount = 0
    for line in file[1].lines:
        maps[fcount].add @[]
        for c in line:
            maps[fcount][lcount].add parseMapTile c
        lcount += 1
    fcount += 1

for i in maps[0]:
    echo i


const
    tilesize = 64
    screenHeight = 768
    screenWidth = 1280
    screenvec = makevec2(screenWidth, screenHeight)
    numHoriTiles = 1280 / tilesize
    numVertiTiles = 720 / tilesize
    numTilesVec = makevec2(numHoriTiles, numVertiTiles)
    screencenter = makevec2(screenWidth / 2, screenHeight / 2)

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 75

let
    playertex = LoadTexture "assets/sprites/Player.png"
    tileTexArray = [LoadTexture "assets/sprites/BaseTile.png"]

var
    plr = Player(pos : makevec2(0, 0))


while not WindowShouldClose():
    ClearBackground RAYWHITE

    plr.pos = movePlayer plr


    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()

    # for i in 0..1280 div 64:
    #     for j in 0..768 div 64:
    #         DrawTexture tidleTexArray[0], i * 64, j * 64, WHITE 

    renderMap maps[0], tileTexArray, tilesize
    drawTexCenteredFromGrid playertex, plr.pos
    EndDrawing()

for tex in tileTexArray:
    UnloadTexture tex
CloseWindow()