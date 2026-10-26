//! Runs the shared cases (docs/release-1-cases.json) with a tiny built-in JSON reader.
use arithmos::calculator::Calculator;
use arithmos::converter;
use arithmos::programmer::Programmer;
use arithmos::shared::Res;
use std::collections::HashMap;

// ------------------------------------------------------------ minimal JSON
#[derive(Debug, Clone)]
enum J {
    S(String),
    A(Vec<J>),
    O(Vec<(String, J)>),
}

impl J {
    fn get(&self, k: &str) -> Option<&J> {
        match self {
            J::O(v) => v.iter().find(|(key, _)| key == k).map(|(_, v)| v),
            _ => None,
        }
    }
}

struct P<'a> {
    b: &'a [u8],
    i: usize,
}

impl<'a> P<'a> {
    fn ws(&mut self) {
        while self.i < self.b.len() && self.b[self.i].is_ascii_whitespace() {
            self.i += 1;
        }
    }
    fn val(&mut self) -> J {
        self.ws();
        match self.b[self.i] {
            b'[' => {
                self.i += 1;
                let mut v = Vec::new();
                loop {
                    self.ws();
                    if self.b[self.i] == b']' {
                        self.i += 1;
                        break;
                    }
                    v.push(self.val());
                    self.ws();
                    if self.b[self.i] == b',' {
                        self.i += 1;
                    }
                }
                J::A(v)
            }
            b'{' => {
                self.i += 1;
                let mut v = Vec::new();
                loop {
                    self.ws();
                    if self.b[self.i] == b'}' {
                        self.i += 1;
                        break;
                    }
                    let k = self.string();
                    self.ws();
                    assert_eq!(self.b[self.i], b':');
                    self.i += 1;
                    v.push((k, self.val()));
                    self.ws();
                    if self.b[self.i] == b',' {
                        self.i += 1;
                    }
                }
                J::O(v)
            }
            b'"' => J::S(self.string()),
            c => panic!("unexpected JSON byte {}", c as char),
        }
    }
    fn string(&mut self) -> String {
        assert_eq!(self.b[self.i], b'"');
        self.i += 1;
        let mut out = Vec::new();
        while self.b[self.i] != b'"' {
            if self.b[self.i] == b'\\' {
                self.i += 1;
                match self.b[self.i] {
                    b'n' => out.push(b'\n'),
                    b't' => out.push(b'\t'),
                    b'u' => {
                        let h = std::str::from_utf8(&self.b[self.i + 1..self.i + 5]).unwrap();
                        let ch = char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap_or('?');
                        out.extend(ch.to_string().bytes());
                        self.i += 4;
                    }
                    c => out.push(c),
                }
            } else {
                out.push(self.b[self.i]);
            }
            self.i += 1;
        }
        self.i += 1;
        String::from_utf8(out).unwrap()
    }
}

// ------------------------------------------------------------ session + checks
enum Tool {
    Std(Calculator),
    Prog(Programmer),
    Conv,
}

impl Tool {
    fn run(&mut self, line: &str) -> Res<String> {
        match self {
            Tool::Std(c) => c.evaluate(line),
            Tool::Prog(p) => p.run(line),
            Tool::Conv => converter::run_line(line),
        }
    }
}

fn check(tool: &mut Tool, step: &J) -> Result<(), String> {
    let input = match step.get("input") {
        Some(J::S(s)) => s.clone(),
        _ => return Err("no input".into()),
    };
    let r = tool.run(&input);
    if let Some(J::S(code)) = step.get("error") {
        return match r {
            Err(e) if e.code == code => Ok(()),
            other => Err(format!("`{}`: expected error {}, got {:?}", input, code, other)),
        };
    }
    let out = r.map_err(|e| format!("`{}`: unexpected {}", input, e))?;
    match step.get("expected") {
        Some(J::S(s)) => {
            if &out == s { Ok(()) } else { Err(format!("`{}`: expected {:?}, got {:?}", input, s, out)) }
        }
        Some(J::O(want)) => {
            let got: HashMap<&str, &str> = out.lines().filter_map(|l| l.split_once(": ")).collect();
            for (k, v) in want {
                let J::S(v) = v else { continue };
                if got.get(k.as_str()) != Some(&v.as_str()) {
                    return Err(format!("`{}`: {} expected {:?}, got {:?}", input, k, v, got.get(k.as_str())));
                }
            }
            Ok(())
        }
        _ => {
            if let Some(J::A(items)) = step.get("expectedContains") {
                let lines: Vec<&str> = out.lines().collect();
                for it in items {
                    if let J::S(s) = it {
                        if !lines.contains(&s.as_str()) {
                            return Err(format!("`{}`: missing line {:?} in {:?}", input, s, out));
                        }
                    }
                }
                Ok(())
            } else {
                Err("no outcome".into())
            }
        }
    }
}

#[test]
fn shared_cases() {
    let path = std::env::var("CASES").unwrap_or_else(|_| "../docs/release-1-cases.json".into());
    let text = std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("cannot read {}: {}", path, e));
    let J::A(cases) = (P { b: text.as_bytes(), i: 0 }).val() else { panic!("array expected") };
    assert_eq!(cases.len(), 175, "the shared file has 175 cases");

    let mut failures = Vec::new();
    for case in &cases {
        let id = match case.get("id") { Some(J::S(s)) => s.clone(), _ => "?".into() };
        let mut tool = match case.get("tool") {
            Some(J::S(t)) if t == "standard" => Tool::Std(Calculator::new()),
            Some(J::S(t)) if t == "programmer" => Tool::Prog(Programmer::new()),
            _ => Tool::Conv,
        };
        if let Some(J::A(setup)) = case.get("setup") {
            for s in setup {
                if let J::S(line) = s {
                    tool.run(line).expect("setup line failed");
                }
            }
        }
        let results: Vec<Result<(), String>> = match case.get("steps") {
            Some(J::A(steps)) => steps.iter().map(|s| check(&mut tool, s)).collect(),
            _ => vec![check(&mut tool, case)],
        };
        for r in results {
            if let Err(e) = r {
                failures.push(format!("{}: {}", id, e));
            }
        }
    }
    assert!(failures.is_empty(), "{} failed:\n{}", failures.len(), failures.join("\n"));
}