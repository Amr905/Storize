// T-049: runs the REAL assets/hook.js in a Node `vm` context and prints one
// JSON object per scenario. Synthetic values only.
// Usage: node t049_harness.js <path to hook.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const source = fs.readFileSync(process.argv[2], 'utf8');
const secrets = { includeBody: true, includeRequestSecrets: true };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const provider = (v) => ({ get: () => v });

const graphqlModule = (providedValues) => ({
  params: { providedVariables: Object.fromEntries(Object.entries(providedValues).map(([k, v]) => [k, provider(v)])) },
  fragment: { argumentDefinitions: [{ name: 'username' }, { name: 'data' }] },
});

function makeContext(config, modules, extra) {
  const handled = [];
  const listeners = {};
  const sent = { fetch: 0, xhr: 0, beacon: 0 };
  const ctx = {
    location: { href: 'https://www.instagram.com/zzfake_user/', origin: 'https://www.instagram.com' },
    URL, URLSearchParams, Response, Request, Headers, Blob, FormData, Uint8Array, ArrayBuffer, Event, EventTarget, Promise, JSON, Object, Array, String, Number, isFinite, setTimeout,
    flutter_inappwebview: { callHandler: (n, msg) => handled.push(JSON.parse(JSON.stringify(msg))) },
    __STORIZE_HOOK_CONFIG: config,
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
  };
  ctx.window = ctx;
  ctx.fetch = () => { sent.fetch++; return Promise.resolve(new Response('{"data":{}}', { status: 200 })); };
  ctx.XMLHttpRequest = class { open() {} send() { sent.xhr++; } setRequestHeader() {} abort() {} };
  ctx.XMLHttpRequest.prototype.open = function () {};
  ctx.XMLHttpRequest.prototype.send = function () { sent.xhr++; };
  ctx.navigator = { sendBeacon: () => { sent.beacon++; return true; } };
  if (modules) ctx.require = (n) => modules[n];
  Object.assign(ctx, extra || {});
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return { ctx, handled, sent, listeners };
}

const discoveries = (h) => h.filter((m) => m.type === 'discovery');
const captures = (h) => h.filter((m) => m.type === undefined);
const results = {};
async function scenario(name, fn) {
  try { results[name] = await fn(); } catch (e) { results[name] = { error: String(e) }; }
}

const POSTS = 'PolarisProfilePostsQuery';
const PV = '__relay_internal__pv__PolarisZzFakeEnabled';

// The web app's body: doc_id is the LAST field (no trailing separator).
function webBody(extra) {
  const p = new URLSearchParams();
  p.set('av', '17841400000000000');
  p.set('__a', '1');
  p.set('fb_dtsg', 'ZZFAKE_cap_dtsg');
  p.set('lsd', 'ZZFAKE_cap_lsd');
  p.set('fb_api_req_friendly_name', POSTS);
  p.set('variables', JSON.stringify({ username: 'zzfake_user', data: { count: 12 }, [PV]: true, __relay_internal__pv__ZzObj: { a: 1 } }));
  p.set('server_timestamps', 'true');
  if (extra) Object.keys(extra).forEach((k) => p.set(k, extra[k]));
  p.set('doc_id', '33333333333333333');
  return p;
}

