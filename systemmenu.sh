#!/usr/bin/env bash
# systemmenu.sh — BIOS-style system command launcher
# Config: config.conf in the same directory as this script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.conf}"

# ─── Award BIOS Color Scheme ──────────────────────────────────────────────────
export NEWT_COLORS='
root=white,blue
border=white,blue
title=yellow,blue
roottext=cyan,blue
window=white,blue
textbox=white,blue
button=black,cyan
actbutton=yellow,blue
compactbutton=white,blue
listbox=white,blue
actlistbox=black,cyan
sellistbox=yellow,blue
actsellistbox=black,cyan
checkbox=white,blue
actcheckbox=black,cyan
entry=black,cyan
disentry=white,blue
label=cyan,blue
emptyscale=white,blue
fullscale=cyan,blue
helpline=black,cyan
'

# ─── Config Parser ────────────────────────────────────────────────────────────
declare -a GROUP_NAMES=()
declare -A GROUP_ACTION_LABELS=()   # group -> newline-separated labels
declare -A GROUP_ACTION_COMMANDS=() # group -> newline-separated commands

parse_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        whiptail --title "Error" --msgbox "Config file not found:\n$CONFIG_FILE" 10 60
        exit 1
    fi

    local current_group=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip blank lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == GROUP=* ]]; then
            current_group="${line#GROUP=}"
            GROUP_NAMES+=("$current_group")
            GROUP_ACTION_LABELS["$current_group"]=""
            GROUP_ACTION_COMMANDS["$current_group"]=""

        elif [[ "$line" == ACTION=* && -n "$current_group" ]]; then
            local rest="${line#ACTION=}"
            local label="${rest%%|*}"
            local cmd="${rest#*|}"

            if [[ -n "${GROUP_ACTION_LABELS[$current_group]}" ]]; then
                GROUP_ACTION_LABELS["$current_group"]+=$'\n'"$label"
                GROUP_ACTION_COMMANDS["$current_group"]+=$'\n'"$cmd"
            else
                GROUP_ACTION_LABELS["$current_group"]="$label"
                GROUP_ACTION_COMMANDS["$current_group"]="$cmd"
            fi
        fi
    done < "$CONFIG_FILE"
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
# Get terminal size
get_term_size() {
    TERM_LINES=$(tput lines 2>/dev/null || echo 24)
    TERM_COLS=$(tput cols  2>/dev/null || echo 80)
}

# Build a whiptail menu array from newline-separated labels
# Usage: build_menu_args labels_string
build_menu_args() {
    local labels="$1"
    local -a args=()
    local i=1
    while IFS= read -r label; do
        args+=("$i" "$label")
        ((i++))
    done <<< "$labels"
    printf '%s\0' "${args[@]}"
}

# Get Nth line (1-indexed) from a newline-separated string
get_nth_line() {
    local str="$1"
    local n="$2"
    sed -n "${n}p" <<< "$str"
}

# ─── CP437 / Unicode box-drawing characters ───────────────────────────────────
# Double-line frame (used for outer box borders)
BX_TL='╔'   # 201  top-left corner
BX_TR='╗'   # 187  top-right corner
BX_BL='╚'   # 200  bottom-left corner
BX_BR='╝'   # 188  bottom-right corner
BX_H='═'    # 205  horizontal
BX_V='║'    # 186  vertical
BX_ML='╠'   # 204  left T-junction (middle-left)
BX_MR='╣'   # 185  right T-junction (middle-right)
BX_MT='╦'   # 203  top T-junction
BX_MB='╩'   # 202  bottom T-junction
BX_X='╬'    # 206  cross junction
# Single-line (used for inner rails and separators)
BX_SH='─'   # 196  single horizontal
BX_SV='│'   # 179  single vertical
BX_SR='┤'   # 180  single right T
BX_SL='├'   # 195  single left T
# Shade blocks (for backgrounds / accents)
BX_LT='░'   # 176  light shade
BX_MD='▒'   # 177  medium shade
BX_DK='▓'   # 178  dark shade

# ─── Draw horizontal border lines ─────────────────────────────────────────────
make_hbar()  { printf "${BX_H}%.0s"  $(seq 1 $(( TERM_COLS - 2 ))); }
make_sbar()  { printf "${BX_SH}%.0s" $(seq 1 $(( TERM_COLS - 2 ))); }

