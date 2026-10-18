# Decisões pendentes D1–D16

Versão 1 · 18/10/2026 · Fase 1
Estado: **todas pendentes de aprovação**. As recomendações abaixo são propostas, não decisões.

Base técnica: [../revisao-seguranca.md](../revisao-seguranca.md). Ameaças: [../modelo-de-ameacas.md](../modelo-de-ameacas.md).

---

## 1. Resumo

| ID | Decisão | Recomendação | Precisa da sua aprovação? | Bloqueia |
| --- | --- | --- | --- | --- |
| D1 | Protocolo e biblioteca | MLS com **OpenMLS 0.9.x** via Rust + flutter_rust_bridge, condicionado ao spike S1–S5. Sem libsodium. | Sim | Fases 4–5 |
| D2 | Revisão externa | Obrigatória antes do lançamento público; teste fechado pode ocorrer antes. | Sim (custo) | Lançamento |
| D3 | Ciphersuite | `MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519` (0x0003) | Sim | Fase 5 |
| D4 | Convite e derivação | 8 palavras (88 bits) + QR com o mesmo segredo, Argon2id + HKDF | Sim | Fase 5 |
| D5 | Lista de palavras | BIP39 português (2048 palavras), após revisão manual | Sim | Fase 5 |
| D6 | Limite de participantes | Teto técnico, número definido após medição (ponto de partida: 50) | **Sim — conflita com P5** | Fase 4 |
| D7 | Trancar a sala | Ação opcional "Trancar entrada", sem desfazer | **Sim — interage com P4** | Fase 6 |
| D8 | Remoção de participantes | Só saída própria e remoção automática de desconectados; sem administração | Sim | Fase 5 |
| D9 | Reconexão | Fila em RAM de até 60 s por participante; estado perdido = nova entrada | Sim | Fase 4 |
| D10 | Tamanho de frame | 8 KiB para mensagens de aplicação; controle definido após medição | Sim | Fase 4 |
| D11 | Limitação por IP | Contadores em RAM com HMAC do IP e chave rotativa, sem logs | Sim (+ jurídico) | Fase 4 |
| D12 | Metadados | TLS no lançamento; divulgar limites; Tor/proxy depois | Sim | Fase 9 |
| D13 | Cópia do convite | Permitir com aviso, marcar como sensível, limpeza condicional | Sim | Fase 6 |
| D14 | Fixação de certificado | Não fixar no lançamento | Sim | Fase 6 |
| D15 | Licença do app | MPL-2.0 (alternativa: GPL-3.0 + CLA) | **Sim — afeta P13** | Fases 9–10 |
| D16 | Verificação de idade | Sinal de idade da loja, sem documentos; depende de parecer jurídico | **Sim — afeta P1/P11** | Fases 7, 9 |

---

## 2. Conflitos entre decisões de produto e técnicas

| Conflito | Problema | Opções | Recomendação |
| --- | --- | --- | --- |
| **P5 × D6** | "Sem limite" de participantes. Cada entrada gera um `Welcome` que carrega a árvore inteira (cresce com N) e cada commit precisa chegar a todos. Sem teto, uma sala pode ser usada para esgotar memória do servidor e dos celulares baratos. | (a) Teto técnico com mensagem clara ("Esta conversa está cheia"); (b) sem teto, aceitando degradação e risco de abuso; (c) teto alto só no servidor (ex.: 500), sem garantia de funcionar em aparelhos baratos. | (a). O produto não impõe limite; o teto é técnico, publicado na tela Sobre e revisto com medições. |
| **P4 × D7** | A chave vale enquanto a conversa existir. Se vazar, qualquer pessoa entra. | (a) Manter P4 e oferecer "Trancar entrada" opcional; (b) manter P4 sem trancar; (c) mudar P4. | (a). Não muda o padrão de P4. |
| **P6 × D8** | Encerrar só tira quem apertou. Em MLS, um membro não pode commitar a própria remoção; outro membro precisa fazê-lo. | Membro designado commita a remoção; se ninguém estiver online, a sala acaba (P8). | Compatível; só documentar. |
| **P7/P8 × D9** | 60 s em segundo plano tira a pessoa; queda de rede tenta reconectar por 60 s. Se o último participante estiver reconectando, a sala ainda existe? | (a) A sala vive enquanto houver alguém conectado **ou** dentro da janela de reconexão; (b) a sala morre na hora em que não há conexão. | (a), com no máximo 60 s. |
| **P3 × D9** | Expiração de 10 min com só o criador. Se o criador cair e voltar? | Mesmo tratamento de reconexão; o relógio de 10 min não reinicia. | Documentar. |
| **P11 × D16 × P1** | ECA Digital exige mecanismo de idade além da autodeclaração (segundo a imprensa; falta parecer). P1 proíbe cadastro. | Ver D16. | Parecer jurídico antes da Fase 7. |
| **P13 × D15** | GPL-3.0 é considerada incompatível com os termos da App Store quando há vários autores. | Ver D15. | Decidir antes de aceitar a primeira contribuição externa. |
| **P10** | Sem push. | — | Sem conflito. Explicar na tela Sobre e na loja. |
| Tela Início × D9 | O fato "0 mensagens guardadas no servidor" seria falso com a fila de reconexão e com denúncias. | Usar os três fatos sugeridos no prompt. | Já previsto. |

