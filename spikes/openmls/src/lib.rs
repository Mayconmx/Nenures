//! SPIKE TÉCNICO — NÃO É CÓDIGO DE PRODUÇÃO.
//!
//! Serve só para gerar evidência para a decisão D1 (OpenMLS) e para os itens
//! S1–S6 de docs/revisao-seguranca.md. Não é ligado ao app nem ao servidor.
//! O código de produção será escrito na Fase 5, a partir das conclusões daqui.
//!
//! Protocolo exercitado (revisao-seguranca.md, seção 4):
//! - convite de 88 bits -> Argon2id -> HKDF -> (room_id, adm_key);
//! - pedido de entrada = AEAD(adm_key, KeyPackage);
//! - grupo MLS com a ciphersuite 0x0003, mensagens só cifradas.

use argon2::{Algorithm, Argon2, Params, Version};
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use hkdf::Hkdf;
use openmls::prelude::tls_codec::{Deserialize, Serialize};
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_rust_crypto::OpenMlsRustCrypto;
use openmls_traits::random::OpenMlsRand;
use sha2::Sha256;

/// D3: X25519 + ChaCha20-Poly1305 + SHA-256 + Ed25519.
pub const CIPHERSUITE: Ciphersuite =
    Ciphersuite::MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519;

/// D4: 8 palavras de 11 bits = 88 bits = 11 bytes.
pub const INVITE_BYTES: usize = 11;

/// Salt fixo de domínio (16 bytes), justificado em revisao-seguranca.md 4.2.
const INVITE_SALT: &[u8; 16] = b"nenures/v1/conv.";

/// Parâmetros propostos para o Argon2id (a ajustar por medição no aparelho).
#[derive(Clone, Copy, Debug)]
pub struct KdfParams {
    pub m_kib: u32,
    pub t: u32,
    pub p: u32,
}

pub const KDF_PROPOSED: KdfParams = KdfParams { m_kib: 64 * 1024, t: 3, p: 1 };

/// Segredos derivados do convite. `adm_key` nunca sai do aparelho.
pub struct InviteSecrets {
    pub room_id: [u8; 32],
    pub adm_key: [u8; 32],
}

pub fn derive_invite(secret: &[u8; INVITE_BYTES], params: KdfParams) -> InviteSecrets {
    let argon = Argon2::new(
        Algorithm::Argon2id,
        Version::V0x13,
        Params::new(params.m_kib, params.t, params.p, Some(32)).expect("parâmetros Argon2"),
    );
    let mut k = [0u8; 32];
    argon
        .hash_password_into(secret, INVITE_SALT, &mut k)
        .expect("Argon2id");
    let hk = Hkdf::<Sha256>::new(None, &k);
    let mut room_id = [0u8; 32];
    let mut adm_key = [0u8; 32];
    hk.expand(b"nenures/v1/sala", &mut room_id).expect("HKDF");
    hk.expand(b"nenures/v1/admissao", &mut adm_key).expect("HKDF");
    InviteSecrets { room_id, adm_key }
}

const ADM_AD: &[u8] = b"nenures/v1/pedido";

/// Pedido de entrada: nonce (12 bytes) || AEAD(adm_key, KeyPackage).
pub fn seal_join_request(adm_key: &[u8; 32], nonce: [u8; 12], key_package: &[u8]) -> Vec<u8> {
    let aead = ChaCha20Poly1305::new(Key::from_slice(adm_key));
    let ct = aead
        .encrypt(Nonce::from_slice(&nonce), Payload { msg: key_package, aad: ADM_AD })
        .expect("AEAD");
    [nonce.as_slice(), &ct].concat()
}

pub fn open_join_request(adm_key: &[u8; 32], request: &[u8]) -> Option<Vec<u8>> {
    if request.len() < 12 + 16 {
        return None;
    }
    let (nonce, ct) = request.split_at(12);
    let aead = ChaCha20Poly1305::new(Key::from_slice(adm_key));
    aead.decrypt(Nonce::from_slice(nonce), Payload { msg: ct, aad: ADM_AD }).ok()
}

