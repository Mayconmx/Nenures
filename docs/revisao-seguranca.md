# Revisão de segurança — Nenures

Versão 1 · 18/10/2026 · Fase 1 (auditoria inicial)
Estado: **rascunho para aprovação**. Nada aqui está aprovado até o responsável pelo produto aprovar as decisões em [decisoes/decisoes-pendentes.md](decisoes/decisoes-pendentes.md).

Este documento é a referência para o protocolo criptográfico. Instruções antigas (protótipo, design system, versões anteriores do prompt) que conflitem com ele devem ser corrigidas.

---

## 1. Material auditado

| Fonte | Versão lida | Observação |
| --- | --- | --- |
| Prompt mestre v2 (`PROMPT-NENURES-v2.md`) | 18/10/2026 | Requisitos P1–P13, D1–D16 |
| Protótipo navegável (artifact `NkQ5yuWPHcfvBi7KeSBqrv`) | versão 1792331241 | HTML + JS, WebCrypto |
| Design system (artifact `H7qHKD34BUarMZ8SpvzxSF`) | versão 1792331264 | README, tokens, 5 componentes |
| Repositório de código | — | **Não existe.** Nenhum código Flutter ou Go foi encontrado na máquina. |

Ambiente de desenvolvimento verificado em 18/10/2026: Flutter 3.47.0 (stable, Dart 3.13.0), Rust 1.99.0, Git 2.55, Android SDK (build-tools, platform-tools, emulator). **Go não está instalado. Java (JDK) não está no PATH.** Há duas instalações de Flutter no PATH (`Downloads/flutter` e `C:/flutter`, esta incompleta); convém manter só uma.

---

## 2. O que o protótipo implementa hoje (modelo L0)

Trechos do protótipo:

```js
function genKey(){return Array.from({length:6},()=>WORDS[rnd(WORDS.length)]).join(" ");}   // 6 palavras, lista de 64
deriveKey: PBKDF2(SHA-256, salt fixo "nenures-v0", 100000 iterações) -> AES-GCM-256
seal: AES-GCM com IV aleatório de 12 bytes, mesma chave para todos
```

| # | Achado | Gravidade | Consequência |
| --- | --- | --- | --- |
| A1 | Lista de **64 palavras × 6 = 36 bits** de entropia. | Crítica | Com PBKDF2 a 100 mil iterações, uma GPU testa todo o espaço em horas a dias. Quem gravou o tráfego decifra a conversa. |
| A2 | Uma única chave simétrica derivada do convite cifra todas as mensagens (L0). | Crítica | Sem autenticação por remetente, sem sigilo futuro, sem revogação; quem obtiver o convite depois decifra o tráfego gravado. |
| A3 | Salt fixo `nenures-v0`. | Alta (com A1) | Permite pré-computação contra todas as salas de uma vez. |
| A4 | `rnd(n)` usa `getRandomValues(...) % n`. | Baixa (n=64 divide 2³²) | Com listas cujo tamanho não divide 2³² haveria viés de módulo. Na implementação real, usar amostragem por rejeição ou bits diretos. |
| A5 | Contador de pessoas é um número local, não validado. | Alta (no produto real) | O PresenceBar diz que "o contador é a defesa contra intrusos"; isso só vale se o número vier do estado criptográfico do grupo. |
| A6 | Textos "Nada ficou guardado" e "A conversa foi apagada de vez" (tela Fim). | Média | Promessas absolutas, proibidas pelo próprio design system e pela seção 15 do prompt. |
| A7 | Alternância "ver como o servidor" mostra o texto cifrado. | Baixa | Recurso de demonstração. Não deve ir para o app: induz a pensar que o servidor só vê aquilo (ele vê metadados). |
| A8 | Copiar a chave não exibe aviso. | Média | Contraria 3.1 e D13. |

**Conclusão:** o protótipo serve como referência visual e de fluxo. **Nenhuma parte da sua criptografia deve ser reaproveitada.**

---

## 3. Contradições entre os documentos

