# Scope Receipt — E2E harness fixture (basic)

> Synthetic scope for tests/e2e/. Do not use for real engagements.

## Authorization
- [x] I have **written authorization** to test the hosts listed below (synthetic fixture).
- Authorizing party / program: tests/e2e/ harness
- Reference: mad-hacks E2E fixture

## In scope
- example.com
- *.api.example.com
- 10.0.0.0/8
- re:^lab[0-9]+\.acme\.io$

## Out of scope (do NOT touch)
- admin.example.com
- internal.example.com
- prod-db.api.example.com

## Rules of engagement
- Environment: [x] local/lab
- Allowed action classes: [x] passive/read-only  [x] active scan
- Rate limits / testing hours: no limit (fixture)
- Traffic identifier: X-E2E-Fixture
- Emergency contact / stop signal: N/A (fixture)
