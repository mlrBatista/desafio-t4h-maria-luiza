# Experimentos

Registro de cada mudança aplicada na aplicação, com a hipótese, a fonte da ideia, a medição antes e depois e a conclusão. As ideias pesquisadas que não foram testadas estão em [proximos-testes.md](proximos-testes.md).

## Como ler esta página

- **Todo número vem de `resultados/`**, gerado por `scripts/medir.sh` com os mesmos parâmetros em todas as execuções: `VUS=20`, `DURACAO=60s`, `SEMENTE=42`, aquecimento de 15 s. Os parâmetros e o commit de cada execução estão no `contexto.txt` de cada pasta.
- **Cada valor é a mediana das 3 execuções** do mesmo rótulo, não a melhor. Para os tempos, é a mediana das 3 medianas, dos 3 p95 e dos 3 p99 de cada execução.
- **CPU e memória** são as médias de cada execução no `recursos.txt` (100% = 1 CPU inteira), também pela mediana das 3. Limites, iguais em todas as medições: API com 0,5 CPU e 256 MB, banco com 1 CPU e 512 MB.
- **O pico de CPU da API** (`cpu_max` do `recursos.txt`) não é usado: em várias execuções ele aparece menor que a média, o que é impossível. O `recursos.csv` da mesma pasta mostra amostras bem acima do valor relatado. Não editamos o script (régua do desafio). Quando o pico importa, ele é lido do `recursos.csv`.
- **Status** (os três do enunciado): "Aplicada e medida" (a mudança foi aplicada e o ganho medido), "Aplicada, sem ganho" (aplicada e medida, sem diferença de vazão além do ruído; a conclusão explica por quê) e "Pesquisada, teste futuro" (as ideias de [proximos-testes.md](proximos-testes.md)). A 10 foi aplicada e medida e depois revertida na versão final.
- **Contrato:** todas as execuções listadas abaixo terminaram com "Contrato mantido: as 42 respostas são iguais às gravadas" (`contrato.txt` de cada pasta) e registram `arquivos alterados sem commit: 0`.

### Qual "antes" foi usado

- **Mudanças 01 e 02:** o antes é a medição anterior (linha de base e 01-pool), feita na mesma máquina nos dias 03 e 04/11.
- **Mudanças 03 em diante:** o antes é um **controle medido no mesmo dia, logo antes ou logo depois da mudança**, com o código do commit anterior. Motivo: em 07/11, a mesma versão do código mediu 5.96 req/s numa série e 8.60 req/s noutra, com ~40 minutos de diferença, e rotas que a mudança nem tocava ficaram ~3x mais lentas. A máquina (Windows + WSL2, reiniciada naquele dia) variou mais do que o efeito que queríamos medir. Comparar com uma medição de outro dia misturaria o efeito do código com o da máquina. Desde a 04, o controle é medido também **no mesmo banco**, depois do `down -v`, para que a única diferença seja o código. Desde a 07, o controle é medido **antes e depois** da mudança (desenho A-B-A): se os dois controles derem parecido, a máquina ficou estável durante todo o teste e a ordem das séries não favoreceu nenhum lado.

## Resumo

