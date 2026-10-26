//! Menus, prompt loops and tool bindings. Errors print as `Error [CODE]: message`.
use super::io::Io;
use super::pick::{pick, Opt, Pick};
use crate::calculator::Calculator;
use crate::converter::{self, Category, Unit};
use crate::programmer::Programmer;
use crate::shared::{ArithmosError, Res};
use std::panic::{catch_unwind, AssertUnwindSafe};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Exit {
    Back, // return to the previous screen / main menu
    Quit, // leave the program (also end of input)
}

/// Invalid input never crashes the program: a panic becomes `Error [INTERNAL]`.
fn guarded(f: impl FnOnce() -> Res<String>) -> Res<String> {
    match catch_unwind(AssertUnwindSafe(f)) {
        Ok(r) => r,
        Err(_) => Err(ArithmosError::new("INTERNAL", "Unexpected internal error")),
    }
}

fn show(io: &mut dyn Io, r: Res<String>) {
    match r {
        Ok(s) => io.write(&format!("{}\n", s)),
        Err(e) => io.write(&format!("{}\n", e)),
    }
}

fn no_cmd(_: &mut dyn Io, _: &str) -> bool {
    false
}

const STD_INTRO: &str = "Standard Calculator. Type an expression; help for commands, back to return.\n";
const STD_HELP: &str = "Operators: + - * / ^  unary signs  ( )  %  of  sqrt()  abs()  ans\n\
Examples: 2 + 3 * 4   20% of 150   200 + 10%   ans * 2\nCommands: help (or ?), back, quit\n";
const PROG_INTRO: &str = "Programmer Calculator (64-bit signed). Type a value or command; help for commands, back to return.\n";
const PROG_HELP: &str = "Value: 0xFF  0b101  0o17  0d9  (prefix wins over the input base)\n\
base <bin|oct|dec|hex>   [convert] <value> <from> <to>   AND OR XOR NOT   <<  >>  >>>\n\
Commands: help (or ?), back, quit\n";
const CONV_HELP: &str = "Type a value to convert, e.g. 100. One-line forms work too:\n\
  convert 100 cm in    100 cm in    convert 1 km all    list    list <category>\nCommands: help (or ?), back, quit\n";

/// Shared prompt loop for the calculators.
fn prompt_loop(io: &mut dyn Io, prompt: &str, intro: &str, help: &str, handler: &mut dyn FnMut(&str) -> Res<String>) -> Exit {
    io.write(intro);
    loop {
        let Some(line) = io.read_line(prompt) else { return Exit::Quit };
        let t = line.trim();
        if t.is_empty() {
            continue;
        }
        match t.to_lowercase().as_str() {
            "back" => return Exit::Back,
            "quit" => return Exit::Quit,
            "help" | "?" => {
                io.write(help);
                continue;
            }
            _ => {}
        }
        let r = guarded(|| handler(t));
        show(io, r);
    }
}

pub fn standard_tool(io: &mut dyn Io) -> Exit {
    let mut calc = Calculator::new();
    prompt_loop(io, "standard> ", STD_INTRO, STD_HELP, &mut |l| calc.evaluate(l))
}

pub fn programmer_tool(io: &mut dyn Io) -> Exit {
    let mut prog = Programmer::new();
    prompt_loop(io, "programmer> ", PROG_INTRO, PROG_HELP, &mut |l| prog.run(l))
}

// ------------------------------------------------------------ guided converter

/// Is this typed line a one-line converter command? If so run it and say yes.
fn conv_cmd(io: &mut dyn Io, line: &str) -> bool {
    let w: Vec<&str> = line.split_whitespace().collect();
    let first = w.first().map(|s| s.to_lowercase()).unwrap_or_default();
    if first == "convert" || first == "list" || w.len() == 3 {
        let r = guarded(|| converter::run_line(line));
        show(io, r);
        true
    } else {
        false
    }
}