# ─── Run a command ────────────────────────────────────────────────────────────
run_command() {
    local label="$1"
    local cmd="$2"
    local group="${3:-}"

    # Redraw terminal size on resize
    trap 'get_term_size' SIGWINCH
    get_term_size

    local hbar; hbar=$(make_hbar)
    local breadcrumb="${group:+$group  >>  }$label"

    # ── Full-screen blue background ──────────────────────────────────────────
    printf '\e[44m'; clear

    # ── Header box ───────────────────────────────────────────────────────────
    printf "\e[44;37m${BX_TL}%s${BX_TR}\e[0m\n" "$hbar"
    printf "\e[44;93;1m${BX_V}  %-*s${BX_V}\e[0m\n" $(( TERM_COLS - 4 )) "SYSTEM MENU  v1.0"
    printf "\e[44;37m${BX_ML}%s${BX_MR}\e[0m\n" "$(make_sbar)"
    printf "\e[44;97m${BX_V}  %-*s${BX_V}\e[0m\n"   $(( TERM_COLS - 4 )) "$breadcrumb"
    printf "\e[44;36m${BX_V}  \$ %-*s${BX_V}\e[0m\n" $(( TERM_COLS - 6 )) "$cmd"
    printf "\e[44;37m${BX_ML}%s${BX_MR}\e[0m\n" "$hbar"
    echo ""

    # ── Stream output with chat-style left rail ───────────────────────────────
    # Strip background colors (40-49, 100-107) and reverse video (7, 27) from
    # command output, then re-inject \e[44m (blue bg) after every SGR sequence
    # so the blue background is never overridden by the command's own colors.
    local exit_file; exit_file=$(mktemp)
    bash -c "$cmd; echo \$? > '$exit_file'" 2>&1 | \
        perl -pe 's#\e\[([0-9;]*)m#my @c=grep{length&&$_!~m{^(7|27|4[0-9]|10[0-7])$}}split(";",$1//"0");"\e[".(@c?join(";",@c):"0")."m\e[44m"#ge' | \
        while IFS= read -r line; do
            printf "\e[44;34m  ${BX_SV} \e[0m\e[44;97m%s\e[0m\e[44m\e[K\n" "$line"
        done
    local exit_code; exit_code=$(cat "$exit_file" 2>/dev/null || echo 1)
    rm -f "$exit_file"

    echo ""

    # ── Footer box (uses size at time of drawing — handles resize) ────────────
    get_term_size
    hbar=$(make_hbar)
    local status_text
    printf "\e[44;37m${BX_ML}%s${BX_MR}\e[0m\n" "$hbar"
    if [[ $exit_code -eq 0 ]]; then
        status_text="[OK]  Exit code: 0"
        printf "\e[44;92m${BX_V}  %-*s${BX_V}\e[0m\n" $(( TERM_COLS - 4 )) "$status_text"
    else
        status_text="[!!]  Exit code: $exit_code  ERROR"
        printf "\e[44;91m${BX_V}  %-*s${BX_V}\e[0m\n" $(( TERM_COLS - 4 )) "$status_text"
    fi
    printf "\e[44;37m${BX_ML}%s${BX_MR}\e[0m\n" "$(make_sbar)"
    printf "\e[44;36m${BX_V}  %-*s${BX_V}\e[0m\n" $(( TERM_COLS - 4 )) "Press any key to return to menu..."
    printf "\e[44;37m${BX_BL}%s${BX_BR}\e[0m\n" "$hbar"

    read -n 1 -s
    trap - SIGWINCH
    tput sgr0; echo ""
}

