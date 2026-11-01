#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/git-verify-min-version-in-history.sh -v <VAR_NAME> -m <MIN_VERSION> [-r <REF>] [-f <TARGET_FILE>] [-s <true|false>]
#
# Exit code:
#   0 -> Detected version >= min-version
#   1 -> Detected version < min-version or not found

VAR_NAME=""
MIN_VERSION=""
GIT_REF="HEAD"
TARGET_FILE=""
ALLOW_SPACES="true"

usage() {
  cat <<EOF >&2
Usage: $0 -v <VAR_NAME> -m <MIN_VERSION> [-r <REF>] [-f <TARGET_FILE>] [-s <true|false>]
Options:
  -v, --variable-name   Variable name (e.g., OPENRESTY_VERSION)
  -m, --min-version     Minimum required semantic version (e.g., 1.31.8.1)
  -r, --ref             Target git ref to inspect (optional; defaults to HEAD)
  -f, --target-file     Target file path (optional; searches full history if omitted)
  -s, --allow-spaces    Allow spaces around '=': true or false (default: true)
      --no-spaces       Disallow spaces around '=' (shorthand for -s false)
  -h, --help            Show this help message
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--variable-name  ) VAR_NAME="$2";         shift 2 ;;
       --variable-name=*) VAR_NAME="${1#*=}";    shift   ;;

    -m|--min-version    ) MIN_VERSION="$2";      shift 2 ;;
       --min-version=*  ) MIN_VERSION="${1#*=}"; shift   ;;

    -r|--ref            ) GIT_REF="$2";          shift 2 ;;
       --ref=*          ) GIT_REF="${1#*=}";     shift   ;;

    -f|--target-file    ) TARGET_FILE="$2";      shift 2 ;;
       --target-file=*  ) TARGET_FILE="${1#*=}"; shift   ;;

    -s|--allow-spaces   ) ALLOW_SPACES="$2";      shift 2 ;;
       --allow-spaces=* ) ALLOW_SPACES="${1#*=}"; shift   ;;

       --no-spaces      ) ALLOW_SPACES="false";   shift   ;;

    -h|--help           ) usage ;;
    *                   ) echo "Error: Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$VAR_NAME" || -z "$MIN_VERSION" ]]; then
  echo "Error: Missing required arguments." >&2
  usage
fi

REGEX_VERSION='[0-9]+(\.[0-9]+)+'

if [[ "$ALLOW_SPACES" == "true" ]]; then
  REGEX="${VAR_NAME}[[:blank:]]*=[[:blank:]]*['\"]?v*${REGEX_VERSION}"
else
  REGEX="${VAR_NAME}=['\"]?v*${REGEX_VERSION}"
fi

# Setup optional path-limiting arguments
PATH_SPEC=()
if [[ -n "$TARGET_FILE" ]]; then
  PATH_SPEC=(-- "$TARGET_FILE")
  echo "Checking ${VAR_NAME} in ${TARGET_FILE} history on ${GIT_REF} (Threshold: >= ${MIN_VERSION}, Allow spaces: ${ALLOW_SPACES})" >&2
else
  echo "Checking ${VAR_NAME} across full repository history on ${GIT_REF} (Threshold: >= ${MIN_VERSION}, Allow spaces: ${ALLOW_SPACES})" >&2
fi

# 1. Locate the latest commit on GIT_REF touching the variable
COMMIT_HASH=$(git log "$GIT_REF" -n 1 --format="%H" -G "$REGEX" "${PATH_SPEC[@]}" 2>/dev/null || true)

DETECTED_VERSION=""
if [[ -n "$COMMIT_HASH" ]]; then
  echo "Latest commit touching ${VAR_NAME} on ${GIT_REF}: ${COMMIT_HASH}" >&2
  DETECTED_VERSION=$(git grep -E -h "$REGEX" "$COMMIT_HASH" "${PATH_SPEC[@]}" 2>/dev/null | grep -oE "$REGEX_VERSION" | head -n1 || true)
else
  echo "No commit found matching regex with -G on ${GIT_REF}; checking ref directly..." >&2
  DETECTED_VERSION=$(git grep -E -h "$REGEX" "$GIT_REF" "${PATH_SPEC[@]}" 2>/dev/null | grep -oE "$REGEX_VERSION" | head -n1 || true)
fi

echo "Detected version: '${DETECTED_VERSION:-not found}'" >&2

if [[ -z "$DETECTED_VERSION" ]]; then
  echo "Warning: Version not found." >&2
  exit 1
fi

# Print detected version to stdout
echo "$DETECTED_VERSION"

# 2. Semantic version comparison via sort -V
LOWEST_VERSION=$(printf '%s\n%s\n' "$DETECTED_VERSION" "$MIN_VERSION" | sort -V | head -n1)

if [[ "$DETECTED_VERSION" == "$MIN_VERSION" || "$LOWEST_VERSION" == "$MIN_VERSION" ]]; then
  echo "Version (${DETECTED_VERSION}) meets or exceeds requirement (${MIN_VERSION})." >&2
  exit 0
else
  echo "Version (${DETECTED_VERSION}) is older than requirement (${MIN_VERSION})." >&2
  exit 1
fi
