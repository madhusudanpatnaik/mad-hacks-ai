# hunt-registration — Bug taxonomy for signup / user-registration flows

**Source:** distilled from `packs/writeups/a-comprehensive-guide-to-hunting-bugs-in-user-registration-features.md` and `packs/writeups/uncovering-invisible-privileges-…-mass-assignment-…` (CoffinXP / Lostsec).

The signup flow is the front door where user input first hits the DB + auth layer. Walk this 22-check taxonomy against every POST /register / /signup / /api/*/create endpoint you find.

---

## 1. Duplicate registration / account overwrite
Register a user with an email that already exists. Success = takeover of the original account.
- Variant: **case-sensitivity bypass** — `abc@x` exists, try `Abc@x` / `aBc@x`. If the uniqueness check is case-sensitive but storage is case-insensitive → shadow account.

## 2. Denial-of-Service via input size
Paste `python3 -c "print('A'*20000)"` into `password` or `username`. Response hang + 500 = server exhaustion.

## 3. Missing rate limit on signup
Burp Intruder → 1000 sequential requests with numbered email. All 200 OK without CAPTCHA/lockout = no rate limit.

## 4. Stored XSS in registration fields
- Text fields (`username`, `first_name`, `last_name`):
  ```
  "><img src=x onerror=alert(1)>
  <svg/onload=confirm(1)>
  ```
- Email field (some validators are loose):
  ```
  "><svg/onload=confirm(1)>"@x.y
  "><svg/onload=prompt(1)>"@x.y
  ```
- Bypasses: casing (`<ScRiPt>`), alt events (`onmouseover`, `onsubmit`), encoding. See `references/hunt-xss.md`.

## 5. Insufficient email verification
- **A. Response manipulation** — intercept response, flip `"is_verified":false` → `true`. Grant access.
- **B. Status-code manipulation** — intercept `403` → `200`.
- **C. Force-browsing** — hit `/user/dashboard`, `/account/settings`, `/onboarding/step2` without verifying.
- **D. Verification-swap** — sign up as attacker, change email in settings to victim BEFORE clicking the original link, then click the original link. If the token verifies the new email → **stale-token pre-ATO**.

## 6. Weak registration practices
- Disposable email allowed (Mailinator/TempMail)
- Signup page over HTTP (not HTTPS)

## 7. Weak password policy
- Accepts `123456`, `password`, `qwerty`, `admin`
- Password == username
- Password == email

## 8. Path overwrite / route collision
If profiles live at `site.com/{username}`, register reserved names:
- Modern: `login`, `admin`, `signup`, `api`, `dashboard`
- Legacy: `index.php`, `admin.aspx`, `signup.php`

Visit the URL. If your profile loads where the system page should = **route collision**.

## 9. Server-side validation bypass
Intercept the signup POST. Strip / mutate parameters that frontend enforces:
- Empty username / email
- Password shorter than min
- Invalid email format (`test@test`, `a@b`)
- Special chars in restricted fields

If signup still succeeds → server-side is missing.

## 10. Hidden / legacy registration endpoints
Enumerate:
```
/api/v1/register
/api/v2/register
/auth/create
/user/create
/legacy/signup
/mobile/register
```
Compare validation. Any endpoint with looser checks = target.

## 11. HTTP Parameter Pollution (HPP)
```
email=victim@x&email=attacker@x
```
If server picks the wrong one → account takeover, bypassed validation.

## 12. Weak / predictable verification links
Register + inspect the link format:
- Base64-encoded email → brute forceable
- Short numeric token
- Incrementing IDs

## 13. Punycode / IDN homograph
`admin@example.com` vs `аdmin@example.com` (Cyrillic `а`). Punycode `xn--dmin-7cd@example.com`. If normalized to same user during signup → **pre-ATO of admin**.

See `packs/writeups/the-most-underrated-0-click-account-takeover-using-punycode-idn-homograph-attacks.md`.

## 14. OTP brute-force during signup
Signup requests OTP → verify endpoint has no rate limit → brute-force 000000-999999 with Intruder.

## 15. Reusable session tokens
Compare session cookie before signup / after verification. If unchanged → **session fixation vector**.

## 16. Null-byte injection
Register with `attacker@mail.com%00victim@mail.com` or `username%00.jpg`. If backend truncates at NUL after validation → bypass.

## 17. Missing email confirmation enforcement
Register + skip the verify link + try to log in / perform actions. If the account is fully functional without verification → **impersonation vector**.

## 18. Session fixation during signup + verification
Session ID unchanged across signup → login flow = fixation.

## 19. Cache-control on signup / OTP screens
Complete signup → Back button → OTP screen / verification-status page appears from cache = leaks tokens to next user on shared device.

## 20. Cross-account IDOR after signup
Create accounts A + B. Intercept onboarding APIs. Replace A's IDs with B's. If A can view/mutate B's onboarding → **IDOR in flow**.

## 21. Mass-assignment (crown-jewel)
JSON APIs deserializing into models leak privilege. Full payload library: `brain/payloads/mass-assignment-json.md`.
- `isAdmin:true`, `role:"admin"`, `email_verified:true`, `plan:"enterprise"`
- `__proto__:{"isAdmin":true}` (Node.js prototype pollution)
- Nested `account.role:"admin"`

## 22. OAuth / provider spoofing
Signup normally but inject:
```json
{"provider":"google","provider_id":"<victim-google-sub>"}
```
If system links your password account to victim's Google identity → **ATO via OAuth linking flaw**.

---

## Evidence contract
Every finding: exact endpoint + method + payload sent + response body/status + PROOF the side effect landed (subsequent authenticated GET showing the escalated field). Screenshot / raw HTTP log required.

## Escalation targets
- Mass-assign → Admin ATO / paid-tier bypass / cross-tenant access
- IDN homograph → Pre-ATO of admin@company.com
- Verification bypass → account impersonation on downstream flows
- Route collision → phishing surface
