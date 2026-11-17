-- Escrita simulada (não deixa dados novos e aciona os triggers): INSERT de um pedido e DELETE do mesmo pedido, status 'pago'.
\set id random(10000000, 2000000000)
BEGIN;
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) VALUES (:id, 1 + (:id % 100000), 'pago', now(), '');
DELETE FROM pedidos WHERE id = :id;
COMMIT;
