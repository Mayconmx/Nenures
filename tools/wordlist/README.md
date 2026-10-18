# Lista de palavras do convite (D5)

`nenures-pt-v1.txt`: 2048 palavras, 11 bits cada; 8 palavras = 88 bits (D4).

**Origem:** lista BIP-39 em português, `bitcoin/bips` → `bip-0039/portuguese.txt`, baixada em 18/10/2026, sha256 `2685e9c194c82ae67e10ba59d9ea5345a23dc093e92276fc5361f6667d79cd3f`. A BIP-39 declara licença MIT.

**Lista derivada:** sha256 `0da77bafff27163c15479538090468c8ecfc8c21f9b4061d8a8b0f9cc3637564`.

## Por que foi alterada

A chave é compartilhada entre pessoas. 39 palavras foram trocadas na revisão manual de 18/10/2026 (`trocas.json`):

- sexuais ou sugestivas (ex.: orgasmo, nudez, vibrador);
- usadas como ofensa racial ou homofóbica no Brasil (ex.: macaco, crioulo, veado);
- usadas como estigma (autismo, bipolar);
- armas e violência (ex.: pistola, granada, sangue);
- gíria de droga (baseado).

Cada palavra foi trocada **na mesma posição**, então a correspondência índice ↔ palavra das demais não muda.

## Propriedades verificadas

- 2048 palavras distintas, só letras ASCII minúsculas, de 4 a 8 letras;
- prefixos de 4 letras todos distintos (digitar só o começo basta);
- nenhum par de palavras a distância de edição 1 (um erro de digitação não vira outra palavra válida).

Estas propriedades também são verificadas por teste na biblioteca Rust do app.

## Regerar

Os comandos e a lista de trocas estão em `trocas.json`; mudar a lista é uma mudança incompatível (convites antigos deixam de valer) e exige nova versão do arquivo (`-v2`).
