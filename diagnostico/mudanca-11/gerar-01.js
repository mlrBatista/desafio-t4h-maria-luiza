// Gera 01-planos.sql: EXPLAIN (ANALYZE, BUFFERS) das consultas de TODAS as rotas (as de api/src/rotas.js), 3 vezes cada,
// primeiro COM o idx_pedidos_criado_em_dia e depois SEM ele (DROP INDEX dentro de BEGIN; ... ROLLBACK;).
const fs = require('fs');
const Q = [];
const add = (nome, sql) => Q.push([nome, sql]);
add('GET /clientes?email=', "SELECT * FROM clientes WHERE lower(email) = lower('cliente100@exemplo.com') ORDER BY id");
add('GET /clientes/:id', 'SELECT * FROM clientes WHERE id = 100');
add('GET /clientes/:id/pedidos (pedidos do cliente)', 'SELECT * FROM pedidos WHERE cliente_id = 90142 ORDER BY criado_em DESC, id DESC');
add('GET /clientes/:id/pedidos (itens dos pedidos)', 'SELECT i.pedido_id, i.produto_id, i.quantidade, i.preco_unitario_centavos, pr.nome AS produto_nome FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = ANY(ARRAY[89971, 189971, 289971, 389971, 489971]::int[]) ORDER BY i.pedido_id, i.id');
for (const s of ['pago', 'entregue', 'cancelado', 'pendente']) {
  add(`GET /pedidos (total, ${s})`, `SELECT COALESCE((SELECT total FROM pedidos_por_status WHERE status = '${s}'), 0) AS total`);
  for (const [pg, off] of [[1, 0], [500, 9980], [1000, 19980]]) add(`GET /pedidos (página ${pg}, ${s})`, `SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = '${s}' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET ${off}`);
}
add('GET /produtos/busca', "SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20");
add('GET /relatorios/vendas-por-dia (31 dias)', "SELECT to_char(dia, 'YYYY-MM-DD') AS dia, pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia BETWEEN '2025-01-01' AND '2025-01-31' ORDER BY dia");
add('GET /relatorios/top-produtos (limite 10)', 'SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 10');
add('GET /relatorios/top-produtos (limite 50)', 'SELECT id, nome, categoria, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 50');
const L = [];
const p = (s) => L.push(s);
p('-- Mudança 11, passo 1: alguma consulta das rotas usa o idx_pedidos_criado_em_dia? Gerado por gerar-01.js; rodado com psql -f.');
p('-- As consultas são as de api/src/rotas.js (commit atual), com parâmetros de exemplo. 3 EXPLAIN de cada consulta COM o índice e 3 SEM ele.');
p('-- O DROP INDEX roda dentro de BEGIN; ... ROLLBACK;: o índice continua existindo no fim (conferido com \\di).');
p('\\set ON_ERROR_STOP on');
p('\\echo ##### INDICES de pedidos antes');
p('\\di *pedidos*');
p('\\echo ##### COM o indice');
for (const [n, sql] of Q) for (let i = 1; i <= 3; i++) { p(`\\echo ##### [COM] ${n} | execucao ${i}`); p(`EXPLAIN (ANALYZE, BUFFERS) ${sql};`); }
p('\\echo ##### SEM o indice (DROP INDEX dentro de BEGIN)');
p('BEGIN;');
p('DROP INDEX idx_pedidos_criado_em_dia;');
p("SELECT count(*) AS indice_existe_dentro_da_transacao FROM pg_indexes WHERE indexname = 'idx_pedidos_criado_em_dia';");
for (const [n, sql] of Q) for (let i = 1; i <= 3; i++) { p(`\\echo ##### [SEM] ${n} | execucao ${i}`); p(`EXPLAIN (ANALYZE, BUFFERS) ${sql};`); }
p('ROLLBACK;');
p('\\echo ##### INDICES de pedidos depois do ROLLBACK (o idx_pedidos_criado_em_dia precisa existir)');
p('\\di *pedidos*');
p("SELECT count(*) AS indice_existe_depois FROM pg_indexes WHERE indexname = 'idx_pedidos_criado_em_dia';");
p("SELECT indexrelname AS indice, idx_scan FROM pg_stat_user_indexes WHERE relname = 'pedidos' ORDER BY 1;");
fs.writeFileSync('diagnostico/mudanca-11/01-planos.sql', L.join('\n') + '\n');
console.log('consultas:', Q.length, '| EXPLAIN:', Q.length * 6);
