# Modelo de ameaças — Nenures

Versão 1 · 18/10/2026 · Fase 1
Estado: **rascunho**. As mitigações dependem das decisões D1–D16 ([decisoes/decisoes-pendentes.md](decisoes/decisoes-pendentes.md)). Nenhuma ameaça está "resolvida": uma ameaça só muda de estado quando o teste correspondente existir e passar.

## 1. Ativos

| Ativo | Onde vive | Por quanto tempo |
| --- | --- | --- |
| Texto das mensagens | RAM dos aparelhos (em claro); servidor (cifrado, em trânsito e fila D9) | Até a saída / até 60 s na fila |
| Convite (8 palavras / QR) | RAM, tela, área de transferência se copiado, canal externo usado para compartilhar | Até a sala acabar |
| Segredos MLS (épocas, chaves de folha) | RAM dos aparelhos | Até a saída |
| `room_id` | RAM do servidor e dos aparelhos | Até a sala acabar |
| Metadados (IP, horários, volumes, tamanhos) | Servidor, provedor de hospedagem, provedores de rede | Varia; fora do nosso controle em parte |
| Denúncias confirmadas | Armazenamento separado do servidor | Até 30 dias |
| Integridade do app e do build | Repositório, CI, lojas | Permanente |

## 2. Agentes

Servidor malicioso ou comprometido; operador da hospedagem; observador de rede; participante malicioso; quem obtém o convite sem ter sido convidado; ex-participante; atacante sem convite (internet); dependência comprometida; aparelho comprometido (malware, acesso físico); denunciante de má-fé.

## 3. Escala

Probabilidade: baixa / média / alta (qualitativa). Impacto: baixo / médio / alto / crítico.

---

## 4. Ameaças

### T1 — Servidor comprometido ou malicioso
- **Cenário:** quem controla o servidor tenta ler mensagens, inserir participantes, alterar ou ocultar mensagens.
- **Impacto:** crítico se conseguir ler; alto se conseguir inserir participante invisível.
- **Probabilidade:** média (servidor único, mantido por uma pessoa).
- **Mitigação:** MLS; servidor não conhece o convite; pedido de entrada autenticado com `adm_key`; contador vindo da árvore MLS; nenhum log de conteúdo.
- **Teste:** servidor de teste adversário que injeta pedido de entrada sem `adm_key`, injeta commit falso, repete pedidos antigos; todos devem ser rejeitados pelos clientes.
- **Residual:** vê metadados; pode bloquear, atrasar, descartar, dividir o grupo (detectado como falha de decifragem); pode tentar adivinhar o convite a partir de `room_id` (inviável com 88 bits + Argon2id).

### T2 — Participante malicioso
- **Cenário:** alguém convidado copia, fotografa, repassa o convite, envia conteúdo abusivo ou mensagens malformadas.
- **Impacto:** alto (conteúdo vazado fora do app).
- **Probabilidade:** alta.
- **Mitigação:** sair/bloquear; denúncia; validação estrita de mensagens MLS; limite de 1000 caracteres; `FLAG_SECURE`.
- **Teste:** mensagens malformadas, acima do limite e com época inválida são rejeitadas sem travar o app.
- **Residual:** o app não impede cópia, foto de outro aparelho nem repasse do convite. Documentado na tela Sobre.

### T3 — Roubo ou compartilhamento indevido do convite
- **Cenário:** o convite vaza (print de conversa em outro app, área de transferência, alguém olhando a tela).
- **Impacto:** alto: por P4, quem tem o convite entra enquanto a conversa existir e lê o que for enviado depois.
- **Probabilidade:** média.
- **Mitigação:** entrada visível (contador e aviso de sistema); "Trancar entrada" (D7); aviso ao copiar (D13); expiração de 10 min sem entrada.
- **Teste:** terceiro cliente com o convite entra e todos veem o contador subir e o aviso; após trancar, o pedido é recusado.
- **Residual:** sem trancar, a janela de risco dura toda a conversa. Mensagens anteriores à entrada continuam protegidas.

