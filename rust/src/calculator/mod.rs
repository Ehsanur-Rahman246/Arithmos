//! Standard Calculator: tokenize -> parse (AST) -> evaluate -> format (spec §3).
use crate::shared::{fail, format_number, Res};

// ---------------------------------------------------------------- tokenizer

#[derive(Debug, Clone, Copy, PartialEq)]
enum Tok {
    Num(f64),
    Plus,
    Minus,
    Star,
    Slash,
    Caret,
    LParen,
    RParen,
    Percent,
    Of,
    Sqrt,
    Abs,
    Ans,
}

fn tokenize(src: &str) -> Res<Vec<Tok>> {
    let ch: Vec<char> = src.chars().collect();
    let mut out = Vec::new();
    let mut i = 0;
    while i < ch.len() {
        let c = ch[i];
        if c.is_whitespace() {
            i += 1;
        } else if c.is_ascii_digit() || c == '.' {
            // 12, 12.5, .5, 5.  (one dot at most; `5.5.5` becomes two adjacent numbers)
            let start = i;
            let (mut dot, mut digits) = (false, 0);
            while i < ch.len() && (ch[i].is_ascii_digit() || (ch[i] == '.' && !dot)) {
                if ch[i] == '.' {
                    dot = true;
                } else {
                    digits += 1;
                }
                i += 1;
            }
            if digits == 0 {
                return fail("INVALID_EXPRESSION", "Unexpected character '.'");
            }
            let text: String = ch[start..i].iter().collect();
            match text.parse::<f64>() {
                Ok(v) if v.is_finite() => out.push(Tok::Num(v)),
                Ok(_) => return fail("OVERFLOW", "That number is too large"),
                Err(_) => return fail("INVALID_EXPRESSION", format!("Unexpected character '{}'", c)),
            }
        } else if c.is_alphabetic() {
            let start = i;
            while i < ch.len() && ch[i].is_alphabetic() {
                i += 1;
            }
            let word: String = ch[start..i].iter().collect();
            out.push(match word.to_lowercase().as_str() {
                "sqrt" => Tok::Sqrt,
                "abs" => Tok::Abs,
                "ans" => Tok::Ans,
                "of" => Tok::Of,
                _ => return fail("INVALID_EXPRESSION", format!("Unknown word '{}'", word)),
            });
        } else {
            out.push(match c {
                '+' => Tok::Plus,
                '-' => Tok::Minus,
                '*' => Tok::Star,
                '/' => Tok::Slash,
                '^' => Tok::Caret,
                '(' => Tok::LParen,
                ')' => Tok::RParen,
                '%' => Tok::Percent,
                _ => return fail("INVALID_EXPRESSION", format!("Unexpected character '{}'", c)),
            });
            i += 1;
        }
    }
    Ok(out)
}

// ---------------------------------------------------------------- parser (AST)

#[derive(Clone, Copy)]
enum Op {
    Add,
    Sub,
    Mul,
    Div,
    Pow,
}

#[derive(Clone, Copy)]
enum Fun {
    Sqrt,
    Abs,
}

enum Node {
    Num(f64),
    Ans,
    Neg(Box<Node>),
    Pos(Box<Node>),
    Pct(Box<Node>),   // postfix %, its own node (spec §3.4)
    Group(Box<Node>), // parentheses: stops a % inside from being "relative" (R1)
    Bin(Op, Box<Node>, Box<Node>),
    Call(Fun, Box<Node>),
}

struct Parser {
    t: Vec<Tok>,
    p: usize,
}

impl Parser {
    fn peek(&self) -> Option<Tok> {
        self.t.get(self.p).copied()
    }

    // expr := term (('+'|'-') term)*
    fn expr(&mut self) -> Res<Node> {
        let mut l = self.term()?;
        loop {
            let op = match self.peek() {
                Some(Tok::Plus) => Op::Add,
                Some(Tok::Minus) => Op::Sub,
                _ => break,
            };
            self.p += 1;
            let r = self.term()?;
            l = Node::Bin(op, Box::new(l), Box::new(r));
        }
        Ok(l)
    }

    // term := unary (('*'|'/'|'of') unary)*
    fn term(&mut self) -> Res<Node> {
        let mut l = self.unary()?;
        loop {
            let op = match self.peek() {
                Some(Tok::Star) | Some(Tok::Of) => Op::Mul,
                Some(Tok::Slash) => Op::Div,
                _ => break,
            };
            self.p += 1;
            let r = self.unary()?;
            l = Node::Bin(op, Box::new(l), Box::new(r));
        }
        Ok(l)
    }

    // unary := ('+'|'-') unary | power        (so -2^2 = -4)
    fn unary(&mut self) -> Res<Node> {
        match self.peek() {
            Some(Tok::Plus) => {
                self.p += 1;
                Ok(Node::Pos(Box::new(self.unary()?)))
            }
            Some(Tok::Minus) => {
                self.p += 1;
                Ok(Node::Neg(Box::new(self.unary()?)))
            }
            _ => self.power(),
        }
    }

    // power := postfix ('^' unary)?           (right-assoc; exponent may be signed: 2^-1)
    fn power(&mut self) -> Res<Node> {
        let base = self.postfix()?;
        if self.peek() == Some(Tok::Caret) {
            self.p += 1;
            let e = self.unary()?;
            return Ok(Node::Bin(Op::Pow, Box::new(base), Box::new(e)));
        }
        Ok(base)
    }

