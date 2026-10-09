#!/usr/bin/env bash
set -Eeuo pipefail

readonly DAYI_SOURCE_COMMIT="ea28d61b50950b3738e3f401e5828478d303d0fe"
readonly DAYI_SOURCE_URL="https://raw.githubusercontent.com/chinese-opendesktop/cin-tables/${DAYI_SOURCE_COMMIT}/dayi4.cin"
readonly DAYI_SOURCE_SHA256="0291a6ffdd211fd4142ec733ee72c53d2b6a0587b6c35ffdbb04df44fa3760d5"

log() {
  printf '[DaYi-RIME] %s\n' "$*"
}

die() {
  printf '[DaYi-RIME] ERROR: %s\n' "$*" >&2
  exit 1
}

if [[ ${EUID} -eq 0 ]]; then
  die "請以一般使用者執行，不要在整支腳本前加 sudo；腳本只會在安裝系統套件時要求密碼。"
fi

command -v apt-get >/dev/null 2>&1 || die "目前只支援使用 apt 的 Ubuntu / Linux Mint 系統。"

readonly USER_HOME="${HOME}"
readonly RIME_DIR="${DAYI_RIME_DIR:-${XDG_DATA_HOME:-${USER_HOME}/.local/share}/fcitx5/rime}"
readonly FCITX_CONFIG_DIR="${DAYI_FCITX_CONFIG_DIR:-${XDG_CONFIG_HOME:-${USER_HOME}/.config}/fcitx5}"
readonly AUTOSTART_DIR="${DAYI_AUTOSTART_DIR:-${XDG_CONFIG_HOME:-${USER_HOME}/.config}/autostart}"
readonly BACKUP_ROOT="${DAYI_BACKUP_DIR:-${XDG_DATA_HOME:-${USER_HOME}/.local/share}/dayi-rime-installer/backups}"
readonly RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
readonly WORK_DIR="$(mktemp -d /tmp/dayi-rime-installer.XXXXXX)"

cleanup() {
  rm -rf -- "${WORK_DIR}"
}
trap cleanup EXIT

repair_known_nctu_mirror() {
  local source_file="/etc/apt/sources.list.d/official-package-repositories.list"
  local backup_file

  [[ -f ${source_file} ]] || return 1
  grep -q 'http://ubuntu\.cs\.nctu\.edu\.tw/ubuntu' "${source_file}" || return 1

  backup_file="${source_file}.bak-${RUN_STAMP}"
  log "偵測到會回傳 403 的 NCTU HTTP 鏡像；備份並切換至 Ubuntu HTTPS 官方鏡像。"
  sudo cp -a "${source_file}" "${backup_file}"
  sudo sed -i \
    -e 's|http://ubuntu.cs.nctu.edu.tw/ubuntu|https://archive.ubuntu.com/ubuntu|g' \
    -e 's|http://security.ubuntu.com/ubuntu/|https://security.ubuntu.com/ubuntu/|g' \
    "${source_file}"
  log "原套件來源已備份到 ${backup_file}"
}

install_packages() {
  local packages=(
    ca-certificates
    curl
    fcitx5
    fcitx5-config-qt
    fcitx5-rime
    librime-bin
    im-config
  )

  log "更新 apt 套件索引。"
  if ! sudo apt-get update; then
    repair_known_nctu_mirror || die "apt-get update 失敗，且不是已知的 NCTU 鏡像問題。"
    sudo apt-get update
  fi

  log "安裝 Fcitx5、RIME 與設定工具。"
  if ! sudo apt-get install -y "${packages[@]}"; then
    repair_known_nctu_mirror || die "套件安裝失敗；請查看上方 apt 錯誤。"
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
  fi
}

download_dayi_table() {
  local output_file="$1"
  local actual_sha

  if [[ -n ${DAYI_CIN_FILE:-} ]]; then
    [[ -f ${DAYI_CIN_FILE} ]] || die "DAYI_CIN_FILE 不存在：${DAYI_CIN_FILE}"
    cp "${DAYI_CIN_FILE}" "${output_file}"
  else
    log "下載固定版本的大易四碼表。"
    curl -fL --retry 3 --retry-delay 2 -o "${output_file}" "${DAYI_SOURCE_URL}"
  fi

  actual_sha="$(sha256sum "${output_file}" | awk '{print $1}')"
  [[ ${actual_sha} == "${DAYI_SOURCE_SHA256}" ]] || \
    die "大易碼表 SHA-256 驗證失敗。預期 ${DAYI_SOURCE_SHA256}，實際 ${actual_sha}。"
}

