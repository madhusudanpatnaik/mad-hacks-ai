---
title: A Practical Guide to Authentication and Session Management Vulnerabilities
subtitle: A step-by-step breakdown of the most common Session Management Vulnerabilities
tags:
- Bug Bounty
- Cybersecurity
- Technology
- Penetration Testing
- Programming
published: '2025-12-01'
updated: '2026-04-23'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/a-practical-guide-to-authentication-and-session-management-vulnerabilities-517f5412a02a
source_url: https://infosecwriteups.com/a-practical-guide-to-authentication-and-session-management-vulnerabilities-517f5412a02a
---

# A Practical Guide to Authentication and Session Management Vulnerabilities

*A step-by-step breakdown of the most common Session Management Vulnerabilities*

*Published Dec 01, 2025 · Updated Apr 23, 2026 · Free: No*

### Introduction

Modern applications rely heavily on sessions, tokens and identity checks. When these controls aren't implemented correctly, attackers can bypass restrictions or take over accounts with little effort. In this guide, I'll walk you through a checklist of all session-related issues, how to test for them and what their impact can look like. It's a straightforward way to confirm whether an application's session handling is actually secure.

### 1. Old Session Does Not Expire After Password Change

**Description:** When a user changes their password, all existing active sessions (on other devices or browsers) should generally be invalidated.

#### **Steps to Reproduce:**

1. Create an account on the target site.
2. Log in to the account on two different browsers (e.g., Chrome and Firefox/Incognito).
3. On Chrome, navigate to settings and change your password.
4. Once the password change is successful, go to the Firefox window (where the old session is active) and refresh the page or navigate to a new tab.
5. If you remain logged in on Firefox, this is a bug.

**Impact:** If an attacker has hijacked a user's session, they will retain access to the account even after the victim notices suspicious activity and changes their password to secure it.

### 2. Failure to Invalidate Session on Logout (Persistent Session)

**Description:** A common issue where the server does not truly destroy the session token upon logout; the browser simply removes the cookie locally.

#### **Steps to Reproduce:**

1. Log in to your account.
2. Open a cookie editor extension (e.g., EditThisCookie) and copy all current session cookies to your clipboard.
3. Click the "Logout" button on the website.
4. Open the cookie editor again and paste the previously copied cookies back into the browser.
5. Refresh the page
6. If you are logged in again without entering credentials, the bug exists.

**Impact:** If an attacker steals a victim's cookies (via XSS or network sniffing), they can use them to access the account indefinitely, even if the user frequently logs out.

### 3. Browser Cache Weakness (Back Button Vulnerability)

**Description:** Sensitive pages should include Cache-Control headers (e.g., no-store, no-cache) to prevent the browser from storing them locally.

#### **Steps to Reproduce:**

1. Log in to the application.
2. Navigate to sensitive pages (Profile, Settings, Payments).
3. Log out of the account.
4. Press the browser's "Back" button (or Alt + Left Arrow).
5. If you can view the sensitive pages or the cached session appears active, report it.

**Impact:** In public environments (libraries, internet cafes), a malicious user can view the previous user's private data simply by clicking the back button after the victim leaves.

### 4. Email Verification Bypass (Logic Flaw)

**Description:** This logic bug occurs when an application verifies an email address based on a trigger that doesn't correspond to the current email state.

#### **Steps to Reproduce:**

1. Create an account and receive the initial email verification link. **Do not click it yet.**
2. Log in and change your email address to "Email B"
3. The system sends a new link to Email B. Verify that link.
4. Go back to settings and change your email _back_ to the original "Email A".
5. If "Email A" is now marked as verified without you clicking its specific link, this is a bypass.

**Impact:** An attacker can sign up with a fake or targeted email address (e.g., [admin@company.com](mailto:admin@company.com)) and verify it without actually owning that email account, potentially bypassing domain-based restrictions.

### 5. Email Verification Swap Attack

**Description:** A variation of the bypass where a verification link generated for one email address validates a different email address.

#### **Steps to Reproduce:**