/// Um participante: provedor só em memória (OpenMlsRustCrypto usa MemoryStorage),
/// chave de assinatura nova por sessão e credencial básica aleatória (P1: sem identidade).
pub struct Participant {
    pub provider: OpenMlsRustCrypto,
    pub signer: SignatureKeyPair,
    pub credential: CredentialWithKey,
    pub group: Option<MlsGroup>,
}

impl Participant {
    pub fn new() -> Self {
        let provider = OpenMlsRustCrypto::default();
        let random_id = provider.rand().random_vec(16).expect("rand");
        let signer = SignatureKeyPair::new(CIPHERSUITE.signature_algorithm()).expect("assinatura");
        signer.store(provider.storage()).expect("guardar chave");
        let credential = CredentialWithKey {
            credential: BasicCredential::new(random_id).into(),
            signature_key: signer.to_public_vec().into(),
        };
        Self { provider, signer, credential, group: None }
    }

    pub fn random(&self, n: usize) -> Vec<u8> {
        self.provider.rand().random_vec(n).expect("rand")
    }

    pub fn create_group(&mut self) {
        let config = MlsGroupCreateConfig::builder()
            .ciphersuite(CIPHERSUITE)
            .wire_format_policy(PURE_CIPHERTEXT_WIRE_FORMAT_POLICY)
            .use_ratchet_tree_extension(true)
            .max_past_epochs(2)
            .build();
        let group = MlsGroup::new(&self.provider, &self.signer, &config, self.credential.clone())
            .expect("criar grupo");
        self.group = Some(group);
    }

    /// KeyPackage serializado, com validade curta (anti-replay, revisao-seguranca.md 4.3).
    pub fn key_package_bytes(&self, lifetime_secs: u64) -> Vec<u8> {
        let bundle = KeyPackage::builder()
            .key_package_lifetime(Lifetime::new(lifetime_secs))
            .build(CIPHERSUITE, &self.provider, &self.signer, self.credential.clone())
            .expect("KeyPackage");
        bundle.key_package().tls_serialize_detached().expect("serializar")
    }

    pub fn group(&mut self) -> &mut MlsGroup {
        self.group.as_mut().expect("sem grupo")
    }

    pub fn members(&self) -> usize {
        self.group.as_ref().map(|g| g.members().count()).unwrap_or(0)
    }

    pub fn epoch(&self) -> u64 {
        self.group.as_ref().expect("sem grupo").epoch().as_u64()
    }

    /// Valida um KeyPackage recebido e cria Commit(Add) + Welcome.
    /// Retorna (commit, welcome) serializados.
    pub fn add_from_key_package(&mut self, kp_bytes: &[u8]) -> Result<(Vec<u8>, Vec<u8>), String> {
        let kp_in = KeyPackageIn::tls_deserialize_exact(kp_bytes).map_err(|e| e.to_string())?;
        let kp = kp_in
            .validate(self.provider.crypto(), ProtocolVersion::Mls10)
            .map_err(|e| e.to_string())?;
        let provider = &self.provider;
        let signer = &self.signer;
        let group = self.group.as_mut().expect("sem grupo");
        let (commit, welcome, _info) = group
            .add_members(provider, signer, core::slice::from_ref(&kp))
            .map_err(|e| e.to_string())?;
        Ok((
            commit.tls_serialize_detached().expect("serializar"),
            welcome.tls_serialize_detached().expect("serializar"),
        ))
    }

    /// Confirma o próprio commit depois que o "servidor" o aceitou.
    pub fn merge_own_commit(&mut self) {
        let provider = &self.provider;
        self.group.as_mut().expect("sem grupo").merge_pending_commit(provider).expect("merge");
    }

    /// Descarta o próprio commit quando o servidor aceitou outro na mesma época.
    pub fn discard_own_commit(&mut self) {
        let provider = &self.provider;
        self.group
            .as_mut()
            .expect("sem grupo")
            .clear_pending_commit(provider.storage())
            .expect("descartar");
    }

