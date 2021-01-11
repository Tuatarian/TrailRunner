import raylib, sequtils, lenientops, rayutils, math

type
    player = object
        pos : Vector2
        gridpos : Vector2
        sprite : Texture2D

    # --------------------------- #
    #       Grid Management       #
    # --------------------------- #

func screenToGrid(screencoord : Vector2) : Vector2 =
    return makevec2(grEqCeil screencoord.x, grEqCeil screencoord.y)

func screenToGrid(screencoord : float | int | float32, numXTiles : int | float32) : float | int | float32 =
    return grEqCeil screencoord / numXTiles

func gridToScreen(gridcoord, numXTiles : float | int | float32) : float | int | float32 =
    return (gridcoord * numXTiles)

proc drawTexFromGrid(tex : Texture, pos : Vector2, numTiles : Vector2) =
    DrawTexture(tex, int gridToScreen(pos.x, numTiles.x), int gridToScreen(pos.y, numTiles.y), WHITE)

proc movePlayer(plr : player) : Vector2 =
    if IsKeyDown(KEY_A or KEY_LEFT):
        result.x += -1.float32
    elif IsKeyDown(KEY_D or KEY_RIGHT):
        result.x += 1.float32
    elif IsKeyDown(KEY_W or KEY_UP):
        result.y += -1.float32
    elif IsKeyDown(KEY_S or KEY_DOWN):
        result.y += 1.float32


func parseMapTiles(inp : seq[seq[char]]) : seq[seq[int]] =
    for i  in 0..<inp.len:
        for c in inp[i]:
            if c == '-': result[i].add(0)
            if c == '#': result[i].add(1)

proc renderMap(map : seq[seq[int]], tileTexArray : openArray[Texture], numTilesVec : Vector2) =
    for i in 0..<map.len:
        for j in 0..map[i].len:
            drawTexFromGrid(tileTexArray[i - 1], makevec2(i, j), numTilesVec)


const
    screenHeight = 720
    screenWidth = 1280
    screenvec = makevec2(screenWidth, screenHeight)
    numHoriTiles = 1280 / 8
    numVertiTiles = 720 / 8
    numTilesVec = makevec2(numHoriTiles, numVertiTiles)
    screencenter = makevec2(screenWidth / 2, screenHeight / 2)

let
    tileTexArray = [LoadTextureFromImage LoadImage("assets/BaseTile")]
    # playerTex = LoadTextureFromImage LoadImage("assets/Player")

InitWindow(screenWidth, screenHeight, "BgGen")
SetTargetFPS 75

while not WindowShouldClose():
    ClearBackground RAYWHITE

    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()
    EndDrawing()
CloseWindow()