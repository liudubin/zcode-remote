#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# v88: 删除「纯黑 AMOLED」设置行 + WebVC 下发强制 false（功能保留、入口移除）
import sys

fails = []

def patch(path, old, new, tag, expect=1):
    raw = open(path, 'rb').read().decode('utf-8')
    NL = '\r\n' if raw.count('\r\n') > 50 else '\n'
    o = NL.join(old.split('\n'))
    n = NL.join(new.split('\n'))
    k = raw.count(o)
    if k != expect:
        fails.append('%s: %s %d hits (expect %d)' % (path, tag, k, expect))
        return
    open(path, 'wb').write(raw.replace(o, n).encode('utf-8'))
    print('OK', path, tag)

# ---- 1) SettingsViewController.swift: 删「纯黑 AMOLED」行 ----
patch('ios/App/Sources/SettingsViewController.swift',
"""            (Section.page, Row(title: "纯黑 AMOLED", subtitle: "实验", icon: "moon.fill",
                               boolKey: ({ $0.amoledBlack }, { $0.amoledBlack = $1 }), segmented: nil, opensDetail: false)),
""",
"",
'tag88a')

# ---- 2) WebViewController.swift: 三处强制 false ----
patch('ios/App/Sources/WebViewController.swift',
""""amoledBlack":\\(settings.amoledBlack),""",
""""amoledBlack":false,""",
'tag88b')
patch('ios/App/Sources/WebViewController.swift',
"""            s.restoreOnBottom, s.sendMinimize, s.amoledBlack,""",
"""            s.restoreOnBottom, s.sendMinimize, false,""",
'tag88c')
patch('ios/App/Sources/WebViewController.swift',
"""            "\\"amoledBlack\\":\\(s.amoledBlack)," +""",
"""            "\\"amoledBlack\\":false," +""",
'tag88d')

if fails:
    print('FAILED:', fails)
    sys.exit(1)
print('v88 all applied')
