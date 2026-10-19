// Arrow-key selector: key handling, drawing (highlight), the terminal wrapper
// (with fake streams), and pick() on top of it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { initialState, applyKey, renderList, selectFromList } from '../src/cli/select.js';
import { pick } from '../src/cli/pick.js';
import { PLAIN, Style } from '../src/cli/style.js';

const press = (state, name, extras, extra = {}) => applyKey(state, { name, ...extra }, extras);

test('up/down move, wrap around, home/end', () => {
  let s = initialState(3);
  s = press(s, 'down').state; assert.equal(s.index, 1);
  s = press(s, 'down').state; s = press(s, 'down').state; assert.equal(s.index, 0); // wrapped
  s = press(s, 'up').state; assert.equal(s.index, 2);
  s = press(s, 'home').state; assert.equal(s.index, 0);
  s = press(s, 'end').state; assert.equal(s.index, 2);
});

test('long lists scroll in a window of 10', () => {
  let s = initialState(18);
  assert.equal(s.size, 10);
  for (let i = 0; i < 12; i += 1) s = press(s, 'down').state;
  assert.ok(s.index >= s.offset && s.index < s.offset + s.size);
  s = press(s, 'end').state;
  assert.equal(s.offset, 8);
  const text = renderList('T', Array.from({ length: 18 }, (_, i) => `u${i}`), s).join('\n');
  assert.ok(text.includes('18 of 18') && text.includes('❯ u17'));
});

test('Enter selects; Esc / b / q only work when offered', () => {
  const s = initialState(3);
  assert.equal(press(s, 'return').done, 'selected');
  assert.equal(press(s, 'escape', {}).done, undefined);
  assert.equal(press(s, 'escape', { back: true }).done, 'back');
  assert.equal(press(s, 'b', { back: true }).done, 'back');
  assert.equal(press(s, 'q', {}).done, undefined);
  assert.equal(press(s, 'q', { quit: true }).done, 'quit');
  assert.equal(press(s, 'x', { back: true, quit: true }).done, undefined);
});

test('Ctrl-C / Ctrl-D abort; other Ctrl combos are ignored', () => {
  const s = initialState(3);
  assert.equal(press(s, 'c', {}, { ctrl: true }).done, 'abort');
  assert.equal(press(s, 'd', {}, { ctrl: true }).done, 'abort');
  assert.equal(press(s, 'b', { back: true }, { ctrl: true }).done, undefined);
});

test('the selected row is highlighted as a full bar', () => {
  const state = press(initialState(3), 'down').state;
  const lines = renderList('Pick', ['aa', 'bbbb', 'c'], state, { style: new Style(true) });
  assert.ok(lines[2].includes('\x1b[7m') && lines[2].includes('❯ bbbb'));
  assert.ok(!(lines[1] + lines[3]).includes('\x1b[7m'));
  assert.equal(lines.length, 5); // title + 3 rows + hint
});

test('plain mode still marks the selected row with the pointer', () => {
  const lines = renderList('Pick', ['aa', 'bb'], initialState(2), { style: PLAIN });
  assert.ok(lines[1].startsWith(' ❯ aa') && lines[2].startsWith('   bb'));
});

test('hint line lists only the keys on offer', () => {
  const hint = (extras) => renderList('T', ['a', 'b'], initialState(2), extras).at(-1);
  assert.ok(hint({}).includes('Enter select') && !hint({}).includes('Esc'));
  assert.ok(hint({ back: true }).includes('Esc back'));
  assert.ok(hint({ quit: true }).includes('q quit'));
});

// A fake key reader: press() feeds keys, readKey() is what the selector awaits.
function fakeKeys() {
  const queue = [];
  let waiter = null;
  const chunks = [];
  return {
    readKey: () => (queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve) => { waiter = resolve; })),
    press(name, extra = {}) {
      const k = { name, ...extra };
      if (waiter) { const w = waiter; waiter = null; w(k); } else queue.push(k);
    },
    output: { write: (t) => chunks.push(t) },
    text: () => chunks.join(''),
  };
}

test('selectFromList: keys in, index out, summary left behind, cursor restored', async () => {
  const t = fakeKeys();
  const p = selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b', 'c'], back: true });
  t.press('down'); t.press('down'); t.press('return');
  assert.deepEqual(await p, { status: 'selected', index: 2 });
  assert.ok(t.text().includes('✔ Pick: c'));
  assert.ok(t.text().startsWith('\x1b[?25l') && t.text().endsWith('\x1b[?25h')); // cursor hidden, then restored
});

test('selectFromList: Esc, ignored keys, Ctrl-C', async () => {
  let t = fakeKeys();
  let p = selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b'], back: true });
  t.press('escape');
  assert.deepEqual(await p, { status: 'back' });
  t = fakeKeys();
  p = selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b'] });
  t.press('escape'); // not on offer: ignored
  t.press('return');
  assert.deepEqual(await p, { status: 'selected', index: 0 });
  t = fakeKeys();
  p = selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b'] });
  t.press('c', { ctrl: true });
  assert.deepEqual(await p, { status: 'abort' });
});

test('selectFromList: keys pressed before the screen is ready are not lost', async () => {
  const t = fakeKeys();
  t.press('down'); t.press('return'); // queued before selectFromList is even called
  assert.deepEqual(await selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b'] }),
    { status: 'selected', index: 1 });
});

test('pick() uses io.select when it exists and maps results', async () => {
  const options = [{ key: '1', label: 'x', value: 'X' }, { key: '2', label: 'y', value: 'Y' }];
  let seen;
  const ioWith = (result) => ({ style: PLAIN, write() {}, select: async (args) => { seen = args; return result; } });
  assert.deepEqual(await pick(ioWith({ status: 'selected', index: 1 }), { title: 't', options, back: true }),
    { status: 'selected', option: options[1] });
  assert.deepEqual(seen, { title: 't', options: ['x', 'y'], back: true, quit: true });
  assert.deepEqual(await pick(ioWith({ status: 'back' }), { title: 't', options }), { status: 'back' });
  assert.deepEqual(await pick(ioWith({ status: 'abort' }), { title: 't', options }), { status: 'eof' });
});