//! Arrow-key selector in four layers: key handling (pure), drawing (pure),
//! a draw/read loop over an injectable keyboard and screen, and (in pick.rs) `pick()`.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Key {
    Up,
    Down,
    Home,
    End,
    PgUp,
    PgDn,
    Enter,
    Esc,
    CtrlC,
    CtrlD,
    Char(char),
    Other,
}

/// Which keys the screen offers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SelOpts {
    pub back: bool,
    pub quit: bool,
    pub typing: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SelResult {
    Index(usize),
    Back,
    Quit,
    Abort, // Ctrl-C / Ctrl-D / end of input
    Typed(char),
}

#[derive(Debug, Clone, Copy, Default)]
pub struct SelState {
    pub index: usize,
    pub top: usize,
}

pub const WINDOW: usize = 10;

/// Rows shown: at most 10, at most the item count, and the block must fit the terminal.
pub fn window_for(n: usize, height: usize) -> usize {
    WINDOW.min(n).min(height.saturating_sub(3).max(1))
}

pub fn scroll(st: &mut SelState, n: usize, window: usize) {
    if st.index < st.top {
        st.top = st.index;
    } else if st.index >= st.top + window {
        st.top = st.index + 1 - window;
    }
    st.top = st.top.min(n.saturating_sub(window));
}

/// Layer 1: apply one key. `Some(result)` ends the selector.
pub fn handle_key(st: &mut SelState, key: Key, n: usize, o: &SelOpts, window: usize) -> Option<SelResult> {
    match key {
        Key::Up => st.index = (st.index + n - 1) % n,
        Key::Down => st.index = (st.index + 1) % n,
        Key::Home => st.index = 0,
        Key::End => st.index = n - 1,
        Key::PgUp => st.index = st.index.saturating_sub(window),
        Key::PgDn => st.index = (st.index + window).min(n - 1),
        Key::Enter => return Some(SelResult::Index(st.index)),
        Key::Esc => {
            if o.back {
                return Some(SelResult::Back);
            }
        }
        Key::CtrlC | Key::CtrlD => return Some(SelResult::Abort),
        Key::Char(c) => {
            let l = c.to_ascii_lowercase();
            if l == 'b' && o.back {
                return Some(SelResult::Back);
            }
            if l == 'q' && o.quit {
                return Some(SelResult::Quit);
            }
            // Any other printable key opens a typed line (space and control keys do not).
            if o.typing && !c.is_control() && !c.is_whitespace() {
                return Some(SelResult::Typed(c));
            }
        }
        Key::Other => {}
    }
    scroll(st, n, window);
    None
}

/// "…" if longer than `width` columns (one logical line = one screen line).
fn fit(s: &str, width: usize) -> String {
    if s.chars().count() <= width {
        s.to_string()
    } else {
        let mut t: String = s.chars().take(width.saturating_sub(1)).collect();
        t.push('…');
        t
    }
}

/// Layer 2: the block as lines (no newlines). Every line is at most (width - 1) columns.
pub fn render(title: &str, labels: &[String], st: &SelState, o: &SelOpts, size: (usize, usize), color: bool) -> Vec<String> {
    let width = size.0.saturating_sub(1).max(8);
    let n = labels.len();
    let window = window_for(n, size.1);
    let mut top = st.top;
    if st.index < top {
        top = st.index;
    } else if st.index >= top + window {
        top = st.index + 1 - window;
    }
    top = top.min(n.saturating_sub(window));

    let mut lines = Vec::new();
    let t = fit(title, width);
    lines.push(if color { format!("\x1b[1m{}\x1b[0m", t) } else { t });
    for i in top..top + window {
        if i == st.index {
            let row = fit(&format!("❯ {}", labels[i]), width);
            if color {
                let pad = width.saturating_sub(row.chars().count());
                lines.push(format!("\x1b[7m{}{}\x1b[0m", row, " ".repeat(pad)));
            } else {
                lines.push(row);
            }
        } else {
            lines.push(fit(&format!("  {}", labels[i]), width));
        }
    }
    let mut hint = String::from("↑↓ move · Enter select");
    if o.back {
        hint.push_str(" · Esc/b back");
    }
    if o.quit {
        hint.push_str(" · q quit");
    }
    if o.typing {
        hint.push_str(" · or type");
    }
    if n > window {
        hint.push_str(&format!(" · {}/{}", st.index + 1, n));
    }
    let h = fit(&hint, width);
    lines.push(if color { format!("\x1b[2m{}\x1b[0m", h) } else { h });
    lines
}

pub trait KeySource {
    fn enter(&mut self); // raw mode on
    fn leave(&mut self); // raw mode off
    fn read_key(&mut self) -> Option<Key>; // None = end of input
}

pub trait Screen {
    fn write(&mut self, s: &str);
    fn size(&mut self) -> (usize, usize); // (columns, rows), measured on every redraw
    fn color(&self) -> bool;
}

/// A redraw moves the cursor up by the number of lines drawn.
fn erase(n: usize) -> String {
    format!("\x1b[{}A\r\x1b[J", n)
}

/// Layer 3: keys in, result out. Leaves `✔ <title>: <label>` behind on a choice and
/// always restores the cursor and the terminal mode.
pub fn run_selector(keys: &mut dyn KeySource, scr: &mut dyn Screen, title: &str, labels: &[String], o: &SelOpts) -> SelResult {
    let n = labels.len();
    if n == 0 {
        return SelResult::Abort;
    }
    keys.enter();
    scr.write("\x1b[?25l");
    let mut st = SelState::default();
    let mut drawn = 0usize;
    let result = loop {
        let size = scr.size();
        let window = window_for(n, size.1);
        scroll(&mut st, n, window);
        if drawn > 0 {
            scr.write(&erase(drawn));
        }
        let lines = render(title, labels, &st, o, size, scr.color());
        drawn = lines.len();
        scr.write(&(lines.join("\n") + "\n"));
        let Some(k) = keys.read_key() else { break SelResult::Abort };
        if let Some(r) = handle_key(&mut st, k, n, o, window) {
            break r;
        }
    };
    if drawn > 0 {
        scr.write(&erase(drawn));
    }
    if let SelResult::Index(i) = result {
        scr.write(&format!("✔ {}: {}\n", title, labels[i]));
    }
    scr.write("\x1b[?25h");
    keys.leave();
    result
}