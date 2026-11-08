# Experimentos

Registro de cada mudança aplicada na aplicação, com a hipótese, a fonte da ideia, a medição antes e depois e a conclusão. As ideias pesquisadas que não foram testadas estão em [proximos-testes.md](proximos-testes.md).

## Como ler esta página

- **Todo número vem de `resultados/`**, gerado por `scripts/medir.sh` com os mesmos parâmetros em todas as execuções: `VUS=20`, `DURACAO=60s`, `SEMENTE=42`, aquecimento de 15 s. Os parâmetros e o commit de cada execução estão no `contexto.txt` de cada pasta.
- **Cada valor é a mediana das 3 execuções** do mesmo rótulo, não a melhor. Para os tempos, é a mediana das 3 medianas, dos 3 p95 e dos 3 p99 de cada execução.
- **CPU e memória** são as médias de cada execução no `recursos.txt` (100% = 1 CPU inteira), também pela mediana das 3. Limites, iguais em todas as medições: API com 0,5 CPU e 256 MB, banco com 1 CPU e 512 MB.
- **O pico de CPU da API** (`cpu_max` do `recursos.txt`) não é usado: em várias execuções ele aparece menor que a média, o que é impossível. O `recursos.csv` da mesma pasta mostra amostras bem acima do valor relatado. Não editamos o script (régua do desafio). Quando o pico importa, ele é lido do `recursos.csv`.
- **Contrato:** todas as execuções listadas abaixo terminaram com "Contrato mantido: as 42 respostas são iguais às gravadas" (`contrato.txt` de cada pasta) e registram `arquivos alterados sem commit: 0`.

### Qual "antes" foi usado

- **Mudanças 01 e 02:** o antes é a medição anterior (linha de base e 01-pool), feita na mesma máquina nos dias 03 e 04/11.
- **Mudanças 03 em diante:** o antes é um **controle medido no mesmo dia, logo antes ou logo depois da mudança**, com o código do commit anterior. Motivo: em 07/11, a mesma versão do código mediu 5.96 req/s numa série e 8.60 req/s noutra, com ~40 minutos de diferença, e rotas que a mudança nem tocava ficaram ~3x mais lentas. A máquina (Windows + WSL2, reiniciada naquele dia) variou mais do que o efeito que queríamos medir. Comparar com uma medição de outro dia misturaria o efeito do código com o da máquina. Desde a 04, o controle é medido também **no mesmo banco**, depois do `down -v`, para que a única diferença seja o código.

## Resumo

| # | Mudança | Status | Antes (rótulo) | req/s antes → depois | p95 antes → depois (ms) | CPU banco / API (média) | Conclusão |
|---|---|---|---|---|---|---|---|
| 01 | Pool de conexões | Aplicada e medida | 00-linha-de-base | 1.69 → 2.15 | 38198.7 → 35717.1 | banco 98.5% → 97.8%; API 9.7% → 8.3% | ganho pequeno; o banco continuou no limite |
| 02 | Índices para as consultas das rotas | Aplicada e medida | 01-pool | 2.15 → 9.43 | 35717.1 → 9177.6 | banco 97.8% → 96.1%; API 8.3% → 24.1% | maior ganho até então; o banco seguiu no limite |
| 03 | Fim do N+1 em `/clientes/:id/pedidos` | Aplicada, sem ganho de vazão | 02-indices-hoje (controle) | 8.35 → 8.60 | 10726.4 → 7422.4 | banco 96.2% → 97.4%; API 26.2% → 25.9% | a rota ficou ~2,4x mais rápida, as outras pioraram; vazão igual |
| 04 | Materialized view para `top-produtos` | Aplicada e medida | 03-controle-hoje2 (controle) | 8.27 → 22.06 | 8213.5 → 2312.2 | banco 95.2% → 65.0%; API 23.9% → 46.6% | maior ganho; o gargalo passou para a API |
| 05 | `vendas-por-dia` agregado no SQL | Aplicada, sem ganho de vazão | 05-controle (controle) | 26.59 → 27.07 | 1977.8 → 1812.0 | banco 65.8% → 99.3%; API 46.8% → 11.9% | tirou o trabalho da API; o gargalo voltou para o banco |
| 06 | Materialized view para `vendas-por-dia` | Aplicada e medida | 06-controle (controle) | 29.29 → 53.61 | 1803.0 → 1110.2 | banco 99.7% → 100.2%; API 12.8% → 20.4% | ~1,8x a vazão com a mesma CPU do banco; todas as rotas mais rápidas |

