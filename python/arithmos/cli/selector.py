"""Arrow-key list selector. The key handling and drawing are plain functions with no
terminal code in them, so they can be tested; console.py supplies the real keys.

Key names: up down home end enter esc b q abort other."""
from dataclasses import dataclass, replace

from .style import PLAIN


@dataclass(frozen=True)
class State:
    index: int
    offset: int
    count: int
    size: int


def initial_state(count: int, size: int = 10) -> State:
    return State(0, 0, count, min(size, count))


def _move_to(state: State, index: int) -> State:
    offset = state.offset
    if index < offset:
        offset = index
    if index >= offset + state.size:
        offset = index - state.size + 1
    return replace(state, index=index, offset=offset)


def apply_key(state: State, key: str, back: bool = False, quit_: bool = False):
    """Returns (new_state, done). done: None | selected | back | quit | abort."""
    if key == "up":
        return _move_to(state, (state.index - 1) % state.count), None
    if key == "down":
        return _move_to(state, (state.index + 1) % state.count), None
    if key == "home":
        return _move_to(state, 0), None
    if key == "end":
        return _move_to(state, state.count - 1), None
    if key == "enter":
        return state, "selected"
    if key == "abort":
        return state, "abort"
    if key in ("esc", "b") and back:
        return state, "back"
    if key == "q" and quit_:
        return state, "quit"
    return state, None


def render(title, labels, state, style=PLAIN, back=False, quit_=False) -> list:
    width = max(len(label) for label in labels)
    lines = [style.bold(title)]
    for i in range(state.offset, state.offset + state.size):
        if i == state.index:  # the whole row is highlighted
            lines.append(style.inverse(f" ❯ {labels[i].ljust(width)} "))
        else:
            lines.append(f"   {labels[i]}")
    if state.count > state.size:
        lines.append(style.dim(f"   {state.index + 1} of {state.count}"))
    hint = ["↑↓ move", "Enter select"]
    if back:
        hint.append("Esc back")
    if quit_:
        hint.append("q quit")
    lines.append(style.dim("   " + " · ".join(hint)))
    return lines


def select_from_list(title, labels, *, out, read_key, style=PLAIN, back=False, quit_=False):
    """Draws the list, reads keys, returns (status, index). status is
    selected | back | quit | abort; index is set only for 'selected'."""
    state = initial_state(len(labels))
    drawn = 0

    def erase():
        nonlocal drawn
        if drawn:
            out.write(f"\x1b[{drawn}A\x1b[0J")
        drawn = 0

    def draw():
        nonlocal drawn
        erase()
        lines = render(title, labels, state, style, back, quit_)
        out.write("\n".join(lines) + "\n")
        out.flush()
        drawn = len(lines)

    out.write("\x1b[?25l")  # hide the cursor while choosing
    done = None
    try:
        draw()
        while done is None:
            try:
                key = read_key()
            except KeyboardInterrupt:
                key = "abort"
            new_state, done = apply_key(state, key, back, quit_)
            if new_state != state:
                state = new_state
                if done is None:
                    draw()
    finally:
        erase()
        if done == "selected":
            out.write(f"{style.green('✔')} {title}: {labels[state.index]}\n")
        out.write("\x1b[?25h")
        out.flush()
    return done, (state.index if done == "selected" else None)