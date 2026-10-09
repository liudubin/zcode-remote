# -*- coding: utf-8 -*-
"""生成 App 图标（1024x1024,单尺寸 asset,本地一次性运行后入库）。
设计：近黑渐变底 + ZCode 绿色闪电（与 Android 版 ic_bolt 同意象）。
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "ios", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset")

SIZE = 1024
BOLT = [(575, 72), (215, 585), (455, 585), (395, 952), (815, 398), (549, 398), (648, 72)]

img = Image.new("RGB", (SIZE, SIZE))
top, bottom = (23, 24, 26), (12, 13, 15)
px = img.load()
for y in range(SIZE):
    t = y / (SIZE - 1)
    c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    for x in range(SIZE):
        px[x, y] = c

draw = ImageDraw.Draw(img)
draw.polygon(BOLT, fill=(0, 230, 118))

os.makedirs(OUT_DIR, exist_ok=True)
img.save(os.path.join(OUT_DIR, "AppIcon1024.png"), "PNG")
print("icon written:", os.path.relpath(os.path.join(OUT_DIR, "AppIcon1024.png"), ROOT))
