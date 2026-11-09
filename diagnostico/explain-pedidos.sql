-- Diagnóstico de GET /pedidos?status=&pagina= (só leitura). Gerado por um script, não por echo.
-- Contagem e páginas 500 (OFFSET 9980) e 1000 (OFFSET 19980) para os 4 status, 3 execuções cada.
-- Depois, o índice cobrindo é testado dentro de BEGIN/ROLLBACK: nada fica no banco.
\set ON_ERROR_STOP on
\echo ##### ESTADO INICIAL: índices de pedidos
\di *pedidos*
\echo ##### ESTADO INICIAL: pg_indexes de pedidos
SELECT indexname FROM pg_indexes WHERE tablename = 'pedidos' ORDER BY 1;
\echo ##### IDX_SCAN lido ANTES dos EXPLAIN (EXPLAIN ANALYZE também conta como uso de índice)
SELECT indexrelname AS indice, idx_scan, idx_tup_read, idx_tup_fetch FROM pg_stat_user_indexes WHERE indexrelname = 'idx_pedidos_criado_em_dia';
SELECT stats_reset FROM pg_stat_database WHERE datname = 'loja';
\echo ##### [ATUAL] contagem | status=pago | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pago';
\echo ##### [ATUAL] contagem | status=pago | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pago';
\echo ##### [ATUAL] contagem | status=pago | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pago';
\echo ##### [ATUAL] pagina 500 | status=pago | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=pago | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=pago | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 1000 | status=pago | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=pago | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=pago | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] contagem | status=entregue | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'entregue';
\echo ##### [ATUAL] contagem | status=entregue | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'entregue';
\echo ##### [ATUAL] contagem | status=entregue | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'entregue';
\echo ##### [ATUAL] pagina 500 | status=entregue | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=entregue | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=entregue | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 1000 | status=entregue | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=entregue | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=entregue | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] contagem | status=cancelado | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'cancelado';
\echo ##### [ATUAL] contagem | status=cancelado | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'cancelado';
\echo ##### [ATUAL] contagem | status=cancelado | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'cancelado';
\echo ##### [ATUAL] pagina 500 | status=cancelado | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=cancelado | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=cancelado | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 1000 | status=cancelado | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=cancelado | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=cancelado | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] contagem | status=pendente | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pendente';
\echo ##### [ATUAL] contagem | status=pendente | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pendente';
\echo ##### [ATUAL] contagem | status=pendente | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pendente';
\echo ##### [ATUAL] pagina 500 | status=pendente | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=pendente | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 500 | status=pendente | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [ATUAL] pagina 1000 | status=pendente | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=pendente | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [ATUAL] pagina 1000 | status=pendente | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### INDICE COBRINDO (dentro de BEGIN; ... ROLLBACK;)
BEGIN;
CREATE INDEX idx_tmp_cobrindo ON pedidos (status, criado_em DESC, id DESC) INCLUDE (cliente_id);
SELECT 'tamanho do índice temporário' AS item, pg_size_pretty(pg_relation_size('idx_tmp_cobrindo')) AS valor;
SELECT 'tamanho do idx_pedidos_status_criado_em atual' AS item, pg_size_pretty(pg_relation_size('idx_pedidos_status_criado_em')) AS valor;
\echo ##### [COBRINDO] pagina 500 | status=pago | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=pago | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=pago | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 1000 | status=pago | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=pago | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=pago | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 500 | status=entregue | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=entregue | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=entregue | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 1000 | status=entregue | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=entregue | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=entregue | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 500 | status=cancelado | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=cancelado | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=cancelado | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 1000 | status=cancelado | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=cancelado | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=cancelado | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 500 | status=pendente | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=pendente | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 500 | status=pendente | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COBRINDO] pagina 1000 | status=pendente | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=pendente | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COBRINDO] pagina 1000 | status=pendente | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
ROLLBACK;
\echo ##### ESTADO FINAL: índices de pedidos - nenhum novo e nenhum apagado
\di *pedidos*
SELECT indexname FROM pg_indexes WHERE tablename = 'pedidos' ORDER BY 1;
\echo ##### ESTADO FINAL: sobrou algum idx_tmp_*? (esperado: 0 linhas)
SELECT indexname FROM pg_indexes WHERE indexname LIKE 'idx_tmp%';
