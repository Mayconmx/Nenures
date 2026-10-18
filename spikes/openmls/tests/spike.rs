//! Cenários do spike (S1–S6 de docs/revisao-seguranca.md e ameaças T1–T8).
//! Rodar com: cargo test --release -- --nocapture --test-threads=1

use std::time::Instant;

use nenures_spike::*;

/// "Servidor" de teste: aceita um commit por época, como o Delivery Service proposto.
struct Relay {
    accepted_epoch: Option<u64>,
}

impl Relay {
    fn new() -> Self {
        Self { accepted_epoch: None }
    }
    /// true se o commit da época `epoch` for o primeiro.
    fn accept_commit(&mut self, epoch: u64) -> bool {
        if self.accepted_epoch == Some(epoch) {
            return false;
        }
        self.accepted_epoch = Some(epoch);
        true
    }
}

fn invite_secret(p: &Participant) -> [u8; INVITE_BYTES] {
    p.random(INVITE_BYTES).try_into().unwrap()
}

/// Leve, para os testes funcionais. A medição usa KDF_PROPOSED.
const KDF_FAST: KdfParams = KdfParams { m_kib: 1024, t: 1, p: 1 };

/// Fluxo de entrada completo: quem entra sela o KeyPackage; o membro designado
/// abre, valida e adiciona; todos processam o commit; quem entra usa o Welcome.
fn admit(
    adm_key_joiner: &[u8; 32],
    adm_key_member: &[u8; 32],
    joiner: &mut Participant,
    committer: &mut Participant,
    others: &mut [&mut Participant],
) -> Result<(), String> {
    let nonce: [u8; 12] = joiner.random(12).try_into().unwrap();
    let request = seal_join_request(adm_key_joiner, nonce, &joiner.key_package_bytes(300));
    let kp = open_join_request(adm_key_member, &request).ok_or("pedido recusado: chave de admissão errada")?;
    let (commit, welcome) = committer.add_from_key_package(&kp)?;
    committer.merge_own_commit();
    for o in others.iter_mut() {
        assert_eq!(o.receive(&commit)?, Received::Commit);
    }
    joiner.join_from_welcome(&welcome)
}

#[test]
fn convite_deriva_os_mesmos_segredos_e_separa_finalidades() {
    let p = Participant::new();
    let s = invite_secret(&p);
    let a = derive_invite(&s, KDF_FAST);
    let b = derive_invite(&s, KDF_FAST);
    assert_eq!(a.room_id, b.room_id);
    assert_eq!(a.adm_key, b.adm_key);
    assert_ne!(a.room_id, a.adm_key, "finalidades diferentes, chaves diferentes");
    let mut other = s;
    other[0] ^= 1;
    assert_ne!(derive_invite(&other, KDF_FAST).room_id, a.room_id);
}

#[test]
fn entrada_mensagens_e_presenca_validada() {
    let mut alice = Participant::new();
    let mut bob = Participant::new();
    let mut carol = Participant::new();
    let inv = derive_invite(&invite_secret(&alice), KDF_FAST);

    alice.create_group();
    assert_eq!(alice.members(), 1);

    admit(&inv.adm_key, &inv.adm_key, &mut bob, &mut alice, &mut []).unwrap();
    assert_eq!((alice.members(), bob.members()), (2, 2));

    admit(&inv.adm_key, &inv.adm_key, &mut carol, &mut alice, &mut [&mut bob]).unwrap();
    assert_eq!((alice.members(), bob.members(), carol.members()), (3, 3, 3));
    assert_eq!(alice.epoch_authenticator(), carol.epoch_authenticator());

    let m = carol.send(b"oi");
    assert_eq!(alice.receive(&m).unwrap(), Received::Text(b"oi".to_vec()));
    assert_eq!(bob.receive(&m).unwrap(), Received::Text(b"oi".to_vec()));
}

#[test]
fn servidor_sem_o_convite_nao_consegue_pedir_entrada() {
    let mut alice = Participant::new();
    let mut intruder = Participant::new();
    let inv = derive_invite(&invite_secret(&alice), KDF_FAST);
    alice.create_group();
    let wrong = derive_invite(&invite_secret(&intruder), KDF_FAST);
    let err = admit(&wrong.adm_key, &inv.adm_key, &mut intruder, &mut alice, &mut []).unwrap_err();
    assert!(err.contains("recusado"));
    assert_eq!(alice.members(), 1);
}

#[test]
fn mensagem_adulterada_e_rejeitada() {
    let (mut alice, mut bob) = pair();
    let mut m = alice.send(b"original");
    let last = m.len() - 1;
    m[last] ^= 0x01;
    assert!(bob.receive(&m).is_err());
}

#[test]
fn mensagem_repetida_e_rejeitada() {
    let (mut alice, mut bob) = pair();
    let m = alice.send(b"uma vez");
    assert!(bob.receive(&m).is_ok());
    assert!(bob.receive(&m).is_err(), "replay precisa falhar");
}

#[test]
fn mensagens_fora_de_ordem_dentro_da_tolerancia() {
    let (mut alice, mut bob) = pair();
    let m1 = alice.send(b"1");
    let m2 = alice.send(b"2");
    assert_eq!(bob.receive(&m2).unwrap(), Received::Text(b"2".to_vec()));
    assert_eq!(bob.receive(&m1).unwrap(), Received::Text(b"1".to_vec()));
}

