//! The only layer that does I/O.
pub mod io;
pub mod keys;
pub mod pick;
pub mod selector;
pub mod terminal;
pub mod tools;

mod oneshot;
pub use oneshot::{one_shot, OneShot};