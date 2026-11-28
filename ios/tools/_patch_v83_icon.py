#!/usr/bin/env python3
# v83: ①左下角收纳图标 自由拖动+磁吸回弹 ②morphReveal/morphMinimize 弹性过冲曲线（磁吸语言统一）
# CRLF 文件；幂等；断言每处唯一命中后才写盘。
import sys
P = 'dev/bundle/06_composer.js'
s = open(P, 'rb').read().decode('utf-8')
NL = '\r\n'
fails = []

def sub1(old, new, tag):
    global s
    if new in s:
        print('SKIP (already applied):', tag); return
    n = s.count(old)
    if n != 1:
        fails.append(f'{tag}: {n} hits'); return
    s = s.replace(old, new)
    print('OK:', tag)

def T(lines):
    return NL.join(lines)

# ---------- 1. v83 函数块：插在 iconRelease 之后 ----------
old1 = T([
"    function iconRelease(ic){",
"      if (!ic) { return; }",
"      ic.style.transition = '';",
"      ic.style.transform = '';",
"    }",
])
new1 = T([
"    function iconRelease(ic){",
"      if (!ic) { return; }",
"      ic.style.transition = '';",
"      ic.style.transform = '';",
"    }",
"    // ---------- v83 图标自由拖动 + 磁吸回弹 ----------",
"    // 拖动中 left/top 已固化（iconDragBegin），transform 只承载偏移（合成层，零 layout）；",
"    // 松手按最近屏幕竖边磁吸 + cubic-bezier 过冲弹簧落位，位置记 localStorage 下次复用。",
"    // tap 唤出 / 上滑唤出 / 右滑导航三条手势全保留（意图锁定：纯右=导航、直上=唤出、其余=拖动）。",
"    var ICON_HOME = null;   // 最近磁吸落点（左上角坐标 {x,y}）；null = 默认左下角",
"    function iconLoadPos(){",
"      if (ICON_HOME) { return iconClamp(ICON_HOME.x, ICON_HOME.y); }",
"      return { x: 12, y: window.innerHeight - 56 - safeB() };",
"    }",
"    function iconClamp(x, y){",
"      var m = 8, w = 44, h = 44;",
"      var maxX = Math.max(m, window.innerWidth - w - m);",
"      var maxY = Math.max(m, window.innerHeight - safeB() - h - m);",
"      return { x: Math.min(Math.max(x, m), maxX), y: Math.min(Math.max(y, m), maxY) };",
"    }",
"    function iconDragBegin(ic){",
"      if (!ic) { return; }",
"      var r = rectOf(ic);",
"      try {",
"        ic.style.transition = 'none';",
"        ic.style.left = r.x + 'px'; ic.style.right = 'auto';",
"        ic.style.top = r.y + 'px'; ic.style.bottom = 'auto';",
"        ic.style.transform = '';",
"      } catch (e0) {}",
"      iconTrack.bx = r.x; iconTrack.by = r.y;   // 锚点 = 手势起点视觉位置",
"    }",
"    function iconDragTo(ic, tx, ty){",
"      if (!ic || !iconTrack) { return; }",
"      var p = iconClamp(tx, ty);",
"      ic.style.transform = 'translate(' + (p.x - iconTrack.bx).toFixed(1) + 'px,' + (p.y - iconTrack.by).toFixed(1) + 'px)';",
"    }",
"    function iconApplyHome(ic){",
"      // 恢复记忆位（无记录=默认左下角）：固化 left/top、清 transform；越界自动夹回",
"      if (!ic) { return; }",
"      var p = iconLoadPos();",
"      try {",
"        ic.style.transition = 'none';",
"        ic.style.left = p.x + 'px'; ic.style.right = 'auto';",
"        ic.style.top = p.y + 'px'; ic.style.bottom = 'auto';",
"        ic.style.transform = '';",
"      } catch (e1) {}",
"    }",
"    function iconMagnetSnap(ic){",
"      if (!ic) { return; }",
"      var r = rectOf(ic);",
"      var p = iconClamp(r.x, r.y);",
"      var leftX = 12, rightX = Math.max(leftX, window.innerWidth - 44 - 12);",
"      p.x = Math.abs(p.x - leftX) <= Math.abs(p.x - rightX) ? leftX : rightX;   // 磁吸最近竖边",
"      ICON_HOME = p;",
"      try { localStorage.setItem('zcode-icon-pos', JSON.stringify(p)); } catch (e2) {}",
"      if (!ANIM_ON || REDUCED) { iconApplyHome(ic); return; }",
"      // 弹簧：从当前偏移过冲过渡到目标（撞边→回弹→贴住的磁吸手感）",
"      var ax = parseFloat(ic.style.left) || leftX;",
"      var ay = parseFloat(ic.style.top) || 0;",
"      try {",
"        ic.style.transition = 'transform 420ms cubic-bezier(0.3,1.4,0.5,1)';",
"        ic.style.transform = 'translate(' + (p.x - ax).toFixed(1) + 'px,' + (p.y - ay).toFixed(1) + 'px)';",
"      } catch (e3) { iconApplyHome(ic); return; }",
"      setTimeout(function(){",
"        try { if (ic.parentNode) { iconApplyHome(ic); } } catch (e4) {}",
"      }, 450);",
"    }",
])
sub1(old1, new1, 'v83-block')

