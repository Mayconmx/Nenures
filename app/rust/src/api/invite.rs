use flutter_rust_bridge::frb;
use openmls_rust_crypto::OpenMlsRustCrypto;
use openmls_traits::OpenMlsProvider;
use openmls_traits::random::OpenMlsRand;
use zeroize::Zeroize;

use crate::error::CoreError;
use crate::invite::{self, InviteSecret, SECRET_BYTES};

/// Gera um convite novo: 88 bits do CSPRNG -> 8 palavras.
pub fn generate_invite_words() -> Result<Vec<String>, CoreError> {
    let provider = OpenMlsRustCrypto::default();
    let mut bytes = provider
        .rand()
        .random_vec(SECRET_BYTES)
        .map_err(|_| CoreError::Internal)?;
    let mut secret = InviteSecret([0; SECRET_BYTES]);
    secret.0.copy_from_slice(&bytes);
    bytes.zeroize();
    Ok(invite::secret_to_words(&secret))
}

/// Confere se as palavras formam um convite válido (contagem e lista).
/// Aceita os 4 primeiros caracteres de cada palavra.
#[frb(sync)]
pub fn check_invite_words(words: Vec<String>) -> Result<Vec<String>, CoreError> {
    let secret = invite::words_to_secret(&words)?;
    // Devolve a forma canônica (palavras completas), para o QR e a interface.
    Ok(invite::secret_to_words(&secret))
}
