-- Estado do banco da aplicação (loja) para comparar ANTES e DEPOIS da simulação de escritas. Só leitura.
-- Rodado com psql -f. As linhas "Time:" mudam entre as duas execuções; o resto precisa ser idêntico.
\set ON_ERROR_STOP on
\timing on
\echo ##### banco
SELECT current_database();
\echo ##### tabela-resumo pedidos_por_status
SELECT status, total FROM pedidos_por_status ORDER BY status;
\echo ##### count(*) de pedidos por status
SELECT status, count(*) AS n FROM pedidos GROUP BY status ORDER BY status;
\echo ##### linhas das tabelas
SELECT (SELECT count(*) FROM pedidos) AS pedidos, (SELECT count(*) FROM itens_pedido) AS itens_pedido, (SELECT count(*) FROM clientes) AS clientes, (SELECT count(*) FROM produtos) AS produtos;
\echo ##### top 3 de top_produtos_mv
SELECT id, nome, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 3;
\echo ##### 3 ultimas linhas de vendas_por_dia_mv
SELECT dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv ORDER BY dia DESC LIMIT 3;
\echo ##### linhas das views
SELECT (SELECT count(*) FROM top_produtos_mv) AS top_produtos_mv, (SELECT count(*) FROM vendas_por_dia_mv) AS vendas_por_dia_mv;
\echo ##### triggers de pedidos e estado (tgenabled: O = ligado, D = desligado)
SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;
\echo ##### descricao da tabela pedidos (inclui a secao Triggers)
\d pedidos
\echo ##### indices do schema public
SELECT indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY 1;
\echo ##### impressoes digitais (md5) do conteudo
SELECT md5(string_agg(id::text || ':' || cliente_id::text || ':' || status || ':' || criado_em::text, ',' ORDER BY id)) AS md5_pedidos FROM pedidos;
SELECT md5(string_agg(id::text || ':' || pedido_id::text || ':' || produto_id::text || ':' || quantidade::text || ':' || preco_unitario_centavos::text, ',' ORDER BY id)) AS md5_itens_pedido FROM itens_pedido;
SELECT md5(string_agg(status || ':' || total::text, ',' ORDER BY status)) AS md5_pedidos_por_status FROM pedidos_por_status;
SELECT md5(string_agg(id::text || ':' || unidades::text || ':' || receita_centavos::text, ',' ORDER BY id)) AS md5_top_produtos_mv FROM top_produtos_mv;
SELECT md5(string_agg(dia::text || ':' || pedidos::text || ':' || itens::text || ':' || receita_centavos::text, ',' ORDER BY dia)) AS md5_vendas_por_dia_mv FROM vendas_por_dia_mv;
