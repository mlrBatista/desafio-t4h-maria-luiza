-- Diagnóstico da view materializada candidata para GET /relatorios/top-produtos.
-- Tudo dentro de uma transação com ROLLBACK: o banco não muda.
\timing on
BEGIN;

\echo '##### Criação da view (tempo de CREATE)'
CREATE MATERIALIZED VIEW top_produtos_mv AS
SELECT pr.id, pr.nome, pr.categoria,
       sum(i.quantidade) AS unidades,
       sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
  FROM itens_pedido i
  JOIN pedidos p ON p.id = i.pedido_id
  JOIN produtos pr ON pr.id = i.produto_id
 WHERE p.status <> 'cancelado'
 GROUP BY pr.id, pr.nome, pr.categoria;
CREATE INDEX idx_top_produtos_mv_receita ON top_produtos_mv (receita_centavos DESC, id);
ANALYZE top_produtos_mv;

\echo '##### Linhas na view'
SELECT count(*) FROM top_produtos_mv;

\echo '##### EXPLAIN da consulta original (limite=10)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id, pr.nome, pr.categoria, sum(i.quantidade) AS unidades, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
  FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id JOIN produtos pr ON pr.id = i.produto_id
 WHERE p.status <> 'cancelado' GROUP BY pr.id, pr.nome, pr.categoria
 ORDER BY receita_centavos DESC, pr.id LIMIT 10;

\echo '##### EXPLAIN da consulta na view (limite=10)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;

\echo '##### Mesmas 50 linhas, na mesma ordem? (0 = igual)'
WITH orig AS (
  SELECT pr.id, pr.nome, pr.categoria, sum(i.quantidade) AS unidades, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
    FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id JOIN produtos pr ON pr.id = i.produto_id
   WHERE p.status <> 'cancelado' GROUP BY pr.id, pr.nome, pr.categoria
   ORDER BY receita_centavos DESC, pr.id LIMIT 50),
mv AS (SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50),
o AS (SELECT row_number() OVER () AS n, * FROM orig),
m AS (SELECT row_number() OVER () AS n, * FROM mv)
SELECT count(*) AS linhas_diferentes FROM o FULL JOIN m USING (n, id, nome, categoria, unidades, receita_centavos) WHERE o.id IS NULL OR m.id IS NULL;

\echo '##### Tamanho da view e do índice'
SELECT pg_size_pretty(pg_total_relation_size('top_produtos_mv')) AS tamanho_total;

ROLLBACK;
