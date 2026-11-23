"""Google Play store graphics -> renders/play/.

python tools/play_store.py [--no-shots]
  icon_512.png               app icon (icons/icon_full.svg rendered at 512)
  feature_ru_1024x500.png    feature graphic: title + a tilted board from the game / feature_en_1024x500.png
  N_name.png                 phone screenshots 1080x1920, rendered by the game itself (-- --storeshots)
"""
import glob
import os
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders", "play")
RAW = os.path.join(OUT, "raw")
GODOT = os.path.expanduser("~/OneDrive/Рабочий стол/Godot_v4.7.2-stable_win64.exe")
FONT = "C:/Windows/Fonts/seguibl.ttf"
FONT_SUB = "C:/Windows/Fonts/segoeuib.ttf"
BG = (39, 50, 77)        # game background #27324d
ACCENT = (255, 196, 60)  # UI accent yellow


def shots():
    for f in glob.glob(os.path.join(RAW, "*.png")):
        os.remove(f)
    subprocess.run([GODOT, "--path", ROOT, "--resolution", "1080x1920", "--", "--storeshots"],
                   check=False, capture_output=True, timeout=300)
    for f in sorted(glob.glob(os.path.join(RAW, "*.png"))):
        im = Image.open(f)
        assert im.size == (1080, 1920), (f, im.size)
        im.convert("RGB").save(os.path.join(OUT, os.path.basename(f)))
        print("shot", os.path.basename(f))


def icon():
    # The full-bleed variant of the app icon, rendered from SVG by Godot (Play masks the corners itself).
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "tools/svg2png.gd", "--",
                    os.path.join(ROOT, "icons", "icon_full.svg"), os.path.join(OUT, "icon_512.png"), "1.0"],
                   check=True, capture_output=True, timeout=120)
    im = Image.open(os.path.join(OUT, "icon_512.png"))
    assert im.size == (512, 512), im.size
    im.convert("RGB").save(os.path.join(OUT, "icon_512.png"))


def board_cutout():
    """The tilted board from the big-board screenshot, on a transparent background."""
    im = Image.open(os.path.join(RAW, "3_big_board.png")).convert("RGB")
    box = (0, 120, 1080, 1500)
    crop = im.crop(box)
    # Everything that is not the plain background colour belongs to the board.
    mask = Image.new("L", crop.size, 0)
    px, mp = crop.load(), mask.load()
    for y in range(crop.size[1]):
        for x in range(crop.size[0]):
            r, g, b = px[x, y]
            if abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 40:
                mp[x, y] = 255
    mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(1))
    out = crop.convert("RGBA")
    out.putalpha(mask)
    return out.crop(mask.getbbox())


def feature(lang, board):
    w, h = 1024, 500
    bg = Image.new("RGB", (w, h), BG)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse((520, -60, 1120, 560), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    bg = Image.composite(Image.new("RGB", (w, h), (70, 92, 140)), bg, glow).convert("RGBA")

    b = board.copy()
    b.thumbnail((440, 440), Image.LANCZOS)
    shadow = Image.new("RGBA", b.size, (0, 0, 0, 0))
    shadow.putalpha(b.getchannel("A").point(lambda a: a * 0.55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    x, y = w - b.size[0] - 34, (h - b.size[1]) // 2
    bg.alpha_composite(shadow, (x + 14, y + 18))
    bg.alpha_composite(b, (x, y))

    d = ImageDraw.Draw(bg)
    if lang == "ru":
        title, sub = ["Лабиринт"], "Наклони и закати шарики\nв лузы своего цвета"
    else:
        title, sub = ["Tilt", "Labyrinth"], "Tilt the board, roll every ball\ninto its own pocket"
    size = 92 if lang == "ru" else 92
    ty = 70 if lang == "ru" else 40
    for line in title:
        d.text((56, ty), line, font=ImageFont.truetype(FONT, size), fill=ACCENT,
               stroke_width=4, stroke_fill=(20, 26, 44))
        ty += int(size * 1.08)
    d.multiline_text((60, ty + 30), sub, font=ImageFont.truetype(FONT_SUB, 34), fill=(235, 240, 250), spacing=10)
    assert d.textbbox((56, 70), title[0], font=ImageFont.truetype(FONT, size))[2] < x, "title overlaps board"
    tag = "32 уровня · наклон или джойстик" if lang == "ru" else "32 levels · tilt or joystick"
    d.text((60, h - 78), tag, font=ImageFont.truetype(FONT_SUB, 26), fill=(190, 202, 228))
    bg.convert("RGB").save(os.path.join(OUT, "feature_%s_1024x500.png" % lang))


def main():
    os.makedirs(RAW, exist_ok=True)
    if "--no-shots" not in sys.argv:
        shots()
    icon()
    board = board_cutout()
    for lang in ("ru", "en"):
        feature(lang, board)
    print("done ->", OUT)


if __name__ == "__main__":
    main()