---

## 3. Detalhamento

### D1 — Protocolo e biblioteca

**Escolha proposta:** MLS (RFC 9420) com OpenMLS, compilado em Rust e ligado ao Dart por flutter_rust_bridge. A derivação do convite (Argon2id, HKDF) também em Rust, com crates RustCrypto (`argon2`, `hkdf`) que o provedor de criptografia do OpenMLS já usa; assim a libsodium não entra no projeto.

**Evidências (18/10/2026):**

| Critério | OpenMLS | mls-rs (AWS) |
| --- | --- | --- |
| Última versão estável | 0.9.1 (07/10/2026) | 0.56.0 (19/08/2026) |
| Licença | MIT | Apache-2.0 OR MIT |
| Ciphersuites | 0x0001, 0x0002, 0x0003 (README) | Não verificado nesta sessão |
| Android/iOS | Compila no CI, **sem testes** nessas plataformas | Não verificado |
| Avisos de segurança | 5 publicados (09/2025–10/2026), 2 altos; correções lançadas | Não verificado |
| Auditoria pública | Nenhuma encontrada da biblioteca em si | Não verificado |
| Mantenedores | Phoenix R&D, Cryspen (CE Labs) | AWS Labs |

**Alternativas:** mls-rs (fica como segunda opção, a avaliar com a mesma tabela antes do spike); Signal Sender Keys (descartado: não há biblioteca de grupo pronta e independente do servidor do Signal; implementar seria criar protocolo próprio); L0 (descartado).

**Riscos:** a ponte Rust aumenta o tamanho do APK e a complexidade do build; OpenMLS não testa Android/iOS, então nós testamos; a lista de avisos mostra bugs reais de validação, o que exige acompanhar versões e ter atualização rápida.

**Impacto na experiência:** nenhum visível se o spike passar. Primeira entrada fica alguns décimos de segundo mais lenta.

**Testes:** vetores oficiais RFC 9420; S1–S5 da revisão de segurança.

### D2 — Revisão externa

Revisar o protocolo de admissão (revisao-seguranca.md 4.3) e a integração, não a biblioteca inteira. Caminhos para um projeto sem fins lucrativos: programas que financiam auditorias de código aberto (por exemplo OSTIF, NLnet, Sovereign Tech Agency) ou consultorias com preço social. **Riscos:** custo e prazo. **Recomendação:** teste fechado pode acontecer sem a revisão; lançamento público não. Se a revisão não acontecer, tratar como risco impeditivo (seção 15).

### D3 — Ciphersuite

0x0003 (X25519, ChaCha20-Poly1305, SHA-256, Ed25519). Celulares baratos podem não ter instruções AES em hardware (ou rodar userspace de 32 bits no Android Go); ChaCha20 é rápido e de tempo constante em software. Alternativa: 0x0001 (AES-128-GCM, obrigatória pela RFC). Como só existe um cliente (o Nenures), não há ganho de interoperabilidade em usar 0x0001. **Teste:** vetores para 0x0003 e medição no aparelho de referência.

