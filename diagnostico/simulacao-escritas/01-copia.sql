-- Cópia do banco da aplicação: CREATE DATABASE loja_teste TEMPLATE loja. Rodado conectado ao banco postgres, com a API parada.
-- A partir daqui, todos os scripts da simulação rodam em loja_teste; o banco loja não é alterado.
\set ON_ERROR_STOP on
\timing on
\echo ##### tamanho do banco loja antes da copia
SELECT pg_database_size('loja') AS bytes_loja, pg_size_pretty(pg_database_size('loja')) AS tamanho_loja;
\echo ##### conexoes abertas em loja (esperado 0 para o TEMPLATE funcionar)
SELECT count(*) AS conexoes_em_loja FROM pg_stat_activity WHERE datname = 'loja';
\echo ##### CREATE DATABASE loja_teste TEMPLATE loja
CREATE DATABASE loja_teste TEMPLATE loja;
\echo ##### tamanho depois da copia
SELECT datname, pg_database_size(datname) AS bytes, pg_size_pretty(pg_database_size(datname)) AS tamanho FROM pg_database WHERE datname IN ('loja', 'loja_teste') ORDER BY 1;
