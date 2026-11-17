-- Passo 3: custo do REFRESH, SÓ em loja_teste (cópia, já com o lote do passo 2). Gerado por script; rodado com psql -f.
-- 3 rodadas; em cada uma: REFRESH normal de top_produtos_mv e de vendas_por_dia_mv, depois REFRESH CONCURRENTLY das duas.
-- top_produtos_mv não tem índice único no banco da aplicação (só idx_top_produtos_mv_receita, não único). Para testar CONCURRENTLY, o índice único idx_teste_top_produtos_mv_id em (id) é criado SÓ NA CÓPIA.
\set ON_ERROR_STOP on
\timing on
DO $$ BEGIN IF current_database() <> 'loja_teste' THEN RAISE EXCEPTION 'este script só roda em loja_teste, e não em %', current_database(); END IF; END $$;
\echo ##### indice unico criado so na copia
CREATE UNIQUE INDEX idx_teste_top_produtos_mv_id ON top_produtos_mv (id);
\echo ##### rodada 1 | normal | top_produtos_mv
REFRESH MATERIALIZED VIEW top_produtos_mv;
\echo ##### rodada 1 | normal | vendas_por_dia_mv
REFRESH MATERIALIZED VIEW vendas_por_dia_mv;
\echo ##### rodada 1 | concorrente | top_produtos_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY top_produtos_mv;
\echo ##### rodada 1 | concorrente | vendas_por_dia_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY vendas_por_dia_mv;
\echo ##### rodada 2 | normal | top_produtos_mv
REFRESH MATERIALIZED VIEW top_produtos_mv;
\echo ##### rodada 2 | normal | vendas_por_dia_mv
REFRESH MATERIALIZED VIEW vendas_por_dia_mv;
\echo ##### rodada 2 | concorrente | top_produtos_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY top_produtos_mv;
\echo ##### rodada 2 | concorrente | vendas_por_dia_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY vendas_por_dia_mv;
\echo ##### rodada 3 | normal | top_produtos_mv
REFRESH MATERIALIZED VIEW top_produtos_mv;
\echo ##### rodada 3 | normal | vendas_por_dia_mv
REFRESH MATERIALIZED VIEW vendas_por_dia_mv;
\echo ##### rodada 3 | concorrente | top_produtos_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY top_produtos_mv;
\echo ##### rodada 3 | concorrente | vendas_por_dia_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY vendas_por_dia_mv;
\echo ##### tamanho das views e indices na copia
SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS tamanho_total FROM pg_class WHERE relname IN ('top_produtos_mv','vendas_por_dia_mv') ORDER BY 1;
