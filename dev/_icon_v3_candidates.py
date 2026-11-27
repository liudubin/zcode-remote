# -*- coding: utf-8 -*-
"""图标 v3 三个候选方向，各出 512 预览 + 拼一张对比图。"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent / "_icon_v3"
OUT.mkdir(exist_ok=True)
S = 512


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diag_gradient(size, c0, c1):
    g = Image.new("RGB", (size, size))
    px = g.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2.0 * (size - 1))
            px[x, y] = lerp(c0, c1, t)
    return g


def glyph_mask(size, w_ratio=0.10):
    """>_ 符号蒙版：粗圆头，256 基准坐标缩放。"""
    s = size / 256.0
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    w = int(26 * s)
    def seg(x1, y1, x2, y2):
        d.line([(x1 * s, y1 * s), (x2 * s, y2 * s)], fill=255, width=w, joint="curve")
    def cap(x, y):
        rr = w / 2.0
        d.ellipse((x * s - rr, y * s - rr, x * s + rr, y * s + rr), fill=255)
    seg(64, 66, 126, 128)
    seg(126, 128, 64, 190)
    cap(64, 66); cap(126, 128); cap(64, 190)
    seg(148, 190, 204, 190)
    cap(148, 190); cap(204, 190)
    return m


GREEN = (52, 238, 154)
CYAN = (25, 200, 224)

# ---------- 候选 A：霓虹渐变底 + 深色终端窗 ----------
def cand_a():
    img = diag_gradient(S, (16, 216, 124), (18, 158, 200))
    # 角落暗角
    vin = Image.new("L", (S, S), 0)
    vd = ImageDraw.Draw(vin)
    vd.ellipse((-S * 0.5, -S * 0.5, S * 0.4, S * 0.4), fill=60)
    vd.ellipse((S * 0.55, S * 0.55, S * 1.6, S * 1.6), fill=70)
    vin = vin.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGB", (S, S), (5, 60, 45)), img, vin)
    # 终端窗卡
    cw = int(S * 0.64)
    cx = (S - cw) // 2
    cy = int(S * 0.20)
    cr = int(cw * 0.22)
    card = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((cx, cy, cx + cw, cy + cw), radius=cr, fill=(10, 16, 14, 255))
    # 卡片投影
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle((cx, cy + int(S * 0.02), cx + cw, cy + cw + int(S * 0.02)), radius=cr, fill=(0, 40, 30, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img.convert("RGBA"), sh)
    img.paste(card, (0, 0), card)
    # 窗口点
    d = ImageDraw.Draw(img)
    dotr = int(S * 0.016)
    dy = cy + int(cw * 0.115)
    for i, c in enumerate([(94, 106, 100), (94, 106, 100), (94, 106, 100)]):
        dx = cx + int(cw * 0.09) + i * int(dotr * 4.4)
        d.ellipse((dx - dotr, dy - dotr, dx + dotr, dy + dotr), fill=c + (255,))
    # 渐变 >_（亮，带微光）
    gm = glyph_mask(S).point(lambda v: v)
    gbox = gm.getbbox()
    gm = gm.crop(gbox)
    gs = int(cw * 0.52)
    ratio = gs / gm.width
    gm = gm.resize((gs, int(gm.height * ratio)), Image.LANCZOS)
    full = Image.new("L", (S, S), 0)
    gx = cx + (cw - gm.width) // 2
    gy = cy + int(cw * 0.24) + (int(cw * 0.62) - gm.height) // 2
    full.paste(gm, (gx, gy))
    grad = diag_gradient(S, GREEN, CYAN)
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for r, a in [(26, 70), (12, 90)]:
        h = Image.new("RGBA", (S, S), (120, 255, 200, a))
        glow = Image.alpha_composite(glow, Image.new("RGBA", (S, S), (0, 0, 0, 0)))
        glow.paste(h, (0, 0), full.filter(ImageFilter.GaussianBlur(r)))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    img.paste(grad, (0, 0), full)
    return img.convert("RGB")


# ---------- 候选 B：深空玻璃 + 发光大符号 ----------
def cand_b():
    img = Image.new("RGB", (S, S), (7, 11, 10))
    px = img.load()
    for y in range(S):
        for x in range(S):
            dx, dy = (x - S * 0.5) / S, (y - S * 0.42) / S
            r = math.sqrt(dx * dx + dy * dy)
            px[x, y] = lerp((14, 30, 24), (5, 7, 7), min(1.0, r * 1.6))
    gm = glyph_mask(S, 0.115)
    grad = diag_gradient(S, GREEN, CYAN)
    full = gm
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for r, a in [(60, 34), (28, 50), (12, 70)]:
        h = Image.new("RGBA", (S, S), (60, 240, 170, a))
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        layer.paste(h, (0, 0), full.filter(ImageFilter.GaussianBlur(r)))
        glow = Image.alpha_composite(glow, layer)
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    img.paste(grad, (0, 0), full)
    # 细渐变描边框
    d = ImageDraw.Draw(img)
    inset = int(S * 0.045)
    d.rounded_rectangle((inset, inset, S - inset, S - inset), radius=int(S * 0.18),
                        outline=(120, 235, 185), width=3)
    return img.convert("RGB")


# ---------- 候选 C：渐变底 + 白符号 + 遥控波 ----------
def cand_c():
    img = diag_gradient(S, (15, 210, 130), (16, 150, 205))
    gm = glyph_mask(S, 0.115)
    white = Image.new("RGB", (S, S), (247, 255, 250))
    d = ImageDraw.Draw(img)
    # 右上角遥控信号弧
    cx, cy = int(S * 0.78), int(S * 0.20)
    for rr, wd in [(int(S * 0.16), 14), (int(S * 0.26), 14)]:
        d.arc((cx - rr, cy - rr, cx + rr, cy + rr), start=250, end=290, fill=(250, 255, 252), width=wd)
    dotr = int(S * 0.028)
    d.ellipse((cx - dotr, cy - dotr, cx + dotr, cy + dotr), fill=(250, 255, 252))
    img.paste(white, (0, 0), gm)
    return img


a, b, c = cand_a(), cand_b(), cand_c()
a.save(OUT / "a.png"); b.save(OUT / "b.png"); c.save(OUT / "c.png")

# 对比图：原始尺寸 + 60px 小尺寸排一行，看缩小后可读性
strip = Image.new("RGB", (S * 3 + 80, S + 60), (18, 18, 20))
for i, im in enumerate([a, b, c]):
    strip.paste(im, (i * (S + 40) + 40, 20))
    small = im.resize((60, 60), Image.LANCZOS)
    strip.paste(small, (i * (S + 40) + 40 + S // 2 - 30, S + 26))
strip.save(OUT / "compare.png")
print("written:", OUT)
