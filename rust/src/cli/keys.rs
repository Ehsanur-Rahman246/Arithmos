//! Raw terminal bytes -> keys. Pure, so it is tested without a terminal (X3).
use super::selector::Key;

pub fn parse_keys(b: &[u8]) -> Vec<Key> {
    let mut out = Vec::new();
    let mut i = 0;
    while i < b.len() {
        let c = b[i];
        if c == 0x1b {
            // ESC [ ... final   or   ESC O final.  A lone ESC is the Esc key.
            if i + 1 < b.len() && (b[i + 1] == b'[' || b[i + 1] == b'O') {
                let start = i + 2;
                let mut j = start;
                while j < b.len() && !(0x40..=0x7e).contains(&b[j]) {
                    j += 1;
                }
                if j >= b.len() {
                    out.push(Key::Other); // incomplete sequence
                    break;
                }
                let params = &b[start..j];
                out.push(match b[j] {
                    b'A' => Key::Up,
                    b'B' => Key::Down,
                    b'H' => Key::Home,
                    b'F' => Key::End,
                    b'~' => match params {
                        b"1" | b"7" => Key::Home,
                        b"4" | b"8" => Key::End,
                        b"5" => Key::PgUp,
                        b"6" => Key::PgDn,
                        _ => Key::Other,
                    },
                    _ => Key::Other,
                });
                i = j + 1;
            } else {
                out.push(Key::Esc);
                i += 1;
            }
            continue;
        }
        match c {
            0x0d | 0x0a => {
                out.push(Key::Enter);
                i += 1;
            }
            0x03 => {
                out.push(Key::CtrlC);
                i += 1;
            }
            0x04 => {
                out.push(Key::CtrlD);
                i += 1;
            }
            0..=0x1f | 0x7f => {
                out.push(Key::Other);
                i += 1;
            }
            _ => {
                let len = if c < 0x80 {
                    1
                } else if c >> 5 == 0b110 {
                    2
                } else if c >> 4 == 0b1110 {
                    3
                } else if c >> 3 == 0b11110 {
                    4
                } else {
                    1
                };
                let end = (i + len).min(b.len());
                out.push(match std::str::from_utf8(&b[i..end]) {
                    Ok(s) => Key::Char(s.chars().next().unwrap()),
                    Err(_) => Key::Other,
                });
                i = end;
            }
        }
    }
    out
}