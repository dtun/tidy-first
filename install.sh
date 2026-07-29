#!/usr/bin/env bash
# Sync every skills/*/ directory in this repo to an agent skills directory at a given git ref.
set -euo pipefail

SELF=$(basename "$0")
MODE=install
REF=""
REF_GIVEN=0
DEST=""
WORK=""

usage() {
  cat <<EOF
Usage: $SELF [--ref <git-ref>] [--dest <dir>] [--check] [--dry-run] [--help]

Installs every skill (a skills/*/ directory containing SKILL.md) from this
repo into an agent skills directory, at a specific git ref.

  --ref <git-ref>  Tag, branch, or sha to install from. Default: the latest
                   semver tag, or the current checkout if the repo has none.
  --dest <dir>     Install destination. Default: the first of
                   \$AGENT_SKILLS_DIR, ~/.agents/skills, ~/.claude/skills that
                   exists, with symlinks resolved; ~/.agents/skills is created
                   if none exists.
  --check          Report installed version vs the version at --ref for every
                   skill, then exit. Installs nothing. Exits 1 if any skill is
                   outdated, not installed, or locally modified.
  --dry-run        Show what an install would do. Changes nothing.
  --help           This text.
EOF
}

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 2; }
warn() { printf '%s: warning: %s\n' "$SELF" "$*" >&2; }

trap 'if [ -n "${WORK:-}" ]; then rm -rf "$WORK"; fi' EXIT INT TERM

while [ $# -gt 0 ]; do
  case $1 in
    --ref) [ $# -ge 2 ] || die "--ref requires an argument"; REF=$2; REF_GIVEN=1; shift 2 ;;
    --ref=*) REF=${1#--ref=}; REF_GIVEN=1; shift ;;
    --dest) [ $# -ge 2 ] || die "--dest requires an argument"; DEST=$2; shift 2 ;;
    --dest=*) DEST=${1#--dest=}; shift ;;
    --check) MODE=check; shift ;;
    --dry-run) MODE=dry-run; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

if [ -t 1 ]; then
  BOLD=$(printf '\033[1m'); DIM=$(printf '\033[2m'); RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m'); RESET=$(printf '\033[0m')
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

# Resolve symlinks by cd-ing into the deepest existing component; `readlink -f` is GNU-only.
canonicalize() {
  # shellcheck disable=SC2088  # matching a literal leading tilde, not expanding one
  case $1 in
    "~") set -- "$HOME" ;;
    "~/"*) set -- "$HOME/${1#"~/"}" ;;
  esac
  if [ -d "$1" ]; then
    (cd "$1" && pwd -P)
  else
    local parent base
    parent=$(dirname "$1"); base=$(basename "$1")
    if [ -d "$parent" ]; then
      printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$base"
    else
      printf '%s\n' "$1"
    fi
  fi
}

# metadata.version out of the leading --- frontmatter block, falling back to a
# top-level version:. Quoted or bare, no yq.
parse_version() {
  local v
  [ -f "$1" ] || return 1
  v=$(awk -v sq="'" '
    function unq(s,   f) {
      sub(/^[ \t]*[A-Za-z_-]+:[ \t]*/, "", s)
      sub(/[ \t\r]+$/, "", s)
      f = substr(s, 1, 1)
      if ((f == "\"" || f == sq) && substr(s, length(s), 1) == f) s = substr(s, 2, length(s) - 2)
      return s
    }
    NR == 1 { if ($0 !~ /^---[ \t\r]*$/) exit; fm = 1; next }
    /^(---|\.\.\.)[ \t\r]*$/ { exit }
    /^metadata:[ \t\r]*$/ { meta = 1; next }
    /^[^ \t]/ { meta = 0 }
    meta && /^[ \t]+version:/ { print unq($0); found = 1; exit }
    !meta && /^version:/ { top = unq($0) }
    END { if (!found && top != "") print top }
  ' "$1") || return 1
  [ -n "$v" ] || return 1
  printf '%s\n' "$v"
}

