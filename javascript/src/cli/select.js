// Arrow-key list selector. The key handling and drawing are plain functions with no
// terminal code in them, so they can be tested; selectFromList() is the thin
// terminal wrapper around them.
import { PLAIN } from "./style.js";

export function initialState(count, size = 10) {
  return { index: 0, offset: 0, count, size: Math.min(size, count) };
}

function moveTo(state, index) {
  let { offset } = state;
  if (index < offset) offset = index;
  if (index >= offset + state.size) offset = index - state.size + 1;
  return { ...state, index, offset };
}

// A key that can start a typed line: one visible character (not a space, not Ctrl/Alt).
const isPrintable = (key) =>
  !key?.ctrl && !key?.meta && typeof key?.str === "string" && key.str.length === 1 &&
  key.str > " " && key.str !== "\x7f";

// Returns { state, done?, typed? }. done: 'selected' | 'back' | 'quit' | 'abort' | 'typed'.
// Esc and b mean "back" when it is on offer; q means "quit" when it is on offer.
// With typing on, any other printable key ends the selector as 'typed' (typed = the key),
// so the caller can read the rest of a line: a number, a name, or a one-line command.
export function applyKey(state, key, { back = false, quit = false, typing = false } = {}) {
  const name = key?.name;
  if (key?.ctrl)
    return name === "c" || name === "d" ? { state, done: "abort" } : { state };
  const { index, count } = state;
  switch (name) {
    case "up":
      return { state: moveTo(state, (index - 1 + count) % count) };
    case "down":
      return { state: moveTo(state, (index + 1) % count) };
    case "home":
      return { state: moveTo(state, 0) };
    case "end":
      return { state: moveTo(state, count - 1) };
    case "return":
    case "enter":
      return { state, done: "selected" };
    case "escape":
    case "b":
      return back ? { state, done: "back" } : { state };
    case "q":
      return quit ? { state, done: "quit" } : { state };
    default:
      if (typing && isPrintable(key)) return { state, done: "typed", typed: key.str };
      return { state };
  }
}

export function renderList(
  title,
  labels,
  state,
  { style = PLAIN, back = false, quit = false, typing = false } = {},
) {
  const width = Math.max(...labels.map((label) => label.length));
  const lines = [style.bold(title)];
  for (let i = state.offset; i < state.offset + state.size; i += 1) {
    // the whole selected row is highlighted
    lines.push(
      i === state.index
        ? style.inverse(` ❯ ${labels[i].padEnd(width)} `)
        : `   ${labels[i]}`,
    );
  }
  if (state.count > state.size)
    lines.push(style.dim(`   ${state.index + 1} of ${state.count}`));
  const hint = ["↑↓ move", "Enter select"];
  if (back) hint.push(typing ? "Esc/b back" : "Esc back");
  if (quit) hint.push("q quit");
  if (typing) hint.push("or type");
  lines.push(style.dim(`   ${hint.join(" · ")}`));
  return lines;
}

// Resolves to { status: 'selected', index }, { status: 'typed', text } or
// { status: 'back' | 'quit' | 'abort' }.
// readKey() resolves to the next key ({ name, ctrl, ... }). The selector never touches
// raw mode or pause/resume: the key reader owns the terminal for the whole session.
export async function selectFromList({
  readKey,
  output,
  title,
  labels,
  style = PLAIN,
  back = false,
  quit = false,
  typing = false,
}) {
  let state = initialState(labels.length);
  let drawn = 0;
  const erase = () => {
    if (drawn) output.write(`\x1b[${drawn}A\x1b[0J`);
    drawn = 0;
  };
  const draw = () => {
    erase();
    const lines = renderList(title, labels, state, { style, back, quit, typing });
    output.write(`${lines.join("\n")}\n`);
    drawn = lines.length;
  };

  output.write("\x1b[?25l"); // hide the cursor while choosing
  draw();
  let status;
  let typed = "";
  for (;;) {
    const result = applyKey(state, await readKey(), { back, quit, typing });
    if (result.done) {
      state = result.state;
      status = result.done;
      typed = result.typed ?? "";
      break;
    }
    if (result.state !== state) {
      state = result.state;
      draw();
    }
  }
  erase();
  if (status === "selected")
    output.write(`${style.green("✔")} ${title}: ${labels[state.index]}\n`);
  output.write("\x1b[?25h");
  if (status === "selected") return { status, index: state.index };
  if (status === "typed") return { status, text: typed };
  return { status };
}
