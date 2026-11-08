-- Diagnóstico do idx_pedidos_criado_em_dia com a consulta ATUAL de vendas-por-dia (agregação no SQL, mudança 05), 31 dias: 2025-01-01 a 2025-01-31.
-- Banco ocioso. 3 execuções COM o índice, depois 3 SEM ele (cada uma em BEGIN; DROP INDEX; EXPLAIN; ROLLBACK;).
\echo ##### COM o indice
\echo --- com, execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado' GROUP BY 1 ORDER BY 1;
\echo --- com, execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado' GROUP BY 1 ORDER BY 1;
\echo --- com, execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado' GROUP BY 1 ORDER BY 1;
\echo ##### SEM o indice, execucao 1
BEGIN;
DROP INDEX idx_pedidos_criado_em_dia;
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado' GROUP BY 1 ORDER BY 1;
ROLLBACK;
\echo ##### SEM o indice, execucao 2
BEGIN;
DROP INDEX idx_pedidos_criado_em_dia;
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado' GROUP BY 1 ORDER BY 1;
ROLLBACK;
\echo ##### SEM o indice, execucao 3
BEGIN;
DROP INDEX idx_pedidos_criado_em_dia;
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado' GROUP BY 1 ORDER BY 1;
ROLLBACK;
\echo ##### Indice ao final (\di)
\di idx_pedidos_criado_em_dia
