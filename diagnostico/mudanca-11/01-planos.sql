-- Mudança 11, passo 1: alguma consulta das rotas usa o idx_pedidos_criado_em_dia? Gerado por gerar-01.js; rodado com psql -f.
-- As consultas são as de api/src/rotas.js (commit atual), com parâmetros de exemplo. 3 EXPLAIN de cada consulta COM o índice e 3 SEM ele.
-- O DROP INDEX roda dentro de BEGIN; ... ROLLBACK;: o índice continua existindo no fim (conferido com \di).
\set ON_ERROR_STOP on
\echo ##### INDICES de pedidos antes
\di *pedidos*
\echo ##### COM o indice
\echo ##### [COM] GET /clientes?email= | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo ##### [COM] GET /clientes?email= | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo ##### [COM] GET /clientes?email= | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo ##### [COM] GET /clientes/:id | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo ##### [COM] GET /clientes/:id | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo ##### [COM] GET /clientes/:id | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo ##### [COM] GET /clientes/:id/pedidos (pedidos do cliente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo ##### [COM] GET /clientes/:id/pedidos (pedidos do cliente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo ##### [COM] GET /clientes/:id/pedidos (pedidos do cliente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo ##### [COM] GET /clientes/:id/pedidos (itens dos pedidos) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id;
\echo ##### [COM] GET /clientes/:id/pedidos (itens dos pedidos) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id;
\echo ##### [COM] GET /clientes/:id/pedidos (itens dos pedidos) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id;
\echo ##### [COM] GET /pedidos (total, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [COM] GET /pedidos (página 1, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 500, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 1000, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (total, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [COM] GET /pedidos (página 1, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 500, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 1000, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (total, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [COM] GET /pedidos (página 1, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 500, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 1000, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (total, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [COM] GET /pedidos (total, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [COM] GET /pedidos (página 1, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 1, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [COM] GET /pedidos (página 500, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 500, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [COM] GET /pedidos (página 1000, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /pedidos (página 1000, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [COM] GET /produtos/busca | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo ##### [COM] GET /produtos/busca | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo ##### [COM] GET /produtos/busca | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo ##### [COM] GET /relatorios/vendas-por-dia (31 dias) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia;
\echo ##### [COM] GET /relatorios/vendas-por-dia (31 dias) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia;
\echo ##### [COM] GET /relatorios/vendas-por-dia (31 dias) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia;
\echo ##### [COM] GET /relatorios/top-produtos (limite 10) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
\echo ##### [COM] GET /relatorios/top-produtos (limite 10) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
\echo ##### [COM] GET /relatorios/top-produtos (limite 10) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
\echo ##### [COM] GET /relatorios/top-produtos (limite 50) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50;
\echo ##### [COM] GET /relatorios/top-produtos (limite 50) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50;
\echo ##### [COM] GET /relatorios/top-produtos (limite 50) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50;
\echo ##### SEM o indice (DROP INDEX dentro de BEGIN)
BEGIN;
DROP INDEX idx_pedidos_criado_em_dia;
SELECT count(*) AS indice_existe_dentro_da_transacao FROM pg_indexes WHERE indexname = 'idx_pedidos_criado_em_dia';
\echo ##### [SEM] GET /clientes?email= | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo ##### [SEM] GET /clientes?email= | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo ##### [SEM] GET /clientes?email= | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo ##### [SEM] GET /clientes/:id | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo ##### [SEM] GET /clientes/:id | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo ##### [SEM] GET /clientes/:id | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo ##### [SEM] GET /clientes/:id/pedidos (pedidos do cliente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo ##### [SEM] GET /clientes/:id/pedidos (pedidos do cliente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo ##### [SEM] GET /clientes/:id/pedidos (pedidos do cliente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo ##### [SEM] GET /clientes/:id/pedidos (itens dos pedidos) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id;
\echo ##### [SEM] GET /clientes/:id/pedidos (itens dos pedidos) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id;
\echo ##### [SEM] GET /clientes/:id/pedidos (itens dos pedidos) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id;
\echo ##### [SEM] GET /pedidos (total, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pago'), 0) AS total;
\echo ##### [SEM] GET /pedidos (página 1, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 500, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 1000, pago) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, pago) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, pago) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (total, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'entregue'), 0) AS total;
\echo ##### [SEM] GET /pedidos (página 1, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 500, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 1000, entregue) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, entregue) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, entregue) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'entregue' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (total, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'cancelado'), 0) AS total;
\echo ##### [SEM] GET /pedidos (página 1, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 500, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 1000, cancelado) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, cancelado) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, cancelado) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'cancelado' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (total, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [SEM] GET /pedidos (total, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = 'pendente'), 0) AS total;
\echo ##### [SEM] GET /pedidos (página 1, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 1, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo ##### [SEM] GET /pedidos (página 500, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 500, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 9980;
\echo ##### [SEM] GET /pedidos (página 1000, pendente) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, pendente) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /pedidos (página 1000, pendente) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = 'pendente' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;
\echo ##### [SEM] GET /produtos/busca | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo ##### [SEM] GET /produtos/busca | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo ##### [SEM] GET /produtos/busca | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo ##### [SEM] GET /relatorios/vendas-por-dia (31 dias) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia;
\echo ##### [SEM] GET /relatorios/vendas-por-dia (31 dias) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia;
\echo ##### [SEM] GET /relatorios/vendas-por-dia (31 dias) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia;
\echo ##### [SEM] GET /relatorios/top-produtos (limite 10) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
\echo ##### [SEM] GET /relatorios/top-produtos (limite 10) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
\echo ##### [SEM] GET /relatorios/top-produtos (limite 10) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
\echo ##### [SEM] GET /relatorios/top-produtos (limite 50) | execucao 1
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50;
\echo ##### [SEM] GET /relatorios/top-produtos (limite 50) | execucao 2
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50;
\echo ##### [SEM] GET /relatorios/top-produtos (limite 50) | execucao 3
EXPLAIN (ANALYZE, BUFFERS) SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50;
ROLLBACK;
\echo ##### INDICES de pedidos depois do ROLLBACK (o idx_pedidos_criado_em_dia precisa existir)
\di *pedidos*
SELECT count(*) AS indice_existe_depois FROM pg_indexes WHERE indexname = 'idx_pedidos_criado_em_dia';
SELECT indexrelname AS indice, idx_scan FROM pg_stat_user_indexes WHERE relname = 'pedidos' ORDER BY 1;
