//! Sessão MLS de uma conversa. Tudo que é segredo fica aqui dentro: o Dart só
//! recebe bytes cifrados para enviar ao servidor, texto já decifrado e
//! informações públicas do grupo (época, folhas).
//!
//! Protocolo: docs/revisao-seguranca.md, seção 4, e docs/protocolo.md.

use std::collections::HashSet;

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use flutter_rust_bridge::frb;
use openmls::prelude::tls_codec::{Deserialize, Serialize};
use openmls::prelude::*;
use openmls::treesync::LeafNodeParameters;
use openmls_basic_credential::SignatureKeyPair;
use openmls_rust_crypto::OpenMlsRustCrypto;
use openmls_traits::random::OpenMlsRand;

use crate::error::CoreError;
use crate::invite::{self, InviteKeys, KDF};

/// D3: X25519 + ChaCha20-Poly1305 + SHA-256 + Ed25519.
const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519;
const MAX_TEXT_CHARS: usize = 1000;
const KEY_PACKAGE_LIFETIME_SECS: u64 = 300;
const ADM_AD: &[u8] = b"nenures/v1/pedido";

// Formato das mensagens de aplicação (dentro do MLS): 1 byte de tipo + conteúdo.
const KIND_TEXT: u8 = 1;
const KIND_LOCK: u8 = 2;

/// Informação pública do grupo, para a interface e para escolher quem faz commits.
pub struct GroupView {
    pub epoch: u64,
    /// Número de folhas ocupadas: o contador de pessoas validado (4.6).
    pub members: u32,
    pub own_leaf: u32,
    /// Índices de todas as folhas ocupadas.
    pub leaves: Vec<u32>,
    pub active: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IncomingKind {
    /// Texto de outra pessoa (em `text`).
    Text,
    /// Alguém trancou a entrada (D7).
    Lock,
    /// Proposta guardada (ex.: alguém tocou em Encerrar); falta o commit.
    Proposal,
    /// Commit processado; o grupo mudou (ver `view`).
    Commit,
    /// Este aparelho foi removido do grupo.
    RemovedSelf,
}

pub struct Incoming {
    pub kind: IncomingKind,
    pub text: Option<String>,
    pub view: GroupView,
}

/// Resultado de aceitar um pedido de entrada: enviar `commit` + `welcome`.
pub struct AddOutcome {
    pub commit: Vec<u8>,
    pub welcome: Vec<u8>,
}

#[frb(opaque)]
pub struct Session {
    provider: OpenMlsRustCrypto,
    signer: SignatureKeyPair,
    credential: CredentialWithKey,
    keys: InviteKeys,
    group: Option<MlsGroup>,
    seen_key_packages: HashSet<Vec<u8>>,
    /// KeyPackage do commit de entrada ainda não confirmado pelo servidor.
    pending_key_package: Option<Vec<u8>>,
}

fn internal<E>(_: E) -> CoreError {
    CoreError::Internal
}

fn invalid<E>(_: E) -> CoreError {
    CoreError::InvalidMessage
}

impl Session {
    fn new(words: &[String]) -> Result<Self, CoreError> {
        let secret = invite::words_to_secret(words)?;
        let keys = invite::derive_keys(&secret, KDF);
        let provider = OpenMlsRustCrypto::default();
        // P1: credencial sem identidade, 16 bytes aleatórios por sessão.
        let random_id = provider.rand().random_vec(16).map_err(internal)?;
        let signer = SignatureKeyPair::new(CIPHERSUITE.signature_algorithm()).map_err(internal)?;
        signer.store(provider.storage()).map_err(internal)?;
        let credential = CredentialWithKey {
            credential: BasicCredential::new(random_id).into(),
            signature_key: signer.to_public_vec().into(),
        };
        Ok(Self {
            provider,
            signer,
            credential,
            keys,
            group: None,
            seen_key_packages: HashSet::new(),
            pending_key_package: None,
        })
    }

