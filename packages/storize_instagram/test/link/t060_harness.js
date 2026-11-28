// Runs the REAL assets/inpage_query.js in Node for the T-060 query
// (PolarisPostRootQuery, six relay providers); prints one JSON object.
// Usage: node t060_harness.js <path to inpage_query.js>
'use strict';
const fs = require('fs');
const source = fs.readFileSync(process.argv[2], 'utf8');

function make() {
  const calls = [];
  const provided = {};
  for (let i = 1; i <= 6; i++) {
    provided['__relay_internal__pv__P' + i] = { get: () => i };
  }
  const modules = {
    DTSGInitialData: { token: 'ZZFAKE_dtsg' },
    LSD: { token: 'ZZFAKE_lsd' },
    PolarisPostRootQuery_instagramRelayOperation: '444',
    'PolarisPostRootQuery.graphql': { params: { providedVariables: provided } },
  };
  const win = {
    require: (id) => { if (modules[id] === undefined) throw new Error('nomod'); return modules[id]; },
  };
  const doc = { cookie: 'csrftoken=ZZcsrf; ds_user_id=900001' };
  const fakeFetch = async (url, init) => {
    calls.push({ url, method: init.method, headers: init.headers, body: init.body.toString() });
    return { status: 200, text: async () => '{"data":{"xdt_api__v1__media__shortcode__web_info":{"items":[]}}}' };
  };
  const fn = new Function('window', 'document', 'fetch', 'URLSearchParams', 'setTimeout', 'clearTimeout',
    source + '\nreturn {query: __storizeQuery, allowed: __storizeAllowed, list: QUERY_ALLOWLIST};');
  return { api: fn(win, doc, fakeFetch, URLSearchParams, setTimeout, clearTimeout), calls };
}

(async () => {
  const out = {};
  const h = make();
  out.allowlist = Object.keys(h.api.list);
  out.ok = await h.api.query('PolarisPostRootQuery', JSON.stringify({
    shortcode: 'ZZFAKE_c1', include_longform_landscape_cover: false,
  }));
  const c = h.calls[0];
  const form = Object.fromEntries(new URLSearchParams(c.body));
  out.request = {
    n: h.calls.length, url: c.url, method: c.method,
    friendly: c.headers['X-FB-Friendly-Name'],
    form: Object.assign({}, form, { variables: JSON.parse(form.variables) }),
  };
  out.rejected = {};
  for (const n of ['PolarisPostRootQuery_Mutation', 'PolarisPostRootSeenQuery', 'PolarisPostRootQuery2', 'polarispostrootquery']) {
    const hh = make();
    out.rejected[n] = { r: await hh.api.query(n, '{}'), sent: hh.calls.length };
  }
  console.log(JSON.stringify(out));
})();
