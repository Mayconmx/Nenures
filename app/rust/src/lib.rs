//! nenures_core: criptografia do Nenures (MLS via OpenMLS + convite).
//!
//! Nenhuma primitiva própria: MLS é o OpenMLS; Argon2id, HKDF e
//! ChaCha20-Poly1305 são crates RustCrypto. Nada é gravado em disco
//! (OpenMlsRustCrypto usa armazenamento em memória).

pub mod api;
pub mod error;
mod frb_generated;
pub mod invite;
