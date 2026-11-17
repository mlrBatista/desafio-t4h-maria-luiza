# Notas para o artigo

Ideias e trechos guardados durante o trabalho, para usar em `artigo/artigo.md`. Este arquivo é rascunho: decidir antes da entrega se ele fica no repositório ou se é apagado.

## Busca de produtos tolerante a erros (seção 7, Limites e testes futuros)

**Contexto.** A rota `GET /produtos/busca?q=` só acha nomes que **contêm** o termo exato (`nome ILIKE '%termo%'`), em ordem alfabética, com o índice de trigramas GIN `idx_produtos_nome_trgm` (mudança 02). Quem digita "cadera" (sem o "i") não recebe nenhuma cadeira.

**Por que não foi feito.** Uma busca tolerante muda o que a rota devolve, e a regra do desafio é não mudar status, campos, valores nem ordem. O contrato tem casos que quebrariam: `?q=inexistente` hoje devolve lista vazia e passaria a devolver os nomes "mais parecidos"; `?q=cadeira` hoje devolve as 20 primeiras em ordem alfabética e passaria a devolver as 20 mais parecidas, em outra ordem (`contrato/verificar.js`, linhas 37 a 42). É uma decisão de produto, não uma otimização.

**Como seria.** Com um índice de trigramas **GiST** (`USING gist (nome gist_trgm_ops)`) e ordenação pela distância entre os textos (`ORDER BY nome <-> 'termo'`). A documentação do `pg_trgm` diz que essa ordenação "can be implemented quite efficiently by GiST indexes, but not by GIN indexes". Uma forma combinada: mostrar primeiro quem contém o termo e, se vierem poucos resultados, completar com os mais parecidos.

**GIN × GiST (fatos da documentação).**
- Os dois atendem `LIKE` e `ILIKE` (pg_trgm).
- GiST guarda uma assinatura de tamanho fixo por linha e é "lossy": "might produce false matches, and it is necessary to check the actual table row", o que "causes performance degradation due to unnecessary fetches of table records" (Text Search, Preferred Index Types).
- GIN é "the preferred text search index type" (mesma página).
- Só o GiST acelera a ordenação por semelhança (`<->`) (pg_trgm).
- Sem fonte verificada (não citar como fato): que o GiST é mais barato de atualizar que o GIN.

**Cuidados de uma busca tolerante.** Definir um limite do que é "parecido o bastante" (senão "cadera" traz "Caneta" no fim da lista); o desempenho de ordenar por semelhança em tabelas grandes; e passar a medir também a qualidade dos resultados, não só a velocidade.

**Alternativas a pesquisar e verificar antes de citar:** busca textual do PostgreSQL (palavras e plurais, sem corrigir erro dentro da palavra) e um motor de busca dedicado (serviço separado, com custo de manter e copiar os dados).

**Trecho sugerido:**
> A busca de produtos só acha nomes que contêm o termo exato. Uma busca tolerante a erros, com índice GiST e ordenação por semelhança, seria melhor para quem digita, mas muda o que a rota devolve, o que o desafio não permite; fica como proposta de produto em `proximos-testes.md`.

**Fontes (abertas e conferidas em 16/11/2026):**
- PostgreSQL 16, *pg_trgm*: https://www.postgresql.org/docs/16/pgtrgm.html
- PostgreSQL 16, *Preferred Index Types for Text Search*: https://www.postgresql.org/docs/16/textsearch-indexes.html

**Para o `proximos-testes.md`:** ficha "Busca tolerante a erros", com a fonte acima, o que mudaria no contrato, como testar (velocidade e qualidade dos resultados) e o que precisaria (aceite de produto para mudar a resposta da rota).

## Consultas paralelas num banco com 1 CPU (seção 7, Limites e testes futuros)

**Contexto.** O PostgreSQL pode dividir uma consulta grande entre um processo líder e processos ajudantes (*workers*), que trabalham ao mesmo tempo; o líder junta o resultado no nó `Gather`. O `docker-compose.yml` não define nenhum parâmetro do PostgreSQL, então vale o padrão de `max_parallel_workers_per_gather`, que é 2: até 2 ajudantes por consulta, ou 3 processos com o líder.