### T4 — Repetição de mensagens (replay)
- **Cenário:** o servidor reenvia mensagens de aplicação, commits ou pedidos de entrada antigos.
- **Impacto:** médio (mensagem duplicada, folha fantasma).
- **Probabilidade:** média (só com servidor malicioso).
- **Mitigação:** MLS rejeita mensagens repetidas via geração/época; KeyPackage com validade curta; lista de KeyPackages já vistos.
- **Teste:** reinjetar a mesma mensagem e o mesmo pedido; o cliente descarta.
- **Residual:** folha fantasma se o `Welcome` original for descartado; ela não lê nada e é removida por inatividade.

### T5 — Alteração, injeção ou descarte de mensagens
- **Cenário:** alterar bytes de mensagens, injetar mensagens forjadas, descartar mensagens seletivamente.
- **Impacto:** alto (alteração), médio (descarte).
- **Probabilidade:** média.
- **Mitigação:** AEAD e assinatura por folha do MLS; rejeição de mensagens adulteradas.
- **Teste:** inverter bits em mensagens e commits; o cliente rejeita e não exibe.
- **Residual:** descarte seletivo não é detectado de forma confiável na v1 (não há confirmação de leitura nem numeração global visível).
- **Achado (18/10/2026, teste `adulterada_repetida_e_texto_longo` em app/rust/tests/core.rs):** se uma cópia adulterada de uma mensagem chega antes da verdadeira, o OpenMLS consome a chave daquela geração e a verdadeira também é rejeitada. Só quem está no caminho da rede (o servidor) consegue fazer isso, e ele já pode descartar mensagens; o efeito é o mesmo de um descarte. As mensagens seguintes continuam funcionando.

### T6 — Entrada indevida em salas
- **Cenário:** adivinhar convites, forçar entrada em sala ativa, criar entrada sem que os outros percebam.
- **Impacto:** crítico.
- **Probabilidade:** baixa (88 bits).
- **Mitigação:** CSPRNG; 88 bits; Argon2id; limitação de tentativas (D11); toda entrada passa por commit MLS visível.
- **Teste:** gerador produz distribuição uniforme (teste estatístico simples); 10 mil convites sem repetição; tentativa de entrada com `room_id` válido e `adm_key` errada é recusada pelos membros.
- **Residual:** quem tem o convite entra (T3).

### T7 — Negação de serviço
- **Cenário:** inundar o servidor com conexões, salas, pedidos, frames grandes; entrar em massa numa sala (P5).
- **Impacto:** médio (indisponibilidade).
- **Probabilidade:** alta (serviço público e gratuito).
- **Mitigação:** limites por IP (D11), teto de participantes (D6), tamanho de frame (D10), timeouts, limites globais de memória e conexões; correções de DoS da biblioteca MLS aplicadas (avisos GHSA-gc79-23g3-8g52, GHSA-rrmv-c79f-cf5r).
- **Teste:** testes de carga e de frames inválidos no servidor; testes de fuzzing do decodificador no cliente.
- **Residual:** ataque distribuído derruba uma VPS pequena. O servidor reiniciado encerra todas as salas.

### T8 — Divergência de estado entre participantes
- **Cenário:** commits concorrentes, mensagens perdidas ou servidor que entrega commits diferentes a grupos diferentes.
- **Impacto:** médio (conversa quebrada; pessoas acham que estão juntas mas não estão).
- **Probabilidade:** média.
- **Mitigação:** servidor aceita um commit por época; fila de reconexão (D9); falhas de decifragem persistentes levam ao estado "conversa inconsistente" e à saída.
- **Teste:** commits concorrentes de 3 clientes; perda de commit; servidor que entrega commits diferentes.
- **Residual:** sem comparação ativa de época, uma divisão só é percebida quando alguém fala.

### T9 — Comprometimento do dispositivo
- **Cenário:** malware, acessibilidade abusada, root, acesso físico.
- **Impacto:** crítico para aquele participante.
- **Probabilidade:** média.
- **Mitigação:** nada persistido em disco; backup desabilitado; estado descartado ao sair.
- **Teste:** inspeção do diretório do app após uso; `adb backup`/regras de extração sem dados.
- **Residual:** o app não protege um aparelho comprometido. Documentado.

### T10 — Captura de tela ou fotografia externa
- **Cenário:** print, gravação de tela, espelhamento, foto com outro aparelho.
- **Impacto:** alto.
- **Probabilidade:** alta.
- **Mitigação:** `FLAG_SECURE` no Android (bloqueia print, gravação e prévia em recentes); no iOS, detecção e ocultação quando possível.
- **Teste:** manual em aparelhos reais (Android 8+ e o aparelho de referência).
- **Residual:** foto com outro aparelho; app modificado ignora `FLAG_SECURE`; aviso de print no iOS não é prova.

