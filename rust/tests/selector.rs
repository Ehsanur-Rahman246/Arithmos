//! Selector tests SL1–SL21 (docs/test-cases.md) plus X2 (line width / window / erase) and X3 (raw bytes).
use arithmos::cli::io::Io;
use arithmos::cli::keys::parse_keys;
use arithmos::cli::pick::{pick, Opt, Pick};
use arithmos::cli::selector::*;
use std::collections::VecDeque;

// ------------------------------------------------------------------ fakes
struct FakeKeys {
    q: VecDeque<Key>,
    entered: bool,
    left: bool,
}
impl KeySource for FakeKeys {
    fn enter(&mut self) { self.entered = true; }
    fn leave(&mut self) { self.left = true; }
    fn read_key(&mut self) -> Option<Key> { self.q.pop_front() }
}
struct FakeScreen {
    out: String,
    size: (usize, usize),
    color: bool,
}
impl Screen for FakeScreen {
    fn write(&mut self, s: &str) { self.out.push_str(s); }
    fn size(&mut self) -> (usize, usize) { self.size }
    fn color(&self) -> bool { self.color }
}
struct FakeIo {
    lines: VecDeque<String>,
    sel: Option<VecDeque<SelResult>>,
    out: String,
    reads: usize,
}
impl FakeIo {
    fn plain(lines: &[&str]) -> Self {
        FakeIo { lines: lines.iter().map(|s| s.to_string()).collect(), sel: None, out: String::new(), reads: 0 }
    }
    fn with_sel(sel: &[SelResult], lines: &[&str]) -> Self {
        FakeIo { sel: Some(sel.iter().copied().collect()), ..FakeIo::plain(lines) }
    }
}
impl Io for FakeIo {
    fn write(&mut self, t: &str) { self.out.push_str(t); }
    fn read_line(&mut self, _p: &str) -> Option<String> { self.reads += 1; self.lines.pop_front() }
    fn has_selector(&self) -> bool { self.sel.is_some() }
    fn select(&mut self, _t: &str, _l: &[String], _o: &SelOpts) -> SelResult {
        self.sel.as_mut().unwrap().pop_front().unwrap_or(SelResult::Abort)
    }
}

fn labels(n: usize) -> Vec<String> { (0..n).map(|i| ["A", "B", "C", "D", "E"][i % 5].to_string() + &i.to_string()).collect() }
fn o(back: bool, quit: bool, typing: bool) -> SelOpts { SelOpts { back, quit, typing } }
fn hk(st: &mut SelState, k: Key, n: usize, op: &SelOpts) -> Option<SelResult> { handle_key(st, k, n, op, 10) }
fn run(keys: &[Key], op: SelOpts, n: usize, color: bool) -> (SelResult, FakeKeys, FakeScreen) {
    let mut k = FakeKeys { q: keys.iter().copied().collect(), entered: false, left: false };
    let mut s = FakeScreen { out: String::new(), size: (80, 24), color };
    let r = run_selector(&mut k, &mut s, "Title", &labels(n), &op);
    (r, k, s)
}
fn opts3() -> Vec<Opt> { vec![Opt::new("alpha"), Opt::new("length"), Opt::new("gamma")] }
fn no_cmd(_: &mut dyn Io, _: &str) -> bool { false }