| # | Mudança | Fonte da ideia | Status | Hipótese | Antes (rótulo) | req/s antes → depois | p95 antes → depois (ms) | CPU banco / API (média) | Pastas de resultados | Conclusão |
|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Pool de conexões | [node-postgres, *Pooling*](https://node-postgres.com/features/pooling) | Aplicada e medida | abrir uma conexão nova a cada consulta custa; reaproveitar conexões reduz a latência | 00-linha-de-base | 1.69 → 2.15 | 38198.7 → 35717.1 | banco 98.5% → 97.8%; API 9.7% → 8.3% | [antes](resultados/20261103-210235-00-linha-de-base) · [depois](resultados/20261104-211122-01-pool) | ganho pequeno; o banco continuou no limite |
| 02 | Índices para as consultas das rotas | `EXPLAIN` de cada consulta ([diagnóstico](diagnostico/explain-rotas.txt)); PostgreSQL 16: [*Indexes on Expressions*](https://www.postgresql.org/docs/16/indexes-expressional.html), [*Indexes and ORDER BY*](https://www.postgresql.org/docs/16/indexes-ordering.html), [*pg_trgm*](https://www.postgresql.org/docs/16/pgtrgm.html) | Aplicada e medida | as consultas leem tabelas inteiras; índices no formato de cada consulta reduzem a leitura | 01-pool | 2.15 → 9.43 | 35717.1 → 9177.6 | banco 97.8% → 96.1%; API 8.3% → 24.1% | [antes](resultados/20261104-211122-01-pool) · [depois](resultados/20261104-220255-02-indices) | maior ganho até então; o banco seguiu no limite |
| 03 | Fim do N+1 em `/clientes/:id/pedidos` | leitura do código; [Rails Guides, *N + 1 Queries Problem*](https://guides.rubyonrails.org/active_record_querying.html#n-1-queries-problem) | Aplicada, sem ganho | 22 consultas viram 3; a rota fica mais rápida e sobra banco para as outras | 02-indices-hoje (controle) | 8.35 → 8.60 | 10726.4 → 7422.4 | banco 96.2% → 97.4%; API 26.2% → 25.9% | [antes](resultados/20261107-204404-02-indices-hoje) · [depois](resultados/20261107-205642-03-consulta-unica-v2) | a rota ficou ~2,4x mais rápida, as outras pioraram; vazão igual |
| 04 | Materialized view para `top-produtos` | [PostgreSQL 16, *Materialized Views*](https://www.postgresql.org/docs/16/rules-materializedviews.html) | Aplicada e medida | o ranking soma 1,5 milhão de itens a cada chamada; lendo o resultado pronto, a CPU do banco cai | 03-controle-hoje2 (controle) | 8.27 → 22.06 | 8213.5 → 2312.2 | banco 95.2% → 65.0%; API 23.9% → 46.6% | [antes](resultados/20261107-211945-03-controle-hoje2) · [depois](resultados/20261107-211442-04-view-top-produtos) | maior ganho; o gargalo passou para a API |
| 05 | `vendas-por-dia` agregado no SQL | perfil de CPU da API com [`--cpu-prof`](https://nodejs.org/docs/latest-v20.x/api/cli.html#--cpu-prof) ([diagnóstico](diagnostico/perfil-api-cpu.txt)) | Aplicada, sem ganho | a API soma ~57 mil linhas em JavaScript; somando no banco, a CPU da API cai e a vazão sobe | 05-controle (controle) | 26.59 → 27.07 | 1977.8 → 1812.0 | banco 65.8% → 99.3%; API 46.8% → 11.9% | [antes](resultados/20261108-112158-05-controle) · [depois](resultados/20261108-111727-05-agregacao-sql) | tirou o trabalho da API; o gargalo voltou para o banco |
| 06 | Materialized view para `vendas-por-dia` | [PostgreSQL 16, *Materialized Views*](https://www.postgresql.org/docs/16/rules-materializedviews.html) | Aplicada e medida | a soma por dia é refeita a cada chamada; pré-calculada, nem a API nem o banco a refazem | 06-controle (controle) | 29.29 → 53.61 | 1803.0 → 1110.2 | banco 99.7% → 100.2%; API 12.8% → 20.4% | [antes](resultados/20261108-114455-06-controle) · [depois](resultados/20261108-114922-06-resumo-vendas-dia) | ~1,8x a vazão com a mesma CPU do banco; todas as rotas mais rápidas |
| 07 | Índice cobrindo + `SELECT` das 4 colunas em `/pedidos` | `EXPLAIN` de `/pedidos` ([diagnóstico](diagnostico/explain-pedidos-resumo.txt)); [PostgreSQL 16, *Index-Only Scans*](https://www.postgresql.org/docs/16/indexes-index-only-scans.html) | Aplicada e medida | as páginas fundas visitam a tabela; com índice cobrindo e só 4 colunas, viram Index Only Scan | 07-controle (controle A-B-A) | 51.34 → 81.60 | 1128.3 → 699.0 | banco 97.9% → 97.9%; API 18.7% → 25.2% | [antes](resultados/20261109-195639-07-controle) · [depois](resultados/20261109-200117-07-indice-cobrindo) | ~1,6x a vazão; os dois controles iguais (51.34 e 52.25), então o ganho é da mudança |
| 08 | Tabela-resumo do total por status, mantida por trigger | [PostgreSQL 16, *Trigger Functions*, Ex. 43.6](https://www.postgresql.org/docs/16/plpgsql-trigger.html) | Aplicada e medida | a contagem por status é refeita a cada página; lendo uma tabela de 4 linhas, deixa de gastar CPU do banco | 08-controle (controle A-B-A) | 90.51 → 265.71 | 604.5 → 162.3 | banco 96.9% → 57.8%; API 24.4% → 50.3% | [antes](resultados/20261109-211322-08-controle) · [depois](resultados/20261109-212204-08-resumo-status) | ~2,9x a vazão; o banco saiu do limite e o gargalo passou para a API |
| 09 | Log de cada resposta sem o corpo da resposta | perfil de CPU da API ([diagnóstico](diagnostico/perfil-api-cpu-08.txt)) | Aplicada, sem ganho | o log custa 8–13% da CPU da API; sem o corpo, a vazão sobe um pouco (+5% a +10%) | controles vizinhos 09-controle-depois-r2 e 09-controle-r3 | 259.45 → 261.31 e 280.90 → 256.56 | 164.2 → 161.8 e 153.0 → 157.8 | API ~49% em todas as séries (no limite) | [antes](resultados/20261110-192916-09-controle-depois-r2) · [depois](resultados/20261110-192354-09-log-sem-corpo-r2); [antes](resultados/20261110-194908-09-controle-r3) · [depois](resultados/20261110-195431-09-log-sem-corpo-r3) | vazão sem diferença mensurável (+0.7% e −8.7%, dentro da variação de ~8% entre os controles daquela sessão); log ~10x menor |
| 10 | API de 0.5 para 1.0 CPU | medição: a API no limite de 0.5 CPU depois da 08 e da 09 | Aplicada e medida | a API é o gargalo; com 1.0 CPU, a vazão sobe até o banco virar o limite | 10-controle (controle A-B-A) | 246.53 → 473.73 | 169.6 → 87.4 | banco 63.3% → 101.3%; API 49.4% → 75.4% | [antes](resultados/20261110-203407-10-controle) · [depois](resultados/20261110-203927-10-api-1cpu) | revertida na versão final; ~1,8x a vazão com +33% de CPU no total; o banco virou o limite |
| 11 | Remoção do `idx_pedidos_criado_em_dia`, sem uso | `idx_scan` 0 nas medições da 07 e planos das 24 consultas ([diagnóstico](diagnostico/mudanca-11/01-planos-resumo.txt)) | Aplicada, sem ganho | nenhuma rota usa o índice; removê-lo não muda a vazão e economiza disco | 11-controle (controle A-B-A) | 296.32 → 296.84 | 115.2 → 115.1 | banco 61.5% → 57.4%; API 50.6% → 50.1% | [antes](resultados/20261117-130442-11-controle) · [depois](resultados/20261117-131145-11-sem-indice-dia) | sem diferença na vazão (+0.2%, controles a −0.9% entre si); 3552 kB a menos em disco |

### A aplicação original e a versão final, medidas no mesmo dia

Para o resultado geral não misturar dias diferentes, a aplicação original (commit `a697110`) foi medida de novo em 17/11/2026, na mesma sessão em que a versão final (`11-sem-indice-dia`) foi medida, com os mesmos parâmetros e os mesmos limites (API com 0.5 CPU, banco com 1.0). As 3 execuções da original registram o commit `a697110`, contrato mantido e 0 arquivos sem commit. O banco foi recriado do zero para cada versão e o autovacuum rodou antes das duas medições.

| Métrica (mediana das 3) | Original, 17/11 ([final-linha-de-base](resultados/20261117-133817-final-linha-de-base), [2](resultados/20261117-134016-final-linha-de-base), [3](resultados/20261117-134216-final-linha-de-base)) | Versão final, 17/11 ([11-sem-indice-dia](resultados/20261117-131145-11-sem-indice-dia), [2](resultados/20261117-131307-11-sem-indice-dia), [3](resultados/20261117-131428-11-sem-indice-dia)) | Original, 03/11 (00-linha-de-base) |
|---|---|---|---|
| Requisições/s | 1.86 (execuções: 1.86, 1.77, 1.86) | 296.84 (execuções: 320.36, 292.85, 296.84) | 1.69 (execuções: 1.70, 1.64, 1.69) |
| Requisições em 60 s | 137 | 17823 | 131 |
| Mediana geral | 1646.5 ms | 76.0 ms | 2311.9 ms |
| p95 | 37824.7 ms | 115.1 ms | 38198.7 ms |
| p99 | 44725.9 ms | 182.8 ms | 49375.5 ms |
| CPU do banco (média / pico) | 97.2% / 107.6% | 57.4% / 67.1% | 98.5% / 107.3% |
| CPU da API (média / pico) | 9.3% / 24.6% | 50.1% / 52.3% | 9.7% / 27.9% |
| Memória do banco / da API | 388.1 / 27.5 MiB | 439.4 / 28.0 MiB | 222.5 / 29.7 MiB |

| Rota (mediana · p95 · p99, em ms) | Original, 17/11 | Versão final, 17/11 |
|---|---|---|
| `/clientes/:id` | 599.3 · 1031.7 · 1260.8 | 48.1 · 92.8 · 144.3 |
| `/clientes?email=` | 1673.3 · 3936.8 · 5549.1 | 66.2 · 93.7 · 159.9 |
| `/clientes/:id/pedidos` | 30392.2 · 44725.0 · 45534.9 | 96.2 · 170.6 · 199.2 |
| `/pedidos` | 12190.4 · 27977.3 · 34641.1 | 87.1 · 153.9 · 194.3 |
| `/produtos/busca` | 1199.5 · 1780.9 · 2064.9 | 74.5 · 100.9 · 167.0 |
| `/relatorios/vendas-por-dia` | 13084.9 · 17500.9 · 18253.9 | 61.8 · 92.2 · 118.9 |
| `/relatorios/top-produtos` | 23694.3 · 23694.3 · 23694.3 | 44.7 · 90.7 · 105.1 |

- **Resultado (contas sobre as medianas):** com os mesmos recursos, a versão final atende **~160 vezes mais requisições por segundo** (296.84 contra 1.86) e tem p95 **~329 vezes menor** (115.1 contra 37824.7 ms); o p99 ficou ~245 vezes menor e a mediana geral ~22 vezes menor. As faixas das execuções nem se aproximam (original de 1.77 a 1.86 req/s; final de 292.85 a 320.36).
- **Onde está o gargalo:** na original, o banco está saturado (97.2% de CPU) e a API quase parada (9.3%), esperando o banco. Na final, o banco tem folga (57.4%) e a API está no limite de 0.5 CPU (50.1%).
- **Cuidado com as rotas da original:** como ela é muito lenta, as rotas rápidas receberam de 22 a 40 requisições e `top-produtos` só 1 em cada execução (por isso p95 e p99 iguais). A comparação vale pelos números gerais.
- **Comparação com 03/11:** a original medida hoje ficou 10.1% acima da de 03/11 em req/s (1.86 contra 1.69), com p95 parecido (37824.7 contra 38198.7 ms). A aplicação é a mesma; a diferença vem da máquina, do dia ou do estado do banco (hoje o autovacuum rodou antes da medição, e em 03/11 a medição foi logo depois da criação do banco), sem que se saiba qual. Pela linha de base de 03/11, a razão seria ~176 vezes; o número da mesma sessão (~160 vezes) é o que vale.
- **Observação:** cada execução da original cobre ~75 s no `recursos.csv`, contra ~61 s na final, porque o k6 espera as requisições lentas terminarem depois dos 60 s, como em 03/11.

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

## 07 · Índice cobrindo e `SELECT` das 4 colunas em `GET /pedidos`

- **Commit:** `06e6893` (mudança, [banco/06-pedidos-indice-cobrindo.sql](banco/06-pedidos-indice-cobrindo.sql) e [api/src/rotas.js](api/src/rotas.js)) · diagnósticos em `4f1f917`, `01af8ee`, `9b6dde1` e `d6d3544` · resultados em `24e71cc` (controle), `ffbc4f3` (mudança) e `99bcb9d` (controle depois).
- **O que mudou:** duas alterações num commit só, porque formam uma única hipótese.
  - **No banco:** o índice `idx_pedidos_status_criado_em` (criado na 02) foi substituído por `idx_pedidos_status_criado_em_cobrindo`, com a mesma chave `(status, criado_em DESC, id DESC)` e o `cliente_id` em `INCLUDE`.
  - **Na API:** a consulta da página trocou `SELECT *` por `SELECT id, cliente_id, status, criado_em`, as 4 colunas que a resposta usa. A contagem e o resto da rota não mudaram.
  - Com as duas juntas, todas as colunas da consulta estão no índice e o banco monta a página sem visitar a tabela (Index Only Scan). Separadas, nenhuma das duas evita a visita: com `SELECT *` faltam colunas no índice, e sem o `INCLUDE` falta o `cliente_id`.
- **Hipótese:** a consulta da página usa `OFFSET` e, com `SELECT *`, visita a tabela para cada linha percorrida; em `cancelado` e `pendente`, as páginas fundas ainda trocam para Parallel Bitmap Heap Scan com ordenação em disco. Com o índice cobrindo e só as 4 colunas, todas as páginas devem virar Index Only Scan, baixando o tempo de `/pedidos` e liberando CPU do banco para as outras rotas.
- **Evidência que originou a ideia:** diagnóstico da rota com o banco ocioso, 3 execuções de cada consulta para os 4 status ([diagnostico/explain-pedidos.txt](diagnostico/explain-pedidos.txt), resumo em [diagnostico/explain-pedidos-resumo.txt](diagnostico/explain-pedidos-resumo.txt)). Nenhuma das duas consultas da rota domina sempre: a contagem pesa em `pago` (mediana de 105.734 ms) e em `entregue` (29.288 ms); a página 1000 pesa em `cancelado` (369.886 ms) e em `pendente` (319.152 ms), onde o plano troca para Parallel Bitmap Heap Scan com `Sort Method: external merge` em disco. Na página 1000 de `pago`, a consulta atual lia 20101 páginas de 8 kB; com o índice cobrindo, testado dentro de `BEGIN ... ROLLBACK`, leu 102, sem visitar a tabela (`Heap Fetches: 0`), em ~1,9 ms na página 500 e ~3,6 ms na 1000 nos 4 status. O índice cobrindo não resolve a contagem.
- **Fontes:**
  - PostgreSQL 16, *Index-Only Scans and Covering Indexes*: um index-only scan responde à consulta "from an index alone without any heap access"; para isso, a página da tabela precisa estar marcada como visível no *visibility map*; colunas em `INCLUDE` ficam guardadas no índice sem fazer parte da chave de busca, e a documentação recomenda cautela porque elas aumentam o tamanho do índice (https://www.postgresql.org/docs/16/indexes-index-only-scans.html).
  - PostgreSQL 16, *Indexes and ORDER BY*, já citada na 02 (https://www.postgresql.org/docs/16/indexes-ordering.html).
- **Verificação extra do contrato:** 22 respostas de `/pedidos` (4 status nas páginas 1, 2, 500, 1000 e além do fim, mais `pagina=0` e status inválido) idênticas byte a byte antes e depois, tanto antes de commitar quanto depois de aplicar no banco recriado ([diagnostico/comparacao-rota-pedidos.txt](diagnostico/comparacao-rota-pedidos.txt)).
- **Estado do banco antes de medir** ([diagnostico/estado-banco-07.txt](diagnostico/estado-banco-07.txt)): banco recriado com `down -v`, autovacuum já executado nas 4 tabelas, mapa de visibilidade completo em `pedidos` (`relallvisible` 20834 de 20834), índice antigo ausente e índice novo presente. Com o índice novo, a página 1000 levou 5.240 ms em `pago`, 6.198 ms em `cancelado` e 4.937 ms em `pendente`, todas com Index Only Scan.
- **Condições da medição:** desenho A-B-A no mesmo banco e em sequência: controle (código anterior), mudança, controle de novo. O código da API foi conferido dentro do container antes de cada série. Antes da primeira série, como os containers tinham acabado de reiniciar, rodou-se uma carga de aquecimento de 60 s sem gravar resultados (não gerou pasta em `resultados/`).
- **Ressalva sobre o controle:** os dois controles rodam o código antigo (`SELECT *`) no banco já recriado com o índice cobrindo, porque o índice antigo não existe mais nesse banco. Com `SELECT *`, o índice novo se comporta como o antigo: mesma chave, e a consulta precisa ir à tabela buscar as colunas que o índice não tem. Recriar o banco com o índice antigo só para o controle colocaria uma segunda diferença (outro banco, outro cache) entre as séries. **Evidência:** um diagnóstico com o banco ocioso, depois das medições, rodou a consulta antiga e a nova com o índice novo, 3 vezes cada, nos 4 status ([diagnostico/explain-pedidos-07.txt](diagnostico/explain-pedidos-07.txt), resumo em [diagnostico/explain-pedidos-07-resumo.txt](diagnostico/explain-pedidos-07-resumo.txt)). A consulta antiga com o índice novo leu exatamente as mesmas páginas e usou os mesmos planos que com o índice antigo em [diagnostico/explain-pedidos.txt](diagnostico/explain-pedidos.txt): 10052 páginas na página 500 de `pago` e 20101 na 1000 (Index Scan); 21166 e 20181 na página 1000 de `cancelado` e `pendente` (Parallel Bitmap Heap Scan). A consulta nova leu de 53 a 124 páginas, com Index Only Scan e `Heap Fetches: 0` em todos os casos.
- **Antes (controle):** [07-controle](resultados/20261109-195639-07-controle), [2](resultados/20261109-195806-07-controle), [3](resultados/20261109-195933-07-controle).
- **Depois:** [07-indice-cobrindo](resultados/20261109-200117-07-indice-cobrindo), [2](resultados/20261109-200241-07-indice-cobrindo), [3](resultados/20261109-200404-07-indice-cobrindo).
- **Controle depois:** [07-controle-depois](resultados/20261109-200547-07-controle-depois), [2](resultados/20261109-200713-07-controle-depois), [3](resultados/20261109-200839-07-controle-depois).

| Métrica (mediana das 3) | Controle | Mudança | Controle depois |
|---|---|---|---|
| Requisições/s | 51.34 (execuções: 47.31, 51.34, 52.98) | 81.60 (execuções: 74.28, 85.52, 81.60) | 52.25 (execuções: 52.17, 54.32, 52.25) |
| Mediana geral | 205.6 ms | 190.3 ms | 208.7 ms |
| p95 | 1128.3 ms | 699.0 ms | 1197.8 ms |
| p99 | 2327.6 ms | 1177.4 ms | 2316.4 ms |
| CPU / memória do banco | 97.9% / 426.7 MiB | 97.9% / 371.7 MiB | 96.5% / 436.9 MiB |
| CPU / memória da API | 18.7% / 27.3 MiB | 25.2% / 27.6 MiB | 19.1% / 26.2 MiB |
| Pico de CPU da API (mediana dos máximos do `recursos.csv`) | 35.78% | 40.17% | 35.73% |

| Rota (mediana das medianas) | Controle | Mudança | Controle depois |
|---|---|---|---|
| cliente | 188.2 ms | 106.8 ms | 190.0 ms |
| cliente-por-email | 187.7 ms | 106.2 ms | 188.9 ms |
| pedidos-do-cliente | 511.4 ms | 301.3 ms | 466.2 ms |
| pedidos-por-status | 908.5 ms | 503.0 ms | 976.5 ms |
| busca-produtos | 202.7 ms | 189.1 ms | 207.6 ms |
| vendas-por-dia | 187.4 ms | 107.2 ms | 188.5 ms |
| top-produtos | 189.3 ms | 112.1 ms | 192.0 ms |

- **Custo:** o índice novo tem 22118400 bytes (21 MB), o mesmo tamanho do índice que ele substituiu ([diagnostico/estado-banco-07.txt](diagnostico/estado-banco-07.txt)). O `cliente_id` em `INCLUDE` não aumentou o tamanho medido; o motivo não foi investigado.
- **Conclusão:** ~1,6x mais requisições/s (51.34 → 81.60) e p95 ~38% menor. Os dois controles ficaram praticamente iguais (51.34 e 52.25 req/s; p95 de 1128.3 e 1197.8 ms), então a máquina ficou estável durante as 9 execuções e o ganho é da mudança. Como na 06, todas as rotas ficaram mais rápidas, não só `/pedidos`: o banco segue a ~98% de CPU, mas gasta menos por requisição e atende ~60% mais. A memória média do banco caiu (426.7 → 371.7 MiB); a hipótese é que menos páginas da tabela passam a ser carregadas, o que não foi verificado. A API subiu de 18.7% para 25.2% de CPU média, e uma das execuções da mudança teve pico de 51.99% no `recursos.csv`, acima do limite de 50% (0.5 CPU): a API volta a se aproximar do limite.
- **O que continua igual:** a contagem por status, que ainda soma todas as linhas do status a cada requisição. Com o índice novo, a contagem de `pago` levou 63.955 ms com o banco ocioso ([diagnostico/estado-banco-07.txt](diagnostico/estado-banco-07.txt)).
- **Índice sem uso confirmado:** o `idx_pedidos_criado_em_dia` teve `idx_scan` 0 antes e 0 depois das 9 execuções, com `idx_tup_read` 0 ([diagnostico/idx-scan-depois-07.txt](diagnostico/idx-scan-depois-07.txt)). Nenhuma rota o usa; a remoção fica para uma mudança própria.

## 08 · Tabela-resumo do total por status, mantida por trigger, em `GET /pedidos`

- **Commit:** `9d3bdf4` (mudança, [banco/07-pedidos-por-status.sql](banco/07-pedidos-por-status.sql) e [api/src/rotas.js](api/src/rotas.js)) · diagnósticos em `0759f64` e `a543805` · resultados em `3e64156` (controle), `252a714` (mudança) e `060dbcd` (controle depois).
- **O que mudou:**
  - **No banco:** uma tabela `pedidos_por_status` (4 linhas: status e total), preenchida com a contagem dos pedidos na criação do banco, e triggers em `pedidos` que a mantêm correta: `INSERT` soma 1 no status, `DELETE` subtrai 1, `UPDATE` que muda o status subtrai do antigo e soma no novo, e `TRUNCATE` zera os totais.
  - **Na API:** a contagem `SELECT count(*) FROM pedidos WHERE status = $1` passou a ser a leitura do total dessa tabela (com `COALESCE(..., 0)` para um status sem pedidos). A página e o resto da rota não mudaram.
- **Por que trigger e não materialized view:** as duas leem 4 linhas prontas, então, para esta carga, que só lê, o desempenho de leitura deve ser equivalente (a variante com view não foi medida). A diferença está nas escritas: a view seria uma foto da criação do banco e ficaria errada até um `REFRESH`, que conta todas as linhas de novo; a tabela com trigger fica correta a cada escrita, sem `REFRESH`. Para um total que aparece na resposta de uma rota de consulta, e não num relatório que aceita atraso, preferimos que ele esteja sempre correto. Nas mudanças 04 e 06, que são relatórios, a materialized view foi mantida.
- **Hipótese:** depois da 07, a contagem era o maior custo que sobrava em `/pedidos`, e o banco seguia a ~98% de CPU. Lendo o total de uma tabela de 4 linhas, em vez de contar todas as linhas do status a cada requisição, a contagem deixa de consumir CPU do banco, a vazão sobe e `/pedidos` fica mais rápida. Custo esperado: cada escrita em `pedidos` também atualiza uma linha da tabela-resumo.
- **Evidência que originou a ideia:** contagem com o índice novo, banco ocioso, 3 execuções por status ([diagnostico/explain-pedidos-07-resumo.txt](diagnostico/explain-pedidos-07-resumo.txt)): mediana de 205.306 ms em `pago`, 27.076 em `entregue`, 15.250 em `cancelado` e 10.331 em `pendente`, com Parallel Index Only Scan e `Heap Fetches: 0`, ou seja, já no caminho mais barato que uma contagem exata permite. A página, depois da 07, custava de 2.605 a 7.213 ms.
- **Fonte:** PostgreSQL 16, *Trigger Functions*, Example 43.6 (*A PL/pgSQL Trigger Function for Maintaining a Summary Table*): "One use of triggers is to maintain a summary table of another table. The resulting summary can be used in place of the original table for certain queries — often with vastly reduced run times." (https://www.postgresql.org/docs/16/plpgsql-trigger.html).
- **Teste de correção dos triggers:** a carga do desafio só lê, então ela nunca dispara os triggers. A evidência de que eles estão certos vem de um teste dentro de `BEGIN ... ROLLBACK` ([diagnostico/teste-trigger-pedidos-por-status.txt](diagnostico/teste-trigger-pedidos-por-status.txt), repetido no banco recriado em [diagnostico/teste-trigger-pedidos-por-status-banco-recriado.txt](diagnostico/teste-trigger-pedidos-por-status-banco-recriado.txt)): em 8 passos (inserir 12 pedidos, 2 deles com um status novo; mudar o status de pedidos novos e de um existente; `UPDATE` sem mudança de status; apagar pedidos novos e um existente com os itens; `UPDATE` de várias linhas; `TRUNCATE`), a tabela-resumo bateu com `count(*)` por status em todos. Depois do `ROLLBACK`, os totais voltaram a cancelado=50000, entregue=125000, pago=300000 e pendente=25000.
- **Custo nas escritas** ([diagnostico/custo-escrita-trigger-pedidos-por-status-resumo.txt](diagnostico/custo-escrita-trigger-pedidos-por-status-resumo.txt)): diagnóstico isolado, não vem do `medir.sh`. `INSERT` de 10 mil pedidos dentro de `BEGIN ... ROLLBACK`, 3 vezes de cada lado: com trigger, 2618.959, 990.097 e 806.505 ms (mediana 990.097 ms); sem trigger, 2328.978, 274.079 e 169.714 ms (mediana 274.079 ms). Razão das medianas: 3.61x, ou ~0.0716 ms a mais por linha inserida. A 1ª execução de cada lado inclui cache frio, e as razões por par variaram de 1.12x a 4.75x, então o número indica uma ordem de grandeza, não um valor preciso.
- **Verificação extra do contrato:** 22 respostas de `/pedidos` idênticas byte a byte antes e depois ([diagnostico/comparacao-rota-pedidos-08.txt](diagnostico/comparacao-rota-pedidos-08.txt)).
- **Estado do banco antes de medir** ([diagnostico/estado-banco-08.txt](diagnostico/estado-banco-08.txt)): banco recriado, autovacuum feito, tabela-resumo igual ao `count(*)` por status, triggers presentes, 32 kB de tamanho. A leitura nova do total levou de 0.047 a 0.151 ms (12 execuções, 3 por status), contra 205.306 ms da contagem de `pago`.
- **Condições da medição:** A-B-A no mesmo banco e em sequência, com o código da API conferido dentro do container antes de cada série e uma carga de aquecimento de 60 s sem gravar antes da primeira série. Na série do controle, a 3ª execução começou ~5,5 minutos depois da 2ª (pastas `20261109-211447` e `20261109-212024`), um intervalo maior que o normal e sem explicação registrada; a 1ª execução dessa série também foi mais baixa (67.51 req/s). A mediana da série não depende dessas duas observações, e ela ficou próxima da do controle depois.
- **Ressalva sobre o controle:** os controles rodam o código antigo (`count(*)`) no banco que já tem a tabela-resumo e os triggers. Como a carga só lê, os triggers não disparam, e a tabela-resumo não é lida pelo código antigo, então o controle faz o mesmo trabalho que a versão anterior.
- **Antes (controle):** [08-controle](resultados/20261109-211322-08-controle), [2](resultados/20261109-211447-08-controle), [3](resultados/20261109-212024-08-controle).
- **Depois:** [08-resumo-status](resultados/20261109-212204-08-resumo-status), [2](resultados/20261109-212325-08-resumo-status), [3](resultados/20261109-212446-08-resumo-status).
- **Controle depois:** [08-controle-depois](resultados/20261109-212625-08-controle-depois), [2](resultados/20261109-212747-08-controle-depois), [3](resultados/20261109-212908-08-controle-depois).

| Métrica (mediana das 3) | Controle | Mudança | Controle depois |
|---|---|---|---|
| Requisições/s | 90.51 (execuções: 67.51, 95.66, 90.51) | 265.71 (execuções: 259.48, 265.71, 272.82) | 91.89 (execuções: 93.37, 91.39, 91.89) |
| Mediana geral | 184.9 ms | 80.3 ms | 181.2 ms |
| p95 | 604.5 ms | 162.3 ms | 601.6 ms |
| p99 | 999.5 ms | 194.9 ms | 1002.1 ms |
| CPU / memória do banco | 96.9% / 365.2 MiB | 57.8% / 437.8 MiB | 99.4% / 426.4 MiB |
| CPU / memória da API | 24.4% / 27.5 MiB | 50.3% / 28.8 MiB | 25.6% / 26.8 MiB |
| Pico de CPU da API (mediana dos máximos do `recursos.csv`) | 43.38% | 52.60% | 44.34% |

| Rota (mediana das medianas) | Controle | Mudança | Controle depois |
|---|---|---|---|
| cliente | 103.2 ms | 69.3 ms | 103.7 ms |
| cliente-por-email | 103.5 ms | 71.0 ms | 103.8 ms |
| pedidos-do-cliente | 293.8 ms | 102.3 ms | 289.0 ms |
| pedidos-por-status | 417.8 ms | 92.7 ms | 431.9 ms |
| busca-produtos | 182.9 ms | 78.3 ms | 168.9 ms |
| vendas-por-dia | 101.9 ms | 71.3 ms | 103.0 ms |
| top-produtos | 104.2 ms | 72.1 ms | 106.1 ms |

- **Conclusão:** ~2,9x mais requisições/s (90.51 → 265.71) e p95 ~73% menor, com todas as rotas mais rápidas. Os dois controles ficaram praticamente iguais (90.51 e 91.89 req/s; p95 de 604.5 e 601.6 ms), então o ganho é da mudança. Pela primeira vez desde a linha de base, o banco saiu do limite (CPU média de 96.9% para 57.8%): a contagem era o maior consumidor de CPU do banco que sobrava. **O gargalo passou para a API**, com CPU média de 50.3%, igual ao limite de 0.5 CPU, e picos acima dele (52.60% de mediana dos máximos; 54.86% no maior). A memória média do banco subiu na mudança (365.2 → 437.8 MiB), mas o controle depois também ficou alto (426.4 MiB), então isso parece variação entre séries, e não efeito da mudança.
- **Custos e limites:** a tabela ocupa 32 kB. O custo real fica nas escritas, que a carga não mede: ~3,6x no `INSERT` de 10 mil pedidos no diagnóstico isolado. Além disso, todas as escritas de um mesmo status atualizam a mesma linha da tabela-resumo e esperam umas pelas outras até o fim da transação; numa loja com muitos pedidos simultâneos, isso pode virar um ponto de espera. A documentação do PostgreSQL mostra que triggers por comando com *transition tables* "can be significantly faster than the row-trigger approach when the invoking statement has modified many rows", uma alternativa para inserções em lote que não foi testada.

## 09 · Log de cada resposta sem o corpo da resposta

- **Commit:** `5c11ece` (mudança, [api/src/server.js](api/src/server.js)) · diagnósticos em `36ac39a` (perfil), `1197b05` (exemplo do log), `d2af856` e `cdf5f10` (tamanho do log) · resultados da sessão válida em `ca47cc1`, `ad52bff`, `851ca57`, `60d9eac` e `ceed42c`.
- **O que mudou:** o middleware de [api/src/server.js](api/src/server.js) que registra cada resposta deixou de incluir o campo `resposta` (o corpo inteiro da resposta, serializado com `JSON.stringify`). O log continua com método, URL, status e duração de cada requisição. Nada mais mudou: a resposta HTTP é a mesma, e o contrato foi mantido em todas as execuções.
- **Hipótese:** depois da 08, a API era o gargalo (CPU média no limite de 0.5 CPU). Sem serializar o corpo de cada resposta uma segunda vez só para o log, a API gastaria menos CPU por requisição e a vazão subiria um pouco (estimativa de +5% a +10%). Custo: o log deixa de guardar o conteúdo das respostas.
- **Evidência que originou a ideia:** perfil de CPU da API sob carga, com o código da 08 ([diagnostico/perfil-api-cpu-08.txt](diagnostico/perfil-api-cpu-08.txt)). O middleware de log, inclusivo, ocupava 40.0% do tempo ativo, dos quais 27.0% eram o envio real da resposta pelo Express (que acontece de qualquer forma), 8.2% o `console.log` e 4.5% o tempo próprio do wrapper. O custo do log ficava entre 8.2% e 12.7% do tempo ativo. Nenhuma função do código das rotas aparecia entre as mais pesadas.
- **Formato do log antes e depois** ([diagnostico/log-exemplo-09.txt](diagnostico/log-exemplo-09.txt)): para as mesmas 4 requisições, 2663 bytes antes e 295 bytes depois.
- **Como a medição foi feita, e por que precisou ser repetida:**
  1. **Primeira tentativa (09/11), descartada:** o computador suspendeu durante a 1ª execução do segundo controle, e as outras duas execuções desse controle rodaram no dia seguinte. Sem um segundo controle válido, o A-B-A não fecha (ver "Séries que não entram nas comparações").
  2. **Repetição (10/11):** aquecimento de 60 s sem gravar antes de cada série e código da API conferido com `grep` dentro do container em cada série, sem suspensão do computador. Primeiro, as 3 séries do A-B-A em sequência (r2, das 19:18 às 19:32); depois de ~17 minutos, mais 2 séries (r3, das 19:49 às 19:58), acrescentadas porque o primeiro controle destoou de todas as outras.
- **Fonte sobre a escrita do log:** a documentação do Node.js, *A note on process I/O*, diz que a escrita em `process.stdout` para pipes e sockets é assíncrona em sistemas POSIX (e síncrona para arquivos e terminais) (https://nodejs.org/docs/latest-v20.x/api/process.html#a-note-on-process-io). No Docker, a saída da API vai para um pipe.

| Série (ordem na sessão de 10/11) | Código | Req/s (execuções → mediana) | Mediana geral | p95 | p99 | CPU / memória da API | CPU / memória do banco |
|---|---|---|---|---|---|---|---|
| 1 · 09-controle-r2 | com o corpo | 165.74, 177.60, 176.96 → 176.96 | 100.3 ms | 205.0 ms | 286.9 ms | 49.1% / 28.8 MiB | 56.9% / 449.2 MiB |
| 2 · 09-log-sem-corpo-r2 | sem o corpo | 253.73, 261.31, 266.22 → 261.31 | 81.5 ms | 161.8 ms | 194.9 ms | 49.3% / 28.9 MiB | 60.9% / 457.9 MiB |
| 3 · 09-controle-depois-r2 | com o corpo | 259.45, 266.74, 238.16 → 259.45 | 81.3 ms | 164.2 ms | 195.2 ms | 49.0% / 29.0 MiB | 58.0% / 459.4 MiB |
| 4 · 09-controle-r3 | com o corpo | 296.46, 280.90, 278.57 → 280.90 | 78.4 ms | 153.0 ms | 187.9 ms | 49.4% / 29.5 MiB | 63.4% / 332.9 MiB |
| 5 · 09-log-sem-corpo-r3 | sem o corpo | 253.65, 256.56, 264.33 → 256.56 | 82.6 ms | 157.8 ms | 189.2 ms | 49.1% / 29.0 MiB | 62.8% / 398.0 MiB |

- **Pastas:** [1](resultados/20261110-191818-09-controle-r2), [1](resultados/20261110-191945-09-controle-r2), [1](resultados/20261110-192108-09-controle-r2) · [2](resultados/20261110-192354-09-log-sem-corpo-r2), [2](resultados/20261110-192515-09-log-sem-corpo-r2), [2](resultados/20261110-192636-09-log-sem-corpo-r2) · [3](resultados/20261110-192916-09-controle-depois-r2), [3](resultados/20261110-193037-09-controle-depois-r2), [3](resultados/20261110-193157-09-controle-depois-r2) · [4](resultados/20261110-194908-09-controle-r3), [4](resultados/20261110-195028-09-controle-r3), [4](resultados/20261110-195149-09-controle-r3) · [5](resultados/20261110-195431-09-log-sem-corpo-r3), [5](resultados/20261110-195552-09-log-sem-corpo-r3), [5](resultados/20261110-195712-09-log-sem-corpo-r3).
- **Leitura:**
  - **A série 1 destoa** de todas as outras: 176.96 req/s, contra 256 a 281 nas séries 2 a 5. A CPU da API ficou em ~49% em todas, então na série 1 a mesma CPU rendeu menos requisições. A hipótese é que o computador estava mais lento nos primeiros minutos da sessão; a causa não foi verificada. Ela fica fora da comparação e mantida como evidência do ruído do ambiente.
  - **Pares vizinhos, mudança contra controle:** série 2 contra série 3, **+0.7%** (261.31 contra 259.45; a faixa do controle, 238.16 a 266.74, contém a da mudança); série 5 contra série 4, **−8.7%** (256.56 contra 280.90).
  - **Variação entre controles do mesmo código, na mesma noite (~17 minutos de intervalo):** séries 3 e 4, 259.45 e 280.90 req/s, ~8% de diferença. As duas diferenças da mudança (+0.7% e −8.7%) ficam dentro dessa variação, então não dá para afirmar nem ganho nem perda. O ganho estimado de +5% a +10% não apareceu em nenhum dos pares.
  - **Recursos:** CPU da API em ~49% em todas as séries, com picos de 52.15% a 53.82% no `recursos.csv`; memória da API entre 28.8 e 29.5 MiB em todas. Nenhuma das duas mudou com a remoção do corpo.
- **Tamanho do log** ([diagnostico/bytes-de-log-09-r2.txt](diagnostico/bytes-de-log-09-r2.txt), 1ª execução de cada série, incluindo aquecimento e verificação de contrato): 15766698 bytes no controle (série 1) e 1577798 bytes na mudança (série 2), cerca de 10 vezes menos. Na tentativa de 09/11 ([diagnostico/bytes-de-log-09.txt](diagnostico/bytes-de-log-09.txt)), 18891047 contra 1085787 bytes.
- **Conclusão: Aplicada, sem ganho** (de vazão). Remover o corpo do log não mudou a vazão, a CPU ou a memória da API de forma mensurável. O que ela entregou de concreto foi um log cerca de 10 vezes menor, com o custo de não registrar mais o conteúdo das respostas. A mudança foi mantida, porque não piorou nenhuma métrica com diferença maior que o ruído e reduz o volume de log.
- **Por que o ganho do perfil não apareceu:** o perfil mostrava o log com 8.2% a 12.7% do tempo ativo da API, mas a fatia de CPU de uma função não vira, automaticamente, ganho de vazão. Uma explicação possível, não verificada, é que a escrita no pipe já é assíncrona e não segurava as respostas; outra é que o ganho existe, mas é menor que a variação de ~8% entre séries daquela sessão, que é o limite do que este teste consegue detectar.
- **Lição de método:** sem o controle repetido, esta mudança teria três conclusões erradas: na tentativa de 09/11, comparando só com o primeiro controle, ela pareceria ter piorado; na repetição, contra o primeiro controle, pareceria ter melhorado 47.7%; olhando só o último par, pareceria ter piorado 8.7%.

## 10 · Limite de CPU da API de 0.5 para 1.0 (experimento de escala, revertido)

- **Commit:** `baa518a` (mudança, [docker-compose.yml](docker-compose.yml)) · resultados em `3a1a4aa` (controle), `434faf2` (mudança) e `97292de` (controle depois) · revertida em `4c50db5`.
- **O que mudou:** só o limite de CPU do serviço `api` no `docker-compose.yml`, de `cpus: "0.5"` para `cpus: "1.0"`. Código, banco e memória (256 MB) não mudaram. É a única mudança que aumenta recurso, então o ganho vem com o custo.
- **Hipótese:** depois da 08 e da 09, a API era o gargalo (CPU média de ~49% para um limite de 50%, enquanto o banco ficava em ~57–63%), e todas as rotas levavam ~70–105 ms, sinal de fila na API. Com 1.0 CPU, a API deixaria de ser o limite e a vazão subiria até o banco voltar a ser o gargalo. Um processo Node usa ~1 CPU para o JavaScript, então 1.0 é o máximo útil sem cluster.
- **Condições:** A-B-A no mesmo banco, em sessão contínua, aquecimento de 60 s antes de cada série, computador na tomada. O `contexto.txt` de cada execução registra o limite: `api: cpus=500000000` nos dois controles e `cpus=1000000000` na mudança.
- **Antes (controle, 0.5 CPU):** [10-controle](resultados/20261110-203407-10-controle), [2](resultados/20261110-203527-10-controle), [3](resultados/20261110-203647-10-controle).
- **Depois (1.0 CPU):** [10-api-1cpu](resultados/20261110-203927-10-api-1cpu), [2](resultados/20261110-204048-10-api-1cpu), [3](resultados/20261110-204208-10-api-1cpu).
- **Controle depois (0.5 CPU):** [10-controle-depois](resultados/20261110-204444-10-controle-depois), [2](resultados/20261110-204604-10-controle-depois), [3](resultados/20261110-204724-10-controle-depois).

| Métrica (mediana das 3) | Controle (0.5 CPU) | Mudança (1.0 CPU) | Controle depois (0.5 CPU) |
|---|---|---|---|
| Requisições/s | 246.53 (execuções: 246.53, 259.87, 244.54) | 473.73 (execuções: 473.73, 472.00, 510.51) | 273.22 (execuções: 273.22, 269.27, 275.01) |
| Mediana geral | 82.9 ms | 35.1 ms | 79.3 ms |
| p95 | 169.6 ms | 87.4 ms | 130.7 ms |
| p99 | 202.9 ms | 113.8 ms | 191.5 ms |
| CPU / memória do banco | 63.3% / 328.2 MiB | 101.3% / 423.6 MiB | 61.9% / 432.9 MiB |
| CPU / memória da API | 49.4% / 28.9 MiB | 75.4% / 29.3 MiB | 49.5% / 29.0 MiB |
| Pico de CPU da API (mediana dos máximos do `recursos.csv`) | 52.66% | 87.30% | 52.50% |
| Pico de CPU do banco (mediana dos máximos do `recursos.csv`) | 76.51% | 104.82% | 79.64% |

| Rota (mediana das medianas) | Controle | Mudança | Controle depois |
|---|---|---|---|
| cliente | 73.5 ms | 25.1 ms | 70.4 ms |
| cliente-por-email | 73.5 ms | 25.6 ms | 70.7 ms |
| pedidos-do-cliente | 104.6 ms | 59.7 ms | 100.4 ms |
| pedidos-por-status | 95.2 ms | 50.8 ms | 91.5 ms |
| busca-produtos | 81.3 ms | 37.4 ms | 78.3 ms |
| vendas-por-dia | 74.7 ms | 26.0 ms | 71.7 ms |
| top-produtos | 74.9 ms | 25.2 ms | 72.0 ms |

- **Leitura:** +92.2% contra o controle antes e +73.4% contra o controle depois; os dois controles diferem 10.8% entre si, e as faixas não se sobrepõem (controles de 244.54 a 275.01, mudança de 472.00 a 510.51), então o ganho não é ruído. Todas as rotas ficaram ~2 a 3 vezes mais rápidas, o que confirma que o tempo das rotas simples era fila na API. Depois da mudança, **o banco virou o limite** (CPU média de 101.3%, pico de 104.82%), e a API ficou com folga (75.4% de 100%).
- **Custo e ganho (contas sobre as medianas):** a CPU reservada no total foi de 1.5 (0.5 da API + 1.0 do banco) para 2.0, ou +33%. A vazão foi de 259.88 (média dos dois controles) para 473.73 req/s, ou +82%. Em requisições por CPU reservada no total, de ~173 para ~237. A vazão cresceu mais que o custo porque o banco tinha folga e estava esperando a API; com o banco agora no limite, mais CPU só na API não ajudaria mais.
- **Por que foi revertida:** a pergunta do desafio é deixar a aplicação mais rápida e mais barata sem mudar o que ela faz. A versão final mantém os recursos originais (API com 0.5 CPU, banco com 1.0) e mostra o ganho que veio só de tirar desperdício. A 10 fica como experimento de escala: responde quanto custa crescer quando ~260 req/s não bastarem. A configuração com 0.5 CPU é a mesma dos dois controles, já medidos; depois do revert, o contrato foi conferido ("Contrato mantido").
- **O que não foi testado:** mais CPU no banco, que passaria a ser o próximo passo de escala, e o cluster de processos Node, que só faz sentido com mais de 1 CPU na API (ver [proximos-testes.md](proximos-testes.md)).

## 11 · Remoção do `idx_pedidos_criado_em_dia`

- **Commit:** `d9a15a3` (mudança, [banco/08-remove-idx-pedidos-criado-em-dia.sql](banco/08-remove-idx-pedidos-criado-em-dia.sql)) · verificação dos planos em `4c0ce23` · resultados em `4183222` (controle), `cd60e1e` (mudança) e `af4824b` (controle depois) · resumo e tamanhos em `a1952e2` ([diagnostico/mudanca-11/resumo-medicoes.txt](diagnostico/mudanca-11/resumo-medicoes.txt)).
- **O que mudou:** um `.sql` novo com `DROP INDEX idx_pedidos_criado_em_dia`. O `03-indices.sql`, onde o índice foi criado, não foi editado, para o histórico mostrar a criação na 02 e a remoção na 11.
- **Hipótese:** o índice foi criado na mudança 02 para a consulta antiga de `vendas-por-dia`; desde a 06, essa rota lê a `vendas_por_dia_mv`, e nenhuma rota usa o índice. Removê-lo não deve mudar a vazão nem as latências desta carga, que só lê; economiza o espaço do índice e deixa as escritas em `pedidos` um pouco mais baratas, o que esta carga não mede.
- **Evidência:**
  - nas 9 medições da mudança 07, o `idx_scan` do índice ficou em 0 antes e depois ([diagnostico/idx-scan-depois-07.txt](diagnostico/idx-scan-depois-07.txt));
  - antes de mudar, as 24 consultas de todas as rotas foram analisadas com `EXPLAIN (ANALYZE, BUFFERS)`, 3 vezes cada, com o índice e sem ele (dentro de `BEGIN ... ROLLBACK`): a forma do plano é igual nas 24, e nenhuma usa o índice ([diagnostico/mudanca-11/01-planos-resumo.txt](diagnostico/mudanca-11/01-planos-resumo.txt)). Os tempos variaram entre 0.11x e 2.31x (sem ÷ com), o ruído normal de consultas de poucos milissegundos;
  - correção: depois da 07, o contador do índice chegou a 3 usos. A causa é o `SELECT count(*) FROM pedidos` dos scripts de diagnóstico, que o banco resolve por esse índice por ser o menor da tabela. Nenhuma rota faz essa consulta; sem o índice, ela usaria outro.
- **Condições:** A-B-A em sessão contínua, com 60 s de aquecimento antes de cada série, o computador na tomada em todas as execuções e o banco recriado do zero a cada troca de versão: controle com o índice (o banco antes da mudança), mudança sem o índice e controle depois com o índice de novo (com os arquivos de `banco/` do commit anterior). No fim, o banco foi recriado na versão final, sem o índice.
- **Antes (controle, com o índice):** [11-controle](resultados/20261117-130442-11-controle), [2](resultados/20261117-130603-11-controle), [3](resultados/20261117-130725-11-controle).
- **Depois (sem o índice):** [11-sem-indice-dia](resultados/20261117-131145-11-sem-indice-dia), [2](resultados/20261117-131307-11-sem-indice-dia), [3](resultados/20261117-131428-11-sem-indice-dia).
- **Controle depois (com o índice):** [11-controle-depois](resultados/20261117-131849-11-controle-depois), [2](resultados/20261117-132010-11-controle-depois), [3](resultados/20261117-132131-11-controle-depois).

| Métrica (mediana das 3) | Controle | Mudança | Controle depois |
|---|---|---|---|
| Requisições/s | 296.32 (execuções: 290.65, 297.88, 296.32) | 296.84 (execuções: 320.36, 292.85, 296.84) | 293.69 (execuções: 286.16, 300.70, 293.69) |
| Mediana geral | 75.8 ms | 76.0 ms | 76.5 ms |
| p95 | 115.2 ms | 115.1 ms | 113.7 ms |
| p99 | 183.9 ms | 182.8 ms | 182.9 ms |
| CPU / memória do banco | 61.5% / 382.1 MiB | 57.4% / 439.4 MiB | 59.5% / 449.1 MiB |
| CPU / memória da API | 50.6% / 73.3 MiB | 50.1% / 28.0 MiB | 49.5% / 27.9 MiB |

As rotas estão no resumo. As diferenças pequenas por rota (por exemplo, `/clientes/:id` com 48.1 ms na mudança, contra 64.5 e 61.7 nos controles) vêm de uma única execução fora da curva e não são evidência de efeito.

- **Custo e ganho:** os índices de `pedidos` foram de 42868736 bytes (4 índices) para 39231488 bytes (3 índices): 3637248 bytes, ou 3552 kB, a menos.
- **Conclusão: Aplicada, sem ganho** (de vazão). A mudança ficou a +0.2% do controle antes e a +1.1% do controle depois, e os dois controles diferem −0.9% entre si: a diferença está dentro do ruído, e as faixas se sobrepõem. O ganho concreto é o espaço em disco e, provavelmente, escritas um pouco mais baratas. A série `11-sem-indice-dia` é a medição da versão final da aplicação.
- **Observações sem explicação:** a memória média da API no primeiro controle (73.3 MiB, contra ~28 MiB nas outras séries) e a memória do banco subindo ao longo da sessão (382.1, 439.4 e 449.1 MiB).
- **Lição:** um índice que ajudou numa etapa pode ficar sem uso na seguinte. Antes de removê-lo, conferir o uso (`idx_scan`) e os planos de todas as consultas.

## Simulação de escritas: limites das mudanças 04, 06 e 08

A carga do desafio só lê, então ela não mostra o que as views e o trigger custam quando os dados mudam. Este diagnóstico simulou escritas numa cópia do banco para medir esses custos. Não é uma mudança e não é medição oficial: os números estão em [diagnostico/simulacao-escritas/](diagnostico/simulacao-escritas/) (resumo em [07-resumo.txt](diagnostico/simulacao-escritas/07-resumo.txt)), não em `resultados/`, e não se comparam com as medições do `medir.sh`.

- **Commit:** `5fc5225`, em 16/11/2026.
- **Como foi feito:** cópia do banco (`CREATE DATABASE loja_teste TEMPLATE loja`) no mesmo container, com a mesma 1 CPU e 512 MB, e a API parada durante o teste. O `pgbench` (a ferramenta de carga do PostgreSQL) rodou num container separado, para não dividir a CPU do banco. Ao fim, a cópia foi apagada, e o banco `loja` foi comparado com o estado salvo antes: 121 linhas e 5 impressões digitais md5 iguais, os 4 triggers ligados, e o contrato mantido. A API voltou com 0.5 CPU e o mesmo código do repositório.
- **Erros no caminho, corrigidos e registrados nos cabeçalhos dos arquivos:** a primeira tentativa usou `-d` no `pgbench`, que liga o modo de depuração (o banco é o argumento final do comando); a depuração distorcia a vazão (a leitura de referência foi de 632.479 para 947.549 tps sem ela), e os passos afetados foram refeitos. Um erro de tipo na consulta do estado dos triggers foi corrigido antes de qualquer execução.

**1. As views ficam desatualizadas; o trigger não.** Lote fictício na cópia: 5000 pedidos `pago` em 2025-12-31, com 15000 itens, 1000 deles com 100 unidades do produto 91 (o 10º do ranking).

| Item | Antes | Depois do lote, sem `REFRESH` | Depois do `REFRESH` |
|---|---|---|---|
| 1º do ranking (view / cálculo ao vivo) | 167 / 167 | 167 / 91 | 91 / 91 |
| Receita do 1º (view / ao vivo) | 4882457440 / 4882457440 | 4882457440 / 13506833440 | 13506833440 / 13506833440 |
| `vendas_por_dia_mv` em 2025-12-31 (view / ao vivo) | 619 pedidos, 915440530 / igual | 619 pedidos, 915440530 / 5619 pedidos, 17812070200 | 5619 pedidos, 17812070200 / igual |
| `pedidos_por_status`, `pago` (resumo / `count(*)`) | 300000 / 300000 | 305000 / 305000 | 305000 / 305000 |

**2. Custo do `REFRESH`** (3 execuções, cópia sem carga): `top_produtos_mv` com mediana de 3067.163 ms no normal e 3353.363 ms no `CONCURRENTLY`; `vendas_por_dia_mv` com 2385.805 ms e 2126.060 ms. O `CONCURRENTLY` exige um índice único: `vendas_por_dia_mv` já tem (em `dia`); para `top_produtos_mv`, o teste criou um índice único em `id` só na cópia, porque a aplicação não tem esse índice.

**3. O `REFRESH` normal trava as leituras.** Com 5 clientes lendo as duas views sem parar por 20 s, e um `REFRESH` disparado no meio:

| Caso | Vazão | Latência média | Latência máxima | Segundos com 0 leituras |
|---|---|---|---|---|
| Sem `REFRESH` | 947.5 tps | 5.178 ms | 130.265 ms | nenhum |
| `REFRESH` normal | 773.3 tps | 6.371 ms | 4794.003 ms | 3 |
| `REFRESH CONCURRENTLY` | 799.6 tps | 6.149 ms | 95.492 ms | nenhum (mínimo de 448.0 tps por segundo) |

Com o `CONCURRENTLY`, as leituras não pararam, mas o próprio `REFRESH` ficou mais lento sob carga: 12196.170 ms para `vendas_por_dia_mv`, contra 2126.060 ms sem carga.

**4. Os triggers sob escritas simultâneas.** Cada transação insere e apaga um pedido e confirma (`COMMIT`), deixando os totais como estavam. 8 combinações × 3 execuções de 30 s, em ordem alternada, 0 falhas. Vazão em transações por segundo (mediana):

| Clientes | Status | Com triggers | Sem triggers | Sem ÷ com (conta) |
|---|---|---|---|---|
| 1 | só `pago` | 672.7 | 853.9 | 1.27x |
| 1 | sorteado entre os 4 | 683.9 | 815.6 | 1.19x |
| 10 | só `pago` | 629.4 | 739.5 | 1.18x |
| 10 | sorteado entre os 4 | 636.3 | 758.0 | 1.19x |

Com 10 clientes e triggers, "só `pago`" × "sorteado" deu 1.01x (sorteado ÷ fixo). No fim, a tabela-resumo bateu com o `count(*)` (`pago` 305000).

- **Leitura:**
  - **Views:** confirmado com dados que os relatórios ficam com o valor antigo até o `REFRESH`, que custa ~2 a 3 s por view sem carga. O `REFRESH` normal parou as leituras por até ~4,8 s; o `CONCURRENTLY` não parou, mas demorou mais sob carga e exige um índice único que `top_produtos_mv` não tem na aplicação.
  - **Trigger:** manteve o total correto em todos os momentos e custou ~1.2x em vazão de escrita neste cenário. A variação entre execuções foi grande (por exemplo, de 593.2 a 861.1 tps no mesmo caso), então o custo real pode ser um pouco maior ou menor. A fila na linha da tabela-resumo, prevista para escritas simultâneas do mesmo status, não apareceu (1.01x).
- **Comparação com o diagnóstico anterior e com a literatura:** no diagnóstico isolado da 08, 10 mil inserções numa única transação, sem confirmar a gravação, ficaram ~3,6x mais lentas com o trigger; aqui, com cada transação confirmada, o custo ficou em ~1,2x. Nelson (2016) relata inserções "fifty times slower" com um contador mantido por trigger. A diferença depende do cenário; uma explicação possível, não verificada, é que o custo de confirmar cada transação dilui o custo do trigger.
- **Hipóteses não verificadas:** o `REFRESH` normal trava as leituras por um bloqueio exclusivo na view durante a reconstrução (o observado foi a espera, com a latência máxima próxima da soma dos dois `REFRESH`); a fila no placar pode não ter aparecido porque o gargalo estava na confirmação das transações, e não na linha da tabela-resumo.
- **O que fica para o artigo:** os relatórios em materialized view trocam atualidade por desempenho, e atualizá-los exige escolher entre travar as leituras (`REFRESH` normal) ou um refresh mais lento com índice único (`CONCURRENTLY`); o contador por trigger fica sempre correto, a um custo de escrita que, neste cenário, foi de ~20%.

## Carga mista: escritas e `REFRESH` com a API sob carga

A simulação acima mediu leituras e escritas separadas, direto no banco. Este diagnóstico mediu o efeito nas rotas da API: o `scripts/medir.sh` oficial, sem nenhuma mudança na régua, rodou enquanto outra carga acontecia no mesmo banco. Não é uma mudança: as pastas de `resultados/` usam o prefixo `diag-` e **não se comparam com as mudanças 01 a 10**, porque têm uma carga extra rodando junto. Resumo gerado por script em [diagnostico/carga-mista/resumo.txt](diagnostico/carga-mista/resumo.txt).

- **Commits:** resultados em `9674199`, `9819836`, `38ae15d`, `aa1459a` e `3cdf9db` (uma série por commit) e diagnóstico em `0a341db`, em 16/11/2026.
- **Como foi feito:** versão final (API com 0.5 CPU, banco com 1.0), sessão contínua, 60 s de aquecimento antes de cada série, computador na tomada. Nada foi gravado no repositório durante as medições (as 15 execuções registram `arquivos alterados sem commit: 0`) e todas mantiveram o contrato. As escritas usaram o `pgbench` num container separado; cada transação insere e apaga um pedido e confirma (`COMMIT`), então os totais não mudam. No fim, o banco foi recriado com `down -v` e comparado com o estado salvo antes (121 linhas e 5 impressões digitais md5 iguais, os 4 triggers ligados, contrato mantido).
- **As 5 séries, nesta ordem, com 3 execuções cada:**
  - **A · `diag-controle`:** só o `medir.sh`.
  - **B · `diag-com-escritas`:** o `medir.sh` com escritas a uma taxa fixa de 50 transações por segundo (`pgbench -c 2 -R 50`), cobrindo o aquecimento e a medição.
  - **C · `diag-refresh-normal`:** `REFRESH` normal das duas views ~45 s depois do início de cada execução, no meio dos 60 s medidos.
  - **D · `diag-refresh-concorrente`:** `REFRESH CONCURRENTLY` só de `vendas_por_dia_mv` no mesmo momento (`top_produtos_mv` não tem índice único na aplicação).
  - **A' · `diag-controle-depois`:** só o `medir.sh` de novo.
- **Pastas:** A [1](resultados/20261116-215231-diag-controle), [2](resultados/20261116-215352-diag-controle), [3](resultados/20261116-215513-diag-controle) · B [1](resultados/20261116-215754-diag-com-escritas), [2](resultados/20261116-215915-diag-com-escritas), [3](resultados/20261116-220036-diag-com-escritas) · C [1](resultados/20261116-220353-diag-refresh-normal), [2](resultados/20261116-220514-diag-refresh-normal), [3](resultados/20261116-220634-diag-refresh-normal) · D [1](resultados/20261116-220904-diag-refresh-concorrente), [2](resultados/20261116-221024-diag-refresh-concorrente), [3](resultados/20261116-221145-diag-refresh-concorrente) · A' [1](resultados/20261116-223726-diag-controle-depois), [2](resultados/20261116-223847-diag-controle-depois), [3](resultados/20261116-224007-diag-controle-depois).

| Métrica (mediana das 3) | A · controle | B · com escritas | C · `REFRESH` normal | D · `REFRESH CONCURRENTLY` | A' · controle depois |
|---|---|---|---|---|---|
| Requisições/s | 254.34 (250.28, 260.13, 254.34) | 233.13 (246.18, 229.21, 233.13) | 217.39 (208.88, 217.39, 217.85) | 232.55 (232.55, 229.07, 232.57) | 236.74 (243.62, 236.74, 235.19) |
| Mediana geral | 82.3 ms | 86.2 ms | 85.4 ms | 85.2 ms | 85.5 ms |
| p95 geral | 164.0 ms | 173.3 ms | 178.6 ms | 179.0 ms | 169.1 ms |
| p99 geral | 195.4 ms | 203.4 ms | 269.8 ms | 215.4 ms | 197.9 ms |
| CPU do banco (média / pico) | 58.2% / 73.6% | 73.9% / 92.2% | 79.1% / 103.5% | 79.1% / 103.2% | 73.7% / 86.2% |
| Memória do banco | 391.4 MiB | 389.5 MiB | 398.5 MiB | 411.0 MiB | 453.5 MiB |
| CPU da API (média / pico) | 49.6% / 52.0% | 49.1% / 53.5% | 45.8% / 52.4% | 48.7% / 52.2% | 49.5% / 52.7% |

| Rota (mediana · p95 · p99, em ms) | A | B | C | D | A' |
|---|---|---|---|---|---|
| `/pedidos` | 94.8 · 170.4 · 198.6 | 103.6 · 183.6 · 236.2 | 104.0 · 197.8 · 291.0 | 105.7 · 198.8 · 262.3 | 103.8 · 182.2 · 207.9 |
| `/clientes/:id/pedidos` | 104.9 · 186.5 · 253.9 | 112.7 · 194.2 · 261.6 | 112.1 · 205.9 · 296.1 | 110.6 · 203.4 · 278.5 | 108.7 · 187.1 · 226.6 |
| `/relatorios/vendas-por-dia` | 73.3 · 100.0 · 162.8 | 76.8 · 104.6 · 176.9 | 76.9 · 104.6 · 206.6 | 73.7 · 103.5 · 160.4 | 76.1 · 98.9 · 158.0 |
| `/relatorios/top-produtos` | 71.1 · 99.1 · 160.5 | 75.2 · 103.1 · 161.4 | 75.9 · 113.5 · 5178.7 | 74.8 · 106.7 · 176.6 | 75.1 · 100.5 · 139.1 |

As outras três rotas estão no resumo. Na série C, o p99 de `top-produtos` por execução foi 6060.4, 5178.7 e 5058.3 ms.

- **Escritas (série B):** o `pgbench` manteve 50.225 transações por segundo (mediana), com latência média de 8.410 ms e nenhuma falha.
- **Duração dos `REFRESH` com a API lendo:** normal, mediana de 7533.543 ms para `top_produtos_mv` e 2432.095 ms para `vendas_por_dia_mv`; `CONCURRENTLY` de `vendas_por_dia_mv`, mediana de 13360.626 ms. Na série C, a latência máxima de `top-produtos` ficou entre 6741.1 e 7563.9 ms e a de `vendas-por-dia` entre 2230.8 e 2920.2 ms, iguais às durações dos `REFRESH`. Na série D, as máximas ficaram entre 141.3 e 261.9 ms.
- **Os dois controles:** 254.34 e 236.74 req/s, −6.9%, com a CPU média do banco subindo de 58.2% para 73.7% e a memória de 391.4 para 453.5 MiB. A máquina e o banco não ficaram iguais durante a hora de teste; só diferenças maiores que essa variação podem ser atribuídas à carga extra.

- **Conclusões:**
  1. **O `REFRESH` normal trava os relatórios para quem usa a API.** Quem pediu o ranking durante o refresh esperou até ~7,5 s (o p99 da rota foi de 160.5 para 5178.7 ms), e a série C foi a única com vazão abaixo dos dois controles. A mediana quase não mudou (71.1 para 75.9 ms), porque a espera dura segundos num minuto de medição: o efeito aparece no p99.
  2. **O `CONCURRENTLY` evita a espera**, com o p99 dos relatórios perto do controle, mas o refresh demora bem mais com a API lendo (~13,4 s, contra ~2,1 s com o banco parado na simulação).
  3. **O custo do refresh cresce com o movimento:** o do ranking foi de ~3,1 s com o banco parado (simulação) para ~7,5 s com a API lendo. Em produção, o refresh deve ser `CONCURRENTLY` e agendado para horários de pouco movimento, e o ranking precisa de um índice único para isso.
  4. **Escritas a 50 por segundo não tiveram efeito mensurável nas leituras.** A vazão da série B ficou entre os dois controles, e o aumento de `/pedidos` na mediana (94.8 para 103.6 ms) não pode ser atribuído às escritas, porque o controle depois deu 103.8 ms. Nesse volume, o custo do trigger fica do lado de quem grava (~20% na simulação), não de quem lê.
  5. **A folga do banco absorveu o trabalho extra.** Na versão final, o banco fica em ~58% de CPU; durante as escritas e os refresh, subiu para ~74–79% de média, e só as rotas de relatório travadas mudaram muito. Na configuração da mudança 10 (API com 1.0 CPU), o banco já estava a ~101%, sem folga; a hipótese, não medida, é que o mesmo refresh ou as mesmas escritas atrapalhariam todas as rotas nessa configuração.
- **Hipóteses não verificadas:** a diferença entre os controles pode vir de linhas mortas, do autovacuum ou do cache do banco depois das escritas e dos refresh; o `CONCURRENTLY` demora mais sob carga por disputar a CPU com as leituras.
- **Observações:** passaram-se ~23 minutos entre a série D e a A' (tempo entre as chamadas do operador; cada medição está íntegra, com o `recursos.csv` cobrindo ~61 s). A primeira tentativa da série B parou antes de medir, por um filtro de verificação errado, e foi refeita.

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

| `09-controle`, `09-log-sem-corpo` e `09-controle-depois` · [controle](resultados/20261109-221425-09-controle), [2](resultados/20261109-221549-09-controle), [3](resultados/20261109-221711-09-controle) · [mudança](resultados/20261109-221851-09-log-sem-corpo), [2](resultados/20261109-222015-09-log-sem-corpo), [3](resultados/20261109-222138-09-log-sem-corpo) · [controle depois](resultados/20261109-222318-09-controle-depois), [2](resultados/20261110-190952-09-controle-depois), [3](resultados/20261110-191123-09-controle-depois) | mantidas no repositório | primeira tentativa da mudança 09, em 09/11. O computador suspendeu durante a 1ª execução do segundo controle (0.41 req/s; o relógio saltou de 22:23 de 09/11 para 19:09 de 10/11), e as outras duas execuções desse controle rodaram no dia seguinte, ~24% abaixo do primeiro controle. Sem um segundo controle válido, o A-B-A não fecha. A série mostra também a máquina perdendo desempenho ao longo da noite: o mesmo código da 08 deu 265.71 req/s às 21:22 (`08-resumo-status`) e 212.71 às 22:14 (`09-controle`). Substituída pela repetição de 10/11. |
| `09-controle-r2` (série 1 da repetição) | mantida e mostrada na seção 09 | o mesmo código das séries 3 e 4 deu 176.96 req/s, contra 259.45 e 280.90, com a CPU da API igual (~49%). Fica fora dos pares de comparação e serve como evidência do ruído do ambiente. |

As séries apagadas nunca foram commitadas, por isso não há pastas para elas. A partir daqui, nenhuma pasta de `resultados/` é apagada: medições com problema ficam no repositório, com o motivo registrado nesta tabela.
