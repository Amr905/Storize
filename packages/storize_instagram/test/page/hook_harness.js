// Runs the real assets/hook.js in a Node `vm` context with fake fetch / XHR /
// sendBeacon / handler, and prints one JSON object per scenario.
// Usage: node hook_harness.js <path to hook.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const source = fs.readFileSync(process.argv[2], 'utf8');
const SEEN = 'PolarisStoriesV3SeenMutation';
const GQL = 'https://www.instagram.com/api/graphql';

function form(name, extra) {
  const p = new URLSearchParams();
  p.set('doc_id', '1234567890');
  p.set('variables', '{}');
  p.set('fb_api_req_friendly_name', name);
  p.set('fb_dtsg', 'ZZFAKE_dtsg');
  p.set('lsd', 'ZZFAKE_lsd');
  Object.keys(extra || {}).forEach((k) => p.set(k, extra[k]));
  return p;
}

function makeContext(config) {
  const sent = { fetch: [], xhr: [], beacon: [] };
  const handled = [];
  const ctx = {
    location: { href: 'https://www.instagram.com/stories/zzfake_user/', origin: 'https://www.instagram.com' },
    URL, URLSearchParams, Response, Request, Headers, Blob, FormData, ReadableStream, Uint8Array, ArrayBuffer, Event, EventTarget, Promise, JSON, Object, Array, String, setTimeout,
    flutter_inappwebview: { callHandler: (name, msg) => handled.push({ name, msg }) },
    __STORIZE_HOOK_CONFIG: config,
  };
  ctx.window = ctx;
  ctx.fetch = function (input, init) {
    sent.fetch.push({ url: typeof input === 'string' ? input : input.url, body: init && init.body ? String(init.body) : null });
    return Promise.resolve(new Response('{"data":{"real":true}}', { status: 200 }));
  };
  class FakeXHR extends EventTarget {
    constructor() { super(); this.readyState = 0; this.status = 0; this.responseType = ''; this.responseText = ''; this.response = ''; this.responseURL = ''; }
    open(m, u) { this._m = m; this._u = u; }
    send(body) {
      sent.xhr.push({ url: this._u, body: body == null ? null : String(body) });
      this.readyState = 4; this.status = 200; this.responseText = '{"data":{"real":true}}'; this.responseURL = this._u;
      setTimeout(() => this.dispatchEvent(new Event('loadend')), 0);
    }
  }
  ctx.XMLHttpRequest = FakeXHR;
  ctx.navigator = { sendBeacon: (url, data) => { sent.beacon.push({ url, data: String(data) }); return true; } };
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return { ctx, sent, handled };
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const results = {};

async function scenario(name, config, fn) {
  const env = makeContext(config);
  try {
    results[name] = await fn(env);
  } catch (e) {
    results[name] = { error: String(e) };
  }
}

(async () => {
  const secrets = { includeBody: true, includeRequestSecrets: true };

  await scenario('fetch_seen_blocked', { ...secrets, blockedFriendlyNames: [SEEN] }, async ({ ctx, sent, handled }) => {
    const res = await ctx.fetch(GQL, { method: 'POST', body: form(SEEN).toString() });
    await wait(10);
    return { sent: sent.fetch.length, status: res.status, body: await res.json(), handled: handled.map((h) => h.msg) };
  });

  await scenario('fetch_seen_urlsearchparams_blocked', { blockedFriendlyNames: [SEEN] }, async ({ ctx, sent }) => {
    await ctx.fetch('/api/graphql', { method: 'POST', body: form(SEEN) });
    return { sent: sent.fetch.length };
  });

  await scenario('fetch_default_list_blocks_seen', {}, async ({ ctx, sent }) => {
    await ctx.fetch(GQL, { method: 'POST', body: form(SEEN).toString() });
    return { sent: sent.fetch.length };
  });

  await scenario('fetch_other_passes_and_reports', secrets, async ({ ctx, sent, handled }) => {
    const res = await ctx.fetch(GQL, { method: 'POST', body: form('PolarisStoriesV3ReelPageStandaloneQuery').toString() });
    await wait(20);
    return { sent: sent.fetch.length, status: res.status, handled: handled.map((h) => h.msg) };
  });

  await scenario('fetch_no_secrets_when_not_configured', { includeBody: false }, async ({ ctx, handled }) => {
    await ctx.fetch(GQL, { method: 'POST', body: form('SomeQuery').toString() });
    await wait(20);
    return { handled: handled.map((h) => h.msg) };
  });

  await scenario('custom_list_adds_to_default', { blockedFriendlyNames: ['OtherMutation'] }, async ({ ctx, sent }) => {
    await ctx.fetch(GQL, { method: 'POST', body: form(SEEN).toString() });
    await ctx.fetch(GQL, { method: 'POST', body: form('OtherMutation').toString() });
    return { sent: sent.fetch.map((s) => s.body.includes(SEEN) ? 'seen' : 'other') };
  });

  await scenario('non_instagram_host_not_blocked', { blockedFriendlyNames: [SEEN] }, async ({ ctx, sent }) => {
    await ctx.fetch('https://example.test/api/graphql', { method: 'POST', body: form(SEEN).toString() });
    return { sent: sent.fetch.length };
  });

  await scenario('xhr_seen_blocked', { blockedFriendlyNames: [SEEN] }, async ({ ctx, sent, handled }) => {
    const xhr = new ctx.XMLHttpRequest();
    let loaded = false;
    xhr.onload = null;
    xhr.addEventListener('load', () => { loaded = true; });
    xhr.open('POST', GQL);
    xhr.send(form(SEEN).toString());
    await wait(20);
    return { sent: sent.xhr.length, loaded, status: xhr.status, readyState: xhr.readyState, text: xhr.responseText, handled: handled.map((h) => h.msg) };
  });

  await scenario('xhr_other_passes', secrets, async ({ ctx, sent, handled }) => {
    const xhr = new ctx.XMLHttpRequest();
    xhr.open('POST', GQL);
    xhr.send(form('PolarisProfilePostsQuery').toString());
    await wait(20);
    return { sent: sent.xhr.length, handled: handled.map((h) => h.msg) };
  });

  await scenario('beacon_seen_blocked', { blockedFriendlyNames: [SEEN] }, async ({ ctx, sent }) => {
    const r1 = ctx.navigator.sendBeacon(GQL, form(SEEN).toString());
    const r2 = ctx.navigator.sendBeacon(GQL, form('Other').toString());
    return { r1, r2, sent: sent.beacon.length };
  });

  // Round 2 (QA-F1): ordinary queries are never blocked, whatever the shape.
  const ORD = 'PolarisProfilePostsQuery';
  await scenario('ordinary_shapes_pass', {}, async ({ ctx, sent }) => {
    await ctx.fetch(GQL, { method: 'POST', body: form(ORD).toString() });
    await ctx.fetch(GQL, { method: 'POST', body: form(ORD) });
    await ctx.fetch(new ctx.Request(GQL, { method: 'POST', body: form(ORD).toString() }));
    await ctx.fetch(new URL(GQL), { method: 'POST', body: new Blob([form(ORD).toString()]) });
    const fd = new FormData(); fd.append('fb_api_req_friendly_name', ORD);
    await ctx.fetch(GQL, { method: 'POST', body: fd });
    await ctx.fetch(GQL, { method: 'POST', body: JSON.stringify({ name: ORD }) });
    await ctx.fetch(GQL + '?x=1', { method: 'POST', headers: { 'x-fb-friendly-name': ORD }, body: '{}' });
    ctx.navigator.sendBeacon(GQL, new Blob([form(ORD).toString()]));
    await wait(30);
    return { fetch: sent.fetch.length, beacon: sent.beacon.length };
  });

  await scenario('unreadable_stream_graphql_blocked', {}, async ({ ctx, sent, handled }) => {
    const stream = new ReadableStream({ start(c) { c.enqueue(new Uint8Array([1])); c.close(); } });
    const res = await ctx.fetch(GQL, { method: 'POST', body: stream, duplex: 'half' });
    return { sent: sent.fetch.length, status: res.status, handled: handled.map((h) => h.msg) };
  });

  await scenario('unreadable_stream_non_graphql_passes', {}, async ({ ctx, sent }) => {
    const stream = new ReadableStream({ start(c) { c.close(); } });
    await ctx.fetch('https://www.instagram.com/ajax/other', { method: 'POST', body: stream, duplex: 'half' });
    return { sent: sent.fetch.length };
  });

  await scenario('encoded_and_cased_name_blocked', {}, async ({ ctx, sent }) => {
    await ctx.fetch(GQL, { method: 'POST', body: 'x=' + encodeURIComponent(SEEN.toLowerCase()) });
    await ctx.fetch(GQL, { method: 'POST', body: 'x=' + SEEN.split('').map((c) => '%' + c.charCodeAt(0).toString(16)).join('') });
    return { sent: sent.fetch.length };
  });

  await scenario('legacy_markers_blocked', {}, async ({ ctx, sent }) => {
    await ctx.fetch('https://www.instagram.com/api/v1/stories/reel/seen/', { method: 'POST', body: 'x=1' });
    await ctx.fetch(GQL, { method: 'POST', body: '{"xdt_mark_story_reel_seen":1}' });
    return { sent: sent.fetch.length };
  });

  console.log(JSON.stringify(results));
})();
