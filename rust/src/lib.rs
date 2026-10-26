//! Arithmos Release 1 (Rust edition).
//! Layers: cli -> {calculator, programmer, converter} -> shared.
//! Engines never read stdin or write stdout; they return `Err(ArithmosError)`.
pub mod calculator;
pub mod cli;
pub mod converter;
pub mod programmer;
pub mod shared;