-- Diagnóstico das consultas de cada rota, com o banco ocioso (sem carga) e a estrutura original (só PKs).
-- Parâmetros: cliente 100 (email cliente100@exemplo.com), cliente 90142 (mais pedidos: 5), status 'pago', 31 dias de 2025-01-01 a 2025-01-31.
\echo '##### GET /clientes?email='
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id;
\echo '##### GET /clientes/:id'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM clientes WHERE id = 100;
\echo '##### GET /clientes/:id/pedidos (pedidos do cliente)'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC;
\echo '##### GET /clientes/:id/pedidos (itens de um pedido, executada 1x por pedido)'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM itens_pedido WHERE pedido_id = 1000 ORDER BY id;
\echo '##### GET /pedidos (contagem)'
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) AS total FROM pedidos WHERE status = 'pago';
\echo '##### GET /pedidos (página 1)'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;
\echo '##### GET /produtos/busca?q=cadeira'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;
\echo '##### GET /relatorios/vendas-por-dia'
EXPLAIN (ANALYZE, BUFFERS) SELECT p.id AS pedido_id, p.criado_em, p.observacoes, i.quantidade, i.preco_unitario_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31' AND p.status <> 'cancelado';
\echo '##### GET /relatorios/top-produtos?limite=10'
EXPLAIN (ANALYZE, BUFFERS) SELECT pr.id, pr.nome, pr.categoria, sum(i.quantidade) AS unidades, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id JOIN produtos pr ON pr.id = i.produto_id WHERE p.status <> 'cancelado' GROUP BY pr.id, pr.nome, pr.categoria ORDER BY receita_centavos DESC, pr.id LIMIT 10;
