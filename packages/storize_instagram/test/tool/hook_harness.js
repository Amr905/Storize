// QA harness: runs assets/hook.js against a mocked browser (FAKE data only).
// usage: node hook_harness.js <hook.js> <includeBody:true|false>
const fs = require('fs');
const src = fs.readFileSync(process.argv[2], 'utf8');
const includeBody = process.argv[3] === 'true';
const sent = [];
const body = '{"reels_media":[],"sessionid":"ZZFAKEbodysecret","status":"ok"}';
global.window = global;
global.location = { href: 'https://www.instagram.com/', origin: 'https://www.instagram.com' };
global.document = { cookie: 'sessionid=ZZFAKEdocumentcookie; csrftoken=ZZFAKEcsrf' };
global.XMLHttpRequest = function () {};
global.XMLHttpRequest.prototype.open = function () {};
global.XMLHttpRequest.prototype.send = function () {};
global.window.flutter_inappwebview = {
  callHandler: (name, msg) => sent.push({ name, msg }),
};
global.window.__STORIZE_HOOK_CONFIG = { handler: 'storizeHook', includeBody };
global.window.fetch = (input) =>
  Promise.resolve({
    url: 'https://www.instagram.com/api/v1/feed/reels_media/?reel_ids=1&sig=ZZFAKEquery',
    status: 200,
    clone() { return { text: () => Promise.resolve(body) }; },
  });
(0, eval)(src);
window.fetch('https://www.instagram.com/api/v1/feed/reels_media/?reel_ids=1')
  .then(() => new Promise((r) => setTimeout(r, 50)))
  .then(() => {
    // also: non-instagram fetch must not be reported
    return window.fetch('https://evil.example.com/x');
  })
  .then(() => new Promise((r) => setTimeout(r, 50)))
  .then(() => console.log(JSON.stringify(sent)));
