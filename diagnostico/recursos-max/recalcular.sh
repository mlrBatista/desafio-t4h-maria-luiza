#!/usr/bin/env bash
# Recalcula, a partir do recursos.csv de cada pasta de resultados/, o resumo que o
# scripts/medir.sh grava em recursos.txt, com o awk corrigido (valores convertidos
# para número com "+ 0"), e compara com o que foi gravado. Não altera scripts/ nem resultados/.
# A média também é recalculada, só para confirmar que as mesmas amostras foram usadas.
# Uso: diagnostico/recursos-max/recalcular.sh > diagnostico/recursos-max/comparacao.txt
set -euo pipefail
cd "$(dirname "$0")/../.."

resumo() { # $1 = recursos.csv, $2 = recursos.txt; usa só as N primeiras amostras de cada
  # container, N = "amostras" gravado no recursos.txt (o coletor às vezes grava uma linha
  # depois de o resumo ser calculado). Imprime: container n cpu_media cpu_max mem_media mem_max
  awk -F',' -v txt="$2" '
    BEGIN { while ((getline l < txt) > 0) { split(l, c, " "); if (c[2] ~ /^[0-9]+$/) lim[c[1]] = c[2] } }
    function mib(valor,   numero, unidade) {
      numero = valor; unidade = valor
      gsub(/[^0-9.]/, "", numero); gsub(/[0-9. ]/, "", unidade)
      if (unidade == "GiB") return numero * 1024
      if (unidade == "KiB") return numero / 1024
      if (unidade == "B")   return numero / 1048576
      return numero + 0
    }
    NR > 1 {
      nome = $2; if (nome in lim && n[nome] >= lim[nome]) next
      cpu = $3; gsub(/%/, "", cpu); cpu += 0
      split($4, partes, " / "); memoria = mib(partes[1])
      n[nome]++; sc[nome] += cpu; sm[nome] += memoria
      if (!(nome in mc) || cpu > mc[nome]) mc[nome] = cpu
      if (!(nome in mm) || memoria > mm[nome]) mm[nome] = memoria
    }
    END { for (k in n) printf "%s %d %.1f %.1f %.1f %.1f\n", k, n[k], sc[k]/n[k], mc[k], sm[k]/n[k], mm[k] }
  ' "$1"
}

printf "%-52s %-28s %8s %8s %8s %8s %8s %8s %8s %8s\n" pasta container cpu_med_g cpu_med_c cpu_max_g cpu_max_c mem_med_g mem_med_c mem_max_g mem_max_c
total=0; cpu_max_errado=0; mem_max_errado=0; media_errada=0
for dir in resultados/*/; do
  csv="${dir}recursos.csv"; txt="${dir}recursos.txt"
  [[ -f "$csv" && -f "$txt" ]] || continue
  while read -r nome nam cmed cmax mmed mmax; do
    linha=$(grep -E "^${nome} " "$txt" || true)
    [[ -n "$linha" ]] || continue
    read -r _ _ gcmed gcmax gmmed _ gmmax _ <<<"$(echo "$linha" | tr -d '%')"
    total=$((total+1))
    [[ "$gcmax" != "$cmax" ]] && cpu_max_errado=$((cpu_max_errado+1))
    [[ "$gmmax" != "$mmax" ]] && mem_max_errado=$((mem_max_errado+1))
    [[ "$gcmed" != "$cmed" || "$gmmed" != "$mmed" ]] && media_errada=$((media_errada+1))
    printf "%-52s %-28s %8s %8s %8s %8s %8s %8s %8s %8s\n" "$(basename "$dir")" "${nome#desafio-performance-}" "$gcmed" "$cmed" "$gcmax" "$cmax" "$gmmed" "$mmed" "$gmmax" "$mmax"
  done < <(resumo "$csv" "$txt")
done
echo
echo "Legenda: _g = gravado no recursos.txt pelo medir.sh; _c = recalculado com o awk corrigido."
echo "Linhas (pasta x container): $total"
echo "cpu_max diferente: $cpu_max_errado"
echo "mem_max diferente: $mem_max_errado"
echo "cpu_media ou mem_media diferente: $media_errada"
