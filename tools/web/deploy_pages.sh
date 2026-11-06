#!/usr/bin/env bash
# Build BodySim's web version and publish it to the gh-pages branch, which
# GitHub Pages serves at https://udargit829.github.io/BodySim/.
#
#   tools/web/deploy_pages.sh            # build, verify, publish
#   tools/web/deploy_pages.sh --no-push  # build and verify only
#
# gh-pages always holds a single commit (replaced on each deploy), so repeated
# deploys don't pile ~66 MB packs into the repository history.
#
# Environment:
#   GODOT   path to a Godot 4.7 binary
#           (default: ~/Applications/Godot_v4.7.1-stable_linux.x86_64)
set -euo pipefail

PUSH=1
for arg in "$@"; do
  case "$arg" in
    --no-push) PUSH=0 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$ROOT"
GODOT=${GODOT:-$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64}
REMOTE=origin
BRANCH=gh-pages
OUT=build/web
WORKTREE=build/gh-pages

say() { printf '\n== %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ── 1. Preconditions ────────────────────────────────────────────────────────
say "Checking the repository"
[ -z "$(git status --porcelain)" ] || fail "uncommitted changes; commit (or stash) them first so the deploy matches a commit"
git fetch -q "$REMOTE"
LOCAL=$(git rev-parse HEAD)
UPSTREAM=$(git rev-parse "$REMOTE/main")
[ "$LOCAL" = "$UPSTREAM" ] || fail "HEAD ($(git rev-parse --short HEAD)) is not $REMOTE/main; push or pull main first"
SOURCE_SHA=$(git rev-parse --short HEAD)

[ -x "$GODOT" ] || fail "Godot not found at $GODOT (set GODOT=/path/to/godot)"
"$GODOT" --version | grep -q '^4\.7\.' || fail "need Godot 4.7.x, found $("$GODOT" --version)"

# ── 2. Build ────────────────────────────────────────────────────────────────
say "Exporting the Web preset"
rm -rf "$OUT"; mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" > build/web-export.log 2>&1 \
  || { tail -20 build/web-export.log; fail "Godot export failed (full log: build/web-export.log)"; }
[ -s "$OUT/index.pck" ] && [ -s "$OUT/index.wasm" ] || fail "export produced no index.pck/index.wasm"

say "Staging exercise photos"
python3 -I tools/web/stage_web_photos.py "$OUT"
cp LICENSE ATTRIBUTION.md "$OUT/"
touch "$OUT/.nojekyll"

# ── 3. Verify ───────────────────────────────────────────────────────────────
say "Verifying the build"
python3 -I - "$OUT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
key = re.compile(rb"sk-proj-|sk-ant-|sk-[A-Za-z0-9_-]{20,}")
problems = []
for p in root.rglob("*"):
    if not p.is_file():
        continue
    data = p.read_bytes()
    if key.search(data):
        problems.append(f"possible API key in {p}")
    if len(data) > 100 * 1024 * 1024:
        problems.append(f"{p} is over GitHub's 100 MB file limit")
pck = (root / "index.pck").read_bytes()
for marker in (b"kinematic_definition_studio", b"exercise_review_council", b"claude_provider", b"run_claude"):
    if marker in pck:
        problems.append(f"authoring/review tool found in index.pck ({marker.decode()})")
if problems:
    print("\n".join(problems)); sys.exit(1)
print("ok: no API keys, no authoring tools, all files under 100 MB")
PY

# ── 4. Commit to gh-pages ───────────────────────────────────────────────────
say "Preparing $BRANCH"
cleanup() { git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true; git branch -D deploy-tmp >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
REMOTE_PAGES=$(git ls-remote "$REMOTE" "refs/heads/$BRANCH" | cut -f1)
git worktree add -q --detach "$WORKTREE"
(
  cd "$WORKTREE"
  git checkout -q --orphan deploy-tmp
  git rm -rq --cached . >/dev/null 2>&1 || true
  find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -a "$ROOT/$OUT/." .
  git add -A
  git commit -q -m "Deploy BodySim web build ($SOURCE_SHA)"
)
NEW_TREE=$(git -C "$WORKTREE" rev-parse HEAD^{tree})
if [ -n "$REMOTE_PAGES" ]; then
  git fetch -q "$REMOTE" "$BRANCH"
  if [ "$(git rev-parse "$REMOTE_PAGES^{tree}")" = "$NEW_TREE" ]; then
    say "Nothing to deploy: the live site already matches this build"
    exit 0
  fi
fi

# ── 5. Publish ──────────────────────────────────────────────────────────────
if [ "$PUSH" = 0 ]; then
  say "Built and verified in $OUT (--no-push: nothing published)"
  exit 0
fi
say "Publishing to $REMOTE/$BRANCH"
git -C "$WORKTREE" push -q --force-with-lease="$BRANCH:${REMOTE_PAGES}" "$REMOTE" "HEAD:refs/heads/$BRANCH"
say "Deployed $SOURCE_SHA. GitHub Pages will update in a minute or two:"
echo "   https://udargit829.github.io/BodySim/"
