use std::fmt;

/// An error with one of the spec §2.2 codes. Tests assert the code, never the message.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ArithmosError {
    pub code: &'static str,
    pub message: String,
}

impl ArithmosError {
    pub fn new(code: &'static str, message: impl Into<String>) -> Self {
        ArithmosError { code, message: message.into() }
    }
}

/// Displays as `Error [CODE]: message`, the line the CLI prints.
impl fmt::Display for ArithmosError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Error [{}]: {}", self.code, self.message)
    }
}

impl std::error::Error for ArithmosError {}

pub type Res<T> = Result<T, ArithmosError>;

/// Shorthand: `return fail("DIV_BY_ZERO", "Cannot divide by zero");`
pub fn fail<T>(code: &'static str, message: impl Into<String>) -> Res<T> {
    Err(ArithmosError::new(code, message))
}