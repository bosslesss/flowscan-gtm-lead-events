// Runs template.tpl outside GTM: a small emulator of the sandbox APIs the template may use, so the
// ___TESTS___ scenarios stored in the .tpl (what GTM's own test runner and the gallery read) run in CI too,
// plus extra checks GTM's runner cannot make (permissions match the APIs used, names match the scanner).
// Usage: node ops/gtm-template/test_template.js
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const tpl = fs.readFileSync(path.join(__dirname, 'template.tpl'), 'utf8');
const sections = {};
const parts = tpl.split(/^___([A-Z_]+)___\s*$/m);
for (let i = 1; i < parts.length; i += 2) sections[parts[i]] = parts[i + 1].trim();
const info = JSON.parse(sections.INFO);
const params = JSON.parse(sections.TEMPLATE_PARAMETERS);
const permissions = JSON.parse(sections.WEB_PERMISSIONS);
const code = sections.SANDBOXED_JS_FOR_WEB_TEMPLATE;

// require() name -> the permission id GTM demands for it (null = none needed).
const NEEDS = { createArgumentsQueue: 'access_globals', callInWindow: 'access_globals', copyFromWindow: 'access_globals',
  setInWindow: 'access_globals', logToConsole: 'logging', getTimestampMillis: null, generateRandom: null,
  makeString: null, isConsentGranted: 'access_consent' };

// Run the template code once with the given data; mocks override the default API emulation.
function run(data, mocks) {
  const calls = [];
  const globals = Object.assign({ fbq: true }, (mocks && mocks.globals) || {});
  const api = {
    createArgumentsQueue: (fn, q) => (...a) => calls.push(['gtag', q, ...a]),
    callInWindow: (fn, ...a) => calls.push([fn, ...a]),
    copyFromWindow: (k) => globals[k],
    setInWindow: (k, v) => { globals[k] = v; calls.push(['setInWindow', k, v]); return true; },
    logToConsole: (...a) => calls.push(['log', ...a]),
    getTimestampMillis: () => 1700000000000,
    generateRandom: (a) => a + 7,
    makeString: String,
    isConsentGranted: (k) => !((mocks && mocks.denied) || []).includes(k),
  };
  Object.assign(api, mocks || {});
  delete api.globals; delete api.denied;
  let outcome = null;
  const d = Object.assign({}, data, { gtmOnSuccess: () => { outcome = 'success'; }, gtmOnFailure: () => { outcome = 'failure'; } });
  new Function('require', 'data', code)((n) => { if (!(n in api)) throw new Error('unknown API ' + n); return api[n]; }, d);
  return { calls, outcome, globals };
}
const gtag = (r) => r.calls.find((c) => c[0] === 'gtag');
const fbq = (r) => r.calls.find((c) => c[0] === 'fbq');
const base = { eventName: 'generate_lead', sendGa4: true, sendMeta: true, ga4MeasurementId: 'G-TEST123456' };

const tests = {
  'info is a web tag template': () => {
    assert.strictEqual(info.type, 'TAG');
    assert.deepStrictEqual(info.containerContexts, ['WEB']);
    assert.strictEqual(info.displayName, 'FlowScan lead events');
  },
  'every event name is read by the scanner as a lead event': () => {
    const catPath = path.join(__dirname, '..', '..', 'backend', 'config', 'signal_catalog.json');
    // Only exists inside the FlowScan repo; the standalone template repo has no scanner to check against.
    if (!fs.existsSync(catPath)) return;
    const cat = fs.readFileSync(catPath, 'utf8');
    const re = new RegExp(cat.match(/"lead_event_regex":\s*"([^"]+)"/)[1], 'i');
    const opts = params.find((p) => p.name === 'eventName').selectItems.map((s) => s.value);
    assert.strictEqual(opts.length, 4);
    opts.forEach((o) => assert.ok(re.test(o), o + ' does not match lead_event_regex'));
  },
  'form submit sends GA4 generate_lead and Meta Lead with one event id': () => {
    const r = run(base);
    const g = gtag(r), f = fbq(r);
    assert.deepStrictEqual(g.slice(0, 3), ['gtag', 'dataLayer', 'event']);
    assert.strictEqual(g[3], 'generate_lead');
    assert.strictEqual(f[1], 'track');
    assert.strictEqual(f[2], 'Lead');
    assert.ok(g[4].event_id && g[4].event_id === f[4].eventID, 'GA4 and Meta must share the event id');
    assert.strictEqual(r.outcome, 'success');
  },
  'each lead type maps to its GA4 and Meta names': () => {
    const want = { generate_lead: 'Lead', contact_phone: 'Contact', schedule_appointment: 'Schedule', contact_chat: 'Contact' };
    Object.keys(want).forEach((n) => {
      const r = run(Object.assign({}, base, { eventName: n }));
      assert.strictEqual(gtag(r)[3], n);
      assert.strictEqual(fbq(r)[2], want[n]);
    });
  },
  'a supplied event id is used for both and published for a server-side send': () => {
    const r = run(Object.assign({}, base, { eventId: 'lead-123' }));
    assert.strictEqual(gtag(r)[4].event_id, 'lead-123');
    assert.strictEqual(fbq(r)[4].eventID, 'lead-123');
    assert.strictEqual(r.globals.fs_last_lead_event_id, 'lead-123');
  },
  'a generated event id is well formed and differs between leads': () => {
    let n = 0;
    const m = { generateRandom: () => ++n * 1000 };
    const a = gtag(run(base, m))[4].event_id;
    const b = gtag(run(base, m))[4].event_id;
    assert.ok(/^fs_[a-z0-9_]+$/.test(a), a);
    assert.notStrictEqual(a, b);
  },
  'GA4 is sent to the chosen measurement id': () => assert.strictEqual(gtag(run(base))[4].send_to, 'G-TEST123456'),
  'sendMeta off sends no Meta event': () => {
    const r = run(Object.assign({}, base, { sendMeta: false }));
    assert.ok(gtag(r));
    assert.ok(!fbq(r));
  },
  'sendGa4 off sends no GA4 event': () => {
    const r = run(Object.assign({}, base, { sendGa4: false }));
    assert.ok(!gtag(r));
    assert.ok(fbq(r));
  },
  'no Meta pixel on the page still sends GA4 and logs it': () => {
    const r = run(base, { globals: { fbq: undefined } });
    assert.ok(gtag(r));
    assert.ok(!fbq(r));
    assert.ok(r.calls.some((c) => c[0] === 'log'));
    assert.strictEqual(r.outcome, 'success');
  },
  'nothing to send fails the tag': () => assert.strictEqual(run(Object.assign({}, base, { sendGa4: false, sendMeta: false })).outcome, 'failure'),
  'only the event id and send_to go to GA4, nothing goes in the Meta custom data': () => {
    const r = run(Object.assign({}, base, { email: 'a@b.c' }));
    assert.deepStrictEqual(Object.keys(gtag(r)[4]).sort(), ['event_id', 'send_to']);
    assert.deepStrictEqual(Object.keys(fbq(r)[3] || {}), []);
  },
  'GA4 is sent with analytics consent alone, Meta is held back without ad consent': () => {
    const r = run(base, { denied: ['ad_storage'] });
    assert.ok(gtag(r), 'GA4 must fire when only analytics_storage is granted');
    assert.ok(!fbq(r), 'Meta must not fire without ad_storage');
    assert.strictEqual(r.outcome, 'success');
  },
  'Meta is sent with ad consent alone, GA4 is held back without analytics consent': () => {
    const r = run(base, { denied: ['analytics_storage'] });
    assert.ok(!gtag(r));
    assert.ok(fbq(r));
    assert.strictEqual(r.outcome, 'success');
  },
  'no consent for either destination sends nothing and fails the tag': () => {
    const r = run(base, { denied: ['analytics_storage', 'ad_storage'] });
    assert.ok(!gtag(r) && !fbq(r));
    assert.strictEqual(r.outcome, 'failure');
  },
  'permissions cover every API the code requires': () => {
    const used = [...code.matchAll(/require\('(\w+)'\)/g)].map((m) => m[1]);
    assert.ok(used.length);
    const have = permissions.map((p) => p.instance.key.publicId);
    used.forEach((u) => {
      assert.ok(u in NEEDS, 'unmapped API ' + u);
      if (NEEDS[u]) assert.ok(have.includes(NEEDS[u]), u + ' needs ' + NEEDS[u]);
    });
  },
};

