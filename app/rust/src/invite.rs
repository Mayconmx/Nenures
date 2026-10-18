//! Convite (D4, D5): 88 bits aleatórios <-> 8 palavras; derivação de chaves.
//!
//! - O segredo vem do CSPRNG do provedor do OpenMLS (ChaCha20 semeado pelo SO).
//! - Os bits viram palavras diretamente (11 bits por palavra), sem módulo,
//!   então não há viés.
//! - Argon2id + HKDF separam o identificador da sala (vai ao servidor) da chave
//!   de admissão (nunca sai do aparelho). Revisão: docs/revisao-seguranca.md 4.2.

use argon2::{Algorithm, Argon2, Params, Version};
use hkdf::Hkdf;
use sha2::Sha256;
use std::sync::OnceLock;
use zeroize::{Zeroize, ZeroizeOnDrop};

use crate::error::CoreError;

pub const WORDS: usize = 8;
pub const SECRET_BYTES: usize = 11; // 8 x 11 bits = 88 bits
const BITS_PER_WORD: usize = 11;

const WORDLIST_TXT: &str = include_str!("wordlist-pt-v1.txt");

pub fn wordlist() -> &'static [&'static str] {
    static LIST: OnceLock<Vec<&'static str>> = OnceLock::new();
    LIST.get_or_init(|| {
        let v: Vec<&str> = WORDLIST_TXT.lines().filter(|l| !l.is_empty()).collect();
        assert_eq!(v.len(), 2048, "lista de palavras precisa ter 2048 entradas");
        v
    })
}

/// Segredo do convite; apagado da memória ao ser descartado.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct InviteSecret(pub [u8; SECRET_BYTES]);

/// Chaves derivadas; apagadas da memória ao serem descartadas.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct InviteKeys {
    pub room_id: [u8; 32],
    pub adm_key: [u8; 32],
}

pub fn secret_to_words(secret: &InviteSecret) -> Vec<String> {
    let list = wordlist();
    let mut acc: u32 = 0;
    let mut nbits = 0;
    let mut out = Vec::with_capacity(WORDS);
    for &byte in secret.0.iter() {
        acc = (acc << 8) | u32::from(byte);
        nbits += 8;
        while nbits >= BITS_PER_WORD {
            nbits -= BITS_PER_WORD;
            let idx = (acc >> nbits) & 0x7ff;
            out.push(list[idx as usize].to_string());
        }
        acc &= (1 << nbits) - 1;
    }
    debug_assert_eq!(out.len(), WORDS);
    out
}

/// Aceita a palavra inteira ou os 4 primeiros caracteres (únicos na lista).
fn word_index(word: &str) -> Option<usize> {
    let w = word.trim().to_ascii_lowercase();
    let list = wordlist();
    if let Some(i) = list.iter().position(|x| *x == w) {
        return Some(i);
    }
    if w.len() >= 4 {
        let mut found = None;
        for (i, x) in list.iter().enumerate() {
            if x.starts_with(&w) {
                if found.is_some() {
                    return None;
                }
                found = Some(i);
            }
        }
        return found;
    }
    None
}

pub fn words_to_secret(words: &[String]) -> Result<InviteSecret, CoreError> {
    if words.len() != WORDS {
        return Err(CoreError::InvalidInvite);
    }
    let mut out = [0u8; SECRET_BYTES];
    let mut acc: u32 = 0;
    let mut nbits = 0;
    let mut pos = 0;
    for w in words {
        let idx = word_index(w).ok_or(CoreError::InvalidInvite)? as u32;
        acc = (acc << BITS_PER_WORD) | idx;
        nbits += BITS_PER_WORD;
        while nbits >= 8 {
            nbits -= 8;
            out[pos] = (acc >> nbits) as u8;
            pos += 1;
        }
        acc &= (1 << nbits) - 1;
    }
    acc.zeroize();
    Ok(InviteSecret(out))
}

/// Parâmetros do Argon2id (D4). A ajustar por medição no aparelho de referência.
#[derive(Clone, Copy, Debug)]
pub struct KdfParams {
    pub m_kib: u32,
    pub t: u32,
    pub p: u32,
}

pub const KDF: KdfParams = KdfParams {
    m_kib: 64 * 1024,
    t: 3,
    p: 1,
};

/// Salt fixo de domínio (16 bytes). Justificativa: revisao-seguranca.md 4.2.
const SALT: &[u8; 16] = b"nenures/v1/conv.";

pub fn derive_keys(secret: &InviteSecret, params: KdfParams) -> InviteKeys {
    let argon = Argon2::new(
        Algorithm::Argon2id,
        Version::V0x13,
        Params::new(params.m_kib, params.t, params.p, Some(32)).expect("parâmetros Argon2 válidos"),
    );
    let mut k = [0u8; 32];
    argon
        .hash_password_into(&secret.0, SALT, &mut k)
        .expect("Argon2id com parâmetros válidos");
    let hk = Hkdf::<Sha256>::new(None, &k);
    let mut keys = InviteKeys {
        room_id: [0; 32],
        adm_key: [0; 32],
    };
    hk.expand(b"nenures/v1/sala", &mut keys.room_id)
        .expect("HKDF 32 bytes");
    hk.expand(b"nenures/v1/admissao", &mut keys.adm_key)
        .expect("HKDF 32 bytes");
    k.zeroize();
    keys
}
