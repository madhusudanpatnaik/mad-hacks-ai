#!/usr/bin/env python3
"""
test_scope_boundary.py — the authorization gate as a security boundary.

Per the operator-integration audit: scope.py is documented as a HARD STOP for
/mad-hunt. This suite proves it. Attacks the gate with the 14 adversarial
target-shape variants the audit called out, and asserts the critical invariant:

    OUT-OF-SCOPE  ⇒  NO recon · NO probe · NO state mutation · exit != 0

Two-layer coverage:
  A. Correctness: does scope.py correctly classify each variant?
  B. Fail-closed side-effect invariant: on OUT-OF-SCOPE, does the pipeline
     (scope.py + engagement-state.sh) refuse to mutate .engagement/<slug>/?

Note the layered defence: scope.sh check (grep -qiF, substring-vulnerable)
is for humans; scope.py (proper matcher) is the actual gate. This suite
attacks scope.py where the /mad-hunt runtime depends on it, and separately
documents scope.sh check's substring behavior as informational.

Usage: python3 tests/e2e/test_scope_boundary.py [--verbose]
Exit: 0 on pass, 1 on any failure.
"""

import argparse
import os
import subprocess
import sys
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
SCOPE_PY  = REPO / "scripts" / "scope.py"
SCOPE_SH  = REPO / "scripts" / "scope.sh"
STATE_SH  = REPO / "scripts" / "engagement-state.sh"
FIXTURE   = Path(__file__).parent / "fixtures" / "scope-basic.md"


def run(cmd, cwd=None):
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd or str(REPO))
    return p.returncode, p.stdout, p.stderr


def scope_check(target, scope_md=FIXTURE):
    """Return (rc, stdout, stderr) from scope.py against a target."""
    return run(["python3", str(SCOPE_PY), "--md", str(scope_md), target])