// ------------------------------------------------------------------ SL1–SL12 (pure layers)
#[test]
fn sl1_move_wrap_home_end() {
    let (mut st, op) = (SelState::default(), o(false, false, false));
    hk(&mut st, Key::Up, 3, &op);
    assert_eq!(st.index, 2); // wrap up
    hk(&mut st, Key::Down, 3, &op);
    assert_eq!(st.index, 0); // wrap down
    hk(&mut st, Key::End, 3, &op);
    assert_eq!(st.index, 2);
    hk(&mut st, Key::Home, 3, &op);
    assert_eq!(st.index, 0);
}
#[test]
fn sl2_long_lists_scroll_in_window_of_10() {
    let (mut st, op) = (SelState::default(), o(false, false, false));
    for _ in 0..12 { hk(&mut st, Key::Down, 25, &op); }
    assert_eq!((st.index, st.top), (12, 3));
    assert_eq!(render("T", &labels(25), &st, &op, (80, 24), false).len(), 12); // title + 10 rows + hint
}
#[test]
fn sl3_enter_selects_esc_b_q_only_when_offered() {
    let (mut st, none) = (SelState::default(), o(false, false, false));
    assert_eq!(hk(&mut st, Key::Enter, 3, &none), Some(SelResult::Index(0)));
    assert_eq!(hk(&mut st, Key::Esc, 3, &none), None);
    assert_eq!(hk(&mut st, Key::Char('b'), 3, &none), None);
    assert_eq!(hk(&mut st, Key::Char('q'), 3, &none), None);
    let all = o(true, true, false);
    assert_eq!(hk(&mut st, Key::Esc, 3, &all), Some(SelResult::Back));
    assert_eq!(hk(&mut st, Key::Char('b'), 3, &all), Some(SelResult::Back));
    assert_eq!(hk(&mut st, Key::Char('q'), 3, &all), Some(SelResult::Quit));
}
#[test]
fn sl4_ctrl_c_d_abort_other_controls_ignored() {
    let (mut st, op) = (SelState::default(), o(true, true, true));
    assert_eq!(hk(&mut st, Key::CtrlC, 3, &op), Some(SelResult::Abort));
    assert_eq!(hk(&mut st, Key::CtrlD, 3, &op), Some(SelResult::Abort));
    assert_eq!(hk(&mut st, Key::Other, 3, &op), None);
}
#[test]
fn sl5_typing_on_printable_key_is_carried() {
    let mut st = SelState::default();
    assert_eq!(hk(&mut st, Key::Char('x'), 3, &o(false, false, true)), Some(SelResult::Typed('x')));
}
#[test]
fn sl6_typing_off_printable_ignored() {
    let mut st = SelState::default();
    assert_eq!(hk(&mut st, Key::Char('x'), 3, &o(false, false, false)), None);
}
#[test]
fn sl7_typing_on_keeps_special_keys() {
    let (mut st, op) = (SelState::default(), o(true, true, true));
    assert_eq!(hk(&mut st, Key::Esc, 3, &op), Some(SelResult::Back));
    assert_eq!(hk(&mut st, Key::Char('b'), 3, &op), Some(SelResult::Back));
    assert_eq!(hk(&mut st, Key::Char('q'), 3, &op), Some(SelResult::Quit));
    assert_eq!(hk(&mut st, Key::Down, 3, &op), None);
    assert_eq!(st.index, 1);
    assert_eq!(hk(&mut st, Key::Enter, 3, &op), Some(SelResult::Index(1)));
}
#[test]
fn sl8_space_and_control_keys_do_not_start_typing() {
    let (mut st, op) = (SelState::default(), o(false, false, true));
    assert_eq!(hk(&mut st, Key::Char(' '), 3, &op), None);
    assert_eq!(hk(&mut st, Key::Char('\t'), 3, &op), None);
    assert_eq!(hk(&mut st, Key::Other, 3, &op), None);
}
#[test]
fn sl9_selected_row_is_a_full_bar() {
    let st = SelState::default();
    let lines = render("T", &labels(3), &st, &o(false, false, false), (40, 24), true);
    assert!(lines[1].starts_with("\x1b[7m") && lines[1].ends_with("\x1b[0m"));
    let visible = lines[1].replace("\x1b[7m", "").replace("\x1b[0m", "");
    assert_eq!(visible.chars().count(), 39);
}
#[test]
fn sl10_plain_mode_marks_row_with_pointer() {
    let lines = render("T", &labels(3), &SelState::default(), &o(false, false, false), (40, 24), false);
    assert!(lines[1].contains('❯') && !lines[1].contains('\x1b'));
}
#[test]
fn sl11_hint_lists_only_offered_keys() {
    let lines = render("T", &labels(3), &SelState::default(), &o(false, false, false), (80, 24), false);
    let hint = lines.last().unwrap();
    assert!(!hint.contains("Esc") && !hint.contains("quit") && !hint.contains("type"));
}
#[test]
fn sl12_hint_shows_back_and_or_type() {
    let lines = render("T", &labels(3), &SelState::default(), &o(true, true, true), (80, 24), false);
    let hint = lines.last().unwrap();
    assert!(hint.contains("Esc/b back") && hint.contains("q quit") && hint.contains("or type"));
}

// ------------------------------------------------------------------ SL13–SL15 (loop)
#[test]
fn sl13_loop_keys_in_index_out() {
    let (r, k, s) = run(&[Key::Down, Key::Enter], o(true, true, false), 3, false);
    assert_eq!(r, SelResult::Index(1));
    assert!(s.out.contains("✔ Title: B1"));
    assert!(s.out.contains("\x1b[?25l") && s.out.ends_with("\x1b[?25h"));
    assert!(k.entered && k.left);
}
#[test]
fn sl14_loop_esc_ignored_keys_ctrl_c() {
    assert_eq!(run(&[Key::Other, Key::Esc], o(true, false, false), 3, false).0, SelResult::Back);
    assert_eq!(run(&[Key::Esc, Key::Other, Key::CtrlC], o(false, false, false), 3, false).0, SelResult::Abort);
    assert_eq!(run(&[], o(false, false, false), 3, false).0, SelResult::Abort); // end of input
}
#[test]
fn sl15_loop_typed_key_restores_cursor() {
    let (r, k, s) = run(&[Key::Char('x')], o(false, false, true), 3, false);
    assert_eq!(r, SelResult::Typed('x'));
    assert!(s.out.ends_with("\x1b[?25h") && k.left);
    assert!(!s.out.contains('✔'));
}

