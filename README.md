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
git clone https://github.com/samael0x4/EVIL-403.git
cd EVIL-403
chmod +x evil_403.sh

./evil_403.sh -u https://target.com \
  --payload-path 403_path_payloads.txt \
  --payload-header 403_header_payloads.txt \
  --stealth --ua-rotate --delay 0.4

```

## 📂 Folder Structure
```evil-403/
 ├── evil_403.sh              # main automation wrapper
 ├── payloads/
 │    ├── 403_header_payloads.txt
 │    └── 403_path_payloads.txt
```




## 🔒 Disclaimer
This tool is for educational and authorized security testing only.
Do not use against systems without explicit permission.

