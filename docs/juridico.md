# Pendências jurídicas — Nenures

Versão 1 · 18/10/2026 · Fase 3
Estado: **nenhum ponto está resolvido.** Este documento lista o que precisa de parecer de advogado(a) de direito digital antes da publicação (Fases 9 e 10). Ele não é parecer jurídico e não substitui um.

Cada item tem: o que sabemos (com fonte e data da consulta), como o app se comporta hoje e as perguntas para o(a) advogado(a). Quando houver parecer, registrar abaixo do item: data, quem emitiu e conclusão.

---

## 1. Fatos do sistema que importam para a análise

| Dado | Onde | Por quanto tempo | Situação |
| --- | --- | --- | --- |
| Endereço IP | Servidor (conexão) e proxy TLS | Duração da conexão; se D11 for aprovada, HMAC do IP em RAM por até ~10 min | Planejado (Fase 4) |
| Horários, volume e tamanho do tráfego, número de conexões por sala | Servidor | Duração da sala, em RAM | Planejado |
| Identificador de sala (`room_id`, derivado do convite) | Servidor | Duração da sala, em RAM | Planejado |
| Mensagens cifradas | Servidor | Só retransmissão; até 60 s na fila de reconexão (D9) | Planejado |
| Texto das mensagens | Só nos aparelhos, em RAM | Até a pessoa sair | Implementado (sem rede) |
| Denúncias confirmadas (texto escolhido pela pessoa) | Armazenamento separado no servidor | Até 30 dias | Fase 7 |
| Contato de suporte (e-mail de quem escreve) | Caixa de e-mail do projeto | A definir | Fase 7 |
| Cadastro, nome, telefone, e-mail, foto, localização, contatos | — | — | **Não coletados** (P1) |
| Analytics, publicidade, crash reporting de terceiros | — | — | **Não usados** (10.1; o leitor de QR com ML Kit foi recusado por isso, D17) |

Limitações que o app não controla: provedor de hospedagem, provedores de rede, lojas de aplicativos, sistema operacional e teclado.

---

## 2. LGPD (Lei 13.709/2018)

**O que sabemos**
- IP, dados de denúncia e e-mail de suporte são dados pessoais. O conteúdo cifrado que o servidor não consegue ler também pode ser considerado tratamento de dados pessoais, ainda que o projeto não tenha acesso ao conteúdo.
- A Resolução CD/ANPD nº 2/2022 (agentes de tratamento de pequeno porte) inclui pessoas naturais e pessoas jurídicas sem fins lucrativos e dispensa a indicação de encarregado, exigindo um canal de comunicação com titulares, salvo tratamento de alto risco (art. 3º). Fontes consultadas em 18/10/2026: análises de Felsberg Advogados e Mayer Brown; texto vigente não conferido.

**Perguntas**
1. Quem é o controlador: a pessoa física que mantém o projeto, ou é preciso constituir uma associação antes de publicar?
2. Quais bases legais se aplicam a: (a) IP e metadados de conexão para operar o serviço; (b) limitação de abuso por IP (D11); (c) denúncias; (d) suporte?
3. O projeto se enquadra como agente de pequeno porte? O tratamento é de "alto risco" (art. 3º da Resolução 2/2022), por exemplo pela possibilidade de uso por adolescentes ou pela natureza das conversas, o que exigiria encarregado?
4. Qual canal de titulares é suficiente (e-mail dedicado basta)?
5. Como responder a pedidos de titulares se o projeto não tem como identificar ninguém (não há conta)?
6. Hospedagem fora do Brasil configura transferência internacional? Que cláusulas ou avisos são necessários?
7. Incidentes de segurança: qual o procedimento simplificado aplicável e em que prazo?

---

## 3. Marco Civil da Internet (Lei 12.965/2014)