dirs_differ() { ! diff -r -q "$1" "$2" >/dev/null 2>&1; }

# Mirror src onto dst: drop files that no longer exist at the ref, then copy.
sync_skill() {
  local src=$1 dst=$2 rel
  mkdir -p "$dst"
  (cd "$dst" && find . -type f -print) | while IFS= read -r rel; do
    [ -f "$src/$rel" ] || rm -f "$dst/$rel"
  done
  (cd "$src" && find . -type f -print) | while IFS= read -r rel; do
    mkdir -p "$dst/$(dirname "$rel")"
    cp "$src/$rel" "$dst/$rel"
  done
  find "$dst" -depth -type d ! -path "$dst" -exec rmdir {} + 2>/dev/null || true
}

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null) ||
  die "not a git repository: $SCRIPT_DIR"

if [ "$REF_GIVEN" -eq 0 ]; then
  REF=$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)
  [ -n "$REF" ] || REF=$(git -C "$REPO_ROOT" tag --sort=-v:refname 2>/dev/null | head -1 || true)
fi

if [ -n "$REF" ]; then
  git -C "$REPO_ROOT" rev-parse --verify --quiet "$REF^{commit}" >/dev/null ||
    die "unknown git ref: $REF"
  REF_LABEL=$REF
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/skills-install.XXXXXX")
  git -C "$REPO_ROOT" archive --format=tar "$REF" -- skills >"$WORK/skills.tar" 2>/dev/null ||
    die "ref $REF has no skills/ directory"
  tar -xf "$WORK/skills.tar" -C "$WORK"
  SRC_SKILLS="$WORK/skills"
else
  REF_LABEL="working tree"
  SRC_SKILLS="$REPO_ROOT/skills"
fi
[ -d "$SRC_SKILLS" ] || die "no skills/ directory at $REF_LABEL"

DEST_CREATED=0
if [ -n "$DEST" ]; then
  DEST=$(canonicalize "$DEST")
else
  for candidate in "${AGENT_SKILLS_DIR:-}" "$HOME/.agents/skills" "$HOME/.claude/skills"; do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate" ]; then DEST=$(canonicalize "$candidate"); break; fi
  done
  if [ -z "$DEST" ]; then
    DEST=$(canonicalize "${AGENT_SKILLS_DIR:-$HOME/.agents/skills}")
    DEST_CREATED=1
  fi
fi

if [ "$DEST_CREATED" -eq 1 ] && [ "$MODE" = install ]; then
  mkdir -p "$DEST"
  printf 'created %s\n' "$DEST"
elif [ "$DEST_CREATED" -eq 1 ]; then
  printf 'would create %s\n' "$DEST"
fi

ROWS=""
NAME_W=5
V1_W=9
V2_W=6
COUNT=0
N_UPDATED=0
N_SYNC=0
N_NEW=0
N_STALE=0

