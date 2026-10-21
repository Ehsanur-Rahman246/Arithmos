// Arrow-key selector: key handling, drawing (highlight), the draw/read loop (with a fake
// keyboard and screen), and pick() on top of it.
//
// SL1-SL21 are the same 21 behaviours, with the same numbers and names, in the Python
// (tests/test_select.py) and C (test/run_selector.c) editions; see docs/test-cases.md.
// X1 is JavaScript-only (it tests the key queue of this edition's key reader).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { initialState, applyKey, renderList, selectFromList } from '../src/cli/select.js';
import { pick } from '../src/cli/pick.js';
import { PLAIN, Style } from '../src/cli/style.js';

const press = (state, name, extras, extra = {}) => applyKey(state, { name, ...extra }, extras);
// A printable key as the terminal reports it: name and str are the character.
const char = (c) => ({ name: c.toLowerCase(), str: c });

// ---------- keys (pure) ----------

test('SL1: up/down move, wrap around, home/end', () => {
  let s = initialState(3);
  s = press(s, 'down').state; assert.equal(s.index, 1);
  s = press(s, 'down').state; s = press(s, 'down').state; assert.equal(s.index, 0); // wrapped
  s = press(s, 'up').state; assert.equal(s.index, 2);
  s = press(s, 'home').state; assert.equal(s.index, 0);
  s = press(s, 'end').state; assert.equal(s.index, 2);
});

test('SL2: long lists scroll in a window of 10', () => {
  let s = initialState(18);
  assert.equal(s.size, 10);
  for (let i = 0; i < 12; i += 1) s = press(s, 'down').state;
  assert.ok(s.index >= s.offset && s.index < s.offset + s.size);
  s = press(s, 'end').state;
  assert.equal(s.offset, 8);
  const text = renderList('T', Array.from({ length: 18 }, (_, i) => `u${i}`), s).join('\n');
  assert.ok(text.includes('18 of 18') && text.includes('❯ u17'));
});

test('SL3: Enter selects; Esc / b / q only work when offered', () => {
  const s = initialState(3);
  assert.equal(press(s, 'return').done, 'selected');
  assert.equal(press(s, 'escape', {}).done, undefined);
  assert.equal(press(s, 'escape', { back: true }).done, 'back');
  assert.equal(press(s, 'b', { back: true }).done, 'back');
  assert.equal(press(s, 'q', {}).done, undefined);
  assert.equal(press(s, 'q', { quit: true }).done, 'quit');
  assert.equal(press(s, 'x', { back: true, quit: true }).done, undefined);
});

test('SL4: Ctrl-C / Ctrl-D abort; other control keys are ignored', () => {
  const s = initialState(3);
  assert.equal(press(s, 'c', {}, { ctrl: true }).done, 'abort');
  assert.equal(press(s, 'd', {}, { ctrl: true }).done, 'abort');
  assert.equal(press(s, 'b', { back: true, typing: true }, { ctrl: true, str: '\x02' }).done, undefined);
});

test('SL5: typing on: a printable key ends the selector and carries the character', () => {
  const r = applyKey(initialState(3), char('x'), { typing: true });
  assert.equal(r.done, 'typed');
  assert.equal(r.typed, 'x');
  assert.equal(applyKey(initialState(3), char('1'), { typing: true }).typed, '1');
});

test('SL6: typing off: printable keys are ignored', () => {
  assert.equal(applyKey(initialState(3), char('x'), {}).done, undefined);
  assert.equal(applyKey(initialState(3), char('1'), { back: true, quit: true }).done, undefined);
});

test('SL7: typing on: Esc, b, q, arrows and Enter keep their meaning', () => {
  const on = { back: true, quit: true, typing: true };
  const s = initialState(3);
  assert.equal(applyKey(s, { name: 'escape', str: '\x1b' }, on).done, 'back');
  assert.equal(applyKey(s, char('b'), on).done, 'back');
  assert.equal(applyKey(s, char('q'), on).done, 'quit');
  assert.equal(applyKey(s, { name: 'down' }, on).state.index, 1);
  assert.equal(applyKey(s, { name: 'return', str: '\r' }, on).done, 'selected');
  assert.equal(applyKey(s, char('b'), { typing: true }).done, undefined); // back not offered: not a typed key either
});