**O que sabemos**
- O art. 15 obriga o provedor de aplicações **constituído na forma de pessoa jurídica**, que exerça a atividade **de forma organizada, profissionalmente e com fins econômicos**, a guardar registros de acesso a aplicações por 6 meses, sob sigilo. Fontes consultadas em 18/10/2026: texto do art. 15 reproduzido em modeloinicial.com.br e material da Escola Superior do MPU; análise da Mozilla (2014) sobre serviços sem fins econômicos.
- O art. 15, § 1º, permite que ordem judicial obrigue provedores não enquadrados no *caput* a guardar registros por tempo certo.

**Situação do Nenures:** pessoa física, sem fins econômicos, sem anúncios. O desenho atual **não guarda** registros de acesso (D11 prevê só contadores em RAM).

**Perguntas**
1. O projeto, como pessoa física ou como associação sem fins lucrativos, está fora do *caput* do art. 15?
2. Se depois virar associação ou receber doações recorrentes, isso muda o enquadramento ("fins econômicos", "profissionalmente")?
3. Diante de uma ordem judicial de guarda futura (art. 15, § 1º), o que o projeto consegue cumprir tecnicamente e como documentar isso?
4. A ausência de registros pode gerar responsabilidade civil quando houver ordem de identificação de usuário?

---

## 4. ECA Digital (Lei 15.211/2025)

**O que sabemos** (fontes consultadas em 18/10/2026: página "ECA Digital" da ANPD; Agência Brasil, 03/2026; cartilha Demarest, 03/2026)
- Em vigor desde 17/03/2026. Aplica-se a produtos e serviços de TI direcionados a crianças e adolescentes **ou de acesso provável** por eles.
- A autodeclaração de idade deixa de ser suficiente. A ANPD é a autoridade responsável (Decreto 12.622/2025) e publicou orientações preliminares (03/2026) e uma proposta de "Guia Orientativo — Mecanismos de Aferição de Idade" (05/2026), ainda em atualização.
- O Decreto 12.880/2026 detalhou a lei e criou a Política Nacional de Proteção dos Direitos da Criança e do Adolescente no Ambiente Digital. Uma fonte jornalística menciona um centro nacional ligado à Polícia Federal para centralizar denúncias de crimes identificados pelas plataformas. **Não confirmado no texto oficial.**
- Lojas e sistemas operacionais devem fornecer um "sinal de idade" aos apps.

**Situação do Nenures:** classificação 18+ nas lojas (P11), sem cadastro (P1), conversas entre desconhecidos possíveis, sem moderação de conteúdo (é cifrado). Proposta técnica em D16: usar o sinal de idade da loja, sem documentos.

**Perguntas**
1. Um app de mensagens anônimo e classificado como 18+ é de "acesso provável" por adolescentes?
2. Se for, qual mecanismo de aferição de idade é aceitável sem criar cadastro (P1)? O sinal de idade da loja basta?
3. Quais obrigações valem para um projeto sem fins lucrativos mantido por pessoa física? Há regime diferenciado por porte ou risco?
4. Há dever de comunicar às autoridades conteúdo de abuso sexual infantil recebido por denúncia? A qual órgão, em que prazo e em que formato?
5. Que ferramentas mínimas de segurança (denúncia, bloqueio, avisos) a lei exige para este tipo de serviço?

---

## 5. Conteúdo ilegal e denúncias

**O que sabemos**
- A SaferNet mantém a Central Nacional de Denúncias, em convênio com o Ministério Público Federal (fonte jornalística, 02/2026).
- O procedimento operacional proposto está em [operacao.md](operacao.md), marcado como pendente.
- Limite técnico: o servidor não consegue confirmar que o texto denunciado foi enviado na conversa (sem *message franking*). Quem denuncia pode inventar o conteúdo.

**Perguntas**
1. Qual o procedimento correto ao receber uma denúncia com indício de abuso sexual infantil: a quem comunicar (SaferNet, MPF, Polícia Federal, centro previsto no ECA Digital) e em que prazo?
2. O que pode e o que deve ser preservado, por quanto tempo e com que controle de acesso, sem que a própria guarda configure crime (posse de material)?
3. A retenção de denúncias por até 30 dias é adequada? Precisa ser mais curta ou mais longa?
4. Qual a responsabilidade do projeto se uma denúncia não puder ser verificada?