    /// Quem gera a chave: deriva os segredos e cria o grupo (época 0).
    pub fn create(words: Vec<String>) -> Result<Session, CoreError> {
        let mut s = Self::new(&words)?;
        let config = MlsGroupCreateConfig::builder()
            .ciphersuite(CIPHERSUITE)
            .wire_format_policy(PURE_CIPHERTEXT_WIRE_FORMAT_POLICY)
            .use_ratchet_tree_extension(true)
            .max_past_epochs(2)
            .build();
        let group = MlsGroup::new(&s.provider, &s.signer, &config, s.credential.clone())
            .map_err(internal)?;
        s.group = Some(group);
        Ok(s)
    }

    /// Quem entra com a chave: deriva os segredos; o grupo vem pelo Welcome.
    pub fn prepare_join(words: Vec<String>) -> Result<Session, CoreError> {
        Self::new(&words)
    }

    /// Identificador da sala para o servidor (não revela o convite).
    #[frb(sync)]
    pub fn room_id(&self) -> Vec<u8> {
        self.keys.room_id.to_vec()
    }

    /// Pedido de entrada: nonce (12) || AEAD(adm_key, KeyPackage).
    pub fn join_request(&mut self) -> Result<Vec<u8>, CoreError> {
        let bundle = KeyPackage::builder()
            .key_package_lifetime(Lifetime::new(KEY_PACKAGE_LIFETIME_SECS))
            .build(
                CIPHERSUITE,
                &self.provider,
                &self.signer,
                self.credential.clone(),
            )
            .map_err(internal)?;
        let kp = bundle
            .key_package()
            .tls_serialize_detached()
            .map_err(internal)?;
        let nonce = self.provider.rand().random_vec(12).map_err(internal)?;
        let aead = ChaCha20Poly1305::new(Key::from_slice(&self.keys.adm_key));
        let ct = aead
            .encrypt(
                Nonce::from_slice(&nonce),
                Payload {
                    msg: &kp,
                    aad: ADM_AD,
                },
            )
            .map_err(internal)?;
        Ok([nonce.as_slice(), &ct].concat())
    }

    /// Membro designado: abre o pedido, valida o KeyPackage e cria Commit(Add) + Welcome.
    /// O commit fica pendente até o servidor aceitar (confirm_own_commit).
    pub fn handle_join_request(&mut self, request: Vec<u8>) -> Result<AddOutcome, CoreError> {
        if request.len() < 12 + 16 {
            return Err(CoreError::WrongInvite);
        }
        let (nonce, ct) = request.split_at(12);
        let aead = ChaCha20Poly1305::new(Key::from_slice(&self.keys.adm_key));
        let kp_bytes = aead
            .decrypt(
                Nonce::from_slice(nonce),
                Payload {
                    msg: ct,
                    aad: ADM_AD,
                },
            )
            .map_err(|_| CoreError::WrongInvite)?;
        // Anti-replay: o mesmo KeyPackage não entra duas vezes (revisao-seguranca.md 4.3).
        // Só vira "visto" quando o commit é confirmado: se o servidor recusar o
        // commit (outro venceu a época), o mesmo pedido pode ser tentado de novo.
        if self.seen_key_packages.contains(&kp_bytes) {
            return Err(CoreError::InvalidMessage);
        }
        let kp = KeyPackageIn::tls_deserialize_exact(&kp_bytes)
            .map_err(invalid)?
            .validate(self.provider.crypto(), ProtocolVersion::Mls10)
            .map_err(invalid)?;
        let (provider, signer) = (&self.provider, &self.signer);
        let group = self.group.as_mut().ok_or(CoreError::NotReady)?;
        let (commit, welcome, _info) = group
            .add_members(provider, signer, core::slice::from_ref(&kp))
            .map_err(internal)?;
        self.pending_key_package = Some(kp_bytes);
        Ok(AddOutcome {
            commit: commit.tls_serialize_detached().map_err(internal)?,
            welcome: welcome.tls_serialize_detached().map_err(internal)?,
        })
    }