build_rime_files() {
  local cin_file="$1"
  local dict_file="${WORK_DIR}/dayi4.dict.yaml"
  local schema_file="${WORK_DIR}/dayi4.schema.yaml"
  local entry_count

  {
    printf '%s\n' '# Rime dictionary' '# encoding: utf-8'
    printf '%s\n' '# Source: chinese-opendesktop/cin-tables dayi4.cin'
    printf '# Commit: %s\n' "${DAYI_SOURCE_COMMIT}"
    sed -n '1,5p' "${cin_file}"
    printf '%s\n' '---' 'name: dayi4' 'version: "1.0"' 'sort: by_weight' 'use_preset_vocabulary: false' '...'
    awk '
      BEGIN { in_table=0 }
      /^%chardef begin/ { in_table=1; next }
      /^%chardef end/ { in_table=0 }
      in_table && NF {
        if (NF % 2 != 0) {
          printf "Malformed CIN row at line %d\\n", NR > "/dev/stderr"
          exit 2
        }
        for (i=1; i+1<=NF; i+=2) {
          print $(i+1) "\t" $i
        }
      }
    ' "${cin_file}"
  } > "${dict_file}"

  entry_count="$(awk -F '\t' 'NF >= 2 {count++} END {print count+0}' "${dict_file}")"
  (( entry_count >= 18000 )) || die "轉換後只有 ${entry_count} 筆碼表資料，預期至少 18000 筆。"
  grep -Fqx $'的\t/.' "${dict_file}" || die "碼表缺少必要測試碼：/. → 的"
  grep -Fqx $'金\t0' "${dict_file}" || die "碼表缺少數字取碼測試：0 → 金"
  grep -Fqx $'竹\t/' "${dict_file}" || die "碼表缺少符號取碼測試：/ → 竹"

  cat > "${schema_file}" <<'YAML'
# Rime schema
# encoding: utf-8

schema:
  schema_id: dayi4
  name: 大易四碼
  version: "1.0"
  author:
    - DaYi / Rime community
  description: |
    大易輸入法四碼方案，使用 RIME 引擎。

switches:
  - name: ascii_mode
    reset: 0
    states: [ 中文, 西文 ]

engine:
  processors:
    - ascii_composer
    - speller
    - selector
    - navigator
    - express_editor
  segmentors:
    - ascii_segmentor
    - abc_segmentor
    - fallback_segmentor
  translators:
    - table_translator
  filters:
    - uniquifier

speller:
  alphabet: "abcdefghijklmnopqrstuvwxyz0123456789,./;"
  delimiter: " "
  max_code_length: 4

translator:
  dictionary: dayi4
  enable_sentence: false
  enable_user_dict: true
  db_class: tabledb
  preedit_format:
    - "xlit|,./0123456789;abcdefghijklmnopqrstuvwxyz|力點竹金言牛目四王門田米足虫人馬七日一土手鳥木月立女雨魚口耳石工革糸艸禾山水火心|"
  comment_format:
    - "xlit|,./0123456789;abcdefghijklmnopqrstuvwxyz|力點竹金言牛目四王門田米足虫人馬七日一土手鳥木月立女雨魚口耳石工革糸艸禾山水火心|"

menu:
  page_size: 5
  alternative_select_keys: "'[]-\\"
YAML

  log "已產生 ${entry_count} 筆 RIME 大易碼表。"
}

backup_user_config() {
  local backup_dir
  local copied=0
  local source_file

  mkdir -p "${BACKUP_ROOT}"
  backup_dir="$(mktemp -d "${BACKUP_ROOT}/${RUN_STAMP}.XXXXXX")"
  for source_file in \
    "${RIME_DIR}/dayi4.schema.yaml" \
    "${RIME_DIR}/dayi4.dict.yaml" \
    "${RIME_DIR}/default.custom.yaml" \
    "${FCITX_CONFIG_DIR}/profile"; do
    if [[ -f ${source_file} ]]; then
      cp -a "${source_file}" "${backup_dir}/$(basename "${source_file}")"
      copied=1
    fi
  done

  if (( copied == 1 )); then
    log "既有設定已備份到 ${backup_dir}"
  else
    rmdir "${backup_dir}"
  fi
}

