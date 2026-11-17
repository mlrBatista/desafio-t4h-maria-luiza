-- REFRESH normal das duas views, disparado DURANTE o pgbench de leitura (passo 4), só em loja_teste.
\set ON_ERROR_STOP on
\timing on
DO $$ BEGIN IF current_database() <> 'loja_teste' THEN RAISE EXCEPTION 'este script só roda em loja_teste, e não em %', current_database(); END IF; END $$;
\echo ##### REFRESH MATERIALIZED VIEW vendas_por_dia_mv
REFRESH MATERIALIZED VIEW vendas_por_dia_mv;
\echo ##### REFRESH MATERIALIZED VIEW top_produtos_mv
REFRESH MATERIALIZED VIEW top_produtos_mv;