// The scenarios stored in the .tpl (GTM format: runCode/mock/assertApi/assertThat), run on the same emulator.
function scenarios() {
  const out = [];
  let cur = null;
  sections.TESTS.split('\n').forEach((l) => {
    let m;
    if ((m = l.match(/^- name: (.*)$/))) { cur = { name: m[1].trim(), code: [] }; out.push(cur); }
    else if (/^\S/.test(l)) cur = null;
    else if (cur && /^  code: \|-/.test(l)) cur.inCode = true;
    else if (cur && cur.inCode) cur.code.push(l.replace(/^    /, ''));
  });
  return out;
}
function runScenario(s) {
  let last = null;
  const mocks = {};
  const called = {};
  const env = {
    mock: (n, f) => { mocks[n] = typeof f === 'function' ? f : () => f; },
    runCode: (d) => {
      const m = {};
      ['createArgumentsQueue', 'callInWindow', 'setInWindow', 'copyFromWindow', 'logToConsole', 'isConsentGranted'].forEach((n) => {
        m[n] = (...a) => {
          (called[n] = called[n] || []).push(a);
          if (mocks[n]) return mocks[n](...a);
          if (n === 'createArgumentsQueue') return (...q) => { (called.gtag = called.gtag || []).push(q); };
          if (n === 'copyFromWindow') return a[0] === 'fbq' ? true : undefined;
          if (n === 'isConsentGranted') return true;
          return undefined;
        };
      });
      last = run(d, m);
      return last;
    },
    assertApi: (n) => ({
      wasCalled: () => assert.ok(n === 'gtmOnSuccess' ? last.outcome === 'success' : n === 'gtmOnFailure' ? last.outcome === 'failure' : (called[n] || []).length, n + ' not called'),
      wasNotCalled: () => assert.ok(n === 'gtmOnFailure' ? last.outcome !== 'failure' : !(called[n] || []).length, n + ' was called'),
      wasCalledWith: (...a) => assert.ok((called[n] || []).some((c) => JSON.stringify(c) === JSON.stringify(a)), n + ' not called with ' + JSON.stringify(a)),
    }),
    assertThat: (v) => ({ isEqualTo: (x) => assert.strictEqual(v, x), isNotEqualTo: (x) => assert.notStrictEqual(v, x) }),
    fail: (m) => assert.fail(m),
  };
  new Function(...Object.keys(env), s.code.join('\n'))(...Object.values(env));
}

let failed = 0;
const report = (name, fn) => {
  try { fn(); console.log('ok   ' + name); } catch (e) { failed++; console.log('FAIL ' + name + '\n     ' + e.message); }
};
Object.entries(tests).forEach(([n, f]) => report(n, f));
const sc = scenarios();
report('the .tpl carries at least 5 scenarios', () => assert.ok(sc.length >= 5, 'found ' + sc.length));
sc.forEach((s) => report('scenario: ' + s.name, () => runScenario(s)));
console.log(failed ? failed + ' FAILED' : 'ALL PASSED');
process.exit(failed ? 1 : 0);
