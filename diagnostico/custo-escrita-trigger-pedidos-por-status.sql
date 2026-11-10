-- Ordem de grandeza do custo do trigger nas escritas (mudança 08).
-- DIAGNÓSTICO ISOLADO: não vem do medir.sh e não substitui nenhuma medição de carga. A carga do desafio só lê.
-- Mede, com \timing, o INSERT de 10 mil pedidos com os triggers de pedidos_por_status ligados e desligados
-- (ALTER TABLE pedidos DISABLE TRIGGER USER, dentro da transação). Cada execução fica em BEGIN; ... ROLLBACK;.
-- As execuções alternam COM e SEM trigger, 3 de cada, para o efeito de cache não cair só de um lado.
\set ON_ERROR_STOP on
SELECT max(id) AS maxid FROM pedidos \gset

\echo ##### COM trigger, execucao 1
BEGIN;
\timing on
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) SELECT :maxid + g, 1 + g % 1000, (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[1 + g % 4], now(), '' FROM generate_series(1, 10000) g;
\timing off
ROLLBACK;
\echo ##### SEM trigger, execucao 1
BEGIN;
ALTER TABLE pedidos DISABLE TRIGGER USER;
\timing on
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) SELECT :maxid + g, 1 + g % 1000, (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[1 + g % 4], now(), '' FROM generate_series(1, 10000) g;
\timing off
ROLLBACK;
\echo ##### COM trigger, execucao 2
BEGIN;
\timing on
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) SELECT :maxid + g, 1 + g % 1000, (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[1 + g % 4], now(), '' FROM generate_series(1, 10000) g;
\timing off
ROLLBACK;
\echo ##### SEM trigger, execucao 2
BEGIN;
ALTER TABLE pedidos DISABLE TRIGGER USER;
\timing on
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) SELECT :maxid + g, 1 + g % 1000, (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[1 + g % 4], now(), '' FROM generate_series(1, 10000) g;
\timing off
ROLLBACK;
\echo ##### COM trigger, execucao 3
BEGIN;
\timing on
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) SELECT :maxid + g, 1 + g % 1000, (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[1 + g % 4], now(), '' FROM generate_series(1, 10000) g;
\timing off
ROLLBACK;
\echo ##### SEM trigger, execucao 3
BEGIN;
ALTER TABLE pedidos DISABLE TRIGGER USER;
\timing on
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) SELECT :maxid + g, 1 + g % 1000, (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[1 + g % 4], now(), '' FROM generate_series(1, 10000) g;
\timing off
ROLLBACK;

\echo ##### ESTADO FINAL: triggers ligados e totais intactos
SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;
SELECT string_agg(status || '=' || total, ', ' ORDER BY status) AS resumo FROM pedidos_por_status;
SELECT count(*) AS pedidos FROM pedidos;
