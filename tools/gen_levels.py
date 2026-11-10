"""Generates levels/level_NN.json (deterministic). Run: python tools/gen_levels.py
Hand-edit or add JSON files freely afterwards; the game only reads the JSON."""
import json, random, os
from collections import deque

COLORS = [("red", "r"), ("blue", "b"), ("green", "g"), ("yellow", "y")]
LEVELS = [
    # name, maze w, maze h (cells), balls, loop share, holes, seed
    ("Первые шаги", 4, 5, 1, 0.05, 0, 11),
    ("Извилистая тропа", 5, 6, 1, 0.08, 0, 22),
    ("Осторожно, ямы", 5, 6, 1, 0.10, 2, 33),
    ("Двое", 5, 6, 2, 0.12, 0, 44),
    ("Разные пути", 5, 6, 2, 0.10, 1, 55),
    ("Ловушки", 5, 6, 2, 0.10, 3, 66),
    ("Большой лабиринт", 6, 7, 2, 0.12, 3, 77),
    ("Трио", 6, 7, 3, 0.15, 0, 88),
    ("Три цвета", 6, 7, 3, 0.12, 3, 99),
    ("Мастер наклона", 6, 7, 3, 0.10, 4, 1010),
    ("Квартет", 6, 7, 4, 0.18, 2, 1111),
    ("Финал", 6, 7, 4, 0.12, 5, 1212),
    # 13-32: bigger boards, more holes, fewer shortcuts.
    ("Новый круг", 6, 8, 2, 0.12, 3, 1313),
    ("Длинный путь", 6, 8, 2, 0.08, 4, 1414),
    ("Минное поле", 6, 8, 2, 0.12, 6, 1515),
    ("Тройка", 7, 8, 3, 0.12, 4, 1616),
    ("Узкие места", 7, 8, 3, 0.08, 5, 1717),
    ("Пропасти", 7, 8, 3, 0.10, 7, 1818),
    ("Четыре стороны", 7, 8, 4, 0.15, 4, 1919),
    ("Перекрёстки", 7, 9, 4, 0.14, 5, 2020),
    ("Тупики", 7, 9, 4, 0.06, 6, 2121),
    ("Решето", 7, 9, 3, 0.12, 9, 2222),
    ("Великий лабиринт", 8, 9, 3, 0.10, 6, 2323),
    ("Хитрый квартет", 8, 9, 4, 0.12, 7, 2424),
    ("По краю", 8, 9, 4, 0.08, 8, 2525),
    ("Бездна", 8, 10, 3, 0.10, 10, 2626),
    ("Терпение", 8, 10, 4, 0.06, 8, 2727),
    ("Ювелир", 8, 10, 4, 0.10, 10, 2828),
    ("Кошмар", 8, 10, 4, 0.08, 11, 2929),
    ("Испытание", 8, 10, 4, 0.06, 12, 3030),
    ("Предфинал", 8, 10, 4, 0.05, 13, 3131),
    ("Гранд-финал", 8, 10, 4, 0.04, 14, 3232),
]


def gen(mw, mh, nballs, loops, nholes, seed):
    rnd = random.Random(seed)
    W, H = 2 * mw + 1, 2 * mh + 1
    g = [["#"] * W for _ in range(H)]
    stack = [(1, 1)]
    g[1][1] = "."
    while stack:
        x, y = stack[-1]
        nb = [(dx, dy) for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2))
              if 0 < x + dx < W and 0 < y + dy < H and g[y + dy][x + dx] == "#"]
        if not nb:
            stack.pop()
            continue
        dx, dy = rnd.choice(nb)
        g[y + dy // 2][x + dx // 2] = "."
        g[y + dy][x + dx] = "."
        stack.append((x + dx, y + dy))
    walls = [(x, y) for y in range(1, H - 1) for x in range(1, W - 1)
             if g[y][x] == "#" and (x % 2) != (y % 2)]
    rnd.shuffle(walls)
    for x, y in walls[: int(len(walls) * loops)]:
        g[y][x] = "."
    cx, cy = W // 2, H // 2
    room = {(x, y) for y in range(cy - 1, cy + 2) for x in range(cx - 1, cx + 2)}
    for x, y in room:
        g[y][x] = "."
    g[cy][cx] = "S"

    def open_nb(x, y):
        return [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g[y + dy][x + dx] != "#"]

    dist = {(cx, cy): 0}
    q = deque([(cx, cy)])
    while q:
        p = q.popleft()
        for n in open_nb(*p):
            if n not in dist:
                dist[n] = dist[p] + 1
                q.append(n)
    dead = [p for p in dist if p not in room and len(open_nb(*p)) == 1]
    dead.sort(key=lambda p: -dist[p])
    pockets = []
    for min_gap in (5, 3, 1):
        for p in dead:
            if len(pockets) == nballs:
                break
            if p not in pockets and all(abs(p[0] - o[0]) + abs(p[1] - o[1]) >= min_gap for o in pockets):
                pockets.append(p)
    # Not enough dead ends (loops remove them): fall back to far corridor cells.
    far = sorted((p for p in dist if p not in room), key=lambda p: -dist[p])
    for p in far:
        if len(pockets) == nballs:
            break
        if p not in pockets and all(abs(p[0] - o[0]) + abs(p[1] - o[1]) >= 3 for o in pockets):
            pockets.append(p)
    assert len(pockets) == nballs, "not enough room for pockets"
    for (x, y), (_, ch) in zip(pockets, COLORS):
        g[y][x] = ch
    # Holes: unused dead ends, then side pits carved into walls next to a corridor.
    # Holes aren't walkable, so turning a wall into a hole never changes the routes;
    # it just makes the corridor next to it dangerous.
    rest = [p for p in dead if p not in pockets and dist[p] >= 3]
    rnd.shuffle(rest)
    pits = []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if g[y][x] != "#":
                continue
            nb = open_nb(x, y)
            near_pocket = any(abs(x - px) + abs(y - py) <= 2 for px, py in pockets)
            if nb and not near_pocket and all(dist.get(n, 0) >= 2 and n not in room for n in nb):
                pits.append((x, y))
    rnd.shuffle(pits)
    holes = []
    for p in rest + pits:
        if len(holes) == nholes:
            break
        if all(abs(p[0] - h[0]) + abs(p[1] - h[1]) > 2 for h in holes):
            holes.append(p)
    for x, y in holes:
        g[y][x] = "O"
    par = round(4 + sum(dist[p] for p in pockets) * 0.45)
    return ["".join(r) for r in g], par


here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "..", "levels")
for i, (name, mw, mh, n, loops, holes, seed) in enumerate(LEVELS, 1):
    grid, par = gen(mw, mh, n, loops, holes, seed)
    data = {"name": name, "par": par, "grid": grid, "balls": [{"color": c} for c, _ in COLORS[:n]]}
    with open(os.path.join(out_dir, "level_%02d.json" % i), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(i, name, "par", par)
    print("\n".join(grid))
