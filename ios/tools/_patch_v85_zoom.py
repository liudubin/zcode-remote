#!/usr/bin/env python3
# v85: 文字缩放改整页 zoom —— -webkit-text-size-adjust 在 WKWebView 上放大文字但容器
# 仍按原宽排版（气泡换行烂/溢出/部分场景无效）。改 documentElement+body 双挂 CSS zoom，
# 等比缩放整页布局，125%/150% 不再破排版，75% 同理生效。幂等，失败 exit 1。
import sys

PATH = 'ios/App/Sources/WebViewController.swift'

OLD = """    func textZoomJS() -> String {
        let z = settings.textZoom
        if z == 100 { return "document.documentElement.style.webkitTextSizeAdjust='';" }
        return "document.documentElement.style.webkitTextSizeAdjust='\\(z)%';"
    }"""

NEW = """    func textZoomJS() -> String {
        // v85：text-size-adjust 只放大文字不缩容器（换行烂/溢出），改整页 zoom 等比缩放
        let z = settings.textZoom
        let v = String(format: "%.2f", Double(z) / 100.0)
        if z == 100 {
            return "document.documentElement.style.zoom='';document.body&&(document.body.style.zoom='');"
        }
        return "document.documentElement.style.zoom='\\(v)';document.body&&(document.body.style.zoom='\\(v)');"
    }"""


def main():
    raw = open(PATH, 'rb').read().decode('utf-8')
    crlf = raw.count('\r\n')
    NL = '\r\n' if crlf > 50 else '\n'
    s = raw
    if 'v85' in s:
        print('SKIP v85: already applied')
        return
    old = NL.join(OLD.split('\n'))
    new = NL.join(NEW.split('\n'))
    n = s.count(old)
    if n != 1:
        print('FAILED: textZoomJS anchor %d hits (expect 1)' % n)
        sys.exit(1)
    s = s.replace(old, new)
    open(PATH, 'wb').write(s.encode('utf-8'))
    print('OK v85: textZoom->page zoom')


if __name__ == '__main__':
    main()
