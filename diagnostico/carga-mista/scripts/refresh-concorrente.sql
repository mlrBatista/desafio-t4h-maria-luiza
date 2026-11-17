-- REFRESH CONCURRENTLY só de vendas_por_dia_mv (tem índice único em dia), disparado no meio dos 60 s medidos (série D). Rodado com psql -f.
-- top_produtos_mv não tem índice único na aplicação e nenhum foi criado.
\set ON_ERROR_STOP on
\timing on
\echo ##### REFRESH MATERIALIZED VIEW CONCURRENTLY vendas_por_dia_mv
REFRESH MATERIALIZED VIEW CONCURRENTLY vendas_por_dia_mv;
