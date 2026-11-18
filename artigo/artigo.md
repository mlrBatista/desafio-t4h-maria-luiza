# Medir antes de mudar: 11 mudanças, 4 sem ganho e uma API que atende 160 vezes mais com os mesmos recursos

## 1. Resumo

A API de uma loja fictícia (Node.js e PostgreSQL) atendia 1.86 requisições por segundo sob carga, com p95 de 37,8 s. Segui uma regra: medir, achar o gargalo, mudar uma coisa e medir de novo. Em onze mudanças, troquei leituras de tabelas inteiras por índices, cortei idas ao banco e pré-calculei os resultados mais caros. Quatro mudanças não trouxeram ganho, e entender por quê orientou as seguintes. Medida no mesmo dia e com os mesmos limites de CPU e memória, a versão final atende 296.84 requisições por segundo, com p95 de 115 ms: cerca de 160 vezes mais, sem gastar mais.

## 2. Contexto e diagnóstico

A API tem sete rotas, todas de leitura. Toda versão é medida com o mesmo teste de carga (20 usuários por 60 s, `scripts/medir.sh`) e os mesmos limites: 0.5 CPU para a API e 1 CPU para o banco.

**O sintoma.** A versão original atendia 1.86 requisições por segundo, com p95 de 37,8 s (medianas de 3 execuções; [experimentos.md](../experimentos.md#a-aplicação-original-e-a-versão-final-medidas-no-mesmo-dia)).

**Onde o tempo ia.** O banco ficava a ~97% de CPU e a API a ~9%. Ou seja, a API passava quase todo o tempo esperando o banco.

**Por quê.** Encontrei quatro evidências, e cada uma virou uma hipótese. Ataquei nesta ordem:
- **Conexões.** A API abria uma conexão nova a cada consulta, e o node-postgres estima de 20 a 30 ms por conexão [10]. Hipótese: conectar custa caro. O ganho foi pequeno e o banco seguiu a ~98%; o custo estava nas próprias consultas.
- **Índices.** O `EXPLAIN ANALYZE`, que mostra o caminho e o tempo de cada etapa da consulta [1], mostrou quase todas lendo a tabela inteira (*Seq Scan*). Buscar os itens de um pedido levava 177 ms para achar uma linha ([diagnóstico](../diagnostico/explain-rotas.txt)). Hipótese: faltam índices.
- **Idas ao banco.** A rota de pedidos do cliente fazia 22 consultas para um cliente com 5 pedidos. Hipótese: idas demais (o padrão N+1).
- **Somas repetidas.** A cada chamada, o ranking somava 1,5 milhão de itens, o relatório por dia somava o período e `/pedidos` contava os pedidos do status. Hipótese: o mesmo cálculo era refeito a cada requisição.

Quando o gargalo passou para a API, usei um perfil de CPU (`node --cpu-prof`) [2] para ver onde ela gastava ([diagnóstico](../diagnostico/perfil-api-cpu.txt)).

## 3. Estado da arte

Agrupei as fontes em quatro abordagens, na ordem das hipóteses. As três primeiras reduzem o trabalho; a quarta acrescenta peças para dividi-lo.

### Gastar menos em cada ida ao banco
Abrir uma conexão custa de 20 a 30 ms, e o node-postgres recomenda reaproveitá-las num *pool* [10]; o PgBouncer faz o mesmo como um serviço separado, entre a aplicação e o banco [20]. Fazer uma consulta por item dentro de um laço é o anti-padrão que Chen et al. chamam de *one-by-one processing*; no estudo deles, corrigir anti-padrões desse tipo reduziu o tempo de resposta em até 98% [8]. O guia do Rails chama o mesmo problema de *N + 1 queries* [9].

### Fazer o banco ler menos, com índices
Sem índice, o banco lê a tabela inteira para achar poucas linhas. Um índice leva direto às linhas certas, como o índice de um livro, mas só quando tem o formato da consulta. A documentação do PostgreSQL descreve os formatos que usei:
- **de expressão** [3]: a busca por e-mail ignora maiúsculas, comparando `lower(email)` (o e-mail em minúsculas); o índice guarda o e-mail já em minúsculas;
- **na ordem do `ORDER BY`** [4]: a lista de pedidos é mostrada do mais novo para o mais antigo; com o índice já nessa ordem, o banco lê as primeiras linhas sem ordenar todas;
- **cobrindo** [5]: com todas as colunas pedidas no índice, o banco nem abre a tabela (*index-only scan*);
- **de trigramas** [6]: atende a busca por um trecho no meio do nome (`ILIKE '%termo%'`), que um índice comum não atende.

O custo é espaço em disco e uma atualização a mais em cada escrita.

### Pré-calcular o que o índice não resolve
Quando a consulta precisa somar tudo, o índice não evita o trabalho. Gupta e Mumick tratam a view materializada como um cache do resultado, mais rápido de ler do que recalcular [11]; no PostgreSQL, ela só se atualiza com `REFRESH` [12]. Contar linhas também exige percorrê-las, porque cada transação pode enxergar uma versão diferente da tabela [13]. Para contagens, a documentação mostra uma tabela-resumo mantida por trigger [14]; segundo Nelson, a leitura fica barata e o custo passa para as escritas [15].

### Acrescentar peças
É o caminho comum na nuvem. Uma réplica de leitura do Amazon RDS divide as leituras com o banco principal, mas recebe as mudanças com atraso e é cobrada como outra instância [18]. Um cache como o ElastiCache responde antes do banco, com o risco de devolver dado antigo [19]. As duas funcionam, e as duas são mais uma peça para pagar e manter.

## 4. Alternativas consideradas

| Alternativa | Custo | Desempenho | Risco | Esforço |
|---|---|---|---|---|
| A. Índices e consultas enxutas | disco (~37 MB nos índices de `pedidos`) e escritas um pouco mais caras | alto: atacou o maior desperdício | baixo: se atualizam sozinhos | baixo |
| B. Pré-cálculo (views materializadas e tabela-resumo com trigger) | quase nenhum disco; refresh ou escritas mais caras | alto nos relatórios e na contagem | dado atrasado (views) ou lógica a manter (trigger) | médio |
| C. Cache: guardar respostas prontas na API ou num serviço como o ElastiCache [19] | memória da API ou um serviço a mais | baixo nesta carga: 60% das requisições pedem um cliente sorteado entre 100 mil, que quase nunca se repete | devolver dado antigo | médio |
| D. Réplica de leitura: uma cópia do banco só para leituras [16][18] | um banco inteiro a mais | só ajuda com o banco no limite; na versão final, o limite é a API | a cópia recebe as mudanças com atraso [17]; mais uma peça para manter | alto |
| E. Mais CPU | +0.5 CPU na API (+33% no total) | medido: ~1,8x | baixo | muito baixo |

Avaliei as alternativas pelo gargalo de cada momento: o banco no começo, depois a API. A, B e E foram aplicadas e medidas. C e D ficaram como testes futuros, e o desempenho delas na tabela é dedução minha, a partir do teste de carga e da CPU medida, sem teste. O custo de B não aparece no teste de carga, que só lê, e por isso foi medido em dois testes à parte (seção 7): numa simulação de escritas numa cópia do banco, sem a API, o trigger deixou as escritas ~20% mais lentas e o `REFRESH` levou ~2 a ~3 s; com o teste de carga rodando junto, o `REFRESH` levou ~7,5 s.

A e B reduzem o trabalho; C, D e E acrescentam peças ou capacidade. Acrescentar capacidade enquanto o banco lê tabelas inteiras é pagar para desperdiçar mais rápido.

## 5. Solução escolhida e por quê

Escolhi A e B, nessa ordem, e usei E só como experimento. O critério foi o próprio desafio: mais rápido **e** mais barato. Índices e consultas enxutas tiram desperdício sem custo de recurso. O pré-cálculo entra onde o índice não ajuda, quando a consulta precisa mesmo ler tudo.

Dentro de B, escolhi a ferramenta pelo tipo de dado. Os relatórios usam views materializadas, porque são analíticos e aceitam algum atraso. O total de pedidos por status usa trigger, porque aparece ao lado de uma lista em tempo real e não pode ficar atrasado; com 4 linhas, é simples de manter.

O mercado costuma resolver lentidão acrescentando peças, como uma réplica ou um cache, e pagando por elas. Se eu tivesse colocado uma réplica no começo, ela repetiria as mesmas leituras de tabela inteira: o desperdício seria dividido, não eliminado. A versão entregue chega a ~160x sem nenhuma peça nova. Comprar só passou a valer depois: na mudança 10, com o desperdício já removido, +33% de CPU rendeu +82% de vazão. Mesmo assim, voltei aos limites originais, para mostrar que todo o ganho veio do código e do banco; a mudança 10 fica como o próximo passo se a carga crescer.

## 6. Experimento e resultado

Cada mudança foi medida 3 vezes, e comparei as medianas. A partir da 03, o "antes" é um controle com o código anterior, medido no mesmo dia, porque a máquina variou mais entre dias do que o efeito de algumas mudanças. Desde a 07, o controle foi medido antes e depois da mudança. Os valores medidos aparecem como o `medir.sh` os grava, com ponto decimal.

| Mudança | Hipótese | p95 antes → depois | req/s antes → depois | CPU do banco | CPU da API | Memória do banco (MiB) | Memória da API (MiB) | Pastas de resultados | Conclusão |
|---|---|---|---|---|---|---|---|---|---|
| 01 Pool de conexões | conexões novas custam | 38198.7 → 35717.1 ms | 1.69 → 2.15 | 98.5 → 97.8% | 9.7 → 8.3% | 222.5 → 410.4 | 29.7 → 33.2 | [antes](../resultados/20261103-210235-00-linha-de-base) · [depois](../resultados/20261104-211122-01-pool) | ganho pequeno |
| 02 Índices | consultas leem tabelas inteiras | 35717.1 → 9177.6 ms | 2.15 → 9.43 | 97.8 → 96.1% | 8.3 → 24.1% | 410.4 → 412.6 | 33.2 → 34.0 | [antes](../resultados/20261104-211122-01-pool) · [depois](../resultados/20261104-220255-02-indices) | ~4,4x |
| 03 Fim do N+1 | menos idas ao banco | 10726.4 → 7422.4 ms | 8.35 → 8.60 | 96.2 → 97.4% | 26.2 → 25.9% | 413.9 → 407.7 | 35.6 → 36.1 | [antes](../resultados/20261107-204404-02-indices-hoje) · [depois](../resultados/20261107-205642-03-consulta-unica-v2) | **sem ganho de vazão** |
| 04 View do ranking | agregação refeita a cada chamada | 8213.5 → 2312.2 ms | 8.27 → 22.06 | 95.2 → 65.0% | 23.9 → 46.6% | 407.3 → 468.4 | 34.6 → 42.3 | [antes](../resultados/20261107-211945-03-controle-hoje2) · [depois](../resultados/20261107-211442-04-view-top-produtos) | ~2,7x |
| 05 Soma por dia no SQL | API agregando 57 mil linhas | 1977.8 → 1812.0 ms | 26.59 → 27.07 | 65.8 → 99.3% | 46.8 → 11.9% | 466.7 → 458.5 | 36.6 → 26.1 | [antes](../resultados/20261108-112158-05-controle) · [depois](../resultados/20261108-111727-05-agregacao-sql) | **sem ganho de vazão** |
| 06 View das vendas por dia | agregação refeita a cada chamada | 1803.0 → 1110.2 ms | 29.29 → 53.61 | 99.7 → 100.2% | 12.8 → 20.4% | 465.9 → 428.3 | 26.0 → 25.9 | [antes](../resultados/20261108-114455-06-controle) · [depois](../resultados/20261108-114922-06-resumo-vendas-dia) | ~1,8x |
| 07 Índice cobrindo | páginas fundas visitam a tabela | 1128.3 → 699.0 ms | 51.34 → 81.60 | 97.9 → 97.9% | 18.7 → 25.2% | 426.7 → 371.7 | 27.3 → 27.6 | [antes](../resultados/20261109-195639-07-controle) · [depois](../resultados/20261109-200117-07-indice-cobrindo) | ~1,6x |
| 08 Contagem por trigger | contagem refeita a cada página | 604.5 → 162.3 ms | 90.51 → 265.71 | 96.9 → 57.8% | 24.4 → 50.3% | 365.2 → 437.8 | 27.5 → 28.8 | [antes](../resultados/20261109-211322-08-controle) · [depois](../resultados/20261109-212204-08-resumo-status) | ~2,9x |
| 09 Log sem o corpo | log custa 8–13% da CPU da API | 164.2 → 161.8 ms | 259.45 → 261.31 | 58.0 → 60.9% | 49.0 → 49.3% | 459.4 → 457.9 | 29.0 → 28.9 | [antes](../resultados/20261110-192916-09-controle-depois-r2) · [depois](../resultados/20261110-192354-09-log-sem-corpo-r2) | **sem ganho de vazão**; log ~10x menor |
| 10 API com 1.0 CPU | a API é o gargalo | 169.6 → 87.4 ms | 246.53 → 473.73 | 63.3 → 101.3% | 49.4 → 75.4% | 328.2 → 423.6 | 28.9 → 29.3 | [antes](../resultados/20261110-203407-10-controle) · [depois](../resultados/20261110-203927-10-api-1cpu) | ~1,8x com +33% de CPU; revertida |
| 11 Remover índice sem uso | nenhuma rota o usa | 115.2 → 115.1 ms | 296.32 → 296.84 | 61.5 → 57.4% | 50.6 → 50.1% | 382.1 → 439.4 | 73.3 → 28.0 | [antes](../resultados/20261117-130442-11-controle) · [depois](../resultados/20261117-131145-11-sem-indice-dia) | **sem ganho de vazão**; 3552 kB a menos |
| **Total**, mesmo dia | — | **37824.7 → 115.1 ms** | **1.86 → 296.84** | 97.2 → 57.4% | 9.3 → 50.1% | 388.1 → 439.4 | 27.5 → 28.0 | [original](../resultados/20261117-133817-final-linha-de-base) · [final](../resultados/20261117-131145-11-sem-indice-dia) | **~160x vazão, p95 ~329x menor** |

Nas colunas de CPU, 100% é uma CPU inteira: o banco, com limite de 1 CPU, satura perto de 100%, e a API, com 0.5 CPU, satura perto de 50% (só na 10 ela teve 1 CPU). A memória ficou abaixo dos limites (512 MiB no banco e 256 MiB na API) em todas as medições. Detalhes e séries descartadas estão em [experimentos.md](../experimentos.md).

O raciocínio seguiu o gargalo, em cinco etapas:

1. **Banco no limite, lendo tabelas inteiras.** O pool (01) quase não mudou nada; os índices (02) deram ~4,4x.
2. **Banco ainda no limite.** Tirar o N+1 (03) não mudou a vazão, porque o banco estava ocupado com as somas, e não com as idas. A view do ranking (04) deu ~2,7x e passou o gargalo para a API.
3. **API no limite.** Somar no SQL (05) aliviou a API, mas devolveu o trabalho ao banco, sem ganho. A view das vendas (06) tirou essa soma dos dois lados: ~1,8x.
4. **Banco de volta ao limite, agora em `/pedidos`.** O índice cobrindo (07) deu ~1,6x e a contagem por trigger (08), ~2,9x. A API encostou nos 0.5 CPU dela.
5. **API no limite.** Tirar o corpo do log (09) não mudou a vazão; mais CPU (10) mudou, mas custa. Por fim, removi um índice que nenhuma rota usava (11).

A lição das quatro mudanças sem ganho: melhorar o que não é o gargalo do momento só muda a espera de lugar.

> **Conceitos que aprendi no caminho:** p95 e p99 (a mediana esconde a cauda); *Seq Scan* × *Index Scan* × *Index Only Scan*; índice de expressão, composto e cobrindo (`INCLUDE`); trigramas (GIN × GiST); N+1 e *pool* de conexões; MVCC e por que `count(*)` é lento; view materializada × tabela-resumo com trigger; controle A-B-A e ruído de ambiente; gargalo que muda de lugar. A explicação de cada um e o passo a passo completo estão em [raciocinio-e-conceitos.md](raciocinio-e-conceitos.md).

## 7. Limites e testes futuros

A carga do desafio só lê, então medi à parte o que ela não mostra. Primeiro, numa simulação de escritas com pgbench numa cópia do banco, sem a API, as views ficaram com o valor antigo até o `REFRESH`, e o trigger manteve o total certo, deixando as escritas ~20% mais lentas ([diagnóstico](../diagnostico/simulacao-escritas/07-resumo.txt)). Depois, com o teste de carga rodando junto, um `REFRESH` normal travou o ranking por até ~7,5 s (p99 de 5,2 s), e o `REFRESH CONCURRENTLY` evitou a espera ([diagnóstico](../diagnostico/carga-mista/resumo.txt)). A aplicação entregue não atualiza as views. Em produção, precisaria de um índice único no ranking e de um `REFRESH CONCURRENTLY` agendado.

O ambiente é um notebook com WSL. Entre controles do mesmo código na mesma sessão, a vazão variou de 0.9% a 10.8%. Em dois casos, o mesmo código rendeu muito menos que nas séries vizinhas: na primeira série da sessão da 09 (176.96 req/s, contra 259.45 e 280.90 nas seguintes) e na 03, medida ~25 minutos depois de ligar a máquina (5.96 req/s, contra 8.60 cerca de 40 minutos depois). As duas foram descartadas e estão registradas no experimentos.md. Por isso, só afirmo efeitos bem acima de ~11%. Todas as mudanças com ganho medidas contra controle passaram disso com folga. A exceção é a 01, comparada com a linha de base de outro dia: o ganho dela é o menos firme. A busca de produtos só acha o termo exato. Uma busca tolerante a erros, com índice GiST [6], mudaria o que a rota devolve, e o desafio não permite isso.

Minha conclusão cairia se, com escritas em volume real, o custo do trigger ou do refresh superasse o ganho nas leituras, ou se uma réplica rendesse mais por real gasto do que as mudanças de código. Essas ideias estão em [proximos-testes.md](../proximos-testes.md), com fontes e forma de testar, junto com outras, como paginar pelo último valor visto em vez de `OFFSET` [7].

## 8. Referências

1. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 14.1. Using EXPLAIN. https://www.postgresql.org/docs/16/using-explain.html. Acesso em 08/11/2026.
2. OpenJS Foundation. Node.js v20 Documentation, Command-line API, `--cpu-prof`. https://nodejs.org/docs/latest-v20.x/api/cli.html#--cpu-prof. Acesso em 08/11/2026.
3. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 11.7. Indexes on Expressions. https://www.postgresql.org/docs/16/indexes-expressional.html. Acesso em 08/11/2026.
4. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 11.4. Indexes and ORDER BY. https://www.postgresql.org/docs/16/indexes-ordering.html. Acesso em 08/11/2026.
5. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 11.9. Index-Only Scans and Covering Indexes. https://www.postgresql.org/docs/16/indexes-index-only-scans.html. Acesso em 08/11/2026.
6. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, F.35. pg_trgm. https://www.postgresql.org/docs/16/pgtrgm.html. Acesso em 16/11/2026.
7. Winand, M. We need tool support for keyset pagination. Use The Index, Luke!. https://use-the-index-luke.com/no-offset. Acesso em 10/11/2026.
8. Chen, T.-H.; Shang, W.; Jiang, Z. M.; Hassan, A. E.; Nasser, M.; Flora, P. Detecting Performance Anti-patterns for Applications Developed using Object-Relational Mapping. ICSE 2014. https://ece.uwaterloo.ca/~wshang/pubs/peter_icse2014.pdf. Acesso em 10/11/2026.
9. Ruby on Rails Guides. Active Record Query Interface, N + 1 Queries Problem. https://guides.rubyonrails.org/active_record_querying.html#n-1-queries-problem. Acesso em 08/11/2026.
10. node-postgres. Pooling. https://node-postgres.com/features/pooling. Acesso em 08/11/2026.
11. Gupta, A.; Mumick, I. S. (orgs.). Materialized Views: Techniques, Implementations, and Applications. MIT Press, 1999. https://pages.iai.uni-bonn.de/manthey_rainer/Seminars2018/matView.pdf. Acesso em 10/11/2026.
12. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 41.3. Materialized Views. https://www.postgresql.org/docs/16/rules-materializedviews.html. Acesso em 08/11/2026.
13. PostgreSQL Wiki. Slow Counting. https://wiki.postgresql.org/wiki/Slow_Counting. Acesso em 10/11/2026.
14. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 43.10. Trigger Functions (Example 43.6). https://www.postgresql.org/docs/16/plpgsql-trigger.html. Acesso em 10/11/2026.
15. Nelson, J. Faster PostgreSQL Counting. 2016 (publicado também no blog da Citus Data). https://begriffs.com/posts/2016-10-12-count-performance.html. Acesso em 10/11/2026.
16. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, Chapter 27. High Availability, Load Balancing, and Replication. https://www.postgresql.org/docs/16/high-availability.html. Acesso em 16/11/2026.
17. PostgreSQL Global Development Group. PostgreSQL 16 Documentation, 27.4. Hot Standby. https://www.postgresql.org/docs/16/hot-standby.html. Acesso em 16/11/2026.
18. Amazon Web Services. Amazon RDS User Guide, Working with DB instance read replicas. https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html. Acesso em 17/11/2026.
19. Amazon Web Services. Amazon ElastiCache Developer Guide, Caching strategies for Memcached. https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Strategies.html. Acesso em 17/11/2026.
20. PgBouncer. PgBouncer features. https://www.pgbouncer.org/features.html. Acesso em 17/11/2026.

## 9. Uso de IA

Usei o Claude Code em duas sessões: uma no terminal, sob minha orientação, para aplicar as mudanças, rodar os diagnósticos e as medições; outra para explicar resultados, preparar as instruções e redigir a documentação e o rascunho deste artigo. Conferi cada número contra as pastas de `resultados/` e `diagnostico/`, e cada fonte foi aberta e lida antes de ser citada.
