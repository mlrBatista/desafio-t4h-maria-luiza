# Comparação dos índices de `banco/03-indices.sql`

Fontes (todos os números abaixo vêm destes arquivos):

- **Antes** (só as chaves primárias): [explain-rotas.txt](explain-rotas.txt), gerado pelo [explain-rotas.sql](explain-rotas.sql) em 2026-11-04.
- **Depois** (os 6 índices): [20261105-depois-indices/com-todos.txt](20261105-depois-indices/com-todos.txt).
- **Sem um índice** (só aquele removido, dentro de uma transação com `ROLLBACK`): `20261105-depois-indices/sem-<índice>.txt`.
- Uso, tamanho e extensões: `uso-indices.txt`, `tamanho-indices.txt` e `extensoes.txt`, na mesma pasta.
- Script: [diagnosticar-indices.sh](diagnosticar-indices.sh). Ele rodou 2 vezes cada situação e guardou a 2ª. Ao final, `verificacao.txt` confirma que os índices ficaram intactos.

> **Os tempos abaixo são de consultas isoladas, sem carga, e não substituem os números do `medir.sh`.**
> O ruído entre execuções é grande. O mesmo plano deu 166.909 ms (`com-todos.txt`) e 19.819 ms (`sem-idx_produtos_nome_trgm.txt`) na contagem de pedidos por status, e 1006.386 ms contra 425.328 ms em `vendas-por-dia`. Por isso, **a mudança de plano é a evidência confiável; o tempo só conta quando a diferença é de ordem de grandeza.**
> O "antes" vem de uma execução em outro dia e roda uma única vez, então a comparação com o "depois" tem esse viés.

## Consulta por consulta

| Consulta | Rota | Índice usado | Plano antes → depois | Tempo antes → depois | Linhas descartadas antes → depois |
| --- | --- | --- | --- | --- | --- |
| `clientes` por `lower(email)` | `GET /clientes?email=` | `idx_clientes_email_lower` | Seq Scan → Index Scan | 33.259 ms → 0.265 ms | 99999 → não aparece no plano |
| `clientes` por id | `GET /clientes/:id` | `clientes_pkey` (já existia) | Index Scan → Index Scan | 0.022 ms → 0.036 ms | não aparece no plano |
| `pedidos` por `cliente_id` | `GET /clientes/:id/pedidos` | `idx_pedidos_cliente_id` | Parallel Seq Scan → Index Scan | 30.094 ms → 0.080 ms | 166665 → não aparece no plano |
| `itens_pedido` por `pedido_id` (1x por pedido) | `GET /clientes/:id/pedidos` | `idx_itens_pedido_pedido_id` | Parallel Seq Scan → Index Scan | 177.644 ms → 0.032 ms | 500000 → não aparece no plano |
| `count(*)` por status | `GET /pedidos` | `idx_pedidos_status_criado_em` | Parallel Seq Scan → Parallel Index Only Scan | 203.020 ms → 166.909 ms | 66667 → não aparece no plano |
| página 1 por status | `GET /pedidos` | `idx_pedidos_status_criado_em` | Parallel Seq Scan + top-N heapsort → Index Scan (sem Sort) | 195.817 ms → 0.177 ms | 66667 → não aparece no plano |
| busca `ILIKE` em `produtos.nome` | `GET /produtos/busca` | `idx_produtos_nome_trgm` | Seq Scan → Bitmap Heap Scan + Bitmap Index Scan | 12.778 ms → 4.999 ms | 19000 → não aparece no plano |
| `vendas-por-dia` | `GET /relatorios/vendas-por-dia` | `idx_pedidos_criado_em_dia` | Parallel Seq Scan em `pedidos` → Parallel Bitmap Heap Scan (`itens_pedido` continua em Seq Scan) | 593.773 ms → 1006.386 ms | 160305 → 706 |
| `top-produtos` | `GET /relatorios/top-produtos` | `idx_pedidos_status_criado_em` | Parallel Seq Scan em `pedidos` → Parallel Index Only Scan (`itens_pedido` e `produtos` continuam em Seq Scan) | 2910.308 ms → 5335.119 ms | 16667 → 16667 |

`Heap Fetches` na contagem de pedidos por status: **0**. O `top-produtos` também mostra `Heap Fetches: 0`.

## O que cada índice mudou (comparando "sem só ele" com "todos")

Tempos de `com-todos.txt` contra o arquivo `sem-<índice>.txt`, da mesma sessão.

