// Extra tests (not shared): formatting boundaries, settled amendments, garbage
// input, scripted sessions, one-shot exit codes.
import assert from 'node:assert/strict';
import test from 'node:test';
import { Calculator } from '../src/calculator';
import { runInteractive, runOneShot } from '../src/cli/cli';
import { convertLine } from '../src/converter';
import { Programmer } from '../src/programmer';
import { ArithmosError, type ErrorCode } from '../src/shared/errors';
import { formatNumber } from '../src/shared/format-number';
import { FakeIo } from './fakes';

const std = (s: string): string => new Calculator().evaluate(s);
const prog = (s: string, base?: string) => {
  const p = new Programmer();
  if (base) p.execute(`base ${base}`);
  return p.execute(s);
};
const codeOf = (fn: () => unknown): string | undefined => {
  try { fn(); } catch (e) { return e instanceof ArithmosError ? e.code : `non-spec: ${String(e)}`; }
  return undefined;
};
const expectCode = (fn: () => unknown, code: ErrorCode): void => assert.equal(codeOf(fn), code);

test('formatNumber boundaries (spec §2.3)', () => {
  assert.equal(formatNumber(100000000000.5), '100000000001'); // half away from zero (R10)
  assert.equal(formatNumber(123456789012.5), '123456789013');
  assert.equal(formatNumber(1e-6), '0.000001');
  assert.equal(formatNumber(2e-7), '2e-7');
  assert.equal(formatNumber(1e15), '1e+15');
  assert.equal(formatNumber(999999999999999), '1e+15'); // exponent read after rounding
  assert.equal(formatNumber(1.5e20), '1.5e+20');
  assert.equal(formatNumber(-0), '0');
  assert.equal(formatNumber(0.1 + 0.2), '0.3');
  assert.equal(formatNumber(-2.5), '-2.5');
  expectCode(() => formatNumber(Infinity), 'OVERFLOW');
});

test('settled amendments: Standard (R1-R9)', () => {
  assert.equal(std('200 + (10%)'), '200.1');
  assert.equal(std('200 + 5 * 10%'), '200.5');
  assert.equal(std('2^50%'), '1.41421356237');
  assert.equal(std('50%%'), '0.005');
  assert.equal(std('5 of 10'), '50');
  assert.equal(std('ANS'), '0');
  expectCode(() => std('1e5'), 'INVALID_EXPRESSION');
  expectCode(() => std('5.5.5'), 'INVALID_EXPRESSION');
  expectCode(() => std('.'), 'INVALID_EXPRESSION');
  assert.equal(std('10^-400'), '0');
  expectCode(() => std('(-8)^(1/3)'), 'DOMAIN_ERROR');
  expectCode(() => std('sqrt 4'), 'INVALID_EXPRESSION');
});

test('settled amendments: Programmer (R11-R15, R29, R30)', () => {
  assert.equal((prog('A AND F', 'hex') as { display: { HEX: string } }).display.HEX, 'A');
  assert.equal((prog('DEC', 'hex') as { display: { DEC: string } }).display.DEC, '3564');
  assert.equal((prog('NOT 0xFF') as { display: { DEC: string } }).display.DEC, '-256');
  assert.equal((prog('NOT -1') as { display: { DEC: string } }).display.DEC, '0');
  assert.equal((prog('1<<3') as { display: { DEC: string } }).display.DEC, '8');
  assert.equal((prog('-0x80') as { display: { DEC: string } }).display.DEC, '-128');
  assert.equal((prog('convert FFFFFFFFFFFFFFFF hex dec') as { text: string }).text, '-1');
  assert.equal((prog('0B', 'hex') as { display: { DEC: string } }).display.DEC, '11');
  expectCode(() => prog('1 << 0x3'), 'INVALID_SHIFT');
  expectCode(() => prog('1 << 2.5'), 'INVALID_SHIFT');
  expectCode(() => prog('0x'), 'INVALID_DIGIT');
});

