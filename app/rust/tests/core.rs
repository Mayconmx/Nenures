//! Testes da biblioteca nenures_core pela API pública (a mesma usada pelo Dart).
//! cargo test --release

use std::collections::HashSet;

use nenures_core::api::error::CoreError;
use nenures_core::api::invite::{check_invite_words, generate_invite_words};
use nenures_core::api::session::{IncomingKind, Session};
use nenures_core::invite::{self, InviteSecret, KdfParams};

// ---------------------------------------------------------------- lista de palavras (D5)

#[test]
fn lista_tem_as_propriedades_aprovadas() {
    let list = invite::wordlist();
    assert_eq!(list.len(), 2048);
    assert_eq!(list.iter().collect::<HashSet<_>>().len(), 2048);
    assert_eq!(
        list.iter().map(|w| &w[..4]).collect::<HashSet<_>>().len(),
        2048
    );
    for w in list {
        assert!((4..=8).contains(&w.len()), "{w}");
        assert!(w.bytes().all(|b| b.is_ascii_lowercase()), "{w}");
    }
    for bad in ["orgasmo", "macaco", "pistola", "baseado", "veado"] {
        assert!(
            !list.contains(&bad),
            "palavra removida na revisão voltou: {bad}"
        );
    }
}

// ---------------------------------------------------------------- convite (D4)

fn words(s: &str) -> Vec<String> {
    s.split_whitespace().map(String::from).collect()
}

#[test]
fn palavras_e_bits_vao_e_voltam() {
    let list = invite::wordlist();
    for seed in 0u8..=255 {
        let secret = InviteSecret([seed; 11]);
        let w = invite::secret_to_words(&secret);
        assert_eq!(w.len(), 8);
        assert!(w.iter().all(|x| list.contains(&x.as_str())));
        let back = invite::words_to_secret(&w).unwrap();
        assert_eq!(back.0, secret.0);
    }
    // Extremos: tudo zero e tudo um.
    assert_eq!(
        invite::secret_to_words(&InviteSecret([0; 11])),
        vec![list[0].to_string(); 8]
    );
    assert_eq!(
        invite::secret_to_words(&InviteSecret([0xff; 11])),
        vec![list[2047].to_string(); 8]
    );
}

#[test]
fn convites_gerados_sao_diferentes_e_validos() {
    let mut seen = HashSet::new();
    for _ in 0..2000 {
        let w = generate_invite_words().unwrap();
        assert_eq!(check_invite_words(w.clone()).unwrap(), w);
        assert!(seen.insert(w.join(" ")), "convite repetido");
    }
}

#[test]
fn distribuicao_das_palavras_nao_tem_vies_grosseiro() {
    // 4000 convites x 8 palavras = 32000 sorteios em 2048 palavras (~15,6 cada).
    let list = invite::wordlist();
    let mut count = vec![0u32; 2048];
    for _ in 0..4000 {
        for w in generate_invite_words().unwrap() {
            count[list.iter().position(|x| *x == w).unwrap()] += 1;
        }
    }
    let (lo, hi) = (*count.iter().min().unwrap(), *count.iter().max().unwrap());
    assert!(
        lo >= 1 && hi <= 45,
        "distribuição suspeita: min {lo}, max {hi}"
    );
    // Primeira e segunda metade da lista aparecem em proporção parecida.
    let first: u32 = count[..1024].iter().sum();
    let ratio = f64::from(first) / 32000.0;
    assert!((0.47..0.53).contains(&ratio), "metade inferior com {ratio}");
}

#[test]
fn aceita_prefixo_de_4_letras_e_recusa_o_resto() {
    let full = generate_invite_words().unwrap();
    let prefixes: Vec<String> = full.iter().map(|w| w[..4].to_string()).collect();
    assert_eq!(check_invite_words(prefixes).unwrap(), full);
    let upper: Vec<String> = full.iter().map(|w| w.to_uppercase()).collect();
    assert_eq!(check_invite_words(upper).unwrap(), full);

    assert_eq!(
        check_invite_words(words("abacate abelha")),
        Err(CoreError::InvalidInvite)
    );
    let mut wrong = full.clone();
    wrong[3] = "xyzw".into();
    assert_eq!(check_invite_words(wrong), Err(CoreError::InvalidInvite));
    let mut short = full.clone();
    short[0] = "aba".into(); // 3 letras: ambíguo
    assert_eq!(check_invite_words(short), Err(CoreError::InvalidInvite));
}

