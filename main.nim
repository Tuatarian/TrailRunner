import raylib, sequtils, lenientops, rayutils


type
    player = object
        pos : Vector2
        gridpos : Vector2

proc movePlayer(plr : player) : Vector2 =
    if IsKeyDown(KEY_A or KEY_LEFT):
        result.x += -1.float32
    elif IsKeyDown(KEY_D or KEY_RIGHT):
        result.x += 1.float32
    elif IsKeyDown(KEY_W or KEY_UP):
        result.y += -1.float32
    elif IsKeyDown(KEY_S or KEY_DOWN):
        result.y += 1.float32

const
    screenHeight = 720
    screenWidth = 1280
    screenvec = makevec2(screenWidth, screenHeight)
    screencenter = makevec2(screenWidth / 2, screenHeight / 2)

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