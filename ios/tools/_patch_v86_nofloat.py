#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# v86: 取消悬浮输入框（iOS 强制下发 floatInput=false + 删设置行）+
#      原生输入框抬高 12px（html:not(.zcode-float-on) dock padding-bottom）
import sys

fails = []

def patch(path, old, new, tag, expect=1):
    raw = open(path, 'rb').read().decode('utf-8')
    NL = '\r\n' if raw.count('\r\n') > 50 else '\n'
    if tag in raw:
        print('SKIP', path)
        return
    o = NL.join(old.split('\n'))
    n = NL.join(new.split('\n'))
    k = raw.count(o)
    if k != expect:
        fails.append('%s: %s %d hits (expect %d)' % (path, tag, k, expect))
        return
    open(path, 'wb').write(raw.replace(o, n).encode('utf-8'))
    print('OK', path, tag)

# ---- 1) WebViewController.swift: 三处 floatingInput 强制 false ----
W = 'ios/App/Sources/WebViewController.swift'
patch(W,
"""try { (window.__ZCODE_BUNDLE)(css, \\(settings.turnNavigator), \\(settings.notifyReply), \\(settings.floatingInput), true, {noBroadcast:true}); }""",
"""try { (window.__ZCODE_BUNDLE)(css, \\(settings.turnNavigator), \\(settings.notifyReply), false, true, {noBroadcast:true}); }""",
'tag86a')
patch(W,
"""            s.hideScrollbar, s.turnNavigator, s.notifyReply, s.floatingInput,""",
"""            s.hideScrollbar, s.turnNavigator, s.notifyReply, false,""",
'tag86b')
patch(W,
"""            "\\"floatInput\\":\\(s.floatingInput)," +""",
"""            "\\"floatInput\\":false," +""",
'tag86c')

# ---- 2) SettingsViewController.swift: 删「浮动输入框」设置行 ----
patch('ios/App/Sources/SettingsViewController.swift',
"""            (Section.page, Row(title: "浮动输入框", subtitle: "增强 UI 总开关", icon: "keyboard",
                               boolKey: ({ $0.floatingInput }, { $0.floatingInput = $1 }), segmented: nil, opensDetail: false)),
""",
"",
'tag86d')

# ---- 3) 02_style.js: 原生 dock 抬高 12px ----
patch('dev/bundle/02_style.js',
"""        'html.zcode-float-on [data-v4-composer-dock="true"]:not(.zcode-composer-float)' +
        ':not(.zcode-composer-full):not(.zcode-popup-mode) [data-testid="v4-composer"]{display:none!important}' +""",
"""        // v86: 原生输入框整体抬高 12px
        'html:not(.zcode-float-on) [data-v4-composer-dock="true"]{padding-bottom:12px!important}' +
        'html.zcode-float-on [data-v4-composer-dock="true"]:not(.zcode-composer-float)' +
        ':not(.zcode-composer-full):not(.zcode-popup-mode) [data-testid="v4-composer"]{display:none!important}' +""",
'tag86e')

if fails:
    print('FAILED:', fails)
    sys.exit(1)
print('v86 all applied')
