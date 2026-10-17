// CLI tests (typed fallback mode): menu, guided converter, help/back/quit, EOF,
// UNKNOWN_COMMAND, one-shot mode, and "invalid input never crashes".
import { test } from "node:test";
import assert from "node:assert/strict";
import { main } from "../src/cli/index.js";

// A scripted io: readLine(prompt) records the prompt like a real terminal would.
function scripted(lines) {
  const queue = [...lines];
  const chunks = [];
  return {
    io: {
      async readLine(prompt = "") {
        chunks.push(prompt);
        return queue.length ? queue.shift() : null;
      },
      write(t) {
        chunks.push(t);
      },
    },
    text: () => chunks.join(""),
  };
}
const session = async (lines) => {
  const s = scripted(lines);
  const code = await main([], s.io);
  return { code, out: s.text() };
};
const count = (text, piece) => text.split(piece).length - 1;

test("menu shows tools 1/2/3/0 and exits on 0", async () => {
  const { code, out } = await session(["0"]);
  assert.equal(code, 0);
  for (const piece of [
    "Arithmos 1.0 — Core CLI",
    "1) Standard Calculator",
    "2) Programmer Calculator",
    "3) Unit Converter",
    "0) Exit",
  ]) {
    assert.ok(out.includes(piece), piece);
  }
});

test("each tool runs and `back` returns to the menu", async () => {
  const { out } = await session([
    "1",
    "25 + 17",
    "back",
    "2",
    "5 AND 3",
    "back",
    "3",
    "12",
    "1",
    "2",
    "100",
    "back",
    "0",
  ]);
  assert.ok(out.includes("standard> 42\n"));
  assert.ok(out.includes("DEC: 1\n"));
  assert.ok(out.includes("100 c = 212 f\n"));
  assert.equal(count(out, "Arithmos 1.0 — Core CLI"), 4); // initial + after 3 backs
});

test("every tool says what to type when entered", async () => {
  const std = (await session(["1", "quit"])).out;
  assert.ok(
    std.includes("Examples:") &&
      std.includes('"ans"') &&
      std.includes('"back"'),
  );
  const prog = (await session(["2", "quit"])).out;
  assert.ok(
    prog.includes("Show a value:") &&
      prog.includes("Bitwise:") &&
      prog.includes("Shifts:"),
  );
  const conv = (await session(["3", "quit"])).out;
  assert.equal(count(conv, "\n  12) temperature\n"), 1);
});

test("converter lists all 12 categories, then only that category's units", async () => {
  const { out } = await session(["3", "12", "quit"]);
  const cats = [
    "length",
    "mass",
    "area",
    "volume",
    "time",
    "speed",
    "digital",
    "energy",
    "power",
    "pressure",
    "angle",
    "temperature",
  ];
  cats.forEach((c, i) => assert.ok(out.includes(`  ${i + 1}) ${c}\n`), c));
  const afterPick = out.slice(out.indexOf("Temperature — convert FROM"));
  assert.ok(
    afterPick.includes("kelvin") &&
      !afterPick.includes("centimetre") &&
      !afterPick.includes("inch"),
  );
});

test("converter accepts names or symbols as well as numbers", async () => {
  const { out } = await session(["3", "temperature", "c", "f", "0", "quit"]);
  assert.ok(out.includes("0 c = 32 f\n"));
});

test("converter: values repeat without re-picking, errors do not end the loop", async () => {
  const { out } = await session([
    "3",
    "12",
    "1",
    "2",
    "100",
    "-40",
    "abc",
    "-300",
    "0",
    "quit",
  ]);
  assert.ok(
    out.includes("100 c = 212 f\n") &&
      out.includes("-40 c = -40 f\n") &&
      out.includes("0 c = 32 f\n"),
  );
  assert.ok(
    out.includes("Error [INVALID_NUMBER]") &&
      out.includes("Error [BELOW_ABSOLUTE_ZERO]"),
  );
});

test("converter: `change` returns to the category list", async () => {
  const { out } = await session(["3", "1", "6", "7", "change", "12", "quit"]);
  assert.equal(count(out, "Unit Converter — choose a category"), 2);
  assert.ok(out.includes("Temperature — convert FROM"));
});

test("converter: one-line commands still work (category screen and value screen)", async () => {
  const { out } = await session([
    "3",
    "100 cm in",
    "list length",
    "1",
    "1",
    "1",
    "convert 1 km all",
    "quit",
  ]);
  assert.ok(out.includes("39.3700787402\n"));
  assert.ok(
    out.includes(
      "pm, ang, nm, um, mm, cm, m, km, in, ft, yd, mi, nmi, au, ly\n",
    ),
  );
  assert.ok(out.includes("km: 1\n") && out.includes("mi: 0.621371192237\n"));
});

