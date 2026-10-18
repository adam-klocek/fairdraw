// Optional animation tests: node --test tests/reveal.test.cjs (no npm packages).
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../www/app.js'), 'utf8');

function setup(reduced = false) {
  let now = 0, next = 1;
  const timers = new Map(), handlers = {}, events = [], elements = {};
  function element() {
    const classes = new Set();
    return {style: {setProperty() {}}, offsetWidth: 260, disabled: false,
      classList: {add: x => classes.add(x), remove: x => classes.delete(x), toggle: x => classes.has(x) ? classes.delete(x) : classes.add(x)},
      setAttribute() {}, appendChild() {}, remove() {}};
  }
  for (const id of ['draw-card', 'draw', 'wheel', 'spin-progress', 'wheel-countdown', 'spin-fill']) elements[id] = element();
  const schedule = (callback, ms, interval = false) => {
    const id = next++; timers.set(id, {callback, due: now + ms, interval: interval ? ms : 0}); return id;
  };
  const context = {document: {documentElement: {}, body: element(), addEventListener() {},
      getElementById: id => elements[id], querySelectorAll: () => [], createElement: element},
    performance: {now: () => now}, getComputedStyle: e => ({transform: e.style.transform || 'none'}),
    matchMedia: () => ({matches: reduced}),
    Shiny: {addCustomMessageHandler: (name, fn) => { handlers[name] = fn; }, setInputValue: (name, value) => events.push({name, value})},
    $: () => ({on: (_, fn) => fn()}),
    setTimeout: (fn, ms) => schedule(fn, ms), clearTimeout: id => timers.delete(id),
    setInterval: (fn, ms) => schedule(fn, ms, true), clearInterval: id => timers.delete(id)};
  context.window = context; vm.createContext(context); vm.runInContext(source, context);
  return {context, handlers, events, elements, advance(ms) {
    const until = now + ms;
    while (true) {
      const next = [...timers].filter(([, t]) => t.due <= until).sort((a, b) => a[1].due - b[1].due)[0];
      if (!next) break;
      const [id, timer] = next; now = timer.due;
      if (timer.interval) timer.due += timer.interval; else timers.delete(id);
      timer.callback();
    }
    now = until;
  }};
}
test('wheel remains locked for 30 seconds, then reveals the same record token', () => {
  const app = setup(); app.handlers['fd-reveal']({mode: 'wheel', token: 'locked-record', duration: 30000});
  assert.equal(app.elements.draw.disabled, true);
  app.advance(29999); assert.equal(app.events.length, 0);
  assert.match(app.elements['wheel-countdown'].textContent, /Zbývá 1 s/);
  app.advance(1); assert.equal(app.events.length, 1);
  assert.equal(app.events[0].value.token, 'locked-record');
  assert.equal(app.elements.draw.disabled, false);
});
test('skipping finishes once and preserves the already computed token', () => {
  const app = setup(); app.handlers['fd-reveal']({mode: 'wheel', token: 'same-result'});
  app.advance(5000); const finish = app.context.Fairdraw.finishReveal; finish(); finish();
  app.advance(30000); assert.equal(app.events.length, 1); assert.equal(app.events[0].value.token, 'same-result');
});
test('instant and reduced-motion paths finish without a long animation', () => {
  for (const [reduced, mode] of [[false, 'instant'], [true, 'wheel']]) {
    const app = setup(reduced); app.handlers['fd-reveal']({mode, token: 'fast'});
    assert.equal(app.elements['spin-progress'].style.display, 'none');
    app.advance(40); assert.equal(app.events.length, 1); assert.equal(app.events[0].value.token, 'fast');
  }
});
test('a replacement reveal cancels the old timer', () => {
  const app = setup(); app.handlers['fd-reveal']({mode: 'wheel', token: 'old'});
  app.advance(2000); app.handlers['fd-reveal']({mode: 'wheel', token: 'new'});
  app.advance(30000); assert.equal(app.events.length, 1); assert.equal(app.events[0].value.token, 'new');
});
