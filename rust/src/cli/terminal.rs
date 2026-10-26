//! Real terminal: detection, raw key reading, size.
//! POSIX: `stty` on /dev/tty (raw mode only while a selector is on screen).
//! Windows: kernel32 + `_getwch`, declared by hand (no crates).
use super::selector::{Key, KeySource, Screen};
use std::io::{IsTerminal, Write};
use std::time::{Duration, Instant};

pub use sys::{console_guard, ConsoleGuard};

/// stdin and stdout are terminals, TERM is not `dumb`, ARITHMOS_PLAIN is not `1`, raw mode works.
pub fn selector_available() -> bool {
    if std::env::var("ARITHMOS_PLAIN").map(|v| v == "1").unwrap_or(false) {
        return false;
    }
    if std::env::var("TERM").map(|t| t == "dumb").unwrap_or(false) {
        return false;
    }
    std::io::stdin().is_terminal() && std::io::stdout().is_terminal() && sys::available()
}

pub fn color_enabled() -> bool {
    std::env::var_os("NO_COLOR").is_none()
}

pub fn new_keys() -> Box<dyn KeySource> {
    Box::new(sys::RawKeys::new())
}

pub struct TermScreen {
    color: bool,
    cache: Option<(Instant, (usize, usize))>,
}

impl TermScreen {
    pub fn new(color: bool) -> Self {
        TermScreen { color, cache: None }
    }
}

fn env_size() -> (usize, usize) {
    let g = |k: &str, d: usize| std::env::var(k).ok().and_then(|v| v.parse().ok()).unwrap_or(d);
    (g("COLUMNS", 80), g("LINES", 24))
}

impl Screen for TermScreen {
    fn write(&mut self, s: &str) {
        let mut o = std::io::stdout();
        let _ = o.write_all(s.as_bytes());
        let _ = o.flush();
    }
    /// Measured on every redraw (cached for 150 ms), so resizing works.
    fn size(&mut self) -> (usize, usize) {
        if let Some((t, s)) = self.cache {
            if t.elapsed() < Duration::from_millis(150) {
                return s;
            }
        }
        let s = sys::size().unwrap_or_else(env_size);
        self.cache = Some((Instant::now(), s));
        s
    }
    fn color(&self) -> bool {
        self.color
    }
}

// ------------------------------------------------------------------ POSIX
#[cfg(unix)]
mod sys {
    use super::*;
    use crate::cli::keys::parse_keys;
    use std::collections::VecDeque;
    use std::fs::File;
    use std::io::Read;
    use std::process::{Command, Stdio};
    use std::sync::atomic::{AtomicBool, Ordering};

    static STOP: AtomicBool = AtomicBool::new(false);

    extern "C" {
        fn signal(sig: i32, handler: usize) -> usize; // libc is already linked by std
    }
    extern "C" fn on_signal(_: i32) {
        STOP.store(true, Ordering::SeqCst); // seen by read_key within 0.1 s
    }

    /// Run `stty` against /dev/tty (works the same on Linux and macOS).
    fn stty(args: &[&str]) -> Option<String> {
        let tty = File::open("/dev/tty").ok()?;
        let out = Command::new("stty").args(args).stdin(Stdio::from(tty)).stderr(Stdio::null()).output().ok()?;
        if out.status.success() {
            Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
        } else {
            None
        }
    }

    pub fn available() -> bool {
        stty(&["-g"]).is_some()
    }

    pub fn size() -> Option<(usize, usize)> {
        let s = stty(&["size"])?;
        let mut p = s.split_whitespace();
        let rows: usize = p.next()?.parse().ok()?;
        let cols: usize = p.next()?.parse().ok()?;
        if rows == 0 || cols == 0 { None } else { Some((cols, rows)) }
    }

    pub struct ConsoleGuard;
    pub fn console_guard() -> ConsoleGuard {
        ConsoleGuard
    }

    pub struct RawKeys {
        saved: Option<String>,
        tty: Option<File>,
        queue: VecDeque<Key>,
    }

    impl RawKeys {
        pub fn new() -> Self {
            RawKeys { saved: None, tty: None, queue: VecDeque::new() }
        }
    }

    impl KeySource for RawKeys {
        fn enter(&mut self) {
            self.saved = stty(&["-g"]);
            // min 0 time 1: a read gives up after 0.1 s, so a lone Esc is told from an arrow.
            stty(&["-icanon", "-echo", "-isig", "min", "0", "time", "1"]);
            self.tty = File::open("/dev/tty").ok();
            unsafe {
                signal(15, on_signal as usize); // SIGTERM
                signal(1, on_signal as usize); // SIGHUP
            }
        }
        fn leave(&mut self) {
            if let Some(s) = self.saved.take() {
                stty(&[s.as_str()]);
            }
            self.tty = None;
            unsafe {
                signal(15, 0); // back to SIG_DFL
                signal(1, 0);
            }
        }
        fn read_key(&mut self) -> Option<Key> {
            loop {
                if let Some(k) = self.queue.pop_front() {
                    return Some(k);
                }
                if STOP.load(Ordering::SeqCst) {
                    return Some(Key::CtrlC);
                }
                let tty = self.tty.as_mut()?;
                let mut buf = [0u8; 64];
                match tty.read(&mut buf) {
                    Ok(0) => continue, // timeout
                    Ok(n) => self.queue.extend(parse_keys(&buf[..n])),
                    Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                    Err(_) => return None,
                }
            }
        }
    }