# Tab is IFS whitespace, so the reader below collapses runs of tabs — an empty
# cell would shift every later column left. Default empties to "-".
add_row() {
  local name=${1:--} v1=${2:--} v2=${3:--}
  ROWS="$ROWS$name	$v1	$v2	$4	$5
"
  [ ${#name} -gt "$NAME_W" ] && NAME_W=${#name}
  [ ${#v1} -gt "$V1_W" ] && V1_W=${#v1}
  [ ${#v2} -gt "$V2_W" ] && V2_W=${#v2}
  return 0
}

for skill_dir in "$SRC_SKILLS"/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  name=$(basename "$skill_dir")
  COUNT=$((COUNT + 1))
  skill_dir=${skill_dir%/}

  ref_version=$(parse_version "$skill_dir/SKILL.md" || true)
  if [ -z "$ref_version" ]; then
    warn "$name: no parseable metadata.version at $REF_LABEL"
    ref_version="?"
  fi

  installed_dir="$DEST/$name"
  if [ -f "$installed_dir/SKILL.md" ]; then
    installed_version=$(parse_version "$installed_dir/SKILL.md" || true)
    if [ -z "$installed_version" ]; then
      warn "$name: no parseable metadata.version in $installed_dir/SKILL.md"
      installed_version="?"
    fi
  else
    installed_version=""
  fi

  if [ -z "$installed_version" ]; then
    state=missing
  elif [ "$installed_version" != "$ref_version" ] || [ "$ref_version" = "?" ]; then
    state=outdated
  elif dirs_differ "$skill_dir" "$installed_dir"; then
    state=modified
  else
    state=synced
  fi

  if [ "$MODE" = check ]; then
    case $state in
      missing)  add_row "$name" "-" "$ref_version" "not installed" red; N_STALE=$((N_STALE + 1)) ;;
      outdated) add_row "$name" "$installed_version" "$ref_version" "outdated" yellow; N_STALE=$((N_STALE + 1)) ;;
      modified) add_row "$name" "$installed_version" "$ref_version" "modified" yellow; N_STALE=$((N_STALE + 1)) ;;
      synced)   add_row "$name" "$installed_version" "$ref_version" "up to date" green; N_SYNC=$((N_SYNC + 1)) ;;
    esac
    continue
  fi

  case $state in
    missing)  action="installed"; color=green; N_NEW=$((N_NEW + 1)) ;;
    outdated) action="updated $installed_version -> $ref_version"; color=green; N_UPDATED=$((N_UPDATED + 1)) ;;
    modified) action="refreshed (local changes overwritten)"; color=yellow; N_UPDATED=$((N_UPDATED + 1)) ;;
    synced)   action="already in sync"; color=dim; N_SYNC=$((N_SYNC + 1)) ;;
  esac
  [ "$MODE" = dry-run ] && [ "$state" != synced ] && action="would be ${action}"
  add_row "$name" "$installed_version" "$ref_version" "$action" "$color"

  if [ "$MODE" = install ] && [ "$state" != synced ]; then
    sync_skill "$skill_dir" "$installed_dir"
  fi
done

if [ "$COUNT" -eq 0 ]; then
  die "no skills found under skills/ at $REF_LABEL"
fi

printf '%sskills @ %s%s -> %s\n\n' "$BOLD" "$REF_LABEL" "$RESET" "$DEST"

if [ "$MODE" = check ]; then
  printf "%s%-${NAME_W}s  %-${V1_W}s  %-${V2_W}s  %s%s\n" \
    "$DIM" "SKILL" "INSTALLED" "AT REF" "STATUS" "$RESET"
else
  printf "%s%-${NAME_W}s  %-${V1_W}s  %-${V2_W}s  %s%s\n" \
    "$DIM" "SKILL" "INSTALLED" "AT REF" "ACTION" "$RESET"
fi

while IFS='	' read -r name v1 v2 status color; do
  [ -n "$name" ] || continue
  case $color in
    green) c=$GREEN ;;
    yellow) c=$YELLOW ;;
    red) c=$RED ;;
    *) c=$DIM ;;
  esac
  printf "%-${NAME_W}s  %-${V1_W}s  %-${V2_W}s  %s%s%s\n" "$name" "$v1" "$v2" "$c" "$status" "$RESET"
done <<EOF
$ROWS
EOF

plural() { [ "$1" -eq 1 ] && printf 'skill' || printf 'skills'; }

printf '\n%d %s' "$COUNT" "$(plural "$COUNT")"
if [ "$MODE" = check ]; then
  [ "$N_STALE" -gt 0 ] && printf ', %d needing attention' "$N_STALE"
  [ "$N_SYNC" -gt 0 ] && printf ', %d up to date' "$N_SYNC"
else
  [ "$N_NEW" -gt 0 ] && printf ', %d new' "$N_NEW"
  [ "$N_UPDATED" -gt 0 ] && printf ', %d updated' "$N_UPDATED"
  [ "$N_SYNC" -gt 0 ] && printf ', %d in sync' "$N_SYNC"
fi
printf '\n'

if [ "$MODE" = check ] && [ "$N_STALE" -gt 0 ]; then
  exit 1
fi
exit 0
