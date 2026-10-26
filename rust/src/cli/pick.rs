//! Layer 4: `pick()` = one question, many answers (selector on a terminal, numbered list elsewhere).
use super::io::Io;
use super::selector::{SelOpts, SelResult};

/// One answer: a tag shown in numbered lists (default: its position), a label, and extra
/// typed names or symbols that select it.
pub struct Opt {
    pub tag: String,
    pub label: String,
    pub keys: Vec<String>,
}

impl Opt {
    pub fn new(label: &str) -> Self {
        Opt { tag: String::new(), label: label.to_string(), keys: Vec::new() }
    }
    pub fn tag(mut self, tag: &str) -> Self {
        self.tag = tag.to_string();
        self
    }
    pub fn keys(mut self, keys: &[&str]) -> Self {
        self.keys = keys.iter().map(|k| k.to_lowercase()).collect();
        self
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Pick {
    Chosen(usize),
    Back,
    Quit,
    Eof,
}

fn tag_of(opts: &[Opt], i: usize) -> String {
    if opts[i].tag.is_empty() { (i + 1).to_string() } else { opts[i].tag.clone() }
}

fn find(opts: &[Opt], typed: &str) -> Option<usize> {
    (0..opts.len()).find(|&i| {
        tag_of(opts, i) == typed || opts[i].label.to_lowercase() == typed || opts[i].keys.iter().any(|k| k == typed)
    })
}

/// `cmd` gets a typed line that matches no option; it returns true if it was a one-line
/// command (it has printed its own output). The list then comes back.
pub fn pick(
    io: &mut dyn Io,
    title: &str,
    opts: &[Opt],
    back: bool,
    quit: bool,
    cmd: &mut dyn FnMut(&mut dyn Io, &str) -> bool,
) -> Pick {
    let labels: Vec<String> = opts.iter().map(|o| o.label.clone()).collect();
    let mut show = true;
    loop {
        let line: String = if io.has_selector() {
            let so = SelOpts { back, quit, typing: true };
            match io.select(title, &labels, &so) {
                SelResult::Index(i) => return Pick::Chosen(i),
                SelResult::Back => return Pick::Back,
                SelResult::Quit => return Pick::Quit,
                SelResult::Abort => return Pick::Eof,
                SelResult::Typed(c) => match io.read_line_prefill("> ", &c.to_string()) {
                    Some(l) => l,
                    None => return Pick::Eof,
                },
            }
        } else {
            if show {
                io.write(&format!("{}\n", title));
                for i in 0..opts.len() {
                    io.write(&format!("  {}) {}\n", tag_of(opts, i), opts[i].label));
                }
                show = false;
            }
            match io.read_line("> ") {
                Some(l) => l,
                None => return Pick::Eof,
            }
        };
        let t = line.trim();
        if t.is_empty() {
            continue;
        }
        let lower = t.to_lowercase();
        match lower.as_str() {
            "help" | "?" => {
                io.write("Type a number, a name or a symbol from the list, or a one-line command. Type back to go back, quit to exit.\n");
                continue;
            }
            "quit" => return Pick::Quit,
            "back" if back => return Pick::Back,
            _ => {}
        }
        if let Some(i) = find(opts, &lower) {
            return Pick::Chosen(i);
        }
        if cmd(io, t) {
            show = true;
            continue;
        }
        io.write("Error [UNKNOWN_COMMAND]: Pick one from the list\n");
        show = true;
    }
}