#[test]
fn derivacao_separa_sala_e_admissao() {
    const FAST: KdfParams = KdfParams {
        m_kib: 1024,
        t: 1,
        p: 1,
    };
    let s = InviteSecret([7; 11]);
    let a = invite::derive_keys(&s, FAST);
    let b = invite::derive_keys(&s, FAST);
    assert_eq!(a.room_id, b.room_id);
    assert_eq!(a.adm_key, b.adm_key);
    assert_ne!(a.room_id, a.adm_key);
    let other = invite::derive_keys(&InviteSecret([8; 11]), FAST);
    assert_ne!(a.room_id, other.room_id);
}

// ---------------------------------------------------------------- sessão MLS

/// Entrada completa: quem entra pede; o membro aceita; os outros processam o commit.
fn admit(member: &mut Session, others: &mut [&mut Session], joiner: &mut Session) {
    let req = joiner.join_request().unwrap();
    let add = member.handle_join_request(req).unwrap();
    member.confirm_own_commit().unwrap();
    for o in others.iter_mut() {
        assert_eq!(
            o.process(add.commit.clone()).unwrap().kind,
            IncomingKind::Commit
        );
    }
    joiner.accept_welcome(add.welcome).unwrap();
}

fn group_of(n: usize) -> (Vec<String>, Vec<Session>) {
    let w = generate_invite_words().unwrap();
    let mut all = vec![Session::create(w.clone()).unwrap()];
    for _ in 1..n {
        let mut j = Session::prepare_join(w.clone()).unwrap();
        let (first, rest) = all.split_first_mut().unwrap();
        let mut others: Vec<&mut Session> = rest.iter_mut().collect();
        admit(first, &mut others, &mut j);
        all.push(j);
    }
    (w, all)
}

#[test]
fn mesma_chave_mesma_sala_chaves_diferentes_salas_diferentes() {
    let w = generate_invite_words().unwrap();
    let a = Session::create(w.clone()).unwrap();
    let b = Session::prepare_join(w).unwrap();
    assert_eq!(a.room_id(), b.room_id());
    let c = Session::prepare_join(generate_invite_words().unwrap()).unwrap();
    assert_ne!(a.room_id(), c.room_id());
}

#[test]
fn conversa_com_tres_e_contador_validado() {
    let (_, mut g) = group_of(3);
    for s in &g {
        assert_eq!(s.view().members, 3);
        assert_eq!(s.view().epoch, 2);
    }
    let m = g[2].encrypt_text("olá, tudo bem? 🌱".into()).unwrap();
    for s in g.iter_mut().take(2) {
        let inc = s.process(m.clone()).unwrap();
        assert_eq!(inc.kind, IncomingKind::Text);
        assert_eq!(inc.text.as_deref(), Some("olá, tudo bem? 🌱"));
    }
}

#[test]
fn pedido_sem_o_convite_e_recusado() {
    let w = generate_invite_words().unwrap();
    let mut a = Session::create(w).unwrap();
    let mut intruder = Session::prepare_join(generate_invite_words().unwrap()).unwrap();
    let req = intruder.join_request().unwrap();
    assert_eq!(
        a.handle_join_request(req).err(),
        Some(CoreError::WrongInvite)
    );
    assert_eq!(
        a.handle_join_request(vec![1, 2, 3]).err(),
        Some(CoreError::WrongInvite)
    );
    assert_eq!(a.view().members, 1);
}

#[test]
fn pedido_repetido_e_recusado() {
    let w = generate_invite_words().unwrap();
    let mut a = Session::create(w.clone()).unwrap();
    let mut b = Session::prepare_join(w).unwrap();
    let req = b.join_request().unwrap();
    a.handle_join_request(req.clone()).unwrap();
    a.confirm_own_commit().unwrap();
    assert_eq!(
        a.handle_join_request(req).err(),
        Some(CoreError::InvalidMessage)
    );
}

#[test]
fn adulterada_repetida_e_texto_longo() {
    let (_, mut g) = group_of(2);
    let mut m = g[0].encrypt_text("original".into()).unwrap();
    let ok = m.clone();
    let last = m.len() - 1;
    m[last] ^= 1;
    assert_eq!(g[1].process(m).err(), Some(CoreError::InvalidMessage));
    // Achado (docs/modelo-de-ameacas.md, T5): a cópia adulterada consome a chave
    // daquela geração, e a mensagem verdadeira, se chegar depois, também falha.
    // Só quem está no caminho (o servidor) consegue isso, e ele já pode descartar
    // mensagens. O grupo continua funcionando para as seguintes.
    assert_eq!(g[1].process(ok).err(), Some(CoreError::InvalidMessage));
    let next = g[0].encrypt_text("seguinte".into()).unwrap();
    assert_eq!(
        g[1].process(next.clone()).unwrap().text.as_deref(),
        Some("seguinte")
    );
    // Repetição da mesma mensagem é recusada.
    assert_eq!(g[1].process(next).err(), Some(CoreError::InvalidMessage));

    assert_eq!(
        g[0].encrypt_text("a".repeat(1001)).err(),
        Some(CoreError::TooLong)
    );
    assert!(
        g[0].encrypt_text("é".repeat(1000)).is_ok(),
        "1000 caracteres, não bytes"
    );
    assert_eq!(
        g[0].encrypt_text(String::new()).err(),
        Some(CoreError::InvalidMessage)
    );
}