# ---------- 2. iconMove：意图锁定 + drag 分支 ----------
old2 = T([
"    function iconMove(e){",
"      if (!iconTrack || iconTrack.done) { return; }",
"      var t = evXY(e);",
"      var dx = t.clientX - iconTrack.x, dy = t.clientY - iconTrack.y;",
"      iconFeedback(e.currentTarget, dx, dy);",
])
new2 = T([
"    function iconMove(e){",
"      if (!iconTrack || iconTrack.done) { return; }",
"      var t = evXY(e);",
"      var dx = t.clientX - iconTrack.x, dy = t.clientY - iconTrack.y;",
"      var adx = Math.abs(dx), ady = Math.abs(dy);",
"      // v83 意图锁定：纯右滑=导航、直上滑=唤出、其余方向=自由拖动（锁一次不再改判）",
"      if (!iconTrack.dir && (adx > 22 || ady > 22)) {",
"        if (dx > 22 && ady < 24) { iconTrack.dir = 'right'; }",
"        else if (dy < -22 && adx < 24) { iconTrack.dir = 'up'; }",
"        else { iconTrack.dir = 'drag'; iconDragBegin(e.currentTarget); vibrate(); uiLog('icon-drag'); }",
"      }",
"      if (iconTrack.dir === 'drag') {",
"        e.preventDefault();",
"        iconDragTo(e.currentTarget, (iconTrack.bx || 0) + dx, (iconTrack.by || 0) + dy);",
"        return;",
"      }",
"      iconFeedback(e.currentTarget, dx, dy);",
])
sub1(old2, new2, 'iconMove-head')

old3 = T([
"      if (dx > 48 && Math.abs(dy) < 40) {",
])
new3 = T([
"      if (iconTrack.dir !== 'up' && dx > 48 && Math.abs(dy) < 40) {",
])
sub1(old3, new3, 'guard-right')

# iconMove 内的上滑分支（前面是 toggleNavigator 行，避免误中 dock 手势的同款判断）
old4 = T([
"        else { toggleNavigator(); }",
"      } else if (dy < -44 && Math.abs(dx) < 40) {",
])
new4 = T([
"        else { toggleNavigator(); }",
"      } else if (iconTrack.dir !== 'right' && dy < -44 && Math.abs(dx) < 40) {",
])
sub1(old4, new4, 'guard-up')

# ---------- 3. iconEnd：drag 松手走磁吸 ----------
old5 = T([
"      var ic = e.currentTarget;",
"      if (tr.done) {",
"        if (tr.dir !== 'up') { iconRelease(ic); }",
"        return;",
"      }",
])
new5 = T([
"      var ic = e.currentTarget;",
"      if (tr.dir === 'drag') { iconMagnetSnap(ic); return; }   // v83：拖动松手=磁吸回弹落位",
"      if (tr.done) {",
"        if (tr.dir !== 'up') { iconRelease(ic); }",
"        return;",
"      }",
])
sub1(old5, new5, 'iconEnd-drag')