test('SL8: typing on: space and control keys do not start a typed line', () => {
  const s = initialState(3);
  assert.equal(applyKey(s, { name: 'space', str: ' ' }, { typing: true }).done, undefined);
  assert.equal(applyKey(s, { name: 'x', str: '\x18', ctrl: true }, { typing: true }).done, undefined);
});

// ---------- drawing (pure) ----------

test('SL9: the selected row is highlighted as a full bar', () => {
  const state = press(initialState(3), 'down').state;
  const lines = renderList('Pick', ['aa', 'bbbb', 'c'], state, { style: new Style(true) });
  assert.ok(lines[2].includes('\x1b[7m') && lines[2].includes('❯ bbbb'));
  assert.ok(!(lines[1] + lines[3]).includes('\x1b[7m'));
  assert.equal(lines.length, 5); // title + 3 rows + hint
});

test('SL10: plain mode still marks the selected row with the pointer', () => {
  const lines = renderList('Pick', ['aa', 'bb'], initialState(2), { style: PLAIN });
  assert.ok(lines[1].startsWith(' ❯ aa') && lines[2].startsWith('   bb'));
});

test('SL11: hint line lists only the keys on offer', () => {
  const hint = (extras) => renderList('T', ['a', 'b'], initialState(2), extras).at(-1);
  assert.ok(hint({}).includes('Enter select') && !hint({}).includes('Esc'));
  assert.ok(hint({ back: true }).includes('Esc back'));
  assert.ok(hint({ quit: true }).includes('q quit'));
});

test('SL12: hint shows Esc/b back and or type when typing is on', () => {
  const hint = renderList('T', ['a', 'b'], initialState(2), { back: true, quit: true, typing: true }).at(-1);
  assert.ok(hint.includes('Esc/b back') && hint.includes('q quit') && hint.includes('or type'));
});

// ---------- the loop, over a fake keyboard and screen ----------

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

test('SL13: loop: keys in, index out, summary left behind, cursor restored', async () => {
  const t = fakeKeys();
  const p = selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b', 'c'], back: true });
  t.press('down'); t.press('down'); t.press('return');
  assert.deepEqual(await p, { status: 'selected', index: 2 });
  assert.ok(t.text().includes('✔ Pick: c'));
  assert.ok(t.text().startsWith('\x1b[?25l') && t.text().endsWith('\x1b[?25h')); // cursor hidden, then restored
});