---

## 6. Termos de uso e política de privacidade

Rascunhos baseados no comportamento real: [privacidade.md](privacidade.md) e [termos-de-uso.md](termos-de-uso.md).

**Perguntas**
1. Os rascunhos estão adequados ao CDC, à LGPD e ao ECA Digital?
2. Que cláusulas de limitação de responsabilidade são válidas para um serviço gratuito sem fins lucrativos?
3. Qual foro e qual lei aplicável indicar?
4. Os textos podem ser publicados num repositório público (GitHub Pages) ou precisam de domínio próprio?

---

## 7. Forma jurídica

| Opção | Prós | Contras |
| --- | --- | --- |
| Pessoa física | Simples; sem custos de constituição | Responsabilidade pessoal ilimitada; dados pessoais do mantenedor aparecem na loja (Play exige nome e endereço para contas pessoais, a confirmar) |
| Associação sem fins lucrativos | Separa a responsabilidade; facilita doações e parcerias; conta de organização na Play não exige o teste fechado de 12 pessoas | Custos e obrigações (estatuto, assembleia, contabilidade, CNPJ) |

**Perguntas**
1. Qual forma é recomendável antes da publicação, considerando responsabilidade, doações e lojas?
2. Como receber doações em cada caso (e tributação)?
3. A publicação na Play como pessoa física expõe dados pessoais do mantenedor? Isso é desejável para um app de privacidade?

---

## 8. Licença do aplicativo (D15)

Análise técnica em [licencas-terceiros.md](licencas-terceiros.md) e [decisoes/decisoes-pendentes.md](decisoes/decisoes-pendentes.md) (D15).

**Perguntas**
1. A GPL-3.0 é compatível com os termos da App Store para um projeto com vários autores? Uma exceção para lojas resolveria?
2. A MPL-2.0 atende ao objetivo de manter o código aberto?
3. É necessário um acordo de contribuição (CLA ou DCO) desde já?

---

## 9. Registro de pareceres

| Data | Item | Quem emitiu | Conclusão |
| --- | --- | --- | --- |
| — | — | — | Nenhum parecer registrado |

---

## Fontes (consultadas em 18/10/2026)

- ANPD, ECA Digital: https://www.gov.br/anpd/pt-br/assuntos/eca-digital
- Agência Brasil, "ECA Digital começa a valer nesta terça": https://agenciabrasil.ebc.com.br/politica/noticia/2026-03/eca-digital-comeca-valer-nesta-terca-confira-principais-pontos
- Demarest, cartilha ECA Digital: https://www.demarest.com.br/wp-content/uploads/2026/03/Cartilha-ECA-Digital_V2.pdf
- Marco Civil, art. 15: https://modeloinicial.com.br/lei/27460/marco-civil-internet/art-15
- Mozilla, análise do Marco Civil (2014): https://blog.mozilla.org/press-br/2014/03/26/marco-civil-uma-vitoria-historica-embora-nao-perfeita-para-os-internautas-brasileiros/
- Resolução CD/ANPD nº 2/2022, análises: https://www.felsberg.com.br/?p=39730 e https://www.mayerbrown.com/-/media/files/perspectives-events/publications/2022/02/regulation-for-the-application-of-the-general-data-protection-law-lgpd-for-small-business-data-processing-agents/legal-update--regulamento-agentes-de-pequeno-porte.pdf
- SaferNet, Central Nacional de Denúncias (via Movimento Econômico, 02/2026): https://movimentoeconomico.com.br/internet/2026/02/10/safernet-denuncias-de-crimes-ciberneticos-crescem-28-em-2025/
- Google Play, teste fechado para contas pessoais: https://support.google.com/googleplay/android-developer/answer/14151465
- Google ML Kit, divulgação de dados: https://developers.google.com/ml-kit/android-data-disclosure

Os textos oficiais (Planalto, DOU, ANPD) devem ser conferidos pelo(a) advogado(a); várias fontes acima são secundárias.
