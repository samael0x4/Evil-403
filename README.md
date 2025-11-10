# Evil-403

**Advanced, stealthy 403 discovery & bypass tester**

> `Evil-403` is a focused, portable Bash toolkit that finds 403 (Forbidden) pages, attempts high-probability bypasses (path, header, method, encoding), and saves verifiable evidence — all while giving you stealth controls to reduce detection risk.

---

## Why this tool (short & punchy)

* **Designed for accuracy, not noise.** We use body fingerprinting (SHA256) + status checks to reduce false positives — not just a single status code.
* **Stealth-first defaults.** Built-in jittered delays, optional user-agent rotation and conservative request pacing help avoid WAF throttles and bans during real-world engagements.
* **Evidence-grade output.** Full response bodies and headers are saved for each interesting request, making PoCs court/report-ready.
* **Extremely configurable.** Bring your own path and header payload lists — the tool tests *every header* against *every path* (path-first → header permutations) as requested.
* **Portable and safe.** Pure Bash + `curl` (no heavy deps) — runs on Kali, WSL, macOS, minimal Docker images.
* **Audit friendly.** No `eval` usage, robust quoting, `mktemp` directories, and explicit dependency checks.

## Highlights — Why it's better

* **Higher signal, less noise:** Body hashing avoids many false positives common in other fast/noisy tools.
* **Configurable stealth:** Fine-grained `--delay`, `--stealth`, and `--ua-rotate` options let you tune for safe, in-scope tests.
* **Custom payload orchestration:** For each path payload (e.g. `/admin`), the script will run *all* header payloads (e.g. `X-Original-URL: /admin`) and capture the results — ideal for real bug bounty operations.
* **Evidence-first mindset:** Every bypass candidate saves `body` + `hdr` files named with sanitized targets and timestamps — ready for reporting.
* **Minimal runtime footprint:** No Go/Python compilation or heavy runtime libs — perfect for on-box triage.

## Quick comparison (tl;dr)

* **4-Zero-3 / bypass-403 / nomore403**: fast & concurrent but loud. Great for bulk scanning.
* **Evil-403**: slower by default but *safer* — better for validated findings, stealth tests, and deliverable PoCs.

## Quick start

```bash
chmod +x evil_403.sh
./evil_403.sh -u https://target.com \
  --payload-path 403_path_payloads.txt \
  --payload-header 403_header_payloads.txt \
  --stealth --ua-rotate --delay 0.4
```

**Flags**

* `-u, --url` target
* `--payload-path <file>` path payloads (one per line)
* `--payload-header <file>` header payloads (one per line, exact `Header: value` format)
* `-s, --stealth` enable stealth mode
* `--delay <seconds>` base delay between requests
* `--ua-rotate` rotate user-agents per request

## Output & evidence

All evidence is stored in a timestamped directory created in your working directory (`evil403.<random>/`). For each interesting request you will find both:

* `evidence_<sanitized_target>_<sanitized_payload>_body` (full response body)
* `evidence_<sanitized_target>_<sanitized_payload>_hdr` (response headers)

These files are intended to be attached directly to bug-bounty reports — they include exact request headers (sent) and the server response.

## Recommended payload files

Two example files are included in the repo: `403_path_payloads.txt` (high-probability) and `403_header_payloads.txt` (common header tricks). We also provide `*_advanced.txt` variants for edge-case encodings and aggressive payloads.

## Ethics & rules of engagement

Only scan systems where you have **explicit authorization**. Automated bypass testing can trigger defensive mechanisms and cause measurable load. Always get permission, scope boundaries, and exclude sensitive production endpoints unless permitted.

**Pro tip:** Use `--stealth` and `--delay` for live environments, and verify findings with manual checks before reporting.

## Roadmap & contributions

Planned features:

* optional feroxbuster/ffuf integration for automatic discovery of 403 paths
* JSON report export and `--persist <outdir>` to keep evidence in a named folder
* optional concurrency mode with safe rate-limits

Contributions welcome. Open an issue or PR. Respect licensing and responsible disclosure guidelines.

## License

MIT — see `LICENSE` for details.

---

*Made with ☠ by samael0x4 — built for careful, professional recon.*
