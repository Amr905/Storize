// Runs the REAL assets/hook.js in a Node `vm` context with a fake
// `window.require` (synthetic values only) and prints one JSON object per
// scenario. Usage: node discovery_harness.js <path to hook.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const source = fs.readFileSync(process.argv[2], 'utf8');

function provider(v) {
  return { get: () => v };
}

// A fake module table: name -> value (or a function that throws).
function goodModules() {
  const m = {};
  m['PolarisProfilePostsQuery_instagramRelayOperation'] = '11111111111111111';
  m['PolarisProfilePostsQuery.graphql'] = {
    params: {
      providedVariables: {
        __relay_internal__pv__PolarisShortDramaEnabled: provider(true),
        __relay_internal__pv__PolarisSEOIsCrawler: provider(false),
        __relay_internal__pv__PolarisLevel: provider(3),
        __relay_internal__pv__PolarisLabel: provider('zzfake'),
        __relay_internal__pv__PolarisObject: provider({ no: 1 }),
        not_a_provider_key: provider(true),
      },
    },
    fragment: {
      argumentDefinitions: [{ name: 'after' }, { name: 'data' }, { name: 'username' }, { name: 'Bad-Name' }, { name: 'first' }],
    },
  };
  m['PolarisStoriesV3ReelPageStandaloneQuery_instagramRelayOperation'] = '22222222222222222';
  m['PolarisStoriesV3ReelPageStandaloneQuery.graphql'] = {
    params: { providedVariables: {} },
    fragment: { argumentDefinitions: [{ name: 'is_highlight' }, { name: 'reel_ids_arr' }] },
  };
  // A doc id that is not digits is ignored.
  m['PolarisProfilePageContentQuery_instagramRelayOperation'] = 'not-digits';
  m['DTSGInitialData'] = { token: 'ZZFAKE_dtsg' };
  m['LSD'] = { token: 'ZZFAKE_lsd' };
  return m;
}

function makeContext(config, modules, opts) {
  const sent = { fetch: 0, xhr: 0, beacon: 0 };
  const handled = [];
  const listeners = {};
  const ctx = {
    location: { href: 'https://www.instagram.com/zzfake_user/', origin: 'https://www.instagram.com' },
    URL, URLSearchParams, Response, Request, Headers, Blob, FormData, Uint8Array, ArrayBuffer, Event, EventTarget, Promise, JSON, Object, Array, String, Number, isFinite, setTimeout,
    flutter_inappwebview: { callHandler: (name, msg) => handled.push(JSON.parse(JSON.stringify(msg))) },
    __STORIZE_HOOK_CONFIG: config,
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
  };
  ctx.window = ctx;
  ctx.fetch = () => { sent.fetch++; return Promise.resolve(new Response('{}')); };
  ctx.XMLHttpRequest = class { open() {} send() { sent.xhr++; } setRequestHeader() {} abort() {} };
  ctx.XMLHttpRequest.prototype.open = function () {};
  ctx.XMLHttpRequest.prototype.send = function () { sent.xhr++; };
  ctx.navigator = { sendBeacon: () => { sent.beacon++; return true; } };
  if (modules) {
    ctx.require = (name) => {
      if (opts && opts.throwOn && opts.throwOn.indexOf(name) !== -1) throw new Error('ZZFAKE boom');
      if (opts && opts.throwAll) throw new Error('ZZFAKE boom');
      return modules[name];
    };
  }
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return { ctx, sent, handled, listeners };
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const results = {};
async function scenario(name, config, modules, opts, fn) {
  const env = makeContext(config, modules, opts);
  try {
    results[name] = await fn(env);
  } catch (e) {
    results[name] = { error: String(e) };
  }
}
const secrets = { includeBody: true, includeRequestSecrets: true };
const discoveries = (h) => h.filter((m) => m.type === 'discovery');

(async () => {
  await scenario('success', secrets, goodModules(), null, async ({ handled, sent }) => {
    await wait(50);
    return { msgs: discoveries(handled), sent, total: handled.length };
  });

  await scenario('not_configured', { includeBody: false }, goodModules(), null, async ({ handled }) => {
    await wait(50);
    return { total: handled.length };
  });

  await scenario('no_require_yet_then_message', secrets, null, null, async ({ ctx, handled, listeners }) => {
    await wait(50);
    const before = handled.length;
    ctx.require = (n) => goodModules()[n];
    (listeners.message || []).forEach((fn) => fn({ data: { storizeDiscover: true } }));
    return { before, after: discoveries(handled).length };
  });

  await scenario('other_message_ignored', secrets, null, null, async ({ ctx, handled, listeners }) => {
    await wait(50);
    ctx.require = (n) => goodModules()[n];
    (listeners.message || []).forEach((fn) => fn({ data: { hello: 1 } }));
    return { after: handled.length };
  });

  const partial = goodModules();
  delete partial['PolarisStoriesV3ReelPageStandaloneQuery_instagramRelayOperation'];
  delete partial['LSD'];
  await scenario('missing_module', secrets, partial, null, async ({ handled }) => {
    await wait(50);
    return { msgs: discoveries(handled) };
  });

  await scenario('one_module_throws', secrets, goodModules(), { throwOn: ['PolarisProfilePostsQuery.graphql'] }, async ({ handled }) => {
    await wait(50);
    return { msgs: discoveries(handled) };
  });

  await scenario('require_throws', secrets, goodModules(), { throwAll: true }, async ({ handled, sent }) => {
    await wait(50);
    return { msgs: discoveries(handled), sent };
  });

  await scenario('nothing_resolves', secrets, {}, null, async ({ handled }) => {
    await wait(50);
    return { msgs: discoveries(handled), total: handled.length };
  });

  await scenario('bounded_posts', secrets, { DTSGInitialData: { token: 'ZZFAKE_dtsg' } }, null, async ({ ctx, handled }) => {
    for (let i = 0; i < 30; i++) ctx.__storizeRunDiscovery();
    return { count: discoveries(handled).length };
  });

  process.stdout.write(JSON.stringify(results));
})();
