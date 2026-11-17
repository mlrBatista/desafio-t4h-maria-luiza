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

## Mudança 10 e a escolha da versão final (seções 5 e 6)

- 0.5 → 1.0 CPU na API: 246.53 → 473.73 req/s (controle depois: 273.22). CPU total reservada de 1.5 para 2.0 (+33%) para +82% de vazão (259.88 → 473.73, média dos controles); de ~173 para ~237 req/s por CPU. O banco virou o limite (~101%).
- Revertida (`4c50db5`): a versão final mantém os recursos originais, para mostrar o ganho só com a remoção de desperdício. A 10 responde "quanto custa crescer".
- Trecho sugerido:
> Tirando desperdício, a aplicação passou a atender cerca de 150 vezes mais requisições com os mesmos recursos. Num experimento à parte, dobrar a CPU da API (+33% de CPU no total) aumentou a vazão em ~82%, porque o banco tinha folga; a partir daí, o banco virou o limite.
- Atenção: o "~150 vezes" compara a linha de base (03/11) com medições de outros dias. Ou medir os dois no mesmo dia, ou dizer no texto que são dias diferentes.
