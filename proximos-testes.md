# Próximos testes

Ideias que apareceram na pesquisa e nos diagnósticos e que **não foram aplicadas nem medidas**, por falta de tempo, por mudarem o que a aplicação devolve (o que o desafio não permite) ou porque só fariam sentido noutra configuração. Nenhuma ficha traz resultado: onde aparece um número, ele vem de um diagnóstico já salvo no repositório, e a ficha diz qual. As ideias aplicadas e medidas estão em [experimentos.md](experimentos.md).

Cada ficha diz de onde veio a ideia, o que se espera ganhar, como testar e o que seria preciso para testar. As fontes externas foram abertas e conferidas entre 08/11 e 17/11/2026.

---

## 1. Atualização das views em produção

- **De onde veio:** a simulação de escritas e a carga mista ([experimentos.md](experimentos.md), seções "Simulação de escritas" e "Carga mista"). A aplicação entregue não executa nenhum `REFRESH`: as views `top_produtos_mv` e `vendas_por_dia_mv` são criadas uma vez, quando o banco nasce. Documentação: PostgreSQL 16, *Materialized Views*, que mostra um resumo de vendas com índice único e `REFRESH` agendado (https://www.postgresql.org/docs/16/rules-materializedviews.html).
- **O que se espera ganhar:** relatórios com atraso limitado e conhecido, sem travar as leituras. Nos diagnósticos, o `REFRESH` normal travou o ranking por até ~7,5 s com a API sob carga (`diagnostico/carga-mista/resumo.txt`), e o `REFRESH CONCURRENTLY` não travou.
- **Como testar:** criar um índice único em `top_produtos_mv (id)` num `.sql` novo; agendar `REFRESH MATERIALIZED VIEW CONCURRENTLY` nas duas views; medir, com escritas reais acontecendo, o atraso dos relatórios e o p99 das rotas de relatório durante cada refresh, em horários de muito e de pouco movimento.
- **O que precisaria:** um agendador (cron no servidor, extensão de agendamento do PostgreSQL ou job da aplicação), monitoramento que avise se o refresh parar, e um acordo com quem usa os relatórios sobre o atraso aceitável.

## 2. Contador por trigger com triggers por comando

- **De onde veio:** a mudança 08 mantém `pedidos_por_status` com triggers por linha. Documentação: PostgreSQL 16, *Trigger Functions*, Example 43.7: triggers por comando com *transition tables* "can be significantly faster than the row-trigger approach when the invoking statement has modified many rows" (https://www.postgresql.org/docs/16/plpgsql-trigger.html).
- **O que se espera ganhar:** escritas em lote (importações, atualizações em massa) mais baratas: um ajuste por comando, em vez de um por linha. No diagnóstico isolado da 08, inserir 10 mil pedidos numa transação ficou ~3,6x mais lento com o trigger por linha (`diagnostico/custo-escrita-trigger-pedidos-por-status-resumo.txt`).
- **Como testar:** reescrever o trigger com `REFERENCING NEW TABLE ... OLD TABLE ...` e `FOR EACH STATEMENT`; repetir o teste de correção de 8 passos e o custo de inserção em lote, com e sem a troca.
- **O que precisaria:** uma carga de escrita em lote representativa, que o desafio não tem.

## 3. Busca de produtos tolerante a erros

- **De onde veio:** a rota `GET /produtos/busca?q=` só acha nomes que contêm o termo exato; quem digita "cadera" não recebe nenhuma cadeira. Documentação: PostgreSQL 16, *pg_trgm*: a ordenação por semelhança (`ORDER BY nome <-> 'termo'`) "can be implemented quite efficiently by GiST indexes, but not by GIN indexes" (https://www.postgresql.org/docs/16/pgtrgm.html); e *Preferred Index Types for Text Search*: o GiST é "lossy" e pode exigir mais leituras da tabela (https://www.postgresql.org/docs/16/textsearch-indexes.html).
- **O que se espera ganhar:** uma busca melhor para quem digita, não uma busca mais rápida.
- **Como testar:** índice GiST de trigramas (`gist_trgm_ops`) e uma versão nova da rota que mostre primeiro quem contém o termo e complete com os mais parecidos; medir velocidade e também a qualidade dos resultados (por exemplo, com uma lista de termos com erros de digitação e a resposta esperada).
- **O que precisaria:** aceite de produto para mudar o que a rota devolve. O contrato quebraria: `?q=inexistente` hoje devolve lista vazia, e `?q=cadeira` devolve as 20 primeiras em ordem alfabética (`contrato/verificar.js`).

## 4. Paginação por cursor em `/pedidos`

- **De onde veio:** a rota usa `OFFSET`, e a página 1000 ainda percorre ~20 mil entradas do índice (diagnóstico da mudança 07, `diagnostico/explain-pedidos-07-resumo.txt`). Winand, *We need tool support for keyset pagination*: grandes `OFFSET`s "impose a lot of work on the database"; a alternativa é filtrar pelo último valor visto (https://use-the-index-luke.com/no-offset).
- **O que se espera ganhar:** custo constante por página, sem depender do número da página.
- **Como testar:** uma versão da rota que receba o último `(criado_em, id)` visto em vez de `pagina`; medir as páginas fundas com e sem a troca.
- **O que precisaria:** mudar o contrato da rota, que hoje recebe `pagina`. O próprio Winand aponta a limitação: não dá para pular direto para uma página qualquer.

## 5. Mais CPU no banco

- **De onde veio:** na mudança 10 (API com 1.0 CPU), o banco virou o limite, com CPU média de 101.3% (`resultados/*-10-api-1cpu`).
- **O que se espera ganhar:** mais vazão depois de a API ter folga. Sem a vantagem da 10, em que o banco tinha CPU ociosa esperando a API.
- **Como testar:** com a API em 1.0 CPU, medir o banco em 1.0 e em 2.0 CPU em A-B-A, apresentando o ganho junto com o custo.
- **O que precisaria:** apenas o `docker-compose.yml`; o custo é o principal ponto da comparação.

## 6. Desligar o paralelismo do banco

- **De onde veio:** o PostgreSQL usa até 2 processos ajudantes por consulta (`max_parallel_workers_per_gather`, padrão 2), e vários planos salvos mostram `Workers Launched: 2` (`diagnostico/20261105-depois-indices/com-todos.txt`, `diagnostico/explain-pedidos-07.txt`). Com o container limitado a 1 CPU, esses processos dividem a mesma cota. Documentação: PostgreSQL 16, *How Parallel Query Works* (https://www.postgresql.org/docs/16/how-parallel-query-works.html) e *Resource Consumption*: "Setting this value to 0 disables parallel query execution" e consultas paralelas "may consume very substantially more resources" (https://www.postgresql.org/docs/16/runtime-config-resource.html).
- **O que se espera ganhar:** menos CPU gasta em coordenação quando o banco é o gargalo. Na versão final, provavelmente nada: o gargalo é a API, e as consultas que usavam paralelismo foram substituídas por índices e resumos.
- **Como testar:** primeiro, conferir no `EXPLAIN` das consultas da carga se alguma ainda usa *workers* (se nenhuma usar, o ganho esperado é zero); depois, com a API em 1.0 CPU, medir em A-B-A com o parâmetro em 2 e em 0 (com `-c` no `command` do banco).
- **O que precisaria:** a configuração da mudança 10, em que o banco é o limite.

## 7. Dois bancos ou réplica de leitura

- **De onde veio:** ideia de separar os relatórios num banco à parte, ou de dividir as leituras entre duas cópias. Documentação: PostgreSQL 16, *High Availability, Load Balancing, and Replication*: servidores secundários permitem que "several computers to serve the same data" (https://www.postgresql.org/docs/16/high-availability.html); e *Hot Standby*: os dados da réplica são "eventually consistent" com o principal (https://www.postgresql.org/docs/16/hot-standby.html).
- **O que se espera ganhar:** pouco com um banco só para relatórios, que já leem resumos prontos; mais com uma réplica dividindo todas as leituras, quando o banco for o gargalo. Num mesmo container, nada: as duas instâncias dividiriam o mesmo limite de CPU.
- **Como testar:** segundo container PostgreSQL com limites próprios, a API mandando leituras para os dois; A-B-A com o custo dos recursos novos e a comparação com "mais CPU no banco atual" (ficha 5).
- **O que precisaria:** replicação ou cópia dos dados (aqui os dados são determinísticos, mas uma loja real precisaria de replicação, com atraso), um segundo pool na API e o custo de mais um banco.

## 8. Vários processos Node (cluster)

- **De onde veio:** a API roda em um processo só. Documentação: Node.js 20, *Cluster*: "Clusters of Node.js processes can be used to run multiple instances of Node.js that can distribute workloads among their application threads" (https://nodejs.org/docs/latest-v20.x/api/cluster.html).
- **O que se espera ganhar:** nada com 0.5 CPU, porque os processos dividiriam a mesma meia CPU; algum ganho só com mais de 1 CPU na API, onde um processo Node usa ~1 CPU para o JavaScript.
- **Como testar:** com a API em 2.0 CPU, 1 processo × 2 processos, em A-B-A, com o custo.
- **O que precisaria:** mais CPU na API e o banco com folga (fichas 5 e 7).

## 9. Desligar o ETag do Express

- **De onde veio:** o Express calcula um ETag para cada resposta (o cabeçalho `ETag: W/"..."` aparece nas respostas da API), e a carga do desafio nunca o usa. No perfil de CPU da API, a função de hash aparece com 0.9% do tempo ativo (`diagnostico/perfil-api-cpu-08.txt`). Documentação: Express 4, *Application*, tabela de configurações: o `etag` vem ligado (`weak`) e "`false` disables ETag altogether" (https://expressjs.com/en/4x/api/application).
- **O que se espera ganhar:** ~1% de CPU da API, abaixo da variação de ~8% entre controles que este ambiente mostrou. Provavelmente não seria detectável.
- **Como testar:** `app.set('etag', false)` e A-B-A, como na mudança 09.
- **O que precisaria:** confirmar que nenhum cliente da API depende de respostas 304 (o teste de contrato compara status e corpo, não cabeçalhos).

## 10. Menos idas ao banco em `/clientes/:id/pedidos`

- **De onde veio:** leitura do código ([api/src/rotas.js](api/src/rotas.js)): a rota faz 3 consultas por requisição, busca o cliente com `SELECT *` só para saber se ele existe, e busca os pedidos com `SELECT *`, incluindo `observacoes`, que a resposta não usa. É a rota mais lenta na versão final (mediana de 96.2 ms na `11-sem-indice-dia`).
- **O que se espera ganhar:** pouco: são poucas linhas por cliente, e o banco não é o gargalo na versão final.
- **Como testar:** pedir só as colunas usadas e, numa segunda etapa, juntar as consultas; A-B-A.
- **O que precisaria:** nada além de tempo; o resultado provável é "sem diferença mensurável".

## 11. Cache em memória na API

- **De onde veio:** no perfil de CPU da API, o driver `pg` ocupava 9.6% do tempo ativo (`diagnostico/perfil-api-cpu-08.txt`); respostas repetidas evitariam esse trabalho.
- **O que se espera ganhar:** depende de quanto as requisições se repetem. A carga sorteia entre 100 mil clientes, então as rotas de cliente quase não se repetiriam; os relatórios e a busca, sim.
- **Como testar:** cache com tempo de expiração nas rotas de relatório e de busca; medir vazão, memória da API e taxa de acerto do cache.
- **O que precisaria:** decidir o atraso aceitável (o mesmo problema das views) e aceitar o custo de memória; com várias instâncias da API, cada uma teria a sua cópia.

## 12. Leituras pela API com escritas em volume real

- **De onde veio:** a carga mista testou escritas a 50 por segundo e não encontrou efeito mensurável nas leituras ([experimentos.md](experimentos.md), seção "Carga mista").
- **O que se espera ganhar:** saber a partir de que volume de escritas as leituras começam a sofrer, e se a fila na linha do contador (`pedidos_por_status`) aparece em volumes maiores.
- **Como testar:** repetir a carga mista com taxas crescentes de escrita (50, 200, 500 por segundo), com o mesmo A-B-A.
- **O que precisaria:** uma estimativa do volume real de pedidos de uma loja, para escolher taxas que façam sentido.
