//! Rust extras: formatting boundaries, settled amendments, garbage input, one-shot exit codes.
use arithmos::calculator::Calculator;
use arithmos::cli::one_shot;
use arithmos::converter;
use arithmos::programmer::Programmer;
use arithmos::shared::format_number;

fn std_ok(s: &str) -> String {
    Calculator::new().evaluate(s).unwrap()
}
fn std_err(s: &str) -> &'static str {
    Calculator::new().evaluate(s).unwrap_err().code
}

#[test]
fn formatting_boundaries() {
    assert_eq!(format_number(100000000000.5).unwrap(), "100000000001"); // R10: half away from zero
    assert_eq!(format_number(-0.0).unwrap(), "0");
    assert_eq!(format_number(1e15).unwrap(), "1e+15");
    assert_eq!(format_number(999999999999.0).unwrap(), "999999999999");
    assert_eq!(format_number(0.000001).unwrap(), "0.000001");
    assert_eq!(format_number(0.0000001).unwrap(), "1e-7");
    assert_eq!(format_number(999999999999000.0).unwrap(), "999999999999000"); // Just below 1e15 with only 12 significant digits: stays plain notation.
    assert_eq!(format_number(999999999999499.0).unwrap(), "999999999999000"); // The 13th digit is 4, so it rounds down and stays plain.
    assert_eq!(format_number(999999999999900.0).unwrap(), "1e+15"); // The 13th digit is 9, so it carries up to exactly 1e15, which is scientific (spec §2.3).
    assert_eq!(format_number(9.999999999999e14).unwrap(), "1e+15");
    assert_eq!(format_number(0.99999999999999).unwrap(), "1"); // carry out of the first digit
    assert_eq!(format_number(f64::INFINITY).unwrap_err().code, "OVERFLOW");
}

#[test]
fn settled_amendments() {
    assert_eq!(std_ok("200 + (10%)"), "200.1"); // R1
    assert_eq!(std_ok("200 + 5 * 10%"), "200.5"); // R2
    assert_eq!(std_ok("2^50%"), "1.41421356237"); // R3
    assert_eq!(std_ok("50%%"), "0.005"); // R4
    assert_eq!(std_ok("5 of 10"), "50"); // R5
    assert_eq!(std_ok("ANS"), "0"); // R6
    assert_eq!(std_err("1e5"), "INVALID_EXPRESSION"); // R7
    assert_eq!(std_err("5.5.5"), "INVALID_EXPRESSION"); // R8
    assert_eq!(std_ok("10^-400"), "0"); // R9
    let mut p = Programmer::new();
    p.run("base hex").unwrap();
    assert!(p.run("A AND F").unwrap().contains("DEC: 10")); // R11
    assert!(p.run("DEC").unwrap().contains("DEC: 3564"));
    assert_eq!(Programmer::new().run("NOT -1").unwrap().lines().nth(1).unwrap(), "DEC: 0"); // R12
    assert_eq!(Programmer::new().run("1 << 0x3").unwrap_err().code, "INVALID_SHIFT"); // R13
    assert_eq!(Programmer::new().run("-0x80").unwrap().lines().nth(1).unwrap(), "DEC: -128"); // R14
    assert_eq!(Programmer::new().run("convert FFFFFFFFFFFFFFFF hex dec").unwrap(), "-1"); // R15
    assert_eq!(Programmer::new().run("1<<3").unwrap().lines().nth(1).unwrap(), "DEC: 8"); // R29
    assert_eq!(Programmer::new().run("0x").unwrap_err().code, "INVALID_DIGIT"); // R30
    assert_eq!(Programmer::new().run("base DEC").unwrap(), "Input base: dec"); // R32
    assert_eq!(converter::run_line("convert 1e3 m cm").unwrap_err().code, "INVALID_NUMBER"); // R16
    assert_eq!(converter::run_line("list foo").unwrap_err().code, "UNKNOWN_COMMAND"); // R19
    assert!(converter::run_line("convert -273.15 c all").unwrap().contains("k: 0")); // R20
    assert!(converter::run_line("convert -459.67 f all").unwrap().contains("k: 0"));
}

#[test]
fn garbage_input_never_panics() {
    // The long digit string must live in its own binding so `junk` can borrow it.
    let long_digits = "9".repeat(400);
    let junk = [
        "", "   ", "(", ")", "%", "of", "sqrt", "sqrt(", "1 +* 2", "ÿ", "2 $ 3", ".", "..",
        long_digits.as_str(), "-", "0x", "<<", "1 << ", "convert", "list a b c", "é é é",
    ];
    for j in junk {
        // Any result is fine; the point is that nothing panics.
        let _ = Calculator::new().evaluate(j);
        let _ = Programmer::new().run(j);
        let _ = converter::run_line(j);
    }
    assert_eq!(std_err(&long_digits), "OVERFLOW");

    // Deep nesting runs on a big-stack thread, as main() does.
    let deep = format!("{}1{}", "(".repeat(5000), ")".repeat(5000));
    let _ = std::thread::Builder::new()
        .stack_size(256 << 20)
        .spawn(move || Calculator::new().evaluate(&deep))
        .unwrap()
        .join();
}

#[test]
fn one_shot_exit_codes() {
    let a = |v: &[&str]| one_shot(&v.iter().map(|s| s.to_string()).collect::<Vec<_>>());
    let r = a(&["std", "2 + 3 * 4"]);
    assert_eq!((r.code, r.out.as_str()), (0, "14\n"));
    let r = a(&["STD", "10 / 0"]);
    assert_eq!(r.code, 1);
    assert!(r.err.starts_with("Error [DIV_BY_ZERO]"));
    assert_eq!(a(&["prog", "0xFF", "AND", "0x0F"]).code, 0);
    assert_eq!(a(&["convert", "100", "cm", "in"]).out, "39.3700787402\n");
    assert_eq!(a(&["bogus"]).code, 2);
    assert_eq!(a(&[]).code, 2);
    assert_eq!(a(&["--help"]).code, 0);
}