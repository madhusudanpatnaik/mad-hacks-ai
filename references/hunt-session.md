# hunt-session — Authentication + Session Management taxonomy

**Source:** `packs/writeups/a-practical-guide-to-authentication-and-session-management-vulnerabilities.md` (CoffinXP).

14-check ladder — walk it against every login/logout/reset/JWT flow. Every session invariant a modern app should hold is a check here.

---

## 1. Old sessions survive password change
Log in on Chrome + Firefox. Change password on Chrome. Refresh Firefox. Still logged in = **stolen session = permanent access** even after victim rotates password.

## 2. Logout doesn't invalidate server-side
Copy cookies with EditThisCookie → click Logout → paste cookies back → refresh. If you're re-authed → server never destroyed the token = **cookie theft = forever access**.

## 3. Back-button cache leak
Log in → visit `/profile` / `/settings` / `/payments` → Log out → hit browser Back. If sensitive page renders from cache = **PII leak on shared devices**.

## 4. Email-verification bypass (logic)
- Register + don't click original link.
- Change email in settings → verify NEW email.
- Change email BACK to original. If original now shows "verified" without ever clicking its link → bug.

## 5. Email-verification swap
- Sign up as `attacker@x` → don't click the link.
- Change email to `victim@x` in settings.
- Click the ORIGINAL link (sent to `attacker@x`).
- If `victim@x` is now verified → attacker owns a verified account for an email they don't control.

## 6. Password-reset token persistence
Request reset (Link 1). Request reset again (Link 2). Try Link 1. If it works = **stale reset tokens accepted** → past leaked links stay live.

## 7. Password-reset token re-use
Use the reset link once → try the same link a second time. If it still resets → **one-time-use invariant broken**.

## 8. Session validation missing on sensitive endpoints
- Log in, prepare a Profile edit request in Repeater.
- Log out in the browser.
- Send the Repeater request. If it succeeds + data changes → **endpoint checks cookie EXISTS but not that the session is ACTIVE**. Chains to full ATO after any cookie leak.

## 9. Session fixation
Note `PHPSESSID` before login. Log in. Check again. If same → **fixation**. Attacker pre-seeds victim's cookie, waits for them to log in, then reuses.

## 10. Concurrent-session bypass
Log in on Browser A, then B. If A isn't kicked and both persist → concurrent-session cap missing → **impossible-travel fraud detection broken**.

## 11. Missing session rotation after privilege change
Log in as regular user → note session ID → perform action that ups privilege (accept admin invite, upgrade tier, enable 2FA). If session ID stays → hijacker keeps the upgraded access.

## 12. Infinite sessions
Wait hours-days. Reuse cookie. If it still works → **stolen cookie = permanent access**.

## 13. Weak "Remember Me" token
Enable "Stay logged in" → inspect cookie → log out → paste cookie back → refresh. If it logs you in → static remember-token = persistent access surviving password change.

## 14. JWT not revoked on logout
Log in → capture JWT → logout → reuse JWT in Repeater. If accepted → **JWT is permanent** (no server-side blacklist). Common in stateless-only implementations. Chains with #8 for ATO.

---

## Additional adjacent checks (from mad-hacks router)

- **JWT alg-none / kid injection / jku bypass** → `references/hunt-xss.md` § "OAuth/JWT" + Strix `authentication_jwt.md`
- **OAuth redirect_uri / returnTo** → `references/hunt-xss.md` § "10 sub-techniques" D
- **MFA bypass** → `brain/payloads/mfa-bypass.txt`
- **Rate-limit → brute force** → `brain/payloads/brute-force.txt`

## Evidence contract
For every check: full HTTP request/response before AND after the invariant-breaking step. A `200 OK` on an endpoint after logout, or a Set-Cookie that never rotates across state changes, is the proof.

## Escalation
- Any of #1, #2, #8, #12, #13, #14 → **ATO chain** — pair with cookie/token leak (XSS, SSRF, log exposure, referer leak).
- #4/#5 → **Pre-ATO of admin@company.com** (huge bounty).
- #9 → **Session fixation** — usable in phishing chain.
- #11 → **Persistent admin** after victim regains "control".
