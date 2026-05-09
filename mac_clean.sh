#!/usr/bin/env bash
# ============================================================
#  mac_clean.sh — Interactive Mac Disk Scanner & Cleaner
#  Works on any macOS machine. No external dependencies.
# ============================================================

set -uo pipefail

# ── Colors ──────────────────────────────────────────────────
RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'
BLU=$'\033[0;34m'; CYN=$'\033[0;36m'; MAG=$'\033[0;35m'
WHT=$'\033[1;37m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; NC=$'\033[0m'

# ── Globals ──────────────────────────────────────────────────
DRY_RUN=true
HOME_DIR="$HOME"
declare -a CMDS=()        # cleanup command strings
declare -a CMD_LABELS=()  # labels
declare -a CMD_SIZES=()   # size estimates
declare -a CMD_RISKS=()   # LOW / MED / HIGH

# ── Helpers ──────────────────────────────────────────────────
hr()  { printf "${DIM}%s${NC}\n" "$(printf '─%.0s' {1..70})"; }
hdr() { echo; printf "${BOLD}${BLU}  ◆ %s${NC}\n" "$*"; hr; }
info(){ printf "  ${CYN}ℹ${NC}  %s\n" "$*"; }
warn(){ printf "  ${YEL}⚠${NC}  %s\n" "$*"; }
ok()  { printf "  ${GRN}✔${NC}  %s\n" "$*"; }
err() { printf "  ${RED}✖${NC}  %s\n" "$*"; }

# Returns human-readable size of a path (0B if missing)
dir_size() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sh "$path" 2>/dev/null | cut -f1
  else
    echo "0B"
  fi
}

# Converts du output (e.g. "1.5G") to MB for rough comparison
to_mb() {
  local s="$1"
  local num unit
  num=$(echo "$s" | sed 's/[BKMG]//g')
  unit=$(echo "$s" | sed 's/[0-9.]//g')
  case "$unit" in
    G) echo "$num * 1024" | bc | cut -d. -f1 ;;
    M) echo "$num" | cut -d. -f1 ;;
    K) echo "1" ;;
    *) echo "0" ;;
  esac
}

register_cmd() {
  # register_cmd "LABEL" "SIZE_EST" "RISK" "COMMAND..."
  CMD_LABELS+=("$1"); CMD_SIZES+=("$2"); CMD_RISKS+=("$3")
  CMDS+=("$4")
}

spinner() {
  local pid=$1 msg=$2 spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYN}%s${NC} %s " "${spin:$((i%10)):1}" "$msg"
    sleep 0.1; ((i++)) || true
  done
  printf "\r%-60s\r" " "
}

# ── Banner ───────────────────────────────────────────────────
print_banner() {
  clear
  echo
  printf "${BOLD}${MAG}"
  cat <<'EOF'
  ╔══════════════════════════════════════════════════════════╗
  ║          🍎  Mac Disk Scanner & Cleaner                  ║
  ║          Works on any macOS · No dependencies            ║
  ╚══════════════════════════════════════════════════════════╝
EOF
  printf "${NC}\n"
}