### T11 — Vazamento pela área de transferência
- **Cenário:** convite copiado fica na área de transferência, sincronizada com outros aparelhos ou lida por outros apps/teclados.
- **Impacto:** alto (equivale a T3).
- **Probabilidade:** média.
- **Mitigação:** aviso ao copiar; marcação sensível (Android 13+); limpeza após 60 s só se a área de transferência ainda tiver a mesma cópia, comparando o carimbo de tempo sem ler o conteúdo (D13, Android 8+); aprendizado do teclado desligado nos campos.
- **Teste:** copiar → verificar marcação; limpeza só quando o conteúdo ainda é o convite.
- **Residual:** limpeza não garantida; teclados de terceiros podem registrar o que é digitado.

### T12 — Exposição de metadados
- **Cenário:** servidor, hospedagem ou rede correlacionam IPs e horários para descobrir quem conversa com quem.
- **Impacto:** alto para pessoas em risco.
- **Probabilidade:** média.
- **Mitigação:** TLS; sem logs de acesso no proxy; sem IDs de sala em logs; métricas agregadas; HMAC rotativo para limitação por IP.
- **Teste:** verificação automatizada de que logs do servidor não contêm `room_id`, IPs ou conteúdo.
- **Residual:** o servidor e o provedor veem IPs e horários. Não prometer anonimato.

### T13 — Erros de implementação ou de integração criptográfica
- **Cenário:** uso errado da API MLS, validação omitida, segredo em log, reaproveitamento de nonce, viés no gerador de convites.
- **Impacto:** crítico.
- **Probabilidade:** média (projeto pequeno, uma pessoa).
- **Mitigação:** sem primitivas próprias; interface isolada; vetores oficiais; revisão externa (D2); testes adversos.
- **Teste:** suíte 12.1 completa.
- **Residual:** só a revisão externa reduz este risco de forma relevante.

### T14 — Falhas de dependências
- **Cenário:** vulnerabilidade na biblioteca MLS, ponte Rust, pacotes Flutter, Go; pacote malicioso.
- **Impacto:** crítico.
- **Probabilidade:** média (OpenMLS teve 5 avisos em 13 meses, 2 altos).
- **Mitigação:** versões fixadas, `Cargo.lock`/`pubspec.lock`/`go.sum` no repositório; `cargo audit`, `govulncheck` e verificação de avisos no CI; poucas dependências.
- **Teste:** jobs de auditoria no CI que falham com aviso conhecido.
- **Residual:** vulnerabilidades ainda não divulgadas.
- **Exceções ativas (18/10/2026):** RUSTSEC-2026-0330 e 0331 (`libcrux-kem` 0.0.9, panic/DoS) ignoradas no `cargo audit` porque o pacote só aparece no `Cargo.lock` como dependência opcional desligada do `hpke-rs` 0.7 e não é compilado; o CI falha se ele entrar no build. Justificativa em `app/rust/.cargo/audit.toml`. Aviso informativo: `proc-macro-error2` sem manutenção (usado só na compilação de macros).

### T15 — Abuso do mecanismo de denúncias
- **Cenário:** denúncia com conteúdo inventado; enxurrada de denúncias; denúncias usadas para assediar a moderação.
- **Impacto:** médio.
- **Probabilidade:** alta.
- **Mitigação:** a moderação sabe que o conteúdo não é verificável (sem *message franking*); limite de envio; sem IP ou `room_id` anexado.
- **Teste:** denúncia sem consentimento não sai; payload enviado é exatamente o mostrado; retenção de 30 dias aplicada.
- **Residual:** denúncias falsas são indistinguíveis de verdadeiras.

### T16 — Uso por menores ou contato de adultos com menores
- **Cenário:** menores usam o app; adultos usam o anonimato para contatar menores.
- **Impacto:** crítico.
- **Probabilidade:** média.
- **Mitigação:** classificação 18+ (P11); mecanismo de idade de D16; procedimento para conteúdo ilegal (operacao.md); denúncia.
- **Teste:** depende de D16.
- **Residual:** sem cadastro, nenhum mecanismo impede totalmente o uso por menores. Depende de parecer jurídico.