#[test]
fn commits_concorrentes_servidor_aceita_um_e_o_outro_descarta() {
    let (mut alice, mut bob) = pair();
    let mut relay = Relay::new();
    let epoch = alice.epoch();

    let ca = alice.self_update();
    let cb = bob.self_update();
    assert!(relay.accept_commit(epoch), "primeiro commit aceito");
    assert!(!relay.accept_commit(epoch), "segundo commit da mesma época recusado");

    alice.merge_own_commit();
    bob.discard_own_commit();
    assert_eq!(bob.receive(&ca).unwrap(), Received::Commit);
    assert_eq!(alice.epoch(), bob.epoch());
    assert_eq!(alice.epoch_authenticator(), bob.epoch_authenticator());
    drop(cb);

    let m = bob.send(b"seguimos juntos");
    assert_eq!(alice.receive(&m).unwrap(), Received::Text(b"seguimos juntos".to_vec()));
}

#[test]
fn encerrar_remove_a_folha_e_protege_mensagens_futuras() {
    let mut alice = Participant::new();
    let mut bob = Participant::new();
    let mut carol = Participant::new();
    let inv = derive_invite(&invite_secret(&alice), KDF_FAST);
    alice.create_group();
    admit(&inv.adm_key, &inv.adm_key, &mut bob, &mut alice, &mut []).unwrap();
    admit(&inv.adm_key, &inv.adm_key, &mut carol, &mut alice, &mut [&mut bob]).unwrap();

    // Carol toca em Encerrar: proposta de saída; Alice (menor folha) faz o commit.
    let proposal = carol.leave();
    assert_eq!(alice.receive(&proposal).unwrap(), Received::Proposal);
    assert_eq!(bob.receive(&proposal).unwrap(), Received::Proposal);
    let commit = alice.commit_pending();
    alice.merge_own_commit();
    assert_eq!(bob.receive(&commit).unwrap(), Received::Commit);
    assert_eq!(carol.receive(&commit).unwrap(), Received::RemovedSelf);
    assert!(!carol.is_active());
    assert_eq!((alice.members(), bob.members()), (2, 2));

    // Mensagem nova não é legível por quem saiu.
    let m = alice.send(b"depois da saida");
    assert!(carol.receive(&m).is_err());
    assert_eq!(bob.receive(&m).unwrap(), Received::Text(b"depois da saida".to_vec()));
}

#[test]
fn quem_entrou_depois_nao_le_mensagens_anteriores() {
    let (mut alice, mut bob) = pair();
    let antiga = alice.send(b"antes");
    let mut carol = Participant::new();
    let inv = derive_invite(&invite_secret(&alice), KDF_FAST);
    admit(&inv.adm_key, &inv.adm_key, &mut carol, &mut alice, &mut [&mut bob]).unwrap();
    assert!(carol.receive(&antiga).is_err());
}

#[test]
fn medicao_de_tempos_no_aparelho_atual() {
    let p = Participant::new();
    let s = invite_secret(&p);
    let t = Instant::now();
    let _ = derive_invite(&s, KDF_PROPOSED);
    println!(
        "MEDICAO argon2id m={}KiB t={} p={}: {} ms",
        KDF_PROPOSED.m_kib,
        KDF_PROPOSED.t,
        KDF_PROPOSED.p,
        t.elapsed().as_millis()
    );

    let mut alice = Participant::new();
    alice.create_group();
    let inv = derive_invite(&s, KDF_FAST);
    let mut members = Vec::new();
    for n in 2..=25usize {
        let mut joiner = Participant::new();
        let t = Instant::now();
        let nonce: [u8; 12] = joiner.random(12).try_into().unwrap();
        let req = seal_join_request(&inv.adm_key, nonce, &joiner.key_package_bytes(300));
        let kp = open_join_request(&inv.adm_key, &req).unwrap();
        let (commit, welcome) = alice.add_from_key_package(&kp).unwrap();
        alice.merge_own_commit();
        let commit_ms = t.elapsed().as_micros() as f64 / 1000.0;
        let t = Instant::now();
        for m in members.iter_mut() {
            let m: &mut Participant = m;
            m.receive(&commit).unwrap();
        }
        let others_ms = t.elapsed().as_micros() as f64 / 1000.0;
        joiner.join_from_welcome(&welcome).unwrap();
        if [2, 10, 25].contains(&n) {
            println!(
                "MEDICAO n={n}: commit {:.1} ms, commit {} B, welcome {} B, processar nos outros {:.1} ms (total)",
                commit_ms,
                commit.len(),
                welcome.len(),
                others_ms
            );
        }
        members.push(joiner);
    }
    let t = Instant::now();
    let m = alice.send(&[b'x'; 1000]);
    let enc = t.elapsed().as_micros();
    println!("MEDICAO mensagem de 1000 caracteres: {} B cifrada, {} us para cifrar", m.len(), enc);
}

fn pair() -> (Participant, Participant) {
    let mut alice = Participant::new();
    let mut bob = Participant::new();
    let inv = derive_invite(&invite_secret(&alice), KDF_FAST);
    alice.create_group();
    admit(&inv.adm_key, &inv.adm_key, &mut bob, &mut alice, &mut []).unwrap();
    (alice, bob)
}