(async () => {
  // Modules (doc id + tokens) exist at once, but `.graphql` arrives after 2 s.
  await scenario('late_modules', async () => {
    const m = {
      [POSTS + '_instagramRelayOperation']: '11111111111111111',
    };
    const { handled } = makeContext(secrets, m);
    await wait(1000);
    const early = discoveries(handled).length;
    m[POSTS + '.graphql'] = graphqlModule({ [PV]: true });
    m.DTSGInitialData = { token: 'ZZFAKE_dtsg' };
    m.LSD = { token: 'ZZFAKE_lsd' };
    await wait(3600); // the 4 s try
    const msgs = discoveries(handled);
    await wait(11000); // no more posts after completion (9 s and 15 s tries)
    return { early, msgs, after: discoveries(handled).length };
  });

  // Modules appear only after 2 s (nothing before).
  await scenario('modules_after_two_seconds', async () => {
    const m = {};
    const { handled } = makeContext(secrets, m);
    await wait(1900);
    const early = discoveries(handled).length;
    Object.assign(m, {
      [POSTS + '_instagramRelayOperation']: '11111111111111111',
      [POSTS + '.graphql']: graphqlModule({ [PV]: false }),
      DTSGInitData: { token: 'ZZFAKE_dtsg2' },
      LSD: { token: 'ZZFAKE_lsd2' },
    });
    await wait(2500);
    return { early, msgs: discoveries(handled) };
  });

  // `.graphql` is missing: requireLazy loads it (once, guarded), no API call.
  await scenario('require_lazy', async () => {
    const m = {
      [POSTS + '_instagramRelayOperation']: '11111111111111111',
      DTSGInitialData: { token: 'ZZFAKE_dtsg' },
      LSD: { token: 'ZZFAKE_lsd' },
    };
    const calls = [];
    const env = makeContext(secrets, m, {
      requireLazy: (names, cb) => {
        calls.push(names);
        m[names[0]] = graphqlModule({ [PV]: true });
        cb(m[names[0]]);
      },
    });
    await wait(300);
    return { calls, msgs: discoveries(env.handled), sent: env.sent };
  });

  // requireLazy that throws must not break discovery.
  await scenario('require_lazy_throws', async () => {
    const m = { [POSTS + '_instagramRelayOperation']: '11111111111111111', LSD: { token: 'ZZFAKE_lsd' } };
    const env = makeContext(secrets, m, { requireLazy: () => { throw new Error('ZZFAKE'); } });
    await wait(300);
    return { msgs: discoveries(env.handled) };
  });

  // Providers, args and tokens from a captured request (urlencoded body,
  // doc_id last). No module has them.
  await scenario('capture_urlencoded', async () => {
    const m = { [POSTS + '_instagramRelayOperation']: '11111111111111111' };
    const env = makeContext(secrets, m);
    await env.ctx.fetch('https://www.instagram.com/api/graphql', { method: 'POST', body: webBody().toString() });
    await wait(300);
    return { caps: captures(env.handled), msgs: discoveries(env.handled) };
  });

  // The same request as multipart FormData and as JSON.
  await scenario('capture_formdata_and_json', async () => {
    const env = makeContext(secrets, {});
    const fd = new FormData();
    webBody().forEach((v, k) => fd.append(k, v));
    await env.ctx.fetch('https://www.instagram.com/api/graphql', { method: 'POST', body: fd });
    const obj = {};
    webBody().forEach((v, k) => { obj[k] = v; });
    await env.ctx.fetch('https://www.instagram.com/api/graphql', { method: 'POST', body: JSON.stringify(obj) });
    await wait(200);
    return { caps: captures(env.handled) };
  });

  // The doc_id in the URL query, the lsd in the X-FB-LSD header only, the
  // friendly name from a header.
  await scenario('capture_query_and_header', async () => {
    const env = makeContext(secrets, {});
    const p = new URLSearchParams();
    p.set('fb_dtsg', 'ZZFAKE_cap_dtsg');
    p.set('variables', JSON.stringify({ username: 'zzfake_user' }));
    await env.ctx.fetch('https://www.instagram.com/graphql/query?doc_id=44444444444444', {
      method: 'POST',
      body: p.toString(),
      headers: { 'X-FB-LSD': 'ZZFAKE_hdr_lsd', 'X-FB-Friendly-Name': POSTS },
    });
    await wait(200);
    return { caps: captures(env.handled) };
  });

  // Discovery completes from captures alone (module doc id only): tokens from
  // the captured form.
  await scenario('complete_from_captures', async () => {
    const m = { [POSTS + '_instagramRelayOperation']: '11111111111111111' };
    const env = makeContext(secrets, m);
    await wait(100);
    const before = discoveries(env.handled).length;
    await env.ctx.fetch('https://www.instagram.com/api/graphql', { method: 'POST', body: webBody().toString() });
    await wait(200);
    const msgs = discoveries(env.handled);
    await wait(1800); // the 0.4 s and 1.5 s tries find nothing new
    return { before, msgs, after: discoveries(env.handled).length };
  });

  // Posts are capped even if modules keep changing.
  await scenario('cap', async () => {
    const m = { [POSTS + '_instagramRelayOperation']: '11111111111111111' };
    const env = makeContext(secrets, m);
    for (let i = 0; i < 40; i++) {
      m.LSD = { token: 'ZZFAKE_lsd_' + i };
      env.ctx.__storizeRunDiscovery();
    }
    return { count: discoveries(env.handled).length };
  });

  // The blocked-name logic is untouched by the new form parsing.
  await scenario('seen_still_blocked', async () => {
    const env = makeContext(secrets, {});
    const p = webBody({ fb_api_req_friendly_name_x: 'x' });
    p.set('fb_api_req_friendly_name', 'PolarisStoriesV3SeenMutation');
    await env.ctx.fetch('https://www.instagram.com/api/graphql', { method: 'POST', body: p.toString() });
    return { sent: env.sent, blocked: env.handled.filter((h) => h.type === 'blocked').length };
  });

  process.stdout.write(JSON.stringify(results));
})();