| # | Onde | Contradição | Resolução proposta |
| --- | --- | --- | --- |
| C1 | Protótipo × Composer (DS) × prompt | Protótipo: 6 palavras. Composer: "A chave tem 8 palavras". Prompt: 8 palavras/88 bits. | Seguir D4/D5 (proposta: 8 palavras de lista de 2048). Corrigir protótipo e DS depois da aprovação. |
| C2 | Protótipo × prompt 6.1 | Protótipo usa L0. | L0 rejeitado. Ver seção 4. |
| C3 | Tela Início (protótipo) | "E2E — só quem tem a chave lê as mensagens". Com P4, qualquer pessoa que obtenha a chave pode entrar e ler as mensagens **a partir da entrada**. | Usar o texto sugerido no prompt: "E2E — o servidor recebe as mensagens cifradas". |
| C4 | Tela Fim (protótipo) × DS "Voz" | "Nada ficou guardado" é proibido pelo DS. | Reescrever (Fase 2): "As mensagens foram descartadas deste aparelho. Não conseguimos apagar cópias, prints ou o que outras pessoas guardaram." |
| C5 | PresenceBar (DS) | "Defesa contra intrusos" pressupõe contador validado. | Contador = número de folhas da árvore MLS (seção 4.6). Ajustar o texto do DS para não prometer detecção. |
| C6 | Button/bundle.css (DS) × prompt 8 | Botão pequeno com `min-height: 32px` (Encerrar, Copiar chave). Requisito: alvos ≥ 48 dp. | No Flutter, manter área de toque de 48 dp mesmo com visual compacto (`MaterialTapTargetSize.padded`). |
| C7 | Tokens (DS) | `line` sobre `surface-000`/`surface-100`: contraste 1,25–1,43:1 (claro) e 1,27–1,41:1 (escuro). WCAG 1.4.11 pede 3:1 para o contorno de controles (campos de texto). | Criar token `line-strong` para bordas de campos, ou reforçar o foco/fundo do campo. Os demais pares de texto passam de 4,5:1 nos dois temas (medido; ver seção 7). |
| C8 | DS Iconografia | "Material Symbols Rounded (já disponível no Flutter)". O `Icons` do Flutter traz Material **Icons**, não Material **Symbols**. | Verificar na Fase 2: empacotar a fonte variável oficial (Apache-2.0) ou usar pacote equivalente, sem download em tempo de execução. |
| C9 | DS (aviso de print) × P9 | No Android, P9 bloqueia a captura com `FLAG_SECURE`; portanto não há evento "Alguém tirou print" no Android. | O aviso existe só no iOS (Fase 10) e é informativo (3.4). |
| C10 | Protótipo/DS | Fontes carregadas do Google Fonts por rede. | No app, fontes empacotadas (OFL). Já previsto no DS. |

Conflitos entre decisões de produto (P) e técnicas (D) estão na seção 2 de [decisoes-pendentes.md](decisoes/decisoes-pendentes.md).

---

## 4. Arquitetura criptográfica proposta (para aprovação)

**Nada desta seção deve ser implementado antes da aprovação de D1–D14.** Os pontos marcados "spike" precisam ser confirmados contra a API real da biblioteca escolhida.

### 4.1 Visão geral

- **MLS (RFC 9420)** para o grupo: cada participante tem uma folha na árvore, com chave de assinatura própria gerada na sessão. As mensagens de aplicação são cifradas com segredos por época; entradas e saídas geram commits que avançam a época.
- **Convite** = segredo aleatório de 88 bits mostrado como 8 palavras e QR. Serve para (a) localizar a sala e (b) provar aos membros que quem pede para entrar tem o convite. **Não cifra mensagens.**
- **Servidor** = Delivery Service do MLS: ordena commits, retransmite, guarda o mínimo em RAM. Não conhece o convite nem segredos do grupo.
- Uma única biblioteca nativa (Rust) faz MLS **e** a derivação do convite (Argon2id + HKDF). Isso torna a libsodium desnecessária (ver D1 e D4).

### 4.2 Derivação do convite (proposta D4)

```
S        = 11 bytes aleatórios do CSPRNG do sistema (88 bits) -> 8 palavras BIP39-PT (11 bits cada)
K        = Argon2id(senha = S, salt = "nenures/v1/convite" (16 bytes fixos), m, t, p)   -- parâmetros medidos no aparelho de referência
room_id  = HKDF-Expand(K, "nenures/v1/sala",     32)    -- enviado ao servidor
adm_key  = HKDF-Expand(K, "nenures/v1/admissao", 32)    -- nunca sai do aparelho
```

- O QR carrega o mesmo segredo S (formato proposto: `nenures:1:` + as 8 palavras), para que QR e digitação deem exatamente o mesmo resultado.
- O salt é fixo por necessidade: quem entra só tem as palavras. O risco de ataque a muitas salas de uma vez é aceito porque S tem 88 bits: mesmo dividindo por 2²⁰ salas simultâneas, restam 2⁶⁸ avaliações de Argon2id.
- O servidor vê `room_id` e pode tentar adivinhar S offline. 2⁸⁸ avaliações de Argon2id é inviável. Ainda assim, um convite que vaze depois da conversa **não** decifra mensagens antigas, porque elas usam segredos MLS (diferença central em relação ao L0).

### 4.3 Admissão (proposta: entrada mediada por membro)

