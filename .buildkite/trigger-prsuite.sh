#!/usr/bin/env bash
# Resolve the ECE OS/runtime combo and trigger matcher PrSuite on cloud master.
set -euo pipefail

# Comment/New Build use ECE_TESTS_OS and ECE_TESTS_CONTAINER_ENGINE.
# The matcher still expects ECE_TESTS_DOCKER for the engine token; remap here.
# ECE_TESTS_DOCKER is accepted as an alias. Arm OS tokens also set
# ECE_TESTS_ENV=ce-aws-arm (x86 instance types otherwise).

combo_os=""
combo_engine=""
combo_env=""
engine_from_preferred=""

is_generic_os_name() {
  case "$1" in
    linux | Linux | darwin | Darwin | Windows_NT | windows | macOS) return 0 ;;
    *) return 1 ;;
  esac
}

apply_kv() {
  local key="$1"
  local val="$2"
  key="$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"

  case "$key" in
    ECE_TESTS_OS | ECE_TESTS_CONTAINER_ENGINE | ECE_TESTS_DOCKER | ECE_TESTS_ENV) ;;
    ECE_*)
      echo "Unknown ECE_* comment arg: ${key}" >&2
      exit 1
      ;;
    *)
      echo "Ignoring unsupported comment arg: ${key}" >&2
      return 0
      ;;
  esac

  if [[ ! "$val" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value for ${key}: ${val}" >&2
    exit 1
  fi

  case "$key" in
    ECE_TESTS_OS)
      if is_generic_os_name "$val"; then
        echo "Ignoring ${key}=${val} (not an ECE OS token)" >&2
        return 0
      fi
      combo_os="$val"
      ;;
    ECE_TESTS_CONTAINER_ENGINE)
      combo_engine="$val"
      engine_from_preferred=1
      ;;
    ECE_TESTS_DOCKER)
      if [[ -z "${engine_from_preferred:-}" ]]; then
        combo_engine="$val"
      fi
      ;;
    ECE_TESTS_ENV)
      combo_env="$val"
      ;;
  esac
}

if [[ -n "${ECE_TESTS_OS:-}" ]]; then
  apply_kv ECE_TESTS_OS "$ECE_TESTS_OS"
fi
# Preferred name wins over the matcher alias if both are set.
if [[ -n "${ECE_TESTS_DOCKER:-}" ]]; then
  apply_kv ECE_TESTS_DOCKER "$ECE_TESTS_DOCKER"
fi
if [[ -n "${ECE_TESTS_CONTAINER_ENGINE:-}" ]]; then
  apply_kv ECE_TESTS_CONTAINER_ENGINE "$ECE_TESTS_CONTAINER_ENGINE"
fi
if [[ -n "${ECE_TESTS_ENV:-}" ]]; then
  apply_kv ECE_TESTS_ENV "$ECE_TESTS_ENV"
fi

# Named capture group `args` from pull-requests.json, e.g.
# `ECE_TESTS_OS=ubuntu_24.04 ECE_TESTS_CONTAINER_ENGINE=docker_29`.
args="${GITHUB_PR_COMMENT_VAR_ARGS:-}"

# Comment KEY=value overrides New Build / API env. Preferred engine name wins
# regardless of token order (engine_from_preferred).
for token in $args; do
  [[ "$token" == *=* ]] || continue
  apply_kv "${token%%=*}" "${token#*=}"
done

combo_os="${combo_os:-ubuntu_24.04}"
combo_engine="${combo_engine:-docker_29}"

if [[ -z "$combo_env" && "$combo_os" == *arm64* ]]; then
  combo_env="ce-aws-arm"
fi

if [[ ! "$combo_os" =~ ^[A-Za-z0-9._-]+$ || ! "$combo_engine" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid ECE_TESTS_OS=${combo_os} or ECE_TESTS_CONTAINER_ENGINE=${combo_engine}" >&2
  exit 1
fi

echo "Triggering ECE PrSuite ECE_TESTS_OS=${combo_os} ECE_TESTS_CONTAINER_ENGINE=${combo_engine}${combo_env:+ ECE_TESTS_ENV=${combo_env}} branch=${BUILDKITE_BRANCH}"

env_env_line=""
if [[ -n "$combo_env" ]]; then
  env_env_line=$'\n'"        ECE_TESTS_ENV: \"${combo_env}\""
fi

buildkite-agent pipeline upload <<EOF
steps:
  - label: ":elastic: ECE PrSuite (${combo_os} / ${combo_engine})"
    trigger: cloud-integration-ece-matcher-tests
    async: false
    build:
      message: "ansible-ece ${BUILDKITE_BRANCH} PrSuite ${combo_os}/${combo_engine}"
      branch: master
      commit: HEAD
      env:
        ANSIBLE_ECE_BRANCH: "${BUILDKITE_BRANCH}"
        ECE_TEST_USE_LATEST_AVAILABLE_IMAGES: "true"
        ECE_TESTS_OS: "${combo_os}"
        ECE_TESTS_DOCKER: "${combo_engine}"${env_env_line}
        TEST_MATCHER: "-w co.elastic.cloud --tag co.elastic.cloud.test.tags.PrSuite"
EOF
