/*
 * Storize page-mode hook (T-002 spike; reused by T-014).
 *
 * Injected at document start. Wraps fetch and XMLHttpRequest and reports a
 * SUMMARY of every instagram.com JSON response to a flutter_inappwebview
 * handler: {url, status, bodyLength, topLevelKeys, origin, via}.
 * It never reads cookies and, by default, never sends response bodies.
 *
 * Configure BEFORE this script runs with:
 *   window.__STORIZE_HOOK_CONFIG = { handler: 'storizeHook', includeBody: false };
 * `includeBody: true` (T-014 only) adds a `body` string to the message.
 */
(function () {
  'use strict';
  if (window.__storizeHookInstalled) return;
  window.__storizeHookInstalled = true;

  var cfg = window.__STORIZE_HOOK_CONFIG || {};
  var handler = cfg.handler || 'storizeHook';
  var includeBody = cfg.includeBody === true;

  function isInstagram(url) {
    try {
      var h = new URL(url, location.href).hostname;
      return h === 'instagram.com' || h.slice(-14) === '.instagram.com';
    } catch (e) {
      return false;
    }
  }

  function report(url, status, text, via) {
    try {
      var absolute = new URL(url, location.href).href.split('#')[0];
      var keys = [];
      var parsed = null;
      try {
        if (text.indexOf('for (;;);') === 0) text = text.slice(9);
        parsed = JSON.parse(text);
      } catch (e) {
        return; // not JSON: ignore
      }
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        keys = Object.keys(parsed).slice(0, 50);
      } else if (Array.isArray(parsed)) {
        keys = ['<array:' + parsed.length + '>'];
      }
      var msg = {
        url: absolute,
        status: status,
        bodyLength: text.length,
        topLevelKeys: keys,
        origin: location.origin,
        via: via,
      };
      if (includeBody) msg.body = text;
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler(handler, msg);
      }
    } catch (e) {
      /* never break the page */
    }
  }

  var origFetch = window.fetch;
  if (typeof origFetch === 'function') {
    window.fetch = function (input, init) {
      var p = origFetch.apply(this, arguments);
      try {
        var url = typeof input === 'string' ? input : input && input.url;
        if (url && isInstagram(url)) {
          p.then(function (res) {
            try {
              res.clone().text().then(function (t) {
                report(res.url || url, res.status, t, 'fetch');
              });
            } catch (e) {}
          }, function () {});
        }
      } catch (e) {}
      return p;
    };
  }

  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    try {
      this.__storizeUrl = url;
    } catch (e) {}
    return origOpen.apply(this, arguments);
  };
  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function () {
    try {
      var xhr = this;
      if (xhr.__storizeUrl && isInstagram(String(xhr.__storizeUrl))) {
        xhr.addEventListener('loadend', function () {
          try {
            var t = '';
            if (xhr.responseType === '' || xhr.responseType === 'text') {
              t = xhr.responseText || '';
            } else if (xhr.responseType === 'json' && xhr.response) {
              t = JSON.stringify(xhr.response);
            }
            if (t) report(xhr.responseURL || xhr.__storizeUrl, xhr.status, t, 'xhr');
          } catch (e) {}
        });
      }
    } catch (e) {}
    return origSend.apply(this, arguments);
  };
})();
