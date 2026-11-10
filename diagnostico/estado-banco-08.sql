-- Estado do banco depois de aplicar a mudança 08 (down -v + up --build + autovacuum nas 4 tabelas), ANTES de qualquer medição. Só leitura.
\set ON_ERROR_STOP on
\echo ##### Tabela-resumo x count(*) por status
SELECT coalesce(s.status, c.status) AS status, s.total AS resumo, c.n AS contagem, (coalesce(s.total, 0) = coalesce(c.n, 0)) AS bate FROM pedidos_por_status s FULL JOIN (SELECT status, count(*) AS n FROM pedidos GROUP BY status) c ON c.status = s.status ORDER BY 1;
\echo ##### Tamanho da tabela-resumo (pg_total_relation_size)
SELECT pg_total_relation_size('pedidos_por_status') AS bytes, pg_size_pretty(pg_total_relation_size('pedidos_por_status')) AS tamanho;
\echo ##### Triggers de pedidos
SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;
\echo ##### [LEITURA NOVA] status=pago | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [LEITURA NOVA] status=pago | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [LEITURA NOVA] status=pago | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [LEITURA NOVA] status=entregue | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [LEITURA NOVA] status=entregue | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [LEITURA NOVA] status=entregue | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [LEITURA NOVA] status=cancelado | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [LEITURA NOVA] status=cancelado | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [LEITURA NOVA] status=cancelado | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [LEITURA NOVA] status=pendente | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [LEITURA NOVA] status=pendente | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [LEITURA NOVA] status=pendente | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
