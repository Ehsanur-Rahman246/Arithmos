// Selector tests SL1–SL21 (docs/test-cases.md) plus X2 (layout) and X3 (key bytes).
import assert from 'node:assert/strict';
import test from 'node:test';
import { parseKeys, type Key, type KeyName } from '../src/cli/keys';
import { pick, type PickSpec } from '../src/cli/pick';
import {
  handleKey, hint, render, runSelector, windowSize,
  type SelState, type SelectSpec,
} from '../src/cli/selector';
import { makeStyle } from '../src/cli/style';
import { FakeIo, FakeKeys, FakeScreen } from './fakes';

const k = (name: KeyName, ch?: string): Key => ({ name, ch });
const labels = (n: number): string[] => Array.from({ length: n }, (_, i) => `item${i}`);
const mk = (o: Partial<SelectSpec> = {}): SelectSpec =>
  ({ title: 'T', labels: labels(5), back: false, quit: false, typing: false, ...o });

/** Feed keys to handleKey; return the final state, or the result that ended it. */
function press(spec: SelectSpec, keys: Key[], rows = 24): SelState | { kind: string; [x: string]: unknown } {
  let s: SelState = { index: 0, top: 0 };
  const win = windowSize(spec.labels.length, rows);
  for (const key of keys) {
    const o = handleKey(s, key, spec, win);
    if ('done' in o) return o.done;
    s = o.state;
  }
  return s;
}
const plain = makeStyle(false);

test('SL1 up/down move, wrap around, home/end', () => {
  assert.deepEqual(press(mk(), [k('up')]), { index: 4, top: 0 });
  assert.deepEqual(press(mk(), [k('down'), k('down')]), { index: 2, top: 0 });
  assert.deepEqual(press(mk(), Array(5).fill(k('down'))), { index: 0, top: 0 });
  assert.deepEqual(press(mk(), [k('end')]), { index: 4, top: 0 });
  assert.deepEqual(press(mk(), [k('end'), k('home')]), { index: 0, top: 0 });
});

test('SL2 long lists scroll in a window of 10', () => {
  const spec = mk({ labels: labels(25) });
  assert.equal(windowSize(25, 24), 10);
  assert.deepEqual(press(spec, Array(10).fill(k('down'))), { index: 10, top: 1 });
  assert.deepEqual(press(spec, [k('up')]), { index: 24, top: 15 });
  assert.equal(render({ index: 0, top: 0 }, spec, { cols: 80, rows: 24 }, plain).length, 12); // title + 10 + hint
});

test('SL3 Enter selects; Esc / b / q only work when offered', () => {
  assert.deepEqual(press(mk(), [k('down'), k('enter')]), { kind: 'index', index: 1 });
  assert.deepEqual(press(mk(), [k('escape'), k('char', 'b'), k('char', 'q')]), { index: 0, top: 0 });
  assert.deepEqual(press(mk({ back: true }), [k('escape')]), { kind: 'back' });
  assert.deepEqual(press(mk({ back: true }), [k('char', 'b')]), { kind: 'back' });
  assert.deepEqual(press(mk({ quit: true }), [k('char', 'q')]), { kind: 'quit' });
});

test('SL4 Ctrl-C / Ctrl-D abort; other control keys are ignored', () => {
  assert.deepEqual(press(mk(), [k('ctrl-c')]), { kind: 'eof' });
  assert.deepEqual(press(mk(), [k('ctrl-d')]), { kind: 'eof' });
  assert.deepEqual(press(mk(), [k('tab'), k('other'), k('left')]), { index: 0, top: 0 });
});

test('SL5 typing on: a printable key ends the selector and carries the character', () => {
  assert.deepEqual(press(mk({ typing: true }), [k('char', '1')]), { kind: 'typed', ch: '1' });
  assert.deepEqual(press(mk({ typing: true }), [k('char', 'x')]), { kind: 'typed', ch: 'x' });
});

test('SL6 typing off: printable keys are ignored', () => {
  assert.deepEqual(press(mk(), [k('char', 'x'), k('char', '1')]), { index: 0, top: 0 });
});

test('SL7 typing on: Esc, b, q, arrows and Enter keep their meaning', () => {
  const spec = mk({ typing: true, back: true, quit: true });
  assert.deepEqual(press(spec, [k('escape')]), { kind: 'back' });
  assert.deepEqual(press(spec, [k('char', 'b')]), { kind: 'back' });
  assert.deepEqual(press(spec, [k('char', 'q')]), { kind: 'quit' });
  assert.deepEqual(press(spec, [k('down'), k('enter')]), { kind: 'index', index: 1 });
});

