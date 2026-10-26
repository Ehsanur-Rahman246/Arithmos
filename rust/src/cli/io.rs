//! The `io` object every screen talks to (ARCHITECTURE.md "CLI screens").
use super::selector::{run_selector, SelOpts, SelResult};
use super::terminal;
use std::io::Write;

pub trait Io {
    fn write(&mut self, text: &str);
    /// `None` at end of input.
    fn read_line(&mut self, prompt: &str) -> Option<String>;
    /// A typed line that already starts with `prefill` (the key that opened it).
    fn read_line_prefill(&mut self, prompt: &str, prefill: &str) -> Option<String> {
        self.read_line(&format!("{}{}", prompt, prefill)).map(|rest| format!("{}{}", prefill, rest))
    }
    /// True only on a real terminal.
    fn has_selector(&self) -> bool {
        false
    }
    fn select(&mut self, _title: &str, _labels: &[String], _opts: &SelOpts) -> SelResult {
        SelResult::Abort
    }
}

pub struct ConsoleIo {
    selector: bool,
    color: bool,
    _guard: terminal::ConsoleGuard, // Windows: UTF-8 + ANSI on, restored on drop
}

impl Default for ConsoleIo {
    fn default() -> Self {
        Self::new()
    }
}

impl ConsoleIo {
    pub fn new() -> Self {
        let guard = terminal::console_guard();
        ConsoleIo { selector: terminal::selector_available(), color: terminal::color_enabled(), _guard: guard }
    }

    fn raw_read(&mut self) -> Option<String> {
        let mut s = String::new();
        match std::io::stdin().read_line(&mut s) {
            Ok(0) | Err(_) => {
                self.write("\n"); // end of input: finish the prompt line
                None
            }
            Ok(_) => Some(s.trim_end_matches(['\r', '\n']).to_string()),
        }
    }
}

impl Io for ConsoleIo {
    fn write(&mut self, text: &str) {
        let mut o = std::io::stdout();
        let _ = o.write_all(text.as_bytes());
        let _ = o.flush();
    }

    fn read_line(&mut self, prompt: &str) -> Option<String> {
        self.write(prompt);
        self.raw_read()
    }

    fn read_line_prefill(&mut self, prompt: &str, prefill: &str) -> Option<String> {
        self.write(&format!("{}{}", prompt, prefill));
        self.raw_read().map(|rest| format!("{}{}", prefill, rest))
    }

    fn has_selector(&self) -> bool {
        self.selector
    }

    fn select(&mut self, title: &str, labels: &[String], opts: &SelOpts) -> SelResult {
        let mut keys = terminal::new_keys();
        let mut screen = terminal::TermScreen::new(self.color);
        run_selector(&mut *keys, &mut screen, title, labels, opts)
    }
}