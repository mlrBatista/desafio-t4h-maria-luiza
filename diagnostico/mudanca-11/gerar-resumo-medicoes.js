// Gera diagnostico/mudanca-11/resumo-medicoes.txt a partir de resultados/*-11-* e dos tamanhos salvos. Nenhum número é digitado.
const fs = require('fs'), path = require('path');
const R = 'resultados', D = 'diagnostico/mudanca-11';
const SERIES = [['11-controle', 'A · 11-controle (com o índice)'], ['11-sem-indice-dia', 'B · 11-sem-indice-dia (sem o índice)'], ['11-controle-depois', "A' · 11-controle-depois (com o índice de novo)"]];
const ROTAS = ['cliente', 'cliente-por-email', 'pedidos-do-cliente', 'pedidos-por-status', 'busca-produtos', 'vendas-por-dia', 'top-produtos'];
const NOME = { 'cliente': '/clientes/:id', 'cliente-por-email': '/clientes?email=', 'pedidos-do-cliente': '/clientes/:id/pedidos', 'pedidos-por-status': '/pedidos', 'busca-produtos': '/produtos/busca', 'vendas-por-dia': '/relatorios/vendas-por-dia', 'top-produtos': '/relatorios/top-produtos' };
const med = (a) => { const s = [...a].sort((x, y) => x - y); const n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; };
const f = (x, d = 1) => Number(x).toFixed(d);
const out = []; const p = (...ss) => { if (!ss.length) out.push(''); ss.forEach((s) => out.push(s)); };
const commit = require('child_process').execSync('git rev-parse --short HEAD').toString().trim();
function ler(rot) {
  const ds = fs.readdirSync(R).filter((d) => d.endsWith('-' + rot)).sort();
  const m = { rps: [], req: [], med: [], p95: [], p99: [], cpuB: [], picoB: [], memB: [], cpuA: [], picoA: [], memA: [] };
  const rr = {}; ROTAS.forEach((k) => (rr[k] = { med: [], p95: [], p99: [] }));
  const ctx = [];
  for (const d of ds) {
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
    ctx.push(`${d.slice(9, 15)} commit=${(c.match(/^commit: (\w+)/m) || [])[1]} sem commit=${(c.match(/arquivos alterados sem commit: (\d+)/) || [])[1]} api=${(c.match(/api: cpus=(\d+)/) || [])[1]} contrato mantido=${/Contrato mantido/.test(fs.readFileSync(path.join(R, d, 'contrato.txt'), 'utf8'))}`);
  }
  return { m, rr, ctx };
}
const dados = SERIES.map(([rot, nome]) => ({ rot, nome, ...ler(rot) }));
p('# RESUMO das medições da mudança 11 (remover o idx_pedidos_criado_em_dia), gerado por diagnostico/mudanca-11/gerar-resumo-medicoes.js. Nenhum número foi digitado.');
p(`# Data e hora da geração: ${new Date().toString()} | Commit (HEAD): ${commit}`);
p('# A-B-A em sessão contínua, no mesmo dia, com o computador na tomada, 60 s de aquecimento sem gravar antes de cada série e o banco recriado (down -v) a cada mudança de versão.');
p('', '== MEDIANAS DAS 3 EXECUÇÕES (valores por execução → mediana) ==');
const K = [['rps', 'req/s', 2], ['req', 'requisições', 0], ['med', 'mediana geral (ms)', 1], ['p95', 'p95 geral (ms)', 1], ['p99', 'p99 geral (ms)', 1], ['cpuB', 'CPU média do banco (%)', 1], ['picoB', 'pico de CPU do banco (%, recursos.csv)', 1], ['memB', 'memória média do banco (MiB)', 1], ['cpuA', 'CPU média da API (%)', 1], ['picoA', 'pico de CPU da API (%, recursos.csv)', 1], ['memA', 'memória média da API (MiB)', 1]];
for (const d of dados) {
  p('', d.nome);
  for (const [k, n, dec] of K) p(`  ${n.padEnd(40)} ${d.m[k].map((x) => f(x, dec)).join(' | ').padEnd(28)} → ${f(med(d.m[k]), dec)}`);
  p(`  contexto.txt: ${d.ctx.join(' ; ')}`);
}
p('', '== MEDIANA · p95 · p99 DE CADA ROTA (mediana das 3 execuções, ms) ==');
for (const k of ROTAS) { p('', NOME[k]); for (const d of dados) p(`  ${d.nome.split(' (')[0].padEnd(34)} ${f(med(d.rr[k].med)).padStart(7)} · ${f(med(d.rr[k].p95)).padStart(7)} · ${f(med(d.rr[k].p99)).padStart(7)}   [medianas por execução: ${d.rr[k].med.map((x) => f(x)).join(', ')}]`); }
const [A, B, A2] = dados.map((d) => med(d.m.rps));
const faixa = (d) => `${f(Math.min(...d.m.rps), 2)} a ${f(Math.max(...d.m.rps), 2)}`;
p('', '== COMPARAÇÃO (req/s, conta sobre as medianas) ==');
p(`  A ${f(A, 2)} (${faixa(dados[0])}) | B ${f(B, 2)} (${faixa(dados[1])}) | A' ${f(A2, 2)} (${faixa(dados[2])})`);
p(`  B contra A: ${f((B / A - 1) * 100)}% | B contra A': ${f((B / A2 - 1) * 100)}% | A' contra A (diferença entre os dois controles): ${f((A2 / A - 1) * 100)}%`);
const dif = Math.min(Math.abs(B / A - 1), Math.abs(B / A2 - 1)), ctrl = Math.abs(A2 / A - 1);
p(`  a diferença da mudança contra o controle mais próximo (${f(dif * 100)}%) é ${dif < ctrl ? 'MENOR' : 'maior'} que a diferença entre os dois controles (${f(ctrl * 100)}%)`);
p(`  mediana geral (ms): A ${f(med(dados[0].m.med))} | B ${f(med(dados[1].m.med))} | A' ${f(med(dados[2].m.med))}; p95: A ${f(med(dados[0].m.p95))} | B ${f(med(dados[1].m.p95))} | A' ${f(med(dados[2].m.p95))}; p99: A ${f(med(dados[0].m.p99))} | B ${f(med(dados[1].m.p99))} | A' ${f(med(dados[2].m.p99))}`);
p('', '== TAMANHO DOS ÍNDICES DE pedidos (pg_relation_size, salvo antes de cada série) ==');
const tam = (arq) => { const t = fs.readFileSync(path.join(D, 'saidas', arq), 'utf8'); const m = t.match(/^\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(.+?)\s*$/m); const lin = t.split('\n').filter((l) => /^ idx_|^ pedidos_pkey/.test(l)).map((l) => l.replace(/\s+/g, ' ').trim()); return { n: +m[1], bytes: +m[2], pretty: m[3], lin }; };
const ta = tam('tamanhos-11-controle.txt'), tb = tam('tamanhos-11-sem-indice-dia.txt'), tc = tam('tamanhos-11-controle-depois.txt');
p(`  A (com o índice): ${ta.n} índices, ${ta.bytes} bytes (${ta.pretty})`); ta.lin.forEach((l) => p(`      ${l}`));
p(`  B (sem o índice): ${tb.n} índices, ${tb.bytes} bytes (${tb.pretty})`); tb.lin.forEach((l) => p(`      ${l}`));
p(`  A' (com o índice): ${tc.n} índices, ${tc.bytes} bytes (${tc.pretty})`);
p(`  economia (A menos B): ${ta.bytes - tb.bytes} bytes = ${f((ta.bytes - tb.bytes) / 1024, 0)} kB`);
fs.writeFileSync(path.join(D, 'resumo-medicoes.txt'), out.join('\n') + '\n');
console.log(out.join('\n'));
