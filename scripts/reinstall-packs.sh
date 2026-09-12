#!/usr/bin/env bash
# reinstall-packs.sh — re-hydrate externally-cloned packs at the commits they were ingested at.
# Reads packs/UPSTREAM.md as source of truth. Idempotent — skips packs already present at the
# right commit, re-clones missing ones, warns on drift.
#
# Usage:
#   scripts/reinstall-packs.sh                # re-hydrate any missing packs
#   scripts/reinstall-packs.sh --update       # re-hydrate to LATEST upstream (drift-tolerated)
#   scripts/reinstall-packs.sh --verify       # only report what's missing / drifted, don't clone
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
REPO_ROOT="$PWD"
MODE="hydrate"
[ "${1:-}" = "--update" ] && MODE="update"
[ "${1:-}" = "--verify" ] && MODE="verify"

# Registry: pack-name  upstream-url  pinned-commit
PACKS=(
  "xalgorix|https://github.com/xalgorix/xalgorix|98d18a458cb1cc4681cdd9fb8ef726f14167ddcb"
  "dalfox|https://github.com/hahwul/dalfox|7bb684fdf48959d10c6a6ac24d4a190361c58c8f"
  "rifteo-skills|https://github.com/Rifteo/skills|c62366221cb3f448495c374eff376549e4bfa107"
  "secrets-patterns-db|https://github.com/mazen160/secrets-patterns-db|24984df1a3f78475132ed183cebce4452b601161"
  "exploitarium|https://github.com/bikini/exploitarium|cdcbe772ed7ee2a36f2d84a93018f820a32a4a9f"
  "CloudRip|https://github.com/moscovium-mc/CloudRip|5bd7d54a6976e86bcb5a816886b2b8432a81967c"
  "Poc|https://github.com/shadowsock5/Poc|b6e7ec272fa6f4bc93918b4d7ba7d83ce8940eaa"
  "Awesome-Bugbounty-Writeups|https://github.com/devanshbatham/Awesome-Bugbounty-Writeups|72010067cd49196f8f45b9137d1c0d06ad5ba915"
  "vulnerability-research|https://github.com/skraft9/vulnerability-research|81664c5ec1b0bf66a75596ad1ea2dfbbcfbbbf38"
  "AILA|https://github.com/project-lambda-zero/AILA|ae50589ff301b23ab501594737d47cf775ca694a"
  "camofox-browser|https://github.com/jo-inc/camofox-browser|e5a36f5cd0332fde6597de474329a308a53a0716"
  "OmniRoute|https://github.com/diegosouzapw/OmniRoute|ba597b631d22d85e56db6982f24b7d1ebe238df9"
)

command -v git >/dev/null || { echo "reinstall-packs: git required"; exit 3; }

for row in "${PACKS[@]}"; do
  NAME="${row%%|*}"; rest="${row#*|}"
  URL="${rest%%|*}";  PIN="${rest#*|}"
  DIR="$REPO_ROOT/packs/$NAME"

  if [ -d "$DIR/.git" ]; then
    HAVE=$(cd "$DIR" && git rev-parse HEAD 2>/dev/null || echo "?")
    if [ "$MODE" = "verify" ]; then
      if [ "$HAVE" = "$PIN" ]; then
        printf "  ✓ %-16s  at pinned commit\n" "$NAME"
      else
        printf "  ⚠ %-16s  drifted: have %s ≠ pin %s\n" "$NAME" "${HAVE:0:12}" "${PIN:0:12}"
      fi
      continue
    fi
    if [ "$MODE" = "update" ]; then
      echo "── updating $NAME to upstream HEAD ──"
      (cd "$DIR" && git pull --depth 1 --ff-only 2>&1 | tail -3)
      continue
    fi
    # hydrate mode: pack already present, leave alone
    if [ "$HAVE" = "$PIN" ]; then
      printf "  ✓ %-16s  present at pinned commit\n" "$NAME"
    else
      printf "  ⚠ %-16s  present but drifted from pin (%s vs %s) — leaving as-is\n" \
        "$NAME" "${HAVE:0:12}" "${PIN:0:12}"
    fi
    continue
  fi

  if [ "$MODE" = "verify" ]; then
    printf "  ✗ %-16s  MISSING — run without --verify to hydrate\n" "$NAME"
    continue
  fi

  echo "── hydrating $NAME from $URL ──"
  # shallow clone; if we need the pinned commit specifically, deepen only enough to reach it
  git clone --depth 1 "$URL" "$DIR" 2>&1 | tail -2
  HAVE=$(cd "$DIR" && git rev-parse HEAD 2>/dev/null || echo "?")
  if [ "$MODE" = "hydrate" ] && [ "$HAVE" != "$PIN" ]; then
    # try to check out the pinned commit — deepen and hope it's reachable
    (cd "$DIR" && git fetch --depth 50 origin "$PIN" 2>/dev/null || true)
    (cd "$DIR" && git checkout -q "$PIN" 2>/dev/null) \
      && printf "  ✓ %-16s  checked out pinned %s\n" "$NAME" "${PIN:0:12}" \
      || printf "  ⚠ %-16s  cloned upstream HEAD (%s); pinned %s not reachable from --depth 1 — run with more history for exact pin\n" "$NAME" "${HAVE:0:12}" "${PIN:0:12}"
  else
    printf "  ✓ %-16s  hydrated (HEAD %s)\n" "$NAME" "${HAVE:0:12}"
  fi
done

echo ""
echo "done. See packs/UPSTREAM.md for provenance + ingested-at dates."