// ------------------------------------------------------------------ SL16–SL21 (pick)
#[test]
fn sl16_pick_uses_selector_and_maps_results() {
    let mut io = FakeIo::with_sel(&[SelResult::Index(1)], &[]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Chosen(1));
    let mut io = FakeIo::with_sel(&[SelResult::Back], &[]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Back);
    let mut io = FakeIo::with_sel(&[SelResult::Quit], &[]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Quit);
    let mut io = FakeIo::with_sel(&[SelResult::Abort], &[]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Eof);
}
#[test]
fn sl17_pick_typed_name_or_number_selects() {
    let mut io = FakeIo::with_sel(&[SelResult::Typed('l')], &["ength"]);
    assert_eq!(pick(&mut io, "T", &opts3(), false, false, &mut no_cmd), Pick::Chosen(1));
    let mut io = FakeIo::with_sel(&[SelResult::Typed('3')], &[""]);
    assert_eq!(pick(&mut io, "T", &opts3(), false, false, &mut no_cmd), Pick::Chosen(2));
}
#[test]
fn sl18_pick_typed_command_runs_and_list_returns() {
    let mut io = FakeIo::with_sel(&[SelResult::Typed('1'), SelResult::Index(0)], &["00 cm in"]);
    let mut seen = Vec::new();
    let mut cmd = |io: &mut dyn Io, l: &str| {
        seen.push(l.to_string());
        io.write("39.37\n");
        true
    };
    assert_eq!(pick(&mut io, "T", &opts3(), false, false, &mut cmd), Pick::Chosen(0));
    assert_eq!(seen, vec!["100 cm in"]);
    assert!(io.out.contains("39.37"));
}
#[test]
fn sl19_pick_unknown_word_is_error_and_list_returns() {
    let mut io = FakeIo::with_sel(&[SelResult::Typed('z'), SelResult::Index(0)], &["zz"]);
    assert_eq!(pick(&mut io, "T", &opts3(), false, false, &mut no_cmd), Pick::Chosen(0));
    assert!(io.out.contains("UNKNOWN_COMMAND"));
}
#[test]
fn sl20_pick_b_q_esc_act_at_once() {
    for (r, want) in [(SelResult::Back, Pick::Back), (SelResult::Quit, Pick::Quit)] {
        let mut io = FakeIo::with_sel(&[r], &["never read"]);
        assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), want);
        assert_eq!(io.reads, 0); // no prompt line
    }
}
#[test]
fn sl21_pick_numbered_list_without_selector() {
    let mut io = FakeIo::plain(&["", "2"]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Chosen(1));
    assert!(io.out.contains("  1) alpha") && io.out.contains("  3) gamma"));
    let mut io = FakeIo::plain(&["back"]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Back);
    let mut io = FakeIo::plain(&[]);
    assert_eq!(pick(&mut io, "T", &opts3(), true, true, &mut no_cmd), Pick::Eof);
}

// ------------------------------------------------------------------ X2, X3
#[test]
fn x2_width_height_and_erase() {
    let long: Vec<String> = (0..30).map(|i| format!("a very long label number {}", i)).collect();
    let lines = render("A long title for a narrow terminal", &long, &SelState::default(), &o(true, true, true), (20, 6), false);
    assert!(lines.iter().all(|l| l.chars().count() <= 19)); // width - 1
    assert_eq!(lines.len(), 5); // window shrank to 3 rows: title + 3 + hint <= 6
    let mut k = FakeKeys { q: [Key::Down, Key::Enter].into_iter().collect(), entered: false, left: false };
    let mut s = FakeScreen { out: String::new(), size: (20, 6), color: false };
    run_selector(&mut k, &mut s, "T", &long, &o(true, true, true));
    assert!(s.out.contains("\x1b[5A\r\x1b[J")); // erase moves up by the drawn line count
}
#[test]
fn x3_raw_bytes_become_keys() {
    assert_eq!(parse_keys(b"\x1b[A"), vec![Key::Up]);
    assert_eq!(parse_keys(b"\x1b[B"), vec![Key::Down]);
    assert_eq!(parse_keys(b"\x1bOA"), vec![Key::Up]);
    assert_eq!(parse_keys(b"\x1b"), vec![Key::Esc]);
    assert_eq!(parse_keys(b"\x1b[H"), vec![Key::Home]);
    assert_eq!(parse_keys(b"\x1b[F"), vec![Key::End]);
    assert_eq!(parse_keys(b"\x1b[5~"), vec![Key::PgUp]);
    assert_eq!(parse_keys(b"\x1b[6~"), vec![Key::PgDn]);
    assert_eq!(parse_keys(&[3]), vec![Key::CtrlC]);
    assert_eq!(parse_keys(&[4]), vec![Key::CtrlD]);
    assert_eq!(parse_keys(b"\r"), vec![Key::Enter]);
    assert_eq!(parse_keys("é".as_bytes()), vec![Key::Char('é')]);
    assert_eq!(parse_keys(b"a\x1b[Bb"), vec![Key::Char('a'), Key::Down, Key::Char('b')]);
}