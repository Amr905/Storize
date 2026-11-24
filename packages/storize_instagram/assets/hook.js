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
 * IN-PAGE DISCOVERY (T-048, only with includeRequestSecrets). The first page
 * of posts is server-preloaded, so watching traffic never sees its doc_id.
 * Instead the hook reads, from the page's own module system (window.require,
 * NO network request), for a fixed allowlist of operations: the doc_id
 * (<Name>_instagramRelayOperation), the relay provided-variable values and
 * the argument names (<Name>.graphql), plus the fb_dtsg / lsd tokens. It posts
 * {type:'discovery', origin, ops:[{name, docId, provided, args}], tokens} once
 * the page is ready and again on a window message {storizeDiscover:true}.
 * A failure posts an empty ops list and an error code, never a value. It
 * never touches stories UI or the seen mutation.
 *
 * T-049: discovery is COMPLETE only when every found op has its provided
 * variables (its <Name>.graphql module is loaded, or they were taken from a
 * captured request) AND fb_dtsg and lsd are known (modules, or the forms /
 * X-FB-LSD header of captured requests). Until then it retries (0, 0.4, 1.5,
 * 4, 9, 15 s, on load, on message, on each capture), MERGES what it finds
 * (nothing found earlier is lost) and posts only when something new appears
 * (capped). A missing <Name>.graphql module is asked for once through
 * window.requireLazy (static JS only, no API call). A captured request for an
 * allowlisted op also gives its __relay_internal__pv__* scalars, its argument
 * names, and its fb_dtsg / lsd.
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
      noteCapture(friendlyName, requestInfo);
      if (!discoveryDone) runDiscovery(); // before the capture that may end the run
      post(msg);
    } catch (e) {
      /* never break the page */
    }
  }

  // ------------------------------------------------- in-page discovery (T-048)
  // Reads, from the page's own module system (window.require), the doc_id,
  // the relay provided-variable values and the argument names of a FIXED
  // allowlist of operations, plus the page tokens. It makes NO network
  // request and touches no story UI. Only runs with includeRequestSecrets.
  // Posts ONE message per success: {type:'discovery', origin, ops:[{name,
  // docId, provided:{k:bool|num|string}, args:[...]}], tokens:{fb_dtsg, lsd}};
  // on failure an empty ops list with an error code and no values.
  var DISCOVERY_OPS = [
    'PolarisProfilePostsQuery',
    'PolarisProfilePostsTabContentQuery_connection',
    'PolarisStoriesV3ReelPageStandaloneQuery',
    'PolarisProfileStoryHighlightsTrayContentQuery',
    'PolarisProfilePageContentQuery',
    'PolarisStoriesV3HighlightsPageQuery',
  ];
  var PROVIDER_KEY = /^__relay_internal__pv__[A-Za-z0-9_]{1,100}$/;
  var ARG_NAME = /^[a-z_]{1,64}$/;
  var DOC_ID = /^\d{5,32}$/;
  var MAX_ARGS = 40;
  var MAX_PROVIDED = 40;
  var MAX_DISCOVERY_POSTS = 10;
  var discoveryPosts = 0;
  var discoveryDone = false;
  var requireErrors = 0;
  var errorPosted = false;
  var foundOps = {}; // name -> merged {name, docId, provided, args, loaded}
  var modTokens = {}; // fb_dtsg / lsd from the page's modules
  var capTokens = {}; // fb_dtsg / lsd from captured requests
  var capProvided = {}; // op name -> provided scalars of a captured request
  var capArgs = {}; // op name -> argument names of a captured request
  var lazyAsked = {};
  var lastSig = '';

  function reqModule(name) {
    try {
      var r = window.require;
      if (typeof r !== 'function') return undefined;
      return r(name);
    } catch (e) {
      requireErrors++; // counted only; the error text is never read or sent
      return undefined;
    }
  }

  function scalar(v) {
    var t = typeof v;
    if (t === 'boolean') return v;
    if (t === 'number') return isFinite(v) ? v : undefined;
    if (t === 'string' && v.length <= 64) return v;
    return undefined;
  }

  function askLazy(name) {
    // Loads the static <Name>.graphql module if the page has not yet. No API
    // call: only the JS module. Asked once per name, fully guarded.
    if (lazyAsked[name]) return;
    lazyAsked[name] = true;
    try {
      if (typeof window.requireLazy !== 'function') return;
      window.requireLazy([name + '.graphql'], function () {
        try { setTimeout(runDiscovery, 0); } catch (e) {}
      });
    } catch (e) {
      /* never break the page */
    }
  }

  function readOp(name) {
    var id = reqModule(name + '_instagramRelayOperation');
    if (typeof id !== 'string' || !DOC_ID.test(id)) return null;
    var provided = {};
    var args = [];
    var loaded = false;
    try {
      var g = reqModule(name + '.graphql');
      loaded = !!g && typeof g === 'object';
      if (!loaded) askLazy(name);
      var pv = g && g.params && g.params.providedVariables;
      if (pv && typeof pv === 'object') {
        Object.keys(pv).slice(0, MAX_PROVIDED).forEach(function (k) {
          if (!PROVIDER_KEY.test(k)) return;
          var p = pv[k];
          var v = p && typeof p.get === 'function' ? scalar(p.get()) : undefined;
          if (v !== undefined) provided[k] = v;
        });
      }
      var defs = g && g.fragment && g.fragment.argumentDefinitions;
      if (defs && typeof defs.length === 'number') {
        for (var i = 0; i < defs.length && args.length < MAX_ARGS; i++) {
          var a = defs[i] && defs[i].name;
          if (typeof a === 'string' && ARG_NAME.test(a)) args.push(a);
        }
      }
    } catch (e) {
      /* the doc_id alone is still useful */
    }
    return { name: name, docId: id, provided: provided, args: args, loaded: loaded };
  }

  function tokenOf(moduleName) {
    var m = reqModule(moduleName);
    var t = m && m.token;
    return typeof t === 'string' && t.length > 0 && t.length <= 4096 ? t : null;
  }

  function postDiscovery(ops, tokens, error, sources) {
    if (discoveryPosts >= MAX_DISCOVERY_POSTS) return;
    discoveryPosts++;
    var msg = { type: 'discovery', origin: location.origin, ops: ops, tokens: tokens || {} };
    if (sources) msg.tokenSources = sources;
    if (error) msg.error = error;
    post(msg);
  }

  function copyInto(dst, src) {
    Object.keys(src).forEach(function (k) { dst[k] = src[k]; });
    return dst;
  }

  // The merged view of one op: module values win over captured ones.
  function viewOf(op) {
    var cp = capProvided[op.name] || {};
    var provided = copyInto(copyInto({}, cp), op.provided);
    var fromModule = Object.keys(op.provided).length > 0;
    var fromCapture = Object.keys(cp).length > 0;
    var args = op.args.length > 0 ? op.args : capArgs[op.name] || [];
    return {
      name: op.name,
      docId: op.docId,
      provided: provided,
      args: args,
      loaded: op.loaded === true || (!fromModule && capArgs[op.name] !== undefined),
      src: fromModule ? 'module' : fromCapture ? 'capture' : 'none',
    };
  }

  function opComplete(v) {
    return v.loaded || Object.keys(v.provided).length > 0;
  }

  function mergedTokens() {
    var tokens = {};
    var sources = {};
    ['fb_dtsg', 'lsd'].forEach(function (k) {
      if (modTokens[k]) { tokens[k] = modTokens[k]; sources[k] = 'module'; }
      else if (capTokens[k]) { tokens[k] = capTokens[k]; sources[k] = 'capture'; }
    });
    return { tokens: tokens, sources: sources };
  }

  // A captured request of an allowlisted op: its provider scalars, argument
  // names and tokens. Values only go to Dart (never logged).
  function noteCapture(name, info) {
    try {
      if (!includeRequestSecrets || !info) return;
      if (name && DISCOVERY_OPS.indexOf(name) !== -1) {
        if (info.provided && Object.keys(info.provided).length > 0) {
          capProvided[name] = copyInto(capProvided[name] || {}, info.provided);
        }
        if (info.args && info.args.length > 0) capArgs[name] = info.args;
        else if (info.vars === true && capArgs[name] === undefined) capArgs[name] = [];
      }
      var t = info.tokens || {};
      ['fb_dtsg', 'lsd'].forEach(function (k) {
        if (typeof t[k] === 'string' && t[k].length > 0 && t[k].length <= 4096) capTokens[k] = t[k];
      });
    } catch (e) {}
  }

  // Merges what the modules show now into what was found before, posts when
  // something is new, and returns true once discovery is complete.
  function runDiscovery() {
    if (!includeRequestSecrets) return false;
    try {
      if (typeof window.require !== 'function') return false;
      DISCOVERY_OPS.forEach(function (name) {
        try {
          var op = readOp(name);
          if (!op) return;
          var old = foundOps[name];
          if (old) {
            op.provided = copyInto(copyInto({}, old.provided), op.provided);
            if (op.args.length === 0) op.args = old.args;
            op.loaded = old.loaded || op.loaded;
          }
          foundOps[name] = op;
        } catch (e) {}
      });
      var dtsg = tokenOf('DTSGInitialData') || tokenOf('DTSGInitData');
      var lsd = tokenOf('LSD');
      if (dtsg) modTokens.fb_dtsg = dtsg;
      if (lsd) modTokens.lsd = lsd;
      var views = Object.keys(foundOps).map(function (n) { return viewOf(foundOps[n]); });
      var mt = mergedTokens();
      if (views.length === 0 && !mt.tokens.fb_dtsg && !mt.tokens.lsd) {
        if (requireErrors > 0 && !errorPosted) {
          errorPosted = true;
          postDiscovery([], {}, 'require_failed');
        }
        return false;
      }
      var sig = JSON.stringify([ // local only, never posted
        views.map(function (v) {
          return [v.name, v.docId, Object.keys(v.provided).sort(), v.args, v.loaded, v.src];
        }),
        mt.tokens.fb_dtsg || '',
        mt.tokens.lsd || '',
      ]);
      if (sig !== lastSig) {
        lastSig = sig;
        postDiscovery(views, mt.tokens, null, mt.sources);
      }
      discoveryDone =
        views.length > 0 &&
        views.every(opComplete) &&
        !!mt.tokens.fb_dtsg &&
        !!mt.tokens.lsd;
      return discoveryDone;
    } catch (e) {
      try { postDiscovery([], {}, 'discovery_failed'); } catch (e2) {}
      return false;
    }
  }

  // Modules appear as the page boots (some only after seconds, the .graphql
  // ones lazily): keep trying until discovery is complete, and again on a
  // message from the page or the app.
  function scheduleDiscovery() {
    if (!includeRequestSecrets) return;
    try {
      [0, 400, 1500, 4000, 9000, 15000].forEach(function (ms) {
        setTimeout(function () {
          if (!discoveryDone) runDiscovery();
        }, ms);
      });
      if (typeof window.addEventListener === 'function') {
        window.addEventListener('message', function (ev) {
          try {
            if (ev && ev.data && ev.data.storizeDiscover === true) runDiscovery();
          } catch (e) {}
        });
        window.addEventListener('load', function () {
          if (!discoveryDone) runDiscovery();
        });
      }
    } catch (e) {}
  }
  window.__storizeRunDiscovery = runDiscovery;

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

  // The fields of a request body: urlencoded, JSON or multipart FormData text.
  // A trailing newline (the pieces of a request are joined with one) is
  // dropped first: otherwise the LAST field (doc_id on the web app) carries it
  // and no shape check accepts it (T-049: has_doc_id=0 on the phone).
  function fieldsOf(text) {
    var out = {};
    function put(k, v) {
      if (!Object.prototype.hasOwnProperty.call(out, k)) out[k] = v;
    }
    try {
      var t = String(text).replace(/\s+$/, '');
      if (t.charAt(0) === '{') {
        var o = JSON.parse(t);
        Object.keys(o).forEach(function (k) {
          var v = o[k];
          put(k, typeof v === 'string' ? v : v !== null && typeof v === 'object' ? JSON.stringify(v) : String(v));
        });
      } else if (/content-disposition:\s*form-data/i.test(t)) {
        var re = /name="([^"]{1,80})"\r?\n\r?\n([\s\S]*?)\r?\n--/g;
        var m;
        while ((m = re.exec(t + '\n--')) !== null) put(m[1], m[2]);
      } else {
        new URLSearchParams(t).forEach(function (v, k) { put(k, v); });
      }
    } catch (e) {}
    return out;
  }

  function queryParam(url, key) {
    try { return new URL(url, location.href).searchParams.get(key); } catch (e) { return null; }
  }

  function lsdHeader(headerTexts) {
    try {
      var m = /^x-fb-lsd:\s*(\S{1,4096})\s*$/im.exec((headerTexts || []).join('\n'));
      return m ? m[1] : null;
    } catch (e) {
      return null;
    }
  }

  // {name, info} from a request body: the friendly name and, only when
  // configured, the page's own doc_id, tokens (form fields, or the X-FB-LSD
  // header), provider scalars and argument names of its `variables`.
  function formInfo(text, url, headerTexts) {
    var out = { name: null, info: null };
    try {
      var f = fieldsOf(text);
      if (f[NAME_KEY]) out.name = String(f[NAME_KEY]);
      var docId = f.doc_id || queryParam(url, 'doc_id');
      var vars = null;
      try {
        vars = f.variables ? JSON.parse(f.variables) : null;
      } catch (e) {}
      if (!vars || typeof vars !== 'object' || Array.isArray(vars)) vars = null;
      if (includeRequestSecrets && (docId || vars)) {
        var tokens = {};
        var count = 0;
        Object.keys(f).forEach(function (key) {
          var value = f[key];
          if (NOT_TOKENS[key] || count >= MAX_TOKENS) return;
          if (value.length === 0 || value.length > MAX_TOKEN_LENGTH) return;
          tokens[key] = value;
          count++;
        });
        var h = lsdHeader(headerTexts);
        if (!tokens.lsd && h) tokens.lsd = h;
        var provided = {};
        var args = [];
        if (vars) {
          Object.keys(vars).slice(0, 120).forEach(function (k) {
            if (PROVIDER_KEY.test(k)) {
              var v = scalar(vars[k]);
              if (v !== undefined && Object.keys(provided).length < MAX_PROVIDED) provided[k] = v;
            } else if (ARG_NAME.test(k) && args.length < MAX_ARGS) {
              args.push(k);
            }
          });
        }
        out.info = {
          docId: docId || null,
          tokens: tokens,
          provided: provided,
          args: args,
          vars: vars !== null,
        };
      }
    } catch (e) {}
    return out;
  }

  // The friendly name from the request headers (`X-FB-Friendly-Name`), for a
  // request whose body carries none. Header texts are "name:value" lines.
  function headerName(headerTexts) {
    try {
      var m = /^x-fb-friendly-name:\s*([A-Za-z0-9_]{1,120})\s*$/im.exec(
        headerTexts.join('\n')
      );
      return m ? m[1] : null;
    } catch (e) {
      return null;
    }
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
        var form = formInfo(d.body, url, headerTexts);
        var p = origFetch.apply(self, args);
        try {
          p.then(
            function (res) {
              try {
                res.clone().text().then(function (t) {
                  report(res.url || url, res.status, t, 'fetch', form.name || headerName(headerTexts), form.info);
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
      var form = formInfo(d.body, url, headerTexts);
      xhr.addEventListener('loadend', function () {
        try {
          var t = '';
          if (xhr.responseType === '' || xhr.responseType === 'text') {
            t = xhr.responseText || '';
          } else if (xhr.responseType === 'json' && xhr.response) {
            t = JSON.stringify(xhr.response);
          }
          if (t) report(xhr.responseURL || url, xhr.status, t, 'xhr', form.name || headerName(headerTexts), form.info);
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
  scheduleDiscovery();
})();