    impl Drop for RawKeys {
        fn drop(&mut self) {
            self.leave(); // the terminal is never left raw
        }
    }
}

// ---------------------------------------------------------------- Windows
#[cfg(windows)]
mod sys {
    use super::*;

    #[repr(C)]
    #[derive(Default, Clone, Copy)]
    struct Coord {
        x: i16,
        y: i16,
    }
    #[repr(C)]
    #[derive(Default, Clone, Copy)]
    struct Rect {
        l: i16,
        t: i16,
        r: i16,
        b: i16,
    }
    #[repr(C)]
    #[derive(Default, Clone, Copy)]
    struct Info {
        size: Coord,
        cursor: Coord,
        attr: u16,
        win: Rect,
        max: Coord,
    }

    #[link(name = "kernel32")]
    extern "system" {
        fn GetStdHandle(n: u32) -> isize;
        fn GetConsoleMode(h: isize, m: *mut u32) -> i32;
        fn SetConsoleMode(h: isize, m: u32) -> i32;
        fn GetConsoleScreenBufferInfo(h: isize, i: *mut Info) -> i32;
        fn SetConsoleOutputCP(cp: u32) -> i32;
        fn GetConsoleOutputCP() -> u32;
    }
    extern "C" {
        fn _getwch() -> u32;
    }

    const STD_IN: u32 = 0xFFFF_FFF6; // -10
    const STD_OUT: u32 = 0xFFFF_FFF5; // -11

    fn mode(which: u32) -> Option<(isize, u32)> {
        unsafe {
            let h = GetStdHandle(which);
            let mut m = 0u32;
            if GetConsoleMode(h, &mut m) != 0 { Some((h, m)) } else { None }
        }
    }

    pub fn available() -> bool {
        mode(STD_IN).is_some() && mode(STD_OUT).is_some()
    }

    pub fn size() -> Option<(usize, usize)> {
        unsafe {
            let h = GetStdHandle(STD_OUT);
            let mut i = Info::default();
            if GetConsoleScreenBufferInfo(h, &mut i) != 0 {
                Some(((i.win.r - i.win.l + 1) as usize, (i.win.b - i.win.t + 1) as usize))
            } else {
                None
            }
        }
    }

    /// UTF-8 output and ANSI escapes while the program runs; restored on drop.
    pub struct ConsoleGuard {
        cp: u32,
        out: Option<(isize, u32)>,
    }
    pub fn console_guard() -> ConsoleGuard {
        unsafe {
            let cp = GetConsoleOutputCP();
            let out = mode(STD_OUT);
            if let Some((h, m)) = out {
                SetConsoleMode(h, m | 0x0004); // ENABLE_VIRTUAL_TERMINAL_PROCESSING
            }
            SetConsoleOutputCP(65001);
            ConsoleGuard { cp, out }
        }
    }
    impl Drop for ConsoleGuard {
        fn drop(&mut self) {
            unsafe {
                if let Some((h, m)) = self.out {
                    SetConsoleMode(h, m);
                }
                SetConsoleOutputCP(self.cp);
            }
        }
    }

    pub struct RawKeys {
        saved: Option<(isize, u32)>,
    }
    impl RawKeys {
        pub fn new() -> Self {
            RawKeys { saved: None }
        }
    }
    impl KeySource for RawKeys {
        fn enter(&mut self) {
            self.saved = mode(STD_IN);
            if let Some((h, m)) = self.saved {
                unsafe { SetConsoleMode(h, m & !0x0001) }; // no processed input: Ctrl-C arrives as a key
            }
        }
        fn leave(&mut self) {
            if let Some((h, m)) = self.saved.take() {
                unsafe { SetConsoleMode(h, m) };
            }
        }
        fn read_key(&mut self) -> Option<Key> {
            let c = unsafe { _getwch() };
            if c == 0 || c == 0xE0 {
                let c2 = unsafe { _getwch() };
                return Some(match c2 {
                    72 => Key::Up,
                    80 => Key::Down,
                    71 => Key::Home,
                    79 => Key::End,
                    73 => Key::PgUp,
                    81 => Key::PgDn,
                    _ => Key::Other,
                });
            }
            Some(match c {
                13 => Key::Enter,
                27 => Key::Esc,
                3 => Key::CtrlC,
                4 => Key::CtrlD,
                0..=31 | 127 => Key::Other,
                n => char::from_u32(n).map(Key::Char).unwrap_or(Key::Other),
            })
        }
    }
    impl Drop for RawKeys {
        fn drop(&mut self) {
            self.leave();
        }
    }
}