# ---------- 4. iconHomeRect 用记忆位 ----------
old6 = T([
"    function iconHomeRect(){",
"      // 收纳图标悬浮位（CSS: left:12px bottom:12px+安全区，44px）",
"      return { x: 12, y: window.innerHeight - 56 - safeB(), w: 44, h: 44 };",
"    }",
])
new6 = T([
"    function iconHomeRect(){",
"      // v83：收纳图标可拖动+磁吸记忆——家 = 最近磁吸落点（无记录 = CSS 默认左下角）",
"      var p = iconLoadPos();",
"      return { x: p.x, y: p.y, w: 44, h: 44 };",
"    }",
])
sub1(old6, new6, 'iconHomeRect')

# ---------- 5. ensureIcon 复出时恢复记忆位 ----------
old7 = T([
"      ic.style.display = 'flex';",
"      ic.style.transform = '';   // v69：清掉上次手势的跟手偏移，图标每次复出都从原位开始",
])
new7 = T([
"      ic.style.display = 'flex';",
"      iconApplyHome(ic);   // v83：清跟手偏移并恢复磁吸记忆位（无记录=默认左下角）",
])
sub1(old7, new7, 'ensureIcon-home')

# ---------- 6. morphGhost 加 snap 弹性曲线参数 ----------
old8 = T([
"    function morphGhost(pill, from, to, dur, radiusEnd, settle){",
])
new8 = T([
"    function morphGhost(pill, from, to, dur, radiusEnd, settle, snap){",
])
sub1(old8, new8, 'morphGhost-sig')

old9 = T([
"      var ease = ' cubic-bezier(0.2,0.8,0.2,1)';",
])
new9 = T([
"      var ease = snap ? ' cubic-bezier(0.34,1.35,0.64,1)' : ' cubic-bezier(0.2,0.8,0.2,1)';   // v83：snap=过冲回弹",
])
sub1(old9, new9, 'morphGhost-ease')

# ---------- 7. morphReveal（打开）传 snap=true，320ms ----------
old10 = T([
"      morphGhost(pill, from, to, 280, rad, function(){",
"        pillMorphCleanup(dock, pill);",
"        pillChildrenFade(pill, '1', 0.12, 0);",
"        if (after) { after(); }",
"      });",
])
new10 = T([
"      morphGhost(pill, from, to, 320, rad, function(){",
"        pillMorphCleanup(dock, pill);",
"        pillChildrenFade(pill, '1', 0.12, 0);",
"        if (after) { after(); }",
"      }, true);   // v83：打开=磁吸弹性（胶囊过冲长大再回弹落位）",
])
sub1(old10, new10, 'reveal-snap')

# ---------- 8. morphMinimize（收纳）传 snap=true，300ms ----------
old11 = T([
"      morphGhost(pill, from, to, 260, '50%', function () {",
])
new11 = T([
"      morphGhost(pill, from, to, 300, '50%', function () {",
])
sub1(old11, new11, 'minimize-dur')
# minimize 的 snap：闭包末尾 `    });` 在 morphMinimize 内——用 holeBurst 行锚定其后的调用收尾
old12 = T([
"        uiLog('composer-hide');",
"      });",
])
new12 = T([
"        uiLog('composer-hide');",
"      }, true);   // v83：收纳=磁吸弹性（吸回图标位，过冲贴附）",
])
sub1(old12, new12, 'minimize-snap')

# morphFlip（浮动⇄全屏）保持原曲线：闭包以 pillChildrenFade 行结尾、无 after——需确认不被 minimize-snap 误改
# （morphFlip 的收尾是 `      });` 且前面是 pillChildrenFade 行，old12 锚的是 uiLog('composer-hide')，安全）

if fails:
    print('FAILED:', fails)
    sys.exit(1)
open(P, 'wb').write(s.encode('utf-8'))
print('written', P)