    pub fn accept_welcome(&mut self, welcome: Vec<u8>) -> Result<GroupView, CoreError> {
        let msg = MlsMessageIn::tls_deserialize_exact(&welcome).map_err(invalid)?;
        let MlsMessageBodyIn::Welcome(w) = msg.extract() else {
            return Err(CoreError::InvalidMessage);
        };
        let config = MlsGroupJoinConfig::builder()
            .wire_format_policy(PURE_CIPHERTEXT_WIRE_FORMAT_POLICY)
            .use_ratchet_tree_extension(true)
            .max_past_epochs(2)
            .build();
        let group = StagedWelcome::new_from_welcome(&self.provider, &config, w, None)
            .map_err(invalid)?
            .into_group(&self.provider)
            .map_err(invalid)?;
        self.group = Some(group);
        Ok(self.view())
    }

    /// O servidor aceitou o commit deste aparelho.
    pub fn confirm_own_commit(&mut self) -> Result<GroupView, CoreError> {
        let provider = &self.provider;
        self.group
            .as_mut()
            .ok_or(CoreError::NotReady)?
            .merge_pending_commit(provider)
            .map_err(internal)?;
        if let Some(kp) = self.pending_key_package.take() {
            self.seen_key_packages.insert(kp);
        }
        Ok(self.view())
    }

    /// O servidor recusou o commit (outro venceu na mesma época).
    pub fn discard_own_commit(&mut self) -> Result<(), CoreError> {
        let provider = &self.provider;
        self.pending_key_package = None;
        self.group
            .as_mut()
            .ok_or(CoreError::NotReady)?
            .clear_pending_commit(provider.storage())
            .map_err(internal)
    }

    fn encrypt_app(&mut self, payload: &[u8]) -> Result<Vec<u8>, CoreError> {
        let (provider, signer) = (&self.provider, &self.signer);
        let group = self.group.as_mut().ok_or(CoreError::NotReady)?;
        group
            .create_message(provider, signer, payload)
            .map_err(internal)?
            .tls_serialize_detached()
            .map_err(internal)
    }

    pub fn encrypt_text(&mut self, text: String) -> Result<Vec<u8>, CoreError> {
        let n = text.chars().count();
        if n == 0 {
            return Err(CoreError::InvalidMessage);
        }
        if n > MAX_TEXT_CHARS {
            return Err(CoreError::TooLong);
        }
        let mut payload = Vec::with_capacity(1 + text.len());
        payload.push(KIND_TEXT);
        payload.extend_from_slice(text.as_bytes());
        self.encrypt_app(&payload)
    }

    /// "Trancar entrada" (D7), avisado a todos dentro do MLS.
    pub fn encrypt_lock(&mut self) -> Result<Vec<u8>, CoreError> {
        self.encrypt_app(&[KIND_LOCK])
    }

    /// Processa qualquer mensagem MLS recebida do servidor (msg, commit, proposal).
    pub fn process(&mut self, message: Vec<u8>) -> Result<Incoming, CoreError> {
        let msg = MlsMessageIn::tls_deserialize_exact(&message).map_err(invalid)?;
        let protocol = msg.try_into_protocol_message().map_err(invalid)?;
        let provider = &self.provider;
        let group = self.group.as_mut().ok_or(CoreError::NotReady)?;
        let processed = group.process_message(provider, protocol).map_err(invalid)?;
        let (kind, text) = match processed.into_content() {
            ProcessedMessageContent::ApplicationMessage(m) => parse_app(&m.into_bytes())?,
            ProcessedMessageContent::ProposalMessage(p) => {
                group
                    .store_pending_proposal(provider.storage(), *p)
                    .map_err(internal)?;
                (IncomingKind::Proposal, None)
            }
            ProcessedMessageContent::StagedCommitMessage(c) => {
                let removed = c.self_removed();
                group.merge_staged_commit(provider, *c).map_err(invalid)?;
                (
                    if removed {
                        IncomingKind::RemovedSelf
                    } else {
                        IncomingKind::Commit
                    },
                    None,
                )
            }
            _ => return Err(CoreError::InvalidMessage),
        };
        Ok(Incoming {
            kind,
            text,
            view: self.view(),
        })
    }