class Test:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.passed = []
        self.failed = []

    def check(self, name, cond, detail=""):
        (self.passed if cond else self.failed).append((name, detail))
        marker = "✓" if cond else "✗"
        if not cond or self.verbose:
            print(f"  {marker} {name}" + (f"   ({detail})" if not cond else ""))

    # ═════════════════════════════════════════════════════════════════
    # LAYER A — CORRECTNESS OF THE MATCHER (attack variants)
    # ═════════════════════════════════════════════════════════════════

    def test_exact_in_scope_apex(self):
        rc, out, _ = scope_check("https://example.com/login")
        self.check("apex in-scope: exit 0", rc == 0, detail=out.strip())
        self.check("apex in-scope: prints IN-SCOPE", "IN-SCOPE" in out)

    def test_subdomain_of_bare_domain(self):
        # scope pattern `example.com` → apex + any subdomain
        rc, out, _ = scope_check("https://foo.example.com/x")
        self.check("subdomain of bare-domain rule: in-scope", rc == 0, detail=out.strip())

    def test_deep_subdomain_of_wildcard(self):
        # scope pattern `*.api.example.com` → subdomains only (not apex api.example.com)
        rc, _, _ = scope_check("https://v1.api.example.com/")
        self.check("wildcard *.api.example.com — subdomain in-scope", rc == 0)

    def test_wildcard_apex_is_still_covered_by_bare_rule(self):
        # api.example.com is NOT covered by *.api.example.com, but IS covered by example.com
        rc, out, _ = scope_check("https://api.example.com/")
        self.check(
            "wildcard apex — still in-scope via bare `example.com` rule (both cover)",
            rc == 0,
            detail=out.strip(),
        )

    def test_cidr_in_scope(self):
        rc, _, _ = scope_check("https://10.5.6.7:8443/")
        self.check("CIDR 10.0.0.0/8: 10.5.6.7 in-scope", rc == 0)

    def test_cidr_boundary(self):
        rc, _, _ = scope_check("https://11.0.0.1/")
        self.check("CIDR 10.0.0.0/8: 11.0.0.1 out-of-scope (default deny)", rc != 0)

    def test_regex_in_scope(self):
        rc, _, _ = scope_check("https://lab42.acme.io/")
        self.check("regex re:^lab[0-9]+\\.acme\\.io$: lab42.acme.io in-scope", rc == 0)

    def test_regex_boundary(self):
        rc, _, _ = scope_check("https://labab.acme.io/")
        self.check("regex boundary: labab.acme.io out-of-scope (regex requires digits)", rc != 0)

    def test_default_deny_unknown_domain(self):
        rc, out, _ = scope_check("https://evil.com/")
        self.check("default deny: unknown domain out-of-scope", rc != 0, detail=out.strip())

    # ─── 14-variant attack surface (audit priority #2) ────────────

    def test_attack_suffix_confusion(self):
        # notexample.com should NOT match `example.com` rule (suffix confusion)
        rc, _, _ = scope_check("https://notexample.com/")
        self.check("attack: notexample.com — suffix confusion rejected", rc != 0)

    def test_attack_prefix_confusion(self):
        # example.com.evil.com should NOT match `example.com` rule
        rc, _, _ = scope_check("https://example.com.evil.com/")
        self.check("attack: example.com.evil.com — prefix confusion rejected", rc != 0)

    def test_attack_lookalike_domain(self):
        # exanple.com (l→n typo) should NOT match example.com
        rc, _, _ = scope_check("https://exanple.com/")
        self.check("attack: lookalike (exanple.com) rejected", rc != 0)

    def test_attack_sibling_domain(self):
        # example.org (sibling TLD) should NOT match example.com
        rc, _, _ = scope_check("https://example.org/")
        self.check("attack: sibling TLD (example.org) rejected", rc != 0)

    def test_attack_ip_of_apex_hosted_elsewhere(self):
        # Arbitrary IP not in CIDR 10.0.0.0/8 must be out-of-scope
        rc, _, _ = scope_check("https://8.8.8.8/")
        self.check("attack: 8.8.8.8 (Google DNS) — out of CIDR — rejected", rc != 0)

    def test_attack_url_with_credentials(self):
        # In-scope with credentials: still in-scope; verify no crash + correct outcome
        rc, out, _ = scope_check("https://user:pass@example.com/")
        self.check(
            "attack: URL with credentials — parsed correctly, host classified",
            rc == 0,
            detail=out.strip(),
        )
        # Attack: credentials-injected out-of-scope host — must still be rejected
        rc2, _, _ = scope_check("https://example.com@evil.com/")
        self.check(
            "attack: creds-injection example.com@evil.com — rejected (actual host = evil.com)",
            rc2 != 0,
        )

    def test_attack_alternate_ports(self):
        # Port doesn't change host classification
        rc, _, _ = scope_check("https://example.com:8443/")
        self.check("attack: alt-port :8443 on in-scope host — still in-scope", rc == 0)
        rc2, _, _ = scope_check("https://evil.com:80/")
        self.check("attack: alt-port :80 on out-of-scope host — still rejected", rc2 != 0)

    def test_attack_ipv6_loopback(self):
        # [::1] IPv6 loopback — not in any in-scope pattern
        rc, out, _ = scope_check("https://[::1]/")
        self.check(
            "attack: IPv6 [::1] loopback — out-of-scope (no matching pattern)",
            rc != 0,
            detail=out.strip(),
        )

    def test_attack_ipv6_in_scope_ip(self):
        # 10.0.0.0/8 is IPv4 CIDR. An IPv6-mapped equivalent must NOT match.
        rc, _, _ = scope_check("https://[::ffff:10.0.0.1]/")
        self.check(
            "attack: IPv6-mapped IPv4 [::ffff:10.0.0.1] — out of IPv4 CIDR — rejected",
            rc != 0,
        )

    def test_attack_trailing_dot_hostname(self):
        # example.com. (FQDN with trailing dot) should behave same as example.com
        rc, out, _ = scope_check("https://example.com./")
        self.check(
            "attack: trailing-dot hostname (example.com.) — normalized, in-scope",
            rc == 0,
            detail=out.strip(),
        )
        rc2, _, _ = scope_check("https://evil.com./")
        self.check(
            "attack: trailing-dot on out-of-scope host still rejected",
            rc2 != 0,
        )

    def test_attack_mixed_case_hostname(self):
        rc, _, _ = scope_check("https://ExAmPlE.CoM/")
        self.check("attack: mixed-case ExAmPlE.CoM — case-normalized in-scope", rc == 0)
        rc2, _, _ = scope_check("https://EvIl.CoM/")
        self.check("attack: mixed-case out-of-scope EvIl.CoM — still rejected", rc2 != 0)

    def test_attack_idn_punycode(self):
        # xn--e1afmkfd.com (пример.com in punycode). Not in any rule.
        rc, _, _ = scope_check("https://xn--e1afmkfd.com/")
        self.check(
            "attack: IDN/punycode xn--e1afmkfd.com — out-of-scope (no pattern matches)",
            rc != 0,
        )
        # Reverse attack: what if attacker crafts a punycode form of an
        # in-scope name? Scope patterns should match exact Unicode-canonical
        # form the pattern uses. `example.com` is ASCII; punycode xn--...
        # is a different string; not a bypass.

    def test_attack_wildcard_apex_only(self):
        # scope pattern `*.api.example.com` should NOT match api.example.com bare
        # But the fixture ALSO has `example.com` which DOES match it (peer coverage).
        # So we test wildcard-only behavior with a pattern that has no peer.
        rc, out, _ = run([
            "python3", str(SCOPE_PY),
            "--in-scope", "*.wildonly.test",
            "https://wildonly.test/",
        ])
        self.check(
            "attack: wildcard-only pattern rejects bare apex",
            rc != 0,
            detail=out.strip(),
        )
        rc2, _, _ = run([
            "python3", str(SCOPE_PY),
            "--in-scope", "*.wildonly.test",
            "https://a.wildonly.test/",
        ])
        self.check("wildcard-only matches subdomains", rc2 == 0)

    def test_attack_explicit_exclusion_wins(self):
        # admin.example.com is under example.com (in-scope) BUT admin.example.com
        # is explicitly out-of-scope. Deny must win.
        rc, out, _ = scope_check("https://admin.example.com/")
        self.check(
            "attack: deny-wins — admin.example.com explicit exclusion beats in-scope apex rule",
            rc != 0,
            detail=out.strip(),
        )
        rc2, _, _ = scope_check("https://prod-db.api.example.com/")
        self.check(
            "attack: deny-wins — nested prod-db.api.example.com exclusion beats *.api.example.com rule",
            rc2 != 0,
        )

    def test_attack_junk_input(self):
        # Empty target, just-slashes, random noise
        for bad in ("", "///", "http://", "not a url", "https://"):
            rc, out, _ = scope_check(bad)
            self.check(
                f"attack: junk input {bad!r} — rejected (no crash, exit != 0)",
                rc != 0,
                detail=out.strip()[:80],
            )

    # ═════════════════════════════════════════════════════════════════
    # LAYER B — FAIL-CLOSED SIDE-EFFECT INVARIANT
    # ═════════════════════════════════════════════════════════════════
    # The critical invariant per audit #2:
    #   OUT_OF_SCOPE ⇒  NO recon · NO hunter · NO curl · NO nmap · NO nuclei
    #                   · NO state mutation
    #
    # We test this by attempting the operator's own workflow (engagement-state.sh
    # init on an out-of-scope target) and asserting NO .engagement/<slug>/
    # directory is created. The scope gate is upstream — a downstream call
    # that happens AFTER scope rejection would be a violation of the doctrine.
    #
    # Note: engagement-state.sh does not itself call scope.py — that gate is
    # the OPERATOR's responsibility (documented in /mad-hunt.md). This test
    # therefore documents a live gap: engagement-state.sh accepts ANY target
    # string. Recommendation follows in the report.

    def test_side_effect_no_state_dir_on_explicit_scope_reject(self):
        """The invariant: OUT-OF-SCOPE ⇒ NO state mutation.
        engagement-state.sh init WITH --scope-check <path> MUST refuse to
        create .engagement/<slug>/ for a target scope.py rejects.
        Exit code 4 = scope rejection (distinct from 3=missing-file, 2=usage)."""
        target = "evil.com"
        # baseline: scope.py rejects
        rc, _, _ = scope_check(f"https://{target}/")
        self.check("invariant baseline: evil.com scope-rejected by scope.py", rc != 0)
        # engagement-state.sh init --scope-check FIXTURE MUST refuse
        slug_dir = REPO / ".engagement" / target.lower()
        if slug_dir.exists():
            shutil.rmtree(slug_dir)
        p = subprocess.run(
            ["bash", str(STATE_SH), "init", target,
             "--tech", "e2e-test", "--scope-check", str(FIXTURE)],
            capture_output=True, text=True, cwd=str(REPO),
        )
        self.check(
            "invariant: engagement-state.sh init --scope-check refuses OUT-OF-SCOPE (exit 4)",
            p.returncode == 4,
            detail=f"got exit={p.returncode} stderr={(p.stderr or '')[:200]}",
        )
        self.check(
            "invariant: NO .engagement/<slug>/ directory created on scope rejection",
            not slug_dir.exists(),
            detail="scope refusal must not touch the filesystem",
        )
        self.check(
            "invariant: stderr names the scope file that rejected the target",
            "OUT-OF-SCOPE" in p.stderr and str(FIXTURE.name) in p.stderr,
            detail=(p.stderr or "")[:200],
        )
        if slug_dir.exists():
            shutil.rmtree(slug_dir)

    def test_side_effect_scope_check_accepts_in_scope(self):
        """Positive path: an in-scope target with --scope-check MUST init state."""
        target = "example.com"
        slug_dir = REPO / ".engagement" / target.lower()
        if slug_dir.exists():
            shutil.rmtree(slug_dir)
        p = subprocess.run(
            ["bash", str(STATE_SH), "init", target,
             "--tech", "e2e-test", "--scope-check", str(FIXTURE)],
            capture_output=True, text=True, cwd=str(REPO),
        )
        self.check(
            "positive-path: in-scope target initializes state (exit 0)",
            p.returncode == 0 and slug_dir.exists(),
            detail=f"exit={p.returncode} state_dir_exists={slug_dir.exists()}",
        )
        if slug_dir.exists():
            shutil.rmtree(slug_dir)

    def test_side_effect_no_scope_check_flag_bypasses(self):
        """Test flag semantics: --no-scope-check must allow init for arbitrary
        target (needed for intelligence tests + off-scope research)."""
        target = "evil.com"
        slug_dir = REPO / ".engagement" / target.lower()
        if slug_dir.exists():
            shutil.rmtree(slug_dir)
        p = subprocess.run(
            ["bash", str(STATE_SH), "init", target,
             "--tech", "e2e-test", "--no-scope-check"],
            capture_output=True, text=True, cwd=str(REPO),
        )
        self.check(
            "escape-hatch: --no-scope-check bypasses gate cleanly (exit 0)",
            p.returncode == 0 and slug_dir.exists(),
            detail=f"exit={p.returncode}",
        )
        if slug_dir.exists():
            shutil.rmtree(slug_dir)

    def test_side_effect_discoverable_scope_md_gates_by_default(self):
        """When .t3mp3st/SCOPE.md exists at CWD, engagement-state.sh init
        MUST use it as the scope source WITHOUT explicit --scope-check —
        this is what /mad-hunt.md's workflow relies on."""
        import tempfile
        with tempfile.TemporaryDirectory() as td:
            # Set up a .t3mp3st/SCOPE.md via the fixture content
            scope_dir = Path(td) / ".t3mp3st"
            scope_dir.mkdir()
            (scope_dir / "SCOPE.md").write_text(FIXTURE.read_text())
            # OUT-OF-SCOPE target must be refused
            target = "evil.com"
            p = subprocess.run(
                ["bash", str(STATE_SH), "init", target, "--tech", "e2e-test"],
                capture_output=True, text=True, cwd=td,
            )
            self.check(
                "auto-scope: discoverable .t3mp3st/SCOPE.md refuses OUT-OF-SCOPE without explicit flag",
                p.returncode == 4,
                detail=f"exit={p.returncode} stderr={(p.stderr or '')[:200]}",
            )
            # IN-SCOPE target must be accepted. Note: .engagement/ is always
            # created at REPO/.engagement/<slug>/ (not at CWD/.engagement/) —
            # engagement-state.sh derives REPO from its own script path.
            target2 = "example.com"
            in_scope_dir = REPO / ".engagement" / target2.lower()
            if in_scope_dir.exists():
                shutil.rmtree(in_scope_dir)
            p2 = subprocess.run(
                ["bash", str(STATE_SH), "init", target2, "--tech", "e2e-test"],
                capture_output=True, text=True, cwd=td,
            )
            state_created = in_scope_dir.exists()
            self.check(
                "auto-scope: discoverable SCOPE.md accepts IN-SCOPE target",
                p2.returncode == 0 and state_created,
                detail=f"exit={p2.returncode} state_dir_exists={state_created}",
            )
            if in_scope_dir.exists():
                shutil.rmtree(in_scope_dir)

    def test_scope_selftest_passes(self):
        """The built-in scope.py self-test must pass — that's the matcher's
        canonical acceptance test."""
        rc, out, err = run(["python3", str(SCOPE_PY), "--selftest"])
        self.check(
            "scope.py --selftest PASS",
            rc == 0 and "PASS" in out,
            detail=(err or out).strip()[:200],
        )

    def test_scope_sh_check_substring_vulnerability(self):
        """DOCUMENTED VULNERABILITY: scope.sh check uses grep -qiF (substring
        match). `check example.com` matches a file containing `notexample.com`.
        This is NOT the /mad-hunt gate (scope.py is) but it IS a human-facing
        confirmation that could mislead an operator. Test that /mad-hunt does
        NOT depend on scope.sh check."""
        # Create a doctored SCOPE.md and probe scope.sh check
        import tempfile
        with tempfile.TemporaryDirectory() as td:
            fake_scope_dir = Path(td) / ".t3mp3st"
            fake_scope_dir.mkdir()
            (fake_scope_dir / "SCOPE.md").write_text(
                "# fixture\n\n## In scope\n- notexample.com\n\n"
                "## Out of scope\n- (none)\n"
            )
            p = subprocess.run(
                ["bash", str(SCOPE_SH), "check", "example.com"],
                capture_output=True, text=True, cwd=td,
            )
            # If it exits 0 and says listed → substring bug confirmed
            substring_bug = (p.returncode == 0 and "is listed" in p.stdout)
        self.check(
            "documented: scope.sh check has substring-match behavior (grep -qiF)",
            substring_bug,   # asserting TRUE — this test documents the behavior exists
            detail=(
                "scope.sh check matches example.com in a file containing notexample.com. "
                "This is a human-facing helper only; /mad-hunt uses scope.py (safe). "
                "Recommendation: harden scope.sh check to use scope.py's matcher."
            ),
        )

    def run_all(self):
        print("── scope adversarial boundary tests ──")
        # Layer A: matcher correctness
        self.test_exact_in_scope_apex()
        self.test_subdomain_of_bare_domain()
        self.test_deep_subdomain_of_wildcard()
        self.test_wildcard_apex_is_still_covered_by_bare_rule()
        self.test_cidr_in_scope()
        self.test_cidr_boundary()
        self.test_regex_in_scope()
        self.test_regex_boundary()
        self.test_default_deny_unknown_domain()
        # Layer A: adversarial variants (audit #2)
        self.test_attack_suffix_confusion()
        self.test_attack_prefix_confusion()
        self.test_attack_lookalike_domain()
        self.test_attack_sibling_domain()
        self.test_attack_ip_of_apex_hosted_elsewhere()
        self.test_attack_url_with_credentials()
        self.test_attack_alternate_ports()
        self.test_attack_ipv6_loopback()
        self.test_attack_ipv6_in_scope_ip()
        self.test_attack_trailing_dot_hostname()
        self.test_attack_mixed_case_hostname()
        self.test_attack_idn_punycode()
        self.test_attack_wildcard_apex_only()
        self.test_attack_explicit_exclusion_wins()
        self.test_attack_junk_input()
        # Layer B: side-effect / integration
        self.test_side_effect_no_state_dir_on_explicit_scope_reject()
        self.test_side_effect_scope_check_accepts_in_scope()
        self.test_side_effect_no_scope_check_flag_bypasses()
        self.test_side_effect_discoverable_scope_md_gates_by_default()
        self.test_scope_selftest_passes()
        self.test_scope_sh_check_substring_vulnerability()

        print()
        print(f"  PASSED: {len(self.passed)}   FAILED: {len(self.failed)}")
        if self.failed:
            print()
            print("  Failures / documented gaps:")
            for name, detail in self.failed:
                print(f"    ✗ {name}")
                if detail:
                    print(f"       → {detail[:300]}")
            sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    Test(verbose=args.verbose).run_all()
