import raylib, os, lenientops, rayutils, math, random

randomize()

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
    DrawTexture(tex, int pos.x * tilesize + (tilesize - tex.width) / 2, int pos.y * tilesize + (tilesize - tex.height) / 2, tint)

    # ----------------------------- #
    #       Player Management       #
    # ----------------------------- #

proc movePlayer(plr : var Player, lfkey : KeyboardKey) : KeyboardKey =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            return KEY_LEFT
        plr.pos.x += -1
        return KEY_LEFT
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            return KEY_RIGHT
        plr.pos.x += 1
        return KEY_RIGHT
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            return KEY_UP
        plr.pos.y += -1
        return KEY_UP
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            return KEY_DOWN
        plr.pos.y += 1
        return KEY_DOWN

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
    tilesize = 96
    screenHeight = 768
    screenWidth = 1248

InitWindow screenWidth, screenHeight, "TrailRun"
SetTargetFPS 75

let
    playertex = LoadTexture "assets/sprites/Player.png"
    tileTexArray = [LoadTexture "assets/sprites/BaseTile.png"]

var
    plr = Player(pos : makevec2(0, 0))
    lastframekey = KEY_F


while not WindowShouldClose():
    ClearBackground RAYWHITE

    lastframekey = movePlayer(plr, lastframekey)
    echo plr.pos


    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()

    # for i in 0..1280 div 64:
    #     for j in 0..768 div 64:
    #         DrawTexture tidleTexArray[0], i * 64, j * 64, WHITE 

    renderMap maps[0], tileTexArray, tilesize
    drawTexCenteredFromGrid playertex, plr.pos, tilesize, WHITE
    EndDrawing()

for tex in tileTexArray:
    UnloadTexture tex
CloseWindow()