**Evidência no repositório.** Vários planos salvos mostram consultas paralelas com `Workers Launched: 2`, por exemplo a contagem por status e os relatórios antes das views (`diagnostico/20261105-depois-indices/com-todos.txt`, `diagnostico/explain-pedidos.txt`, `diagnostico/explain-pedidos-07.txt`). A contagem de `pago`, antes da mudança 08, rodava como `Parallel Index Only Scan` com `rows=100000 loops=3`.

**O problema.** O container do banco tem limite de 1 CPU, e esse limite vale para todos os processos dele juntos. Os 3 processos de uma consulta paralela dividem a mesma cota, então a consulta não deve terminar mais rápido, e há o custo de iniciar os ajudantes e de o líder juntar os resultados. Sob carga, várias consultas paralelas ao mesmo tempo disputam a mesma CPU. Isso é uma hipótese: não foi medido.

**Por que não foi testado.** Na versão final (API com 0.5 CPU), o gargalo é a API, e o banco fica em ~62% de CPU (`10-controle-depois`); ajustar o banco não deve mudar a vazão. Além disso, as consultas que usavam paralelismo (contagem, relatórios, páginas fundas) foram eliminadas pelas mudanças 04, 06, 07 e 08; as que sobraram são pequenas, e o PostgreSQL só usa paralelismo em consultas que estima como grandes.

**Quando valeria testar.** Com o banco como gargalo, como na mudança 10 (API com 1.0 CPU, banco a ~101%). Antes, conferir no `EXPLAIN` das consultas da carga se alguma ainda usa *workers*; se nenhuma usar, o ganho esperado é zero. Teste: A-B-A com `max_parallel_workers_per_gather` em 2 (padrão) e em 0 (passado com `-c` no `command` do banco no `docker-compose.yml`), com a API em 1.0 CPU.

**Fatos da documentação.**
- "The number of background workers that the planner will consider using is limited to at most `max_parallel_workers_per_gather`." (How Parallel Query Works)
- O líder também executa a parte paralela, mas "must also read all of the tuples generated by the workers" (mesma página).
- Padrão de `max_parallel_workers_per_gather`: 2; "Setting this value to 0 disables parallel query execution." (Resource Consumption)
- "parallel queries may consume very substantially more resources than non-parallel queries, because each worker process is a completely separate process"; "a parallel query using 4 workers may use up to 5 times as much CPU time, memory, I/O bandwidth, and so forth as a query which uses no workers at all." (mesma página)
- A documentação não fala de limite de CPU de container: a ligação com o nosso limite de 1 CPU é raciocínio nosso, não citação.

**Correção a lembrar.** Numa explicação anterior, foi dito que o banco "enxerga as 12 CPUs e por isso divide em 3 processos". O correto: o 2 é o padrão fixo do parâmetro; o ponto é que o banco não leva em conta o limite de CPU do container.

**Trecho sugerido:**
> O PostgreSQL usou consultas paralelas (2 ajudantes por consulta, o padrão) nas consultas mais pesadas. Com o container limitado a 1 CPU, os processos de uma consulta paralela dividem a mesma cota, e o paralelismo provavelmente só acrescenta custo de coordenação. Não testamos desligá-lo (`max_parallel_workers_per_gather = 0`) porque, na versão final, o gargalo é a API e as consultas que usavam paralelismo foram substituídas por índices e resumos; o teste faria sentido com o banco no limite, como no experimento com 1.0 CPU na API.

**Fontes (abertas e conferidas em 16/11/2026):**
- PostgreSQL 16, *How Parallel Query Works*: https://www.postgresql.org/docs/16/how-parallel-query-works.html
- PostgreSQL 16, *Resource Consumption* (`max_parallel_workers_per_gather`): https://www.postgresql.org/docs/16/runtime-config-resource.html

**Para o `proximos-testes.md`:** ficha "Desligar o paralelismo do banco", com as fontes acima, a hipótese, a condição para valer (banco no limite), o teste A-B-A e a checagem prévia no `EXPLAIN`.

## Simulação de escritas: os custos que a carga não mostra (seções 6 e 7)

**Onde está:** `experimentos.md`, seção "Simulação de escritas"; dados em `diagnostico/simulacao-escritas/` (resumo em `07-resumo.txt`), commit `5fc5225`. Diagnóstico numa cópia do banco, não medição oficial.

