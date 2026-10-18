# Operação — Nenures

Versão 1 · 18/10/2026 · Fase 3 (rascunho)
Estado: **o procedimento de conteúdo ilegal depende de parecer jurídico** ([juridico.md](juridico.md), seção 5). A configuração do servidor e a implantação entram na Fase 4.

---

## 1. Fila de denúncias (Fase 7)

- Armazenamento separado das salas, cifrado em repouso.
- Retenção máxima de 30 dias; uma tarefa diária apaga as mais antigas. A exclusão é verificada por teste.
- Acesso só para quem modera, com autenticação forte. Cada acesso fica registrado, sem copiar o conteúdo para o registro.
- A denúncia não inclui IP, identificador de sala nem histórico.
- O conteúdo denunciado **não é verificável**: quem denuncia pode ter inventado o texto. Nenhuma decisão deve tratá-lo como prova.

## 2. Denúncia com indício de crime — procedimento proposto

**Pendente de revisão jurídica. Não aplicar antes do parecer.**

1. **Não redistribuir.** Não encaminhar, copiar, imprimir nem mostrar o conteúdo a ninguém fora de quem modera.
2. **Restringir o acesso.** Marcar a denúncia como "possível crime", bloquear a exclusão automática pelo prazo que o parecer definir e limitar o acesso a uma pessoa responsável.
3. **Preservar só o necessário:** o texto denunciado, a data e a hora de recebimento e o motivo escolhido. Não há outros dados para preservar, porque o sistema não os coleta.
4. **Comunicar às autoridades** pelo canal que o parecer indicar. Candidatos a confirmar: a Central Nacional de Denúncias da SaferNet (conveniada ao MPF), a Polícia Federal e o centro nacional mencionado na regulamentação do ECA Digital.
5. **Registrar** a comunicação: data, órgão e protocolo, sem copiar o conteúdo para o registro.
6. **Apagar** quando o prazo de preservação terminar ou quando a autoridade orientar.
7. **Cuidar de quem modera:** contato com material de abuso causa dano psicológico. Limitar a exposição e prever apoio.

**Limitação:** sem identificação de usuários, sem registros de acesso e com conteúdo cifrado, o projeto não tem como identificar autores. A comunicação às autoridades informa isso.

## 3. Pedidos de autoridades

- Toda requisição de dados exige ordem judicial (Marco Civil, art. 10 e art. 15, § 3º; confirmar com o parecer).
- Resposta padrão: descrever o que o sistema guarda (seção 3 de [privacidade.md](privacidade.md)), ou seja, quase nada, e por quanto tempo.
- Registrar cada pedido: data, órgão, processo e resposta.
- Publicar periodicamente um relatório de transparência com números agregados. [Proposta: anual.]

## 4. Registros do servidor (Fase 4)

- Sem registro por requisição. Nunca registrar IP, convite, `room_id` ou conteúdo.
- Métricas só agregadas (por exemplo, número de salas ativas).
- Logs do proxy TLS desligados.
- Reiniciar o servidor encerra todas as salas; avisar isso na página de status.

## 5. A fazer nas próximas fases

- Implantação, TLS, atualização e recuperação (Fase 4).
- Suporte: e-mail, prazo de resposta e retenção (Fase 7).
- Relatório de transparência (antes da Fase 9).
