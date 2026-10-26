use super::errors::{fail, Res};

/// Spec §2.3: 12 significant digits, half away from zero, trailing zeros trimmed,
/// plain notation for 1e-6 <= |x| < 1e15, otherwise `<mantissa>e<sign><exponent>`.
///
/// Rust's `{:.60e}` prints the exact decimal expansion of the double (correctly rounded
/// at 61 digits), so the 13th digit decides the rounding: >= 5 rounds the magnitude up,
/// which is "half away from zero". Rust's own shorter formatting is not used.
pub fn format_number(x: f64) -> Res<String> {
    if x.is_nan() {
        return fail("INVALID_EXPRESSION", "Result is not a number");
    }
    if x.is_infinite() {
        return fail("OVERFLOW", "Result is too large to represent");
    }
    if x == 0.0 {
        return Ok("0".to_string()); // also covers -0
    }
    let neg = x < 0.0;
    let s = format!("{:.60e}", x.abs());
    let (mant, exp_text) = s.split_once('e').expect("exponent form");
    let mut exp: i32 = exp_text.parse().expect("exponent");
    let mut digits: Vec<u8> = mant.bytes().filter(|b| *b != b'.').map(|b| b - b'0').collect();

    // Round the digit string to 12 significant digits.
    let round_up = digits[12] >= 5;
    digits.truncate(12);
    if round_up {
        let mut i = 12;
        loop {
            if i == 0 {
                // 9.99999999999.. carried out of the first digit
                digits.insert(0, 1);
                digits.truncate(12);
                exp += 1;
                break;
            }
            i -= 1;
            if digits[i] == 9 {
                digits[i] = 0;
            } else {
                digits[i] += 1;
                break;
            }
        }
    }
    while digits.len() > 1 && *digits.last().unwrap() == 0 {
        digits.pop();
    }
    let ds: String = digits.iter().map(|d| (b'0' + d) as char).collect();

    let body = if (-6..15).contains(&exp) {
        if exp >= 0 {
            let e = exp as usize;
            if ds.len() <= e + 1 {
                format!("{}{}", ds, "0".repeat(e + 1 - ds.len()))
            } else {
                format!("{}.{}", &ds[..e + 1], &ds[e + 1..])
            }
        } else {
            format!("0.{}{}", "0".repeat((-exp - 1) as usize), ds)
        }
    } else {
        let m = if ds.len() > 1 { format!("{}.{}", &ds[..1], &ds[1..]) } else { ds.clone() };
        format!("{}e{}{}", m, if exp < 0 { '-' } else { '+' }, exp.abs())
    };
    Ok(if neg { format!("-{}", body) } else { body })
}