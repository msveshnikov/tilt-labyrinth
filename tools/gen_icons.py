"""Generate the app icons as SVG.

    python tools/gen_icons.py

Writes:
  icon.svg                         project icon (512, rounded tile), also the web favicon
  icons/icon_full.svg              same art, full-bleed square (iOS / apple-touch-icon)
  icons/adaptive_background.svg    Android adaptive icon, background layer (432)
  icons/adaptive_foreground.svg    Android adaptive icon, foreground layer (432)
  icons/adaptive_monochrome.svg    Android 13+ themed icon (432, alpha only)
  icons/splash.svg                 boot splash (512, board only, on the navy boot background)

The export presets point at PNG renders of these (icons/*.png). Re-render them with any
SVG renderer after changing the art, e.g. Chromium or `rsvg-convert -w 192 icon.svg`.
Only plain shapes, gradients and opacity are used (no filters), so Godot's ThorVG
renders icon.svg the same way.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Palette, matching the in-game materials (board.gd, ball.gd, ui_theme.gd).
WOOD_DARK = "#6b3f25"
WOOD_FRAME = "#8d5a36"
WALL_TOP = "#94603b"
WALL_EDGE = "#b98457"
WALL_SIDE = "#5a341e"
FLOOR_A = "#dcb07a"
FLOOR_B = "#c3915a"
BG_TOP = "#3a4a7c"
BG_BOTTOM = "#161c30"

# Board geometry in a 512 space: frame 64..448, floor 88..424, 4x4 cells of 84.
CELL = 84
F0, F1 = 88, 424
LINES = [F0 + CELL * i for i in range(5)]  # 88 172 256 340 424
CENTERS = [F0 + CELL * i + CELL // 2 for i in range(4)]  # 130 214 298 382
WALL_W = 20

# Interior wall segments on grid lines: ("h", y, x0, x1) or ("v", x, y0, y1).
WALLS = [
    ("h", LINES[1], LINES[0], LINES[2]),
    ("v", LINES[3], LINES[0], LINES[2]),
    ("h", LINES[2], LINES[1], LINES[3]),
    ("v", LINES[1], LINES[2], LINES[4]),
    ("h", LINES[3], LINES[2], LINES[4]),
]

RED = ("#ff9aa0", "#e63946", "#86121d")
BLUE = ("#9cc0ff", "#2f6fe4", "#122f78")


def defs() -> str:
    def ball_grad(gid, c):
        return (
            f'<radialGradient id="{gid}" cx="0.4" cy="0.36" r="0.68" fx="0.32" fy="0.28">'
            f'<stop offset="0" stop-color="{c[0]}"/><stop offset="0.5" stop-color="{c[1]}"/>'
            f'<stop offset="1" stop-color="{c[2]}"/></radialGradient>'
        )

    return (
        "<defs>"
        f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{BG_TOP}"/><stop offset="1" stop-color="{BG_BOTTOM}"/></linearGradient>'
        '<radialGradient id="glow" cx="0.5" cy="0.45" r="0.5">'
        '<stop offset="0" stop-color="#7f95d8" stop-opacity="0.45"/>'
        '<stop offset="1" stop-color="#7f95d8" stop-opacity="0"/></radialGradient>'
        f'<linearGradient id="frame" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="#a66d43"/><stop offset="0.5" stop-color="{WOOD_FRAME}"/>'
        f'<stop offset="1" stop-color="{WOOD_DARK}"/></linearGradient>'
        f'<linearGradient id="floor" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{FLOOR_A}"/><stop offset="1" stop-color="{FLOOR_B}"/></linearGradient>'
        '<linearGradient id="inset" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#3a1f10" stop-opacity="0.35"/>'
        '<stop offset="1" stop-color="#3a1f10" stop-opacity="0"/></linearGradient>'
        '<linearGradient id="insetL" x1="0" y1="0" x2="1" y2="0">'
        '<stop offset="0" stop-color="#3a1f10" stop-opacity="0.3"/>'
        '<stop offset="1" stop-color="#3a1f10" stop-opacity="0"/></linearGradient>'
        '<radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5">'
        '<stop offset="0" stop-color="#000" stop-opacity="0.45"/>'
        '<stop offset="0.6" stop-color="#000" stop-opacity="0.25"/>'
        '<stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>'
        '<radialGradient id="pit" cx="0.5" cy="0.42" r="0.55">'
        '<stop offset="0" stop-color="#000"/><stop offset="0.7" stop-color="#140b07"/>'
        '<stop offset="1" stop-color="#4a2c19"/></radialGradient>'
        + ball_grad("red", RED)
        + ball_grad("blue", BLUE)
        + "</defs>"
    )


def wall_rect(w):
    kind, a, b0, b1 = w
    h = WALL_W / 2
    if kind == "h":
        return b0, a - h, b1 - b0, WALL_W
    return a - h, b0, WALL_W, b1 - b0


def ball(cx, cy, gid, r=29) -> str:
    return (
        f'<ellipse cx="{cx + 7}" cy="{cy + 11}" rx="{r + 6}" ry="{r + 2}" fill="url(#shadow)"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{gid})"/>'
        f'<ellipse cx="{cx - 10}" cy="{cy - 12}" rx="10" ry="6.5" fill="#fff" opacity="0.85" '
        f'transform="rotate(-35 {cx - 10} {cy - 12})"/>'
        f'<circle cx="{cx + 9}" cy="{cy + 13}" r="{r - 6}" fill="none" stroke="#fff" '
        f'stroke-width="2.5" stroke-opacity="0.18"/>'
    )


def board(mono=False) -> str:
    """The tray, walls, pocket, hole and balls, centred on (256, 256) in a 512 space."""
    out = []
    if mono:
        # Themed icon: alpha only. Frame ring, walls, pocket ring and balls.
        out.append('<path fill="#fff" fill-rule="evenodd" d="M100 64h312a36 36 0 0 1 36 36v312a36 36 0 0 1-36 36H100a36 36 0 0 1-36-36V100a36 36 0 0 1 36-36z'
                   'M98 88h316a10 10 0 0 1 10 10v316a10 10 0 0 1-10 10H98a10 10 0 0 1-10-10V98a10 10 0 0 1 10-10z"/>')
        for w in WALLS:
            x, y, ww, hh = wall_rect(w)
            out.append(f'<rect x="{x}" y="{y}" width="{ww}" height="{hh}" rx="5" fill="#fff"/>')
        px, py = CENTERS[3], CENTERS[3]
        out.append(f'<circle cx="{px}" cy="{py}" r="29" fill="none" stroke="#fff" stroke-width="9"/>')
        out.append(f'<circle cx="{CENTERS[0]}" cy="{CENTERS[2]}" r="27" fill="#fff" opacity="0.45"/>')
        out.append(f'<circle cx="{CENTERS[2] - 4}" cy="{CENTERS[3]}" r="29" fill="#fff"/>')
        out.append(f'<circle cx="{CENTERS[1]}" cy="{CENTERS[0]}" r="29" fill="#fff"/>')
        return "".join(out)

    # Drop shadow under the tray (stacked rects fake a blur without SVG filters).
    for i, op in enumerate((0.10, 0.10, 0.12, 0.14)):
        g = 14 - i * 4
        out.append(f'<rect x="{64 - g + 10}" y="{64 - g + 18}" width="{384 + 2 * g}" height="{384 + 2 * g}" '
                   f'rx="{36 + g}" fill="#000" opacity="{op}"/>')
    # Frame with a bevel highlight, then the recessed floor.
    out.append('<rect x="64" y="64" width="384" height="384" rx="36" fill="url(#frame)"/>')
    out.append('<rect x="67" y="67" width="378" height="378" rx="33" fill="none" stroke="#d29a68" '
               'stroke-width="3" stroke-opacity="0.55"/>')
    out.append(f'<rect x="{F0 - 3}" y="{F0 - 3}" width="{F1 - F0 + 6}" height="{F1 - F0 + 6}" rx="12" fill="{WALL_SIDE}"/>')
    out.append(f'<rect x="{F0}" y="{F0}" width="{F1 - F0}" height="{F1 - F0}" rx="10" fill="url(#floor)"/>')
    # Wood grain.
    for i, y in enumerate((120, 205, 262, 318, 395)):
        bend = 10 if i % 2 else -8
        out.append(f'<path d="M{F0} {y} C 180 {y + bend}, 320 {y - bend}, {F1} {y + bend // 2}" fill="none" '
                   f'stroke="#a8743f" stroke-width="2" stroke-opacity="0.22"/>')
    # The frame's shadow falling onto the floor (light comes from the top left).
    out.append(f'<rect x="{F0}" y="{F0}" width="{F1 - F0}" height="22" rx="10" fill="url(#inset)"/>')
    out.append(f'<rect x="{F0}" y="{F0}" width="22" height="{F1 - F0}" rx="10" fill="url(#insetL)"/>')

    # Hole and pocket sit in the floor, under the walls' shadows.
    hx, hy = CENTERS[0], CENTERS[2]
    out.append(f'<circle cx="{hx}" cy="{hy}" r="29" fill="url(#pit)"/>')
    out.append(f'<path d="M{hx - 26} {hy + 8} A 27 27 0 0 0 {hx + 26} {hy + 8}" fill="none" stroke="#8a5a36" '
               'stroke-width="3" stroke-opacity="0.7"/>')
    px, py = CENTERS[3], CENTERS[3]
    out.append(f'<circle cx="{px}" cy="{py}" r="31" fill="#b3202d"/>')
    out.append(f'<circle cx="{px}" cy="{py}" r="29" fill="#e63946"/>')
    out.append(f'<circle cx="{px}" cy="{py}" r="20" fill="#140c0c"/>')
    out.append(f'<circle cx="{px}" cy="{py}" r="8" fill="none" stroke="#f59aa1" stroke-width="3.5"/>')

    # Walls: cast shadow, side face, top face, lit edge.
    for w in WALLS:
        x, y, ww, hh = wall_rect(w)
        out.append(f'<rect x="{x + 5}" y="{y + 9}" width="{ww}" height="{hh}" rx="6" fill="#3a1f10" opacity="0.28"/>')
    for w in WALLS:
        x, y, ww, hh = wall_rect(w)
        out.append(f'<rect x="{x}" y="{y + 6}" width="{ww}" height="{hh}" rx="5" fill="{WALL_SIDE}"/>')
        out.append(f'<rect x="{x}" y="{y}" width="{ww}" height="{hh}" rx="5" fill="{WALL_TOP}"/>')
        out.append(f'<rect x="{x + 2}" y="{y + 1.5}" width="{ww - 4}" height="3" rx="1.5" fill="{WALL_EDGE}" opacity="0.8"/>')

    # Red ball rolling right into its pocket, with a faint motion trail; blue ball resting.
    rx, ry = CENTERS[2] - 4, CENTERS[3]
    for dx, op in ((-44, 0.10), (-24, 0.18)):
        out.append(f'<circle cx="{rx + dx}" cy="{ry}" r="27" fill="#e63946" opacity="{op}"/>')
    out.append(ball(rx, ry, "red"))
    out.append(ball(CENTERS[1], CENTERS[0], "blue"))
    return "".join(out)


TILT = -7  # degrees: the board is drawn tilted, like in play


def svg(size, body) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">{body}</svg>\n')


def tilted(scale, size, mono=False) -> str:
    c = size / 2
    return (f'<g transform="translate({c} {c}) rotate({TILT}) scale({scale}) translate(-256 -256)">'
            f"{board(mono)}</g>")


def main():
    icons = ROOT / "icons"
    icons.mkdir(exist_ok=True)
    tile = '<rect width="512" height="512" rx="112" fill="url(#bg)"/><rect width="512" height="512" rx="112" fill="url(#glow)"/>'
    square = '<rect width="512" height="512" fill="url(#bg)"/><rect width="512" height="512" fill="url(#glow)"/>'
    (ROOT / "icon.svg").write_text(svg(512, defs() + tile + tilted(0.9, 512)))
    (icons / "icon_full.svg").write_text(svg(512, defs() + square + tilted(0.9, 512)))
    # Adaptive layers are 432 with a 288 visible area; keep the art inside the ~264 safe circle.
    (icons / "adaptive_background.svg").write_text(svg(432, defs() + '<rect width="432" height="432" fill="url(#bg)"/>'
                                                       '<rect width="432" height="432" fill="url(#glow)"/>'))
    (icons / "adaptive_foreground.svg").write_text(svg(432, defs() + tilted(0.47, 432)))
    (icons / "adaptive_monochrome.svg").write_text(svg(432, tilted(0.47, 432, mono=True)))
    (icons / "splash.svg").write_text(svg(512, defs() + tilted(0.9, 512)))
    print("wrote icon.svg and icons/*.svg")


if __name__ == "__main__":
    main()
