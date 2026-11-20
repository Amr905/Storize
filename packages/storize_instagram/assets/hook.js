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
 * SEEN-MUTATION BLOCKING (UD-3, BR-8) - FAILS CLOSED. Opening a story page
 * makes the page fire PolarisStoriesV3SeenMutation, which marks the story as
 * seen for its owner and cannot be undone. For every fetch / XHR / sendBeacon
 * to instagram.com the hook builds a TEXT of everything the request carries:
 *   - the URL, including its query;
 *   - every header name and value (fetch init, a Request object, XHR
 *     setRequestHeader);
 *   - the body as text, whatever its form: string, URLSearchParams, FormData,
 *     Blob, ArrayBuffer / typed array, JSON, or the body of a Request object
 *     (read through clone(); async bodies are read BEFORE deciding).
 * The text is scanned (case-insensitive, also after URL-decoding) for the
 * blocked names. A match is answered LOCALLY (a fake 200 JSON reply of the
 * right type) and NEVER SENT. The name is matched, not the doc_id (which
 * rotates).
 * Blocked names = PolarisStoriesV3SeenMutation (ALWAYS, a config cannot remove
 * it) + the legacy markers xdt_mark_story_reel_seen and /stories/reel/seen +
 * the names in blockedFriendlyNames (a config can only ADD names).
 * Unreadable bodies: a body that cannot be read as text (a ReadableStream, or
 * a read that fails) sent to a URL whose path contains "graphql" cannot be
 * ruled out, so it is BLOCKED. Ordinary queries have string bodies, so
 * nothing the extractor needs is affected. Other unreadable requests pass.
 * Each block posts {type:'blocked', friendlyName, origin, via} so Dart can
 * count it. The hook never clicks, taps or scrolls anything in the page.
 * Not covered (device test): Worker / service-worker contexts and a realm
 * taken from a fresh iframe; Dart's canary (seen_block_leak) detects a leak.
 */
