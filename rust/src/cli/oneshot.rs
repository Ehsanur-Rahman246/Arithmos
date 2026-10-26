//! One-shot mode: `arithmos std "2 + 3 * 4"`. Results and --help go to stdout; `Error [CODE]`
//! and bad-usage text go to stderr. Exit status 0 / 1 (an Error) / 2 (bad usage).
use crate::calculator::Calculator;
use crate::converter;
use crate::programmer::Programmer;

pub struct OneShot {
    pub out: String,
    pub err: String,
    pub code: i32,
}

const USAGE: &str = "Usage:\n  arithmos                      interactive menu\n  arithmos std <expression>     one calculation\n  arithmos prog <command>       one programmer command\n  arithmos convert <v> <from> <to>\n  arithmos list [category]\n";

pub fn one_shot(args: &[String]) -> OneShot {
    let bad = || OneShot { out: String::new(), err: USAGE.to_string(), code: 2 };
    let Some(first) = args.first() else { return bad() };
    let cmd = first.to_lowercase();
    if cmd == "--help" || cmd == "-h" || cmd == "help" {
        return OneShot { out: USAGE.to_string(), err: String::new(), code: 0 };
    }
    let rest = args[1..].join(" ");
    let result = match cmd.as_str() {
        "std" | "standard" => {
            if rest.trim().is_empty() {
                return bad();
            }
            Calculator::new().evaluate(&rest)
        }
        "prog" | "programmer" => {
            if rest.trim().is_empty() {
                return bad();
            }
            Programmer::new().run(&rest)
        }
        "convert" => {
            if rest.trim().is_empty() {
                return bad();
            }
            converter::run_line(&format!("convert {}", rest))
        }
        "list" => converter::run_line(&format!("list {}", rest)),
        _ => return bad(),
    };
    match result {
        Ok(s) => OneShot { out: format!("{}\n", s), err: String::new(), code: 0 },
        Err(e) => OneShot { out: String::new(), err: format!("{}\n", e), code: 1 },
    }
}