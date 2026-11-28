#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# v87: fix double-zoom -- v85 mounted CSS zoom on BOTH html and body; CSS zoom
# compounds multiplicatively (html 1.5 * body 1.5 = 2.25x). Mount on documentElement only.
import sys

PATH = 'ios/App/Sources/WebViewController.swift'

OLD = """    func textZoomJS() -> String {
        // v85：text-size-adjust 只放大文字不缩容器（换行烂/溢出），改整页 zoom 等比缩放
        let z = settings.textZoom
        let v = String(format: "%.2f", Double(z) / 100.0)
        if z == 100 {
            return "document.documentElement.style.zoom='';document.body&&(document.body.style.zoom='');"
        }
        return "document.documentElement.style.zoom='\\(v)';document.body&&(document.body.style.zoom='\\(v)');"
    }"""

NEW = """    func textZoomJS() -> String {
        // v85→v87：zoom 只挂 documentElement——html+body 双挂复合相乘（150% 实际变 225%）
        let z = settings.textZoom
        let v = String(format: "%.2f", Double(z) / 100.0)
        if z == 100 {
            return "document.documentElement.style.zoom='';"
        }
        return "document.documentElement.style.zoom='\\(v)';"
    }"""


def main():
    raw = open(PATH, 'rb').read().decode('utf-8')
    NL = '\r\n' if raw.count('\r\n') > 50 else '\n'
    if 'v87' in raw:
        print('SKIP v87: already applied')
        return
    old = NL.join(OLD.split('\n'))
    new = NL.join(NEW.split('\n'))
    n = raw.count(old)
    if n != 1:
        print('FAILED: v87 anchor %d hits (expect 1)' % n)
        sys.exit(1)
    open(PATH, 'wb').write(raw.replace(old, new).encode('utf-8'))
    print('OK v87: single-mount zoom')


if __name__ == '__main__':
    main()
