# CWE → STRIDE Threat Model Mapping

Classify every finding by threat-model leg for SARIF tagging, coverage reporting, and risk aggregation.
Adapted from Strix SARIF module (Apache-2.0). Use with `scripts/sarif-export.py`.

## STRIDE Legs

| Leg | Threat | Question |
|-----|--------|----------|
| **S** — Spoofing | Authentication / identity | Can an attacker pretend to be someone else? |
| **T** — Tampering | Integrity | Can an attacker modify data in transit or at rest? |
| **R** — Repudiation | Audit / logging | Can an attacker deny their actions? |
| **I** — Information Disclosure | Confidentiality | Can an attacker access data they shouldn't? |
| **D** — Denial of Service | Availability | Can an attacker disrupt the service? |
| **E** — Elevation of Privilege | Authorization | Can an attacker gain higher privileges? |

## CWE → STRIDE Mapping (55 entries)

### S — Spoofing (authentication / identity)
| CWE | Name | STRIDE |
|-----|------|--------|
| 287 | Improper Authentication | S |
| 290 | Authentication Bypass by Spoofing | S |
| 294 | Authentication Bypass by Capture-replay | S |
| 306 | Missing Authentication for Critical Function | S, E |
| 345 | Insufficient Verification of Data Authenticity | S, T |
| 346 | Origin Validation Error | S |
| 352 | Cross-Site Request Forgery | T, S |
| 384 | Session Fixation | S |
| 521 | Weak Password Requirements | S |
| 613 | Insufficient Session Expiration | S |
| 640 | Weak Password Recovery Mechanism | S |
| 259 | Use of Hard-coded Password | S, I |
| 798 | Use of Hard-coded Credentials | S, I |
| 1391 | Use of Weak Credentials | S |

### T — Tampering (integrity)
| CWE | Name | STRIDE |
|-----|------|--------|
| 20 | Improper Input Validation | T |
| 73 | External Control of File Name or Path | T, I |
| 78 | OS Command Injection | T, E |
| 79 | Cross-Site Scripting | T, I |
| 89 | SQL Injection | T |
| 91 | XML Injection | T |
| 94 | Code Injection | T, E |
| 434 | Unrestricted File Upload | T |
| 502 | Deserialization of Untrusted Data | T, E |
| 915 | Mass Assignment | E, T |
| 918 | Server-Side Request Forgery | T, I |
| 1336 | Server-Side Template Injection | T, E |

### R — Repudiation (audit / logging)
| CWE | Name | STRIDE |
|-----|------|--------|
| 117 | Improper Output Neutralization for Logs | R |
| 223 | Omission of Security-relevant Information | R |
| 778 | Insufficient Logging | R |

### I — Information Disclosure (confidentiality)
| CWE | Name | STRIDE |
|-----|------|--------|
| 200 | Exposure of Sensitive Information | I |
| 201 | Insertion of Sensitive Info into Sent Data | I |
| 209 | Error Message Containing Sensitive Info | I |
| 256 | Plaintext Storage of a Password | I |
| 311 | Missing Encryption of Sensitive Data | I |
| 319 | Cleartext Transmission of Sensitive Information | I |
| 327 | Broken or Risky Cryptographic Algorithm | I |
| 328 | Use of Weak Hash | I |
| 522 | Insufficiently Protected Credentials | I |
| 525 | Web Browser Cache Containing Sensitive Info | I |
| 532 | Sensitive Information into Log File | I |
| 538 | Sensitive Info into Externally-Accessible File | I |
| 598 | GET Request With Sensitive Query Strings | I |

### D — Denial of Service (availability)
| CWE | Name | STRIDE |
|-----|------|--------|
| 400 | Uncontrolled Resource Consumption | D |
| 770 | Allocation Without Limits or Throttling | D |
| 1333 | ReDoS | D |

### E — Elevation of Privilege (authorization)
| CWE | Name | STRIDE |
|-----|------|--------|
| 269 | Improper Privilege Management | E |
| 284 | Improper Access Control | E |
| 285 | Improper Authorization | E |
| 639 | Authorization Bypass (IDOR/BOLA) | E |
| 732 | Incorrect Permission Assignment | E |
| 862 | Missing Authorization | E |
| 863 | Incorrect Authorization | E |
| 1220 | Insufficient Granularity of Access Control | E |

### Multi-leg
| CWE | Name | STRIDE |
|-----|------|--------|
| 22 | Path Traversal | T, I |
| 611 | XML External Entity (XXE) | I, T |

## Default for unmapped CWEs: T, I
Tampering + information-disclosure is the most common shape for unclassified bugs.

## Usage in T3MP3ST
1. `t3-reporter` tags each finding with its STRIDE leg(s) from this map
2. `sarif-export.py` emits `stride:S`, `stride:T` etc. as SARIF rule tags
3. Coverage reports show which STRIDE legs have been tested vs. gaps
4. Executive summaries group findings by threat-model category