# ── 1. Disk Overview ─────────────────────────────────────────
scan_disk_overview() {
  hdr "Disk Overview"
  local line total used avail pct
  line=$(df -h / | tail -1)
  total=$(echo "$line" | awk '{print $2}')
  used=$(echo "$line"  | awk '{print $3}')
  avail=$(echo "$line" | awk '{print $4}')
  pct=$(echo "$line"   | awk '{print $5}')

  printf "  %-18s ${WHT}%s${NC}\n" "Total:"     "$total"
  printf "  %-18s ${RED}%s${NC}\n" "Used:"      "$used ($pct)"
  printf "  %-18s ${GRN}%s${NC}\n" "Available:" "$avail"
  echo

  # Usage bar
  local pct_num=${pct//%/}
  local filled=$(( pct_num * 40 / 100 ))
  local empty=$(( 40 - filled ))
  local color=$GRN
  [[ $pct_num -ge 70 ]] && color=$YEL
  [[ $pct_num -ge 85 ]] && color=$RED
  printf "  [${color}%s${NC}%s] %s\n\n" \
    "$(printf '█%.0s' $(seq 1 $filled))" \
    "$(printf '░%.0s' $(seq 1 $empty))" \
    "$pct"
}

# ── 2. Top Home Dirs ─────────────────────────────────────────
scan_home_top() {
  hdr "Top Directories in Home (~)"
  printf "  ${DIM}Scanning... (this may take a moment)${NC}\n"
  local out
  out=$(du -sh "$HOME_DIR"/*/ 2>/dev/null | sort -rh | head -15 || true)
  if [[ -z "$out" ]]; then
    info "No directories found."
    echo; return
  fi
  while IFS=$'\t' read -r size path; do
    [[ -z "$size" || -z "$path" ]] && continue
    local name="${path/#$HOME_DIR\//~/}"
    local color=$GRN
    local mb; mb=$(to_mb "$size" || echo 0)
    [[ "$mb" -ge 1024  ]] 2>/dev/null && color=$YEL || true
    [[ "$mb" -ge 5120  ]] 2>/dev/null && color=$RED || true
    printf "  ${color}%-8s${NC}  %s\n" "$size" "$name"
  done <<< "$out"
  echo
}

# ── 3. Library Breakdown ─────────────────────────────────────
scan_library() {
  hdr "~/Library Breakdown"
  local lib="$HOME_DIR/Library"
  local dirs=("Caches" "Application Support" "Containers" "Logs" "Group Containers")
  for d in "${dirs[@]}"; do
    local p="$lib/$d"
    local sz; sz=$(dir_size "$p")
    local mb; mb=$(to_mb "$sz" || echo 0)
    local color=$GRN
    [[ "$mb" -ge 512  ]] 2>/dev/null && color=$YEL || true
    [[ "$mb" -ge 2048 ]] 2>/dev/null && color=$RED || true
    printf "  ${color}%-10s${NC}  %s\n" "$sz" "Library/$d"
  done
  echo

  # Caches top 10
  printf "  ${DIM}Top caches:${NC}\n"
  local cache_out; cache_out=$(du -sh "$lib/Caches"/*/ 2>/dev/null | sort -rh | head -10 || true)
  while IFS=$'\t' read -r sz path; do
    [[ -z "$sz" ]] && continue
    printf "    ${YEL}%-8s${NC}  %s\n" "$sz" "$(basename "$path")"
  done <<< "$cache_out"
  echo

  # App Support top 10
  printf "  ${DIM}Top Application Support:${NC}\n"
  local appsupp_out; appsupp_out=$(du -sh "$lib/Application Support"/*/ 2>/dev/null | sort -rh | head -10 || true)
  while IFS=$'\t' read -r sz path; do
    [[ -z "$sz" ]] && continue
    printf "    ${YEL}%-8s${NC}  %s\n" "$sz" "$(basename "$path")"
  done <<< "$appsupp_out"
  echo
}

# ── 4. Developer Junk ────────────────────────────────────────
scan_dev() {
  hdr "Developer Space"

  # node_modules
  printf "  ${DIM}Searching for node_modules (depth ≤4)...${NC}\r"
  local nm_total="0"
  local nm_dirs=()
  while IFS= read -r d; do
    nm_dirs+=("$d")
    local s; s=$(to_mb "$(dir_size "$d")" || echo 0)
    nm_total=$(( nm_total + s )) || true
  done < <(find "$HOME_DIR" -maxdepth 4 -name "node_modules" -type d 2>/dev/null | head -20 || true)
  printf "%-70s\r" " "
  printf "  node_modules found: ${YEL}%d dirs${NC}, ~${RED}%d MB${NC}\n" "${#nm_dirs[@]}" "$nm_total"
  for d in "${nm_dirs[@]:0:5}"; do
    printf "    ${DIM}%s${NC}\n" "${d/#$HOME_DIR/~}"
  done
  [[ ${#nm_dirs[@]} -gt 5 ]] && printf "    ${DIM}... and %d more${NC}\n" "$(( ${#nm_dirs[@]} - 5 ))" || true

  # .git repos
  printf "\n  ${DIM}Git repos (depth ≤5)...${NC}\r"
  local git_count
  git_count=$(find "$HOME_DIR" -maxdepth 5 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')
  printf "%-70s\r" " "
  printf "  Git repos: ${CYN}%s${NC}\n" "$git_count"

  # Go cache
  local go_cache="$HOME_DIR/Library/Caches/go-build"
  local go_sz; go_sz=$(dir_size "$go_cache")
  printf "  Go build cache:  ${YEL}%s${NC}\n" "$go_sz"

  # go mod cache
  local go_mod="$HOME_DIR/go/pkg/mod"
  local gomod_sz; gomod_sz=$(dir_size "$go_mod")
  printf "  Go module cache: ${YEL}%s${NC}\n" "$gomod_sz"

  # pip cache
  local pip_cache="$HOME_DIR/Library/Caches/pip"
  local pip_sz; pip_sz=$(dir_size "$pip_cache")
  printf "  pip cache:       ${YEL}%s${NC}\n" "$pip_sz"

  # Homebrew
  if command -v brew &>/dev/null; then
    local brew_cache; brew_cache=$(brew --cache 2>/dev/null || echo "$HOME_DIR/Library/Caches/Homebrew")
    local brew_sz; brew_sz=$(dir_size "$brew_cache")
    printf "  Homebrew cache:  ${YEL}%s${NC}\n" "$brew_sz"
  fi
  echo
}

# ── 5. Docker ────────────────────────────────────────────────
scan_docker() {
  hdr "Docker"
  if ! command -v docker &>/dev/null; then
    info "Docker not installed — skipping."
    echo; return
  fi
  if ! docker info &>/dev/null 2>&1; then
    warn "Docker installed but not running — skipping."
    echo; return
  fi
  docker system df 2>/dev/null | while IFS= read -r line; do
    printf "  %s\n" "$line"
  done
  echo
}

# ── 6. Large Files ───────────────────────────────────────────
scan_large_files() {
  hdr "Largest Files in Home (~)"
  printf "  ${DIM}Searching (depth ≤6, files > 100 MB)...${NC}\r"
  local results
  results=$(find "$HOME_DIR" -maxdepth 6 -type f -size +100M 2>/dev/null \
    ! -path "*/Library/Containers/com.docker.docker/*" \
    ! -path "*/.Trash/*" \
    | xargs du -sh 2>/dev/null | sort -rh | head -15 || true)
  printf "%-70s\r" " "
  if [[ -z "$results" ]]; then
    ok "No files > 100 MB found outside Docker."
  else
    while IFS=$'\t' read -r sz path; do
      [[ -z "$sz" ]] && continue
      printf "  ${RED}%-10s${NC}  %s\n" "$sz" "${path/#$HOME_DIR/~}"
    done <<< "$results"
  fi
  echo
}

# ── 7. Downloads ─────────────────────────────────────────────
scan_downloads() {
  hdr "Downloads Folder"
  local dl="$HOME_DIR/Downloads"
  local total; total=$(dir_size "$dl")
  printf "  Total: ${YEL}%s${NC}\n\n" "$total"
  local dl_out; dl_out=$(du -sh "$dl"/* 2>/dev/null | sort -rh | head -20 || true)
  while IFS=$'\t' read -r sz path; do
    [[ -z "$sz" ]] && continue
    local color=$GRN
    local mb; mb=$(to_mb "$sz" || echo 0)
    [[ "$mb" -ge 50  ]] 2>/dev/null && color=$YEL || true
    [[ "$mb" -ge 200 ]] 2>/dev/null && color=$RED || true
    printf "  ${color}%-10s${NC}  %s\n" "$sz" "$(basename "$path")"
  done <<< "$dl_out"
  echo
}

# ── 8. Trash ─────────────────────────────────────────────────
scan_trash() {
  hdr "Trash"
  local trash="$HOME_DIR/.Trash"
  local sz; sz=$(dir_size "$trash")
  printf "  Trash size: ${YEL}%s${NC}\n" "$sz"
  local count; count=$(find "$trash" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  printf "  Items:      %s\n\n" "$(( count - 1 ))"
}

# ── Build Cleanup Menu ────────────────────────────────────────
build_cleanup_menu() {
  local lib="$HOME_DIR/Library"

  # Caches (safe)
  local cache_sz; cache_sz=$(dir_size "$lib/Caches")
  register_cmd \
    "Clear ALL ~/Library/Caches" \
    "$cache_sz" "LOW" \
    "rm -rf '$lib/Caches'/* && echo 'Caches cleared'"

  # Homebrew
  if command -v brew &>/dev/null; then
    local brew_cache; brew_cache=$(brew --cache 2>/dev/null || echo "$lib/Caches/Homebrew")
    local bsz; bsz=$(dir_size "$brew_cache")
    register_cmd \
      "Homebrew cleanup (--prune=all)" \
      "$bsz" "LOW" \
      "brew cleanup --prune=all -s"
  fi

  # Go build cache
  local go_sz; go_sz=$(dir_size "$lib/Caches/go-build")
  register_cmd \
    "Go build cache (go clean -cache)" \
    "$go_sz" "LOW" \
    "go clean -cache 2>/dev/null && echo 'Go cache cleared' || echo 'go not installed'"

  # Go module cache
  local gomod_sz; gomod_sz=$(dir_size "$HOME_DIR/go/pkg/mod")
  register_cmd \
    "Go module cache (go clean -modcache)" \
    "$gomod_sz" "MED" \
    "go clean -modcache 2>/dev/null && echo 'Go mod cache cleared' || echo 'go not installed'"

  # pip cache
  local pip_sz; pip_sz=$(dir_size "$lib/Caches/pip")
  register_cmd \
    "pip cache purge" \
    "$pip_sz" "LOW" \
    "pip cache purge 2>/dev/null && echo 'pip cache cleared' || echo 'pip not installed'"

  # Logs
  local log_sz; log_sz=$(dir_size "$lib/Logs")
  register_cmd \
    "Clear ~/Library/Logs" \
    "$log_sz" "LOW" \
    "rm -rf '$lib/Logs'/* && echo 'Logs cleared'"

  # Trash
  local trash_sz; trash_sz=$(dir_size "$HOME_DIR/.Trash")
  register_cmd \
    "Empty Trash" \
    "$trash_sz" "LOW" \
    "osascript -e 'tell application \"Finder\" to empty trash' && echo 'Trash emptied'"

  # Docker
  if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    register_cmd \
      "Docker: prune stopped containers + dangling images + networks" \
      "varies" "LOW" \
      "docker system prune -f"
    register_cmd \
      "Docker: remove ALL unused images (not just dangling)" \
      "varies" "MED" \
      "docker image prune -a -f"
    register_cmd \
      "Docker: remove unused volumes" \
      "varies" "HIGH" \
      "docker volume prune -f"
    register_cmd \
      "Docker: remove ALL build cache" \
      "varies" "LOW" \
      "docker builder prune -a -f"
  fi

  # npm/node_modules
  register_cmd \
    "Remove node_modules in ~/ws (depth ≤4)" \
    "varies" "HIGH" \
    "find '$HOME_DIR/ws' -maxdepth 4 -name 'node_modules' -type d -exec rm -rf {} + 2>/dev/null; echo 'Done'"

  # Xcode derived data (if exists)
  local xcode_dd="$lib/Developer/Xcode/DerivedData"
  if [[ -d "$xcode_dd" ]]; then
    local xd_sz; xd_sz=$(dir_size "$xcode_dd")
    register_cmd \
      "Xcode DerivedData" \
      "$xd_sz" "LOW" \
      "rm -rf '$xcode_dd' && echo 'Xcode DerivedData cleared'"
  fi

  # iOS device support
  local ios_ds="$lib/Developer/Xcode/iOS DeviceSupport"
  if [[ -d "$ios_ds" ]]; then
    local ios_sz; ios_sz=$(dir_size "$ios_ds")
    register_cmd \
      "Xcode iOS DeviceSupport (old SDKs)" \
      "$ios_sz" "MED" \
      "rm -rf '$ios_ds'/* && echo 'iOS DeviceSupport cleared'"
  fi
}

# ── Cleanup Menu ─────────────────────────────────────────────
show_cleanup_menu() {
  while true; do
    local mode_label
    if [[ "$DRY_RUN" == true ]]; then
      mode_label="${YEL}[DRY-RUN — preview only, nothing executed]${NC}"
    else
      mode_label="${RED}[LIVE MODE — commands WILL run]${NC}"
    fi
    hdr "Cleanup Menu  ${mode_label}"
    printf "  ${DIM}%-4s  %-44s  %-8s  %-5s${NC}\n" "ID" "Action" "Est.Size" "Risk"
    hr
    local i=0
    for label in "${CMD_LABELS[@]}"; do
      local sz="${CMD_SIZES[$i]}"
      local risk="${CMD_RISKS[$i]}"
      local risk_color=$GRN
      [[ "$risk" == "MED"  ]] && risk_color=$YEL
      [[ "$risk" == "HIGH" ]] && risk_color=$RED
      printf "  ${WHT}[%2d]${NC}  %-44s  ${YEL}%-8s${NC}  ${risk_color}%s${NC}\n" \
        "$((i+1))" "$label" "$sz" "$risk"
      ((i++)) || true
    done
    echo
    printf "  ${WHT}[a]${NC}  Run ALL low-risk items (risk=LOW only)\n"
    printf "  ${WHT}[t]${NC}  Toggle DRY-RUN / LIVE mode  ${DIM}(current: %s)${NC}\n" \
      "$( [[ "$DRY_RUN" == true ]] && echo 'DRY-RUN' || echo 'LIVE' )"
    printf "  ${WHT}[q]${NC}  Quit\n"
    echo
    read -rp "$(printf "  ${BOLD}Enter choice:${NC} ")" choice

    case "$choice" in
      q|Q) echo; ok "Bye!"; echo; exit 0 ;;
      t|T)
        if [[ "$DRY_RUN" == true ]]; then
          echo
          warn "You are switching to LIVE mode. Commands will ACTUALLY run."
          read -rp "  Type 'yes' to confirm: " confirm
          [[ "$confirm" == "yes" ]] && DRY_RUN=false && ok "Live mode enabled." || info "Keeping dry-run."
        else
          DRY_RUN=true; ok "Back to dry-run mode."
        fi
        sleep 1
        ;;
      a|A)
        echo
        local ran=0
        local i=0
        for risk in "${CMD_RISKS[@]}"; do
          if [[ "$risk" == "LOW" ]]; then
            run_cleanup_item "$i"
            ((ran++)) || true
          fi
          ((i++)) || true
        done
        ok "Ran $ran LOW-risk items."
        read -rp "  Press Enter to continue..."
        ;;
      ''|*[!0-9]*)
        warn "Invalid input."
        sleep 1
        ;;
      *)
        local idx=$(( choice - 1 ))
        if [[ $idx -ge 0 && $idx -lt ${#CMDS[@]} ]]; then
          run_cleanup_item "$idx"
          read -rp "  Press Enter to continue..."
        else
          warn "Number out of range."
          sleep 1
        fi
        ;;
    esac
  done
}

run_cleanup_item() {
  local idx="$1"
  local label="${CMD_LABELS[$idx]}"
  local cmd="${CMDS[$idx]}"
  local risk="${CMD_RISKS[$idx]}"
  echo
  printf "  ${BOLD}Action:${NC} %s\n" "$label"
  printf "  ${BOLD}Risk:${NC}   %s\n" "$risk"
  printf "  ${BOLD}Command:${NC}\n"
  printf "    ${DIM}%s${NC}\n" "$cmd"
  echo
  if [[ "$DRY_RUN" == true ]]; then
    info "DRY-RUN: Command NOT executed. Toggle to LIVE mode to run."
  else
    if [[ "$risk" == "HIGH" ]]; then
      warn "HIGH risk action! Type 'yes' to confirm."
      read -rp "  Confirm: " confirm
      [[ "$confirm" != "yes" ]] && info "Skipped." && return
    fi
    printf "  ${GRN}Running...${NC}\n"
    eval "$cmd" 2>&1 | while IFS= read -r line; do
      printf "    %s\n" "$line"
    done
    ok "Done."
  fi
}

# ── Main ─────────────────────────────────────────────────────
main() {
  print_banner

  # Arg parsing
  for arg in "$@"; do
    case "$arg" in
      --live) DRY_RUN=false ;;
      --help|-h)
        printf "Usage: %s [--live]\n" "$(basename "$0")"
        printf "  --live   Execute cleanup commands (default: dry-run / preview)\n"
        exit 0 ;;
    esac
  done

  [[ "$DRY_RUN" == true ]] && \
    printf "  ${YEL}Mode: DRY-RUN${NC} (safe preview). Use ${BOLD}--live${NC} to actually execute, or toggle in the menu.\n\n"

  printf "  ${DIM}Running scan... please wait.${NC}\n"
  sleep 0.3

  scan_disk_overview
  scan_home_top
  scan_library
  scan_dev
  scan_docker
  scan_large_files
  scan_downloads
  scan_trash

  build_cleanup_menu
  show_cleanup_menu
}

main "$@"