**Os números que importam:**
- Sem `REFRESH`, as views ficam com o valor antigo: depois de 5000 pedidos novos, o 1º do ranking continuou 167 na view, enquanto o cálculo ao vivo já mostrava o 91; o total de `pago` do trigger já estava em 305000, igual ao `count(*)`.
- `REFRESH` sem carga: ~3,1 s (ranking) e ~2,4 s (vendas por dia), medianas de 3067.163 e 2385.805 ms.
- `REFRESH` normal com leituras acontecendo: latência máxima de 4794.003 ms e 3 segundos com 0 leituras. `CONCURRENTLY`: latência máxima de 95.492 ms, sem parar, mas o refresh de vendas por dia levou 12196.170 ms sob carga. E o `CONCURRENTLY` exige índice único, que o ranking não tem na aplicação.
- Trigger com escritas confirmadas: ~1.2x mais lento (1.18x a 1.27x), com muito ruído entre execuções; a fila no placar (10 clientes, só `pago` × sorteado) não apareceu (1.01x).

**Discussão com a literatura (seção 3 ou 7):** Nelson (2016, Citus) relata inserções "fifty times slower" com contador por trigger; nós medimos ~3,6x em lote sem confirmar a gravação (diagnóstico de 10/11) e ~1,2x com cada transação confirmada. O custo depende do cenário; a hipótese, não verificada, é que confirmar cada transação dilui o custo do trigger.

**Trecho sugerido (seção 7):**
> A carga do desafio só lê. Numa simulação de escritas numa cópia do banco, os relatórios em materialized view ficaram com o valor antigo até o `REFRESH`; o `REFRESH` normal levou ~2 a 3 s e travou as leituras por até ~4,8 s, e o `CONCURRENTLY` não travou, mas ficou mais lento sob carga e exige um índice único. O total por status mantido por trigger ficou sempre correto, com custo de ~20% na vazão de escrita nesse cenário, e a fila prevista para escritas simultâneas do mesmo status não apareceu. Em produção, os relatórios precisariam de um `REFRESH ... CONCURRENTLY` agendado e de um índice único no ranking.

**Para o `proximos-testes.md`:** índice único em `top_produtos_mv` (habilita `CONCURRENTLY`) e um agendamento de refresh; repetir a simulação com leituras e escritas ao mesmo tempo pela API (não feito: aqui, leituras e escritas foram medidas separadas, direto no banco).

## Carga mista: o refresh e as escritas vistos pela API (seções 6 e 7)

**Onde está:** `experimentos.md`, seção "Carga mista"; resumo em `diagnostico/carga-mista/resumo.txt`; pastas `resultados/*-diag-*` (não se comparam com as mudanças).

**Os números que importam:**
- `REFRESH` normal com a API lendo: o ranking (`/relatorios/top-produtos`) teve p99 de 5178.7 ms, contra 160.5 ms no controle; latência máxima de até 7563.9 ms, igual à duração do refresh (mediana de 7533.543 ms). A mediana quase não mudou (71.1 → 75.9 ms).
- `REFRESH CONCURRENTLY` (só vendas por dia): p99 dos relatórios perto do controle; o refresh levou 13360.626 ms com carga, contra ~2,1 s parado.
- O refresh do ranking: ~3,1 s com o banco parado (simulação) e ~7,5 s com a API lendo.
- Escritas a 50/s: vazão 233.13, entre os controles (254.34 e 236.74); sem efeito mensurável nas leituras.
- Os controles variaram 6.9% em uma hora, mesmo com todos os cuidados.

**Ideias para o texto:**
- A média esconde, o p99 mostra: 1% das pessoas esperou mais de 5 s, justamente as que chegaram durante o refresh. Bom exemplo para explicar percentis no artigo.
- A folga do banco (~58% na versão final) absorveu escritas e refresh; com a API em 1.0 CPU (mudança 10), o banco já estava a ~101%, sem folga. A versão final é mais barata e também deixa folga para manutenção (hipótese, não medida com a API em 1.0).
- Limite do método: efeitos menores que ~7–8% não podem ser afirmados neste ambiente (casos da 09 e das escritas a 50/s); o A-B-A evitou atribuir às escritas uma deriva da máquina (`/pedidos` 103.6 com escritas × 103.8 no controle depois).

**Recomendação de produção (seção 5 ou 7):**
1. índice único no ranking, para permitir `REFRESH CONCURRENTLY` nas duas views;
2. refresh `CONCURRENTLY` agendado para horários de pouco movimento;
3. monitorar o p99 das rotas de relatório, não só a média;
4. ao escalar a API, garantir folga no banco para essas tarefas, ou escalar os dois juntos.

