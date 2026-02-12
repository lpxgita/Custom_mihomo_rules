#!/usr/bin/env bash
set -euo pipefail

MIHOMO_BIN="${1:-./mihomo}"
RULESET_DIR="${2:-rulesets}"
SRC_DIR="$RULESET_DIR/mrs_src"

if [[ ! -x "$MIHOMO_BIN" ]]; then
  echo "mihomo binary not executable: $MIHOMO_BIN" >&2
  exit 1
fi

mkdir -p "$SRC_DIR"

# Build domain behavior sources from resolve-classical files.
# DOMAIN-SUFFIX -> +.domain
# DOMAIN        -> domain
# DOMAIN-KEYWORD cannot be represented in domain.mrs and is exported separately.
for name in direct reject; do
  in="$RULESET_DIR/${name}_resolve_classical.yaml"
  out_domain="$SRC_DIR/${name}_resolve_domain.yaml"
  out_keyword="$SRC_DIR/${name}_resolve_keyword_classical.yaml"

  printf 'payload:\n' > "$out_domain"
  printf 'payload:\n' > "$out_keyword"

  awk -F, '
    /^  - / {
      gsub(/\r/, "")
      t=$1; sub(/^  - /, "", t); gsub(/^ +| +$/, "", t)
      p=$2; gsub(/^ +| +$/, "", p)
      if (t=="DOMAIN-SUFFIX") {
        print "  - +." p >> dfile
      } else if (t=="DOMAIN") {
        print "  - " p >> dfile
      } else if (t=="DOMAIN-KEYWORD") {
        print "  - DOMAIN-KEYWORD," p >> kfile
      }
    }
  ' dfile="$out_domain" kfile="$out_keyword" "$in"
done

# Build ipcidr behavior sources from no_resolve-classical files.
for name in direct reject; do
  in="$RULESET_DIR/${name}_no_resolve_classical.yaml"
  out_ip="$SRC_DIR/${name}_no_resolve_ipcidr.yaml"
  printf 'payload:\n' > "$out_ip"

  awk -F, '
    /^  - / {
      gsub(/\r/, "")
      t=$1; sub(/^  - /, "", t); gsub(/^ +| +$/, "", t)
      p=$2; gsub(/^ +| +$/, "", p)
      if (t=="IP-CIDR" || t=="IP-CIDR6") {
        print "  - " p
      }
    }
  ' "$in" >> "$out_ip"
done

# Convert to mrs.
"$MIHOMO_BIN" convert-ruleset domain yaml "$SRC_DIR/direct_resolve_domain.yaml" "$RULESET_DIR/direct_resolve.mrs"
"$MIHOMO_BIN" convert-ruleset domain yaml "$SRC_DIR/reject_resolve_domain.yaml" "$RULESET_DIR/reject_resolve.mrs"
"$MIHOMO_BIN" convert-ruleset ipcidr yaml "$SRC_DIR/direct_no_resolve_ipcidr.yaml" "$RULESET_DIR/direct_no_resolve.mrs"
"$MIHOMO_BIN" convert-ruleset ipcidr yaml "$SRC_DIR/reject_no_resolve_ipcidr.yaml" "$RULESET_DIR/reject_no_resolve.mrs"

# Export mrs to text for quick verification.
"$MIHOMO_BIN" convert-ruleset domain mrs "$RULESET_DIR/direct_resolve.mrs" "$SRC_DIR/direct_resolve_from_mrs.txt"
"$MIHOMO_BIN" convert-ruleset domain mrs "$RULESET_DIR/reject_resolve.mrs" "$SRC_DIR/reject_resolve_from_mrs.txt"
"$MIHOMO_BIN" convert-ruleset ipcidr mrs "$RULESET_DIR/direct_no_resolve.mrs" "$SRC_DIR/direct_no_resolve_from_mrs.txt"
"$MIHOMO_BIN" convert-ruleset ipcidr mrs "$RULESET_DIR/reject_no_resolve.mrs" "$SRC_DIR/reject_no_resolve_from_mrs.txt"

# Analysis summary
{
  echo -e "artifact\tcount"
  for f in "$RULESET_DIR"/*_classical.yaml; do
    c=$(awk '/^  - /{n++} END{print n+0}' "$f")
    printf "%s\t%d\n" "$(basename "$f")" "$c"
  done
  for f in "$SRC_DIR"/*_domain.yaml "$SRC_DIR"/*_ipcidr.yaml "$SRC_DIR"/*_keyword_classical.yaml; do
    c=$(awk '/^  - /{n++} END{print n+0}' "$f")
    printf "%s\t%d\n" "$(basename "$f")" "$c"
  done
  for f in "$RULESET_DIR"/*.mrs; do
    sz=$(wc -c < "$f")
    printf "%s(bytes)\t%d\n" "$(basename "$f")" "$sz"
  done
} > "$RULESET_DIR/mrs_analysis.tsv"

echo "Built mrs files:" 
ls -1 "$RULESET_DIR"/*.mrs