test("help/back/quit are case-insensitive in every tool", async () => {
  for (const flow of [["1"], ["2"], ["3", "12", "1", "2"]]) {
    const helped = await session([...flow, "HELP", "Back", "0"]);
    assert.ok(helped.out.includes("Commands: help, back"));
    assert.equal(count(helped.out, "Arithmos 1.0 — Core CLI"), 2); // Back returned to the menu
    const quit = await session([...flow, "QuIt", "1", "never reached"]);
    assert.equal(quit.code, 0);
    assert.equal(count(quit.out, "Arithmos 1.0 — Core CLI"), 1); // quit exits, no menu again
  }
});

test("typed `back` / `quit` work on the converter pick screens too", async () => {
  assert.equal(
    count((await session(["3", "Back", "0"])).out, "Arithmos 1.0 — Core CLI"),
    2,
  );
  assert.equal(
    count(
      (await session(["3", "1", "Back", "0"])).out,
      "Arithmos 1.0 — Core CLI",
    ),
    2,
  );
  assert.equal(
    count(
      (await session(["3", "1", "1", "QUIT", "0"])).out,
      "Arithmos 1.0 — Core CLI",
    ),
    1,
  );
});

test("EOF exits cleanly, in the menu, inside a tool, and mid-converter", async () => {
  for (const flow of [
    [],
    ["1"],
    ["3"],
    ["3", "1"],
    ["3", "1", "1"],
    ["3", "1", "1", "1"],
  ]) {
    assert.equal((await session(flow)).code, 0);
  }
});

test("blank lines and surrounding whitespace are ignored", async () => {
  const { out } = await session(["1", "", "   ", "  2 + 2  ", "quit"]);
  assert.ok(out.includes("standard> 4\n"));
  assert.ok(!out.includes("Error"));
});

test("unknown command yields UNKNOWN_COMMAND in every tool and the menu", async () => {
  const { out } = await session([
    "9",
    "2",
    "hello world foo",
    "back",
    "3",
    "blah",
    "back",
    "0",
  ]);
  assert.equal(count(out, "Error [UNKNOWN_COMMAND]"), 3);
});

test("a bad unit pick is an error and asks again", async () => {
  const { out } = await session(["3", "12", "inch", "c", "f", "quit"]);
  assert.ok(out.includes("Error [UNKNOWN_COMMAND]"));
  assert.ok(out.includes("convert TO"));
});

test("errors print as `Error [CODE]: message` and ans survives them", async () => {
  const { out } = await session(["1", "7", "10 / 0", "ans", "quit"]);
  assert.ok(/Error \[DIV_BY_ZERO\]: .+/.test(out));
  assert.ok(out.endsWith("7\nstandard> "));
});

test("invalid input never crashes any tool", async () => {
  const junk = [
    "(((",
    ")",
    "%",
    "1e5",
    "5.5.5",
    "$$$",
    "0x",
    "-",
    "1 << ",
    "convert",
    "convert 1",
    "list nope",
    "base",
    "\t",
    "999999999999999999999999 + 1",
  ];
  const { code, out } = await session([
    "1",
    ...junk,
    "back",
    "2",
    ...junk,
    "back",
    "3",
    ...junk,
    "back",
    "3",
    "1",
    "1",
    "2",
    ...junk,
    "quit",
  ]);
  assert.equal(code, 0);
  assert.ok(!out.includes("INTERNAL"));
});

test("one-shot mode: arithmos convert 100 cm in", async () => {
  const s = scripted([]);
  assert.equal(await main(["convert", "100", "cm", "in"], s.io), 0);
  assert.equal(s.text(), "39.3700787402\n");
});

test("one-shot mode: std / prog, error exit status, usage", async () => {
  let s = scripted([]);
  assert.equal(await main(["std", "25 + 17"], s.io), 0);
  assert.equal(s.text(), "42\n");
  s = scripted([]);
  assert.equal(await main(["prog", "convert 255 dec hex"], s.io), 0);
  assert.equal(s.text(), "FF\n");
  s = scripted([]);
  assert.equal(await main(["std", "10 / 0"], s.io), 1);
  assert.ok(s.text().startsWith("Error [DIV_BY_ZERO]"));
  s = scripted([]);
  assert.equal(await main(["bogus"], s.io), 2);
});
