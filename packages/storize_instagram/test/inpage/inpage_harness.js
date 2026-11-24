// Runs the REAL assets/inpage_query.js in Node with a fake window.require,
// document.cookie and fetch; prints one JSON object per scenario.
// Usage: node inpage_harness.js <path to inpage_query.js>
'use strict';
const fs = require('fs');
const source = fs.readFileSync(process.argv[2], 'utf8');

function make(opts) {
  opts = opts || {};
  const calls = [];
  const lazyRequested = [];
  const modules = Object.assign({
    DTSGInitialData: { token: 'ZZFAKE_dtsg' },
    LSD: { token: 'ZZFAKE_lsd' },
    PolarisProfilePostsQuery_instagramRelayOperation: '111',
    'PolarisProfilePostsQuery.graphql': { params: { providedVariables: { __relay_internal__pv__X: { get: () => true } } } },
    PolarisStoriesV3ReelPageStandaloneQuery_instagramRelayOperation: '222',
    'PolarisStoriesV3ReelPageStandaloneQuery.graphql': { params: {} },
  }, opts.modules || {});
  const lazy = opts.lazy || {};
  const win = {
    require: (id) => { if (modules[id] === undefined) throw new Error('nomod'); return modules[id]; },
  };
  if (opts.noRequire) delete win.require;
  if (!opts.noLazy) {
    win.requireLazy = (ids, cb) => {
      lazyRequested.push(ids[0]);
      if (lazy[ids[0]] !== undefined) { modules[ids[0]] = lazy[ids[0]]; cb(lazy[ids[0]]); }
    };
  }
  const doc = { cookie: opts.cookie === undefined ? 'csrftoken=ZZcsrf; ds_user_id=900001; other=1' : opts.cookie };
  const fakeFetch = async (url, init) => {
    calls.push({ url, method: init.method, credentials: init.credentials, headers: init.headers, body: init.body.toString() });
    if (opts.fetchThrows) throw new Error('boom');
    return { status: opts.status || 200, text: async () => opts.reply === undefined ? '{"data":{"ok":1}}' : opts.reply };
  };
  const fn = new Function('window', 'document', 'fetch', 'URLSearchParams', 'setTimeout', 'clearTimeout',
    source + '\nreturn {ready: __storizeReady, query: __storizeQuery};');
  const api = fn(win, doc, fakeFetch, URLSearchParams, setTimeout, clearTimeout);
  return { api, calls, lazyRequested };
}

(async () => {
  const out = {};
  let h = make();
  out.ready = h.api.ready();
  out.ready_nocookie = make({ cookie: '' }).api.ready();
  out.ready_notoken = make({ modules: { LSD: null } }).api.ready();

  h = make();
  const vars = { username: 'zzfake', data: { count: 12 } };
  out.ok = await h.api.query('PolarisProfilePostsQuery', JSON.stringify(vars));
  const c = h.calls[0];
  const form = Object.fromEntries(new URLSearchParams(c.body));
  out.request = {
    n: h.calls.length, url: c.url, method: c.method, credentials: c.credentials,
    headers: c.headers, form: Object.assign({}, form, { variables: JSON.parse(form.variables) }),
  };

  out.rejected = {};
  for (const n of ['PolarisStoriesV3SeenMutation', 'PolarisProfilePostsQuery_Mutation', 'SeenQuery', 'SomethingElse', '', 'a b', 'constructor']) {
    const hh = make();
    out.rejected[n] = { r: await hh.api.query(n, '{}'), sent: hh.calls.length };
  }
  out.nonstring = await make().api.query(null, '{}');
  out.badvars = await make().api.query('PolarisProfilePostsQuery', '[1]');
  out.badjson = await make().api.query('PolarisProfilePostsQuery', '{nope');

  const shield = make({ reply: 'for (;;);{"error":1357054,"errorSummary":"x"}' });
  out.shielded = await shield.api.query('PolarisProfilePostsQuery', '{}');
  out.bad_json_reply = await make({ reply: '<html>' }).api.query('PolarisProfilePostsQuery', '{}');
  out.network = await make({ fetchThrows: true }).api.query('PolarisProfilePostsQuery', '{}');
  out.status429 = await make({ status: 429, reply: '{"message":"wait"}' }).api.query('PolarisProfilePostsQuery', '{}');

  h = make({ lazy: { 'PolarisProfileStoryHighlightsTrayContentQuery_instagramRelayOperation': '333',
    'PolarisProfileStoryHighlightsTrayContentQuery.graphql': { params: {} } } });
  out.lazy = await h.api.query('PolarisProfileStoryHighlightsTrayContentQuery', '{"user_id":"1"}');
  out.lazy_requested = h.lazyRequested;
  out.lazy_doc = Object.fromEntries(new URLSearchParams(h.calls[0].body)).doc_id;

  out.no_lazy_unavailable = await make({ noLazy: true }).api.query('PolarisProfileStoryHighlightsTrayContentQuery', '{}');
  out.no_require = await make({ noRequire: true }).api.query('PolarisProfilePostsQuery', '{}');
  out.no_tokens = await make({ modules: { LSD: null } }).api.query('PolarisProfilePostsQuery', '{}');
  out.no_cookies = await make({ cookie: 'x=1' }).api.query('PolarisProfilePostsQuery', '{}');
  console.log(JSON.stringify(out));
})();
