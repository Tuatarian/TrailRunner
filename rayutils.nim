import raylib, math

const colorArr* : array[25, Color] = [LIGHTGRAY, GRAY, DARKGRAY, YELLOW, GOLD, ORANGE, PINK, RED, MAROON, GREEN, LIME, DARKGREEN, SKYBLUE, BLUE, DARKBLUE, PURPLE, VIOLET, DARKPURPLE, BEIGE, BROWN, DARKBROWN, WHITE, BLACK, MAGENTA, RAYWHITE]

func toTuple*(v : Vector2) : (float32, float32) =
    return (v.x, v.y) 

func makevec2*(x, y: float | float32 | int) : Vector2 =
    result.x = float x
    result.y = float y

func clamp*(v, v2 : Vector2) : Vector2 =
    return makevec2(min(v.x, v2.x), min(v.y, v2.y))

func antiClamp*(v, v2 : Vector2) : Vector2 =
    return makevec2(max(v.x, v2.x), max(v.y, v2.y))

func grEqCeil*(n : int | float | float32) : int | float | float32 =
    if n == n.int.float:
        return n
    return ceil(n)

proc drawTexCentered*(tex : Texture2D, pos : Vector2, tint : Color) =
    tex.DrawTexture(int pos.x + tex.width / 2, int pos.y + tex.height / 2, tint)

proc drawTexCentered*(tex : Texture2D, posx, posy : int | float | float32, tint : Color) =
    tex.DrawTexture(int posx + tex.width / 2, int posy + tex.height / 2, tint)

func reflect*(i, tp : int | float) : int | float =
    return tp - i + tp

func `+`*(v, v2 : Vector2) : Vector2 =
    result.x = v.x + v2.x
    result.y = v.y + v2.y

func `-`*(v, v2 : Vector2) : Vector2 =
    result.x = v.x - v2.x
    result.y = v.y - v2.y

func `+`*[T](v : Vector2, n : T) : Vector2 =
    result.x = v.x + n
    result.y = v.y + n

func `-`*[T](v : Vector2, n : T) : Vector2 =
    result.x = v.x - n
    result.y = v.y - n

func `+=`*[T](v : var Vector2, t : T) =
    v = v + t

func `/`*(v, v2 : Vector2) : Vector2 =
    result.x = v.x / v2.x
    result.y = v.y / v2.y

func `/`*(v, : Vector2, f : float) : Vector2 =
    result.x = v.x / f
    result.y = v.y / f

func `div`*(v, : Vector2, f : float) : Vector2 =
    result.x = ceil(v.x / f)
    result.y = ceil(v.y / f)

func `mod`*(v, v2 : Vector2) : Vector2 =
    return makevec2(v.x mod v2.x, v.y mod v2.y)

func `*`*(v, v2 : Vector2) : Vector2 =
    result.x = v.x * v2.x
    result.y = v.y * v2.y

func cart2Polar*(v : Vector2, c = Vector2(x : 0, y : 0)) : Vector2 =
    let v = v - c
    result.x = sqrt((v.x ^ 2) + (v.y ^ 2)) 
    result.y = arctan(v.y / v.x)

proc echo(vs : varargs[Vector2]) =
    for v in vs:
        echo (v.x, v.y)

func dist*(v, v2 : Vector2) : float = 
    return abs sqrt(((v.x - v2.x) ^ 2) + ((v.y - v2.y) ^ 2))

func dot*(v, v2 : Vector2) : float =
    return (v.x * v2.x) + (v.y * v2.y)

func dot*(x, y : int) : float =
    return float (x * x) + (y * y)

func dot*(x, y : float | float32) : float =
    return (x * x) + (y * y)

func dot*(v : Vector2) : float =
    return float (v.x * v.x) + (v.y * v.y)

func makevec3*(i, j, k : float) : Vector3 =
    return Vector3(x : i, y : j, z : k)

func makecolor*[T](f, d, l, o : T) : Color =
    return Color(r : uint8 f, g : uint8 d, b : uint8 l, a : uint8 o)

func normalizeToScreen*(v, screenvec : Vector2) : Vector2 =
    return makevec2(v.x / screenvec.x, v.y / screenvec.y )

proc drawTriangleFan*(verts : openArray[Vector2], color : Color) =
    var inpoint : Vector2
    var mutverts : seq[Vector2]

    for v in verts: 
        inpoint = inpoint + v
        mutverts.add(v)
    
    inpoint = inpoint / float verts.len
    mutverts.add(verts[0])

    for i in 1..<mutverts.len:
        var points = [inpoint, mutverts[i - 1], mutverts[i]]
        var ininpoint = (points[0] + points[1] + points[2]) / 3
        var polarpoints = [cart2Polar(points[0], ininpoint), cart2Polar(points[1], ininpoint), cart2Polar(points[2], ininpoint)]
        for j in 0..points.len:
            for k in 0..<points.len - 1 - j:
                if polarpoints[k].y > polarpoints[k + 1].y:
                    swap(polarpoints[k], polarpoints[k + 1])
                    swap(points[k], points[k + 1])
        DrawTriangle(points[0], points[1], points[2], color)

func normalize*(v : Vector2) : Vector2 =
    return v / sqrt v.x ^ 2 + v.y ^ 2