    /// Encerrar: proposta de remoção da própria folha (P6). Outro membro faz o commit.
    pub fn leave(&mut self) -> Result<Vec<u8>, CoreError> {
        let (provider, signer) = (&self.provider, &self.signer);
        self.group
            .as_mut()
            .ok_or(CoreError::NotReady)?
            .leave_group(provider, signer)
            .map_err(internal)?
            .tls_serialize_detached()
            .map_err(internal)
    }

    /// Commit das propostas pendentes (ex.: saídas). None se não houver nenhuma.
    pub fn commit_pending(&mut self) -> Result<Option<Vec<u8>>, CoreError> {
        let (provider, signer) = (&self.provider, &self.signer);
        let group = self.group.as_mut().ok_or(CoreError::NotReady)?;
        if group.pending_proposals().next().is_none() {
            return Ok(None);
        }
        let (commit, _w, _i) = group
            .commit_to_pending_proposals(provider, signer)
            .map_err(internal)?;
        Ok(Some(commit.tls_serialize_detached().map_err(internal)?))
    }

    /// Remove quem caiu e não voltou a tempo (o servidor avisou `gone`).
    pub fn remove_leaf(&mut self, leaf: u32) -> Result<Vec<u8>, CoreError> {
        let (provider, signer) = (&self.provider, &self.signer);
        let group = self.group.as_mut().ok_or(CoreError::NotReady)?;
        let idx = LeafNodeIndex::new(leaf);
        if group.member(idx).is_none() || idx == group.own_leaf_index() {
            return Err(CoreError::InvalidMessage);
        }
        let (commit, _w, _i) = group
            .remove_members(provider, signer, &[idx])
            .map_err(internal)?;
        commit.tls_serialize_detached().map_err(internal)
    }

    /// Atualiza a própria folha (gera uma época nova; usado nos testes de concorrência).
    pub fn self_update(&mut self) -> Result<Vec<u8>, CoreError> {
        let (provider, signer) = (&self.provider, &self.signer);
        let group = self.group.as_mut().ok_or(CoreError::NotReady)?;
        let bundle = group
            .self_update(provider, signer, LeafNodeParameters::default())
            .map_err(internal)?;
        bundle
            .into_contents()
            .0
            .tls_serialize_detached()
            .map_err(internal)
    }

    #[frb(sync)]
    pub fn view(&self) -> GroupView {
        match &self.group {
            None => GroupView {
                epoch: 0,
                members: 0,
                own_leaf: 0,
                leaves: vec![],
                active: false,
            },
            Some(g) => {
                let leaves: Vec<u32> = g.members().map(|m| m.index.u32()).collect();
                GroupView {
                    epoch: g.epoch().as_u64(),
                    members: leaves.len() as u32,
                    own_leaf: g.own_leaf_index().u32(),
                    leaves,
                    active: g.is_active(),
                }
            }
        }
    }

    /// Descarta o grupo e as chaves desta sessão (o resto é apagado no drop).
    pub fn close(&mut self) {
        self.group = None;
        self.seen_key_packages.clear();
        self.pending_key_package = None;
    }
}

fn parse_app(bytes: &[u8]) -> Result<(IncomingKind, Option<String>), CoreError> {
    match bytes.split_first() {
        Some((&KIND_TEXT, rest)) => {
            let text = std::str::from_utf8(rest).map_err(invalid)?;
            let n = text.chars().count();
            if n == 0 || n > MAX_TEXT_CHARS {
                return Err(CoreError::InvalidMessage);
            }
            Ok((IncomingKind::Text, Some(text.to_owned())))
        }
        Some((&KIND_LOCK, [])) => Ok((IncomingKind::Lock, None)),
        _ => Err(CoreError::InvalidMessage),
    }
}
