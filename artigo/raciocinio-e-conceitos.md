# Raciocínio passo a passo e conceitos aprendidos

Apêndice do [artigo](artigo.md). O artigo conta a história em poucas linhas; aqui está cada passo como ele aconteceu: o que eu via, o que eu pensava, o que mudei, o que a medição mostrou e o que aprendi. Os números vêm de [experimentos.md](../experimentos.md), que liga cada um às pastas de `resultados/` e `diagnostico/`. As letras entre colchetes, como [1], remetem às referências do artigo.

## O método

Antes de qualquer mudança, defini uma regra para não me enganar:

1. **Medir** o estado atual (3 vezes, comparando medianas).
2. **Achar o gargalo**: quem está no limite de CPU, o banco ou a API?
3. **Diagnosticar** por que ele está no limite (`EXPLAIN ANALYZE` no banco, perfil de CPU na API).
4. **Formular uma hipótese** com o efeito esperado, antes de mexer.
5. **Mudar uma coisa só**, commitar e conferir que o contrato (as respostas) não mudou.
6. **Medir de novo** e comparar com um controle medido no mesmo dia.
7. **Concluir**, inclusive quando não houve ganho, e escolher o próximo alvo a partir do novo gargalo.

## Os passos

### Passo 0: onde o tempo está sendo gasto?

- **O que eu via:** 1.69 requisições por segundo, p95 de 38,2 s. Banco a ~98% de CPU, API a ~10%.
- **O que eu pensei:** a API está parada, esperando o banco. A primeira suspeita foi a ligação entre os dois: a API abria uma conexão nova a cada consulta.
- **Outras evidências:** o `EXPLAIN ANALYZE` mostrou quase todas as consultas fazendo *Seq Scan*; buscar os itens de um pedido levava 177 ms para achar uma linha. No código, a rota de pedidos do cliente fazia 22 idas ao banco para um cliente com 5 pedidos.

### Passo 1: pool de conexões (01)

- **Hipótese:** abrir uma conexão nova por consulta custa 20 a 30 ms [10].
- **Resultado:** 1.69 → 2.15 req/s. O banco continuou a ~98%.
- **O que aprendi:** o ganho foi real, mas pequeno, e o banco seguiu a ~98%: o custo não estava em abrir conexões, e sim dentro das consultas. Primeira pista de que a mudança certa é a que ataca o gargalo, e não a mais simples.

### Passo 2: índices (02)

- **Hipótese:** as consultas leem tabelas inteiras; com índices que casam com cada filtro e ordenação, leem só o necessário [3][4].
- **Resultado:** 2.15 → 9.43 req/s (~4,4x). A CPU da API subiu de ~8% para ~24%: ela passou a ter trabalho.
- **O que aprendi:** o maior ganho veio do desperdício mais básico. E cada índice tem um porquê: `lower(email)` para busca sem diferença de maiúsculas, ordem igual ao `ORDER BY` para não ordenar, trigramas para busca "contém".

### Passo 3: fim do N+1 (03) — sem ganho

- **Hipótese:** 22 idas ao banco viram 3; a rota fica mais rápida e sobra banco para o resto.
- **Resultado:** a rota alterada ficou ~2,4x mais rápida, mas a vazão geral ficou igual (8.35 → 8.60) e as rotas rápidas pioraram.
- **O que eu pensei:** o banco continuava a ~97%. Ele estava ocupado com outra coisa (as agregações dos relatórios), e não com as idas. Sem o N+1, mais relatórios disputaram a CPU ao mesmo tempo.
- **O que aprendi:** otimizar o que não é gargalo só muda a espera de lugar. Mantive a mudança porque o código ficou correto e mais simples.

### Passo 4: view materializada do ranking (04)

- **Hipótese:** o ranking de produtos soma 1,5 milhão de itens a cada chamada; se o resultado for pré-calculado, a rota só lê.
- **Resultado:** 8.27 → 22.06 req/s (~2,7x). Banco de ~95% para 65%; API de ~24% para ~47%, encostando no limite de 0.5 CPU.
- **O que aprendi:** pela primeira vez o gargalo mudou de lugar, do banco para a API. E pré-calcular tem preço: a view é uma foto e só se atualiza com `REFRESH` [12].

### Passo 5: soma por dia no SQL (05) — sem ganho

- **O que eu via:** o perfil de CPU da API mostrou que `vendas-por-dia` dominava o trabalho dela: a API recebia ~57 mil linhas e somava em JavaScript.
- **Hipótese:** somando no banco, a API fica livre.
- **Resultado:** a CPU da API caiu de ~47% para ~12%, mas o banco foi a ~99% e a vazão não mudou (26.59 → 27.07).
- **O que aprendi:** o mesmo padrão do passo 3, no sentido contrário. Tirar trabalho de um lado e mandar para o outro não diminui o trabalho total. O resultado apontou o próximo alvo: a soma em si.

