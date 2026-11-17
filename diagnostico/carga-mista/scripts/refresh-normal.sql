-- REFRESH normal das duas views, disparado no meio dos 60 s medidos (série C). Rodado com psql -f.
\set ON_ERROR_STOP on
\timing on
\echo ##### REFRESH MATERIALIZED VIEW top_produtos_mv
REFRESH MATERIALIZED VIEW top_produtos_mv;
\echo ##### REFRESH MATERIALIZED VIEW vendas_por_dia_mv
REFRESH MATERIALIZED VIEW vendas_por_dia_mv;