#[test]
fn commits_concorrentes_um_vence() {
    let (_, mut g) = group_of(2);
    let ca = g[0].self_update().unwrap();
    let _cb = g[1].self_update().unwrap();
    // Servidor aceitou o de g[0].
    g[0].confirm_own_commit().unwrap();
    g[1].discard_own_commit().unwrap();
    assert_eq!(g[1].process(ca).unwrap().kind, IncomingKind::Commit);
    assert_eq!(g[0].view().epoch, g[1].view().epoch);
    let m = g[1].encrypt_text("seguimos".into()).unwrap();
    assert_eq!(g[0].process(m).unwrap().text.as_deref(), Some("seguimos"));
}

#[test]
fn encerrar_e_remocao_por_queda() {
    let (_, mut g) = group_of(4);
    // g[3] toca em Encerrar.
    let p = g[3].leave().unwrap();
    for s in g.iter_mut().take(3) {
        assert_eq!(s.process(p.clone()).unwrap().kind, IncomingKind::Proposal);
    }
    let c = g[0].commit_pending().unwrap().expect("havia proposta");
    g[0].confirm_own_commit().unwrap();
    for s in g.iter_mut().skip(1).take(2) {
        assert_eq!(s.process(c.clone()).unwrap().view.members, 3);
    }
    assert_eq!(g[3].process(c).unwrap().kind, IncomingKind::RemovedSelf);
    assert!(!g[3].view().active);

    // g[2] caiu e não voltou: o servidor avisou `gone`; g[0] remove a folha.
    let leaf = g[2].view().own_leaf;
    let c = g[0].remove_leaf(leaf).unwrap();
    g[0].confirm_own_commit().unwrap();
    assert_eq!(g[1].process(c).unwrap().view.members, 2);
    let own = g[0].view().own_leaf;
    assert_eq!(g[0].remove_leaf(own).err(), Some(CoreError::InvalidMessage));
    assert_eq!(g[0].commit_pending().unwrap(), None);
}

#[test]
fn trancar_chega_a_todos() {
    let (_, mut g) = group_of(3);
    let l = g[1].encrypt_lock().unwrap();
    assert_eq!(g[0].process(l.clone()).unwrap().kind, IncomingKind::Lock);
    assert_eq!(g[2].process(l).unwrap().kind, IncomingKind::Lock);
}

#[test]
fn quem_entra_depois_nao_le_o_passado() {
    let (w, mut g) = group_of(2);
    let antiga = g[0].encrypt_text("antes".into()).unwrap();
    let mut late = Session::prepare_join(w).unwrap();
    let (first, rest) = g.split_first_mut().unwrap();
    let mut others: Vec<&mut Session> = rest.iter_mut().collect();
    admit(first, &mut others, &mut late);
    assert!(late.process(antiga).is_err());
}

#[test]
fn operacoes_fora_de_hora() {
    let mut j = Session::prepare_join(generate_invite_words().unwrap()).unwrap();
    assert_eq!(j.encrypt_text("oi".into()).err(), Some(CoreError::NotReady));
    assert!(!j.view().active);
    let (_, mut g) = group_of(2);
    g[0].close();
    assert_eq!(
        g[0].encrypt_text("oi".into()).err(),
        Some(CoreError::NotReady)
    );
}

#[test]
fn pedido_pode_ser_tentado_de_novo_se_o_commit_perder_a_epoca() {
    let (w, mut g) = group_of(2);
    let mut joiner = Session::prepare_join(w).unwrap();
    let req = joiner.join_request().unwrap();
    // g[0] tenta adicionar, mas g[1] vence a época com outro commit.
    let _lost = g[0].handle_join_request(req.clone()).unwrap();
    let winner = g[1].self_update().unwrap();
    g[1].confirm_own_commit().unwrap();
    g[0].discard_own_commit().unwrap();
    g[0].process(winner).unwrap();
    // Nova tentativa com o mesmo pedido funciona.
    let add = g[0].handle_join_request(req.clone()).unwrap();
    g[0].confirm_own_commit().unwrap();
    g[1].process(add.commit).unwrap();
    joiner.accept_welcome(add.welcome).unwrap();
    assert_eq!(joiner.view().members, 3);
    // Depois de confirmado, repetir o pedido é recusado.
    assert_eq!(
        g[0].handle_join_request(req).err(),
        Some(CoreError::InvalidMessage)
    );
}
