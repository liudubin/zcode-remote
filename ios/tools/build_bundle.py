# -*- coding: utf-8 -*-
"""生成 iOS 注入资源 ios/App/Resources/ZCodeBundle.js（生成物，gitignore，CI/本地运行本脚本重建）。

与 Android 的 _patch_web2.py 同源同料：
- JS：dev/bundle/*.js 按文件名序拼接（剔除模块头注释），原样作为 IIFE 函数暴露为 window.__ZCODE_BUNDLE；
- CSS：从 WebActivity.kt 抽出 MOBILE_CSS / CSS_SCROLLBAR_HIDDEN / CSS_SCROLLBAR_SLIM 原文，
  以 JSON 字符串常量暴露，由 WebViewController 在 documentEnd 的引导脚本里作为 bundle 首参传入。

iOS 端不需要 JVM 常量池分段，单文件整段写入。
"""
import glob
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KT = os.path.join(ROOT, "app", "src", "main", "java", "com", "zcode", "remote", "WebActivity.kt")
OUT = os.path.join(ROOT, "ios", "App", "Resources", "ZCodeBundle.js")

web = open(KT, encoding="utf-8").read()


def raw_const(name):
    m = re.search(r'private const val ' + name + r' = """(.*?)"""', web, flags=re.S)
    if not m:
        raise SystemExit("const %s not found in WebActivity.kt" % name)
    return m.group(1)


mobile_css = raw_const("MOBILE_CSS")
scroll_hidden = raw_const("CSS_SCROLLBAR_HIDDEN")
scroll_slim = raw_const("CSS_SCROLLBAR_SLIM")

mods = sorted(glob.glob(os.path.join(ROOT, "dev", "bundle", "*.js")))
if not mods:
    raise SystemExit("no modules in dev/bundle/")
parts = []
for f in mods:
    with io.open(f, encoding="utf-8") as mf:
        for ln in mf.read().splitlines(keepends=True):
            if ln.startswith("// ===== "):
                continue
            parts.append(ln)
bundle = "".join(parts).strip()

js = (
    "// 由 ios/tools/build_bundle.py 生成（源：dev/bundle/ + WebActivity.kt），勿手改。\n"
    + "window.__ZCODE_CSS_BASE = %s;\n" % json.dumps(mobile_css)
    + "window.__ZCODE_SCROLLBAR_HIDDEN = %s;\n" % json.dumps(scroll_hidden)
    + "window.__ZCODE_SCROLLBAR_SLIM = %s;\n" % json.dumps(scroll_slim)
    + "window.__ZCODE_BUNDLE = " + bundle + ";\n"
)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(js)
print("ios bundle built from %d modules, %d bytes -> %s" % (len(mods), len(js.encode("utf-8")), os.path.relpath(OUT, ROOT)))
