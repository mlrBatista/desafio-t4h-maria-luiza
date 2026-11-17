// Gera diagnostico/carga-mista/resumo.txt a partir de resultados/*-diag-* e das saídas desta pasta. Nenhum número é digitado.
// Uso (na raiz do repositório): node diagnostico/carga-mista/gerar-resumo.js
const fs = require('fs');
const path = require('path');
const D = 'diagnostico/carga-mista';
const R = 'resultados';
const SERIES = [
  ['diag-controle', 'A · diag-controle (só o medir.sh)'],
  ['diag-com-escritas', 'B · diag-com-escritas (+ pgbench de escrita, -c 2 -T 75 -R 50)'],
  ['diag-refresh-normal', 'C · diag-refresh-normal (+ REFRESH normal das 2 views, ~45 s depois do início)'],
  ['diag-refresh-concorrente', 'D · diag-refresh-concorrente (+ REFRESH CONCURRENTLY de vendas_por_dia_mv, ~45 s depois do início)'],
  ['diag-controle-depois', 'A\' · diag-controle-depois (só o medir.sh, para conferir a estabilidade)'],
];
const ROTAS = ['cliente', 'cliente-por-email', 'pedidos-do-cliente', 'pedidos-por-status', 'busca-produtos', 'vendas-por-dia', 'top-produtos'];
const NOME = { 'cliente': '/clientes/:id', 'cliente-por-email': '/clientes?email=', 'pedidos-do-cliente': '/clientes/:id/pedidos', 'pedidos-por-status': '/pedidos', 'busca-produtos': '/produtos/busca', 'vendas-por-dia': '/relatorios/vendas-por-dia', 'top-produtos': '/relatorios/top-produtos' };
const med = (a) => { const s = [...a].sort((x, y) => x - y); const n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; };
const f = (x, d = 1) => Number(x).toFixed(d);
const out = [];
const p = (...ss) => { if (ss.length === 0) out.push(''); ss.forEach((s) => out.push(s)); };
const commit = require('child_process').execSync('git rev-parse --short HEAD').toString().trim();

function lerSerie(rot) {
  const pastas = fs.readdirSync(R).filter((d) => d.endsWith('-' + rot)).sort();
  const m = { rps: [], req: [], med: [], p95: [], p99: [], cpuB: [], cpuA: [], memB: [], memA: [], picoA: [], picoB: [] };
  const rr = {}; ROTAS.forEach((k) => (rr[k] = { med: [], p95: [], p99: [] }));
  const ctx = [];
  for (const d of pastas) {
    const r = fs.readFileSync(path.join(R, d, 'resumo.txt'), 'utf8');
    m.rps.push(+r.match(/Requisições\/s:\s+([\d.]+)/)[1]); m.req.push(+r.match(/Requisições:\s+(\d+)/)[1]);
    const t = r.match(/mediana ([\d.]+) ms \| p95 ([\d.]+) ms \| p99 ([\d.]+) ms/); m.med.push(+t[1]); m.p95.push(+t[2]); m.p99.push(+t[3]);
    for (const k of ROTAS) { const x = r.match(new RegExp('^' + k + '\\s+\\d+\\s+([\\d.]+) ms\\s+([\\d.]+) ms\\s+([\\d.]+) ms', 'm')); rr[k].med.push(+x[1]); rr[k].p95.push(+x[2]); rr[k].p99.push(+x[3]); }
    const u = fs.readFileSync(path.join(R, d, 'recursos.txt'), 'utf8');
    const b = u.match(/banco-1\s+\d+\s+([\d.]+)%\s+[\d.]+%\s+([\d.]+) MiB/), a = u.match(/api-1\s+\d+\s+([\d.]+)%\s+[\d.]+%\s+([\d.]+) MiB/);
    m.cpuB.push(+b[1]); m.memB.push(+b[2]); m.cpuA.push(+a[1]); m.memA.push(+a[2]);
    let pa = 0, pb = 0;
    for (const l of fs.readFileSync(path.join(R, d, 'recursos.csv'), 'utf8').split('\n')) { const c = l.split(','); const v = parseFloat(c[2]); if (/api-1/.test(c[1] || '') && v > pa) pa = v; if (/banco-1/.test(c[1] || '') && v > pb) pb = v; }
    m.picoA.push(pa); m.picoB.push(pb);
    const c = fs.readFileSync(path.join(R, d, 'contexto.txt'), 'utf8');
    ctx.push({ pasta: d, sujo: (c.match(/arquivos alterados sem commit: (\d+)/) || [])[1], commit: (c.match(/^commit: (\w+)/m) || [])[1], contrato: /Contrato mantido/.test(fs.readFileSync(path.join(R, d, 'contrato.txt'), 'utf8')) });
  }
  return { pastas, m, rr, ctx };
}