(function () {
  'use strict';
  if (window.__storizeHookInstalled) return;
  window.__storizeHookInstalled = true;

  var cfg = window.__STORIZE_HOOK_CONFIG || {};
  var handler = cfg.handler || 'storizeHook';
  var includeBody = cfg.includeBody === true;
  var includeRequestSecrets = cfg.includeRequestSecrets === true;
  // ALWAYS blocked; a config can add names, never remove these.
  var DEFAULT_BLOCKED = ['PolarisStoriesV3SeenMutation'];
  var MARKERS = ['xdt_mark_story_reel_seen', '/stories/reel/seen'];
  var blockedNames = DEFAULT_BLOCKED.slice();
  if (Array.isArray(cfg.blockedFriendlyNames)) {
    cfg.blockedFriendlyNames.forEach(function (n) {
      n = String(n);
      if (n && blockedNames.indexOf(n) === -1) blockedNames.push(n);
    });
  }
  var needles = blockedNames.concat(MARKERS).map(function (n) {
    return { raw: n, lower: n.toLowerCase() };
  });
  var UNREADABLE = { unreadable: true };

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

  // -------------------------------------------------- reading the request
  function isThenable(x) {
    return !!x && typeof x.then === 'function';
  }
  function isParams(b) {
    return Object.prototype.toString.call(b) === '[object URLSearchParams]';
  }
  function isStreamLike(b) {
    return !!b && typeof b === 'object' && typeof b.getReader === 'function';
  }

  // The text of a body: a string, a Promise of a string, or UNREADABLE.
  function bodyText(body) {
    if (body === undefined || body === null) return '';
    if (typeof body === 'string') return body;
    try {
      if (isParams(body)) return body.toString();
      if (isStreamLike(body)) return UNREADABLE;
      // Blob, FormData, ArrayBuffer, typed arrays: Response reads them all
      // without consuming the original.
      return new Response(body).text().then(
        function (t) { return t; },
        function () { return UNREADABLE; }
      );
    } catch (e) {
      try { return String(body); } catch (e2) { return UNREADABLE; }
    }
  }

  // The body of a Request object, through a clone (the original stays usable).
  function requestBodyText(req) {
    try {
      return req.clone().text().then(
        function (t) { return t; },
        function () { return UNREADABLE; }
      );
    } catch (e) {
      return UNREADABLE;
    }
  }

  function headersText(h) {
    var out = '';
    try {
      if (!h) return '';
      if (Array.isArray(h)) {
        h.forEach(function (p) { out += String(p && p[0]) + ':' + String(p && p[1]) + '\n'; });
      } else if (typeof h.forEach === 'function') {
        h.forEach(function (v, k) { out += String(k) + ':' + String(v) + '\n'; });
      } else {
        Object.keys(h).forEach(function (k) { out += k + ':' + h[k] + '\n'; });
      }
    } catch (e) {}
    return out;
  }

  function urlOf(input) {
    try {
      if (typeof input === 'string') return input;
      if (input && typeof input.url === 'string') return input.url;
      if (input) return String(input); // a URL object
    } catch (e) {}
    return null;
  }

  function pathOf(url) {
    try { return new URL(url, location.href).pathname; } catch (e) { return String(url); }
  }

  // %XX sequences decoded one by one (never throws), so an encoded name is seen.
  function unescapeAll(t) {
    var r = t.replace(/\+/g, ' ');
    for (var i = 0; i < 2; i++) {
      r = r.replace(/%([0-9a-fA-F]{2})/g, function (m, h) {
        return String.fromCharCode(parseInt(h, 16));
      });
    }
    return r;
  }

  var NAME_SHAPE = /^[A-Za-z0-9_]{1,120}$/;

  // items: the body pieces (strings or UNREADABLE). Returns
  // {block, name, body}. Never throws: on a bug it blocks GraphQL paths.
  function decide(url, headerTexts, items) {
    try {
      var unreadable = false;
      var body = '';
      items.forEach(function (p) {
        if (p === UNREADABLE) unreadable = true;
        else if (typeof p === 'string') body += p + '\n';
      });
      var hay = [url].concat(headerTexts, [body]).join('\n');
      var lower = (hay + '\n' + unescapeAll(hay)).toLowerCase();
      for (var i = 0; i < needles.length; i++) {
        if (lower.indexOf(needles[i].lower) !== -1) {
          return {
            block: true,
            name: NAME_SHAPE.test(needles[i].raw) ? needles[i].raw : 'seen_marker',
          };
        }
      }
      if (unreadable && /graphql/i.test(pathOf(url))) {
        return { block: true, name: 'unreadable_body' };
      }
      return { block: false, body: body };
    } catch (e) {
      return /graphql/i.test(String(url))
        ? { block: true, name: 'hook_error' }
        : { block: false, body: '' };
    }
  }

  // Decides now when every piece is a string, else after reading them.
  function collect(items, fn) {
    return items.some(isThenable) ? Promise.all(items).then(fn) : fn(items);
  }

  // {name, info} from a urlencoded body: the friendly name and, only when
  // configured, the page's own doc_id and tokens.
  function formInfo(text) {
    var out = { name: null, info: null };
    try {
      var form = new URLSearchParams(text);
      var name = form.get(NAME_KEY);
      if (name) out.name = String(name);
      if (includeRequestSecrets && form.get('doc_id')) {
        var tokens = {};
        var count = 0;
        form.forEach(function (value, key) {
          if (NOT_TOKENS[key] || count >= MAX_TOKENS) return;
          if (value.length === 0 || value.length > MAX_TOKEN_LENGTH) return;
          tokens[key] = value;
          count++;
        });
        out.info = { docId: form.get('doc_id') || null, tokens: tokens };
      }
    } catch (e) {}
    return out;
  }

  function notifyBlocked(name, via) {
    post({ type: 'blocked', friendlyName: name, origin: location.origin, via: via });
  }

  function fakeResponse() {
    return new Response(BLOCKED_REPLY, {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // ------------------------------------------------------------------ fetch
  var origFetch = window.fetch;
  if (typeof origFetch === 'function') {
    window.fetch = function (input, init) {
      var self = this;
      var args = arguments;
      var url = urlOf(input);
      if (!url || !isInstagram(url)) return origFetch.apply(self, args);
      var headerTexts = [];
      var items = [];
      try {
        if (input && typeof input === 'object' && typeof input.clone === 'function') {
          headerTexts.push(headersText(input.headers));
          items.push(requestBodyText(input));
        }
        if (init) {
          headerTexts.push(headersText(init.headers));
          items.push(bodyText(init.body));
        }
      } catch (e) {
        items.push(UNREADABLE);
      }
      function proceed(d) {
        if (d.block) {
          notifyBlocked(d.name, 'fetch');
          return Promise.resolve(fakeResponse());
        }
        var form = formInfo(d.body);
        var p = origFetch.apply(self, args);
        try {
          p.then(
            function (res) {
              try {
                res.clone().text().then(function (t) {
                  report(res.url || url, res.status, t, 'fetch', form.name, form.info);
                });
              } catch (e) {}
            },
            function () {}
          );
        } catch (e) {}
        return p;
      }
      var result = collect(items, function (its) {
        return decide(url, headerTexts, its);
      });
      return isThenable(result) ? result.then(proceed) : proceed(result);
    };
  }

  // -------------------------------------------------------------------- XHR
  // The own properties answerLocally() puts on an XHR to fake a finished
  // request. open() deletes them (R2-F1): a page may reuse the same XHR for a
  // later, real request, and an own property would shadow the prototype
  // accessors, so the page (and report()) would keep reading the fake reply.
  var FAKE_XHR_KEYS = [
    'readyState',
    'status',
    'statusText',
    'response',
    'responseText',
    'responseURL',
    'getAllResponseHeaders',
    'getResponseHeader',
  ];
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    try {
      for (var i = 0; i < FAKE_XHR_KEYS.length; i++) {
        var key = FAKE_XHR_KEYS[i];
        if (Object.prototype.hasOwnProperty.call(this, key)) delete this[key];
      }
    } catch (e) {}
    try {
      this.__storizeUrl = String(url);
      this.__storizeHeaders = [];
      this.__storizeAborted = false;
    } catch (e) {}
    return origOpen.apply(this, arguments);
  };
  var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
  if (typeof origSetHeader === 'function') {
    XMLHttpRequest.prototype.setRequestHeader = function (k, v) {
      try {
        (this.__storizeHeaders = this.__storizeHeaders || []).push(String(k) + ':' + String(v));
      } catch (e) {}
      return origSetHeader.apply(this, arguments);
    };
  }
  var origAbort = XMLHttpRequest.prototype.abort;
  if (typeof origAbort === 'function') {
    XMLHttpRequest.prototype.abort = function () {
      try { this.__storizeAborted = true; } catch (e) {}
      return origAbort.apply(this, arguments);
    };
  }

  function bytesOf(str) {
    var u = new Uint8Array(str.length);
    for (var i = 0; i < str.length; i++) u[i] = str.charCodeAt(i) & 255;
    return u;
  }

  // The local reply in the type the page asked for (responseType).
  function replyFor(type) {
    switch (type) {
      case 'json': return JSON.parse(BLOCKED_REPLY);
      case 'arraybuffer': return bytesOf(BLOCKED_REPLY).buffer;
      case 'blob': return new Blob([BLOCKED_REPLY], { type: 'application/json' });
      case 'document': return null;
      default: return BLOCKED_REPLY;
    }
  }

  // Makes [xhr] look finished with the local reply, without sending anything.
  function answerLocally(xhr, url) {
    var type = xhr.responseType;
    var fields = {
      // Keep in step with FAKE_XHR_KEYS.
      readyState: 4,
      status: 200,
      statusText: 'OK',
      response: replyFor(type),
      responseText: type === '' || type === 'text' ? BLOCKED_REPLY : '',
      responseURL: String(url),
      getAllResponseHeaders: function () { return 'content-type: application/json\r\n'; },
      getResponseHeader: function (n) {
        return String(n).toLowerCase() === 'content-type' ? 'application/json' : null;
      },
    };
    Object.keys(fields).forEach(function (k) {
      Object.defineProperty(xhr, k, { value: fields[k], configurable: true, writable: true });
    });
    setTimeout(function () {
      ['readystatechange', 'load', 'loadend'].forEach(function (t) {
        try {
          xhr.dispatchEvent(
            typeof ProgressEvent === 'function' && t !== 'readystatechange'
              ? new ProgressEvent(t)
              : new Event(t)
          );
        } catch (e) {}
      });
    }, 0);
  }

  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function (body) {
    var xhr = this;
    var args = arguments;
    var url = xhr.__storizeUrl;
    if (!url || !isInstagram(url)) return origSend.apply(xhr, args);
    var headerTexts = [(xhr.__storizeHeaders || []).join('\n')];
    var items = [bodyText(body)];
    function proceed(d) {
      if (xhr.__storizeAborted) return undefined;
      if (d.block) {
        notifyBlocked(d.name, 'xhr');
        answerLocally(xhr, url);
        return undefined;
      }
      var form = formInfo(d.body);
      xhr.addEventListener('loadend', function () {
        try {
          var t = '';
          if (xhr.responseType === '' || xhr.responseType === 'text') {
            t = xhr.responseText || '';
          } else if (xhr.responseType === 'json' && xhr.response) {
            t = JSON.stringify(xhr.response);
          }
          if (t) report(xhr.responseURL || url, xhr.status, t, 'xhr', form.name, form.info);
        } catch (e) {}
      });
      return origSend.apply(xhr, args);
    }
    var result = collect(items, function (its) {
      return decide(url, headerTexts, its);
    });
    if (isThenable(result)) {
      result.then(proceed);
      return undefined;
    }
    return proceed(result);
  };

  // ------------------------------------------------------------- sendBeacon
  if (typeof navigator !== 'undefined' && typeof navigator.sendBeacon === 'function') {
    var origBeacon = navigator.sendBeacon;
    navigator.sendBeacon = function (url, data) {
      var self = this;
      var args = arguments;
      var u = urlOf(url);
      if (!u || !isInstagram(u)) return origBeacon.apply(self, args);
      var items = [bodyText(data)];
      function proceed(d) {
        if (d.block) {
          notifyBlocked(d.name, 'beacon');
          return true; // "queued"; nothing is sent
        }
        return origBeacon.apply(self, args);
      }
      var result = collect(items, function (its) {
        return decide(u, [], its);
      });
      if (isThenable(result)) {
        result.then(proceed);
        return true; // sent or dropped once the body has been read
      }
      return proceed(result);
    };
  }
})();
