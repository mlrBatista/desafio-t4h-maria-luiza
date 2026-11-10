-- Teste de correção dos triggers de pedidos_por_status (banco/07-pedidos-por-status.sql).
-- A carga do desafio só lê, então ela nunca dispara os triggers: este teste é a evidência de que eles estão certos.
-- Tudo dentro de BEGIN; ... ROLLBACK;: nada fica no banco. Rodar com psql -f.
\set ON_ERROR_STOP on

\set cmp 'SELECT coalesce(s.status, c.status) AS status, s.total AS resumo, c.n AS contagem, (coalesce(s.total, 0) = coalesce(c.n, 0)) AS bate FROM pedidos_por_status s FULL JOIN (SELECT status, count(*) AS n FROM pedidos GROUP BY status) c ON c.status = s.status ORDER BY 1'
\set tudo 'SELECT coalesce(bool_and(coalesce(s.total, 0) = coalesce(c.n, 0)), true) AS tudo_bate FROM pedidos_por_status s FULL JOIN (SELECT status, count(*) AS n FROM pedidos GROUP BY status) c ON c.status = s.status'

\echo ##### ESTADO ORIGINAL (antes do BEGIN)
SELECT string_agg(status || '=' || total, ', ' ORDER BY status) AS inicial FROM pedidos_por_status \gset
SELECT :'inicial' AS resumo_original;
SELECT (SELECT count(*) FROM pedidos) AS pedidos, (SELECT count(*) FROM itens_pedido) AS itens_pedido;
SELECT max(id) AS maxid FROM pedidos \gset
SELECT :maxid AS maior_id_de_pedido;
SELECT tgname AS triggers_de_pedidos FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;

BEGIN;

\echo ##### PASSO 0: antes de mexer em nada
:cmp;
:tudo;

\echo ##### PASSO 1: INSERT de 12 pedidos novos (ids acima do maior, cliente_id 1, sem itens), status variados, 2 deles com status novo 'teste_novo'
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes)
SELECT :maxid + g, 1, (ARRAY['pago', 'entregue', 'cancelado', 'pendente', 'teste_novo'])[1 + g % 5], now(), ''
  FROM generate_series(1, 12) g;
:cmp;
:tudo;

\echo ##### PASSO 2: muda o status de 4 pedidos novos e de 1 pedido existente (id 1)
SELECT status AS status_do_pedido_1_antes FROM pedidos WHERE id = 1;
UPDATE pedidos SET status = 'entregue' WHERE id > :maxid AND id <= :maxid + 4;
UPDATE pedidos SET status = CASE WHEN status = 'pago' THEN 'pendente' ELSE 'pago' END WHERE id = 1;
SELECT status AS status_do_pedido_1_depois FROM pedidos WHERE id = 1;
:cmp;
:tudo;

\echo ##### PASSO 3: UPDATEs que NÃO mudam o status (mesmo valor e outra coluna): não podem alterar o resumo
UPDATE pedidos SET status = status WHERE id IN (2, 3);
UPDATE pedidos SET criado_em = criado_em WHERE id IN (4, 5);
:cmp;
:tudo;

\echo ##### PASSO 4: DELETE de 5 pedidos novos
DELETE FROM pedidos WHERE id > :maxid AND id <= :maxid + 5;
:cmp;
:tudo;

\echo ##### PASSO 5: DELETE de um pedido existente (id 3) e dos seus itens
DELETE FROM itens_pedido WHERE pedido_id = 3;
DELETE FROM pedidos WHERE id = 3;
:cmp;
:tudo;

\echo ##### PASSO 6: um único UPDATE de várias linhas para um status novo
UPDATE pedidos SET status = 'teste_novo' WHERE id IN (7, 8, 9);
:cmp;
:tudo;

\echo ##### PASSO 7: TRUNCATE de pedidos (e de itens_pedido, que referencia pedidos)
TRUNCATE pedidos, itens_pedido;
SELECT status, total FROM pedidos_por_status ORDER BY 1;
SELECT count(*) AS linhas_em_pedidos FROM pedidos;
:tudo;

ROLLBACK;

\echo ##### DEPOIS DO ROLLBACK: tudo precisa ter voltado ao original
:cmp;
:tudo;
SELECT (string_agg(status || '=' || total, ', ' ORDER BY status) = :'inicial') AS resumo_voltou_ao_original FROM pedidos_por_status;
SELECT (SELECT count(*) FROM pedidos) AS pedidos, (SELECT count(*) FROM itens_pedido) AS itens_pedido;
SELECT tgname AS triggers_de_pedidos FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;
SELECT indexname AS indices_de_pedidos FROM pg_indexes WHERE tablename = 'pedidos' ORDER BY 1;