### Passo 6: view materializada das vendas por dia (06)

- **Hipótese:** pré-calculando a soma por dia, nem a API nem o banco precisam refazê-la.
- **Resultado:** 29.29 → 53.61 req/s (~1,8x). O banco seguiu no limite, agora por causa de outra rota.

### Passo 7: índice cobrindo em `/pedidos` (07)

- **O que eu via:** `/pedidos` pagina com `OFFSET`. Nas páginas fundas, o banco visitava a tabela para cada linha percorrida: na página 1000 de `pago`, lia 20101 páginas de 8 kB.
- **Hipótese:** com todas as colunas da consulta no índice (`INCLUDE`), a página sai do índice sem visitar a tabela (*Index Only Scan*) [5].
- **Resultado:** 51.34 → 81.60 req/s (~1,6x); no diagnóstico, a mesma página passou a ler 102 páginas, com `Heap Fetches: 0`.
- **O que aprendi:** foi a primeira mudança com controle antes e depois (A-B-A), e os dois controles ficaram próximos, o que dá confiança de que o ganho é da mudança e não da máquina.

### Passo 8: contagem por trigger (08)

- **O que eu via:** a outra metade de `/pedidos` é o total de pedidos do status, um `count(*)` de todos os pedidos do status a cada página.
- **O que eu pensei:** por causa do MVCC, o PostgreSQL precisa percorrer as linhas para contar [13]. Uma view materializada deixaria o total atrasado, e ele aparece ao lado de uma lista em tempo real. Então: uma tabela-resumo com 4 linhas, mantida por trigger a cada insert, delete ou update [14][15].
- **Resultado:** 90.51 → 265.71 req/s (~2,9x). O banco saiu do limite (96.9% → 57.8%) e a API encostou nos 0.5 CPU dela (50.3%).
- **O que aprendi:** escolher a ferramenta pelo tipo de dado: relatório aceita atraso (view); contador ao lado de dado vivo não aceita (trigger).

### Passo 9: log sem o corpo da resposta (09) — sem ganho

- **O que eu via:** com a API no limite, o perfil mostrou o log gastando de 8% a 13% da CPU dela, porque gravava o corpo de cada resposta.
- **Resultado:** o log ficou ~10x menor, mas a vazão ficou dentro do ruído.
- **O que aprendi:** uma lição de método. Sem o controle repetido, a mesma mudança teria parecido piorar, melhorar 47.7% ou piorar 8.7%, dependendo de qual par de séries eu comparasse. O ruído do ambiente (~8% entre controles) é maior que o efeito de mudanças pequenas.

### Passo 10: mais CPU para a API (10) — revertida

- **Pergunta:** se a API é o gargalo, quanto rende comprar capacidade?
- **Resultado:** 246.53 → 473.73 req/s (~1,8x) com 0.5 CPU a mais (+33% no total). O banco voltou ao limite (~101%).
- **Decisão:** voltei aos limites originais, para mostrar que todo o ganho veio do código e do banco. Mas a mudança respondeu uma pergunta importante: depois de tirar o desperdício, comprar recurso rende mais que o custo. Antes, teria só acelerado o desperdício.

### Passo 11: remover um índice sem uso (11) — sem ganho de vazão

- **O que eu via:** o índice criado na 02 para a consulta antiga de vendas por dia não era usado por nenhuma rota desde a 06.
- **Antes de remover:** analisei as 24 consultas com e sem o índice; os planos ficaram iguais.
- **Resultado:** vazão igual (296.32 → 296.84; controle depois 293.69) e 3552 kB a menos em disco.
- **O que aprendi:** um índice que ajudou numa etapa pode ficar inútil na seguinte, e cada índice custa espaço e escrita.

### Depois das mudanças: o que a carga não mostrava

A carga do desafio só lê. Para saber o custo real das views e do trigger, testei à parte:

- **Simulação de escritas** numa cópia do banco: as views ficaram com o valor antigo até o `REFRESH`; o trigger manteve o total certo, deixando as escritas ~20% mais lentas.
- **Carga mista** (API sob carga + escritas + `REFRESH`): o `REFRESH` normal travou o ranking por até ~7,5 s; o `REFRESH CONCURRENTLY` não travou, mas demorou mais.
- **Conclusão:** em produção, as views precisariam de refresh `CONCURRENTLY` agendado (e de um índice único no ranking). Trocar tudo por trigger traria a lógica dos relatórios para dentro de cada escrita, com mais risco de erro.

## O mapa do gargalo