    pub fn join_from_welcome(&mut self, welcome_bytes: &[u8]) -> Result<(), String> {
        let msg = MlsMessageIn::tls_deserialize_exact(welcome_bytes).map_err(|e| e.to_string())?;
        let MlsMessageBodyIn::Welcome(welcome) = msg.extract() else {
            return Err("não é Welcome".into());
        };
        let config = MlsGroupJoinConfig::builder()
            .wire_format_policy(PURE_CIPHERTEXT_WIRE_FORMAT_POLICY)
            .use_ratchet_tree_extension(true)
            .max_past_epochs(2)
            .build();
        let group = StagedWelcome::new_from_welcome(&self.provider, &config, welcome, None)
            .map_err(|e| e.to_string())?
            .into_group(&self.provider)
            .map_err(|e| e.to_string())?;
        self.group = Some(group);
        Ok(())
    }

    pub fn send(&mut self, text: &[u8]) -> Vec<u8> {
        let provider = &self.provider;
        let signer = &self.signer;
        self.group
            .as_mut()
            .expect("sem grupo")
            .create_message(provider, signer, text)
            .expect("cifrar")
            .tls_serialize_detached()
            .expect("serializar")
    }

    /// Commit que só atualiza a própria folha (gera concorrência nos testes).
    pub fn self_update(&mut self) -> Vec<u8> {
        let provider = &self.provider;
        let signer = &self.signer;
        let bundle = self
            .group
            .as_mut()
            .expect("sem grupo")
            .self_update(provider, signer, LeafNodeParameters::default())
            .expect("self update");
        bundle.into_contents().0.tls_serialize_detached().expect("serializar")
    }

    /// "Encerrar": proposta de remoção da própria folha.
    pub fn leave(&mut self) -> Vec<u8> {
        let provider = &self.provider;
        let signer = &self.signer;
        self.group
            .as_mut()
            .expect("sem grupo")
            .leave_group(provider, signer)
            .expect("sair")
            .tls_serialize_detached()
            .expect("serializar")
    }

    /// Commit das propostas pendentes (por exemplo, a saída de alguém).
    pub fn commit_pending(&mut self) -> Vec<u8> {
        let provider = &self.provider;
        let signer = &self.signer;
        let (commit, _w, _i) = self
            .group
            .as_mut()
            .expect("sem grupo")
            .commit_to_pending_proposals(provider, signer)
            .expect("commit");
        commit.tls_serialize_detached().expect("serializar")
    }

    pub fn is_active(&self) -> bool {
        self.group.as_ref().map(|g| g.is_active()).unwrap_or(false)
    }

    pub fn epoch_authenticator(&self) -> Vec<u8> {
        self.group.as_ref().expect("sem grupo").epoch_authenticator().as_slice().to_vec()
    }

    /// Processa uma mensagem recebida do "servidor".
    pub fn receive(&mut self, bytes: &[u8]) -> Result<Received, String> {
        let msg = MlsMessageIn::tls_deserialize_exact(bytes).map_err(|e| e.to_string())?;
        let protocol = msg.try_into_protocol_message().map_err(|e| e.to_string())?;
        let provider = &self.provider;
        let group = self.group.as_mut().ok_or("sem grupo")?;
        let processed = group.process_message(provider, protocol).map_err(|e| e.to_string())?;
        match processed.into_content() {
            ProcessedMessageContent::ApplicationMessage(m) => Ok(Received::Text(m.into_bytes())),
            ProcessedMessageContent::ProposalMessage(p) => {
                group.store_pending_proposal(provider.storage(), *p).map_err(|e| e.to_string())?;
                Ok(Received::Proposal)
            }
            ProcessedMessageContent::StagedCommitMessage(c) => {
                let removed_self = c.self_removed();
                group.merge_staged_commit(provider, *c).map_err(|e| e.to_string())?;
                Ok(if removed_self { Received::RemovedSelf } else { Received::Commit })
            }
            _ => Ok(Received::Other),
        }
    }
}

impl Default for Participant {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, PartialEq)]
pub enum Received {
    Text(Vec<u8>),
    Proposal,
    Commit,
    RemovedSelf,
    Other,
}

pub use openmls::treesync::LeafNodeParameters;
