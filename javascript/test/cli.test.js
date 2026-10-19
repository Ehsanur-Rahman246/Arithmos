// CLI tests (typed mode): menu, guided converter, help/back/quit, EOF, UNKNOWN_COMMAND,
// one-shot mode, and "invalid input never crashes".
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { main } from '../src/cli/index.js';
import { PLAIN } from '../src/cli/style.js';

// A scripted io: readLine(prompt) records the prompt like a real terminal would.
function scripted(lines) {
  const queue = [...lines];
  const chunks = [];
  return {
    io: {
      style: PLAIN,
      async readLine(prompt = '') { chunks.push(prompt); return queue.length ? queue.shift() : null; },
      write(t) { chunks.push(t); },
    },
    text: () => chunks.join(''),
  };
}
const session = async (lines) => {
  const s = scripted(lines);
  const code = await main([], s.io);
  return { code, out: s.text() };
};
const count = (text, piece) => text.split(piece).length - 1;

const MENU = 'Arithmos 1.0 — Core CLI';
const CONVERTER_VALUES = ['3', '12', '1', '2']; // menu -> temperature -> c -> f, ready for values

test('menu lists tools and exits on 0', async () => {
  const { code, out } = await session(['0']);
  assert.equal(code, 0);
  for (const piece of [MENU, '1) Standard Calculator', '2) Programmer Calculator', '3) Unit Converter', '0) Exit']) {
    assert.ok(out.includes(piece), piece);
  }
});

test('each tool runs and `back` returns to the menu', async () => {
  const { out } = await session(['1', '25 + 17', 'back', '2', '5 AND 3', 'back', ...CONVERTER_VALUES, '100', 'back', 'back', 'back', 'back', '0']);
  assert.ok(out.includes('standard> 42\n'));
  assert.ok(out.includes('DEC: 1\n'));
  assert.ok(out.includes('100 c = 212 f\n'));
  assert.equal(count(out, MENU), 4); // first screen + after three tools
});

test('every tool says what to type', async () => {
  const std = (await session(['1', 'quit'])).out;
  assert.ok(std.includes('(help · back · quit)') && std.includes('Try: 2 + 3 * 4'));
  assert.ok((await session(['2', 'quit'])).out.includes('Try: 255    5 AND 3'));
  assert.ok((await session([...CONVERTER_VALUES, 'quit'])).out.includes('Type a number'));
});

test('help and ? print a short command list', async () => {
  for (const flow of [['1'], ['2'], CONVERTER_VALUES]) {
    for (const word of ['help', 'HELP', '?']) {
      const { out } = await session([...flow, word, 'quit']);
      assert.ok(out.includes('quit  exit') && out.includes('back  '), `${flow} ${word}`);
    }
  }
});

test('back and quit work in any case', async () => {
  for (const [flow, backs] of [[['1'], 1], [['2'], 1], [CONVERTER_VALUES, 4]]) {
    const back = await session([...flow, ...Array(backs).fill('Back'), '0']);
    assert.equal(count(back.out, MENU), 2, flow.join());
    const quit = await session([...flow, 'QuIt', '1', 'never reached']);
    assert.equal(quit.code, 0);
    assert.equal(count(quit.out, MENU), 1, flow.join()); // quit exits, no menu again
  }
});

test('end of input exits cleanly everywhere', async () => {
  for (const flow of [[], ['1'], ['3'], ['3', '1'], ['3', '1', '1'], ['3', '1', '1', '1']]) {
    assert.equal((await session(flow)).code, 0);
  }
});

test('blank lines and surrounding spaces are ignored', async () => {
  const { out } = await session(['1', '', '   ', '  2 + 2  ', 'quit']);
  assert.ok(out.includes('standard> 4\n'));
  assert.ok(!out.includes('Error'));
});

test('unknown command yields UNKNOWN_COMMAND in every tool and the menu', async () => {
  const { out } = await session(['9', '2', 'hello world foo', 'back', '3', 'blah', 'back', '0']);
  assert.equal(count(out, 'Error [UNKNOWN_COMMAND]'), 3);
});

test('errors print on one line and ans survives them', async () => {
  const { out } = await session(['1', '7', '10 / 0', 'ans', 'quit']);
  assert.ok(/Error \[DIV_BY_ZERO\]: .+/.test(out));
  assert.ok(out.endsWith('7\nstandard> '));
});

