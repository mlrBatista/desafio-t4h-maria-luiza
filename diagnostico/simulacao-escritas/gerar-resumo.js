// Gera 07-resumo.txt a partir das saídas brutas desta pasta (nenhum número é digitado).
// Uso: node diagnostico/simulacao-escritas/gerar-resumo.js <pasta dos logs por transação do pgbench>
const fs = require('fs');
const path = require('path');
const D = 'diagnostico/simulacao-escritas';
const LOGS = process.argv[2];
const lerLinhas = (f) => fs.readFileSync(path.join(D, f), 'utf8').split('\n');
const mediana = (a) => { const s = [...a].sort((x, y) => x - y); const n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; };
const f = (x, d = 3) => Number(x).toFixed(d);

// ---- tabelas psql ----
function tabelaApos(linhas, marcador) {
  const i = linhas.findIndex((l) => l.startsWith(marcador));
  if (i < 0) return null;
  let j = i + 1;
  while (j < linhas.length && !linhas[j].includes('|')) j++;
  const cab = linhas[j].split('|').map((s) => s.trim());
  j += 2;
  const rows = [];
  while (j < linhas.length && linhas[j].trim() !== '' && !linhas[j].startsWith('(')) { const c = linhas[j].split('|').map((s) => s.trim()); rows.push(Object.fromEntries(cab.map((k, n) => [k, c[n]]))); j++; }
  return rows;
}
const tempoApos = (linhas, marcador) => { // primeira linha "Time: x ms" depois do marcador
  const i = linhas.findIndex((l) => l.startsWith(marcador));
  for (let j = i + 1; j < linhas.length; j++) { const m = linhas[j].match(/^Time: ([\d.]+) ms/); if (m) return +m[1]; if (linhas[j].startsWith('#####')) break; }
  return null;
};

const out = [];
const p = (...ss) => { if (ss.length === 0) out.push(''); ss.forEach((s) => out.push(s)); };
const commit = require('child_process').execSync('git rev-parse --short HEAD').toString().trim();
p('# RESUMO gerado por diagnostico/simulacao-escritas/gerar-resumo.js a partir das saídas brutas desta pasta. Nenhum número foi digitado.');
p(`# Data e hora da geração: ${new Date().toString()} | Commit (HEAD): ${commit}`);
p('# Cenário FICTÍCIO numa CÓPIA do banco (loja_teste, CREATE DATABASE ... TEMPLATE loja) dentro do MESMO container do banco (1 CPU e 512 MB). O banco da aplicação (loja) não foi alterado.');
p('# Lote inserido: 5000 pedidos \'pago\' em 2025-12-31 (último dia com dados), 3 itens cada, 15000 itens no total; 1 em cada 5 pedidos tem um item de 100 unidades a R$ 1.000,00 no produto que era o 10º do ranking.');
p('#   Simula um dia de vendas muito acima do normal, com uma venda grande concentrada num produto, para mudar o ranking e a receita de forma visível.');
p('# Não é medição oficial: a régua (carga/, scripts/medir.sh) não mudou e estes números não vêm de resultados/. O autovacuum pode ter rodado na cópia (e rodou: ver o fim do passo 5).');
p('# O pgbench roda em um container separado (postgres:16.4, mesma rede), então o servidor não divide a CPU com o cliente.');
p('# Tentativas descartadas e refeitas (registradas nos cabeçalhos dos arquivos): erro de tipo no estado dos triggers (passo 5) e uso da opção -d do pgbench, que liga o modo de depuração (passos 4 e 5).');

// ---- passo 1 ----
const l1 = lerLinhas('01-copia.txt');
p('', '== PASSO 1: cópia do banco ==');
p(`CREATE DATABASE loja_teste TEMPLATE loja: ${f(tempoApos(l1, '##### CREATE DATABASE'))} ms`);
const t1 = tabelaApos(l1, '##### tamanho depois da copia');
t1.forEach((r) => p(`  ${r.datname}: ${r.tamanho} (${r.bytes} bytes)`));