| Depois de | Gargalo | Sinal |
|---|---|---|
| linha de base, 01, 02, 03 | banco | CPU do banco ~96–98% |
| 04 | API | banco 65%, API ~47% (teto 50%) |
| 05, 06, 07 | banco | CPU do banco ~98–100% |
| 08, 09, 11 (final) | API | banco ~58%, API ~50% (teto) |
| 10 (revertida) | banco | banco ~101% com a API em 1.0 CPU |

## O mercado e o que entreguei

| Como o mercado costuma resolver | O que custa | O que fiz no lugar |
|---|---|---|
| Réplica de leitura gerenciada (ex.: Amazon RDS) [18] | outra instância, cobrada como a primeira; dado com atraso | índices e pré-cálculo no banco que já existia |
| Serviço de cache (ex.: ElastiCache) [19] | um serviço a mais; dado antigo e expiração para gerenciar | views materializadas e tabela-resumo, que ficam no próprio banco |
| *Pooler* externo (ex.: PgBouncer) [20] | mais um serviço para operar | o *pool* da própria biblioteca `pg` [10] |
| Mais CPU e memória | custo direto | medido (10), mas revertido |

Essas soluções existem porque, em escala, a capacidade de uma máquina acaba. O ponto deste trabalho é a ordem: primeiro tirar o desperdício, depois comprar o que faltar.

## Glossário dos conceitos aprendidos

- **Vazão (req/s):** quantas requisições a aplicação termina por segundo.
- **Mediana, p95 e p99:** ordenando todos os tempos de resposta, o p95 é o tempo abaixo do qual ficam 95% deles. A mediana mostra o caso típico e esconde os lentos; o p99 mostra a cauda que alguns usuários sentem.
- **Gargalo:** a parte que está no limite e segura o resto. Melhorar outra parte não aumenta a vazão.
- **Limite de CPU no container:** "0.5 CPU" significa metade de um núcleo; por isso a API "no limite" aparece com ~50%.
- **`EXPLAIN ANALYZE`:** executa a consulta e mostra o caminho que o banco escolheu e o tempo de cada etapa [1].
- **Seq Scan:** leitura da tabela inteira.
- **Index Scan:** o banco usa o índice para achar as linhas e depois visita a tabela para buscar as colunas.
- **Index Only Scan:** o índice tem todas as colunas pedidas e a tabela nem é visitada [5]; depende do *visibility map* estar em dia (o autovacuum cuida disso).
- **Índice B-tree:** o índice padrão, uma árvore ordenada que serve para `=`, `<`, `>` e ordenação.
- **Índice de expressão:** indexa o resultado de uma expressão, como `lower(email)` [3].
- **Índice composto e ordem do `ORDER BY`:** se o índice está na ordem pedida, as primeiras linhas saem prontas, sem ordenar tudo [4].
- **Índice cobrindo (`INCLUDE`):** guarda colunas extras no índice, sem usá-las na busca, para permitir o Index Only Scan.
- **Trigramas (`pg_trgm`):** quebram o texto em pedaços de 3 letras, o que permite indexar buscas "contém". O GIN acha o termo exato mais rápido; o GiST permite busca por semelhança (tolerante a erro) [6].
- **N+1:** uma consulta para a lista e mais uma para cada item dela [8][9].
- **Pool de conexões:** conexões abertas uma vez e reaproveitadas [10].
- **MVCC:** o PostgreSQL guarda versões das linhas para leituras e escritas não se bloquearem; por isso `count(*)` precisa conferir linha a linha [13].
- **View materializada:** o resultado de uma consulta guardado como tabela; só muda com `REFRESH` [12]. O `REFRESH CONCURRENTLY` não bloqueia leituras, mas exige um índice único.
- **Tabela-resumo com trigger:** uma tabela pequena atualizada pelo próprio banco a cada escrita; a leitura fica barata e o custo vai para a escrita [14][15].
- **Paginação por `OFFSET` × por cursor:** com `OFFSET`, o banco percorre e descarta as linhas anteriores; paginar pelo último valor visto evita isso [7].
- **Controle A-B-A:** medir o código antigo, o novo e o antigo de novo, na mesma sessão. Se os dois controles batem, a diferença é da mudança, e não da máquina.
- **Ruído do ambiente:** a variação entre medições iguais (~8% aqui). Efeitos menores que ele não podem ser afirmados.
- **Perfil de CPU (`node --cpu-prof`):** grava em quais funções o processo gasta CPU [2].
- **Réplica de leitura:** cópia do banco que recebe as mudanças com atraso e atende leituras [16][17][18].
- **Cache:** guarda respostas prontas para não ir ao banco; o risco é devolver dado antigo [19].