1. Quem entra digita/lê o convite, deriva `room_id` e `adm_key`, gera um **KeyPackage** MLS novo (credencial básica com 16 bytes aleatórios, chave Ed25519 nova, validade curta, por exemplo 5 minutos).
2. Envia ao servidor `{room_id, AEAD(adm_key, nonce, KeyPackage, ad = "nenures/v1/pedido")}`.
3. O servidor repassa o pedido aos membros conectados. Ele não consegue forjar um pedido válido sem S.
4. O membro designado (a folha online de menor índice) decifra, valida o KeyPackage (assinatura, ciphersuite, validade, não visto antes nesta conversa), cria `Commit(Add)` + `Welcome`.
5. O servidor aceita **o primeiro** commit da época N e rejeita os demais (ordenação do Delivery Service). Repassa o commit a todos e o `Welcome` a quem entrou.
6. Todos os membros processam o commit: o contador sobe e aparece "Alguém entrou · N pessoas".

Alternativa avaliada: **commit externo** (membros publicam `GroupInfo` cifrado com `adm_key`, e quem entra se adiciona sozinho). Funciona sem membro designado, mas exige republicar o `GroupInfo` a cada época e amplia a superfície. Recomendo a entrada mediada; o commit externo fica como plano B se o spike mostrar problemas de concorrência.

**O que esta proposta responde (exigência 6.3):**

| Pergunta | Resposta |
| --- | --- |
| O que o servidor consegue falsificar? | Não consegue criar pedido de entrada válido (precisa de S). Consegue descartar, atrasar, reordenar e repetir mensagens, e recusar entradas. |
| O que o servidor consegue ler? | `room_id`, tamanhos, horários, IPs, quantidade de conexões, quem envia commits. Não lê KeyPackages (cifrados), mensagens nem o roster de credenciais. |
| Como o participante é autenticado? | Não há identidade. Autenticação = "possui o convite" (prova pelo AEAD) + "controla esta folha" (assinatura MLS). Mensagens são autenticadas por folha, mas a interface **não** associa folhas a pessoas. |
| Como o grupo confirma a entrada? | Pelo commit processado por todos. O contador vem da árvore MLS, não do servidor. |
| Como evitar entradas invisíveis? | Uma folha nova só existe via commit, que todos processam. Se o servidor entregar o commit só para parte do grupo, as épocas divergem e as mensagens deixam de decifrar (detectável, ver 4.7). |
| Como o convite deixa de funcionar? | Expira em 10 min se ninguém entrar (P3); morre quando a sala some (P8); opcionalmente quando alguém tranca a sala (D7). |
| E se o convite vazar? | Por P4, quem tiver o convite entra enquanto a conversa existir. A entrada é visível (contador + aviso). Lê só mensagens posteriores à entrada. Mitigação: trancar (D7) e sair. |

**Repetição de pedido (replay):** o servidor pode reenviar um pedido antigo. Mitigação: validade curta do KeyPackage e lista de KeyPackages já vistos. Risco residual: se o servidor descartar o `Welcome` original, pode surgir uma folha "fantasma" (ninguém tem a chave privada dela). Ela não lê nada, mas infla o contador até ser removida por inatividade (ver 4.5).

### 4.4 Ordenação e concorrência

- O servidor mantém, por sala, o número da época aceita e aceita um único commit por época (primeiro a chegar).
- Quem tiver o commit rejeitado descarta seu commit pendente, processa o vencedor e tenta de novo se ainda fizer sentido.
- Mensagens de aplicação de época antiga são aceitas dentro da janela que a biblioteca permite (configurar `max_past_epochs` pequeno, a definir no spike).

### 4.5 Saída

- **Encerrar:** o cliente envia uma proposta Remove da própria folha (spike: confirmar `leave_group`/SelfRemove na biblioteca), fecha o WebSocket e descarta o estado. O membro designado faz o commit.
- **Queda/fechamento abrupto:** o servidor avisa a sala que a conexão associada à folha X caiu. Passada a janela de reconexão (D9), o membro designado faz `Commit(Remove X)`. O servidor pode mentir sobre isso; o efeito é expulsar alguém (o que ele já pode fazer cortando a conexão), não ler mensagens.
- Remover uma folha protege as mensagens **futuras**. Quem saiu continua com o que já recebeu.

### 4.6 Presença validada

Contador = número de folhas ocupadas na árvore MLS da época atual. O servidor não envia número de pessoas; envia só eventos de conexão, que servem para disparar remoções, nunca para atualizar o contador.

### 4.7 O que o MLS não resolve

- O servidor pode descartar, atrasar ou bloquear tudo (negação de serviço).
- Pode dividir o grupo (mostrar commits diferentes a subconjuntos). Os subgrupos ficam em épocas distintas e não se leem. Detecção proposta: falhas de decifragem persistentes viram o estado "conversa inconsistente", com saída obrigatória. Detecção ativa (comparar `epoch_authenticator`) fica como avaliação futura, porque exigiria um canal fora da banda.
- Não há verificação de "quem é quem". Isso é intencional (P1), e a interface não deve sugerir o contrário.

