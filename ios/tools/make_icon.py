# -*- coding: utf-8 -*-
"""生成 App 图标（1024x1024,单尺寸 asset）与入口页徽标符号（IconSymbol imageset）+ Android 全套 mipmap。

设计 v3「终端窗 · 霓虹」：亮绿→青对角渐变底（带暗角层次），
居中深色终端窗卡（三枚窗口点）+ 渐变发光 ">_" 终端符号，
2x 超采样抗锯齿。与旧版（黑底发光符）形成明确视觉区分。

性能注记：iSH/Aarch64 上纯 Python 逐像素循环不可用（4M+ 像素级循环要几分钟到几十分钟）。
渐变用 4x4 双线性放大（线性函数被双线性插值精确重建，数学无损），
模糊类效果一律小图算完再放大（高斯模糊是平滑场，放大无高频损失）。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios" / "App" / "Resources" / "Assets.xcassets"
APP_RES = ROOT / "app" / "src" / "main" / "res"

GREEN = (16, 216, 124)
CYAN = (18, 158, 200)
SYMBOL_GREEN = (64, 245, 168)
SYMBOL_CYAN = (38, 210, 235)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diag_gradient(size, c0, c1):
    """对角线性渐变：4x4 网格双线性放大即精确线性场。"""
    g = Image.new("RGB", (4, 4))
    for y in range(4):
        for x in range(4):
            g.putpixel((x, y), lerp(c0, c1, (x + y) / 6.0))
    return g.resize((size, size), Image.BILINEAR)


def glyph_mask(size):
    """>_ 符号蒙版：粗圆头线条，256 基准坐标按比例缩放。在 <=1024 上绘制后按需放大。"""
    s = size / 256.0
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    w = int(26 * s)
    rr = w / 2.0

    def seg(x1, y1, x2, y2):
        d.line([(x1 * s, y1 * s), (x2 * s, y2 * s)], fill=255, width=w, joint="curve")

    def cap(x, y):
        d.ellipse((x * s - rr, y * s - rr, x * s + rr, y * s + rr), fill=255)

    seg(64, 66, 126, 128)
    seg(126, 128, 64, 190)
    cap(64, 66)
    cap(126, 128)
    cap(64, 190)
    seg(148, 190, 204, 190)
    cap(148, 190)
    cap(204, 190)
    return m


def vignette(W):
    """暗角：512 上算完放大（平滑场）。"""
    vw = 512
    vin = Image.new("L", (vw, vw), 0)
    vd = ImageDraw.Draw(vin)
    vd.ellipse((-vw * 0.5, -vw * 0.5, vw * 0.4, vw * 0.4), fill=60)
    vd.ellipse((vw * 0.55, vw * 0.55, vw * 1.6, vw * 1.6), fill=70)
    vin = vin.filter(ImageFilter.GaussianBlur(48))
    return vin.resize((W, W), Image.BILINEAR)


def render_icon(S):
    """主图标：2x 超采样渲染后缩回 S。S<=512 时 W=2S，S=1024 时 W=1280（超采样比 1.25x 够抗锯齿且省时）。"""
    W = 1280 if S >= 1024 else S * 2
    img = diag_gradient(W, GREEN, CYAN).convert("RGBA")
    img = Image.composite(Image.new("RGBA", (W, W), (5, 60, 45, 255)), img, vignette(W))

    # 终端窗卡（居中偏上）+ 投影
    cw = int(W * 0.64)
    cx = (W - cw) // 2
    cy = int(W * 0.20)
    cr = int(cw * 0.22)
    sw = 256
    sh = Image.new("RGBA", (sw, sw), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle((sw * 0.2, sw * 0.2, sw * 0.8, sw * 0.8), radius=int(sw * 0.13),
                         fill=(0, 40, 30, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(14)).resize((W, W), Image.BILINEAR)
    # 投影相对卡位下移 2.2%
    off = int(W * 0.022)
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    layer.paste(sh, (0, off), sh)
    img = Image.alpha_composite(img, layer)

    card = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((cx, cy, cx + cw, cy + cw), radius=cr, fill=(10, 16, 14, 255))
    hl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.rounded_rectangle((cx, cy, cx + cw, cy + int(cw * 0.30)), radius=cr, fill=(210, 255, 235, 16))
    card = Image.alpha_composite(card, hl)
    img.paste(card, (0, 0), card)

    # 窗口点
    d = ImageDraw.Draw(img)
    dotr = int(W * 0.016)
    dy = cy + int(cw * 0.115)
    for i in range(3):
        dx = cx + int(cw * 0.09) + i * int(dotr * 4.4)
        d.ellipse((dx - dotr, dy - dotr, dx + dotr, dy + dotr), fill=(96, 110, 102, 255))

    # 渐变 ">_" + 内发光（mask 在 1024 绘制 → LANCZOS 到目标）
    gm = glyph_mask(1024)
    gbox = gm.getbbox()
    gm = gm.crop(gbox)
    gs = int(cw * 0.54)
    ratio = gs / gm.width
    gm = gm.resize((gs, max(1, int(gm.height * ratio))), Image.LANCZOS)
    full = Image.new("L", (W, W), 0)
    gx = cx + (cw - gm.width) // 2
    zone_top = cy + int(cw * 0.24)
    zone_h = int(cw * 0.62)
    gy = zone_top + (zone_h - gm.height) // 2
    full.paste(gm, (gx, gy))
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for blur_r, a in [(W // 80, 60), (W // 170, 80)]:
        small = 256
        sm = full.resize((small, small), Image.BILINEAR).filter(ImageFilter.GaussianBlur(max(1, blur_r * small // W)))
        big = sm.resize((W, W), Image.BILINEAR)
        lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        lay.paste(Image.new("RGBA", (W, W), (120, 255, 200, a)), (0, 0), big)
        glow = Image.alpha_composite(glow, lay)
    img = Image.alpha_composite(img, glow)
    img.paste(diag_gradient(W, SYMBOL_GREEN, SYMBOL_CYAN).convert("RGBA"), (0, 0), full)
    return img.convert("RGB").resize((S, S), Image.LANCZOS)


# ---------- iOS：AppIcon1024 + IconSymbol ----------
OUT = ASSETS / "AppIcon.appiconset" / "AppIcon1024.png"
OUT.parent.mkdir(parents=True, exist_ok=True)
render_icon(1024).save(OUT, "PNG")
print("icon written:", OUT.relative_to(ROOT))


def render_symbol(size):
    """入口页徽标：终端窗卡独立成画（透明四角），即"去底的图标"。"""
    W = size * 2
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cw = int(W * 0.92)
    cx = (W - cw) // 2
    cy = (W - cw) // 2
    cr = int(cw * 0.24)
    card = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((cx, cy, cx + cw, cy + cw), radius=cr, fill=(10, 16, 14, 255))
    hl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.rounded_rectangle((cx, cy, cx + cw, cy + int(cw * 0.30)), radius=cr, fill=(210, 255, 235, 16))
    card = Image.alpha_composite(card, hl)
    out = Image.alpha_composite(out, card)
    d = ImageDraw.Draw(out)
    dotr = int(W * 0.023)
    dy = cy + int(cw * 0.115)
    for i in range(3):
        dx = cx + int(cw * 0.09) + i * int(dotr * 4.4)
        d.ellipse((dx - dotr, dy - dotr, dx + dotr, dy + dotr), fill=(96, 110, 102, 255))
    gm = glyph_mask(1024)
    gbox = gm.getbbox()
    gm = gm.crop(gbox)
    gs = int(cw * 0.54)
    ratio = gs / gm.width
    gm = gm.resize((gs, max(1, int(gm.height * ratio))), Image.LANCZOS)
    full = Image.new("L", (W, W), 0)
    gx = cx + (cw - gm.width) // 2
    zone_top = cy + int(cw * 0.24)
    zone_h = int(cw * 0.62)
    gy = zone_top + (zone_h - gm.height) // 2
    full.paste(gm, (gx, gy))
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for blur_r, a in [(W // 90, 55), (W // 200, 75)]:
        small = 256
        sm = full.resize((small, small), Image.BILINEAR).filter(ImageFilter.GaussianBlur(max(1, blur_r * small // W)))
        big = sm.resize((W, W), Image.BILINEAR)
        lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        lay.paste(Image.new("RGBA", (W, W), (120, 255, 200, a)), (0, 0), big)
        glow = Image.alpha_composite(glow, lay)
    out = Image.alpha_composite(out, glow)
    out.paste(diag_gradient(W, SYMBOL_GREEN, SYMBOL_CYAN).convert("RGBA"), (0, 0), full)
    return out.convert("RGBA").resize((size, size), Image.LANCZOS)


SYMDIR = ASSETS / "IconSymbol.imageset"
SYMDIR.mkdir(parents=True, exist_ok=True)
render_symbol(256).save(SYMDIR / "IconSymbol@2x.png", "PNG")
render_symbol(384).save(SYMDIR / "IconSymbol@3x.png", "PNG")
(SYMDIR / "Contents.json").write_text(
    '{\n  "images": [\n    {"filename": "IconSymbol@2x.png", "idiom": "universal", "scale": "2x"},\n'
    '    {"filename": "IconSymbol@3x.png", "idiom": "universal", "scale": "3x"}\n  ],\n'
    '  "info": {"author": "xcode", "version": 1}\n}\n',
    encoding="utf-8",
)
print("symbol written:", SYMDIR.relative_to(ROOT))

# ---------- Android：legacy mipmap（方/圆 × 5 密度）+ 自适应前景 ----------
DENS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
master512 = render_icon(512)


def rounded(size):
    im = master512.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1),
                                           radius=int(size * 0.225), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def circle(size):
    im = master512.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


for dpi, px in DENS.items():
    d = APP_RES / f"mipmap-{dpi}"
    d.mkdir(parents=True, exist_ok=True)
    rounded(px).save(d / "ic_launcher.png", "PNG")
    circle(px).save(d / "ic_launcher_round.png", "PNG")
print("android mipmaps written")

# 自适应前景 432：徽标卡缩进安全区（内容占 ~80% 居中，卡本身含透明边）
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
inner = render_symbol(432).resize((int(432 * 0.80), int(432 * 0.80)), Image.LANCZOS)
fg.paste(inner, ((432 - inner.width) // 2, (432 - inner.height) // 2), inner)
FGDIR = APP_RES / "drawable-nodpi"
FGDIR.mkdir(parents=True, exist_ok=True)
fg.save(FGDIR / "ic_launcher_foreground.png", "PNG")
print("foreground written:", FGDIR.relative_to(ROOT))
