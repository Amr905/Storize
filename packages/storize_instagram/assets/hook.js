/*
 * Storize page-mode hook (T-002 spike; extended by T-014).
 *
 * Injected at document start. Wraps fetch and XMLHttpRequest and reports a
 * SUMMARY of every instagram.com JSON response to a flutter_inappwebview
 * handler: {url, status, bodyLength, topLevelKeys, origin, via[, friendlyName]}
 * (a response has no `type`; url has no query string unless includeBody is
 * true).
 * It never reads cookies and, by default, never sends response bodies.
 *
 * Configure BEFORE this script runs with:
 *   window.__STORIZE_HOOK_CONFIG = {
 *     handler: 'storizeHook',
 *     includeBody: false,            // true (T-014 only): adds `body`, full url
 *     includeRequestSecrets: false,  // true (T-014 only): adds `request`
 *                                    //   {docId, tokens} from the page's own
 *                                    //   GraphQL POST form; held in memory by
 *                                    //   Dart only, never logged
 *     blockedFriendlyNames: [...]    // see below
 *   };
 *
 * SEEN-MUTATION BLOCKING (UD-3, BR-8). Opening a story page makes the page fire
 * PolarisStoriesV3SeenMutation, which marks the story as seen for its owner.
 * Any fetch / XHR / sendBeacon to instagram.com whose form body has
 * `fb_api_req_friendly_name` equal to a name in `blockedFriendlyNames` is
 * answered LOCALLY (a fake 200 JSON reply) and is NEVER SENT. The name is
 * matched, not the doc_id (which rotates). Default list when the config omits
 * it: ['PolarisStoriesV3SeenMutation'] (fail safe). Each block posts
 * {type:'blocked', friendlyName, origin, via} so Dart can count it.
 * The hook never clicks, taps or scrolls anything in the page.
 */
