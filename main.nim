import raylib, sequtils, lenientops, rayutils


type
    player = object
        pos : Vector2
        gridpos : Vector2

proc movePlayer(p : player) : Vector2 =
    if IsKeyDown(KEY_A or KEY_LEFT):
        result.x += -1.float32


const
    screenHeight = 720
    screenWidth = 1280
    screenvec = makevec2(screenWidth, screenHeight)
    screencenter = makevec2(screenWidth / 2, screenHeight / 2)

InitWindow(screenWidth, screenHeight, "BgGen")

SetTargetFPS 60

var
    verts : seq[Vector2]
    xcoords : seq[float]
    ycoords : seq[float]

for x in 0..10:
    xcoords.add(screenWidth / 11)

for y in 0..8:
    ycoords.add(screenHeight / 930)

for x in xcoords:
    for y in ycoords:
        verts.add(makevec2(x, y))

SetTargetFPS 75

while not WindowShouldClose():
    ClearBackground RAYWHITE

    # ---------------- #
    #       DRAW       #
    # ---------------- #

    BeginDrawing()
    EndDrawing()
CloseWindow()