fn cap(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
        None => String::new(),
    }
}

fn unit_opts(cat: &Category) -> Vec<Opt> {
    cat.units
        .iter()
        .map(|u| {
            let name = u.name.to_lowercase();
            Opt::new(&format!("{} — {}", u.symbol, u.name)).keys(&[u.symbol, name.as_str()])
        })
        .collect()
}

/// The values prompt. `Back` means "go back one stage".
fn values_loop(io: &mut dyn Io, from: &Unit, to: &Unit, cat: &Category) -> Exit {
    let prompt = format!("converter ({} → {})> ", from.symbol, to.symbol);
    loop {
        let Some(line) = io.read_line(&prompt) else { return Exit::Quit };
        let t = line.trim();
        if t.is_empty() {
            continue;
        }
        match t.to_lowercase().as_str() {
            "back" => return Exit::Back,
            "quit" => return Exit::Quit,
            "help" | "?" => {
                io.write(CONV_HELP);
                continue;
            }
            _ => {}
        }
        let w: Vec<&str> = t.split_whitespace().collect();
        let r = if w.len() == 1 && !w[0].eq_ignore_ascii_case("list") {
            guarded(|| converter::convert_units(w[0], from, to, cat))
        } else {
            guarded(|| converter::run_line(t))
        };
        show(io, r);
    }
}

/// category -> from -> to -> values. `back` steps back one stage; from the first it leaves.
pub fn converter_tool(io: &mut dyn Io) -> Exit {
    let cats = converter::categories();
    let (mut stage, mut ci, mut fi, mut ti) = (0usize, 0usize, 0usize, 0usize);
    loop {
        let r = match stage {
            0 => {
                let opts: Vec<Opt> = cats.iter().map(|c| Opt::new(c.name)).collect();
                pick(io, "Unit Converter — choose a category", &opts, true, true, &mut conv_cmd)
            }
            1 => {
                let t = format!("{} — convert from", cap(cats[ci].name));
                pick(io, &t, &unit_opts(&cats[ci]), true, true, &mut conv_cmd)
            }
            2 => {
                let t = format!("{} — convert from {} to", cap(cats[ci].name), cats[ci].units[fi].symbol);
                pick(io, &t, &unit_opts(&cats[ci]), true, true, &mut conv_cmd)
            }
            _ => {
                let cat = &cats[ci];
                match values_loop(io, &cat.units[fi], &cat.units[ti], cat) {
                    Exit::Back => Pick::Back,
                    Exit::Quit => Pick::Quit,
                }
            }
        };
        match r {
            Pick::Chosen(i) => match stage {
                0 => {
                    ci = i;
                    stage = 1;
                }
                1 => {
                    fi = i;
                    stage = 2;
                }
                _ => {
                    ti = i;
                    stage = 3;
                }
            },
            Pick::Back => {
                if stage == 0 {
                    return Exit::Back;
                }
                stage -= 1;
            }
            Pick::Quit | Pick::Eof => return Exit::Quit,
        }
    }
}

// ------------------------------------------------------------------- main menu

pub fn run_interactive(io: &mut dyn Io) {
    let opts = vec![
        Opt::new("Standard Calculator").keys(&["standard", "std"]),
        Opt::new("Programmer Calculator").keys(&["programmer", "prog"]),
        Opt::new("Unit Converter").keys(&["converter", "convert"]),
        Opt::new("Exit").tag("0").keys(&["exit"]),
    ];
    loop {
        let exit = match pick(io, "Arithmos 1.0 — Core CLI", &opts, false, true, &mut no_cmd) {
            Pick::Chosen(0) => standard_tool(io),
            Pick::Chosen(1) => programmer_tool(io),
            Pick::Chosen(2) => converter_tool(io),
            _ => return, // Exit, quit, Ctrl-C or end of input
        };
        if exit == Exit::Quit {
            return;
        }
    }
}