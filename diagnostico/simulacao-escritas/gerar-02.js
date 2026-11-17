// Gera 02-views-desatualizadas.sql (as três comparações usam o mesmo texto; só muda o rótulo).
const fs = require('fs');
const DIA = '2025-12-31';
const guarda = "DO $$ BEGIN IF current_database() <> 'loja_teste' THEN RAISE EXCEPTION 'este script só roda em loja_teste, e não em %', current_database(); END IF; END $$;";
const top = `SELECT m.pos, m.id AS id_view, m.unidades AS un_view, m.receita_centavos AS rec_view, l.id AS id_vivo, l.unidades AS un_vivo, l.receita_centavos AS rec_vivo, (m.id = l.id AND m.unidades = l.unidades AND m.receita_centavos = l.receita_centavos) AS bate
  FROM (SELECT row_number() OVER (ORDER BY receita_centavos DESC, id) AS pos, id, unidades, receita_centavos FROM top_produtos_mv ORDER BY receita_centavos DESC, id LIMIT 3) m
  FULL JOIN (SELECT row_number() OVER (ORDER BY receita_centavos DESC, id) AS pos, id, unidades, receita_centavos
               FROM (SELECT pr.id, sum(i.quantidade) AS unidades, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
                       FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id JOIN produtos pr ON pr.id = i.produto_id
                      WHERE p.status <> 'cancelado' GROUP BY pr.id) x
              ORDER BY receita_centavos DESC, id LIMIT 3) l ON l.pos = m.pos
 ORDER BY 1;`;
const dia = `SELECT DATE '${DIA}' AS dia, m.pedidos AS ped_view, l.pedidos AS ped_vivo, m.itens AS itens_view, l.itens AS itens_vivo, m.receita_centavos AS rec_view, l.receita_centavos AS rec_vivo, (m.pedidos = l.pedidos AND m.itens = l.itens AND m.receita_centavos = l.receita_centavos) AS bate
  FROM (SELECT pedidos, itens, receita_centavos FROM vendas_por_dia_mv WHERE dia = DATE '${DIA}') m
  CROSS JOIN (SELECT count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos
                FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id
               WHERE p.status <> 'cancelado' AND p.criado_em::date = DATE '${DIA}') l;`;
const resumo = `SELECT coalesce(s.status, c.status) AS status, s.total AS resumo, c.n AS contagem, (coalesce(s.total, 0) = coalesce(c.n, 0)) AS bate
  FROM pedidos_por_status s FULL JOIN (SELECT status, count(*) AS n FROM pedidos GROUP BY status) c ON c.status = s.status ORDER BY 1;`;
const bloco = (rot) => [`\\echo ##### ${rot}: top 3 de top_produtos_mv x calculado ao vivo (consulta original da rota)`, top, `\\echo ##### ${rot}: vendas_por_dia_mv do dia ${DIA} x calculado ao vivo`, dia, `\\echo ##### ${rot}: pedidos_por_status x count(*) por status`, resumo].join('\n');
const L = [];
L.push('-- Passo 2: views desatualizadas e trigger em dia, SÓ em loja_teste (cópia). Gerado por gerar-02.js; rodado com psql -f.');
L.push('-- Lote fictício: 5000 pedidos \'pago\' no dia ' + DIA + ' (data de criado_em das 12:00 em diante), 3 itens cada; 1 em cada 5 pedidos tem um item de 100 unidades a R$ 1.000,00 no produto que está em 10º no ranking (simula uma venda grande concentrada num produto).');
L.push('\\set ON_ERROR_STOP on', '\\timing on', guarda, 'SELECT current_database();');
L.push("SELECT max(criado_em::date) AS ultimo_dia_com_dados FROM pedidos;");
L.push(bloco('A. ANTES da escrita'));
L.push("\\echo ##### B. escrita: INSERT do lote e COMMIT (os triggers de pedidos_por_status disparam)");
L.push("SELECT id AS produto_foco FROM top_produtos_mv ORDER BY receita_centavos DESC, id OFFSET 9 LIMIT 1 \\gset");
L.push("SELECT id AS posicao10_id, unidades, receita_centavos FROM top_produtos_mv WHERE id = :produto_foco;");
L.push('SELECT max(id) AS maxped FROM pedidos \\gset', 'SELECT max(id) AS maxitem FROM itens_pedido \\gset');
L.push(`BEGIN;
INSERT INTO pedidos (id, cliente_id, status, criado_em, observacoes)
SELECT :maxped + g, 1 + g % 100000, 'pago', TIMESTAMP '${DIA} 12:00:00' + (g % 3600) * INTERVAL '1 second', ''
  FROM generate_series(1, 5000) g;
INSERT INTO itens_pedido (id, pedido_id, produto_id, quantidade, preco_unitario_centavos)
SELECT :maxitem + (g - 1) * 3 + k, :maxped + g,
       CASE WHEN k = 1 AND g % 5 = 0 THEN :produto_foco ELSE 1 + (g * 7 + k * 13) % 20000 END,
       CASE WHEN k = 1 AND g % 5 = 0 THEN 100 ELSE 1 + (g + k) % 3 END,
       CASE WHEN k = 1 AND g % 5 = 0 THEN 100000 ELSE pr.preco_centavos END
  FROM generate_series(1, 5000) g CROSS JOIN generate_series(1, 3) k
  JOIN produtos pr ON pr.id = CASE WHEN k = 1 AND g % 5 = 0 THEN :produto_foco ELSE 1 + (g * 7 + k * 13) % 20000 END;
COMMIT;`);
L.push("SELECT (SELECT count(*) FROM pedidos WHERE id > :maxped) AS pedidos_inseridos, (SELECT count(*) FROM itens_pedido WHERE id > :maxitem) AS itens_inseridos, (SELECT count(*) FROM itens_pedido WHERE id > :maxitem AND produto_id = :produto_foco AND quantidade = 100) AS itens_no_produto_foco;");
L.push(bloco('C. DEPOIS da escrita, SEM REFRESH'));
L.push('\\echo ##### D. REFRESH MATERIALIZED VIEW das duas views (cada tempo aparece na linha Time: logo abaixo)');
L.push('\\echo ##### D1. REFRESH MATERIALIZED VIEW top_produtos_mv', 'REFRESH MATERIALIZED VIEW top_produtos_mv;');
L.push('\\echo ##### D2. REFRESH MATERIALIZED VIEW vendas_por_dia_mv', 'REFRESH MATERIALIZED VIEW vendas_por_dia_mv;');
L.push(bloco('D. DEPOIS do REFRESH'));
fs.writeFileSync('diagnostico/simulacao-escritas/02-views-desatualizadas.sql', L.join('\n') + '\n');
