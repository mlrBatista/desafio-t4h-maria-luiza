-- Escrita simulada: INSERT de um pedido e DELETE do mesmo pedido, status sorteado entre os 4.
\set id random(10000000, 2000000000)
\set s random(1, 4)
BEGIN;
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes) VALUES (:id, 1 + (:id % 100000), (ARRAY['pago', 'entregue', 'cancelado', 'pendente'])[:s], now(), '');
DELETE FROM pedidos WHERE id = :id;
COMMIT;
