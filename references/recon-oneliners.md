# recon-oneliners — battle-tested one-liner arsenal

**Source:** `packs/writeups/recon-to-master-the-complete-bug-bounty-checklist.md` + `github-recon-…` + `monitor-bug-bounty-targets-in-real-time-using-certificate-transparency-logs.md` (CoffinXP / Lostsec).

Executable snippets grouped by phase. Prefer these over model-freshly-invented commands — they've hit paydirt in real bounty campaigns. Wordlists live in `wordlists/` and `brain/payloads/`.

---

## 0. Tool availability check
```bash
for t in subfinder assetfinder findomain amass chaos alterx dnsx httpx-toolkit katana hakrawler gau urlfinder uro gf nuclei arjun dirsearch ffuf wpscan naabu nmap masscan Gxss dalfox bxss kxss qsreplace Corsy subzy; do
  command -v $t >/dev/null && echo "OK   $t" || echo "MISS $t"
done
```

## 1. Subdomain enumeration
```bash
subfinder -d TARGET -all -recursive -o subfinder.txt
assetfinder --subs-only TARGET > assetfinder.txt
findomain -t TARGET | tee findomain.txt
chaos -d TARGET -silent | tee chaos.txt
amass enum -passive -d TARGET | cut -d']' -f 2 | awk '{print $1}' | sort -u > amass.txt

# Public sources (curl, no keys)
curl -s "https://crt.sh/?q=%.TARGET&output=json" | jq -r '.[].name_value' | grep -Po '(\w+\.\w+\.\w+)$' > crtsh.txt
curl -s "http://web.archive.org/cdx/search/cdx?url=*.TARGET/*&output=text&fl=original&collapse=urlkey" | sort | sed -e 's_https*://__' -e "s/\/.*//" -e 's/:.*//' -e 's/^www\.//' | sort -u > wayback.txt
curl -s "https://api.hackertarget.com/hostsearch/?q=TARGET" | cut -d',' -f1 > hackertarget.txt
curl -s "https://urlscan.io/api/v1/search/?q=domain:TARGET" | jq -r '.results[].page.domain' | sort -u > urlscan.txt

# GitHub subdomains (needs GH token)
github-subdomains -d TARGET -t "$GH_TOKEN"

# Shodan-powered
shosubgo -d TARGET -s "$SHODAN_KEY"

# Permutation + resolve
subfinder -d TARGET -silent | alterx -enrich | dnsx -silent -resp-only

# Brute force
ffuf -u "https://FUZZ.TARGET" -w wordlists/raft-medium-dirs.txt -mc 200,301,302 -s

# Merge + dedupe
cat *.txt | sort -u > final-subs.txt
```

## 2. Live host / port discovery
```bash
cat final-subs.txt | httpx-toolkit -ports 80,443,8080,8000,8888,8443,3000,5000 -threads 200 > alive.txt

naabu -list ip.txt -c 50 -nmap-cli 'nmap -sV -sC' -o naabu.txt
nmap -p- --min-rate 1000 -T4 -A TARGET -oA fullscan
masscan -p0-65535 TARGET --rate 100000 -oG masscan.txt
```

## 3. ASN + IP fanout
```bash
asnmap -d TARGET | dnsx -silent -resp-only
amass intel -org "COMPANY"
amass intel -active -asn "$ASN"
```

## 4. Visual recon
```bash
cat alive.txt | aquatone -ports 80,81,443,591,2082,2087,2095,2096,3000,8000,8001,8008,8080,8083,8443,8834,8888
```

## 5. URL / crawler collection
```bash
# Active
katana -u alive.txt -d 3 -o urls-katana.txt
cat urls-katana.txt | hakrawler -u > urls-hakr.txt

# Passive
cat alive.txt | gau | sort -u > urls-gau.txt
urlfinder -d TARGET | sort -u > urls-uf.txt

# Combined + dedupe
cat urls-*.txt | uro | sort -u > urls-all.txt
```

## 6. Parameter extraction / GF filtering
```bash
cat urls-all.txt | grep '=' | uro | tee params.txt
cat urls-all.txt | grep -E '\?[^=]+=.+$' | tee params-alt.txt

# GF patterns (needs coffinxp/GFpattren cloned into ~/.gf)
cat params.txt | gf xss  | uro > gf-xss.txt
cat params.txt | gf sqli | uro > gf-sqli.txt
cat params.txt | gf ssrf | uro > gf-ssrf.txt
cat params.txt | gf lfi  | uro > gf-lfi.txt
cat params.txt | gf redirect | uro > gf-redirect.txt
```

## 7. Sensitive-file discovery
```bash
cat urls-all.txt | grep -E "\.(xls|xml|xlsx|json|pdf|sql|doc|docx|pptx|txt|zip|tar\.gz|tgz|bak|7z|rar|log|cache|secret|db|backup|yml|gz|config|csv|yaml|md|md5|tar|xz|7zip|p12|pem|key|crt|csr|sh|pl|py|java|class|jar|war|ear|sqlitedb|sqlite3|dbf|db3|accdb|mdb|sqlcipher|gitignore|env|ini|conf|properties|plist|cfg)$"

# Google dork
site:*.TARGET (ext:doc OR ext:pdf OR ext:xls OR ext:xlsx OR ext:txt OR ext:xml OR ext:json OR ext:zip OR ext:bak OR ext:conf OR ext:sql)
```

