// Arrow-key selector: pure key handling, the terminal wrapper (with fake
// streams), and pick() on top of it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import {
  initialState,
  applyKey,
  renderList,
  selectFromList,
} from "../src/cli/select.js";
import { pick } from "../src/cli/pick.js";

const press = (state, name, extras, extra = {}) =>
  applyKey(state, { name, ...extra }, extras);

test("up/down move and wrap around", () => {
  let s = initialState(3);
  s = press(s, "down").state;
  assert.equal(s.index, 1);
  s = press(s, "down").state;
  s = press(s, "down").state;
  assert.equal(s.index, 0); // wrapped
  s = press(s, "up").state;
  assert.equal(s.index, 2); // wrapped back
  s = press(s, "home").state;
  assert.equal(s.index, 0);
  s = press(s, "end").state;
  assert.equal(s.index, 2);
});

test("long lists scroll in a window of 10", () => {
  let s = initialState(18);
  assert.equal(s.size, 10);
  for (let i = 0; i < 12; i += 1) s = press(s, "down").state;
  assert.equal(s.index, 12);
  assert.ok(s.index >= s.offset && s.index < s.offset + s.size);
  s = press(s, "end").state;
  assert.equal(s.offset, 8);
  const text = renderList(
    "T",
    Array.from({ length: 18 }, (_, i) => `u${i}`),
    s,
  ).join("\n");
  assert.ok(
    text.includes("(18 of 18)") &&
      text.includes("❯ u17") &&
      !text.includes("u0\n"),
  );
});

test("Enter selects; Esc / b / q only work when offered", () => {
  const s = initialState(3);
  assert.equal(press(s, "return").done, "selected");
  assert.equal(press(s, "escape", {}).done, undefined);
  assert.equal(press(s, "escape", { esc: "up" }).done, "esc");
  assert.equal(press(s, "b", {}).done, undefined);
  assert.equal(press(s, "b", { back: "menu" }).done, "back");
  assert.equal(press(s, "q", { quit: "quit" }).done, "quit");
});

test("Ctrl-C / Ctrl-D abort; other Ctrl combos are ignored", () => {
  const s = initialState(3);
  assert.equal(press(s, "c", {}, { ctrl: true }).done, "abort");
  assert.equal(press(s, "d", {}, { ctrl: true }).done, "abort");
  assert.equal(press(s, "b", { back: "x" }, { ctrl: true }).done, undefined);
});

test("hint line lists only the keys on offer, without duplicates", () => {
  const hint = (extras) =>
    renderList("T", ["a", "b"], initialState(2), extras).at(-1);
  assert.ok(hint({}).includes("Enter select") && !hint({}).includes("Esc"));
  assert.ok(
    hint({ esc: "categories", back: "main menu", quit: "quit" }).includes(
      "b main menu",
    ),
  );
  assert.ok(
    !hint({ esc: "main menu", back: "main menu" }).includes("b main menu"),
  );
});

function fakeTerminal() {
  const input = new EventEmitter();
  input.isRaw = false;
  input.raw = [];
  input.setRawMode = (v) => {
    input.raw.push(v);
    input.isRaw = v;
  };
  input.resume = () => {};
  input.pause = () => {};
  const chunks = [];
  return {
    input,
    output: { write: (t) => chunks.push(t) },
    text: () => chunks.join(""),
  };
}
const key = (input, name) => input.emit("keypress", undefined, { name });

test("selectFromList: keys in, index out, raw mode restored, summary line left behind", async () => {
  const t = fakeTerminal();
  const p = selectFromList({
    input: t.input,
    output: t.output,
    title: "Pick",
    labels: ["a", "b", "c"],
    extras: { esc: "up" },
  });
  key(t.input, "down");
  key(t.input, "down");
  key(t.input, "return");
  assert.deepEqual(await p, { status: "selected", index: 2 });
  assert.deepEqual(t.input.raw, [true, false]);
  assert.ok(t.text().includes("✔ Pick: c"));
  assert.equal(t.input.listenerCount("keypress"), 0);
});

test("selectFromList: Esc and Ctrl-C", async () => {
  let t = fakeTerminal();
  let p = selectFromList({
    input: t.input,
    output: t.output,
    title: "Pick",
    labels: ["a", "b"],
    extras: { esc: "up" },
  });
  key(t.input, "escape");
  assert.deepEqual(await p, { status: "esc" });
  t = fakeTerminal();
  p = selectFromList({
    input: t.input,
    output: t.output,
    title: "Pick",
    labels: ["a", "b"],
  });
  t.input.emit("keypress", undefined, { name: "c", ctrl: true });
  assert.deepEqual(await p, { status: "abort" });
});

test("pick() uses io.select when it exists and maps results", async () => {
  const options = [
    { key: "1", label: "x", value: "X" },
    { key: "2", label: "y", value: "Y" },
  ];
  const ioWith = (result) => ({ select: async () => result, write() {} });
  assert.deepEqual(
    await pick(ioWith({ status: "selected", index: 1 }), {
      title: "t",
      options,
    }),
    { status: "selected", option: options[1] },
  );
  assert.deepEqual(
    await pick(ioWith({ status: "esc" }), { title: "t", options }),
    { status: "esc" },
  );
  assert.deepEqual(
    await pick(ioWith({ status: "abort" }), { title: "t", options }),
    { status: "eof" },
  );
});