test('invalid input never crashes any tool', async () => {
  const junk = ['(((', ')', '%', '1e5', '5.5.5', '$$$', '0x', '-', '1 << ', 'convert', 'convert 1', 'list nope', 'base', '\t', '999999999999999999999999 + 1'];
  const { code, out } = await session([
    '1', ...junk, 'back', '2', ...junk, 'back', '3', ...junk, 'back', '3', '1', '1', '2', ...junk, 'quit',
  ]);
  assert.equal(code, 0);
  assert.ok(!out.includes('INTERNAL'));
});

test('programmer: the word convert is optional; base changes how numbers are read', async () => {
  const a = await session(['2', '255 dec hex', 'convert 255 dec hex', 'ff hex bin', 'quit']);
  assert.equal(count(a.out, 'programmer> FF\n'), 2);
  assert.ok(a.out.includes('programmer> 11111111\n'));
  const b = await session(['2', 'base hex', '-FF', 'quit']);
  assert.ok(b.out.includes('DEC: -255\n'));
});

test('converter: all 12 categories, then only that category\'s units', async () => {
  const { out } = await session(['3', '12', 'quit']);
  const names = ['length', 'mass', 'area', 'volume', 'time', 'speed', 'digital', 'energy', 'power', 'pressure', 'angle', 'temperature'];
  names.forEach((n, i) => assert.ok(out.includes(`  ${i + 1}) ${n}\n`), n));
  const after = out.slice(out.indexOf('Temperature — convert from'));
  assert.ok(after.includes('kelvin') && !after.includes('centimetre') && !after.includes('inch'));
});

test('converter: names and symbols work as well as numbers', async () => {
  assert.ok((await session(['3', 'temperature', 'c', 'f', '0', 'quit'])).out.includes('0 c = 32 f\n'));
});

test('converter: values repeat and errors do not end the loop', async () => {
  const { out } = await session([...CONVERTER_VALUES, '100', '-40', 'abc', '-300', '0', 'quit']);
  for (const line of ['100 c = 212 f\n', '-40 c = -40 f\n', '0 c = 32 f\n']) assert.ok(out.includes(line), line);
  assert.ok(out.includes('Error [INVALID_NUMBER]') && out.includes('Error [BELOW_ABSOLUTE_ZERO]'));
});

test('converter: back goes one screen at a time', async () => {
  const { out } = await session(['3', '1', '6', '7', '1', 'back', '7', '1', 'back', 'back', 'back', 'quit']);
  // target screen: shown once, then again after each of the two `back`s from the values screen
  assert.equal(count(out, 'Length — convert from cm to'), 3);
  assert.equal(count(out, '1 cm = 0.01 m\n'), 2);
  assert.equal(count(out, 'Unit Converter — choose a category'), 2);
});

test('converter: one-line commands still work', async () => {
  const { out } = await session(['3', '100 cm in', 'list length', '1', '1', '1', 'convert 1 km all', 'quit']);
  assert.ok(out.includes('39.3700787402\n'));
  assert.ok(out.includes('pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly\n'));
  assert.ok(out.includes('km: 1\n') && out.includes('mi: 0.621371192237\n'));
});

test('converter: typed back and quit on the pick screens', async () => {
  assert.equal(count((await session(['3', 'Back', '0'])).out, MENU), 2);
  assert.equal(count((await session(['3', '1', 'Back', 'Back', '0'])).out, MENU), 2);
  assert.equal(count((await session(['3', '1', '1', 'QUIT', '0'])).out, MENU), 1);
});

test('converter: list works at the values prompt', async () => {
  const { out } = await session([...CONVERTER_VALUES, 'list', 'quit']);
  assert.ok(out.includes('length, mass, area'));
});

test('converter: a bad unit pick is an error and asks again', async () => {
  const { out } = await session(['3', '12', 'inch', 'c', 'f', 'quit']);
  assert.ok(out.includes('Error [UNKNOWN_COMMAND]') && out.includes('convert from c to'));
});

test('one-shot mode: convert', async () => {
  const s = scripted([]);
  assert.equal(await main(['convert', '100', 'cm', 'in'], s.io), 0);
  assert.equal(s.text(), '39.3700787402\n');
});

test('one-shot mode: std / prog, error status, usage', async () => {
  let s = scripted([]);
  assert.equal(await main(['std', '25 + 17'], s.io), 0);
  assert.equal(s.text(), '42\n');
  s = scripted([]);
  assert.equal(await main(['prog', 'convert 255 dec hex'], s.io), 0);
  assert.equal(s.text(), 'FF\n');
  s = scripted([]);
  assert.equal(await main(['std', '10 / 0'], s.io), 1);
  assert.ok(s.text().startsWith('Error [DIV_BY_ZERO]'));
  s = scripted([]);
  assert.equal(await main(['bogus'], s.io), 2);
  assert.ok(s.text().includes('Usage:'));
});