// ---- passo 2 ----
const l2 = lerLinhas('02-views-desatualizadas.txt');
p('', '== PASSO 2: antes / depois da escrita sem REFRESH / depois do REFRESH ==');
const rot = [['A. ANTES da escrita', 'antes'], ['C. DEPOIS da escrita, SEM REFRESH', 'sem refresh'], ['D. DEPOIS do REFRESH', 'depois do refresh']];
const lote = tabelaApos(l2, '##### B. escrita');
const loteRes = tabelaApos(l2, ' pedidos_inseridos') || null;
const li = l2.findIndex((l) => l.includes('pedidos_inseridos'));
if (li >= 0) p(`Lote inserido (confirmado com COMMIT): ${l2[li + 2].trim().replace(/\s*\|\s*/g, ' | ')}  [pedidos | itens | itens no produto em foco]`);
p(`Produto em foco (10º do ranking antes da escrita): ${(tabelaApos(l2, '##### B. escrita') || [{}])[0].posicao10_id || '?'}`);
const foco = l2.findIndex((l) => l.includes('posicao10_id'));
if (foco >= 0) p(`  posição 10 antes: ${l2[foco + 2].trim().replace(/\s*\|\s*/g, ' | ')}  [id | unidades | receita_centavos]`);
p('', 'top_produtos_mv (3 primeiros) x consulta original ao vivo:');
for (const [m, nome] of rot) {
  const t = tabelaApos(l2, `##### ${m}: top 3`);
  p(`  [${nome}]`);
  t.forEach((r) => p(`    #${r.pos}: view id ${r.id_view} (${r.un_view} un, ${r.rec_view}) | ao vivo id ${r.id_vivo} (${r.un_vivo} un, ${r.rec_vivo}) | bate: ${r.bate}`));
}
p('', 'vendas_por_dia_mv do dia 2025-12-31 x consulta original ao vivo:');
for (const [m, nome] of rot) {
  const r = tabelaApos(l2, `##### ${m}: vendas_por_dia_mv`)[0];
  p(`  [${nome}] view: ${r.ped_view} pedidos, ${r.itens_view} itens, ${r.rec_view} | ao vivo: ${r.ped_vivo} pedidos, ${r.itens_vivo} itens, ${r.rec_vivo} | bate: ${r.bate}`);
}
p('', 'pedidos_por_status (trigger) x count(*) por status:');
for (const [m, nome] of rot) {
  const t = tabelaApos(l2, `##### ${m}: pedidos_por_status`);
  p(`  [${nome}] ` + t.map((r) => `${r.status}: ${r.resumo} x ${r.contagem} (${r.bate})`).join(' | '));
}
p('', `REFRESH único (passo 2, D1 e D2): top_produtos_mv ${f(tempoApos(l2, '##### D1.'))} ms | vendas_por_dia_mv ${f(tempoApos(l2, '##### D2.'))} ms`);

// ---- passo 3 ----
const l3 = lerLinhas('03-custo-refresh.txt');
p('', '== PASSO 3: custo do REFRESH (3 execuções de cada caso; mediana) ==');
const casos = [['normal', 'top_produtos_mv'], ['normal', 'vendas_por_dia_mv'], ['concorrente', 'top_produtos_mv'], ['concorrente', 'vendas_por_dia_mv']];
for (const [modo, v] of casos) {
  const ts = [1, 2, 3].map((r) => tempoApos(l3, `##### rodada ${r} | ${modo} | ${v}`));
  p(`  REFRESH ${modo === 'concorrente' ? 'CONCURRENTLY ' : ''}${v}: ${ts.map((x) => f(x)).join(' | ')} ms | mediana ${f(mediana(ts))} ms`);
}
p('  (top_produtos_mv CONCURRENTLY usa um índice único criado SÓ na cópia; esse índice não existe no banco da aplicação.)');

