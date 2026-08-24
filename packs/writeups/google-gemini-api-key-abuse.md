# Exposed Google / Gemini API Key → Impact (technique)

> Distilled + REDACTED from an authorized bug-bounty writeup (infosecwriteups.com, Coffinxp, 2026-05-23).
> All `AIza...` values are placeholders. **Authorized testing only** — only validate keys that belong to
> an in-scope target, never touch the key owner's uploaded files, always clean up your PoC artifacts.
> This is a secrets/info-disclosure → cloud-billing/data-abuse chain (family: web_api / cloud_infra).

## 0. Where these keys leak
`.env`, JS bundles, config.js, committed secrets. Format: `AIza[0-9A-Za-z_-]{35}`.
gitleaks/trufflehog already flag this class; escalate a hit instead of treating it as low-sev.

## 1. Discover
GitHub code-search dorks (see brain payload class `google-api-dorks`):
- `"GEMINI_API_KEY"`
- `/AIza[0-9A-Za-z_-]{35}/`  · with `path:.env` · with `path:*.js`
- scope to a program: `"target.com" /AIza[0-9A-Za-z_-]{35}/` · `org:<name> /AIza.../`
Live JS: `katana -u <target> -d 2 | grep '\.js$'` then grep bundles for `AIza`.
(Referenced tool: njcve/gkey-burp — Burp extension that scans proxied traffic for these keys.)

## 2. Validate (receipt_required — hits Google with the found key; in-scope only)
```
curl "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_KEY"
```
- 200 + model list (gemini-*, imagen-*, veo-*) → key is LIVE with generative access → confirmed.
- 403 `API_KEY_RESTRICTED` / 400 `API_KEY_INVALID` → revoked or locked down.

## 3. Prove impact (minimal, reversible, then clean up)
- **File API:** `GET /v1beta/files?key=YOUR_KEY` (list — may reveal owner-uploaded data);
  upload a tiny own PoC file, screenshot the returned URL, then **DELETE it**. Never touch owner files.
- **Content generation** (bills the owner): text `POST /v1beta/models/<model>:generateContent`,
  image `:predict` (imagen), video `:predictLongRunning` (veo — highest cost), TTS `:generateContent` AUDIO.
  Do the **minimum** to prove the capability — one request, capture the response, stop.

## 4. Bypass a 403 (referer restriction)
If key is HTTP-referrer restricted, a matching `Referer:` may pass; the `corpora` endpoint is often
less restricted and persistent (higher severity than 48h-expiry files):
```
curl -s -H "Referer: https://www.google.com/" "https://generativelanguage.googleapis.com/v1beta/corpora?key=YOUR_KEY"
```

## 5. Beyond Gemini
The `AIza` format spans Maps, Firebase, Cloud Vision, YouTube Data. A key that fails Gemini may work
elsewhere — check the other services before closing it out.

## 6. Report (what makes it triage fast + higher severity)
1. **Exact source** — full GitHub/JS URL + line number.
2. **Validated capabilities** — each endpoint/model that responded, with the curl + truncated output + PoC artifact.
3. **Financial impact** — compute cost/run from official Gemini pricing (Veo per-second, Imagen per-image);
   "≈ $X/hour at scale" carries far more weight than vague language.
Risk vectors: quota exhaustion (DoS), financial overbilling (Veo/Imagen), data abuse (File/Corpora).

## Gates (mad-Hacks_ai doctrine)
Validation is active + third-party → receipt_required + in-scope only. Prove minimally. Redact the key in
the report (reference it, show first/last chars). Delete every PoC artifact you create.
