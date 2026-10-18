# Política de privacidade — RASCUNHO

> **Rascunho de 18/10/2026, não publicado.** Escrito a partir do comportamento real do app e do servidor planejados para a primeira versão. Precisa de revisão jurídica ([juridico.md](juridico.md)) e de atualização quando as decisões D9, D11, D12 e D16 forem aprovadas. Trechos entre [colchetes] são pendências.

---

## Política de privacidade do Nenures

Última atualização: [data da publicação]

O Nenures é um app de conversas temporárias, sem cadastro, mantido por [nome do controlador: pessoa física ou associação], sem fins lucrativos e sem anúncios. Esta política explica quais dados passam pelo serviço, por quanto tempo e para quê.

### 1. O que não coletamos

- Não pedimos nome, foto, telefone, e-mail nem nome de usuário. Não existe conta.
- Não acessamos seus contatos, sua localização, seus arquivos nem seu microfone.
- Não usamos ferramentas de análise de uso, publicidade, rastreamento ou relatório de falhas de terceiros.
- Não enviamos notificações. Por isso, você só recebe mensagens com o app aberto.

### 2. Suas mensagens

- As mensagens são cifradas no seu aparelho antes de sair dele. O servidor repassa as mensagens cifradas e não tem as chaves para lê-las.
- O app não grava a conversa no celular. Ao sair, ele descarta as mensagens da memória do aparelho.
- Se a sua conexão cair, o servidor guarda as mensagens cifradas destinadas a você por até [60 segundos, D9], só para entregá-las quando você voltar.
- Quando a última pessoa sai, a conversa deixa de existir no servidor.

**O que não conseguimos garantir:** outras pessoas da conversa podem copiar o texto ou fotografar a tela com outro aparelho. Não conseguimos apagar essas cópias, nem o que o teclado, a área de transferência ou outros apps do seu celular guardaram. Um celular com programa malicioso pode ler a conversa.

### 3. O que o servidor vê para funcionar

Para repassar mensagens, o servidor processa:

| Dado | Para quê | Por quanto tempo |
| --- | --- | --- |
| Endereço IP da conexão | Manter a conexão e entregar mensagens | Enquanto a conexão estiver aberta |
| [Versão protegida do IP (HMAC com chave que muda a cada hora), D11] | Limitar abusos, como excesso de conexões | [Até 10 minutos, só na memória] |
| Horários, tamanho e volume do tráfego, número de conexões em cada conversa | Funcionamento do serviço | Enquanto a conversa existir, só na memória |
| Um identificador da conversa derivado da chave (não é a chave) | Encontrar a conversa certa | Enquanto a conversa existir, só na memória |

O servidor não grava esses dados em disco e não mantém registros de acesso. Reiniciar o servidor apaga todas as conversas em andamento. [Confirmar com o parecer sobre o art. 15 do Marco Civil.]

O provedor de hospedagem [nome, país] e os provedores de internet também podem ver o seu IP e o volume do tráfego. Isso está fora do nosso controle. O Nenures não oferece anonimato de rede: quem precisa esconder o próprio IP deve usar ferramentas próprias para isso.

### 4. Denúncias

Se você tocar e segurar uma mensagem e escolher **Denunciar**, o app mostra exatamente o que será enviado e só envia depois que você confirmar. A denúncia:

- contém só o texto que você confirmou [e o motivo escolhido];
- não inclui o seu IP de forma associada à denúncia, o identificador da conversa nem o histórico;
- fica guardada por até [30 dias], com acesso restrito a quem modera, e depois é apagada.

Não conseguimos confirmar que o texto denunciado foi realmente enviado na conversa. Denúncias com indício de crime podem ser comunicadas às autoridades, conforme a lei [procedimento em revisão jurídica].

### 5. Suporte

Se você nos escrever em [e-mail], usaremos o seu e-mail e a sua mensagem só para responder. [Prazo de retenção a definir.]

### 6. Idade

O Nenures é classificado para maiores de 18 anos. [Mecanismo de verificação de idade a definir, D16.]

### 7. Seus direitos (LGPD)

Você pode pedir informações sobre o tratamento, correção ou exclusão de dados pelo canal [e-mail]. Como não existe conta, na maioria dos casos não temos como associar dados a você; explicaremos isso na resposta.

### 8. Código aberto

O código do app e do servidor é público em https://github.com/Mayconmx/Nenures, para que qualquer pessoa possa verificar o que está descrito aqui.

### 9. Mudanças

Mudanças nesta política serão publicadas aqui e no repositório, com a data de atualização.

### 10. Contato

[Controlador, endereço eletrônico do canal de titulares.]