// ---- passo 4 ----
p('', '== PASSO 4: o REFRESH trava as leituras? (pgbench -c 5 -T 20; REFRESH disparado ~8 s depois do início) ==');
const l4 = lerLinhas('04-pgbench-leituras.txt');
const janelas = Object.fromEntries(lerLinhas('04-janelas-refresh.txt').filter((l) => l.includes('refresh_inicio_epoch')).map((l) => { const m = l.match(/^(\S+) refresh_inicio_epoch=([\d.]+) refresh_fim_epoch=([\d.]+)/); return [m[1], [+m[2], +m[3]]]; }));
for (const caso of ['sem-refresh', 'refresh-normal', 'refresh-concorrente']) {
  const i = l4.findIndex((l) => l.startsWith(`##### caso ${caso}`));
  const j = l4.findIndex((l, n) => n > i && l.startsWith('##### fim do caso'));
  const bloco = l4.slice(i, j);
  const tps = +bloco.find((l) => l.startsWith('tps =')).match(/tps = ([\d.]+)/)[1];
  const lat = +bloco.find((l) => l.startsWith('latency average')).match(/= ([\d.]+) ms/)[1];
  const n = +bloco.find((l) => l.startsWith('number of transactions actually')).match(/: (\d+)/)[1];
  const prog = bloco.filter((l) => l.startsWith('progress:')).map((l) => { const m = l.match(/progress: ([\d.]+) s, ([\d.]+) tps, lat ([\d.]+) ms/); return { t: +m[1], tps: +m[2], lat: +m[3] }; });
  const zeros = prog.filter((x) => x.tps === 0).map((x) => x.t);
  const minimo = Math.min(...prog.map((x) => x.tps));
  const arq = fs.readdirSync(LOGS).find((a) => a.startsWith(`leitura-${caso}.`));
  const tx = fs.readFileSync(path.join(LOGS, arq), 'utf8').trim().split('\n').map((l) => l.split(' ')).map((c) => ({ lat: +c[2] / 1000, ep: +c[4] + (+c[5]) / 1e6 }));
  const lats = tx.map((x) => x.lat).sort((a, b) => a - b);
  const pct = (q) => lats[Math.min(lats.length - 1, Math.floor(q * lats.length))];
  p(`  [${caso}] transações: ${n} | vazão: ${f(tps, 1)} tps | latência média: ${f(lat, 3)} ms | latência máxima: ${f(lats[lats.length - 1], 3)} ms | p99: ${f(pct(0.99), 3)} ms | segundos com 0.0 tps: ${zeros.length ? zeros.join(', ') : 'nenhum'} | menor tps em 1 s: ${f(minimo, 1)}`);
  if (janelas[caso]) {
    const [a, b] = janelas[caso];
    const dentro = tx.filter((x) => x.ep >= a && x.ep <= b + 1);
    const esperaram = tx.filter((x) => x.lat >= 1000);
    p(`      janela do REFRESH: ${f(b - a, 3)} s | transações concluídas dentro dela (+1 s): ${dentro.length} | maior latência dessas: ${dentro.length ? f(Math.max(...dentro.map((x) => x.lat)), 3) : '-'} ms | transações com latência ≥ 1000 ms: ${esperaram.length}`);
    const r4 = lerLinhas(`04-refresh-${caso}.txt`);
    const tempos = r4.filter((l) => /^Time: [\d.]+ ms/.test(l)).map((l) => +l.match(/Time: ([\d.]+) ms/)[1]).filter((x) => x > 100);
    p(`      duração de cada REFRESH nesse cenário (vendas_por_dia_mv, top_produtos_mv): ${tempos.map((x) => f(x)).join(' ms | ')} ms`);
  }
}

