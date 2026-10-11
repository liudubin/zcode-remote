# -*- coding: utf-8 -*-
"""生成 App 图标（1024x1024,单尺寸 asset）与入口页徽标符号（IconSymbol imageset）。
设计 v2：深黑径向渐变底 + 绿→青渐变发光的 ">_" 终端符号（AI 编程智能体主题）。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios" / "App" / "Resources" / "Assets.xcassets"
OUT = ASSETS / "AppIcon.appiconset" / "AppIcon1024.png"

S = 1024
GREEN = (0, 235, 130)
CYAN = (0, 190, 225)

# 1) 背景：线性深底 + 中心径向微亮
img = Image.new("RGB", (S, S))
top, bottom = (17, 22, 20), (5, 7, 9)
px = img.load()
for y in range(S):
    t = y / (S - 1)
    base = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    for x in range(S):
        px[x, y] = base
glow_bg = Image.new("L", (S, S), 0)
gd = ImageDraw.Draw(glow_bg)
gd.ellipse((S * 0.16, S * 0.08, S * 0.98, S * 0.88), fill=52)
glow_bg = glow_bg.filter(ImageFilter.GaussianBlur(150))
img = Image.composite(Image.new("RGB", (S, S), (15, 28, 24)), img, glow_bg)

# 2) 符号蒙版：>_ 粗圆头线条（polyline 一次画，接头自然）
mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
W = 84
md.line([(388, 356), (540, 512), (388, 668)], fill=255, width=W, joint="curve")
md.line([(612, 668), (756, 668)], fill=255, width=W)
r = W // 2
md.ellipse((612 - r, 668 - r, 612 + r, 668 + r), fill=255)
md.ellipse((756 - r, 668 - r, 756 + r, 668 + r), fill=255)

# 3) 绿→青对角渐变上色
grad = Image.new("RGB", (S, S))
gp = grad.load()
x0, y0, x1, y1 = 320, 320, 800, 710
for y in range(S):
    for x in range(S):
        t = max(0.0, min(1.0, ((x - x0) + (y - y0)) / ((x1 - x0) + (y1 - y0))))
        gp[x, y] = tuple(int(GREEN[i] + (CYAN[i] - GREEN[i]) * t) for i in range(3))
symbol = Image.composite(grad, Image.new("RGB", (S, S), (0, 0, 0)), mask)

# 4) 发光：符号形状三层模糊 halo（alpha 合成，不糊背景）
for radius, alpha in [(80, 0.16), (38, 0.22), (16, 0.30)]:
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    tint = Image.new("RGBA", (S, S), (0, 220, 160, int(255 * alpha)))
    halo.paste(tint, (0, 0), mask.filter(ImageFilter.GaussianBlur(radius)))
    img = Image.alpha_composite(img.convert("RGBA"), halo).convert("RGB")

# 5) 合成符号本体
img.paste(symbol, (0, 0), mask)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, "PNG")
print("icon written:", OUT.relative_to(ROOT))


# ---------- 附产品：透明底 >_ 符号（入口页头部徽标用，与新 App 图标同款） ----------
def draw_symbol(size: int) -> Image.Image:
    """256 基准坐标按比例缩放；透明底、绿→青渐变、圆头线条。"""
    s = size / 256.0
    m = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(m)
    w = int(22 * s)
    def seg(x1, y1, x2, y2):
        md.line([(x1 * s, y1 * s), (x2 * s, y2 * s)], fill=255, width=w, joint="curve")
    def cap(x, y):
        rr = w // 2
        md.ellipse((x * s - rr, y * s - rr, x * s + rr, y * s + rr), fill=255)
    seg(55, 62, 117, 128)
    seg(117, 128, 55, 194)
    cap(55, 62)
    cap(117, 128)
    cap(55, 194)
    seg(141, 194, 201, 194)
    cap(141, 194)
    cap(201, 194)
    g = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gpx = g.load()
    for y in range(size):
        for x in range(size):
            t = max(0.0, min(1.0, (x + y) / (size * 2.0)))
            c = tuple(int(GREEN[i] + (CYAN[i] - GREEN[i]) * t) for i in range(3))
            gpx[x, y] = (c[0], c[1], c[2], 255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(g, (0, 0), m)
    return out


SYMDIR = ASSETS / "IconSymbol.imageset"
SYMDIR.mkdir(parents=True, exist_ok=True)
draw_symbol(256).save(SYMDIR / "IconSymbol@2x.png", "PNG")
draw_symbol(384).save(SYMDIR / "IconSymbol@3x.png", "PNG")
(SYMDIR / "Contents.json").write_text(
    '{\n  "images": [\n    {"filename": "IconSymbol@2x.png", "idiom": "universal", "scale": "2x"},\n'
    '    {"filename": "IconSymbol@3x.png", "idiom": "universal", "scale": "3x"}\n  ],\n'
    '  "info": {"author": "xcode", "version": 1}\n}\n',
    encoding="utf-8",
)
print("symbol written:", SYMDIR.relative_to(ROOT))