### 4.8 Estado local e memória

- Estado MLS só em RAM (provedor de armazenamento em memória; spike: confirmar que a biblioteca não grava em disco sem configuração explícita).
- Ao sair: descartar o grupo, sobrescrever buffers mutáveis que estiverem sob nosso controle (Rust `zeroize` onde a biblioteca permitir), soltar referências no Dart.
- Limites documentados: o coletor de lixo do Dart pode copiar e manter strings; o teclado e a área de transferência estão fora do controle do app; o sistema pode fazer swap/compressão de memória. **Não afirmar zeramento físico.**

---

## 5. Regras que valem desde já

1. Nenhum código de produção com criptografia antes da aprovação de D1–D14.
2. Nenhuma primitiva própria; nenhum MLS caseiro.
3. O transporte falso da Fase 2 não cifra nada, vive em código de teste e o build de release falha se for referenciado.
4. Logs: nunca convite, palavras, `room_id`, chaves, texto ou KeyPackages.
5. Vetores de teste só de fontes oficiais (vetores do RFC 9420 publicados pelo grupo MLS / repositório `mls-implementations`), com origem e versão registradas.

---

## 6. Itens a confirmar no spike técnico (início da Fase 5, após aprovação)

| # | Pergunta | Critério de aceite |
| --- | --- | --- |
| S1 | OpenMLS compila para `aarch64-linux-android`, `armv7-linux-androideabi` e `x86_64-linux-android` com flutter_rust_bridge? | Build reprodutível no CI; app de teste roda no emulador e no aparelho de referência. |
| S2 | Ciphersuite 0x0003 funciona com o provedor de criptografia escolhido? | Vetores oficiais passam. |
| S3 | Provedor de armazenamento só em memória? | Teste que verifica ausência de arquivos criados no diretório do app. |
| S4 | Saída voluntária (Remove da própria folha) | Teste de integração com 3 clientes. |
| S5 | Tamanho do APK e memória com 2, 10, 50 participantes | Medido no aparelho de referência. |
| S6 | Tempo de Argon2id com os parâmetros propostos | ≤ 1,5 s no aparelho de referência. |

---

## 7. Medições feitas nesta fase

**Contraste dos tokens do DS** (WCAG 2.x, calculado a partir dos hex):

| Par | Claro | Escuro |
| --- | --- | --- |
| ink / surface-000 | 13,95 | 14,72 |
| ink-muted / surface-000 | 4,92 | 6,23 |
| ink-muted / bubble-theirs | 5,62 | 5,20 |
| on-accent / accent | 6,91 | 7,47 |
| on-bubble-mine / bubble-mine | 6,39 | 7,20 |
| key-ink / surface-sunk | 9,10 | 11,29 |
| danger / surface-000 | 5,59 | 6,18 |
| warn / surface-sunk | 4,73 | 8,72 |
| **line / surface-100** | **1,43** | **1,27** |

**Lista BIP39 em português** (baixada de `github.com/bitcoin/bips/master/bip-0039/portuguese.txt` em 18/10/2026): 2048 palavras únicas, nenhuma com acento, prefixos de 4 letras todos distintos, nenhum par de palavras a distância de edição 1, comprimento de 4 a 8 letras. Falta revisão manual de palavras ofensivas ou constrangedoras e confirmação da licença.

---

## 8. Fontes consultadas (18/10/2026)

- RFC 9420 — https://www.rfc-editor.org/rfc/rfc9420
- OpenMLS: crates.io (`openmls` 0.9.1 publicada em 07/10/2026, MIT), README (ciphersuites 0x0001, 0x0002, 0x0003; Android/iOS só compilados no CI, sem testes; rustc ≥ 1.94), avisos de segurança: https://github.com/openmls/openmls/security/advisories (5 avisos entre 09/2025 e 10/2026, dois de gravidade alta, incluindo GHSA-8x3w-qj7j-gqhf "Improper tag validation" e GHSA-gc79-23g3-8g52 de 08/10/2026).
- mls-rs: crates.io (`mls-rs` 0.56.0, 19/08/2026, Apache-2.0 OR MIT). README não pôde ser lido nesta sessão (falha de rede); avaliação incompleta.
- flutter_rust_bridge: crates.io (2.13.0 estável de 23/08/2026, MIT).
- coder/websocket: proxy.golang.org (v1.8.15, 15/06/2026).
- Auditoria encontrada: NCC Group, revisão do libxmtp (2024), projeto que usa OpenMLS — https://www.nccgroup.com/research/public-report-xmtp-mls-implementation-review/ . **Não é auditoria do OpenMLS.**