### D4 — Convite e derivação

| Opção | Entropia | Experiência | Avaliação |
| --- | --- | --- | --- |
| 6 palavras de 2048 | 66 bits | Mais fácil | Insuficiente: o servidor vê `room_id` e pode atacar offline. |
| **8 palavras de 2048** | **88 bits** | Aceitável | Com Argon2id, inviável de atacar. Recomendado. |
| 12 palavras | 132 bits | Pior para digitar | Margem enorme; permitiria Argon2id leve. Exagero para um segredo que só autoriza entrada. |
| QR com 128+ bits e palavras com 88 | misto | Complica | Dois segredos diferentes para o mesmo convite: descartado. |

**Proposta:** 8 palavras, QR com o mesmo segredo, Argon2id com parâmetros iniciais m = 64 MiB, t = 3, p = 1 (ajustar para ≤ 1,5 s no aparelho de referência; se 64 MiB for pesado em 2 GB de RAM, reduzir m e aumentar t). Normalização: Unicode NFKD, remover acentos, minúsculas, espaços múltiplos → um, aceitar prefixo de 4 letras (único na lista). Gerar bits diretamente do CSPRNG (sem módulo). Sem checksum: palavra inválida já é detectada localmente pela lista.

### D5 — Lista de palavras

BIP39 português, verificada: 2048 palavras, sem acentos, prefixos de 4 letras únicos, nenhum par a distância de edição 1. **Pendências:** (1) confirmar licença do repositório `bitcoin/bips` para a lista; (2) revisão manual de palavras ofensivas ou constrangedoras (troca exige manter as propriedades acima e documentar a lista derivada); (3) a associação com carteiras de criptomoeda pode confundir usuários ("isto é uma carteira?"): o texto da tela deve deixar claro que é só a chave da conversa.

### D6 — Limite de participantes

Medir na Fase 5: tamanho do `Welcome`, tempo de processamento de commit e memória com 2, 10, 25, 50 e 100 participantes no aparelho de referência. Ponto de partida: 50. O servidor aplica o teto e recusa entradas com erro explícito; os clientes também recusam adicionar além do teto. **Conflito com P5: precisa da sua decisão.**

### D7 — Trancar a sala

Ação "Trancar entrada" no menu do chat, disponível a qualquer participante. Efeito: o cliente envia uma mensagem MLS de controle "trancada" (todos passam a recusar pedidos) e avisa o servidor para recusar pedidos novos. Não tem volta. Aviso de sistema: "Alguém trancou a entrada. Ninguém novo pode entrar." **Risco:** um participante pode trancar contra a vontade dos demais (só impede entradas novas). **Recomendação:** incluir na v1, pois é a única mitigação para chave vazada sob P4.

### D8 — Remoção de participantes

v1 sem administração: ninguém remove ninguém. Existem só (1) saída própria e (2) remoção automática de quem desconectou e não voltou dentro da janela de D9. "Bloquear" = sair na hora (3.5). Não prometer que impede a pessoa de voltar com o convite.

### D9 — Reconexão

O estado MLS fica na RAM do processo. **Queda de rede com o app aberto:** o servidor guarda até 60 s de mensagens cifradas destinadas àquela folha (limite também em bytes, por exemplo 1 MiB); ao voltar, o cliente recebe a fila em ordem. **Processo morto pelo sistema:** o estado se perde; a pessoa só volta como participante novo (se a chave ainda vale e ela a digitar de novo) e não recupera mensagens anteriores. Sem a fila, perder um único commit tornaria o estado irrecuperável. Consequência para a interface: não usar o fato "0 mensagens guardadas no servidor".

### D10 — Tamanho máximo de frame

Mensagem de aplicação: 1000 caracteres ocupam no máximo 4000 bytes em UTF-8; com cabeçalho e assinatura MLS, limite proposto de 8 KiB. Mensagens de controle (`Welcome` cresce com N): limite a definir após medição de D6 (estimativa de 256 KiB para 50 participantes, **a confirmar**).

