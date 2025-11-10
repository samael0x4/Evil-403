# Evil-403 ☠️

### Stealthy 403 Bypass Automation — built for real bug hunters

**Automatically detects 403-Forbidden endpoints, fires smart header+path bypass payloads, and reports only verified changes (status/body hash diff).**

```bash
./evil_403.sh -u https://target.com \
  --payload-path 403_path_payloads.txt \
  --payload-header 403_header_payloads.txt \
  --stealth --ua-rotate --delay 0.3
```

**Why better:**

* Path-first, header-permutation logic (exhaustive but stealthy)
* SHA256 body comparison → near-zero false positives
* Full evidence saved: body + header per hit
* No deps beyond `bash` + `curl`

**Example output (live):**

```
[INFO] Target: https://target.com
[403] https://target.com/admin
[INFO] https://target.com/admin -> 403
[BYPASS] https://target.com/admin + header[X-Original-URL: /admin] -> 200 (saved evidence)
```

**Perfect for:**  bug bounty bypass tests, recon pipelines, red-team stealth probes.

**License:** MIT | **Author:** samael0x4
