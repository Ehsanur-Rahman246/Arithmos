use arithmos::cli::{io::ConsoleIo, one_shot, tools};
use std::io::Write;

/// Real entry point. Runs on a big-stack thread so deeply nested expressions are safe.
fn real_main(args: Vec<String>) -> i32 {
    if args.is_empty() {
        let mut io = ConsoleIo::new();
        tools::run_interactive(&mut io);
        return 0;
    }
    let r = one_shot(&args);
    if !r.out.is_empty() {
        let mut o = std::io::stdout();
        let _ = o.write_all(r.out.as_bytes());
        let _ = o.flush();
    }
    if !r.err.is_empty() {
        let _ = std::io::stderr().write_all(r.err.as_bytes());
    }
    r.code
}

fn main() {
    // Panics are caught by the prompt loop and shown as Error [INTERNAL]; keep the hook quiet.
    std::panic::set_hook(Box::new(|_| {}));
    let args: Vec<String> = std::env::args().skip(1).collect();
    let handle = std::thread::Builder::new()
        .stack_size(256 << 20)
        .spawn(move || real_main(args))
        .expect("cannot start main thread");
    let code = handle.join().unwrap_or(1);
    std::process::exit(code);
}