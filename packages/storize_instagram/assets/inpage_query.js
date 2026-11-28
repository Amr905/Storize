// Storize in-page query functions (T-050, ADR-0003 amendment).
//
// Run inside the logged-in instagram.com page, in the page's own JavaScript
// world, so the request has the page's cookies, user agent and tokens. The
// Dart side prepends this source to a `callAsyncJavaScript` function body and
// passes `name` and `varsJson` as arguments (never interpolated into code).
//
// Hard limits:
//  - Only the read queries of QUERY_ALLOWLIST run. Any name containing
//    "Mutation" or "Seen" is refused first (the story "seen" mutation must
//    never be sent).
//  - The only request made is POST /api/graphql on the page's own origin.
//  - No cookie, token or response value is written anywhere: the functions
//    only return the reply to Dart.

var QUERY_ALLOWLIST = {
  PolarisProfilePostsQuery: 1,
  PolarisProfilePostsTabContentQuery_connection: 1,
  PolarisStoriesV3ReelPageStandaloneQuery: 1,
  PolarisProfileStoryHighlightsTrayContentQuery: 1,
  // T-060 (FR-80): one post or reel by shortcode (read only).
  PolarisPostRootQuery: 1,
};

var LAZY_TIMEOUT_MS = 5000;

function __storizeAllowed(name) {
  if (typeof name !== 'string') return false;
  if (!/^[A-Za-z0-9_]{1,100}$/.test(name)) return false;
  if (/Mutation|Seen/i.test(name)) return false;
  return Object.prototype.hasOwnProperty.call(QUERY_ALLOWLIST, name);
}

function __storizeRequire(id) {
  try {
    var R = window.require;
    return typeof R === 'function' ? R(id) || null : null;
  } catch (e) {
    return null;
  }
}

function __storizeCookie(name) {
  var m = (document.cookie || '').match(new RegExp(name + '=([^;]+)'));
  return m ? m[1] : null;
}

function __storizeTokens() {
  var d = __storizeRequire('DTSGInitialData');
  var l = __storizeRequire('LSD');
  return {
    dtsg: d && d.token ? d.token : null,
    lsd: l && l.token ? l.token : null,
    csrf: __storizeCookie('csrftoken'),
    uid: __storizeCookie('ds_user_id'),
  };
}

// Readiness of the page: the tokens and cookies exist. `modules` counts the
// allowlisted operations whose module is already loaded (the others are
// loaded on demand by __storizeQuery).
function __storizeReady() {
  var t = __storizeTokens();
  var modules = 0;
  for (var name in QUERY_ALLOWLIST) {
    if (__storizeRequire(name + '_instagramRelayOperation')) modules++;
  }
  return {
    ready: !!(t.dtsg && t.lsd && t.csrf && t.uid),
    modules: modules,
  };
}

// Resolves a module, force-loading it with requireLazy when missing.
function __storizeLoad(id) {
  var m = __storizeRequire(id);
  if (m) return Promise.resolve(m);
  if (typeof window.requireLazy !== 'function') return Promise.resolve(null);
  return new Promise(function (resolve) {
    var done = false;
    var timer = setTimeout(function () {
      if (!done) {
        done = true;
        resolve(__storizeRequire(id));
      }
    }, LAZY_TIMEOUT_MS);
    try {
      window.requireLazy([id], function (loaded) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        resolve(loaded || __storizeRequire(id));
      });
    } catch (e) {
      if (!done) {
        done = true;
        clearTimeout(timer);
        resolve(null);
      }
    }
  });
}

// Runs one allowlisted read query. Returns one of
//   {error: '<code>'}                       the query did not run
//   {status, json}                          the reply
//   {status, shielded: true, fbError, json} a `for (;;);` error body
// Codes starting with "unavailable" mean the page cannot run queries now
// (modules or tokens missing); the caller may fall back to direct HTTP.
async function __storizeQuery(name, varsJson) {
  if (!__storizeAllowed(name)) return {error: 'not_allowed'};
  var vars;
  try {
    vars = JSON.parse(varsJson);
  } catch (e) {
    return {error: 'bad_variables'};
  }
  if (vars === null || typeof vars !== 'object' || Array.isArray(vars)) {
    return {error: 'bad_variables'};
  }
  if (typeof window.require !== 'function') {
    return {error: 'unavailable:require'};
  }
  var t = __storizeTokens();
  if (!t.dtsg || !t.lsd) return {error: 'unavailable:tokens'};
  if (!t.csrf || !t.uid) return {error: 'unavailable:cookies'};
  var doc = await __storizeLoad(name + '_instagramRelayOperation');
  if (!doc) return {error: 'unavailable:operation_module'};
  var g = await __storizeLoad(name + '.graphql');
  if (!g) return {error: 'unavailable:graphql_module'};
  var provided = {};
  try {
    var pv = (g.params && g.params.providedVariables) || {};
    for (var k in pv) provided[k] = pv[k].get();
  } catch (e) {
    return {error: 'unavailable:providers'};
  }
  var merged = {};
  for (var a in vars) merged[a] = vars[a];
  for (var b in provided) merged[b] = provided[b];
  var body = new URLSearchParams({
    av: t.uid,
    __user: '0',
    __a: '1',
    __comet_req: '7',
    fb_dtsg: t.dtsg,
    lsd: t.lsd,
    fb_api_caller_class: 'RelayModern',
    fb_api_req_friendly_name: name,
    server_timestamps: 'true',
    variables: JSON.stringify(merged),
    doc_id: String(doc),
  });
  var response;
  var text;
  try {
    response = await fetch('/api/graphql', {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-FB-LSD': t.lsd,
        'X-IG-App-ID': '936619743392459',
        'X-CSRFToken': t.csrf,
        'X-FB-Friendly-Name': name,
      },
      body: body,
    });
    text = await response.text();
  } catch (e) {
    return {error: 'network'};
  }
  var shielded = false;
  if (text.indexOf('for (;;);') === 0) {
    shielded = true;
    text = text.slice(9);
  }
  var json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    return {status: response.status, error: 'bad_json'};
  }
  if (shielded) {
    var code = json && typeof json.error === 'number' ? json.error : 0;
    return {
      status: response.status,
      shielded: true,
      fbError: code,
      json: {error: code},
    };
  }
  return {status: response.status, json: json};
}