**Trecho sugerido (seção 7):**
> Com a API sob carga, um `REFRESH` normal deixou o ranking de mais vendidos travado por até ~7,5 s: o p99 da rota foi de 160 ms para 5,2 s, embora a mediana quase não mudasse. O `REFRESH CONCURRENTLY` evitou a espera, ao custo de um refresh mais longo (~13 s com carga). Escritas a 50 por segundo não tiveram efeito mensurável nas leituras. Em produção, os relatórios precisariam de um índice único no ranking e de um refresh `CONCURRENTLY` agendado para horários de pouco movimento.

## A aplicação entregue não atualiza as views (seção 7, Limites; ponto que um avaliador pode perguntar)

**O fato.** Nenhum `REFRESH` é executado na aplicação: não há refresh na API, nos `.sql` de `banco/` nem no `docker-compose.yml` (conferido com busca no código em 16/11/2026). As views `top_produtos_mv` e `vendas_por_dia_mv` são criadas uma vez, quando o banco nasce. O `REFRESH CONCURRENTLY` só foi usado nos diagnósticos (simulação de escritas e carga mista).

**Índices únicos.** `vendas_por_dia_mv` tem índice único em `dia` (`banco/05-vendas-por-dia.sql`, `idx_vendas_por_dia_mv_dia`), então já permite o `CONCURRENTLY`. `top_produtos_mv` só tem um índice comum (`banco/04-top-produtos.sql`, `idx_top_produtos_mv_receita`), então o `CONCURRENTLY` não funciona nela. Nos testes, o índice único do ranking foi criado só na cópia do banco, que depois foi apagada.

**Por que não é problema no desafio.** A carga só lê e os dados nunca mudam: as views criadas na inicialização ficam corretas durante todo o teste.

**O que faltaria para produção.**
1. Índice único no ranking (cada produto aparece uma vez na view): `CREATE UNIQUE INDEX ON top_produtos_mv (id);`
2. Um agendador rodando `REFRESH MATERIALIZED VIEW CONCURRENTLY` nas duas views em horários de pouco movimento (cron no servidor, extensão de agendamento do PostgreSQL ou job da aplicação). É uma peça nova, com custo de operação e monitoramento (alertar se o refresh parar).

**Por que não foi implementado.** Sem escritas, o teste do desafio não mediria nenhum efeito; o agendador é uma peça nova; e o índice único exigiria um `.sql` novo e recriar o banco, sem efeito na carga.

**Trecho sugerido:**
> A aplicação entregue não atualiza as views: no desafio, os dados não mudam. Em produção, seria preciso um índice único em `top_produtos_mv` e um `REFRESH ... CONCURRENTLY` agendado para horários de pouco movimento; as medições mostram que o refresh normal travaria o ranking por até ~7,5 s com a API sob carga, e que o `CONCURRENTLY` evita essa espera.

**Para o `proximos-testes.md`:** ficha "Atualização das views em produção" (índice único no ranking + agendamento do `REFRESH CONCURRENTLY`), com a evidência da simulação e da carga mista, como testar (escritas reais e refresh agendado durante a carga) e o que precisaria (um agendador e o acordo sobre o atraso aceitável dos relatórios).

## Mudança 10 e a escolha da versão final (seções 5 e 6)

- 0.5 → 1.0 CPU na API: 246.53 → 473.73 req/s (controle depois: 273.22). CPU total reservada de 1.5 para 2.0 (+33%) para +82% de vazão (259.88 → 473.73, média dos controles); de ~173 para ~237 req/s por CPU. O banco virou o limite (~101%).
- Revertida (`4c50db5`): a versão final mantém os recursos originais, para mostrar o ganho só com a remoção de desperdício. A 10 responde "quanto custa crescer".
- Trecho sugerido:
> Tirando desperdício, a aplicação passou a atender cerca de 150 vezes mais requisições com os mesmos recursos. Num experimento à parte, dobrar a CPU da API (+33% de CPU no total) aumentou a vazão em ~82%, porque o banco tinha folga; a partir daí, o banco virou o limite.
- Atenção: o "~150 vezes" compara a linha de base (03/11) com medições de outros dias. Ou medir os dois no mesmo dia, ou dizer no texto que são dias diferentes.
