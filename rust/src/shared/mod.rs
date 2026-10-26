pub mod errors;
pub mod format_number;

pub use errors::{fail, ArithmosError, Res};
pub use format_number::format_number;