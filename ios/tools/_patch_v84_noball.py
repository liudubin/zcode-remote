#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# v84: remove composer icon (float ball); recall via auto-reveal + bottom-edge swipe
import sys

P = 'dev/bundle/06_composer.js'
NL = '\r\n'
s = open(P, 'rb').read().decode('utf-8')
fails = []

def sub1(tag, old, new, expect=1):
    global s
    old = NL.join(old.split('\n'))
    new = NL.join(new.split('\n'))
    n = s.count(old)
    if n != expect:
        fails.append('%s: %d hits (expect %d)' % (tag, n, expect))
        return
    s = s.replace(old, new, 1)

if 'v84' in s:
    print('SKIP already applied')
    sys.exit(0)

# 1) ensureIcon: drop ball element, bail out before creation logic
sub1('ensureIcon-bail',
"""      if (composerOpen || dock.classList.contains('zcode-popup-mode') ||""",
"""      // v84: floating ball removed -- minimized state has no UI; recall = scroll-to-bottom auto reveal / bottom-edge swipe-up
      if (ic && ic.parentNode) { ic.parentNode.removeChild(ic); }
      updateGestureExclude();
      return;
      if (composerOpen || dock.classList.contains('zcode-popup-mode') ||""")

# 2) iconHomeRect: minimize target = off-screen bottom center (replace code lines only)
sub1('homeRect-offscreen',
"""      var p = iconLoadPos();
      return { x: p.x, y: p.y, w: 44, h: 44 };""",
"""      var x = Math.max(12, (window.innerWidth - 44) / 2);
      return { x: x, y: window.innerHeight + 64, w: 44, h: 44 };""")

# 3) restore thresholds: 4000 -> 2500ms cooldown, 220px -> 120px
sub1('restore-cooldown',
"""      if (lastMinAt && Date.now() - lastMinAt < 4000) { return; }""",
"""      if (lastMinAt && Date.now() - lastMinAt < 2500) { return; }""")
sub1('restore-dist',
"""      if (dist <= 28 && minUpDist >= 220) {""",
"""      if (dist <= 28 && minUpDist >= 120) {""")

# 4) bottom-edge swipe-up recall gesture: functions before dockGestureEnd
sub1('edge-funcs',
"""    function dockGestureEnd(e){""",
"""    // v84 bottom-edge swipe-up recall (active entry point after ball removal):
    // start within bottom 24px band, vertical up-swipe >56px, release >100px above bottom edge.
    // passive listeners only -- never blocks timeline scrolling.
    var edgeTrack = null;
    function edgeStart(e){
      if (composerOpen || !doc.documentElement.classList.contains('zcode-float-on')) { edgeTrack = null; return; }
      var t = e.changedTouches && e.changedTouches[0];
      if (!t || t.clientY < window.innerHeight - 24) { edgeTrack = null; return; }
      edgeTrack = { x: t.clientX, y: t.clientY };
    }
    function edgeEnd(e){
      var tr = edgeTrack;
      if (!tr) { return; }
      edgeTrack = null;
      var t = e.changedTouches && e.changedTouches[0];
      if (!t) { return; }
      var dx = t.clientX - tr.x, dy = t.clientY - tr.y;
      if (dy < -56 && Math.abs(dy) > Math.abs(dx) * 1.5 && t.clientY < window.innerHeight - 100) {
        if (lastMinAt && Date.now() - lastMinAt < 1500) { return; }
        try { vibrate(); } catch (e1) {}
        showComposer();
      }
    }
    function dockGestureEnd(e){""")

# 5) attach edge listeners next to dock gesture ones
sub1('edge-listeners',
"""      evRoot.addEventListener('pointerup', dockGesturePtrUp, {passive:true});""",
"""      evRoot.addEventListener('pointerup', dockGesturePtrUp, {passive:true});
      evRoot.addEventListener('touchstart', edgeStart, {passive:true});
      evRoot.addEventListener('touchend', edgeEnd, {passive:true});""")

if fails:
    print('FAILED:', fails)
    sys.exit(1)
open(P, 'wb').write(NL.join(s.split('\n')).encode('utf-8'))
print('OK v84: ' + ', '.join(['ensureIcon-bail','homeRect-offscreen','restore-cooldown','restore-dist','edge-funcs','edge-listeners']))
print('written', P)
