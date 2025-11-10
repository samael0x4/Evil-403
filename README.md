# EVIL-403  |  Forbidden Access Destroyer
**Stealth-grade 403 bypass automation wrapper**  
**Designed for bug bounty hunters and security researchers who need clean, modular, and reproducible workflows for bypassing `403 Forbidden` restrictions.**

---

##  Features
- 🔎 **Stealth Recon**: runs `feroxbuster`, `dirsearch`, `ffuf` with low-noise settings to discover 403 endpoints.
- 🛠 **Automated Bypass**: fuzzes with advanced URL + header payloads, integrates with tools like `bypass-403`, `4-ZERO-3`, `nomore403`.
- ⚡ **Validation**: confirms bypasses with `curl`, saves headers + response bodies for evidence.
- 🧩 **Payload Arsenal**: includes `403_master_payloads.txt` (merged URL + header tricks).
- 🕵️ **Stealth Mode**: random User-Agent rotation, jittered rate limiting, scoped hot paths to avoid detection.

---

## Quick Install & Run :
```
git clone https://github.com/<your-username>/EVIL-403.git
cd EVIL-403
chmod +x evil_403.sh

# Run basic usage
./evil_403.sh -u https://target.com

# Run with proxy
./evil_403.sh -u https://target.com -p http://127.0.0.1:8080

# Full arsenal run (payloads + scope + stealth tuning)
./evil_403.sh -u https://target.com -p http://127.0.0.1:8080 \
  --payloads-url ./payloads/403_master_payloads.txt \
  --payloads-header ./payloads/403_header_payloads.txt \
  --scope admin,login,dashboard,api,internal \
  --threads-recon 15 --threads-fuzz 8 --rate 0.2 --timeout 10
```

## 📂 Folder Structure
```evil-403/
 ├── evil_403.sh              # main automation wrapper
 ├── payloads/
 │    ├── 403_master_payloads.txt
 │    ├── 403_url_payloads.txt
 │    └── 403_header_payloads.txt
 ├── .gitignore
 └── README.md
```

## Outputs 
**saved in evil403_out/**
- Recon results → recon/
- Bypass attempts → bypass/
- Validation successes → validation/success.txt
- Evidence → evidence/headers_*.txt, responses/body_*.html


## 🔒 Disclaimer
This tool is for educational and authorized security testing only.
Do not use against systems without explicit permission.