| Índice | Consulta afetada | Plano sem o índice → com | Tempo sem → com |
| --- | --- | --- | --- |
| `idx_clientes_email_lower` | `clientes?email=` | Seq Scan → Index Scan | 41.104 ms → 0.265 ms |
| `idx_pedidos_cliente_id` | pedidos do cliente | Seq Scan → Index Scan | 71.750 ms → 0.080 ms |
| `idx_itens_pedido_pedido_id` | itens de um pedido | Seq Scan → Index Scan | 146.342 ms → 0.032 ms |
| `idx_pedidos_status_criado_em` | página 1 por status | Seq Scan → Index Scan | 373.488 ms → 0.177 ms |
| `idx_pedidos_status_criado_em` | `count(*)` por status | Seq Scan → Parallel Index Only Scan | 172.672 ms → 166.909 ms |
| `idx_produtos_nome_trgm` | busca por nome | Seq Scan → Bitmap Index Scan | 6.917 ms → 4.999 ms |
| `idx_pedidos_criado_em_dia` | `vendas-por-dia` | Seq Scan em `pedidos` + `idx_itens_pedido_pedido_id` → Bitmap Index Scan em `pedidos` + Seq Scan em `itens_pedido` | 498.194 ms → 1006.386 ms |

## Leitura

- **Mais efeito:** `idx_pedidos_status_criado_em` na página 1 (373.488 ms → 0.177 ms), `idx_itens_pedido_pedido_id` (146.342 ms → 0.032 ms por pedido) e `idx_pedidos_cliente_id` (71.750 ms → 0.080 ms). O índice de itens roda 1 vez por pedido do cliente.
- **Efeito pequeno ou nulo no tempo isolado:**
  - `idx_pedidos_status_criado_em` na contagem: o plano virou Index Only Scan com `Heap Fetches: 0`, mas o tempo (172.672 ms → 166.909 ms) está dentro do ruído. A contagem ainda percorre ~100000 linhas por worker (`rows=100000 loops=3`).
  - `idx_produtos_nome_trgm`: o plano usa o índice (Bitmap Index Scan), mas `produtos` tem só 20000 linhas e a diferença é de poucos milissegundos.
- **Possivelmente prejudicial:** `idx_pedidos_criado_em_dia` em `vendas-por-dia`. Com o índice o plano troca o Seq Scan de `pedidos` por um Bitmap Heap Scan e mantém um Seq Scan em `itens_pedido`; sem o índice o planejador usa `idx_itens_pedido_pedido_id`. O tempo ficou maior com o índice (498.194 ms sem → 1006.386 ms com), mas o mesmo plano com o índice deu 425.328 ms em `sem-idx_produtos_nome_trgm.txt`. Com esse ruído o tempo isolado é **inconclusivo**; só o `medir.sh` com e sem o índice resolve.
- **`top-produtos`:** o índice de status entra como Index Only Scan (`Heap Fetches: 0`), mas as demais linhas (`Seq Scan on itens_pedido`) seguem no plano e o tempo não melhorou (2910.308 ms → 5335.119 ms; sem o índice, 4632.579 ms). Um índice simples não resolve essa consulta.
- **`pg_trgm`:** extensão instalada (versão 1.6, em `extensoes.txt`) e usada na busca (`Bitmap Index Scan on idx_produtos_nome_trgm`).

## Índices que nenhuma consulta usou

Nenhum dos 6 índices de `03-indices.sql` ficou sem uso: todos aparecem com `idx_scan` maior que 0 em `uso-indices.txt`. O único com `idx_scan` igual a 0 é `itens_pedido_pkey`, que não é de `03-indices.sql`. `stats_reset` está vazio, ou seja, os contadores acumulam desde a criação do banco (incluem as medições `02-indices` e as verificações de contrato).

## Uso e tamanho

| Índice | Tabela | Tamanho | `idx_scan` | `idx_tup_read` |
| --- | --- | --- | --- | --- |
| `idx_pedidos_status_criado_em` | `pedidos` | 21 MB (22118400 bytes) | 935 | 76340040 |
| `idx_itens_pedido_pedido_id` | `itens_pedido` | 21 MB (22003712 bytes) | 700936 | 2101722 |
| `idx_pedidos_cliente_id` | `pedidos` | 5720 kB (5857280 bytes) | 468 | 2340 |
| `idx_clientes_email_lower` | `clientes` | 4792 kB (4907008 bytes) | 350 | 346 |
| `idx_pedidos_criado_em_dia` | `pedidos` | 3552 kB (3637248 bytes) | 196 | 775654 |
| `idx_produtos_nome_trgm` | `produtos` | 1144 kB (1171456 bytes) | 373 | 522331 |

## O que este diagnóstico não mostra

- O ganho de vazão ou latência de cada índice sob carga. As medições do `medir.sh` (`02-indices`) mostram o efeito do conjunto, não de cada índice.
- O custo de escrita dos índices. A carga é só de leitura.