### D11 — Limitação por IP

Contadores em RAM indexados por HMAC(IP) com chave aleatória gerada na inicialização e trocada a cada hora; janela de 10 minutos; nunca gravados em disco ou log. Limites iniciais: conexões simultâneas por IP, criações de sala por minuto, pedidos de entrada por minuto. **Jurídico:** o Marco Civil (art. 15) obriga guarda de registros de acesso por 6 meses para provedores de aplicação constituídos como pessoa jurídica com fins econômicos; se o projeto se enquadra ou não precisa de parecer (juridico.md). A documentação não pode dizer "não coletamos IP".

### D12 — Metadados

TLS 1.3 no lançamento. A política de privacidade e a tela Sobre dizem o que o servidor vê (IP, horário, volume, tamanho, número de conexões por sala). Proxy embutido ou Tor ficam para avaliação depois do lançamento (custo de manutenção e de bateria).

### D13 — Cópia do convite

Permitir copiar depois de aviso ("Quem tiver estas palavras pode entrar na conversa. Outros apps e a sincronização da área de transferência podem ler o que você copia."). Android 13+: marcar o `ClipData` como sensível (`ClipDescription.EXTRA_IS_SENSITIVE`) para ocultar a prévia. Limpeza: 60 s depois, **somente** se o app estiver em primeiro plano e o conteúdo ainda for o convite copiado (Android 10+ não deixa ler a área de transferência em segundo plano; ler pode exibir o aviso do sistema). Documentar que a limpeza não é garantida.

### D14 — Fixação de certificado

Não fixar no lançamento. O conteúdo já é protegido pelo MLS contra um servidor ou intermediário malicioso; o TLS protege metadados e `room_id`. Fixar certificado com renovação automática (Let's Encrypt via Caddy) pode deixar todos os apps sem conexão se a chave mudar, e celulares sem atualização ficariam inutilizáveis. Reavaliar com fixação da chave pública (SPKI) e chave reserva se houver ameaça concreta.

### D15 — Licença do aplicativo

Dependências previstas (Flutter BSD-3, OpenMLS MIT, flutter_rust_bridge MIT, RustCrypto MIT/Apache, fontes OFL) são permissivas e compatíveis com todas as opções.

| Opção | App Store | Contribuições | Proteção copyleft |
| --- | --- | --- | --- |
| GPL-3.0 sem CLA | Problemática com vários autores | Simples | Forte |
| GPL-3.0 + CLA | Você pode relicenciar para a loja | Exige CLA (atrito, burocracia) | Forte |
| GPL-3.0 + exceção para lojas | Depende da redação; precisa de advogado | Simples | Forte, com exceção |
| **MPL-2.0** | Usada por apps publicados na App Store | Simples | Por arquivo |
| Apache-2.0 | Sem problema | Simples | Nenhuma |

**Recomendação:** MPL-2.0 (copyleft por arquivo, compatível com as lojas, sem CLA). Decidir antes da primeira contribuição externa.

### D16 — Verificação de idade

A Lei 15.211/2025 (ECA Digital) está em vigor desde 17/03/2026, segundo a imprensa; a regulamentação dos métodos de verificação estava pendente de decreto e da ANPD. A lei também prevê que lojas e sistemas operacionais forneçam um "sinal de idade" aos apps. **Opção a avaliar:** consumir o sinal de idade da loja (Google Play e, depois, Apple), sem pedir documento, sem criar conta e sem armazenar o resultado. **Tudo depende de parecer jurídico** (juridico.md); não implementar antes.

---

## 4. Aparelho de referência

Proposta: **Samsung Galaxy A03 (3 GB) ou Motorola Moto E13 (2 GB, Android Go)**, ambos populares no Brasil, com chip Unisoc. O E13 testa o pior caso (2 GB, Android Go, possível userspace de 32 bits, que exige o alvo Rust `armv7-linux-androideabi`). Escolha final depende de qual aparelho físico você tem ou pode comprar. Sem aparelho físico, as medições de D4, D6 e D10 e o teste de `FLAG_SECURE` ficam pendentes.
