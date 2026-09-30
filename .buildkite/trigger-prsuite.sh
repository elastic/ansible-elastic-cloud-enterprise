#!/usr/bin/env bash
# Resolve the ECE OS/runtime combo and trigger matcher PrSuite on cloud master.
set -euo pipefail

# Comment/New Build use OS and CONTAINER_ENGINE. The matcher still wants
# ECE_TESTS_OS / ECE_TESTS_DOCKER (legacy names); those aliases still work.
apply_kv() {
  local key="$1"
  local val="$2"
  if [[ ! "$val" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value for ${key}: ${val}" >&2
    exit 1
  fi
  case "$key" in
    OS | ECE_TESTS_OS)
      ECE_TESTS_OS="$val"
      ;;
    CONTAINER_ENGINE | ECE_TESTS_DOCKER)
      ECE_TESTS_DOCKER="$val"
      ;;
    *)
      echo "Ignoring unsupported comment arg: ${key}" >&2
      ;;
  esac
}

if [[ -n "${OS:-}" ]]; then
  apply_kv OS "$OS"
fi
if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
  apply_kv CONTAINER_ENGINE "$CONTAINER_ENGINE"
fi

# Named capture group `args` from pull-requests.json, e.g.
# `OS=ubuntu_24.04 CONTAINER_ENGINE=docker_29`.
args="${GITHUB_PR_COMMENT_VAR_ARGS:-}"
if [[ -z "$args" && -n "${GITHUB_PR_TRIGGER_COMMENT:-}" ]]; then
  args="${GITHUB_PR_TRIGGER_COMMENT#run ece/tests}"
  args="${args#run ece}"
fi

# Comment KEY=value overrides New Build / API env.
for token in $args; do
  [[ "$token" == *=* ]] || continue
  apply_kv "${token%%=*}" "${token#*=}"
done

ECE_TESTS_OS="${ECE_TESTS_OS:-ubuntu_22.04}"
ECE_TESTS_DOCKER="${ECE_TESTS_DOCKER:-docker_25}"

if [[ ! "$ECE_TESTS_OS" =~ ^[A-Za-z0-9._-]+$ || ! "$ECE_TESTS_DOCKER" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid OS=${ECE_TESTS_OS} or CONTAINER_ENGINE=${ECE_TESTS_DOCKER}" >&2
  exit 1
fi

echo "Triggering ECE PrSuite OS=${ECE_TESTS_OS} CONTAINER_ENGINE=${ECE_TESTS_DOCKER} branch=${BUILDKITE_BRANCH}"

buildkite-agent pipeline upload <<EOF
steps:
  - label: ":elastic: ECE PrSuite (${ECE_TESTS_OS} / ${ECE_TESTS_DOCKER})"
    trigger: cloud-integration-ece-matcher-tests
    async: false
    build:
      message: "ansible-ece ${BUILDKITE_BRANCH} PrSuite ${ECE_TESTS_OS}/${ECE_TESTS_DOCKER}"
      branch: master
      commit: HEAD
      env:
        ANSIBLE_ECE_BRANCH: "${BUILDKITE_BRANCH}"
        ECE_TEST_USE_LATEST_AVAILABLE_IMAGES: "true"
        ECE_TESTS_OS: "${ECE_TESTS_OS}"
        ECE_TESTS_DOCKER: "${ECE_TESTS_DOCKER}"
        TEST_MATCHER: "-w co.elastic.cloud --tag co.elastic.cloud.test.tags.PrSuite"
EOF