## 8. Hidden parameter discovery (arjun)
```bash
arjun -u https://TARGET/endpoint -oT arjun.txt -t 10 --rate-limit 10 --passive -m GET,POST
arjun -u https://TARGET/endpoint -oT arjun.txt -m GET,POST -w wordlists/params.txt -t 10 --rate-limit 10
```

## 9. Directory brute-force
```bash
dirsearch -u https://TARGET -e php,cgi,htm,html,js,txt,bak,zip,old,conf,log,pl,asp,aspx,jsp,sql,db,sqlite,tar,gz,7z,rar,json,xml,yml,yaml,ini --random-agent --recursive -R 3 -t 20 --exclude-status=404 --follow-redirects --delay=0.1

ffuf -w wordlists/raft-medium-dirs.txt -u https://TARGET/FUZZ -fc 400,401,402,403,404,429,500,501,502,503 -recursion -recursion-depth 2 -e .html,.php,.txt,.pdf,.js,.css,.zip,.bak,.old,.log,.json,.xml,.config,.env,.asp,.aspx,.jsp,.gz,.tar,.sql,.db -ac -c -H "User-Agent: Mozilla/5.0" -t 100 -r

# WordPress-specific fuzzing wordlist (coffinxp/payloads → coffin@wp-fuzz.txt)
ffuf -w /path/to/coffin@wp-fuzz.txt -u https://TARGET/FUZZ -fc 401,403,404 -recursion -recursion-depth 2 -e .html,.php,.txt,.pdf -ac -r -t 60 --rate 100 -c
```

## 10. JavaScript recon
```bash
# All JS
echo TARGET | katana -d 3 | grep -E "\.js$" > js.txt

# Secrets by grep
cat js.txt | while read j; do curl -s "$j" | grep -inE '(aws_access_key|aws_secret_key|api[_-]?key|passwd|pwd|heroku|slack|firebase|swagger|password|ftp password|jdbc|db|sql|secret|oauth_token|oauth_token_secret|ssh_key|access_key|secret_token|gcp)'; done

# Nuclei exposures
cat js.txt | nuclei -t nuclei-templates/http/exposures/ -c 30

# LinkFinder for endpoints
cat js.txt | xargs -I@ -P10 bash -c 'python3 linkfinder.py -i @ -o cli 2>/dev/null' | tee endpoints.txt

# SecretFinder
cat js.txt | xargs -I@ -P5 python3 SecretFinder.py -i @ -o cli | tee secrets.txt
```

## 11. GitHub recon (source-leak hunt)
```bash
# Repositories + code
github-subdomains -d TARGET -t "$GH_TOKEN"
gh search code --limit 100 "TARGET api_key"
gh search code --limit 100 "TARGET password"

# Dorks (coffinxp/payloads → github-dork.txt)
# "TARGET" "AWS_SECRET_ACCESS_KEY"
# "TARGET" "aws_access_key_id"
# "TARGET" "api_key"
# "TARGET" ext:env
```

## 12. Certificate-transparency monitoring (real-time)
```bash
# Poll crt.sh every N minutes, diff against last snapshot
while :; do
  curl -s "https://crt.sh/?q=%.TARGET&output=json" | jq -r '.[].name_value' | sort -u > current.txt
  diff last.txt current.txt > new-subs.txt
  cp current.txt last.txt
  cat new-subs.txt | grep '^>' | sed 's/^> //' | httpx-toolkit -silent | tee -a alive-new.txt
  sleep 600
done

# crtmon (coffinxp/crtmon) if installed
crtmon -t TARGET -w webhook.url
```

---

## Per-class recon → hunt handoff

| Class | Recon step | Handoff |
|---|---|---|
| XSS | `gf xss` filter + `Gxss` + `kxss` | `xss-hunter` (see `references/hunt-xss.md`) |
| SQLi | `gf sqli` + `httpx -ms error` timing | `sqli-hunter` + `brain/payloads/sqli.txt` |
| SSRF | `gf ssrf` + Collaborator URLs | `ssrf-hunter` + `brain/payloads/ssrf.txt` |
| LFI | `gf lfi` + `qsreplace /etc/passwd` | manual (`brain/payloads/lfi.txt`) |
| Open-Redirect | `gf redirect` + `loxs/payloads/or.txt` | `open-redirect` agent + `brain/payloads/redirect.txt` |
| Subdomain takeover | `subzy run --targets subs.txt` | `subdomain-takeover` agent |
| CORS | `httpx -H "Origin: evil.com" -mr` | `cors-hunter` |
| Info-Disclosure | `.git` / `.env` / sensitive-file grep | `info-disclosure` agent |

## Tooling attribution
Tools authored by CoffinXP (github.com/coffinxp): `loxs`, `crtmon`, `GFpattren`, `nuclei-templates` (personal), `payloads` (LFI/OR/GH-dork/coffin@wp-fuzz), `lostfuzzer`, `scripts` (punycode_gen, CorsExploit).