p('# RESUMO do diagnóstico de carga mista, gerado por diagnostico/carga-mista/gerar-resumo.js a partir de resultados/*-diag-* e das saídas desta pasta. Nenhum número foi digitado.');
p(`# Data e hora da geração: ${new Date().toString()} | Commit (HEAD): ${commit}`);
p('# NÃO é uma mudança e NÃO se compara com as séries das mudanças 01 a 10 (rótulos diag-*). Mesma régua: scripts/medir.sh, 20 VUs, 60 s, semente 42, aquecimento de 15 s do medir.sh mais 60 s de aquecimento sem gravar antes de cada série.');
p('# Cenário: outra carga roda no MESMO banco (o banco loja da aplicação, com 1 CPU e 512 MB) enquanto o medir.sh mede a API (0.5 CPU e 256 MB). O banco foi recriado com down -v no fim.');
p('# O pgbench roda em um container separado (postgres:16.4, mesma rede), com o banco como argumento final (sem -d, que liga a depuração).');
p('# Entre o fim da série D e o aquecimento da série A\' passaram-se ~23 min (tempo entre as chamadas do operador); a execução de cada medição está íntegra (cada recursos.csv cobre ~61 s).');

const dados = SERIES.map(([rot, nome]) => ({ rot, nome, ...lerSerie(rot) }));

p('', '== 1. MEDIANAS DAS 3 EXECUÇÕES DE CADA SÉRIE (valores por execução → mediana) ==');
const K = [['rps', 'req/s', 2], ['req', 'requisições', 0], ['med', 'mediana geral (ms)', 1], ['p95', 'p95 geral (ms)', 1], ['p99', 'p99 geral (ms)', 1], ['cpuB', 'CPU média do banco (%)', 1], ['picoB', 'pico de CPU do banco (% , recursos.csv)', 1], ['memB', 'memória média do banco (MiB)', 1], ['cpuA', 'CPU média da API (%)', 1], ['picoA', 'pico de CPU da API (% , recursos.csv)', 1], ['memA', 'memória média da API (MiB)', 1]];
for (const d of dados) {
  p('', d.nome);
  for (const [k, nome, dec] of K) p(`  ${nome.padEnd(42)} ${d.m[k].map((x) => f(x, dec)).join(' | ').padEnd(30)} → ${f(med(d.m[k]), dec)}`);
  p(`  conferência dos contexto.txt: ${d.ctx.map((c) => `${c.pasta.slice(0, 15)} sem commit=${c.sujo} commit=${c.commit} contrato mantido=${c.contrato}`).join(' ; ')}`);
}

p('', '== 2. MEDIANA, p95 E p99 DE CADA ROTA, POR SÉRIE (mediana das 3 execuções, em ms) ==');
for (const k of ROTAS) {
  p('', `${NOME[k]}`);
  for (const d of dados) p(`  ${d.nome.split(' (')[0].padEnd(30)} mediana ${f(med(d.rr[k].med)).padStart(8)} | p95 ${f(med(d.rr[k].p95)).padStart(8)} | p99 ${f(med(d.rr[k].p99)).padStart(8)}   [medianas por execução: ${d.rr[k].med.map((x) => f(x)).join(', ')}]`);
}

