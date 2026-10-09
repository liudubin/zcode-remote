/*
 * iOS 原生桥 shim：把 Android 版的 window.zcodeBridge 同步接口映射到 WKWebView 的
 * webkit.messageHandlers.zcodeBridge 异步消息通道（每帧都会注入，帧内直接可用）。
 *
 * 同步返回值（getTrace/getLogoPos）在 WKWebView 上无法同步回传，改为：
 * - 原生在 documentEnd 引导脚本里预注入快照（__zcodeNativeTrace / __zcodeLogoPos）；
 * - 事件（onReply 等）发生后原生用 evaluateJavaScript 刷新 __zcodeNativeTrace 快照。
 * 诊断卡取到的是最近一次快照，毫秒级新鲜度足够展示用。
 *
 * 由 WebViewController 在 documentStart 执行：__zcodeInstallBridge(logoPosJson, traceJson)
 */
function __zcodeInstallBridge(logoPos, nativeTrace) {
  if (window.zcodeBridge) { return; }
  window.__zcodeNativeTrace = nativeTrace || '[]';
  window.__zcodeLogoPos = logoPos || '';
  function post(fn) {
    return function () {
      var args = Array.prototype.slice.call(arguments);
      try {
        window.webkit.messageHandlers.zcodeBridge.postMessage({ fn: fn, args: args });
      } catch (e) {}
    };
  }
  window.zcodeBridge = {
    onReply: post('onReply'),
    onProgress: post('onProgress'),
    onTheme: post('onTheme'),
    onBars: post('onBars'),
    openSettings: post('openSettings'),
    saveLogoPos: post('saveLogoPos'),
    setGestureExclude: post('setGestureExclude'),
    getLogoPos: function () { return window.__zcodeLogoPos || ''; },
    getTrace: function () { return window.__zcodeNativeTrace || '[]'; }
  };
}