## 01 · Pool de conexões

- **Commit:** `acb136d` (mudança) · resultados em `bbb4d16`.
- **O que mudou:** a API abria um `Client` do `pg` por consulta. Passou a usar um `Pool` (`max: 10`), que reaproveita as conexões ([api/src/db.js](api/src/db.js)).
- **Hipótese:** abrir uma conexão nova a cada consulta custa um handshake com o banco; reaproveitar conexões deve reduzir a latência de todas as rotas e o trabalho do banco.
- **Fonte da ideia:** documentação do node-postgres, *Pooling*: abrir um cliente novo exige um handshake de ~20–30 ms e "incurring this cost every time we want to execute a query would substantially slow down our application" (https://node-postgres.com/features/pooling).
- **Antes:** [00-linha-de-base](resultados/20261103-210235-00-linha-de-base), [2](resultados/20261103-210442-00-linha-de-base), [3](resultados/20261103-210647-00-linha-de-base).
- **Depois:** [01-pool](resultados/20261104-211122-01-pool), [2](resultados/20261104-211319-01-pool), [3](resultados/20261104-211510-01-pool).

| Métrica (mediana das 3) | Antes | Depois |
|---|---|---|
| Requisições/s | 1.69 | 2.15 |
| Mediana geral | 2311.9 ms | 2234.0 ms |
| p95 | 38198.7 ms | 35717.1 ms |
| p99 | 49375.5 ms | 42833.9 ms |
| CPU / memória do banco | 98.5% / 222.5 MiB | 97.8% / 410.4 MiB |
| CPU / memória da API | 9.7% / 29.7 MiB | 8.3% / 33.2 MiB |

- **Conclusão:** ganho real, mas pequeno: o banco seguiu a ~98% de CPU, então o custo das conexões não era o gargalo principal. A memória média do banco quase dobrou, o que é coerente com 10 conexões mantidas abertas (cada uma é um processo do PostgreSQL). Uma verificação durante a carga confirmou as 10 conexões abertas, mas não conseguiu medir a memória de cada uma, então a relação ficou sem confirmação (ver `01-pool-diagnostico` em "Séries que não entram nas comparações"). A rota `cliente` piorou (mediana de 501.5 para 999.0 ms) enquanto as rotas pesadas melhoraram, sinal de que as consultas passaram a disputar o banco ao mesmo tempo.

## 02 · Índices para as consultas das rotas

- **Commit:** `07c8212` (mudança, [banco/03-indices.sql](banco/03-indices.sql)) · diagnóstico antes em `e79194a` · resultados em `ded0ead`.
- **O que mudou:** 6 índices, cada um para o filtro ou a ordenação de uma rota: `lower(email)` em `clientes`; `cliente_id` em `pedidos`; `pedido_id` em `itens_pedido`; `(status, criado_em DESC, id DESC)` em `pedidos`; `criado_em::date` em `pedidos`; trigramas (GIN + `pg_trgm`) em `produtos.nome`.
- **Hipótese:** as consultas das rotas leem as tabelas inteiras (Seq Scan) para achar poucas linhas; índices que casam com cada `WHERE` e `ORDER BY` devem trocar essas leituras por buscas pontuais e reduzir a CPU do banco e a latência.
- **Evidência que originou a ideia:** `EXPLAIN (ANALYZE, BUFFERS)` de cada consulta, com o banco ocioso e só as chaves primárias, em [diagnostico/explain-rotas.txt](diagnostico/explain-rotas.txt): Seq Scan (leitura da tabela inteira) em todas as consultas, menos na de `GET /clientes/:id`, que já usava a chave primária. Exemplos: itens de um pedido em 177.644 ms para achar 1 linha; página 1 de `/pedidos` em 195.817 ms.
- **Fontes:**
  - PostgreSQL 16, *Using EXPLAIN*: com `ANALYZE`, o `EXPLAIN` executa a consulta e mostra as contagens de linhas e os tempos reais de cada nó (https://www.postgresql.org/docs/16/using-explain.html).
  - PostgreSQL 16, *Indexes on Expressions*: índice em `lower(col)` para comparação sem diferenciar maiúsculas (https://www.postgresql.org/docs/16/indexes-expressional.html).
  - PostgreSQL 16, *Indexes and ORDER BY*: com `ORDER BY ... LIMIT n` e um índice na mesma ordem, as n primeiras linhas saem sem ordenar o resto (https://www.postgresql.org/docs/16/indexes-ordering.html).
  - PostgreSQL 16, *pg_trgm*: índices GIN e GiST de trigramas atendem buscas com `LIKE` e `ILIKE` (https://www.postgresql.org/docs/16/pgtrgm.html).
- **Antes:** as 3 pastas de `01-pool` acima.
- **Depois:** [02-indices](resultados/20261104-220255-02-indices), [2](resultados/20261104-220441-02-indices), [3](resultados/20261104-220622-02-indices).
- **Diagnóstico depois:** [diagnostico/comparacao-indices.md](diagnostico/comparacao-indices.md) (plano de cada consulta com e sem cada índice) e [diagnostico/20261105-depois-indices/](diagnostico/20261105-depois-indices/).

| Métrica (mediana das 3) | Antes | Depois |
|---|---|---|
| Requisições/s | 2.15 | 9.43 |
| Mediana geral | 2234.0 ms | 443.5 ms |
| p95 | 35717.1 ms | 9177.6 ms |
| p99 | 42833.9 ms | 16376.0 ms |
| CPU / memória do banco | 97.8% / 410.4 MiB | 96.1% / 412.6 MiB |
| CPU / memória da API | 8.3% / 33.2 MiB | 24.1% / 34.0 MiB |

| Rota (mediana das medianas) | Antes | Depois |
|---|---|---|
| cliente | 999.0 ms | 197.0 ms |
| cliente-por-email | 2133.0 ms | 189.8 ms |
| pedidos-do-cliente | 26782.9 ms | 3327.2 ms |
| pedidos-por-status | 8154.4 ms | 1014.8 ms |
| busca-produtos | 1352.5 ms | 198.7 ms |
| vendas-por-dia | 6593.5 ms | 1871.9 ms |
| top-produtos | 32796.5 ms | 15545.2 ms |

- **Conclusão:** ~4,4x mais requisições/s. O banco continuou a ~96% de CPU porque passou a atender muito mais requisições, e as consultas que agregam tabelas inteiras (`top-produtos`, `vendas-por-dia`, a contagem de `/pedidos`) seguiram caras: índice não evita ler todas as linhas quando a consulta precisa de todas. O diagnóstico depois aponta o `idx_pedidos_criado_em_dia` como suspeito de piorar o plano de `vendas-por-dia`; foi investigado depois (ver 06).

## 03 · Fim do N+1 em `GET /clientes/:id/pedidos`

- **Commit:** `b5fc1f5` (mudança) · resultados válidos em `e75c957`.
- **O que mudou:** a rota fazia 1 consulta para o cliente, 1 para os pedidos, 1 para os itens de **cada** pedido e 1 para o produto de **cada** item (2 + P + I consultas; 22 para um cliente com 5 pedidos de 3 itens). Passou a fazer 3: cliente, pedidos e todos os itens com o nome do produto (`JOIN produtos ... WHERE pedido_id = ANY($1)`), agrupados em JavaScript.
- **Hipótese:** menos idas ao banco por requisição devem baixar a latência da rota (20% da carga) e liberar conexões do pool (10 para 20 VUs) para as outras rotas.
- **Fonte da ideia:** leitura do código ([api/src/rotas.js](api/src/rotas.js)) e o padrão "N + 1 queries problem" descrito no guia do Ruby on Rails, que mostra um laço que gera 1 + N consultas (https://guides.rubyonrails.org/active_record_querying.html#n-1-queries-problem). A consulta nova usa índices e leva 2.714 ms isolada ([diagnostico/20261107-explain-03.txt](diagnostico/20261107-explain-03.txt)).
- **Antes (controle no mesmo dia, código `07c8212`):** [02-indices-hoje](resultados/20261107-204404-02-indices-hoje), [2](resultados/20261107-204555-02-indices-hoje), [3](resultados/20261107-204745-02-indices-hoje).
- **Depois:** [03-consulta-unica-v2](resultados/20261107-205642-03-consulta-unica-v2), [2](resultados/20261107-205837-03-consulta-unica-v2), [3](resultados/20261107-210021-03-consulta-unica-v2).
- **Série descartada:** [03-consulta-unica](resultados/20261107-201604-03-consulta-unica), [2](resultados/20261107-201806-03-consulta-unica), [3](resultados/20261107-202001-03-consulta-unica), medida ~25 min depois de a máquina ligar. Deu 5.96 req/s, e rotas que a mudança não tocava ficaram ~3x mais lentas. O banco e os dados eram os mesmos ([diagnostico/20261107-estado-banco.txt](diagnostico/20261107-estado-banco.txt)). Foi o que motivou o controle no mesmo dia.

| Métrica (mediana das 3) | Antes (controle) | Depois |
|---|---|---|
| Requisições/s | 8.35 | 8.60 |
| Mediana geral | 561.5 ms | 1029.1 ms |
| p95 | 10726.4 ms | 7422.4 ms |
| p99 | 18072.9 ms | 19820.1 ms |
| CPU / memória do banco | 96.2% / 413.9 MiB | 97.4% / 407.7 MiB |
| CPU / memória da API | 26.2% / 35.6 MiB | 25.9% / 36.1 MiB |
| `pedidos-do-cliente` (mediana) | 4103.6 ms | 1724.7 ms |
| `cliente` (mediana) | 206.0 ms | 529.4 ms |

- **Conclusão:** **sem ganho de vazão.** A rota alterada ficou ~2,4x mais rápida e o p95 geral caiu, mas as rotas rápidas e frequentes ficaram ~2,5x mais lentas e a mediana geral piorou. Explicação provável (não medida diretamente): o gargalo era a CPU do banco; o N+1 segurava conexões do pool com consultas minúsculas e, sem querer, limitava quantas consultas pesadas rodavam juntas. Sem ele, mais relatórios disputam a CPU e as consultas rápidas esperam atrás deles. Otimizar o que não é gargalo só mudou a espera de lugar. A mudança foi mantida: o código ficou correto e mais simples, e o ganho dela aparece quando o banco deixa de ser o gargalo.

## 04 · Materialized view para `GET /relatorios/top-produtos`

- **Commit:** `f667498` (mudança, [banco/04-top-produtos.sql](banco/04-top-produtos.sql)) · diagnóstico em `7367a3a` · resultados em `f911c06` e controle em `7cc5a98`.
- **O que mudou:** a agregação de 1,5 milhão de itens por produto passou a ser feita uma vez, na criação do banco, numa materialized view (`top_produtos_mv`, ~19 mil linhas, uma por produto com venda) com índice em `(receita_centavos DESC, id)`. A rota lê a view com o mesmo `ORDER BY` e `LIMIT`.
- **Hipótese:** a rota tem só 2% da carga, mas cada chamada junta e soma ~1,35 milhão de linhas (5335.119 ms isolada em [diagnostico/20261105-depois-indices/com-todos.txt](diagnostico/20261105-depois-indices/com-todos.txt)); lendo o resultado pronto, a CPU do banco deve cair e todas as rotas devem esperar menos.
- **Fonte da ideia:** PostgreSQL 16, *Materialized Views*: a view guarda o resultado "in a table-like form", o acesso "is often much faster", os dados nem sempre estão atuais e são renovados com `REFRESH MATERIALIZED VIEW`; o exemplo da documentação é um resumo de vendas atualizado toda noite (https://www.postgresql.org/docs/16/rules-materializedviews.html). Plano da consulta candidata em [diagnostico/explain-top-produtos-mv.txt](diagnostico/explain-top-produtos-mv.txt).
- **Antes (controle no mesmo banco, código `7367a3a`):** [03-controle-hoje2](resultados/20261107-211945-03-controle-hoje2), [2](resultados/20261107-212132-03-controle-hoje2), [3](resultados/20261107-212321-03-controle-hoje2).
- **Depois:** [04-view-top-produtos](resultados/20261107-211442-04-view-top-produtos), [2](resultados/20261107-211611-04-view-top-produtos), [3](resultados/20261107-211738-04-view-top-produtos).

| Métrica (mediana das 3) | Antes (controle) | Depois |
|---|---|---|
| Requisições/s | 8.27 | 22.06 |
| Mediana geral | 982.1 ms | 712.7 ms |
| p95 | 8213.5 ms | 2312.2 ms |
| p99 | 21533.7 ms | 2870.4 ms |
| CPU / memória do banco | 95.2% / 407.3 MiB | 65.0% / 468.4 MiB |
| CPU / memória da API | 23.9% / 34.6 MiB | 46.6% / 42.3 MiB |
| `top-produtos` (mediana) | 16509.8 ms | 299.3 ms |
| `cliente` (mediana) | 575.9 ms | 361.2 ms |

- **Conclusão:** ~2,7x mais requisições/s e p95 ~3,6x menor, com todas as rotas mais rápidas. O banco saiu do limite e **o gargalo passou para a API**, que encostou no teto de 0,5 CPU (média 46.6%). Custos: a view é uma foto da criação do banco e precisa de `REFRESH` se os dados mudarem (a API só lê, então aqui não fica desatualizada); a memória média do banco subiu ~60 MiB, com pico de 503.3 MiB de 512 MiB. O custo de cada `REFRESH` não aparece nesta carga, que só lê.

## 05 · `GET /relatorios/vendas-por-dia` agregado no SQL

- **Commit:** `5f7aa1a` (mudança) · diagnóstico em `bec9e79` · resultados em `113b84a` e controle em `7fc10df`.
- **O que mudou:** a consulta trazia ~57 mil linhas (uma por item, para 31 dias) e a API agrupava por dia num laço em JavaScript. Passou a agrupar no banco (`GROUP BY` do dia, `count(DISTINCT p.id)`, `sum`), e a API recebe no máximo 31 linhas.
- **Hipótese:** o perfil de CPU da API mostrou que `vendas-por-dia` domina o trabalho dela; agregando no banco, a CPU da API deve cair e a vazão subir, já que a API era o gargalo depois da 04.
- **Evidência que originou a ideia:** perfil de CPU da API sob carga com `node --cpu-prof` ([diagnostico/perfil-api-cpu.txt](diagnostico/perfil-api-cpu.txt)): 27.4% do tempo ativo no garbage collector, 17.3% no manipulador da rota, 6.2% + 4.1% convertendo datas no driver `pg`, e só ~4% no log de respostas. Plano da consulta nova em [diagnostico/explain-vendas-por-dia-sql.txt](diagnostico/explain-vendas-por-dia-sql.txt).
- **Fonte:** Node.js 20, opção `--cpu-prof`, que "starts the V8 CPU profiler on start up, and writes the CPU profile to disk before exit" (https://nodejs.org/docs/latest-v20.x/api/cli.html#--cpu-prof).
- **Antes (controle no mesmo dia, código `bb824bc`):** [05-controle](resultados/20261108-112158-05-controle), [2](resultados/20261108-112322-05-controle), [3](resultados/20261108-112445-05-controle).
- **Depois:** [05-agregacao-sql](resultados/20261108-111727-05-agregacao-sql), [2](resultados/20261108-111850-05-agregacao-sql), [3](resultados/20261108-112014-05-agregacao-sql).

| Métrica (mediana das 3) | Antes (controle) | Depois |
|---|---|---|
| Requisições/s | 26.59 | 27.07 |
| Mediana geral | 568.2 ms | 423.6 ms |
| p95 | 1977.8 ms | 1812.0 ms |
| p99 | 2688.7 ms | 4600.2 ms |
| CPU / memória do banco | 65.8% / 466.7 MiB | 99.3% / 458.5 MiB |
| CPU / memória da API | 46.8% / 36.6 MiB | 11.9% / 26.1 MiB |
| `vendas-por-dia` (mediana) | 1257.8 ms | 1490.7 ms |
| `cliente` (mediana) | 390.4 ms | 292.4 ms |

- **Conclusão:** **sem ganho de vazão.** A hipótese sobre a API se confirmou: a CPU dela caiu de ~47% para ~12% e a memória também. Mas o banco voltou a ~99% e passou a ser o gargalo de novo, então a vazão ficou igual e o p99 piorou. É o mesmo padrão da 03. O resultado aponta o próximo alvo: a consulta de `vendas-por-dia`, que continua somando ~57 mil itens no banco a cada chamada.

## 06 · Materialized view para `GET /relatorios/vendas-por-dia`

- **Commit:** `5db79de` (mudança, [banco/05-vendas-por-dia.sql](banco/05-vendas-por-dia.sql) e [api/src/rotas.js](api/src/rotas.js)) · diagnósticos em `d0c679a`, `c39e328` e `4b06033` · resultados em `ccfd842` e controle em `8361224`.
- **O que mudou:** o resumo por dia (pedidos distintos, itens e receita, sem cancelados) passou a ser calculado uma vez, na criação do banco, numa materialized view (`vendas_por_dia_mv`, 731 linhas, uma por dia com venda) com índice único em `dia`. A rota lê `WHERE dia BETWEEN $1 AND $2 ORDER BY dia`, com a mesma validação de datas e as mesmas conversões.
- **Hipótese:** depois da 05, o banco voltou a ~99% de CPU e a consulta de `vendas-por-dia` era a mais cara que restava (899.730 ms isolada em [diagnostico/explain-vendas-por-dia-sql.txt](diagnostico/explain-vendas-por-dia-sql.txt)); lendo o resumo pronto, cada chamada deve custar quase nada ao banco, sobrando CPU para as outras rotas e aumentando a vazão.
- **Fonte da ideia:** a mesma da 04, PostgreSQL 16, *Materialized Views* (https://www.postgresql.org/docs/16/rules-materializedviews.html). O exemplo da documentação é justamente um resumo de vendas por vendedor e por dia, com índice único e `REFRESH` noturno.
- **Diagnóstico do índice suspeito (antes da mudança):** a consulta de 31 dias rodada 3 vezes com e 3 vezes sem o `idx_pedidos_criado_em_dia` ([diagnostico/explain-indice-criado-em-dia.txt](diagnostico/explain-indice-criado-em-dia.txt)). Com o índice: 999.806, 674.750 e 728.832 ms, com Seq Scan em `itens_pedido`. Sem ele: 485.756, 380.135 e 430.490 ms, com Index Scan em `idx_itens_pedido_pedido_id`. O índice não aparece no plano, mas muda a estimativa de linhas de `pedidos` (7684 com ele, 939 sem ele, 6361 reais por worker) e leva o planejador a ler `itens_pedido` inteira. A causa exata não foi verificada.
- **Verificação extra do contrato:** 47 chamadas da rota (42 com status 200 e 5 com 400, incluindo bordas, faixas sem dados e 30 janelas pseudoaleatórias) deram status e corpo idênticos byte a byte antes e depois da view ([diagnostico/comparacao-rota-vendas-por-dia.txt](diagnostico/comparacao-rota-vendas-por-dia.txt)).
- **Condições:** banco recriado do zero (`down -v`), autovacuum já executado nas 4 tabelas antes de medir, controle e mudança medidos no mesmo banco e no mesmo dia, com o código conferido dentro do container antes de cada série.
- **Antes (controle no mesmo banco, código `c39e328`):** [06-controle](resultados/20261108-114455-06-controle), [2](resultados/20261108-114618-06-controle), [3](resultados/20261108-114742-06-controle).
- **Depois:** [06-resumo-vendas-dia](resultados/20261108-114922-06-resumo-vendas-dia), [2](resultados/20261108-115045-06-resumo-vendas-dia), [3](resultados/20261108-115208-06-resumo-vendas-dia).

| Métrica (mediana das 3) | Antes (controle) | Depois |
|---|---|---|
| Requisições/s | 29.29 (execuções: 29.96, 29.29, 28.17) | 53.61 (execuções: 51.06, 53.61, 55.02) |
| Mediana geral | 404.8 ms | 207.1 ms |
| p95 | 1803.0 ms | 1110.2 ms |
| p99 | 3871.2 ms | 2320.1 ms |
| CPU / memória do banco | 99.7% / 465.9 MiB | 100.2% / 428.3 MiB |
| CPU / memória da API | 12.8% / 26.0 MiB | 20.4% / 25.9 MiB |
| Pico de CPU da API (mediana dos máximos do `recursos.csv`) | 25.61% | 40.56% |

| Rota (mediana das medianas) | Antes | Depois |
|---|---|---|
| cliente | 291.9 ms | 189.6 ms |
| cliente-por-email | 296.7 ms | 191.3 ms |
| pedidos-do-cliente | 791.0 ms | 492.5 ms |
| pedidos-por-status | 1197.3 ms | 899.7 ms |
| busca-produtos | 298.1 ms | 204.1 ms |
| vendas-por-dia | 1347.3 ms | 188.0 ms |
| top-produtos | 211.4 ms | 192.7 ms |

- **Conclusão:** ~1,8x mais requisições/s, e as faixas das 3 execuções não se sobrepõem. `vendas-por-dia` ficou ~7x mais rápida, e todas as outras rotas também melhoraram, porque cada chamada da rota passou a custar quase nada ao banco. O banco continua em ~100% de CPU, mas agora entrega quase o dobro de requisições com o mesmo recurso. A API subiu (pico de ~41% contra um limite de 50%) e é o próximo ponto a vigiar. A memória média do banco caiu, e não sabemos explicar por quê. Custo em disco: 104 kB da view mais 32 kB do índice, num banco de 361 MB ([diagnostico/tamanho-vendas-por-dia-mv.txt](diagnostico/tamanho-vendas-por-dia-mv.txt)). O custo real é o mesmo da 04: o dado é uma foto da criação do banco e precisa de `REFRESH` se mudar, o que a carga, só de leitura, não mede.
- **Incidente registrado:** durante o diagnóstico do índice, a primeira versão do script apagou o `idx_pedidos_criado_em_dia` fora de transação (um erro de sintaxe engoliu o `BEGIN`). O índice foi recriado com a mesma definição do `03-indices.sql`, o diagnóstico foi refeito com `ON_ERROR_STOP` e nenhuma medição foi feita nesse estado. O banco foi recriado do zero antes de medir a 06.
- **Consequência:** o `idx_pedidos_criado_em_dia` não serve mais a nenhuma rota. A remoção fica para uma mudança própria.

## Séries que não entram nas comparações

Nem toda medição feita entrou nas tabelas acima. Esta seção lista todas as que ficaram de fora e o motivo, para que nenhuma pasta (ou ausência de pasta) fique sem explicação.

| Série | Situação | Por que não entra nas comparações |
|---|---|---|
| `01-pool-diagnostico` (1 execução, 04/11) | apagada antes do commit | não era medição de mudança: uma execução do `medir.sh` usada só para gerar carga enquanto se contavam as conexões abertas do pool no banco (10 conexões, quase todas ativas, coerente com `max: 10`). A leitura da memória por conexão falhou (o container do banco não tem `ps`), e a hipótese de que as conexões explicam o aumento de memória da 01 ficou sem confirmação. A pasta e o arquivo de diagnóstico correspondente foram descartados. |
| `03-consulta-unica` · [1](resultados/20261107-201604-03-consulta-unica), [2](resultados/20261107-201806-03-consulta-unica), [3](resultados/20261107-202001-03-consulta-unica) | mantida no repositório | código da 03 medido ~25 min depois de a máquina ligar: 5.96 req/s (mediana). Rotas que a mudança não altera ficaram ~3x mais lentas que no dia 04/11, com o mesmo banco e os mesmos dados ([diagnostico/20261107-estado-banco.txt](diagnostico/20261107-estado-banco.txt)). Foi a evidência de que a máquina variava e motivou o controle no mesmo dia. |
| `03-consulta-unica-r2` (3 execuções) | apagada antes do commit | código da 03 medido de novo com 2 arquivos de diagnóstico ainda sem commit (`arquivos alterados sem commit: 2` no `contexto.txt`), o que quebra o ciclo de medição do desafio. Substituída pela `03-consulta-unica-v2`. |
| `03-consulta-unica-hoje` (3 execuções) | apagada antes do commit | depois de voltar do commit do controle para `main`, a API não foi reconstruída (`docker compose up -d --build`), e o container continuou rodando o código da 02. O `contexto.txt` registrava o commit novo, mas a rota `pedidos-do-cliente` deu o mesmo tempo do controle, o que denunciou o erro. Desde então, o código dentro do container é conferido com `grep` antes de cada série. Substituída pela `03-consulta-unica-v2`. |
| `04-revalidacao` (3 execuções, 08/11) | apagada antes do commit | código da 04 medido de novo para conferir se a máquina estava estável ao longo do dia. As 3 execuções registraram 1 arquivo sem commit (o `experimentos.md` ainda não commitado), o que quebra o ciclo de medição. Foi repetida com 0 arquivos sem commit como `04-revalidacao-v2`. |
| `04-revalidacao-v2` · [1](resultados/20261108-123230-04-revalidacao-v2), [2](resultados/20261108-123354-04-revalidacao-v2), [3](resultados/20261108-123518-04-revalidacao-v2) | mantida no repositório | o código da 04 (`f667498`) medido de novo em 08/11: 27.85 req/s, p95 1793.7 ms, CPU média do banco 65.3% e da API 46.2% (medianas). O `05-controle`, que mede o mesmo código cerca de 1 hora antes, deu 26.59 req/s, p95 1977.8 ms, banco 65.8% e API 46.8%. Não é comparação de mudança: serve como evidência de que, no mesmo dia, o mesmo código repete resultados parecidos. |

As séries apagadas nunca foram commitadas, por isso não há pastas para elas. A partir daqui, nenhuma pasta de `resultados/` é apagada: medições com problema ficam no repositório, com o motivo registrado nesta tabela.