    // postfix := primary '%'*
    fn postfix(&mut self) -> Res<Node> {
        let mut n = self.primary()?;
        while self.peek() == Some(Tok::Percent) {
            self.p += 1;
            n = Node::Pct(Box::new(n));
        }
        Ok(n)
    }

    fn rparen(&mut self) -> Res<()> {
        match self.peek() {
            Some(Tok::RParen) => {
                self.p += 1;
                Ok(())
            }
            None => fail("INVALID_EXPRESSION", "Missing closing parenthesis"),
            Some(_) => fail("INVALID_EXPRESSION", "Unexpected symbol"),
        }
    }

    fn primary(&mut self) -> Res<Node> {
        match self.peek() {
            None => fail("INVALID_EXPRESSION", "The expression ends too early"),
            Some(Tok::Num(v)) => {
                self.p += 1;
                Ok(Node::Num(v))
            }
            Some(Tok::Ans) => {
                self.p += 1;
                Ok(Node::Ans)
            }
            Some(Tok::LParen) => {
                self.p += 1;
                let e = self.expr()?;
                self.rparen()?;
                Ok(Node::Group(Box::new(e)))
            }
            Some(t @ (Tok::Sqrt | Tok::Abs)) => {
                let (fun, name) = if t == Tok::Sqrt { (Fun::Sqrt, "sqrt") } else { (Fun::Abs, "abs") };
                self.p += 1;
                if self.peek() != Some(Tok::LParen) {
                    return fail("INVALID_EXPRESSION", format!("{} needs parentheses, like {}(4)", name, name));
                }
                self.p += 1;
                let e = self.expr()?;
                self.rparen()?;
                Ok(Node::Call(fun, Box::new(e)))
            }
            Some(Tok::Of) => fail("INVALID_EXPRESSION", "Unexpected 'of'"),
            Some(_) => fail("INVALID_EXPRESSION", "Unexpected symbol"),
        }
    }
}

// ---------------------------------------------------------------- evaluator

fn finite(v: f64) -> Res<f64> {
    if v.is_nan() {
        fail("DOMAIN_ERROR", "The result is not a number")
    } else if v.is_infinite() {
        fail("OVERFLOW", "The result is too large")
    } else {
        Ok(v)
    }
}

fn power(b: f64, e: f64) -> Res<f64> {
    if b == 0.0 {
        if e == 0.0 {
            return fail("UNDEFINED", "0^0 is undefined");
        }
        if e < 0.0 {
            return fail("DIV_BY_ZERO", "Zero cannot be raised to a negative power");
        }
    }
    if b < 0.0 && e.fract() != 0.0 {
        return fail("DOMAIN_ERROR", "A negative number cannot have a fractional power");
    }
    finite(b.powf(e))
}

fn eval(n: &Node, ans: f64) -> Res<f64> {
    match n {
        Node::Num(v) => Ok(*v),
        Node::Ans => Ok(ans),
        Node::Neg(a) => Ok(-eval(a, ans)?),
        Node::Pos(a) | Node::Group(a) => eval(a, ans),
        Node::Pct(a) => finite(eval(a, ans)? / 100.0),
        Node::Call(Fun::Sqrt, a) => {
            let v = eval(a, ans)?;
            if v < 0.0 {
                return fail("DOMAIN_ERROR", "Cannot take the square root of a negative number");
            }
            Ok(v.sqrt())
        }
        Node::Call(Fun::Abs, a) => Ok(eval(a, ans)?.abs()),
        Node::Bin(op, l, r) => {
            let lv = eval(l, ans)?;
            // Spec §3.4: a % that is the DIRECT right operand of + or - is relative to the left.
            let rv = match (*op, &**r) {
                (Op::Add | Op::Sub, Node::Pct(inner)) => finite(lv * eval(inner, ans)? / 100.0)?,
                _ => eval(r, ans)?,
            };
            match op {
                Op::Add => finite(lv + rv),
                Op::Sub => finite(lv - rv),
                Op::Mul => finite(lv * rv),
                Op::Div => {
                    if rv == 0.0 {
                        return fail("DIV_BY_ZERO", "Cannot divide by zero");
                    }
                    finite(lv / rv)
                }
                Op::Pow => power(lv, rv),
            }
        }
    }
}

// ---------------------------------------------------------------- session

/// One Standard Calculator session. `ans` changes only after a fully successful evaluation.
#[derive(Default)]
pub struct Calculator {
    ans: f64,
}

impl Calculator {
    pub fn new() -> Self {
        Calculator { ans: 0.0 }
    }

    /// Evaluate one line and return the formatted result.
    pub fn evaluate(&mut self, line: &str) -> Res<String> {
        let text = line.trim();
        if text.is_empty() {
            return fail("INVALID_EXPRESSION", "Nothing to calculate");
        }
        if text.chars().count() > 20_000 {
            return fail("INVALID_EXPRESSION", "The expression is too long");
        }
        let mut parser = Parser { t: tokenize(text)?, p: 0 };
        let tree = parser.expr()?;
        if parser.p < parser.t.len() {
            return fail("INVALID_EXPRESSION", "Unexpected symbol"); // e.g. 2(3), 2 3
        }
        let value = eval(&tree, self.ans)?;
        let shown = format_number(value)?;
        self.ans = value;
        Ok(shown)
    }
}