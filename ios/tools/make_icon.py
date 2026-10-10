# -*- coding: utf-8 -*-
"""生成 App 图标（1024x1024,单尺寸 asset,本地一次性运行后入库）。
设计 v2：深黑径向渐变底 + 绿→青渐变发光的 ">_" 终端符号（AI 编程智能体主题）。
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "ios", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png")

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

# 5) 合成符号本体（微内发光提亮边缘）
inner = Image.new("RGBA", (S, S), (0, 0, 0, 0))
inner.paste(Image.new("RGBA", (S, S), (255, 255, 255, 38)), (0, 0),
            Image.eval(mask.filter(ImageFilter.GaussianBlur(6)), lambda v: int(v * 0.15))
            if False else mask)
img.paste(symbol, (0, 0), mask)
img = Image.alpha_composite(img.convert("RGBA"), inner).convert("RGB")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG")
print("icon written:", os.path.relpath(OUT, ROOT))