test('SL8 typing on: space and control keys do not start a typed line', () => {
  const spec = mk({ typing: true });
  assert.deepEqual(press(spec, [k('char', ' '), k('other'), k('tab'), k('backspace')]), { index: 0, top: 0 });
});

test('SL9 the selected row is highlighted as a full bar', () => {
  const lines = render({ index: 1, top: 0 }, mk(), { cols: 40, rows: 24 }, makeStyle(true));
  assert.ok(lines[2].startsWith('\x1b[7m'), 'reverse video on the selected row');
  assert.ok(lines[2].includes('❯ item1'));
  assert.ok(lines[2].replace(/\x1b\[\d+m/g, '').length === 39, 'padded to the full width');
  assert.ok(!lines[1].includes('\x1b[7m'));
});

test('SL10 plain mode still marks the selected row with the pointer', () => {
  const lines = render({ index: 1, top: 0 }, mk(), { cols: 40, rows: 24 }, plain);
  assert.equal(lines[2], '❯ item1');
  assert.equal(lines[1], '  item0');
});

test('SL11 hint line lists only the keys on offer', () => {
  const h = hint(mk());
  assert.ok(h.includes('Enter'));
  assert.ok(!h.includes('Esc') && !h.includes('q quit') && !h.includes('type'));
  assert.ok(hint(mk({ quit: true })).includes('q quit'));
});

test('SL12 hint shows Esc/b back and "or type" when typing is on', () => {
  const h = hint(mk({ back: true, typing: true }));
  assert.ok(h.includes('Esc/b back'));
  assert.ok(h.includes('or type'));
});

test('SL13 loop: keys in, index out, summary left behind, cursor restored', async () => {
  const keys = new FakeKeys([k('down'), k('enter')]);
  const screen = new FakeScreen();
  const r = await runSelector(keys, screen, mk(), plain);
  assert.deepEqual(r, { kind: 'index', index: 1 });
  assert.ok(screen.out.includes('✔ T: item1'));
  assert.ok(screen.out.endsWith('\x1b[?25h'));
  assert.equal(keys.entered, 1);
  assert.equal(keys.left, 1);
});

test('SL14 loop: Esc, ignored keys, Ctrl-C', async () => {
  const esc = await runSelector(new FakeKeys([k('escape')]), new FakeScreen(), mk({ back: true }), plain);
  assert.deepEqual(esc, { kind: 'back' });
  const ignored = await runSelector(new FakeKeys([k('char', 'x'), k('tab'), k('enter')]), new FakeScreen(), mk(), plain);
  assert.deepEqual(ignored, { kind: 'index', index: 0 });
  const keys = new FakeKeys([k('ctrl-c')]);
  assert.deepEqual(await runSelector(keys, new FakeScreen(), mk(), plain), { kind: 'eof' });
  assert.equal(keys.left, 1);
});

test('SL15 loop: a typed key returns its character and restores the cursor', async () => {
  const keys = new FakeKeys([k('char', 'l')]);
  const screen = new FakeScreen();
  assert.deepEqual(await runSelector(keys, screen, mk({ typing: true }), plain), { kind: 'typed', ch: 'l' });
  assert.ok(screen.out.endsWith('\x1b[?25h'));
  assert.equal(keys.left, 1);
});

const pspec = (o: Partial<PickSpec> = {}): PickSpec => ({
  title: 'Pick',
  options: [{ label: 'one', names: ['one'] }, { label: 'two', names: ['two', 'dos'] }, { label: 'three' }],
  back: true,
  quit: true,
  helpText: 'HELP',
  ...o,
});

test('SL16 pick() uses the selector when present and maps its results', async () => {
  assert.deepEqual(await pick(new FakeIo([], [{ kind: 'index', index: 2 }]), pspec()), { kind: 'choice', index: 2 });
  assert.deepEqual(await pick(new FakeIo([], [{ kind: 'back' }]), pspec()), { kind: 'back' });
  assert.deepEqual(await pick(new FakeIo([], [{ kind: 'quit' }]), pspec()), { kind: 'quit' });
  assert.deepEqual(await pick(new FakeIo([], [{ kind: 'eof' }]), pspec()), { kind: 'eof' });
});

test('SL17 pick(): a typed name or number selects it', async () => {
  const byName = new FakeIo(['dos'], [{ kind: 'typed', ch: 'd' }]);
  assert.deepEqual(await pick(byName, pspec()), { kind: 'choice', index: 1 });
  const byNumber = new FakeIo(['3'], [{ kind: 'typed', ch: '3' }]);
  assert.deepEqual(await pick(byNumber, pspec()), { kind: 'choice', index: 2 });
});

test('SL18 pick(): a typed one-line command runs and the list comes back', async () => {
  const io = new FakeIo(['100 cm in'], [{ kind: 'typed', ch: '1' }, { kind: 'index', index: 0 }]);
  const r = await pick(io, pspec({ command: (line) => (line.includes('cm') ? ['39.37'] : null) }));
  assert.deepEqual(r, { kind: 'choice', index: 0 });
  assert.ok(io.out.includes('39.37'));
  assert.equal(io.selectCalls, 2);
});

test('SL19 pick(): an unknown typed word is an error and the list comes back', async () => {
  const io = new FakeIo(['zzz'], [{ kind: 'typed', ch: 'z' }, { kind: 'back' }]);
  assert.deepEqual(await pick(io, pspec()), { kind: 'back' });
  assert.ok(io.out.includes('Error [UNKNOWN_COMMAND]'));
  assert.equal(io.selectCalls, 2);
});

test('SL20 pick(): b, q and Esc act at once, with no prompt line', async () => {
  for (const [key, kind] of [['b', 'back'], ['q', 'quit'], ['escape', 'back']] as const) {
    const io = new FakeIo(['SHOULD NOT BE READ']);
    const screen = new FakeScreen();
    const spec = { ...mk({ back: true, quit: true, typing: true }) };
    const r = await runSelector(new FakeKeys([key === 'escape' ? k('escape') : k('char', key)]), screen, spec, plain);
    assert.deepEqual(r, { kind });
    assert.equal(io.readCalls, 0);
  }
});

test('SL21 pick(): without a selector (pipes) the numbered list works as before', async () => {
  const io = new FakeIo(['2']);
  assert.deepEqual(await pick(io, pspec()), { kind: 'choice', index: 1 });
  assert.ok(io.out.includes('  1) one'));
  assert.ok(io.out.includes('  3) three'));
  assert.deepEqual(await pick(new FakeIo(['quit']), pspec()), { kind: 'quit' });
  assert.deepEqual(await pick(new FakeIo(['back']), pspec()), { kind: 'back' });
  assert.deepEqual(await pick(new FakeIo([null]), pspec()), { kind: 'eof' });
  const bad = new FakeIo(['', 'nope', '1']);
  assert.deepEqual(await pick(bad, pspec()), { kind: 'choice', index: 0 });
  assert.ok(bad.out.includes('Error [UNKNOWN_COMMAND]: Pick one from the list'));
  const noBack = new FakeIo(['back', '1']);
  await pick(noBack, pspec({ back: false }));
  assert.ok(noBack.out.includes('Error [UNKNOWN_COMMAND]'));
});

test('X2 lines never wider than the terminal; window shrinks; erase moves up by the drawn count', async () => {
  const wide = mk({ title: 'A very long title '.repeat(5), labels: ['x'.repeat(100), 'y'.repeat(100)] });
  for (const line of render({ index: 0, top: 0 }, wide, { cols: 20, rows: 24 }, plain)) {
    assert.ok(line.length <= 19, `"${line}"`);
  }
  assert.equal(windowSize(25, 8), 5);
  assert.equal(windowSize(25, 4), 1);
  assert.equal(render({ index: 0, top: 0 }, mk({ labels: labels(25) }), { cols: 80, rows: 8 }, plain).length, 7);
  const screen = new FakeScreen(80, 24);
  await runSelector(new FakeKeys([k('down'), k('enter')]), screen, mk(), plain);
  assert.ok(screen.out.includes('\x1b[7A\r\x1b[J'), 'title + 5 rows + hint = 7 lines');
});

test('X3 raw terminal bytes become keys', () => {
  const names = (s: string): string[] => parseKeys(s).map((x) => (x.name === 'char' ? `char:${x.ch}` : x.name));
  assert.deepEqual(names('\x1b[A\x1b[B\x1b[C\x1b[D'), ['up', 'down', 'right', 'left']);
  assert.deepEqual(names('\x1bOA\x1bOB'), ['up', 'down']);
  assert.deepEqual(names('\x1b[H\x1b[F\x1b[1~\x1b[4~'), ['home', 'end', 'home', 'end']);
  assert.deepEqual(names('\x1b[5~\x1b[6~'), ['pageup', 'pagedown']);
  assert.deepEqual(names('\x1b'), ['escape']);
  assert.deepEqual(names('\r'), ['enter']);
  assert.deepEqual(names('\r\n'), ['enter']);
  assert.deepEqual(names('\x7f\b'), ['backspace', 'backspace']);
  assert.deepEqual(names('\x03\x04'), ['ctrl-c', 'ctrl-d']);
  assert.deepEqual(names('\x01\t'), ['other', 'tab']);
  assert.deepEqual(names('aé€'), ['char:a', 'char:é', 'char:€']);
  assert.deepEqual(names('\x1b[3~\x1bx'), ['other', 'other']);
});