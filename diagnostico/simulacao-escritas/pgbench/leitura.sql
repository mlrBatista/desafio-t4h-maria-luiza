-- Leitura das duas views, como as rotas fazem (vendas-por-dia com 31 dias e top-produtos com limite 10).
\set d random(0, 700)
SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN DATE '2024-01-01' + :d AND DATE '2024-01-01' + :d + 30 ORDER BY dia;
SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10;