p('', '== 3. OS DOIS CONTROLES (A e A\') ==');
const A = med(dados[0].m.rps), A2 = med(dados[4].m.rps);
p(`  req/s: A ${f(A, 2)} (faixa ${f(Math.min(...dados[0].m.rps), 2)} a ${f(Math.max(...dados[0].m.rps), 2)}) | A' ${f(A2, 2)} (faixa ${f(Math.min(...dados[4].m.rps), 2)} a ${f(Math.max(...dados[4].m.rps), 2)}) | diferença A'/A: ${f((A2 / A - 1) * 100)}%`);
p(`  mediana geral (ms): A ${f(med(dados[0].m.med))} | A' ${f(med(dados[4].m.med))}; p95: A ${f(med(dados[0].m.p95))} | A' ${f(med(dados[4].m.p95))}; p99: A ${f(med(dados[0].m.p99))} | A' ${f(med(dados[4].m.p99))}`);
p('  Diferença de req/s de cada série contra o controle A (conta sobre as medianas):');
for (const d of dados) p(`    ${d.nome.split(' (')[0].padEnd(34)} ${f(med(d.m.rps), 2)} req/s | ${f((med(d.m.rps) / A - 1) * 100)}% contra A | ${f((med(d.m.rps) / A2 - 1) * 100)}% contra A'`);

p('', '== 4. SÉRIE B: ESCRITAS DO PGBENCH (-c 2 -T 75 -R 50) ==');
for (let n = 1; n <= 3; n++) {
  const L = fs.readFileSync(path.join(D, 'saidas', `pgbench-diag-com-escritas-${n}.txt`), 'utf8').split('\n');
  const g = (re) => { const x = L.find((l) => re.test(l)); return x ? x.match(re) : null; };
  const tps = g(/^tps = ([\d.]+)/), lat = g(/^latency average = ([\d.]+) ms/), tx = g(/^number of transactions actually processed: (\d+)/), fal = g(/^number of failed transactions: (\d+)/), lag = g(/^rate limit schedule lag: avg ([\d.]+) \(max ([\d.]+)\) ms/);
  p(`  execução ${n}: ${tx[1]} transações | ${f(tps[1], 3)} tps | latência média ${f(lat[1], 3)} ms | falhas ${fal[1]} | atraso da cadência (schedule lag) médio ${lag[1]} ms, máximo ${lag[2]} ms`);
}
const tt = [1, 2, 3].map((n) => { const L = fs.readFileSync(path.join(D, 'saidas', `pgbench-diag-com-escritas-${n}.txt`), 'utf8'); return { tps: +L.match(/^tps = ([\d.]+)/m)[1], lat: +L.match(/^latency average = ([\d.]+) ms/m)[1] }; });
p(`  mediana: ${f(med(tt.map((x) => x.tps)), 3)} tps | latência média ${f(med(tt.map((x) => x.lat)), 3)} ms`);
p('  (cada transação = 1 INSERT e 1 DELETE de um pedido, que dispara os triggers de pedidos_por_status; não deixa dados novos.)');