// ---- passo 5 ----
p('', '== PASSO 5: triggers sob escritas simultâneas (pgbench -n -T 30; 3 execuções por combinação) ==');
const l5 = lerLinhas('05-pgbench-triggers.txt');
const exec = [];
for (let i = 0; i < l5.length; i++) {
  const m = l5[i].match(/^##### rodada (\d) \| trigger=(\w+) \| clientes=(\d+) \| status=(\w+)/);
  if (!m) continue;
  let tps = null, lat = null, n = null, falhas = null;
  for (let j = i + 1; j < l5.length && !l5[j].startsWith('#####'); j++) {
    let x;
    if ((x = l5[j].match(/^tps = ([\d.]+)/))) tps = +x[1];
    if ((x = l5[j].match(/^latency average = ([\d.]+) ms/))) lat = +x[1];
    if ((x = l5[j].match(/^number of transactions actually processed: (\d+)/))) n = +x[1];
    if ((x = l5[j].match(/^number of failed transactions: (\d+)/))) falhas = +x[1];
  }
  exec.push({ rodada: +m[1], trig: m[2], cli: +m[3], st: m[4], tps, lat, n, falhas });
}
p(`  execuções lidas: ${exec.length} (esperado 24) | execuções com transações falhas: ${exec.filter((e) => e.falhas > 0).length}`);
p('  combinação                                  tps (3 execuções)                  mediana tps | latência média ms (3)              mediana');
const med = {};
for (const cli of [1, 10]) for (const st of ['fixo', 'sorteado']) for (const trig of ['com', 'sem']) {
  const e = exec.filter((x) => x.cli === cli && x.st === st && x.trig === trig).sort((a, b) => a.rodada - b.rodada);
  const k = `${trig}|${cli}|${st}`;
  med[k] = { tps: mediana(e.map((x) => x.tps)), lat: mediana(e.map((x) => x.lat)) };
  p(`  trigger ${trig}, ${String(cli).padStart(2)} cliente(s), status ${st.padEnd(8)} ${e.map((x) => f(x.tps, 1)).join(' | ').padEnd(34)} ${f(med[k].tps, 1).padStart(11)} | ${e.map((x) => f(x.lat, 3)).join(' | ').padEnd(34)} ${f(med[k].lat, 3)}`);
}
p('', '  Custo dos triggers (CONTA sobre as medianas: razão = tps sem trigger / tps com trigger; latência = com / sem):');
for (const cli of [1, 10]) for (const st of ['fixo', 'sorteado']) {
  const c = med[`com|${cli}|${st}`], s = med[`sem|${cli}|${st}`];
  p(`    ${cli} cliente(s), status ${st}: tps sem/com = ${f(s.tps / c.tps, 2)}x | latência média com/sem = ${f(c.lat / s.lat, 2)}x`);
}
p('', '  Fila no placar (CONTA: razão das medianas de tps, status sorteado / status fixo \'pago\'):');
for (const trig of ['com', 'sem']) for (const cli of [1, 10]) {
  p(`    trigger ${trig}, ${cli} cliente(s): sorteado/fixo = ${f(med[`${trig}|${cli}|sorteado`].tps / med[`${trig}|${cli}|fixo`].tps, 2)}x`);
}
p('', '  Conferência no fim do passo 5 (tabela-resumo x count(*), triggers e linhas mortas):');
const iFim = l5.findIndex((l) => l.startsWith('##### FIM'));
l5.slice(iFim, iFim + 40).filter((l) => l.trim() !== '').forEach((l) => p('    ' + l));

// ---- passo 6 ----
p('', '== PASSO 6: o banco loja ficou como estava? ==');
const filtra = (arq) => lerLinhas(arq).filter((l) => !l.startsWith('Time:') && !l.startsWith('#'));
const antes = filtra('00-estado-antes.txt'), depois = filtra('00-estado-depois.txt');
const iguais = antes.length === depois.length && antes.every((l, i) => l === depois[i]);
p(`  00-estado-antes.txt x 00-estado-depois.txt (sem as linhas "Time:" e o cabeçalho): ${antes.length} linhas x ${depois.length} linhas | ${iguais ? 'IDÊNTICOS' : 'DIFERENTES'}`);
const md5 = (ls) => ls.filter((l) => /^ [0-9a-f]{32}$/.test(l)).map((l) => l.trim());
p(`  impressões digitais md5 (pedidos, itens_pedido, pedidos_por_status, top_produtos_mv, vendas_por_dia_mv): antes ${md5(antes).map((x) => x.slice(0, 8)).join(' ')} | depois ${md5(depois).map((x) => x.slice(0, 8)).join(' ')}`);
const trig = (ls) => ls.filter((l) => /pedidos_por_status_(insert|delete|update|truncate)\s+\|\s+[OD]$/.test(l)).map((l) => l.replace(/\s+/g, ' ').trim());
p(`  triggers (O = ligado) antes: ${trig(antes).join('; ')}`);
p(`  triggers (O = ligado) depois: ${trig(depois).join('; ')}`);
const lim = (arq) => lerLinhas(arq).find((l) => l.startsWith('# Limites')) || '';
p(`  ${lim('00-estado-antes.txt')}`);
p(`  ${lim('00-estado-depois.txt')}`);
const hs = (arq) => (lerLinhas(arq).find((l) => l.startsWith('# Hash')) || '');
p(`  ${hs('00-estado-antes.txt')}`);
p(`  ${hs('00-estado-depois.txt')}`);

fs.writeFileSync(path.join(D, '07-resumo.txt'), out.join('\n') + '\n');
console.log(out.join('\n'));
