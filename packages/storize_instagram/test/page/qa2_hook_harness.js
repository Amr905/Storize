// QA round 2 (T-014): new adversarial shapes against the REAL assets/hook.js
// in a Node `vm`. The fake network records the WHOLE request (url, headers,
// body text). "reached" = a seen marker was in what the network received.
// "passed" = the request reached the network at all.
// Usage: node qa2_hook_harness.js <path to hook.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const source = fs.readFileSync(process.argv[2], 'utf8');
const SEEN = 'PolarisStoriesV3SeenMutation';
const GQL = 'https://www.instagram.com/api/graphql';
const MARK = /polarisstoriesv3seenmutation|xdt_mark_story_reel_seen|\/stories\/reel\/seen/i;

function fields(name, extra) {
  return Object.assign({
    doc_id: '1234567890',
    variables: '{"reelId":"ZZFAKE"}',
    fb_api_req_friendly_name: name,
    fb_dtsg: 'ZZFAKE_dtsg',
    lsd: 'ZZFAKE_lsd',
  }, extra || {});
}
const enc = (name) => new URLSearchParams(fields(name)).toString();

function makeContext(opts) {
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
        if (init.headers) new Headers(init.headers).forEach((v, k) => { text += k + ':' + v + ' '; });
        const b = init.body;
        if (b != null) {
          if (typeof b === 'string') text += b;
          else if (typeof b.getReader === 'function') {
            const rd = b.getReader(); const dec = new TextDecoder();
            for (;;) { const { done, value } = await rd.read(); if (done) break; text += dec.decode(value); }
          } else text += await new Response(b).text();
        }
      }
    } catch (e) { text += '<describe-error ' + e + '>'; }
    return { kind, text };
  }
  const ctx = {
    location: { href: 'https://www.instagram.com/stories/zzfake_user/', origin: 'https://www.instagram.com' },
    URL, URLSearchParams, Response, Request, Headers, FormData, Blob, Event, EventTarget, Promise, JSON, Object, Array, String, setTimeout, TextDecoder, TextEncoder, ReadableStream, Uint8Array,
    flutter_inappwebview: { callHandler: (name, msg) => handled.push({ name, msg }) },
    __STORIZE_HOOK_CONFIG: opts.config || {},
  };
  ctx.window = ctx;
  ctx.fetch = function (input, init) {
    pending.push(describe('fetch', input, init));
    return Promise.resolve(new Response('{"data":{"real":true}}', { status: 200 }));
  };
  // XHR whose response fields are PROTOTYPE accessors, like a real browser.
  class FakeXHR extends EventTarget {
    constructor() { super(); this._s = { readyState: 0, status: 0, text: '' }; this.responseType = ''; this._h = {}; }
    get readyState() { return this._s.readyState; }
    get status() { return this._s.status; }
    get responseText() { return this._s.text; }
    get response() { return this._s.text; }
    get responseURL() { return String(this._u || ''); }
    open(m, u) { this._m = m; this._u = u; this._h = {}; this._s = { readyState: 1, status: 0, text: '' }; }
    setRequestHeader(k, v) { this._h[k] = v; }
    abort() {}
    send(body) {
      pending.push(describe('xhr', String(this._u), { headers: this._h, body }));
      this._s = { readyState: 4, status: 200, text: '{"data":{"REAL":true}}' };
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
async function scenario(name, fn, opts) {
  const env = makeContext(opts);
  try {
    const extra = (await fn(env)) || {};
    await wait(20);
    const sent = await Promise.all(env.pending);
    results[name] = {
      reached: sent.some((s) => MARK.test(s.text)),
      requests: sent.length,
      blockedNotices: env.handled.filter((h) => h.msg && h.msg.type === 'blocked').length,
      ...extra,
    };
  } catch (e) { results[name] = { error: String(e && e.stack || e) }; }
}
const enc1 = (s) => encodeURIComponent(s);
const streamOf = (...chunks) => new ReadableStream({
  start(c) { chunks.forEach((x) => c.enqueue(new TextEncoder().encode(x))); c.close(); },
});

(async () => {
  // ---- split across chunks / multipart
  await scenario('stream_init_body_graphql_split', async ({ ctx }) => {
    const body = enc(SEEN); const i = Math.floor(body.indexOf('SeenMutation'));
    await ctx.fetch(GQL, { method: 'POST', body: streamOf(body.slice(0, i), body.slice(i)), duplex: 'half' });
  });
  await scenario('stream_init_body_non_graphql_split', async ({ ctx }) => {
    const body = enc(SEEN); const i = body.indexOf('SeenMutation');
    await ctx.fetch('https://www.instagram.com/ajax/bz', { method: 'POST', body: streamOf(body.slice(0, i), body.slice(i)), duplex: 'half' });
  });
  await scenario('request_stream_body_split', async ({ ctx }) => {
    const body = enc(SEEN); const i = body.indexOf('SeenMutation');
    await ctx.fetch(new Request(GQL, { method: 'POST', body: streamOf(body.slice(0, i), body.slice(i)), duplex: 'half' }));
  });
  await scenario('request_stream_body_split_non_graphql', async ({ ctx }) => {
    const body = enc(SEEN); const i = body.indexOf('SeenMutation');
    await ctx.fetch(new Request('https://www.instagram.com/ajax/bz', { method: 'POST', body: streamOf(body.slice(0, i), body.slice(i)), duplex: 'half' }));
  });
  await scenario('multipart_string_body', async ({ ctx }) => {
    const b = '----X';
    const body = `--${b}\r\nContent-Disposition: form-data; name="fb_api_req_friendly_name"\r\n\r\n${SEEN}\r\n--${b}--\r\n`;
    await ctx.fetch(GQL, { method: 'POST', headers: { 'content-type': 'multipart/form-data; boundary=' + b }, body });
  });
  await scenario('multipart_formdata_blob_part', async ({ ctx }) => {
    const fd = new FormData(); fd.append('fb_api_req_friendly_name', new Blob([SEEN]), 'f.txt');
    await ctx.fetch(GQL, { method: 'POST', body: fd });
  });
  await scenario('multipart_string_name_in_field_name', async ({ ctx }) => {
    const b = '----X';
    const body = `--${b}\r\nContent-Disposition: form-data; name="${SEEN}"\r\n\r\n1\r\n--${b}--\r\n`;
    await ctx.fetch(GQL, { method: 'POST', body });
  });
  // ---- encodings and case
    await scenario('name_in_url_query', async ({ ctx }) => { await ctx.fetch(GQL + '?x=' + SEEN, { method: 'POST', body: 'a=b' }); });
  await scenario('encoded_all_chars_once', async ({ ctx }) => {
    const all = [...SEEN].map((c) => '%' + c.charCodeAt(0).toString(16)).join('');
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + all });
  });
  await scenario('encoded_all_chars_twice', async ({ ctx }) => {
    let s = [...SEEN].map((c) => '%' + c.charCodeAt(0).toString(16)).join('');
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + enc1(s) });
  });
  await scenario('encoded_some_chars_twice_mixed', async ({ ctx }) => {
    const v = SEEN.replace('S', '%2553').replace('M', '%254d');
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + v });
  });
  await scenario('encoded_all_chars_thrice', async ({ ctx }) => {
    let s = [...SEEN].map((c) => '%' + c.charCodeAt(0).toString(16)).join('');
    s = enc1(enc1(s));
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + s });
  });
  await scenario('json_unicode_escape', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ fb_api_req_friendly_name: SEEN }).replace('Polaris', '\\u0050olaris') });
  });
  await scenario('json_plain', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ fb_api_req_friendly_name: SEEN }) });
  });
  await scenario('case_upper', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + SEEN.toUpperCase() }); });
  await scenario('case_lower', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + SEEN.toLowerCase() }); });
  await scenario('unicode_fullwidth', async ({ ctx }) => {
    const fw = [...SEEN].map((c) => String.fromCharCode(c.charCodeAt(0) + 0xfee0)).join('');
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + enc1(fw) });
  });
  await scenario('unicode_dotted_I_and_long_s', async ({ ctx }) => {
    const odd = SEEN.replace(/i/g, 'İ').replace(/S/g, 'ſ');
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + enc1(odd) });
  });
  await scenario('unicode_combining_mark_inside', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: 'fb_api_req_friendly_name=' + enc1(SEEN.replace('Seen', 'Séen')) });
  });
  await scenario('malformed_percent_does_not_throw', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: '%E0%A4%A&%zz=%&' + enc(SEEN) });
  });
  await scenario('legacy_rest_path', async ({ ctx }) => { await ctx.fetch('https://i.instagram.com/api/v1/stories/reel/seen', { method: 'POST', body: 'x=1' }); });
  await scenario('legacy_rest_path_upper', async ({ ctx }) => { await ctx.fetch('https://www.instagram.com/API/V1/Stories/Reel/Seen/', { method: 'POST', body: 'x=1' }); });
  await scenario('legacy_marker_in_body', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', body: 'q=xdt_mark_story_reel_seen' }); });
  // ---- beacon
  await scenario('beacon_urlsearchparams', async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, new URLSearchParams(fields(SEEN))); });
  await scenario('beacon_blob', async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, new Blob([enc(SEEN)], { type: 'application/x-www-form-urlencoded' })); });
  await scenario('beacon_blob_return_value', async ({ ctx }) => ({ ret: ctx.navigator.sendBeacon(GQL, new Blob([enc(SEEN)])) }));
  await scenario('beacon_url_object', async ({ ctx }) => { ctx.navigator.sendBeacon(new URL(GQL), enc(SEEN)); });
  await scenario('beacon_typed_array', async ({ ctx }) => { ctx.navigator.sendBeacon(GQL, new TextEncoder().encode(enc(SEEN))); });
  await scenario('beacon_stream_non_graphql', async ({ ctx }) => { ctx.navigator.sendBeacon('https://www.instagram.com/ajax/bz', streamOf(enc(SEEN))); });
  await scenario('beacon_marker_in_url', async ({ ctx }) => { ctx.navigator.sendBeacon('https://www.instagram.com/api/v1/stories/reel/seen/', 'a=1'); });
  // ---- reused XHR
  await scenario('xhr_reused_blocked_then_blocked', async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    x.open('POST', GQL); x.send(enc(SEEN));
    await wait(5);
    x.open('POST', GQL); x.send(enc(SEEN));
  });
  await scenario('xhr_reused_ok_then_blocked', async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    x.open('POST', GQL); x.setRequestHeader('x-a', 'b'); x.send(enc('PolarisProfilePageContentQuery'));
    await wait(5);
    x.open('POST', GQL); x.send(enc(SEEN));
  });
  await scenario('xhr_reused_blocked_then_ok', async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    x.open('POST', GQL); x.send(enc(SEEN));
    await wait(5);
    x.open('POST', GQL); x.send(enc('PolarisProfilePageContentQuery'));
    await wait(5);
    return { requestsAfter: 1, secondResponseText: x.responseText, secondStatusReal: x.responseText.indexOf('REAL') !== -1 };
  });
  await scenario('xhr_header_set_then_reused_headers_reset', async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    x.open('POST', GQL); x.setRequestHeader('x-fb-friendly-name', SEEN);
    x.open('POST', GQL); // headers cleared by the browser; hook resets its log too
    x.send('a=1');
  });
  await scenario('xhr_blocked_then_abort_before_send_microtask', async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    x.open('POST', GQL); x.send(new Blob([enc(SEEN)])); x.abort();
  });
  await scenario('xhr_async_body_blocked_then_not_sent', async ({ ctx }) => {
    const x = new ctx.XMLHttpRequest();
    x.open('POST', GQL); x.send(new Blob([enc(SEEN)]));
  });
  // ---- page restores / captures fetch
  await scenario('page_wraps_hooked_fetch', async ({ ctx }) => {
    const hooked = ctx.fetch;
    ctx.fetch = function (i, n) { return hooked.call(this, i, n); };
    await ctx.fetch(GQL, { method: 'POST', body: enc(SEEN) });
  });
  await scenario('page_calls_fetch_via_apply_call_reflect', async ({ ctx }) => {
    await ctx.fetch.call(ctx, GQL, { method: 'POST', body: enc(SEEN) });
    await ctx.fetch.apply(null, [GQL, { method: 'POST', body: enc(SEEN) }]);
    await Reflect.apply(ctx.fetch, undefined, [GQL, { method: 'POST', body: enc(SEEN) }]);
  });
  await scenario('page_second_hook_inject_does_not_unwrap', async ({ ctx }) => {
    vm.runInContext(source, ctx);
    await ctx.fetch(GQL, { method: 'POST', body: enc(SEEN) });
  });
  await scenario('page_deletes_flag_and_reinjects_double_wrap', async ({ ctx }) => {
    ctx.__storizeHookInstalled = false;
    vm.runInContext(source, ctx);
    await ctx.fetch(GQL, { method: 'POST', body: enc(SEEN) });
  });
  await scenario('proto_restore_xhr_send_via_getOwnPropertyDescriptor', async ({ ctx }) => {
    // the page can only see the wrapper; the original is in a closure.
    const d = Object.getOwnPropertyDescriptor(ctx.XMLHttpRequest.prototype, 'send');
    const x = new ctx.XMLHttpRequest(); x.open('POST', GQL); d.value.call(x, enc(SEEN));
  });
  await scenario('xhr_subclass_page_defined', async ({ ctx }) => {
    class MyX extends ctx.XMLHttpRequest {}
    const x = new MyX(); x.open('POST', GQL); x.send(enc(SEEN));
  });
  // ---- keepalive
  await scenario('fetch_keepalive_string', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', keepalive: true, body: enc(SEEN) }); });
  await scenario('fetch_keepalive_request', async ({ ctx }) => { await ctx.fetch(new Request(GQL, { method: 'POST', keepalive: true, body: enc(SEEN) })); });
  await scenario('fetch_keepalive_blob', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', keepalive: true, body: new Blob([enc(SEEN)]) }); });
  await scenario('fetch_keepalive_stream_graphql', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', keepalive: true, body: streamOf(enc(SEEN)), duplex: 'half' });
  });
  await scenario('fetch_request_plus_init_override_headers_only', async ({ ctx }) => {
    await ctx.fetch(new Request(GQL, { method: 'POST', body: enc(SEEN) }), { headers: { a: 'b' } });
  });
  await scenario('fetch_url_with_userinfo_and_hash', async ({ ctx }) => {
    await ctx.fetch('https://www.instagram.com/api/graphql#frag', { method: 'POST', body: enc(SEEN) });
  });
  await scenario('fetch_protocol_relative', async ({ ctx }) => {
    await ctx.fetch('//www.instagram.com/api/graphql', { method: 'POST', body: enc(SEEN) });
  });
  await scenario('fetch_headers_instance_name', async ({ ctx }) => {
    const h = new Headers(); h.set('X-FB-Friendly-Name', SEEN);
    await ctx.fetch(GQL, { method: 'POST', headers: h, body: 'a=1' });
  });
  await scenario('fetch_headers_array_pairs', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', headers: [['x-fb-friendly-name', SEEN]], body: 'a=1' });
  });
  await scenario('fetch_body_getter_throws', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', get body() { throw new Error('x'); } });
  });
  await scenario('fetch_init_getter_throws_on_non_graphql', async ({ ctx }) => {
    await ctx.fetch('https://www.instagram.com/x', { method: 'POST', get body() { throw new Error('x'); } });
  });
  await scenario('fetch_no_name_but_doc_id_only', async ({ ctx }) => {
    // The hook matches names, not doc_id: a request with no name at all passes (known residual).
    await ctx.fetch(GQL, { method: 'POST', body: 'doc_id=1234567890&variables=%7B%7D' });
  });

  // ---- needed queries must pass (no false positives)
  const needed = {
    stories: 'PolarisStoriesV3ReelPageStandaloneQuery',
    profile: 'PolarisProfilePageContentQuery',
    posts: 'PolarisProfilePostsQuery',
    timeline: 'PolarisProfilePostsTabContentQuery_connection',
    media_info: 'PolarisPostRootQuery',
  };
  for (const [k, n] of Object.entries(needed)) {
    await scenario('needed_' + k + '_string', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', body: enc(n) }); });
    await scenario('needed_' + k + '_formdata', async ({ ctx }) => {
      const fd = new FormData(); Object.entries(fields(n)).forEach(([a, b]) => fd.append(a, b));
      await ctx.fetch(GQL, { method: 'POST', body: fd });
    });
    await scenario('needed_' + k + '_request_obj', async ({ ctx }) => { await ctx.fetch(new Request(GQL, { method: 'POST', body: enc(n) })); });
    await scenario('needed_' + k + '_xhr', async ({ ctx }) => { const x = new ctx.XMLHttpRequest(); x.open('POST', GQL); x.send(enc(n)); });
    await scenario('needed_' + k + '_typed_array', async ({ ctx }) => { await ctx.fetch(GQL, { method: 'POST', body: new TextEncoder().encode(enc(n)) }); });
  }
  await scenario('needed_get_media_info_rest', async ({ ctx }) => { await ctx.fetch('https://www.instagram.com/api/v1/media/3000000000000000000/info/'); });
  await scenario('needed_get_reels_media_rest', async ({ ctx }) => { await ctx.fetch('https://i.instagram.com/api/v1/feed/reels_media/?reel_ids=1'); });
  await scenario('needed_get_user_info_rest', async ({ ctx }) => { await ctx.fetch('https://www.instagram.com/api/v1/users/web_profile_info/?username=zzfake'); });
  await scenario('needed_get_feed_user', async ({ ctx }) => { await ctx.fetch('https://www.instagram.com/api/v1/feed/user/1/?count=12'); });
  await scenario('needed_get_request_object_no_body', async ({ ctx }) => { await ctx.fetch(new Request('https://www.instagram.com/api/v1/feed/user/1/')); });
  await scenario('needed_substring_seen_variables', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: new URLSearchParams(fields('PolarisProfilePageContentQuery', {
      variables: JSON.stringify({ seen: true, has_seen: false, last_seen_at: 1, seen_state: 'x', unseen_count: 3, viewer_seen_reels: [] }),
      extra_seen_mutation: 'SeenMutation', note: 'Polaris Stories V3 Seen' })).toString() });
  });
  await scenario('needed_header_substring_seen', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', headers: { 'x-seen': '1', 'x-ig-app-id': '936619743392459' }, body: enc('PolarisProfilePageContentQuery') });
  });
  await scenario('needed_url_substring_seen', async ({ ctx }) => {
    await ctx.fetch('https://www.instagram.com/api/v1/feed/reels_media/?seen=1&stories=reel&x=/stories/reel');
  });
  await scenario('needed_username_called_seen', async ({ ctx }) => {
    await ctx.fetch('https://www.instagram.com/api/v1/users/web_profile_info/?username=seen_mutation');
  });
  await scenario('needed_non_instagram_host_stream', async ({ ctx }) => {
    await ctx.fetch('https://example.test/api/graphql', { method: 'POST', body: streamOf('a'), duplex: 'half' });
  });
  await scenario('needed_graphql_stream_body_is_blocked_by_rule', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: streamOf(enc('PolarisProfilePageContentQuery')), duplex: 'half' });
  });
  await scenario('needed_graphql_request_with_stream_body_is_read_not_blocked', async ({ ctx }) => {
    await ctx.fetch(new Request(GQL, { method: 'POST', body: streamOf(enc('PolarisProfilePageContentQuery')), duplex: 'half' }));
  });
  await scenario('needed_large_body_900kb', async ({ ctx }) => {
    await ctx.fetch(GQL, { method: 'POST', body: enc('PolarisProfilePageContentQuery') + '&pad=' + 'a'.repeat(900000) });
  });
  console.log(JSON.stringify(results, null, 1));
})();