test('SL14: loop: Esc, ignored keys, Ctrl-C', async () => {
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

test('SL15: loop: a typed key returns its character and restores the cursor', async () => {
  const t = fakeKeys();
  const p = selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b'], back: true, typing: true });
  t.press('x', { str: 'x' });
  assert.deepEqual(await p, { status: 'typed', text: 'x' });
  const text = t.text();
  assert.ok(text.lastIndexOf('\x1b[?25h') > text.lastIndexOf('\x1b[?25l') && text.endsWith('\x1b[?25h'));
});

test('X1 (JavaScript only): keys pressed before the screen is ready are not lost', async () => {
  const t = fakeKeys();
  t.press('down'); t.press('return'); // queued before selectFromList is even called
  assert.deepEqual(await selectFromList({ readKey: t.readKey, output: t.output, title: 'Pick', labels: ['a', 'b'] }),
    { status: 'selected', index: 1 });
});

// ---------- pick(), over a scripted environment ----------

const OPTIONS = ['length', 'mass', 'area'].map((name, i) => ({ key: String(i + 1), label: name, value: name, aliases: [name] }));
const passthrough = (line) => `ran:${line}`;

// keys: what the user presses at the selector; lines: the rest of each typed line (after the
// typed key), or whole lines in plain mode. withSelect: false is a pipe.
function scriptedIo({ keys = [], lines = [], withSelect = true } = {}) {
  const queue = keys.slice();
  const rest = lines.slice();
  const io = {
    style: PLAIN,
    buf: '',
    prompts: [],
    write(text) { this.buf += text; },
    readLine(prompt) { this.prompts.push(prompt); return Promise.resolve(rest.length ? rest.shift() : null); },
  };
  if (withSelect) {
    io.select = (args) => selectFromList({
      readKey: () => Promise.resolve(queue.shift() ?? { name: 'd', ctrl: true }),
      output: io, style: PLAIN, ...args, labels: args.options,
    });
  }
  return io;
}

test('SL16: pick() uses the selector when present and maps its results', async () => {
  const options = [{ key: '1', label: 'x', value: 'X' }, { key: '2', label: 'y', value: 'Y' }];
  let seen;
  const ioWith = (result) => ({ style: PLAIN, write() {}, select: async (args) => { seen = args; return result; } });
  assert.deepEqual(await pick(ioWith({ status: 'selected', index: 1 }), { title: 't', options, back: true }),
    { status: 'selected', option: options[1] });
  assert.deepEqual(seen, { title: 't', options: ['x', 'y'], back: true, quit: true, typing: true });
  assert.deepEqual(await pick(ioWith({ status: 'back' }), { title: 't', options }), { status: 'back' });
  assert.deepEqual(await pick(ioWith({ status: 'quit' }), { title: 't', options }), { status: 'quit' });
  assert.deepEqual(await pick(ioWith({ status: 'abort' }), { title: 't', options }), { status: 'eof' });
});

test('SL17: pick(): a typed name or number selects it', async () => {
  let io = scriptedIo({ keys: [char('m')], lines: ['ass'] });
  let r = await pick(io, { title: 'Cat', options: OPTIONS, back: true, passthrough });
  assert.equal(r.option.value, 'mass');
  assert.equal(io.prompts[0], '> m'); // the typed key is shown after the prompt
  io = scriptedIo({ keys: [char('3')], lines: [''] });
  r = await pick(io, { title: 'Cat', options: OPTIONS, back: true, passthrough });
  assert.equal(r.option.value, 'area');
});

test('SL18: pick(): a typed one-line command runs and the list comes back', async () => {
  const io = scriptedIo({ keys: [char('l'), { name: 'return' }], lines: ['ist'] });
  const r = await pick(io, { title: 'Cat', options: OPTIONS, back: true, passthrough });
  assert.ok(io.buf.includes('ran:list\n')); // the command ran, then the list came back
  assert.equal(r.option.value, 'length');
});

test('SL19: pick(): an unknown typed word is an error and the list comes back', async () => {
  const io = scriptedIo({ keys: [char('x'), { name: 'escape', str: '\x1b' }], lines: ['yz'] });
  const r = await pick(io, { title: 'Cat', options: OPTIONS, back: true });
  assert.ok(io.buf.includes('Error [UNKNOWN_COMMAND]: Pick one from the list'));
  assert.equal(r.status, 'back'); // then Esc goes back
});

test('SL20: pick(): b, q and Esc act at once, with no prompt line', async () => {
  const cases = [
    [char('b'), 'back'], [char('q'), 'quit'], [{ name: 'escape', str: '\x1b' }, 'back'], [{ name: 'd', ctrl: true }, 'eof'],
  ];
  for (const [key, status] of cases) {
    const io = scriptedIo({ keys: [key] });
    const r = await pick(io, { title: 'Cat', options: OPTIONS, back: true });
    assert.equal(r.status, status);
    assert.equal(io.prompts.length, 0);
  }
});

test('SL21: pick(): without a selector (pipes) the numbered list works as before', async () => {
  const io = scriptedIo({ lines: ['mass'], withSelect: false });
  const r = await pick(io, { title: 'Cat', options: OPTIONS, back: true });
  assert.equal(r.option.value, 'mass');
  assert.ok(io.buf.includes('  1) length') && io.buf.includes('  3) area')); // the numbered list is shown
  assert.equal(io.prompts[0], '> ');
});