p('', '== 5. SÉRIES C E D: DURAÇÃO DE CADA REFRESH COM A API LENDO ==');
function tempos(rot, n) {
  const L = fs.readFileSync(path.join(D, 'saidas', `refresh-${rot}-${n}.txt`), 'utf8').split('\n');
  const res = [];
  for (let i = 0; i < L.length; i++) if (L[i].startsWith('##### REFRESH')) { for (let j = i + 1; j < L.length; j++) { const x = L[j].match(/^Time: ([\d.]+) ms/); if (x) { res.push([L[i].replace('##### ', ''), +x[1]]); break; } } }
  return res;
}
for (const rot of ['diag-refresh-normal', 'diag-refresh-concorrente']) {
  p('', `  ${rot}`);
  const porView = {};
  for (let n = 1; n <= 3; n++) {
    const t = fs.readFileSync(path.join(D, 'saidas', `tempos-${rot}-${n}.txt`), 'utf8').trim();
    const ini = t.match(/medir_inicio_epoch=([\d.]+) refresh_inicio_epoch=([\d.]+) refresh_fim_epoch=([\d.]+)/);
    p(`    execução ${n}: o REFRESH começou ${f(+ini[2] - +ini[1])} s depois do início do medir.sh e a sequência durou ${f(+ini[3] - +ini[2], 3)} s no total (inclui o psql)`);
    for (const [nome, ms] of tempos(rot, n)) { (porView[nome] ??= []).push(ms); p(`      ${nome}: ${f(ms, 3)} ms`); }
  }
  for (const [nome, v] of Object.entries(porView)) p(`    mediana de ${nome}: ${f(med(v), 3)} ms (3 execuções: ${v.map((x) => f(x, 3)).join(' | ')})`);
}
p('', '  As leituras das rotas de relatório esperaram durante o REFRESH? Latência MÁXIMA e p99 de cada execução (resumo-k6.json de cada pasta), em ms:');
for (const d of dados) {
  for (const rota of ['top-produtos', 'vendas-por-dia']) {
    const v = d.pastas.map((pasta) => { const j = JSON.parse(fs.readFileSync(path.join(R, pasta, 'resumo-k6.json'), 'utf8')).metrics[`http_req_duration{rota:${rota}}`]; const x = j.values || j; return { max: x.max, p99: x['p(99)'] }; });
    p(`    ${d.nome.split(' (')[0].padEnd(30)} ${NOME[rota].padEnd(28)} máxima por execução: ${v.map((x) => f(x.max)).join(' | ').padEnd(26)} | p99 por execução: ${v.map((x) => f(x.p99)).join(' | ')}`);
  }
}
p('', '  Referência, sem carga (diagnostico/simulacao-escritas/07-resumo.txt, cópia do banco, 3 rodadas): ver aquele arquivo; os números não foram copiados para cá.');

p('', '== 6. ESTADO DO BANCO ==');
const filtra = (arq) => fs.readFileSync(path.join(D, arq), 'utf8').split('\n').filter((l) => !l.startsWith('Time:') && !l.startsWith('#'));
const a = filtra('estado-antes.txt'), b = filtra('estado-depois.txt'), c = filtra('estado-fim-medicoes.txt');
const igual = (x, y) => x.length === y.length && x.every((l, i) => l === y[i]);
p(`  antes x depois de recriar com down -v (sem as linhas "Time:" e o cabeçalho): ${a.length} linhas x ${b.length} linhas | ${igual(a, b) ? 'IDÊNTICOS' : 'DIFERENTES'}`);
p(`  antes x fim das medições (antes de recriar): ${a.length} linhas x ${c.length} linhas | ${igual(a, c) ? 'IDÊNTICOS' : 'DIFERENTES'}`);
const md5 = (ls) => ls.filter((l) => /^ [0-9a-f]{32}$/.test(l)).map((l) => l.trim().slice(0, 8)).join(' ');
p(`  md5 (pedidos, itens_pedido, pedidos_por_status, top_produtos_mv, vendas_por_dia_mv): antes ${md5(a)} | fim das medições ${md5(c)} | depois ${md5(b)}`);
const trig = (ls) => ls.filter((l) => /pedidos_por_status_(insert|delete|update|truncate)\s+\|\s+[OD]$/.test(l)).map((l) => l.replace(/\s+/g, ' ').trim()).join('; ');
p(`  triggers antes: ${trig(a)}`);
p(`  triggers no fim das medições: ${trig(c)}`);
p(`  triggers depois: ${trig(b)}`);
const hdr = (arq, re) => (fs.readFileSync(path.join(D, arq), 'utf8').split('\n').find((l) => re.test(l)) || '');
p(`  ${hdr('estado-antes.txt', /^# Limites/)}`);
p(`  ${hdr('estado-depois.txt', /^# Limites/)}`);
p(`  ${hdr('estado-antes.txt', /^# Hash/)}`);
p(`  ${hdr('estado-depois.txt', /^# Hash/)}`);

fs.writeFileSync(path.join(D, 'resumo.txt'), out.join('\n') + '\n');
console.log(out.join('\n'));