test('settled amendments: Converter (R16-R20)', () => {
  expectCode(() => convertLine('convert 1e3 m cm'), 'INVALID_NUMBER');
  expectCode(() => convertLine('list foo'), 'UNKNOWN_COMMAND');
  assert.equal(convertLine('convert 0 k all').length, 3);
  assert.equal(convertLine('convert -273.15 c all').length, 3); // exactly at the limit is allowed
  expectCode(() => convertLine('convert -460 f all'), 'BELOW_ABSOLUTE_ZERO');
  expectCode(() => convertLine(`convert ${'9'.repeat(300)} ly pm`), 'OVERFLOW'); // A huge value converted to a small unit overflows to Infinity → OVERFLOW (R17).
});

test('garbage input never throws anything but ArithmosError', () => {
  const alphabet = ' 0123456789abcxyz+-*/^()%.<>&|~$\\"\'eofnsqrtANDX';
  let seed = 12345;
  const rand = (): number => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; };
  for (let n = 0; n < 2000; n++) {
    let line = '';
    for (let i = rand() % 14; i >= 0; i--) line += alphabet[rand() % alphabet.length];
    for (const run of [() => std(line), () => prog(line), () => convertLine(line)]) {
      const code = codeOf(run);
      assert.ok(code === undefined || !code.startsWith('non-spec'), `${JSON.stringify(line)} → ${code}`);
    }
  }
});

test('one-shot mode: output, streams and exit codes (R31)', () => {
  const run = (args: string[]) => {
    let out = '', err = '';
    const status = runOneShot(args, (s) => (out += s), (s) => (err += s));
    return { status, out, err };
  };
  assert.deepEqual(run(['std', '2 + 3 * 4']), { status: 0, out: '14\n', err: '' });
  assert.deepEqual(run(['STANDARD', '2+2']), { status: 0, out: '4\n', err: '' });
  assert.equal(run(['convert', '100', 'cm', 'in']).out, '39.3700787402\n');
  assert.ok(run(['prog', '5', 'AND', '3']).out.includes('DEC: 1'));
  assert.ok(run(['list', 'length']).out.startsWith('pm, ang, nm'));
  const bad = run(['std', '10 / 0']);
  assert.equal(bad.status, 1);
  assert.ok(bad.err.startsWith('Error [DIV_BY_ZERO]'));
  assert.equal(bad.out, '');
  assert.equal(run(['nonsense']).status, 2);
  assert.equal(run(['std']).status, 2);
  assert.equal(runOneShot([], () => {}, () => {}), null);
});

test('scripted interactive session (numbered lists)', async () => {
  const io = new FakeIo([
    '1', '25 + 17', 'ans * 2', '10 / 0', '', 'help', 'back', // Standard
    'programmer', '5 AND 3', 'base hex', 'back',             // Programmer
    '3', 'length', 'm', 'yd', '100', 'back', 'back', 'back', 'back', // Converter, walking back out
    'quit',
  ]);
  await runInteractive(io);
  assert.ok(io.out.includes('Arithmos 1.0 — Core CLI'));
  assert.ok(io.out.includes('  1) Standard Calculator'));
  assert.ok(io.out.includes('42\n'));
  assert.ok(io.out.includes('84\n'));
  assert.ok(io.out.includes('Error [DIV_BY_ZERO]'));
  assert.ok(io.out.includes('DEC: 1\n'));
  assert.ok(io.out.includes('Input base: hex'));
  assert.ok(io.out.includes('100 m = 109.361329834 yd'));
  assert.ok(io.out.includes('converter (m → yd)>'));
  assert.ok(io.closed);
});

test('end of input exits cleanly', async () => {
  const io = new FakeIo(['1', '2 + 2']); // then EOF inside the tool
  await runInteractive(io);
  assert.ok(io.out.includes('4\n'));
  assert.ok(io.closed);
});