ensure_fcitx_profile() {
  local profile_file="${FCITX_CONFIG_DIR}/profile"
  local highest_index
  local next_index

  mkdir -p "${FCITX_CONFIG_DIR}"

  if [[ ! -f ${profile_file} ]] || ! grep -q '^\[Groups/0\]$' "${profile_file}"; then
    cat > "${profile_file}" <<'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=rime
Layout=

[GroupOrder]
0=Default
PROFILE
    return
  fi

  if grep -q '^DefaultIM=' "${profile_file}"; then
    sed -i '0,/^DefaultIM=.*/s//DefaultIM=rime/' "${profile_file}"
  else
    sed -i '/^\[Groups\/0\]$/a DefaultIM=rime' "${profile_file}"
  fi

  if ! grep -q '^Name=rime$' "${profile_file}"; then
    highest_index="$(sed -n 's/^\[Groups\/0\/Items\/\([0-9][0-9]*\)\]$/\1/p' "${profile_file}" | sort -n | tail -1)"
    next_index=$(( ${highest_index:-0} + 1 ))
    printf '\n[Groups/0/Items/%d]\nName=rime\nLayout=\n' "${next_index}" >> "${profile_file}"
  fi
}

configure_rime() {
  mkdir -p "${RIME_DIR}"
  cp "${WORK_DIR}/dayi4.schema.yaml" "${RIME_DIR}/dayi4.schema.yaml"
  cp "${WORK_DIR}/dayi4.dict.yaml" "${RIME_DIR}/dayi4.dict.yaml"

  (
    cd "${RIME_DIR}"
    rime_deployer --add-schema dayi4
  )

  rime_deployer --build "${RIME_DIR}" /usr/share/rime-data "${RIME_DIR}/build"

  [[ -f ${RIME_DIR}/build/dayi4.prism.bin ]] || die "RIME 未產生 dayi4.prism.bin。"
  [[ -f ${RIME_DIR}/build/dayi4.table.bin ]] || die "RIME 未產生 dayi4.table.bin。"
  ! grep -q 'accept: period' "${RIME_DIR}/build/dayi4.schema.yaml" || \
    die "部署結果仍含有句號翻頁快捷鍵，/. 將無法正常取碼。"
}

configure_desktop() {
  if [[ ${DAYI_SKIP_IM_CONFIG:-0} != 1 ]]; then
    im-config -n fcitx5
  fi

  mkdir -p "${AUTOSTART_DIR}"
  if [[ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]]; then
    cp /usr/share/applications/org.fcitx.Fcitx5.desktop "${AUTOSTART_DIR}/fcitx5.desktop"
  else
    cat > "${AUTOSTART_DIR}/fcitx5.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Fcitx 5
Comment=Start Input Method
Exec=/usr/bin/fcitx5
Icon=fcitx
Terminal=false
Type=Application
StartupNotify=false
DESKTOP
  fi
}

stop_fcitx() {
  [[ ${DAYI_SKIP_RESTART:-0} == 1 ]] && return

  fcitx5-remote -e >/dev/null 2>&1 || true
  pkill -u "$(id -u)" -x fcitx5 >/dev/null 2>&1 || true
  # Fcitx5 writes its profile when exiting; finish that before editing it.
  for attempt in {1..50}; do
    pgrep -u "$(id -u)" -x fcitx5 >/dev/null || return 0
    sleep 0.1
  done
  die "Fcitx5 尚未停止，為避免設定被覆寫，請結束 Fcitx5 後重試。"
}

restart_fcitx() {
  [[ ${DAYI_SKIP_RESTART:-0} == 1 ]] && return

  if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
    nohup /usr/bin/fcitx5 -d > /tmp/fcitx5-dayi-install.log 2>&1 &
    sleep 2
  fi
}

main() {
  if [[ ${DAYI_SKIP_PACKAGES:-0} != 1 ]]; then
    install_packages
  fi

  command -v rime_deployer >/dev/null 2>&1 || die "找不到 rime_deployer；請確認 fcitx5-rime 已安裝。"
  command -v sha256sum >/dev/null 2>&1 || die "找不到 sha256sum。"

  download_dayi_table "${WORK_DIR}/dayi4.cin"
  build_rime_files "${WORK_DIR}/dayi4.cin"
  stop_fcitx
  backup_user_config
  ensure_fcitx_profile
  configure_rime
  configure_desktop
  restart_fcitx

  log "安裝完成。請登出再登入，然後用 Ctrl+Space 切換至 RIME 大易四碼。"
  log "驗證方式：輸入 /. 再按 Space，應輸出「的」。"
}

main "$@"
