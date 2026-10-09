#!/usr/bin/env bash
set -Eeuo pipefail

readonly TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${TESTS_DIR}/.." && pwd)"
readonly INSTALLER="${PROJECT_DIR}/install-dayi-rime.sh"
readonly TEST_ROOT="$(mktemp -d /tmp/dayi-rime-test.XXXXXX)"

cleanup() {
  rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_installer() {
  env \
    DAYI_RIME_DIR="${TEST_ROOT}/home/.local/share/fcitx5/rime" \
    DAYI_FCITX_CONFIG_DIR="${TEST_ROOT}/home/.config/fcitx5" \
    DAYI_AUTOSTART_DIR="${TEST_ROOT}/home/.config/autostart" \
    DAYI_BACKUP_DIR="${TEST_ROOT}/backups" \
    DAYI_CIN_FILE="${DAYI_TEST_CIN_FILE:-}" \
    DAYI_SKIP_PACKAGES=1 \
    DAYI_SKIP_IM_CONFIG=1 \
    DAYI_SKIP_RESTART=1 \
    bash "${INSTALLER}"
}

run_installer
run_installer

readonly RIME_DIR="${TEST_ROOT}/home/.local/share/fcitx5/rime"
readonly PROFILE="${TEST_ROOT}/home/.config/fcitx5/profile"
readonly SCHEMA="${RIME_DIR}/dayi4.schema.yaml"
readonly DICT="${RIME_DIR}/dayi4.dict.yaml"
readonly BUILT_SCHEMA="${RIME_DIR}/build/dayi4.schema.yaml"

[[ -f ${RIME_DIR}/build/dayi4.prism.bin ]] || fail "缺少 dayi4.prism.bin"
[[ -f ${RIME_DIR}/build/dayi4.table.bin ]] || fail "缺少 dayi4.table.bin"
grep -Fqx $'的\t/.' "${DICT}" || fail "缺少 /. → 的"
grep -Fq 'alphabet: "abcdefghijklmnopqrstuvwxyz0123456789,./;"' "${SCHEMA}" || fail "數字或符號未納入取碼"
! grep -Eq 'punctuator|punct_translator|punct_segmentor' "${SCHEMA}" || fail "標點處理器仍會攔截大易符號碼"
! grep -q 'accept: period' "${BUILT_SCHEMA}" || fail "句號仍被綁定為翻頁鍵"
grep -Fq 'alternative_select_keys: "'"'"'[]-\\"' "${SCHEMA}" || fail "大易選字鍵設定錯誤"
[[ $(grep -c '^Name=rime$' "${PROFILE}") -eq 1 ]] || fail "RIME profile 重複或缺失"
[[ $(grep -c 'schema: dayi4' "${RIME_DIR}/default.custom.yaml") -eq 1 ]] || fail "dayi4 schema 重複或缺失"

printf 'PASS: DaYi-RIME installer integration test\n'