(function () {
  'use strict';
  if (window.__storizeHookInstalled) return;
  window.__storizeHookInstalled = true;

  var cfg = window.__STORIZE_HOOK_CONFIG || {};
  var handler = cfg.handler || 'storizeHook';
  var includeBody = cfg.includeBody === true;
  var includeRequestSecrets = cfg.includeRequestSecrets === true;
  var blockedNames = Array.isArray(cfg.blockedFriendlyNames)
    ? cfg.blockedFriendlyNames.map(String)
    : ['PolarisStoriesV3SeenMutation'];

  var NAME_KEY = 'fb_api_req_friendly_name';
  // Form fields that are the request itself, not a page token.
  var NOT_TOKENS = { doc_id: 1, variables: 1, fb_api_req_friendly_name: 1 };
  var MAX_TOKENS = 80;
  var MAX_TOKEN_LENGTH = 16384;
  var BLOCKED_REPLY = '{"data":{},"extensions":{"is_final":true},"status":"ok"}';

  function isInstagram(url) {
    try {
      var h = new URL(url, location.href).hostname;
      return h === 'instagram.com' || h.slice(-14) === '.instagram.com';
    } catch (e) {
      return false;
    }
  }

  function post(msg) {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler(handler, msg);
      }
    } catch (e) {
      /* never break the page */
    }
  }

  // The form of a string or URLSearchParams body; null for anything else
  // (FormData, Blob, streams are not inspected).
  function formOf(body) {
    try {
      if (typeof body === 'string') return new URLSearchParams(body);
      if (typeof URLSearchParams !== 'undefined' && body instanceof URLSearchParams) {
        return body;
      }
    } catch (e) {}
    return null;
  }

  function friendlyNameOf(body) {
    try {
      var form = formOf(body);
      var name = form ? form.get(NAME_KEY) : null;
      return name ? String(name) : null;
    } catch (e) {
      return null;
    }
  }

  function isBlockedName(name) {
    return !!name && blockedNames.indexOf(name) !== -1;
  }

  // {docId, tokens} of the page's own request, or null. Only when configured.
  function requestInfoOf(body) {
    if (!includeRequestSecrets) return null;
    try {
      var form = formOf(body);
      if (!form) return null;
      var tokens = {};
      var count = 0;
      form.forEach(function (value, key) {
        if (NOT_TOKENS[key] || count >= MAX_TOKENS) return;
        if (value.length === 0 || value.length > MAX_TOKEN_LENGTH) return;
        tokens[key] = value;
        count++;
      });
      return { docId: form.get('doc_id') || null, tokens: tokens };
    } catch (e) {
      return null;
    }
  }

  function notifyBlocked(name, via) {
    post({ type: 'blocked', friendlyName: name, origin: location.origin, via: via });
  }

  function report(url, status, text, via, friendlyName, requestInfo) {
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
        // Query strings can carry signed params or ids: only T-014 (which sets
        // includeBody) gets the full URL.
        url: includeBody ? absolute : absolute.split('?')[0],
        status: status,
        bodyLength: text.length,
        topLevelKeys: keys,
        origin: location.origin,
        via: via,
      };
      if (friendlyName) msg.friendlyName = friendlyName;
      if (includeBody) msg.body = text;
      if (requestInfo) msg.request = requestInfo;
      post(msg);
    } catch (e) {
      /* never break the page */
    }
  }

  // ------------------------------------------------------------------ fetch
  var origFetch = window.fetch;
  if (typeof origFetch === 'function') {
    window.fetch = function (input, init) {
      var url = null;
      var name = null;
      var info = null;
      try {
        url = typeof input === 'string' ? input : input && input.url;
        var body = init && init.body;
        if (url && isInstagram(url)) {
          name = friendlyNameOf(body);
          if (isBlockedName(name)) {
            notifyBlocked(name, 'fetch');
            return Promise.resolve(
              new Response(BLOCKED_REPLY, {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
              })
            );
          }
          info = requestInfoOf(body);
        }
      } catch (e) {}
      var p = origFetch.apply(this, arguments);
      try {
        if (url && isInstagram(url)) {
          p.then(
            function (res) {
              try {
                res.clone().text().then(function (t) {
                  report(res.url || url, res.status, t, 'fetch', name, info);
                });
              } catch (e) {}
            },
            function () {}
          );
        }
      } catch (e) {}
      return p;
    };
  }

  // -------------------------------------------------------------------- XHR
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    try {
      this.__storizeUrl = url;
    } catch (e) {}
    return origOpen.apply(this, arguments);
  };

  // Makes [xhr] look finished with the local reply, without sending anything.
  function answerLocally(xhr, url) {
    var json = BLOCKED_REPLY;
    var value = xhr.responseType === 'json' ? JSON.parse(json) : json;
    var fields = {
      readyState: 4,
      status: 200,
      statusText: 'OK',
      response: value,
      responseText: xhr.responseType === '' || xhr.responseType === 'text' ? json : '',
      responseURL: String(url),
    };
    Object.keys(fields).forEach(function (k) {
      Object.defineProperty(xhr, k, { value: fields[k], configurable: true });
    });
    setTimeout(function () {
      ['readystatechange', 'load', 'loadend'].forEach(function (type) {
        try {
          xhr.dispatchEvent(new Event(type));
        } catch (e) {}
      });
    }, 0);
  }

  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function (body) {
    var xhr = this;
    var name = null;
    var info = null;
    try {
      if (xhr.__storizeUrl && isInstagram(String(xhr.__storizeUrl))) {
        name = friendlyNameOf(body);
        if (isBlockedName(name)) {
          notifyBlocked(name, 'xhr');
          answerLocally(xhr, xhr.__storizeUrl);
          return undefined;
        }
        info = requestInfoOf(body);
        xhr.addEventListener('loadend', function () {
          try {
            var t = '';
            if (xhr.responseType === '' || xhr.responseType === 'text') {
              t = xhr.responseText || '';
            } else if (xhr.responseType === 'json' && xhr.response) {
              t = JSON.stringify(xhr.response);
            }
            if (t) {
              report(xhr.responseURL || xhr.__storizeUrl, xhr.status, t, 'xhr', name, info);
            }
          } catch (e) {}
        });
      }
    } catch (e) {}
    return origSend.apply(this, arguments);
  };

  // ------------------------------------------------------------- sendBeacon
  if (typeof navigator !== 'undefined' && typeof navigator.sendBeacon === 'function') {
    var origBeacon = navigator.sendBeacon;
    navigator.sendBeacon = function (url, data) {
      try {
        if (url && isInstagram(String(url)) && isBlockedName(friendlyNameOf(data))) {
          notifyBlocked(friendlyNameOf(data), 'beacon');
          return true; // "queued"; nothing is sent
        }
      } catch (e) {}
      return origBeacon.apply(this, arguments);
    };
  }
})();
