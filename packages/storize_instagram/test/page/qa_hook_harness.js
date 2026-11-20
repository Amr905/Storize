// QA (T-014): adversarial scenarios for the seen-mutation block, run against
// the REAL assets/hook.js in a Node `vm` context. For every scenario the fake
// network records the WHOLE request (url, headers, body text) and the result
// says whether the mutation name "reached" it. Prints one JSON object.
// Usage: node qa_hook_harness.js <path to hook.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const source = fs.readFileSync(process.argv[2], 'utf8');
const SEEN = 'PolarisStoriesV3SeenMutation';
const GQL = 'https://www.instagram.com/api/graphql';

function fields(name) {
  return {
    doc_id: '1234567890',
    variables: '{"reelId":"ZZFAKE"}',
    fb_api_req_friendly_name: name,
    fb_dtsg: 'ZZFAKE_dtsg',
    lsd: 'ZZFAKE_lsd',
  };
}
function urlEncoded(name) {
  return new URLSearchParams(fields(name)).toString();
}
function formData(name) {
  const fd = new FormData();
  Object.entries(fields(name)).forEach(([k, v]) => fd.append(k, v));
  return fd;
}

function makeContext(config, opts) {
  opts = opts || {};
  const pending = [];
  const handled = [];
  async function describe(kind, input, init) {
    let text = '';
    try {
      if (typeof input === 'string') text += input;
      else if (input instanceof URL) text += input.href;
      else if (input && typeof input.clone === 'function') {
        text += input.url + ' ';
        input.headers.forEach((v, k) => { text += k + ':' + v + ' '; });
        text += await input.clone().text();
      }
      if (init) {
        if (init.headers) {
          const h = new Headers(init.headers);
          h.forEach((v, k) => { text += k + ':' + v + ' '; });
        }
        const b = init.body;
        if (b != null) {
          if (typeof b === 'string') text += b;
          else if (b instanceof Blob) text += await b.text();
          else text += await new Response(b).text();
        }
      }
    } catch (e) { text += '<describe-error ' + e + '>'; }
    return { kind, text };
  }
  const ctx = {
    location: { href: opts.href || 'https://www.instagram.com/stories/zzfake_user/', origin: 'https://www.instagram.com' },
    URL, URLSearchParams, Response, Request, Headers, FormData, Blob, Event, EventTarget, Promise, JSON, Object, Array, String, setTimeout,
    flutter_inappwebview: { callHandler: (name, msg) => handled.push({ name, msg }) },
    __STORIZE_HOOK_CONFIG: config,
  };
  ctx.window = ctx;
  ctx.fetch = function (input, init) {
    pending.push(describe('fetch', input, init));
    return Promise.resolve(new Response('{"data":{"real":true}}', { status: 200 }));
  };
  class FakeXHR extends EventTarget {
    constructor() { super(); this.readyState = 0; this.status = 0; this.responseType = ''; this.responseText = ''; this.response = ''; this.responseURL = ''; this._h = {}; }
    open(m, u) { this._m = m; this._u = u; }
    setRequestHeader(k, v) { this._h[k] = v; }
    send(body) {
      pending.push(describe('xhr', String(this._u), { headers: this._h, body }));
      this.readyState = 4; this.status = 200; this.responseText = '{"data":{"real":true}}'; this.responseURL = String(this._u);
      setTimeout(() => this.dispatchEvent(new Event('loadend')), 0);
    }
  }
  ctx.XMLHttpRequest = FakeXHR;
  ctx.navigator = { sendBeacon: (url, data) => { pending.push(describe('beacon', String(url), { body: data })); return true; } };
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return { ctx, pending, handled };
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const results = {};

// Runs [fn]; records whether the mutation name reached the fake network.
async function scenario(name, config, fn, opts) {
  const env = makeContext(config, opts);
  try {
    const extra = (await fn(env)) || {};
    await wait(10);
    const sent = await Promise.all(env.pending);
    results[name] = {
      reached: sent.some((s) => s.text.indexOf(SEEN) !== -1),
      requests: sent.length,
      blockedNotices: env.handled.filter((h) => h.msg && h.msg.type === 'blocked').length,
      ...extra,
    };
  } catch (e) {
    results[name] = { error: String(e && e.stack || e) };
  }
}

const D = { blockedFriendlyNames: [SEEN] };

(async () => {
  // ---- control: the supported shape is blocked
  await scenario('control_string_body', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
  });

  // ---- bodies and inputs the hook does not parse
  await scenario('fetch_request_object', D, async ({ ctx }) => {
    await ctx.fetch(new Request(GQL, { method: 'POST', body: urlEncoded(SEEN) }));
  });
  await scenario('fetch_request_object_plus_init_body', D, async ({ ctx }) => {
    await ctx.fetch(new Request(GQL, { method: 'POST' }), { body: urlEncoded(SEEN) });
  });
  await scenario('fetch_url_object_input', D, async ({ ctx }) => {
    await ctx.fetch(new URL(GQL), { method: 'POST', body: urlEncoded(SEEN) });
  });
  await scenario('fetch_formdata_body', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: formData(SEEN) });
  });
  await scenario('fetch_blob_body', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: new Blob([urlEncoded(SEEN)], { type: 'application/x-www-form-urlencoded' }) });
  });
  await scenario('fetch_arraybuffer_body', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: new TextEncoder().encode(urlEncoded(SEEN)) });
  });
  await scenario('fetch_json_body', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(fields(SEEN)) });
  });
  await scenario('fetch_name_in_header_only', D, async ({ ctx }) => {
    const f = fields('Other'); delete f.fb_api_req_friendly_name;
    await ctx.fetch(GQL, { method: 'POST', headers: { 'x-fb-friendly-name': SEEN }, body: new URLSearchParams(f).toString() });
  });
  await scenario('fetch_name_in_query_only', D, async ({ ctx }) => {
    const f = fields('Other'); delete f.fb_api_req_friendly_name;
    await ctx.fetch(GQL + '?fb_api_req_friendly_name=' + SEEN, { method: 'POST', body: new URLSearchParams(f).toString() });
  });
  await scenario('fetch_get_with_query', D, async ({ ctx }) => {
    await ctx.fetch(GQL + '?' + urlEncoded(SEEN), { method: 'GET' });
  });
  await scenario('fetch_name_urlencoded_with_space', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN + ' ') });
  });
  await scenario('fetch_name_lowercase', D, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN.toLowerCase()) });
  });
  await scenario('fetch_duplicate_name_key_first_other', D, async ({ ctx }) => {
    // form.get returns the FIRST value; a second key with the real name rides along
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=Other&' + urlEncoded(SEEN) });
  });

  // ---- other endpoint paths (name matching is path independent)
  for (const [tag, url] of [
    ['graphql_query', 'https://www.instagram.com/graphql/query'],
    ['api_graphql_slash', 'https://www.instagram.com/api/graphql/'],
    ['relative', '/api/graphql'],
    ['bare_domain', 'https://instagram.com/api/graphql'],
    ['subdomain_i', 'https://i.instagram.com/api/graphql'],
    ['graph_host', 'https://graph.instagram.com/graphql'],
  ]) {
    await scenario('path_' + tag, D, async ({ ctx }) => {
      await ctx.fetch(url, { method: 'POST', body: urlEncoded(SEEN) });
    });
  }
  await scenario('host_lookalike_not_instagram', D, async ({ ctx }) => {
    await ctx.fetch('https://instagram.com.evil.test/api/graphql', { method: 'POST', body: urlEncoded(SEEN) });
  });
  await scenario('host_facebook', D, async ({ ctx }) => {
    await ctx.fetch('https://www.facebook.com/api/graphql/', { method: 'POST', body: urlEncoded(SEEN) });
  });

  // ---- XHR
  await scenario('xhr_string', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.open('POST', GQL); x.send(urlEncoded(SEEN));
  });
  await scenario('xhr_formdata', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.open('POST', GQL); x.send(formData(SEEN));
  });
  await scenario('xhr_blob', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.open('POST', GQL); x.send(new Blob([urlEncoded(SEEN)]));
  });
  await scenario('xhr_url_object', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.open('POST', new URL(GQL)); x.send(urlEncoded(SEEN));
  });
  await scenario('xhr_header_name', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.open('POST', GQL); x.setRequestHeader('x-fb-friendly-name', SEEN); x.send('doc_id=1');
  });

  // ---- sendBeacon
  await scenario('beacon_string', D, async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, urlEncoded(SEEN)); });
  await scenario('beacon_urlsearchparams', D, async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, new URLSearchParams(fields(SEEN))); });
  await scenario('beacon_blob', D, async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, new Blob([urlEncoded(SEEN)])); });
  await scenario('beacon_formdata', D, async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, formData(SEEN)); });

  // ---- config
  await scenario('config_empty_list', { blockedFriendlyNames: [] }, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
  });
  await scenario('config_other_list', { blockedFriendlyNames: ['SomethingElse'] }, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
  });
  await scenario('config_null_list', { blockedFriendlyNames: null }, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
  });
  await scenario('config_string_list', { blockedFriendlyNames: SEEN }, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
  });
  await scenario('config_undefined_all', undefined, async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
  });

  // ---- page tampering after install
  await scenario('page_reassigns_fetch_to_original_via_iframe_like', D, async ({ ctx }) => {
    // The hook cannot see a fetch taken from a fresh realm; model it by the
    // realm's own (unhooked) fetch: here the harness fetch is replaced by the
    // hook, so we just assert the hook is installed once.
    const first = ctx.fetch;
    vm.runInContext(source, ctx); // a second injection (iframe reload) must not double wrap
    return { stableWrapper: first === ctx.fetch };
  });

  // ---- the fake reply as the page sees it
  await scenario('fake_reply_shape_fetch', D, async ({ ctx }) => {
    const res = await ctx.fetch(GQL, { method: 'POST', body: urlEncoded(SEEN) });
    const headers = {}; res.headers.forEach((v, k) => { headers[k] = v; });
    return { status: res.status, ok: res.ok, headers, url: res.url, redirected: res.redirected, body: await res.text() };
  });
  await scenario('fake_reply_shape_xhr', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    let events = [];
    ['readystatechange', 'load', 'loadend'].forEach((t) => x.addEventListener(t, () => events.push(t)));
    x.open('POST', GQL); x.send(urlEncoded(SEEN));
    await wait(10);
    return { events, status: x.status, ready: x.readyState, text: x.responseText,
      hasGetAllResponseHeaders: typeof x.getAllResponseHeaders };
  });
  await scenario('xhr_json_response_type', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.responseType = 'json'; x.open('POST', GQL); x.send(urlEncoded(SEEN));
    return { response: x.response };
  });
  await scenario('xhr_blob_arraybuffer_response_type', D, async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest(); x.responseType = 'arraybuffer'; x.open('POST', GQL); x.send(urlEncoded(SEEN));
    return { responseType: typeof x.response, response: String(x.response) };
  });

  console.log(JSON.stringify(results));
})();
