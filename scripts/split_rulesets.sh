#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-self_rule.txt}"
OUT_DIR="${2:-rulesets}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input not found: $INPUT_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f \
  "$OUT_DIR"/direct_resolve_classical.yaml \
  "$OUT_DIR"/direct_no_resolve_classical.yaml \
  "$OUT_DIR"/reject_resolve_classical.yaml \
  "$OUT_DIR"/reject_no_resolve_classical.yaml \
  "$OUT_DIR"/analysis.tsv

# Map source policy groups to ASCII filenames.
map_group() {
  case "$1" in
    "🎯 全球直连") echo "direct" ;;
    "🛑 广告拦截") echo "reject" ;;
    *) echo "" ;;
  esac
}

# Initialize output files with classical provider format header.
for name in direct reject; do
  printf 'payload:\n' > "$OUT_DIR/${name}_resolve_classical.yaml"
  printf 'payload:\n' > "$OUT_DIR/${name}_no_resolve_classical.yaml"
done

# Split rules by policy group and resolve behavior.
# Output line format is always: TYPE,PAYLOAD
# no-resolve marker is stripped and used only for file routing.
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]] || continue

  content="${line#*- }"
  IFS=',' read -r col1 col2 col3 col4 _rest <<< "$content"

  type="$(echo "$col1" | sed 's/^ *//; s/ *$//')"
  payload="$(echo "$col2" | sed 's/^ *//; s/ *$//')"
  group="$(echo "$col3" | sed 's/^ *//; s/ *$//')"
  opt="$(echo "${col4:-}" | sed 's/^ *//; s/ *$//')"

  [[ -n "$type" && -n "$payload" && -n "$group" ]] || continue

  target="$(map_group "$group")"
  if [[ -z "$target" ]]; then
    # Skip groups outside direct/reject as requested.
    continue
  fi

  if [[ "$opt" == "no-resolve" ]]; then
    printf '  - %s,%s\n' "$type" "$payload" >> "$OUT_DIR/${target}_no_resolve_classical.yaml"
  else
    printf '  - %s,%s\n' "$type" "$payload" >> "$OUT_DIR/${target}_resolve_classical.yaml"
  fi
done < "$INPUT_FILE"

# Build analysis report for filtered output (direct + reject only).
{
  echo -e "section\tcount\tkey"

  awk -F, '/^  - / {
      gsub(/\r/,"")
      g=$3; gsub(/^ +| +$/, "", g)
      if (g=="🎯 全球直连" || g=="🛑 广告拦截") {
        t=$1; sub(/^  - /,"",t); gsub(/^ +| +$/, "", t)
        type[t]++
        grp[g]++
        total++
      }
    }
    END {
      printf("kept_total\t%d\tdirect+reject\n", total)
      for (k in type) printf("type\t%d\t%s\n", type[k], k)
      for (k in grp) printf("group\t%d\t%s\n", grp[k], k)
    }' "$INPUT_FILE" | sort -t$'\t' -k1,1 -k2,2nr

  awk -F, '/^  - / {
      gsub(/\r/,"")
      g=$3; gsub(/^ +| +$/, "", g)
      if (g=="🎯 全球直连" || g=="🛑 广告拦截") {
        if ($4 ~ /no-resolve/) {
          t=$1; sub(/^  - /,"",t); gsub(/^ +| +$/, "", t)
          nr_type[t]++
          nr_group[g]++
          nr_total++
        } else {
          r_group[g]++
          r_total++
        }
      }
    }
    END {
      printf("no_resolve_total\t%d\tdirect+reject\n", nr_total)
      printf("resolve_total\t%d\tdirect+reject\n", r_total)
      for (k in nr_type) printf("no_resolve_type\t%d\t%s\n", nr_type[k], k)
      for (k in nr_group) printf("no_resolve_group\t%d\t%s\n", nr_group[k], k)
      for (k in r_group) printf("resolve_group\t%d\t%s\n", r_group[k], k)
    }' "$INPUT_FILE" | sort -t$'\t' -k1,1 -k2,2nr

  awk -F, '/^  - / {
      gsub(/\r/,"")
      g=$3; gsub(/^ +| +$/, "", g)
      if (g=="🔍 谷歌服务") skip++
    }
    END {
      printf("skipped_group\t%d\t🔍 谷歌服务\n", skip)
    }' "$INPUT_FILE"
} > "$OUT_DIR/analysis.tsv"

echo "Generated files in $OUT_DIR"
ls -1 "$OUT_DIR"