# ─── Group Commands Menu ──────────────────────────────────────────────────────
show_group_menu() {
    local group="$1"
    local labels="${GROUP_ACTION_LABELS[$group]}"
    local commands="${GROUP_ACTION_COMMANDS[$group]}"

    while true; do
        get_term_size
        local menu_height=$(( TERM_LINES - 8 ))
        local box_height=$(( TERM_LINES - 4 ))

        # Build menu items — label on left, [command] on right (BIOS style)
        local -a items=()
        local i=1
        local max_label=0
        while IFS= read -r label; do
            (( ${#label} > max_label )) && max_label=${#label}
            ((i++))
        done <<< "$labels"
        i=1
        local col_width=$(( TERM_COLS - max_label - 14 ))
        while IFS= read -r label; do
            local cmd_display
            cmd_display=$(get_nth_line "$commands" "$i")
            (( ${#cmd_display} > col_width )) && cmd_display="${cmd_display:0:$col_width}.."
            items+=("$i" "$(printf '%-*s  [%s]' "$max_label" "$label" "$cmd_display")")
            ((i++))
        done <<< "$labels"

        local choice
        choice=$(whiptail \
            --title " $group " \
            --backtitle "SYSTEM MENU  v1.0   ──   $(basename "$CONFIG_FILE")   ──   \xe2\x86\x91\xe2\x86\x93:Move  ENTER:Select  ESC:Back" \
            --menu "  Select an action:" \
            "$box_height" "$(( TERM_COLS - 4 ))" "$menu_height" \
            "${items[@]}" \
            3>&1 1>&2 2>&3)

        local status=$?
        [[ $status -ne 0 ]] && return  # ESC or Cancel = back

        local selected_label
        local selected_cmd
        selected_label=$(get_nth_line "$labels" "$choice")
        selected_cmd=$(get_nth_line "$commands" "$choice")

        run_command "$selected_label" "$selected_cmd" "$group"
    done
}

# ─── Main Menu ────────────────────────────────────────────────────────────────
show_main_menu() {
    while true; do
        get_term_size
        local menu_height=$(( TERM_LINES - 8 ))
        local box_height=$(( TERM_LINES - 4 ))

        local -a items=()
        for group in "${GROUP_NAMES[@]}"; do
            local count
            count=$(echo "${GROUP_ACTION_LABELS[$group]}" | grep -c .)
            items+=("$group" "[${count} actions]")
        done

        local choice
        choice=$(whiptail \
            --title " SYSTEM MENU  v1.0 " \
            --backtitle "SYSTEM MENU  v1.0   ──   $(basename "$CONFIG_FILE")   ──   \xe2\x86\x91\xe2\x86\x93:Move  ENTER:Select  ESC:Exit" \
            --menu "  Select a group:" \
            "$box_height" "$(( TERM_COLS - 4 ))" "$menu_height" \
            "${items[@]}" \
            3>&1 1>&2 2>&3)

        local status=$?
        if [[ $status -ne 0 ]]; then
            whiptail --title " SYSTEM MENU " --yesno "Exit System Menu?" 7 40
            [[ $? -eq 0 ]] && break
        else
            show_group_menu "$choice"
        fi
    done
}

# ─── Sudo Pre-Authentication ──────────────────────────────────────────────────
sudo_preauth() {
    # Already authenticated? Nothing to do.
    if sudo -n true 2>/dev/null; then
        return 0
    fi

    local password
    local attempts=0

    while true; do
        local msg="Some commands require administrator access.\n\nEnter your sudo password to authenticate now,\nor Cancel to skip (sudo commands may prompt later)."
        [[ $attempts -gt 0 ]] && msg="Incorrect password. Try again.\n\n$msg"

        password=$(whiptail \
            --title " SYSTEM MENU — Authentication " \
            --passwordbox "$msg" \
            12 58 \
            3>&1 1>&2 2>&3)

        local status=$?
        # User pressed Cancel/Esc — skip pre-auth
        [[ $status -ne 0 ]] && return 1

        if echo "$password" | sudo -S -v 2>/dev/null; then
            # Keep sudo alive in the background while menu is open
            ( while true; do sudo -n true; sleep 50; done ) &
            SUDO_KEEPALIVE_PID=$!
            return 0
        fi

        (( attempts++ ))
    done
}

cleanup() {
    [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}

# ─── Entry Point ──────────────────────────────────────────────────────────────
main() {
    if ! command -v whiptail &>/dev/null; then
        echo "Error: 'whiptail' is not installed."
        echo "Install it with: sudo apt install whiptail"
        exit 1
    fi

    trap cleanup EXIT

    parse_config
    sudo_preauth
    show_main_menu
    clear
    echo "System Menu closed."
}

main "$@"
