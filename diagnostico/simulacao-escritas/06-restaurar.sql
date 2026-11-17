-- Passo 6: apaga a cópia loja_teste. Rodado conectado ao banco postgres, com psql -f. O banco loja não é tocado.
\set ON_ERROR_STOP on
\timing on
\echo ##### sessoes abertas em loja_teste (esperado 0)
SELECT count(*) AS sessoes_em_loja_teste FROM pg_stat_activity WHERE datname = 'loja_teste';
\echo ##### DROP DATABASE loja_teste
DROP DATABASE loja_teste;
\echo ##### bancos existentes depois (esperado: so loja)
SELECT datname FROM pg_database WHERE datname IN ('loja', 'loja_teste') ORDER BY 1;