1. Create an account with "Email A" (Attacker's email).
2. Receive the verification link at "Email A" but **do not click it**
3. In the application settings, change your email to "Email B" (Victim's email)
4. Go to the inbox of "Email A" and click the verification link sent in Step 2.
5. If "Email B" (the victim's email) gets verified using the link meant for "Email A," this is a bug.

**Impact:** Allows an attacker to confirm an email address they do not own, which can lead to "Pre-Account Takeover" or harassing victims with confirmed account notifications.

### 6. Password Reset Token Persistence (Multiple Requests)

**Description:** Applications should invalidate older password reset tokens when a new one is requested to prevent confusion and race conditions.

#### **Steps to Reproduce:**

1. Create an account with a valid email.
2. Log out and request a "Forgot Password" link (Link 1).
3. Without using Link 1, request a _second_ "Forgot Password" link (Link 2).
4. Go to your email and attempt to use **Link 1** to change the password.
5. If Link 1 still works, report it.

**Impact:** If an attacker gains access to an old email account backup or compromised link history, they can reset the password even if the user has requested a fresh token, creating a persistent backdoor.

### 7. Password Reset Token Re-use

**Description:** A password reset token should be one-time use only.

#### **Steps to Reproduce:**

1. Request a password reset link.
2. Use the link to successfully change your password.
3. After logging in, attempt to visit the same password reset link again.
4. If you can change the password a second time using the same link, the token was not invalidated.

**Impact:** If a victim clicks a reset link and then leaves their browser history accessible, an attacker can use that same link later to takeover the account by resetting the password again.

### 8. Lack of Session Validation on Sensitive Endpoints

**Description:** This happens when an application checks for the _existence_ of a session cookie but does not verify if it is valid/active on specific API endpoints.

#### **Steps to Reproduce:**

1. Log in and navigate to the Profile section.
2. Edit a field (e.g., Name) but do not save yet.
3. Enable Burp Suite Proxy. Click "Save."
4. Capture the request and send it to Repeater. Drop the request in Proxy.
5. Log out of the website in your browser.
6. Go to Burp Repeater, modify the parameters, and send the request.
7. If the server responds with 200 OK and the data changes, the endpoint lacks validation.

**Impact:** Attackers can force changes to a user's account (like changing an email or password) even after the session should have been terminated, leading to full account takeover.

### 9. Session Fixation

**Description:** The application authenticates the user without invalidating the existing session ID, allowing an attacker to "fix" a session ID on a victim.

#### **Steps to Reproduce:**

1. Go to the login page and note the PHPSESSID (or equivalent) value (e.g., XYZ123).
2. Log in with valid credentials.
3. Check the session cookie value again.
4. If the value remains XYZ123, the session was not rotated.

**Impact:** An attacker can send a victim a link with a pre-set session ID. Once the victim logs in, the attacker (who already knows the Session ID) can access the account immediately without needing the password.

### 10. Concurrent Session Limit Bypass

**Description:** Bypassing restrictions on how many devices can be logged in simultaneously.

#### **Steps to Reproduce:**

1. Log in to the account on Browser A.
2. Log in to the same account on Browser B.
3. Check if Browser A is kicked out.
4. If not, use Burp Intruder to send 50 login requests simultaneously to see if there is any cap.

**Impact:** While often low severity, this hinders fraud detection (impossible travel) and allows an attacker to remain unnoticed in an account while the legitimate user is also logged in.

### 11. Missing Session Rotation After Privilege Change

**Description:** Sessions should rotate whenever a user gains higher privileges. If the ID stays the same, attackers who hijacked the earlier low-privilege session can keep using it after the privilege upgrade.

#### **Steps to Reproduce:**

1. Log in as a regular user
2. Note the current session ID.
3. Perform an action that increases privilege (for example, upgrading the account, joining an organization, enabling 2FA or accepting an admin invitation).
4. Check the session cookie again.
5. If the session ID is unchanged, the app failed to rotate

**Impact:** If an attacker steals the session before the privilege change, they inherit the upgraded access without needing to re-authenticate.

### 12. Unrestricted Session Duration (Infinite Sessions)

**Description:** Some apps create sessions that never expire on the server. Even if the cookie has an expiry, the backend keeps it valid indefinitely.

#### **Steps to Reproduce:**

1. Log in.
2. Capture your session cookie.
3. Wait several hours or even days without activity.
4. Reuse the exact same cookie via Burp, or paste it back into your browser.
5. If it still works, the session lifetime is too long.

**Impact:** A stolen cookie becomes a long-term key to the account. Attackers can maintain access for weeks or months without detection.

### 13. Weak "Remember Me" Token Implementation

**Description:** Some applications use predictable or non-rotating "remember me" tokens stored in cookies.

#### **Steps to Reproduce:**

1. Check if the website offers a "Stay logged in" feature.
2. Log in with it enabled and inspect cookies for remember-me values.
3. Log out.
4. Paste back the cookie and refresh.
5. If it logs you in again, the token is static.

**Impact:** Attackers can maintain persistent access even if the user changes their password or logs out.

### 14. JWT Misconfigurations (Stateless Session Issues)

**Description:** Apps using JWT sometimes forget to blacklist or revoke tokens properly.

#### **Steps to Reproduce:**

1. Log in and capture your JWT.
2. Perform logout.
3. Reuse the same JWT in Postman or Burp.
4. If it still works, the server is not revoking tokens.

**Impact:** JWTs become permanent access keys if not invalidated.

### Conclusion

Strong session handling is crucial for keeping accounts safe. The checks in this guide help you spot weak expiration rules, token issues and logic flaws that attackers often rely on. Even simple mistakes can lead to account takeover, so running through this checklist regularly is an easy way to keep your app secure.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly._