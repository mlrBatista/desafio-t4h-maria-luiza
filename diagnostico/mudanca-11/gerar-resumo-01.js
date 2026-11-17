// Gera 01-planos-resumo.txt: compara, consulta por consulta, o plano COM e SEM o idx_pedidos_criado_em_dia. Nenhum número é digitado.
const fs = require('fs');
const L = fs.readFileSync('diagnostico/mudanca-11/01-planos.txt', 'utf8').split('\n');
const casos = new Map();
let cur = null;
for (const l of L) {
  const m = l.match(/^##### \[(COM|SEM)\] (.+) \| execucao (\d)$/);
  if (m) { cur = { plano: [], t: null, buf: null }; const k = `${m[2]}`; if (!casos.has(k)) casos.set(k, { COM: [], SEM: [] }); casos.get(k)[m[1]].push(cur); continue; }
  if (/^#####/.test(l)) { cur = null; continue; }
  if (!cur) continue;
  const e = l.match(/Execution Time: ([\d.]+) ms/); if (e) { cur.t = +e[1]; continue; }
  if (/^ *(Planning|Buffers:|Execution)/.test(l) || /^ *(Rows Removed|Heap Fetches|Workers|Sort Method|Batches|Worker \d|Memory Usage|Buckets)/.test(l) || /^\(\d+ rows\)/.test(l) || /QUERY PLAN|^-+$/.test(l.trim().replace(/\+/g, '-')) || l.trim() === '' || /^(ROLLBACK|BEGIN|DROP INDEX)$/.test(l.trim())) continue;
  cur.plano.push(l.replace(/\s+\(cost=.*$/, '').replace(/\s+\(actual .*$/, '').replace(/\d+(\.\d+)?/g, (x, _, off, s) => (/Limit|OFFSET/.test(s) ? x : x)).trimEnd());
}
const med = (a) => { const s = [...a].sort((x, y) => x - y); const n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; };
const forma = (ex) => ex.plano.join('\n');
const out = [];
out.push('# Resumo gerado por diagnostico/mudanca-11/gerar-resumo-01.js a partir de 01-planos.txt. Nenhum número foi digitado.');
out.push('# "forma do plano" = os nós e as condições do plano, sem custos, tempos, linhas e buffers. Tempos em ms (Execution Time) das 3 execuções; consultas isoladas, sem carga.');
out.push('');
out.push('consulta'.padEnd(52) + ' forma igual | COM o índice (3 execuções → mediana)            | SEM o índice (3 execuções → mediana)            | usa o idx_pedidos_criado_em_dia?');
let iguais = 0, diferentes = [], usa = [];
for (const [nome, v] of casos) {
  const fc = new Set(v.COM.map(forma)), fs_ = new Set(v.SEM.map(forma));
  const igual = fc.size === 1 && fs_.size === 1 && [...fc][0] === [...fs_][0];
  if (igual) iguais++; else diferentes.push(nome);
  const mencionaCom = v.COM.some((x) => x.plano.some((l) => l.includes('idx_pedidos_criado_em_dia')));
  if (mencionaCom) usa.push(nome);
  const tc = v.COM.map((x) => x.t), ts = v.SEM.map((x) => x.t);
  out.push(nome.padEnd(52) + ' ' + (igual ? 'sim' : 'NÃO').padEnd(11) + ' | ' + (tc.map((x) => x.toFixed(3)).join(' | ') + ' → ' + med(tc).toFixed(3)).padEnd(46) + ' | ' + (ts.map((x) => x.toFixed(3)).join(' | ') + ' → ' + med(ts).toFixed(3)).padEnd(46) + ' | ' + (mencionaCom ? 'SIM' : 'não'));
}
out.push('');
out.push(`consultas comparadas: ${casos.size} | com a mesma forma de plano COM e SEM o índice: ${iguais} | com forma diferente: ${diferentes.length}${diferentes.length ? ' (' + diferentes.join('; ') + ')' : ''}`);
out.push(`consultas cujo plano COM o índice usa o idx_pedidos_criado_em_dia: ${usa.length}${usa.length ? ' (' + usa.join('; ') + ')' : ''}`);
const razoes = [...casos.entries()].map(([n, v]) => [n, med(v.SEM.map((x) => x.t)) / med(v.COM.map((x) => x.t))]);
out.push(`razão das medianas SEM/COM por consulta (conta): menor ${Math.min(...razoes.map((r) => r[1])).toFixed(2)}x | maior ${Math.max(...razoes.map((r) => r[1])).toFixed(2)}x`);
const ex = [...razoes].sort((a, b) => b[1] - a[1])[0];
out.push(`maior razão: ${ex[0]} (${ex[1].toFixed(2)}x); como o ruído entre execuções de consultas de poucos milissegundos é grande, só a forma do plano é evidência confiável.`);
const idxm = L.findIndex((l) => l.includes('indice_existe_depois'));
out.push(`índice depois do ROLLBACK (1 = existe): ${L[idxm + 2].trim()}`);
fs.writeFileSync('diagnostico/mudanca-11/01-planos-resumo.txt', out.join('\n') + '\n');
console.log(out.join('\n'));
