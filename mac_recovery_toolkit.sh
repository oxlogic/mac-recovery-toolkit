#!/bin/bash
# ==============================================================================
# OxLogic Mac Recovery Toolkit (MRTK) v1.0.0
# Lead Developer: Md Tazmir (@mdtazmir1 | https://www.facebook.com/muhammadtazmir) | OxLogic Team
# Official Repository: https://github.com/oxlogic/mac-recovery-toolkit
# Hybrid Architecture: Native AppleScript GUI Frontend + Powerful CLI Backend
# Supports Intel (x86_64) & Apple Silicon (ARM64) in Recovery, Live & Single-User
# License: MIT License (Free for Technicians, Attribution Required)
# ==============================================================================

# Ensure standard Unix paths are loaded in Recovery Mode
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# ANSI Colors & Formatting for CLI Mode
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

FORCE_CLI=0

safe_clear() {
    if /usr/bin/clear >/dev/null 2>&1; then
        :
    else
        printf "\033[2J\033[H"
    fi
}

pause() {
    echo ""
    read -rp "Press [Enter] to continue..."
}

# ------------------------------------------------------------------------------
# System & Hardware Detection Engine
# ------------------------------------------------------------------------------
detect_system_info() {
    ARCH=$(uname -m 2>/dev/null || /usr/bin/uname -m 2>/dev/null || sysctl -n hw.machine 2>/dev/null || /usr/sbin/sysctl -n hw.machine 2>/dev/null || echo "x86_64")
    if [ "$ARCH" = "arm64" ]; then
        CHIP_TYPE="Apple Silicon (${BOLD}ARM64${NC})"
        CHIP_PLAIN="Apple Silicon (ARM64)"
        IS_M_SERIES=true
    elif [ "$ARCH" = "x86_64" ]; then
        CHIP_TYPE="Intel (${BOLD}x86_64${NC})"
        CHIP_PLAIN="Intel (x86_64)"
        IS_M_SERIES=false
    else
        CHIP_TYPE="Unknown ($ARCH)"
        CHIP_PLAIN="Unknown ($ARCH)"
        IS_M_SERIES=false
    fi

    MODEL_ID=$(sysctl -n hw.model 2>/dev/null || /usr/sbin/sysctl -n hw.model 2>/dev/null || echo "Generic Mac")
    OS_VERSION=$(sw_vers -productVersion 2>/dev/null || /usr/bin/sw_vers -productVersion 2>/dev/null || echo "Darwin $(uname -r)")
    
    if [ -d "/System/Installation" ] || [ -f "/etc/rc.recovery" ] || [ -d "/Volumes/Image Volume" ]; then
        ENV_MODE="${YELLOW}macOS Recovery${NC}"
        ENV_PLAIN="macOS Recovery"
    else
        ENV_MODE="${GREEN}Live macOS / Terminal${NC}"
        ENV_PLAIN="Live macOS"
    fi

    WIFI_IF=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}' | head -n 1)
    [ -z "$WIFI_IF" ] && WIFI_IF="en0"
}

print_header() {
    detect_system_info
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${BOLD}       OxLogic Mac Recovery Toolkit (MRTK) v1.0.0       ${NC}"
    echo -e "${CYAN}       Developed by Md Tazmir (@mdtazmir1) | OxLogic Team       ${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    echo -e " Model: ${BOLD}$MODEL_ID${NC} | Architecture: $CHIP_TYPE"
    echo -e " Environment: $ENV_MODE | OS: ${BOLD}$OS_VERSION${NC}"
    echo -e " System Time: $(date)"
    echo -e "${CYAN}-----------------------------------------------------------------${NC}"
}

# ------------------------------------------------------------------------------
# Native AppleScript GUI Dialog Engine
# ------------------------------------------------------------------------------
has_gui() {
    [ "$FORCE_CLI" -eq 1 ] && return 1
    if command -v osascript >/dev/null 2>&1; then
        if osascript -e '1' >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

gui_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

gui_alert() {
    local title="$1"
    local msg="$2"
    local icon="${3:-note}" # note, caution, stop
    local esc_title esc_msg
    esc_title=$(gui_escape "$title")
    esc_msg=$(gui_escape "$msg")
    osascript -e "display dialog \"$esc_msg\" with title \"$esc_title\" buttons {\"OK\"} default button \"OK\" with icon $icon" >/dev/null 2>&1
}

gui_confirm() {
    local title="$1"
    local msg="$2"
    local icon="${3:-caution}"
    local ok_btn="${4:-Confirm}"
    local cancel_btn="${5:-Cancel}"
    local esc_title esc_msg
    esc_title=$(gui_escape "$title")
    esc_msg=$(gui_escape "$msg")
    local res
    res=$(osascript -e "display dialog \"$esc_msg\" with title \"$esc_title\" buttons {\"$cancel_btn\", \"$ok_btn\"} default button \"$cancel_btn\" with icon $icon" 2>/dev/null)
    if [[ "$res" =~ "button returned:$ok_btn" ]]; then
        return 0
    fi
    return 1
}

gui_choose_list() {
    local title="$1"
    local prompt="$2"
    local items_csv="$3" # e.g. '"Item 1", "Item 2"'
    local def_item="$4"
    local esc_title esc_prompt
    esc_title=$(gui_escape "$title")
    esc_prompt=$(gui_escape "$prompt")
    local script="choose from list {$items_csv} with title \"$esc_title\" with prompt \"$esc_prompt\" OK button name \"Select\" cancel button name \"Cancel\""
    if [ -n "$def_item" ]; then
        local esc_def
        esc_def=$(gui_escape "$def_item")
        script="$script default items {\"$esc_def\"}"
    fi
    osascript -e "$script" 2>/dev/null
}

gui_choose_buttons() {
    local title="$1"
    local prompt="$2"
    local btns_csv="$3" # e.g. '"Cancel", "APFS", "JHFS+"'
    local def_btn="$4"
    local icon="${5:-note}"
    local esc_title esc_prompt
    esc_title=$(gui_escape "$title")
    esc_prompt=$(gui_escape "$prompt")
    local res
    res=$(osascript -e "display dialog \"$esc_prompt\" with title \"$esc_title\" buttons {$btns_csv} default button \"$def_btn\" with icon $icon" 2>/dev/null)
    echo "$res" | sed -E 's/.*button returned:([^,]+).*/\1/'
}

gui_input() {
    local title="$1"
    local prompt="$2"
    local def_txt="$3"
    local esc_title esc_prompt esc_def
    esc_title=$(gui_escape "$title")
    esc_prompt=$(gui_escape "$prompt")
    esc_def=$(gui_escape "$def_txt")
    local res
    res=$(osascript -e "display dialog \"$esc_prompt\" with title \"$esc_title\" default answer \"$esc_def\" buttons {\"Cancel\", \"OK\"} default button \"OK\"" 2>/dev/null)
    if [[ "$res" =~ "button returned:OK" ]]; then
        echo "$res" | sed -E 's/.*text returned:(.*)/\1/'
    else
        echo ""
    fi
}

gui_choose_file() {
    local prompt="${1:-Select macOS Installer file:}"
    local esc_prompt
    esc_prompt=$(gui_escape "$prompt")
    osascript -e "POSIX path of (choose file with prompt \"$esc_prompt\")" 2>/dev/null
}

confirm_action() {
    local prompt_msg="$1"
    if has_gui; then
        gui_confirm "Confirmation Required" "$prompt_msg" "caution" "Proceed" "Cancel"
        return $?
    else
        echo -e "${RED}${BOLD}CRITICAL CONFIRMATION:${NC} $prompt_msg"
        read -rp "Type 'YES' (exact, all caps) to proceed: " confirmation
        if [ "$confirmation" != "YES" ]; then
            echo -e "${YELLOW}Operation aborted by technician.${NC}"
            return 1
        fi
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Module 1: Hardware Diagnostics & Health Checks
# ------------------------------------------------------------------------------
collect_diagnostics_text() {
    local report=""
    report="=== HARDWARE SPECIFICATIONS ===\n"
    local cpu_cores ram_bytes ram_gb
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")
    ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    if [ "$ram_bytes" -gt 0 ]; then
        ram_gb=$((ram_bytes / 1024 / 1024 / 1024))
        report="${report}• Model: $MODEL_ID\n• Architecture: $CHIP_PLAIN\n• CPU Cores: $cpu_cores | RAM: ${ram_gb} GB\n\n"
    fi

    report="${report}=== INTERNAL STORAGE HEALTH (SMART) ===\n"
    local internal_disks
    internal_disks=$(diskutil list internal physical 2>/dev/null | grep -o '/dev/disk[0-9]*' | sort -u)
    [ -z "$internal_disks" ] && internal_disks="/dev/disk0"

    for dsk in $internal_disks; do
        local dsk_id="${dsk#/dev/}"
        local smart_status media_name total_size
        smart_status=$(diskutil info "$dsk_id" 2>/dev/null | awk -F': *' '/SMART Status/{print $2}')
        media_name=$(diskutil info "$dsk_id" 2>/dev/null | grep -E "Device / Media Name|Media Name" | head -n 1 | awk -F': *' '{print $2}')
        total_size=$(diskutil info "$dsk_id" 2>/dev/null | awk -F': *' '/Disk Size/{print $2}')

        if [ "$smart_status" = "Verified" ]; then
            report="${report}• $dsk ($media_name, $total_size): [HEALTHY / VERIFIED]\n"
        elif [ "$smart_status" = "Failing" ]; then
            report="${report}• $dsk ($media_name, $total_size): [CRITICAL: FAILING! REPLACE DRIVE!]\n"
        elif [ -n "$smart_status" ]; then
            report="${report}• $dsk ($media_name): [$smart_status]\n"
        else
            report="${report}• $dsk ($media_name): [SMART Not Reported]\n"
        fi
    done

    report="${report}\n=== BATTERY CONDITION ===\n"
    if command -v system_profiler >/dev/null 2>&1; then
        local battery_info cycles condition max_cap
        battery_info=$(system_profiler SPPowerDataType 2>/dev/null)
        cycles=$(echo "$battery_info" | awk -F': *' '/Cycle Count/{print $2}' | head -n 1)
        condition=$(echo "$battery_info" | awk -F': *' '/Condition/{print $2}' | head -n 1)
        max_cap=$(echo "$battery_info" | awk -F': *' '/Maximum Capacity/{print $2}' | head -n 1)

        if [ -n "$cycles" ] || [ -n "$condition" ]; then
            [ -z "$condition" ] && condition="Normal"
            report="${report}• Condition: $condition\n• Cycle Count: ${cycles:-Unknown}\n"
            [ -n "$max_cap" ] && report="${report}• Maximum Capacity: $max_cap\n"
        else
            report="${report}• Desktop Mac / No Battery Detected\n"
        fi
    else
        report="${report}• Battery details unavailable in this minimal shell.\n"
    fi
    printf '%b' "$report"
}

menu_diagnostics() {
    if has_gui; then
        local diag_report
        diag_report=$(collect_diagnostics_text)
        gui_alert "Hardware Diagnostics Report" "$diag_report" "note"
    else
        safe_clear
        print_header
        echo -e "${BOLD}--- HARDWARE DIAGNOSTICS & HEALTH ---${NC}\n"
        collect_diagnostics_text
        pause
    fi
}

# ------------------------------------------------------------------------------
# Module 2: Network & Wi-Fi Management
# ------------------------------------------------------------------------------
test_network_status() {
    local status=""
    if ping -c 2 -W 3 1.1.1.1 >/dev/null 2>&1; then
        status="Global Internet (1.1.1.1): ONLINE\n"
    else
        status="Global Internet (1.1.1.1): OFFLINE\n"
    fi
    if ping -c 2 -W 3 time.apple.com >/dev/null 2>&1; then
        status="${status}Apple Server (time.apple.com): REACHABLE"
    else
        status="${status}Apple Server (time.apple.com): UNREACHABLE"
    fi
    printf '%b' "$status"
}

menu_network() {
    if has_gui; then
        while true; do
            local choice
            choice=$(gui_choose_list "Network & Wi-Fi Manager" "Choose a network task:" \
                '"1. Test Internet Connectivity", "2. Scan Wi-Fi Networks", "3. Connect to Wi-Fi", "4. View IP Configuration"' \
                "1. Test Internet Connectivity")
            
            [ -z "$choice" ] || [ "$choice" = "false" ] && break

            case "$choice" in
                *"1."*)
                    local net_res
                    net_res=$(test_network_status)
                    gui_alert "Network Connectivity Test" "$net_res" "note"
                    ;;
                *"2."*)
                    local airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
                    local scan_res=""
                    if [ -x "$airport_bin" ]; then
                        scan_res=$("$airport_bin" -s 2>/dev/null | head -n 25)
                    elif command -v networksetup >/dev/null 2>&1; then
                        scan_res=$(networksetup -listpreferredwirelessnetworks "$WIFI_IF" 2>/dev/null)
                    fi
                    [ -z "$scan_res" ] && scan_res="No wireless networks discovered or scanner unavailable."
                    gui_alert "Discovered Wi-Fi Networks" "$scan_res" "note"
                    ;;
                *"3."*)
                    local ssid pass
                    ssid=$(gui_input "Connect to Wi-Fi" "Enter Wi-Fi Network Name (SSID):" "")
                    if [ -n "$ssid" ]; then
                        pass=$(gui_input "Connect to Wi-Fi" "Enter Wi-Fi Password for '$ssid':" "")
                        if networksetup -setairportnetwork "$WIFI_IF" "$ssid" "$pass" 2>/dev/null; then
                            sleep 2
                            local post_test
                            post_test=$(test_network_status)
                            gui_alert "Wi-Fi Connected" "Connected to '$ssid' successfully!\n\n$post_test" "note"
                        else
                            gui_alert "Connection Failed" "Could not connect to '$ssid'. Verify password." "caution"
                        fi
                    fi
                    ;;
                *"4."*)
                    local ip_info
                    ip_info=$(ifconfig 2>/dev/null | grep -E "^[a-z0-9]+:|inet " | grep -B 1 "inet ")
                    gui_alert "Active IP Configuration" "${ip_info:-No active IP configuration found.}" "note"
                    ;;
            esac
        done
    else
        while true; do
            safe_clear
            print_header
            echo -e "${BOLD}--- NETWORK & WI-FI MANAGER ---${NC}"
            echo " 1. Test Internet Connectivity (Ping Apple & DNS)"
            echo " 2. Scan Available Wi-Fi Networks"
            echo " 3. Connect to a Wi-Fi Network"
            echo " 4. View Active IP & Network Interfaces"
            echo " 5. Back to Main Menu"
            echo -e "${CYAN}-----------------------------------------------------------------${NC}"
            read -rp "Select option (1-5): " net_choice

            case $net_choice in
                1)
                    echo -e "\n$(test_network_status)"
                    pause
                    ;;
                2)
                    local airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
                    if [ -x "$airport_bin" ]; then
                        "$airport_bin" -s
                    elif command -v networksetup >/dev/null 2>&1; then
                        networksetup -listpreferredwirelessnetworks "$WIFI_IF" 2>/dev/null || echo "No preferred networks listed."
                    fi
                    pause
                    ;;
                3)
                    read -rp "Enter Wi-Fi SSID: " wifi_ssid
                    read -rsp "Enter Wi-Fi Password: " wifi_pass
                    echo ""
                    networksetup -setairportnetwork "$WIFI_IF" "$wifi_ssid" "$wifi_pass"
                    pause
                    ;;
                4)
                    ifconfig 2>/dev/null | grep -E "^[a-z0-9]+:|inet " | grep -B 1 "inet "
                    pause
                    ;;
                5) break ;;
                *) echo -e "${RED}Invalid selection.${NC}"; sleep 1 ;;
            esac
        done
    fi
}

# ------------------------------------------------------------------------------
# Module 3: Date & Time Fix (Certificate Fix & Network Sync)
# ------------------------------------------------------------------------------
menu_date() {
    if has_gui; then
        while true; do
            local choice
            choice=$(gui_choose_buttons "Date & Time Synchronization" \
                "Current System Date: $(date)\n\nChoose an action to fix expired certificates or sync:" \
                "\"Cancel\", \"Fix 2016\", \"Fix 2019\", \"Sync Network Time\"" "Sync Network Time" "note")
            
            [ -z "$choice" ] || [ "$choice" = "Cancel" ] && break

            case "$choice" in
                "Fix 2016")
                    if gui_confirm "Offline Requirement" "IMPORTANT: Disconnect Wi-Fi before continuing or macOS will auto-revert the clock.\n\nSet date to 01/01/2016?" "caution" "Set Date" "Cancel"; then
                        date 0101010116 >/dev/null
                        gui_alert "Date Updated" "Clock set to 2016.\nCurrent Date: $(date)" "note"
                    fi
                    ;;
                "Fix 2019")
                    if gui_confirm "Offline Requirement" "IMPORTANT: Disconnect Wi-Fi before continuing or macOS will auto-revert the clock.\n\nSet date to 10/10/2019?" "caution" "Set Date" "Cancel"; then
                        date 1010101019 >/dev/null
                        gui_alert "Date Updated" "Clock set to 2019.\nCurrent Date: $(date)" "note"
                    fi
                    ;;
                "Sync Network Time")
                    if command -v sntp >/dev/null 2>&1; then
                        sntp -sS time.apple.com >/dev/null 2>&1
                    elif command -v ntpdate >/dev/null 2>&1; then
                        ntpdate -u time.apple.com >/dev/null 2>&1
                    fi
                    gui_alert "Network Time Synced" "Network synchronization complete.\nCurrent Date: $(date)" "note"
                    ;;
            esac
        done
    else
        while true; do
            safe_clear
            print_header
            echo -e "${BOLD}--- DATE & TIME SYNCHRONIZATION ---${NC}"
            echo " 1. Set Date: 2016 (For Lion, Mountain Lion, Yosemite, El Capitan)"
            echo " 2. Set Date: 2019 (For macOS Sierra, High Sierra, Mojave)"
            echo " 3. Sync Live Network Time (sntp / ntpdate fallback)"
            echo " 4. View Current System Date"
            echo " 5. Back to Main Menu"
            echo -e "${CYAN}-----------------------------------------------------------------${NC}"
            read -rp "Select option (1-5): " date_choice

            case $date_choice in
                1)
                    echo -e "\n${YELLOW}NOTE: Disconnect Wi-Fi/Ethernet or macOS will auto-sync clock.${NC}"
                    date 0101010116
                    echo -e "${GREEN}Date set to 2016.${NC} Current date: $(date)"
                    pause
                    ;;
                2)
                    echo -e "${YELLOW}NOTE: Disconnect Wi-Fi/Ethernet or macOS will auto-sync clock.${NC}"
                    date 1010101019
                    echo -e "${GREEN}Date set to 2019.${NC} Current date: $(date)"
                    pause
                    ;;
                3)
                    echo "Syncing network time..."
                    if command -v sntp >/dev/null 2>&1; then
                        sntp -sS time.apple.com
                    elif command -v ntpdate >/dev/null 2>&1; then
                        ntpdate -u time.apple.com
                    fi
                    echo -e "${GREEN}Current date:${NC} $(date)"
                    pause
                    ;;
                4) echo -e "\nDate: $(date)"; pause ;;
                5) break ;;
                *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
            esac
        done
    fi
}

# ------------------------------------------------------------------------------
# Module 4: Smart Disk Selector & Safe Formatting
# ------------------------------------------------------------------------------
get_disk_list_data() {
    local raw_disks=()
    while IFS= read -r line; do
        [ -n "$line" ] && raw_disks+=("$line")
    done < <(diskutil list physical 2>/dev/null | grep -o '/dev/disk[0-9]*' | sort -u)

    if [ ${#raw_disks[@]} -eq 0 ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && raw_disks+=("$line")
        done < <(diskutil list 2>/dev/null | grep -o '/dev/disk[0-9]*' | sort -u | head -n 6)
    fi
    printf '%s\n' "${raw_disks[@]}"
}

smart_disk_selector_gui() {
    local raw_disks=()
    while IFS= read -r line; do
        [ -n "$line" ] && raw_disks+=("$line")
    done < <(get_disk_list_data)

    [ ${#raw_disks[@]} -eq 0 ] && return 1

    local items_csv=""
    local def_item=""
    for d in "${raw_disks[@]}"; do
        local d_id="${d#/dev/}"
        local info
        info=$(diskutil info "$d_id" 2>/dev/null)
        local is_internal media_name total_size
        is_internal=$(echo "$info" | grep -E "Device Location|Internal" | head -n 1 | awk -F': *' '{print $2}')
        media_name=$(echo "$info" | grep -E "Device / Media Name|Media Name" | head -n 1 | awk -F': *' '{print $2}')
        total_size=$(echo "$info" | awk -F': *' '/Total Size|Disk Size/{print $2}' | sed -E 's/ *\(.*//' | sed -E 's/^[ \t]*//;s/[ \t]*$//')

        local label=""
        if [[ "$is_internal" =~ (Yes|Internal) ]]; then
            label="$d_id - $total_size ($media_name) [INTERNAL SSD]"
            [ -z "$def_item" ] && def_item="$label"
        else
            label="$d_id - $total_size ($media_name) [EXTERNAL USB - CAUTION]"
        fi

        [ -n "$items_csv" ] && items_csv="$items_csv, "
        items_csv="$items_csv\"$label\""
    done

    local choice
    choice=$(gui_choose_list "Smart Disk Selector" "Select the target drive to format/repair:" "$items_csv" "$def_item")
    if [ -n "$choice" ] && [ "$choice" != "false" ]; then
        echo "$choice" | awk '{print $1}'
        return 0
    fi
    return 1
}

smart_disk_selector_cli() {
    local target_var_name="$1"
    echo -e "\n${CYAN}Scanning connected physical drives...${NC}"
    local raw_disks=()
    while IFS= read -r line; do
        [ -n "$line" ] && raw_disks+=("$line")
    done < <(get_disk_list_data)

    [ ${#raw_disks[@]} -eq 0 ] && { eval "$target_var_name=''"; return 1; }

    echo -e "\n${BOLD}Available Physical Disks:${NC}"
    local idx=1
    for d in "${raw_disks[@]}"; do
        local d_id="${d#/dev/}"
        local info
        info=$(diskutil info "$d_id" 2>/dev/null)
        local is_internal media_name total_size
        is_internal=$(echo "$info" | grep -E "Device Location|Internal" | head -n 1 | awk -F': *' '{print $2}')
        media_name=$(echo "$info" | grep -E "Device / Media Name|Media Name" | head -n 1 | awk -F': *' '{print $2}')
        total_size=$(echo "$info" | awk -F': *' '/Total Size|Disk Size/{print $2}' | sed -E 's/ *\(.*//' | sed -E 's/^[ \t]*//;s/[ \t]*$//')

        if [[ "$is_internal" =~ (Yes|Internal) ]]; then
            echo -e "  ${BOLD}[$idx]${NC} $d - ${BOLD}$total_size${NC} ($media_name) ${GREEN}[INTERNAL SSD - TARGET]${NC}"
        else
            echo -e "  ${BOLD}[$idx]${NC} $d - ${BOLD}$total_size${NC} ($media_name) ${YELLOW}${BOLD}[EXTERNAL / USB - CAUTION]${NC}"
        fi
        ((idx++))
    done

    echo ""
    read -rp "Select disk number (1-${#raw_disks[@]}) or type custom disk ID: " sel_input
    local chosen_disk=""

    if [[ "$sel_input" =~ ^[0-9]+$ ]] && [ "$sel_input" -ge 1 ] && [ "$sel_input" -le ${#raw_disks[@]} ]; then
        chosen_disk="${raw_disks[$((sel_input-1))]}"
    elif [ -n "$sel_input" ]; then
        chosen_disk="$sel_input"
    else
        eval "$target_var_name=''"
        return 1
    fi

    chosen_disk="${chosen_disk#/dev/}"
    eval "$target_var_name='$chosen_disk'"
    return 0
}

execute_disk_format() {
    local f_type="$1" # APFS or JHFS+
    local target_dsk="$2"
    local vol_name="$3"

    [ -z "$vol_name" ] && vol_name="Macintosh HD"

    local dsk_info is_internal
    dsk_info=$(diskutil info "$target_dsk" 2>/dev/null)
    is_internal=$(echo "$dsk_info" | grep -E "Device Location|Internal" | head -n 1 | awk -F': *' '{print $2}')
    
    local os_ver
    os_ver=$(sw_vers -productVersion 2>/dev/null || echo "10.99")
    local is_legacy=false
    if [[ "$os_ver" =~ ^10\.1[0-2]\. ]] || [[ "$os_ver" =~ ^10\.[0-9]\. ]]; then
        is_legacy=true
    fi

    if has_gui; then
        if [[ ! "$is_internal" =~ (Yes|Internal) ]]; then
            if ! gui_confirm "EXTERNAL DRIVE SELECTED" "WARNING: You selected /dev/$target_dsk which appears to be an EXTERNAL / USB drive!\n\nThis could be your installer USB. Proceed anyway?" "stop" "Proceed" "Cancel"; then
                return 1
            fi
        fi

        if [ "$is_legacy" = true ] && [ "$f_type" = "APFS" ]; then
            if ! gui_confirm "Legacy OS Detected" "macOS $os_ver (Sierra or older) has limited or no support for APFS. Formatting as APFS will likely fail.\n\nIt is strongly recommended to use JHFS+ (Mac OS Extended) instead.\n\nProceed with APFS anyway?" "caution" "Proceed" "Cancel"; then
                return 1
            fi
        fi

        if gui_confirm "Confirm Erase & Format" "All data on /dev/$target_dsk will be PERMANENTLY ERASED.\n\nFormat: $f_type\nVolume Name: $vol_name\n\nAre you sure you want to proceed?" "caution" "Erase Disk" "Cancel"; then
            # Aggressive unmount: Find and force-unmount any synthesized APFS/CoreStorage containers attached to this physical disk
            local related_disks
            related_disks=$(diskutil list "/dev/$target_dsk" 2>/dev/null | grep -o 'disk[0-9]*' | sort -u)
            for rd in $related_disks; do
                diskutil unmountDisk force "/dev/$rd" >/dev/null 2>&1
            done
            
            diskutil eraseDisk "$f_type" "$vol_name" "/dev/$target_dsk" >/tmp/format.log 2>&1
            if [ $? -eq 0 ]; then
                gui_alert "Format Successful" "Disk /dev/$target_dsk successfully formatted as $f_type ('$vol_name')." "note"
            else
                local err_log
                err_log=$(tail -n 6 /tmp/format.log)
                if [[ "$err_log" =~ "-69877" ]] || [[ "$err_log" =~ "Couldn't open device" ]] || [[ "$err_log" =~ "Formatting is not supported" ]]; then
                    # Fallback to partitionDisk for stubborn legacy unmount issues
                    diskutil partitionDisk "/dev/$target_dsk" 1 GPT "$f_type" "$vol_name" R >/tmp/format_fallback.log 2>&1
                    if [ $? -eq 0 ]; then
                        gui_alert "Format Successful (Fallback Method)" "Disk /dev/$target_dsk successfully formatted as $f_type ('$vol_name') using forced partition wipe." "note"
                        return 0
                    else
                        err_log=$(tail -n 6 /tmp/format_fallback.log)
                    fi
                fi
                gui_alert "Format Failed" "Error formatting /dev/$target_dsk:\n\n$err_log\n\nTip: Ensure no background processes are locking the drive." "stop"
            fi
        fi
    else
        if [[ ! "$is_internal" =~ (Yes|Internal) ]]; then
            echo -e "\n${RED}${BOLD}CRITICAL WARNING: /dev/$target_dsk is an EXTERNAL DRIVE!${NC}"
            read -rp "Type 'ERASE-EXTERNAL' to confirm: " ext_c
            [ "$ext_c" != "ERASE-EXTERNAL" ] && return 1
        fi

        if [ "$is_legacy" = true ] && [ "$f_type" = "APFS" ]; then
            echo -e "\n${YELLOW}${BOLD}WARNING: macOS $os_ver (Sierra or older) has limited/no support for APFS.${NC}"
            echo -e "Formatting as APFS will likely fail. JHFS+ is highly recommended."
            if ! confirm_action "Proceed with APFS formatting anyway?"; then
                return 1
            fi
        fi

        if confirm_action "Entire disk /dev/$target_dsk will be WIPED and formatted as $f_type ('$vol_name')."; then
            echo -e "${CYAN}Forcing unmount of /dev/$target_dsk and all associated containers...${NC}"
            local related_disks
            related_disks=$(diskutil list "/dev/$target_dsk" 2>/dev/null | grep -o 'disk[0-9]*' | sort -u)
            for rd in $related_disks; do
                diskutil unmountDisk force "/dev/$rd" >/dev/null 2>&1
            done
            
            diskutil eraseDisk "$f_type" "$vol_name" "/dev/$target_dsk" >/tmp/format.log 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n${GREEN}$f_type Format completed.${NC}"
            else
                local err_log
                err_log=$(tail -n 6 /tmp/format.log)
                if [[ "$err_log" =~ "-69877" ]] || [[ "$err_log" =~ "Couldn't open device" ]] || [[ "$err_log" =~ "Formatting is not supported" ]]; then
                    echo -e "${YELLOW}Standard erase failed. Attempting forced partition wipe (legacy fallback)...${NC}"
                    diskutil partitionDisk "/dev/$target_dsk" 1 GPT "$f_type" "$vol_name" R >/tmp/format_fallback.log 2>&1
                    if [ $? -eq 0 ]; then
                        echo -e "\n${GREEN}$f_type Format completed (using partition fallback).${NC}"
                        return 0
                    else
                        err_log=$(tail -n 6 /tmp/format_fallback.log)
                    fi
                fi
                echo -e "\n${RED}Format Failed. Error details:${NC}"
                echo "$err_log"
            fi
        fi
    fi
}

quick_connect_external_drives() {
    local is_gui=false
    has_gui && is_gui=true

    if [ "$is_gui" = true ]; then
        # Check and clear hung background scans (fsck on dirty exFAT/FAT)
        local hung_pids
        hung_pids=$(pgrep -f "fsck_exfat|fsck_msdos" 2>/dev/null)
        local was_hung=false
        if [ -n "$hung_pids" ]; then
            pkill -9 -f "fsck_exfat" 2>/dev/null
            pkill -9 -f "fsck_msdos" 2>/dev/null
            was_hung=true
        fi

        # Find external physical disks
        local ext_disks
        ext_disks=$(diskutil list external physical 2>/dev/null | grep -E '^/dev/disk[0-9]+' | awk '{print $1}')
        if [ -z "$ext_disks" ]; then
            ext_disks=$(diskutil list 2>/dev/null | grep -E '^/dev/disk[0-9]+ \((external|synthesized)' | awk '{print $1}')
        fi

        local mounted_count=0
        local mounted_info=""

        if [ -n "$ext_disks" ]; then
            while IFS= read -r dsk; do
                [ -z "$dsk" ] && continue
                diskutil mountDisk "$dsk" >/tmp/mount_res.log 2>&1
                local d_name
                d_name=$(diskutil info "$dsk" 2>/dev/null | grep -E "Media Name|Device / Media Name" | head -n 1 | awk -F': *' '{print $2}')
                [ -z "$d_name" ] && d_name="$dsk"
                mounted_info="${mounted_info}• $d_name ($dsk)\n"
                ((mounted_count++))
            done <<< "$ext_disks"
        fi

        # Also trigger system-wide mount for all unmounted volumes
        diskutil mount -all >/dev/null 2>&1

        local msg=""
        if [ "$was_hung" = true ]; then
            msg="✓ Fixed! Unlocked frozen background scan (exFAT delay eliminated).\n\n"
        fi

        if [ $mounted_count -gt 0 ]; then
            msg="${msg}Successfully scanned & connected $mounted_count external drive(s):\n\n$mounted_info\nYour drives should now be visible in Finder and /Volumes."
            gui_alert "Quick Connect" "$msg" "note"
        else
            gui_alert "Quick Connect" "Scan complete. All connected external drives are active and mounted.\n\nIf your drive still does not appear, check the USB cable or port." "note"
        fi
    else
        echo -e "\n${CYAN}Scanning for slow-connecting or unmounted external drives...${NC}"
        local hung_pids
        hung_pids=$(pgrep -f "fsck_exfat|fsck_msdos" 2>/dev/null)
        if [ -n "$hung_pids" ]; then
            echo -e "${YELLOW}Detected background scan freeze (fsck). Unlocking drive now...${NC}"
            pkill -9 -f "fsck_exfat" 2>/dev/null
            pkill -9 -f "fsck_msdos" 2>/dev/null
        fi

        local ext_disks
        ext_disks=$(diskutil list external physical 2>/dev/null | grep -E '^/dev/disk[0-9]+' | awk '{print $1}')
        if [ -z "$ext_disks" ]; then
            ext_disks=$(diskutil list 2>/dev/null | grep -E '^/dev/disk[0-9]+ \((external|synthesized)' | awk '{print $1}')
        fi

        local count=0
        if [ -n "$ext_disks" ]; then
            while IFS= read -r dsk; do
                [ -z "$dsk" ] && continue
                local info
                info=$(diskutil info "$dsk" 2>/dev/null)
                local is_int
                is_int=$(echo "$info" | grep -E "Device Location|Internal" | head -n 1 | awk -F': *' '{print $2}')
                if [[ ! "$is_int" =~ (Yes|Internal) ]]; then
                    local d_name
                    d_name=$(echo "$info" | grep -E "Media Name|Device / Media Name" | head -n 1 | awk -F': *' '{print $2}')
                    echo -e "  Mounting: ${BOLD}$dsk${NC} ($d_name)..."
                    diskutil mountDisk "$dsk" 2>/dev/null
                    ((count++))
                fi
            done <<< "$ext_disks"
        fi

        diskutil mount -all >/dev/null 2>&1

        echo -e "\n${GREEN}${BOLD}✓ Quick Connect complete!${NC}"
        echo -e "External drives checked. All volumes are now active in /Volumes."
        pause
    fi
}

menu_disks() {
    if has_gui; then
        while true; do
            local choice
            choice=$(gui_choose_list "Smart Disk Manager & Safe Formatting" "Choose a disk management task:" \
                '"1. Format APFS (Recommended for High Sierra to Sequoia)", "2. Format JHFS+ (Legacy macOS Sierra & older)", "3. Show Disk Topology", "4. Delete APFS Volume Group", "5. Run First Aid / Repair Disk", "6. Quick Connect External USB / Hard Disk"' \
                "1. Format APFS (Recommended for High Sierra to Sequoia)")
            
            [ -z "$choice" ] || [ "$choice" = "false" ] && break

            case "$choice" in
                *"1."*|*"2."*)
                    local f_type="APFS"
                    [[ "$choice" =~ "JHFS+" ]] && f_type="JHFS+"

                    local sel_disk
                    sel_disk=$(smart_disk_selector_gui)
                    if [ -n "$sel_disk" ]; then
                        local vol_name
                        vol_name=$(gui_input "Target Volume Name" "Enter Volume Label for the formatted disk:" "Macintosh HD")
                        [ -n "$vol_name" ] && execute_disk_format "$f_type" "$sel_disk" "$vol_name"
                    fi
                    ;;
                *"3."*)
                    local dlist
                    dlist=$(diskutil list 2>/dev/null | head -n 40)
                    gui_alert "Disk Topology" "$dlist" "note"
                    ;;
                *"4."*)
                    local apfs_id
                    apfs_id=$(gui_input "Delete APFS Volume Group" "Enter APFS Volume Group or identifier to delete (e.g. disk3s1):" "")
                    if [ -n "$apfs_id" ]; then
                        if gui_confirm "Delete APFS Volume Group" "CAUTION: Deleting volume groups on Apple Silicon without care can destroy 1TR Recovery.\n\nPermanently delete /dev/$apfs_id?" "stop" "Delete" "Cancel"; then
                            diskutil apfs deleteVolumeGroup "$apfs_id" >/tmp/apfs_del.log 2>&1
                            if [ $? -eq 0 ]; then
                                gui_alert "APFS Volume Group" "Volume Group deleted." "note"
                            else
                                local err
                                err=$(cat /tmp/apfs_del.log)
                                if [[ "$err" =~ "did not recognize APFS verb" ]] || [[ "$err" =~ "invalid verb" ]]; then
                                    gui_alert "Legacy OS Detected" "This macOS version is too old to use 'deleteVolumeGroup'. Format the entire disk as JHFS+ instead, or use macOS High Sierra or newer." "stop"
                                else
                                    gui_alert "Error" "$err" "stop"
                                fi
                            fi
                        fi
                    fi
                    ;;
                *"5."*)
                    local sel_disk
                    sel_disk=$(smart_disk_selector_gui)
                    if [ -n "$sel_disk" ]; then
                        diskutil repairDisk "/dev/$sel_disk" >/tmp/repair.log 2>&1
                        local log_res
                        log_res=$(tail -n 12 /tmp/repair.log)
                        gui_alert "First Aid Complete" "Repair results for /dev/$sel_disk:\n\n$log_res" "note"
                    fi
                    ;;
                *"6."*)
                    quick_connect_external_drives
                    ;;
            esac
        done
    else
        while true; do
            safe_clear
            print_header
            echo -e "${BOLD}--- SMART DISK MANAGER & SAFE FORMATTING ---${NC}"
            echo " 1. Show Detailed Disk Topology (diskutil list)"
            echo " 2. Format APFS (Recommended for High Sierra to Sequoia)"
            echo " 3. Format JHFS+ (Legacy macOS Sierra & older)"
            echo " 4. Delete APFS Volume Group (Apple Silicon / Big Sur+)"
            echo " 5. Run First Aid / Repair Disk"
            echo " 6. Quick Connect External USB / Hard Disk"
            echo " 7. Back to Main Menu"
            echo -e "${CYAN}-----------------------------------------------------------------${NC}"
            read -rp "Select option (1-7): " disk_choice

            case $disk_choice in
                1) diskutil list; pause ;;
                2)
                    local target_dsk=""
                    smart_disk_selector_cli target_dsk || { pause; continue; }
                    read -rp "Enter Volume Name [Default: Macintosh HD]: " vol_name
                    execute_disk_format "APFS" "$target_dsk" "${vol_name:-Macintosh HD}"
                    pause
                    ;;
                3)
                    local target_dsk=""
                    smart_disk_selector_cli target_dsk || { pause; continue; }
                    read -rp "Enter Volume Name [Default: Macintosh HD]: " vol_name
                    execute_disk_format "JHFS+" "$target_dsk" "${vol_name:-Macintosh HD}"
                    pause
                    ;;
                4)
                    diskutil apfs list
                    read -rp "Enter APFS identifier to delete (e.g. disk3s1): " apfs_target
                    if [ -n "$apfs_target" ] && confirm_action "Delete APFS Volume Group on /dev/$apfs_target?"; then
                        diskutil apfs deleteVolumeGroup "$apfs_target" >/tmp/apfs_del.log 2>&1
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}Volume Group deleted.${NC}"
                        else
                            local err
                            err=$(cat /tmp/apfs_del.log)
                            if [[ "$err" =~ "did not recognize APFS verb" ]] || [[ "$err" =~ "invalid verb" ]]; then
                                echo -e "\n${RED}Legacy OS Detected: This macOS version is too old to use 'deleteVolumeGroup'. Format the entire disk as JHFS+ instead.${NC}"
                            else
                                echo -e "\n${RED}Error: $err${NC}"
                            fi
                        fi
                    fi
                    pause
                    ;;
                5)
                    local target_dsk=""
                    smart_disk_selector_cli target_dsk || { pause; continue; }
                    diskutil repairDisk "/dev/$target_dsk"
                    pause
                    ;;
                6)
                    quick_connect_external_drives
                    ;;
                7) break ;;
                *) echo -e "${RED}Invalid selection.${NC}"; sleep 1 ;;
            esac
        done
    fi
}

# ------------------------------------------------------------------------------
# Module 5: Emergency User Data Backup Engine (Pre-Wipe Triage)
# ------------------------------------------------------------------------------
locate_user_data_root() {
    # Check if we are in live OS where /Users exists directly
    if [ -d "/Users" ] && [ "$ENV_TYPE" = "Live macOS" ]; then
        local user_check
        user_check=$(ls /Users 2>/dev/null | grep -Ev '^(Shared|Guest|\.localized)$' | head -n 1)
        if [ -n "$user_check" ]; then
            echo "/Users"
            return 0
        fi
    fi

    # In Recovery mode or mounted external/internal partitions:
    local d
    for d in "/Volumes"/*" - Data" "/Volumes/Data" "/Volumes/Macintosh HD/Users"; do
        if [ -d "$d/Users" ]; then
            echo "$d/Users"
            return 0
        elif [ -d "$d" ] && [ "$(basename "$d")" = "Users" ]; then
            echo "$d"
            return 0
        fi
    done

    # If not already mounted in /Volumes, inspect APFS volume list for unmounted Data volumes
    local apfs_data_vols
    apfs_data_vols=$(diskutil apfs list 2>/dev/null | grep -B 2 -E "Role:.*(Data|None)" | grep "APFS Volume Disk Identifier:" | awk '{print $NF}')
    if [ -z "$apfs_data_vols" ]; then
        apfs_data_vols=$(diskutil apfs list 2>/dev/null | grep "APFS Volume Disk Identifier:" | awk '{print $NF}')
    fi

    if [ -n "$apfs_data_vols" ]; then
        local v
        for v in $apfs_data_vols; do
            local v_info
            v_info=$(diskutil info "$v" 2>/dev/null)
            local is_mounted
            is_mounted=$(echo "$v_info" | grep -E "Mounted:.*Yes")

            if [ -n "$is_mounted" ]; then
                local m_point
                m_point=$(echo "$v_info" | grep "Mount Point:" | awk -F': *' '{print $2}')
                if [ -d "$m_point/Users" ]; then
                    echo "$m_point/Users"
                    return 0
                fi
            fi
        done
    fi

    return 1
}

unlock_and_mount_apfs_data() {
    local target_disk_id="$1"
    local is_gui=false
    has_gui && is_gui=true

    if [ -z "$target_disk_id" ]; then
        target_disk_id=$(diskutil apfs list 2>/dev/null | grep -B 3 -E "(Role:.*Data|Name:.*Data)" | grep "APFS Volume Disk Identifier:" | head -n 1 | awk '{print $NF}')
        [ -z "$target_disk_id" ] && target_disk_id=$(diskutil list internal 2>/dev/null | grep "Macintosh HD - Data" | awk '{print $NF}')
    fi

    [ -z "$target_disk_id" ] && return 1

    local v_info
    v_info=$(diskutil info "$target_disk_id" 2>/dev/null)
    local is_locked
    is_locked=$(echo "$v_info" | grep -E "FileVault:.*Locked|Locked:.*Yes")

    if [ -n "$is_locked" ]; then
        local pass=""
        if [ "$is_gui" = true ]; then
            pass=$(gui_input "Encrypted Volume Locked" "The internal drive ($target_disk_id) is protected by FileVault.\n\nEnter the Mac user login password to unlock and access data:" "" true)
        else
            echo -e "\n${YELLOW}${BOLD}Internal drive ($target_disk_id) is locked with FileVault encryption.${NC}"
            read -s -rp "Enter Mac user login password to unlock: " pass
            echo ""
        fi

        [ -z "$pass" ] && return 1

        printf '%s' "$pass" | diskutil apfs unlockVolume "$target_disk_id" -stdinpass >/tmp/unlock.log 2>&1
        if [ $? -ne 0 ]; then
            if [ "$is_gui" = true ]; then
                gui_alert "Unlock Failed" "Incorrect password or failed to unlock volume $target_disk_id.\n\n$(cat /tmp/unlock.log)" "stop"
            else
                echo -e "${RED}Failed to unlock $target_disk_id: $(cat /tmp/unlock.log)${NC}"
            fi
            return 1
        fi
    else
        diskutil mount "$target_disk_id" >/dev/null 2>&1
    fi

    return 0
}

get_backup_target_volumes() {
    local candidates=()
    local ext_disks
    ext_disks=$(diskutil list external physical 2>/dev/null | grep -E '^/dev/disk[0-9]+' | awk '{print $1}')
    [ -z "$ext_disks" ] && ext_disks=$(diskutil list 2>/dev/null | grep -E '^\/dev\/disk[0-9]+ \((external|synthesized)' | awk '{print $1}')

    if [ -n "$ext_disks" ]; then
        local ed
        for ed in $ext_disks; do
            local ed_id="${ed#/dev/}"
            while IFS= read -r part_id; do
                [ -z "$part_id" ] && continue
                local info
                info=$(diskutil info "$part_id" 2>/dev/null)
                local mpoint
                mpoint=$(echo "$info" | grep -E "^ *Mount Point:" | awk -F': *' '{print $2}' | sed -E 's/^[ \t]*//;s/[ \t]*$//')
                
                # Extract clean size strings, e.g., "61.5 GB" instead of "61.5 GB (61523034112 Bytes) (exactly 120162176 512-Byte-Units)"
                local total_sz
                total_sz=$(echo "$info" | awk -F': *' '/Total Size|Disk Size/{print $2}' | sed -E 's/ *\(.*//' | sed -E 's/^[ \t]*//;s/[ \t]*$//')
                local free_sz
                free_sz=$(echo "$info" | awk -F': *' '/Volume Free Space|Free Space|Available Space/{print $2}' | sed -E 's/ *\(.*//' | sed -E 's/^[ \t]*//;s/[ \t]*$//')
                
                local vname
                vname=$(echo "$info" | grep -E "^ *Volume Name:" | awk -F': *' '{print $2}' | sed -E 's/^[ \t]*//;s/[ \t]*$//')
                [ -z "$vname" ] && vname="Untitled"
                [ -z "$free_sz" ] && free_sz="Unknown"

                if [ -n "$mpoint" ] && [ -d "$mpoint" ] && [ "$mpoint" != "/" ]; then
                    candidates+=("$mpoint|$vname ($total_sz, Free: $free_sz)")
                fi
            done < <(diskutil list "$ed_id" 2>/dev/null | grep -E '^ +[0-9]+:' | awk '{print $NF}')
        done
    fi

    printf '%s\n' "${candidates[@]}"
}

execute_user_backup() {
    local src_user_dir="$1"
    local dst_vol_mount="$2"
    local username="$3"
    local is_gui=false
    has_gui && is_gui=true

    local backup_folder_name="Backup_${username}_$(date +%Y%m%d_%H%M%S)"
    local target_dest="$dst_vol_mount/$backup_folder_name"

    if [ "$is_gui" = true ]; then
        if ! gui_confirm "Start Data Backup" "Source: $src_user_dir\nTarget: $target_dest\n\n• Resumable Rsync Engine active.\n• System Caches (.Trash, Library/Caches) excluded.\n\nProceed with backup?" "note" "Start Backup" "Cancel"; then
            return 1
        fi

        mkdir -p "$target_dest" 2>/dev/null
        local log_file="/tmp/backup_${username}.log"
        echo "Starting rsync backup for $username..." > "$log_file"

        rsync -avP --partial \
            --exclude="Library/Caches" \
            --exclude="Library/Logs" \
            --exclude=".Trash" \
            --exclude="Library/Containers/*/Data/Library/Caches" \
            "$src_user_dir/" "$target_dest/" > "$log_file" 2>&1 &
        local rsync_pid=$!

        gui_alert "Backup in Progress" "Data backup has started in the background!\n\nDestination: $target_dest\nLog: $log_file\n\nClick OK when file copying finishes." "note"

        wait "$rsync_pid"
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            gui_alert "Backup Successful" "✓ User data for '$username' successfully backed up!\n\nLocation: $target_dest" "note"
        else
            local err_tail
            err_tail=$(tail -n 6 "$log_file")
            gui_alert "Backup Warning" "rsync completed with code $exit_code:\n\n$err_tail" "caution"
        fi
    else
        echo -e "\n${BOLD}=================================================================${NC}"
        echo -e "                   STARTING USER DATA BACKUP                     "
        echo -e "${BOLD}=================================================================${NC}"
        echo -e "Source: ${CYAN}$src_user_dir${NC}"
        echo -e "Target: ${GREEN}$target_dest${NC}"
        echo -e "Excluding: ${YELLOW}Library/Caches, .Trash, Logs${NC}"
        echo -e "${CYAN}-----------------------------------------------------------------${NC}"
        
        mkdir -p "$target_dest" 2>/dev/null

        rsync -avP --partial \
            --exclude="Library/Caches" \
            --exclude="Library/Logs" \
            --exclude=".Trash" \
            --exclude="Library/Containers/*/Data/Library/Caches" \
            "$src_user_dir/" "$target_dest/"

        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo -e "\n${GREEN}${BOLD}✓ Backup completed successfully!${NC}"
            echo -e "Saved to: ${BOLD}$target_dest${NC}"
        else
            echo -e "\n${YELLOW}${BOLD}! Backup finished with exit code: $exit_code (Some locked system files may have been skipped).${NC}"
        fi
        pause
    fi
}

menu_backup_data() {
    local is_gui=false
    has_gui && is_gui=true

    # 1. Locate the users directory
    local users_root
    users_root=$(locate_user_data_root)

    if [ -z "$users_root" ] || [ ! -d "$users_root" ]; then
        if unlock_and_mount_apfs_data; then
            users_root=$(locate_user_data_root)
        fi
    fi

    if [ -z "$users_root" ] || [ ! -d "$users_root" ]; then
        if [ "$is_gui" = true ]; then
            gui_alert "Data Volume Not Found" "Could not detect an accessible 'Macintosh HD - Data' volume or /Users folder.\n\nIf the internal drive is encrypted, unlock it in Disk Utility first." "stop"
        else
            echo -e "\n${RED}Error: Could not locate /Users or accessible Macintosh HD - Data volume.${NC}"
            echo "If the drive has FileVault enabled, unlock it with 'diskutil apfs unlockVolume' first."
            pause
        fi
        return 1
    fi

    # 2. Find valid user accounts
    local valid_users=()
    while IFS= read -r u; do
        if [ -d "$users_root/$u" ] && [[ ! "$u" =~ ^(Shared|Guest|\.localized|\.DS_Store)$ ]]; then
            valid_users+=("$u")
        fi
    done < <(ls -1 "$users_root" 2>/dev/null)

    if [ ${#valid_users[@]} -eq 0 ]; then
        if [ "$is_gui" = true ]; then
            gui_alert "No User Profiles" "No personal user account folders found in $users_root." "caution"
        else
            echo -e "\n${YELLOW}No user account folders found in $users_root.${NC}"
            pause
        fi
        return 1
    fi

    # 3. Find backup target USB drives
    local target_drives=()
    while IFS= read -r t; do
        [ -n "$t" ] && target_drives+=("$t")
    done < <(get_backup_target_volumes)

    if [ ${#target_drives[@]} -eq 0 ]; then
        quick_connect_external_drives
        while IFS= read -r t; do
            [ -n "$t" ] && target_drives+=("$t")
        done < <(get_backup_target_volumes)
    fi

    if [ ${#target_drives[@]} -eq 0 ]; then
        if [ "$is_gui" = true ]; then
            gui_alert "No Backup Drive" "No external USB flash drive or external hard drive detected in /Volumes.\n\nPlease connect an external drive and try again." "stop"
        else
            echo -e "\n${RED}Error: No external USB flash drive or external hard drive detected in /Volumes.${NC}"
            echo "Please connect an external backup drive."
            pause
        fi
        return 1
    fi

    # Selection flow
    local chosen_user=""
    local chosen_dest_mount=""

    if [ "$is_gui" = true ]; then
        local user_csv=""
        local u
        for u in "${valid_users[@]}"; do
            [ -n "$user_csv" ] && user_csv="$user_csv, "
            user_csv="$user_csv\"$u\""
        done

        chosen_user=$(gui_choose_list "Select User to Backup" "Detected User Accounts on Mac:" "$user_csv" "${valid_users[0]}")
        [ -z "$chosen_user" ] || [ "$chosen_user" = "false" ] && return 0

        local drive_csv=""
        local d
        for d in "${target_drives[@]}"; do
            local d_path
            d_path=$(echo "$d" | cut -d'|' -f1)
            local d_desc
            d_desc=$(echo "$d" | cut -d'|' -f2)
            [ -n "$drive_csv" ] && drive_csv="$drive_csv, "
            drive_csv="$drive_csv\"$d_desc [$d_path]\""
        done

        local sel_drive_item
        sel_drive_item=$(gui_choose_list "Select Backup Destination Drive" "Choose external USB drive / Hard Disk to store backup:" "$drive_csv" "")
        [ -z "$sel_drive_item" ] || [ "$sel_drive_item" = "false" ] && return 0

        chosen_dest_mount=$(echo "$sel_drive_item" | sed -E 's/.*\[(.*)\]/\1/')
    else
        safe_clear
        print_header
        echo -e "${BOLD}--- EMERGENCY USER DATA BACKUP (PRE-WIPE TRIAGE) ---${NC}"
        echo -e "\nDetected User Accounts on Mac SSD (${CYAN}$users_root${NC}):"
        local idx=1
        local u
        for u in "${valid_users[@]}"; do
            echo "  [$idx] $u"
            ((idx++))
        done

        read -rp "Select user account number (1-${#valid_users[@]}): " u_choice
        if [[ "$u_choice" =~ ^[0-9]+$ ]] && [ "$u_choice" -ge 1 ] && [ "$u_choice" -le ${#valid_users[@]} ]; then
            chosen_user="${valid_users[$((u_choice-1))]}"
        else
            echo -e "${RED}Invalid selection.${NC}"; pause; return 1
        fi

        echo -e "\nAvailable External Backup Drives:"
        local d_idx=1
        local d
        for d in "${target_drives[@]}"; do
            local d_path
            d_path=$(echo "$d" | cut -d'|' -f1)
            local d_desc
            d_desc=$(echo "$d" | cut -d'|' -f2)
            echo "  [$d_idx] $d_desc"
            echo "        Path: $d_path"
            ((d_idx++))
        done

        read -rp "Select target backup drive (1-${#target_drives[@]}): " d_choice
        if [[ "$d_choice" =~ ^[0-9]+$ ]] && [ "$d_choice" -ge 1 ] && [ "$d_choice" -le ${#target_drives[@]} ]; then
            chosen_dest_mount=$(echo "${target_drives[$((d_choice-1))]}" | cut -d'|' -f1)
        else
            echo -e "${RED}Invalid selection.${NC}"; pause; return 1
        fi
    fi

    if [ -n "$chosen_user" ] && [ -n "$chosen_dest_mount" ]; then
        execute_user_backup "$users_root/$chosen_user" "$chosen_dest_mount" "$chosen_user"
    fi
}

# ------------------------------------------------------------------------------
# Module 6: macOS Deployment & startosinstall Runner
# ------------------------------------------------------------------------------
find_installer_binaries() {
    local found=()
    while IFS= read -r path; do
        if [ -x "$path" ]; then
            found+=("$path")
        fi
    done < <(find /Volumes -maxdepth 4 -name "startosinstall" 2>/dev/null)
    printf '%s\n' "${found[@]}"
}

menu_installer() {
    if has_gui; then
        while true; do
            local choice
            choice=$(gui_choose_list "macOS Deployment & Installation" "Choose an installation option:" \
                '"1. Auto-Detect USB Installers & Run", "2. Run USB Installer with Admin User (Big Sur+)", "3. Download Full Installer from Apple CDN", "4. View Mounted Volumes"' \
                "1. Auto-Detect USB Installers & Run")
            
            [ -z "$choice" ] || [ "$choice" = "false" ] && break

            case "$choice" in
                *"1."*|*"2."*)
                    local installers=()
                    while IFS= read -r line; do
                        [ -n "$line" ] && installers+=("$line")
                    done < <(find_installer_binaries)

                    local selected_installer=""
                    if [ ${#installers[@]} -eq 0 ]; then
                        gui_alert "No Installer Detected" "No bootable macOS installer found in /Volumes.\nMake sure your USB installer is connected and mounted." "caution"
                        continue
                    elif [ ${#installers[@]} -eq 1 ]; then
                        selected_installer="${installers[0]}"
                    else
                        local inst_csv=""
                        for inst in "${installers[@]}"; do
                            [ -n "$inst_csv" ] && inst_csv="$inst_csv, "
                            inst_csv="$inst_csv\"$inst\""
                        done
                        selected_installer=$(gui_choose_list "Select Installer" "Multiple installers found:" "$inst_csv" "${installers[0]}")
                        [ -z "$selected_installer" ] || [ "$selected_installer" = "false" ] && continue
                    fi

                    local target_vol
                    target_vol=$(gui_input "Destination Target Volume" "Enter destination volume mount path:" "/Volumes/Macintosh HD")
                    [ -z "$target_vol" ] && continue

                    if [ ! -d "$target_vol" ]; then
                        gui_alert "Volume Not Found" "Target volume '$target_vol' is not mounted.\nFormat the disk first or check diskutil list." "stop"
                        continue
                    fi

                    if [[ "$choice" =~ "2." ]]; then
                        local admin_user
                        admin_user=$(gui_input "Mac Administrator Username" "Enter Mac Admin Username (required for Big Sur+):" "")
                        [ -z "$admin_user" ] && continue

                        if gui_confirm "Start Installation" "Launch installation of:\n$selected_installer\n\nTarget: $target_vol\nAdmin User: $admin_user\n\nProceed?" "note" "Start Install" "Cancel"; then
                            "$selected_installer" --volume "$target_vol" --agreetolicense --user "$admin_user" --forcequitapps
                        fi
                    else
                        if gui_confirm "Start Installation" "Launch installation of:\n$selected_installer\n\nTarget: $target_vol\n\nProceed?" "note" "Start Install" "Cancel"; then
                            "$selected_installer" --volume "$target_vol" --agreetolicense --forcequitapps
                        fi
                    fi
                    ;;
                *"3."*)
                    local dl_ver
                    dl_ver=$(gui_input "Download macOS Installer" "Enter macOS version to fetch from Apple CDN (e.g. 14.7.1, 13.6.9, 12.7.6):" "14.7.1")
                    if [ -n "$dl_ver" ]; then
                        gui_alert "Starting Download" "Download initiated in terminal for macOS $dl_ver.\nThis requires ~14GB free space." "note"
                        softwareupdate --fetch-full-installer --full-installer-version "$dl_ver"
                        gui_alert "Download Finished" "Installer download process completed." "note"
                    fi
                    ;;
                *"4."*)
                    local vols
                    vols=$(ls -lah /Volumes 2>/dev/null)
                    gui_alert "Mounted Volumes" "$vols" "note"
                    ;;
            esac
        done
    else
        while true; do
            safe_clear
            print_header
            echo -e "${BOLD}--- MACOS DEPLOYMENT & INSTALLATION ---${NC}"
            echo " 1. Auto-Detect USB Installers & Run (Standard Install)"
            echo " 2. Run USB Installer with Admin User (Required for Big Sur+)"
            echo " 3. Download Full macOS Installer from Apple (Online CDN)"
            echo " 4. View Mounted Volumes in /Volumes"
            echo " 5. Back to Main Menu"
            echo -e "${CYAN}-----------------------------------------------------------------${NC}"
            read -rp "Select option (1-5): " inst_choice

            case $inst_choice in
                1|2)
                    local installers=()
                    while IFS= read -r line; do
                        [ -n "$line" ] && installers+=("$line")
                    done < <(find_installer_binaries)

                    [ ${#installers[@]} -eq 0 ] && { echo -e "${YELLOW}No installer detected.${NC}"; pause; continue; }
                    local selected_installer="${installers[0]}"

                    read -rp "Enter Target Volume [Default: /Volumes/Macintosh HD]: " target_vol
                    target_vol="${target_vol:-/Volumes/Macintosh HD}"

                    if [ "$inst_choice" -eq 2 ]; then
                        read -rp "Enter Mac Admin Username: " admin_user
                        "$selected_installer" --volume "$target_vol" --agreetolicense --user "$admin_user" --forcequitapps
                    else
                        "$selected_installer" --volume "$target_vol" --agreetolicense --forcequitapps
                    fi
                    pause
                    ;;
                3)
                    read -rp "Enter macOS version (e.g. 14.7.1): " dl_ver
                    softwareupdate --fetch-full-installer --full-installer-version "$dl_ver"
                    pause
                    ;;
                4) ls -lah /Volumes; pause ;;
                5) break ;;
                *) echo -e "${RED}Invalid selection.${NC}"; sleep 1 ;;
            esac
        done
    fi
}

# ------------------------------------------------------------------------------
# Module 6: Create macOS Bootable USB Installer (Live macOS / GUI & CLI)
# ------------------------------------------------------------------------------
find_installed_macos_apps() {
    local found=()
    for loc in /Applications/Install\ macOS*.app \
               /Applications/Install\ OS\ X*.app \
               "$HOME"/Downloads/Install\ macOS*.app \
               "$HOME"/Desktop/Install\ macOS*.app \
               /Volumes/*/Install\ macOS*.app; do
        if [ -d "$loc" ] && [ -x "$loc/Contents/Resources/createinstallmedia" ]; then
            found+=("$loc")
        fi
    done
    printf '%s\n' "${found[@]}"
}

get_usb_target_volumes() {
    local candidates=()
    for v in /Volumes/*; do
        [ ! -d "$v" ] && continue
        local bname=$(basename "$v")
        case "$bname" in
            "Macintosh HD"|"Macintosh HD - Data"|"Recovery"|"Preboot"|"VM"|"Update"|"Image Volume"|"OS X Base System"|"macOS Base System")
                continue ;;
        esac

        local v_disk
        v_disk=$(df "$v" 2>/dev/null | tail -n 1 | awk '{print $1}')
        v_disk="${v_disk#/dev/}"
        local base_disk=$(echo "$v_disk" | sed -E 's/s[0-9]+.*//')
        local info=$(diskutil info "$base_disk" 2>/dev/null)
        local is_internal=$(echo "$info" | grep -E "Device Location|Internal" | head -n 1 | awk -F': *' '{print $2}')
        if [[ ! "$is_internal" =~ (Yes|Internal) ]]; then
            local sz=$(df -h "$v" 2>/dev/null | tail -n 1 | awk '{print $2}')
            candidates+=("$v|$sz ($base_disk)")
        fi
    done
    printf '%s\n' "${candidates[@]}"
}

menu_create_bootable_usb() {
    if [ -d "/System/Installation" ] || [ -f "/etc/rc.recovery" ] || [ -d "/Volumes/Image Volume" ]; then
        local rec_warn="NOTICE: Creating a Bootable USB via 'createinstallmedia' requires a live running macOS Desktop environment.\n\nInside macOS Recovery's minimal read-only BaseSystem, Apple restricts this tool.\n\nPlease run this feature from a normal running Mac Desktop."
        if has_gui; then
            gui_alert "Live Mac Required" "$rec_warn" "caution"
        else
            echo -e "\n${YELLOW}${BOLD}$rec_warn${NC}\n"
            pause
        fi
        return 1
    fi

    if has_gui; then
        local detected_apps=()
        while IFS= read -r line; do
            [ -n "$line" ] && detected_apps+=("$line")
        done < <(find_installed_macos_apps)

        local selected_app=""
        local app_csv="\"Browse manually for .app / .dmg...\""
        for app in "${detected_apps[@]}"; do
            local aname=$(basename "$app")
            app_csv="\"$aname ($app)\", $app_csv"
        done

        local pick
        pick=$(gui_choose_list "Create Bootable USB - Step 1/3" "Select a detected macOS installer or browse manually:" "$app_csv" "")
        [ -z "$pick" ] || [ "$pick" = "false" ] && return 0

        if [[ "$pick" =~ "Browse manually" ]]; then
            selected_app=$(gui_choose_file "Select Install macOS app or DMG:")
            [ -z "$selected_app" ] && return 0
        else
            selected_app=$(echo "$pick" | sed -E 's/.*\((.*)\)/\1/')
        fi

        if [[ "$selected_app" =~ \.dmg$ ]]; then
            gui_alert "DMG Selected" "Mounting DMG to inspect contents..." "note"
            hdiutil attach "$selected_app" -nobrowse -noverify >/tmp/dmg_mount.log 2>&1
            local inside_app
            inside_app=$(find /Volumes -maxdepth 3 -name "Install macOS*.app" 2>/dev/null | head -n 1)
            if [ -n "$inside_app" ]; then
                selected_app="$inside_app"
            else
                local pkg_found
                pkg_found=$(find /Volumes -maxdepth 3 -name "*.pkg" 2>/dev/null | head -n 1)
                if [ -n "$pkg_found" ]; then
                    gui_alert "Package Found" "Found $(basename "$pkg_found") inside DMG.\nPlease double-click this PKG on your desktop to install the app into /Applications, then run this tool again." "caution"
                    return 0
                else
                    gui_alert "Error" "No macOS installer .app found inside the selected DMG." "stop"
                    return 0
                fi
            fi
        fi

        local tool_bin="$selected_app/Contents/Resources/createinstallmedia"
        if [ ! -x "$tool_bin" ]; then
            gui_alert "Invalid Installer" "The selected application does not contain a valid createinstallmedia tool:\n$selected_app" "stop"
            return 0
        fi

        local usb_candidates=()
        while IFS= read -r line; do
            [ -n "$line" ] && usb_candidates+=("$line")
        done < <(get_usb_target_volumes)

        if [ ${#usb_candidates[@]} -eq 0 ]; then
            gui_alert "No USB Drive Found" "No external USB drives detected!\n\nPlease insert a USB flash drive (16GB or larger) and make sure it is mounted." "caution"
            return 0
        fi

        local usb_csv=""
        for item in "${usb_candidates[@]}"; do
            local vpath=$(echo "$item" | cut -d'|' -f1)
            local vdesc=$(echo "$item" | cut -d'|' -f2)
            [ -n "$usb_csv" ] && usb_csv="$usb_csv, "
            usb_csv="$usb_csv\"$vpath - $vdesc\""
        done

        local sel_usb
        sel_usb=$(gui_choose_list "Create Bootable USB - Step 2/3" "Select the target USB flash drive to wipe & make bootable:" "$usb_csv" "")
        [ -z "$sel_usb" ] || [ "$sel_usb" = "false" ] && return 0

        local target_vol=$(echo "$sel_usb" | awk -F' - ' '{print $1}')
        [ ! -d "$target_vol" ] && { gui_alert "Error" "Target volume $target_vol is no longer mounted." "stop"; return 0; }

        local app_name=$(basename "$selected_app")
        if gui_confirm "Erase & Create Bootable USB" "Target USB: $target_vol will be completely ERASED and formatted as a bootable installer for:\n\n$app_name\n\nWriting takes 10-25 minutes depending on USB speed. Proceed?" "caution" "Start Creating" "Cancel"; then
            gui_alert "Administrator Privileges" "Click OK to enter your Mac Administrator password.\nFile writing will begin. Please DO NOT unplug the USB until finished." "note"
            local cmd="\"$tool_bin\" --volume \"$target_vol\" --nointeraction"
            osascript -e "do shell script \"$cmd\" with administrator privileges" >/tmp/bootable_usb.log 2>&1
            if [ $? -eq 0 ]; then
                gui_alert "Success!" "Bootable USB created successfully for $app_name on $target_vol!" "note"
            else
                local err_log=$(tail -n 8 /tmp/bootable_usb.log)
                gui_alert "Creation Failed" "createinstallmedia encountered an error:\n\n$err_log" "stop"
            fi
        fi
    else
        safe_clear
        print_header
        echo -e "${BOLD}--- CREATE MACOS BOOTABLE USB (CLI) ---${NC}\n"

        local detected_apps=()
        while IFS= read -r line; do
            [ -n "$line" ] && detected_apps+=("$line")
        done < <(find_installed_macos_apps)

        echo -e "${CYAN}Discovered macOS Installer Applications:${NC}"
        local idx=1
        for a in "${detected_apps[@]}"; do
            echo "  [$idx] $(basename "$a") -> $a"
            ((idx++))
        done
        echo "  [$idx] Specify custom / manual path to .app"

        read -rp "Select installer option (1-$idx): " a_sel
        local selected_app=""
        if [[ "$a_sel" =~ ^[0-9]+$ ]] && [ "$a_sel" -ge 1 ] && [ "$a_sel" -lt "$idx" ]; then
            selected_app="${detected_apps[$((a_sel-1))]}"
        else
            read -rp "Enter full path to Install macOS [Name].app: " selected_app
        fi

        local tool_bin="$selected_app/Contents/Resources/createinstallmedia"
        if [ ! -x "$tool_bin" ]; then
            echo -e "${RED}Error: createinstallmedia not found at $tool_bin${NC}"
            pause
            return 1
        fi

        echo -e "\n${CYAN}Scanning for external USB flash drives...${NC}"
        local usb_candidates=()
        while IFS= read -r line; do
            [ -n "$line" ] && usb_candidates+=("$line")
        done < <(get_usb_target_volumes)

        if [ ${#usb_candidates[@]} -eq 0 ]; then
            echo -e "${RED}No external USB drives detected in /Volumes! Please connect a USB drive.${NC}"
            pause
            return 1
        fi

        echo -e "${BOLD}Available USB Drives:${NC}"
        local u_idx=1
        for u in "${usb_candidates[@]}"; do
            local vpath=$(echo "$u" | cut -d'|' -f1)
            local vdesc=$(echo "$u" | cut -d'|' -f2)
            echo "  [$u_idx] $vpath ($vdesc)"
            ((u_idx++))
        done

        read -rp "Select USB drive (1-${#usb_candidates[@]}): " u_sel
        if [[ "$u_sel" =~ ^[0-9]+$ ]] && [ "$u_sel" -ge 1 ] && [ "$u_sel" -le "${#usb_candidates[@]}" ]; then
            local target_vol=$(echo "${usb_candidates[$((u_sel-1))]}" | cut -d'|' -f1)
            echo -e "\n${RED}${BOLD}WARNING: Target volume '$target_vol' will be COMPLETELY ERASED!${NC}"
            read -rp "Type 'YES' to proceed with creating bootable USB: " c_yes
            if [ "$c_yes" = "YES" ]; then
                echo -e "${CYAN}Executing createinstallmedia (Administrator password required)...${NC}"
                sudo "$tool_bin" --volume "$target_vol" --nointeraction
                if [ $? -eq 0 ]; then
                    echo -e "\n${GREEN}${BOLD}Bootable USB created successfully!${NC}"
                else
                    echo -e "\n${RED}Failed to create bootable USB.${NC}"
                fi
            else
                echo -e "${YELLOW}Cancelled by technician.${NC}"
            fi
        else
            echo -e "${RED}Invalid USB selection.${NC}"
        fi
        pause
    fi
}

# ------------------------------------------------------------------------------
# Module 7: Advanced Security & System Utilities
# ------------------------------------------------------------------------------
menu_security() {
    if has_gui; then
        while true; do
            local choice
            choice=$(gui_choose_list "Advanced Security & Utilities" "Choose a utility task:" \
                '"1. Check SIP Status (csrutil)", "2. Reset NVRAM / PRAM (Intel)", "3. Toggle Verbose Boot Mode (-v)", "4. Check Apple Silicon Policy (bputil)", "5. Hardware Reset Reference Guide"' \
                "1. Check SIP Status (csrutil)")
            
            [ -z "$choice" ] || [ "$choice" = "false" ] && break

            case "$choice" in
                *"1."*)
                    local sip_stat
                    sip_stat=$(csrutil status 2>/dev/null || echo "csrutil not available in current shell.")
                    gui_alert "SIP Status" "$sip_stat" "note"
                    ;;
                *"2."*)
                    if [ "$IS_M_SERIES" = true ]; then
                        gui_alert "Apple Silicon Notice" "Apple Silicon Macs automatically reset NVRAM variables at reboot.\nTraditional 'nvram -c' is Intel-specific." "note"
                    elif gui_confirm "Reset NVRAM" "Reset all NVRAM variables on this Mac?" "caution" "Reset" "Cancel"; then
                        nvram -c 2>/dev/null
                        gui_alert "NVRAM Cleared" "NVRAM variables reset successfully." "note"
                    fi
                    ;;
                *"3."*)
                    if [ "$IS_M_SERIES" = true ]; then
                        gui_alert "Not Supported" "Verbose boot-args via nvram is not supported on Apple Silicon without Reduced Security." "caution"
                    else
                        local cur_args
                        cur_args=$(nvram boot-args 2>/dev/null || echo "None")
                        local vb_action
                        vb_action=$(gui_choose_buttons "Verbose Boot Mode" "Current boot-args: $cur_args\n\nSelect action:" "\"Cancel\", \"Disable Verbose\", \"Enable Verbose\"" "Enable Verbose" "note")
                        if [ "$vb_action" = "Enable Verbose" ]; then
                            nvram boot-args="-v"
                            gui_alert "Verbose Boot" "Verbose boot (-v) enabled." "note"
                        elif [ "$vb_action" = "Disable Verbose" ]; then
                            nvram -d boot-args 2>/dev/null || nvram boot-args=""
                            gui_alert "Verbose Boot" "Verbose boot disabled." "note"
                        fi
                    fi
                    ;;
                *"4."*)
                    local bp_res
                    bp_res=$(bputil -d 2>/dev/null || echo "bputil requires Apple Silicon 1TR recovery mode.")
                    gui_alert "Apple Silicon Security Policy" "$bp_res" "note"
                    ;;
                *"5."*)
                    local guide="• Intel PRAM/NVRAM: Option + Command + P + R for 20 sec at power-on.\n• Intel T2 SMC: Control + Option + Shift for 7 sec, then Power for 7 sec.\n• Apple Silicon 1TR: Press and hold Power button until 'Loading startup options' appears.\n• Apple Silicon DFU: Connect right-side USB-C to another Mac with Apple Configurator."
                    gui_alert "Hardware Reset Reference" "$guide" "note"
                    ;;
            esac
        done
    else
        while true; do
            safe_clear
            print_header
            echo -e "${BOLD}--- ADVANCED SECURITY & SYSTEM UTILITIES ---${NC}"
            echo " 1. Check SIP (System Integrity Protection) Status"
            echo " 2. Reset NVRAM / PRAM (Intel Macs)"
            echo " 3. Toggle Verbose Boot Mode (-v) on Intel"
            echo " 4. Check Apple Silicon Security Policy (bputil)"
            echo " 5. Reset SMC / PRAM Guidelines & Key Combinations"
            echo " 6. Back to Main Menu"
            echo -e "${CYAN}-----------------------------------------------------------------${NC}"
            read -rp "Select option (1-6): " sec_choice

            case $sec_choice in
                1) csrutil status 2>/dev/null || echo "csrutil not available."; pause ;;
                2)
                    [ "$IS_M_SERIES" = true ] && echo -e "${YELLOW}Notice: M-series Macs reset NVRAM automatically.${NC}"
                    if confirm_action "Reset all NVRAM variables?"; then
                        nvram -c 2>/dev/null && echo -e "${GREEN}NVRAM cleared.${NC}"
                    fi
                    pause
                    ;;
                3)
                    read -rp "1. Enable Verbose (-v) | 2. Disable Verbose: " v_sel
                    [ "$v_sel" = "1" ] && nvram boot-args="-v"
                    [ "$v_sel" = "2" ] && { nvram -d boot-args 2>/dev/null || nvram boot-args=""; }
                    pause
                    ;;
                4) bputil -d 2>/dev/null || echo "Requires Apple Silicon 1TR recovery."; pause ;;
                5)
                    echo "Intel PRAM: Opt+Cmd+P+R (20s)"
                    echo "Apple Silicon: Hold Power button for 1TR"
                    pause
                    ;;
                6) break ;;
                *) echo -e "${RED}Invalid selection.${NC}"; sleep 1 ;;
            esac
        done
    fi
}

menu_about() {
    if has_gui; then
        local about_txt="🍏 OxLogic Mac Recovery Toolkit (MRTK) v1.0.0\n"
        about_txt+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        about_txt+="Lead Developer: Md Tazmir (@mdtazmir1)\n"
        about_txt+="Facebook: https://www.facebook.com/muhammadtazmir\n"
        about_txt+="Organization: OxLogic (https://github.com/oxlogic)\n"
        about_txt+="Repository: https://github.com/oxlogic/mac-recovery-toolkit\n"
        about_txt+="Support / Donate: https://buymeacoffee.com/mdtazmir\n\n"
        about_txt+="⚙️ HYBRID DUAL-ENGINE ARCHITECTURE:\n"
        about_txt+="• Frontend: Native AppleScript Cocoa Dialogs & Controls\n"
        about_txt+="• Backend: 100% Native Darwin/Unix Shell Commands\n"
        about_txt+="• Zero Dependencies: No Python, Homebrew, or External Binaries\n\n"
        about_txt+="🖥️ DUAL EXECUTION MODES:\n"
        about_txt+="• Live macOS: 1-Click GUI Window Suite via Launch_Mac_Recovery_Toolkit.command\n"
        about_txt+="• Recovery Mode: Direct Terminal CLI Menu (Root / Single-User Compatible)\n\n"
        about_txt+="⚖️ LEGAL DISCLAIMER & LIABILITY:\n"
        about_txt+="MIT License. Provided 'AS IS'. Md Tazmir & OxLogic assume zero liability for data loss."
        
        gui_alert "About OxLogic MRTK" "$about_txt" "note"
    else
        safe_clear
        print_header
        echo -e "${BOLD}                ABOUT OXLOGIC MRTK & ARCHITECTURE${NC}"
        echo -e "${CYAN}-----------------------------------------------------------------${NC}"
        echo -e " ${BOLD}Tool:${NC}         OxLogic Mac Recovery Toolkit (MRTK) v1.0.0"
        echo -e " ${BOLD}Developer:${NC}    Md Tazmir (@mdtazmir1)"
        echo -e " ${BOLD}Facebook:${NC}     https://www.facebook.com/muhammadtazmir"
        echo -e " ${BOLD}Organization:${NC} OxLogic (https://github.com/oxlogic)"
        echo -e " ${BOLD}Repository:${NC}   https://github.com/oxlogic/mac-recovery-toolkit"
        echo -e " ${BOLD}Support / Donate:${NC} ${YELLOW}https://buymeacoffee.com/mdtazmir${NC}"
        echo -e "${CYAN}-----------------------------------------------------------------${NC}"
        echo -e " ${BOLD}HYBRID ENGINE ARCHITECTURE:${NC}"
        echo -e " • ${GREEN}Dual-Mode Interface:${NC} Native AppleScript GUI in Live macOS"
        echo -e "   and 100% Standalone CLI Terminal Menu in macOS Recovery Mode."
        echo -e " • ${GREEN}Backend Power:${NC} Directly executes native macOS Darwin commands"
        echo -e "   (diskutil, gpt, rsync, sntp, scselect, nvram, bputil, createinstallmedia)."
        echo -e " • ${GREEN}Zero Dependencies:${NC} Pure POSIX/Bash. Does NOT require Homebrew,"
        echo -e "   Python, Node.js, or external binaries. Runs anywhere off USB."
        echo -e " • ${GREEN}Cross-Architecture:${NC} Native Intel (x86_64) & Apple Silicon (ARM64)."
        echo -e "${CYAN}-----------------------------------------------------------------${NC}"
        echo -e " ${YELLOW}LEGAL DISCLAIMER & ZERO LIABILITY:${NC}"
        echo -e " Licensed under MIT. Provided 'AS IS' without warranty of any kind."
        echo -e " Md Tazmir & OxLogic assume NO liability for data loss or hardware issues."
        echo -e "${CYAN}=================================================================${NC}"
        pause
    fi
}

# ------------------------------------------------------------------------------
# Main Application Loop (GUI First with CLI Fallback)
# ------------------------------------------------------------------------------
detect_system_info

while true; do
    if has_gui; then
        gui_prompt="Model: $MODEL_ID | Arch: $CHIP_PLAIN\nEnvironment: $ENV_PLAIN | OS: $OS_VERSION\n\nChoose an action:"
        main_sel=$(gui_choose_list "OxLogic Mac Recovery Toolkit (MRTK)" "$gui_prompt" \
            '"1. Hardware Diagnostics & Health (SMART, Battery, Specs)", "2. Network & Wi-Fi Management (Scan, Connect, Ping)", "3. Date & Time Synchronization (Certificate Fix, sntp)", "4. Smart Disk Manager & Format (Safe APFS/JHFS+)", "5. Emergency User Data Backup (Pre-Wipe Triage)", "6. macOS Installer & Deployment (USB Auto-Detect, startosinstall)", "7. Create Bootable USB Installer (Auto-Detect .app, Browse)", "8. Advanced Security & NVRAM (SIP, Verbose Boot, bputil)", "9. Switch to Terminal CLI Mode", "10. About OxLogic MRTK & Architecture", "11. Exit Suite"' \
            "5. Emergency User Data Backup (Pre-Wipe Triage)")

        [ -z "$main_sel" ] || [ "$main_sel" = "false" ] && break

        case "$main_sel" in
            *"1."*) menu_diagnostics ;;
            *"2."*) menu_network ;;
            *"3."*) menu_date ;;
            *"4."*) menu_disks ;;
            *"5."*) menu_backup_data ;;
            *"6."*) menu_installer ;;
            *"7."*) menu_create_bootable_usb ;;
            *"8."*) menu_security ;;
            *"9."*) FORCE_CLI=1 ;;
            *"10."*) menu_about ;;
            *"11."*) exit 0 ;;
        esac
    else
        safe_clear
        print_header
        echo -e "${BOLD}                     MAIN MENU${NC}"
        echo -e "${CYAN}-----------------------------------------------------------------${NC}"
        echo -e " ${BOLD}1.${NC} Hardware Diagnostics & Health  ${CYAN}(SMART SSD, Battery, CPU, RAM)${NC}"
        echo -e " ${BOLD}2.${NC} Network & Wi-Fi Management     ${CYAN}(Scan, Connect, Apple Ping Test)${NC}"
        echo -e " ${BOLD}3.${NC} Date & Time Synchronization    ${CYAN}(Certificate Fix, sntp, ntpdate)${NC}"
        echo -e " ${BOLD}4.${NC} Smart Disk Manager & Format    ${CYAN}(Safe APFS/JHFS+, Internal/External)${NC}"
        echo -e " ${BOLD}5.${NC} Emergency User Data Backup     ${CYAN}(Pre-Wipe Triage, Resumable Rsync)${NC}"
        echo -e " ${BOLD}6.${NC} macOS Installer & Deployment   ${CYAN}(USB Auto-Detect, startosinstall, CDN)${NC}"
        echo -e " ${BOLD}7.${NC} Create Bootable USB Installer  ${CYAN}(Auto-detect .app, Finder Browse)${NC}"
        echo -e " ${BOLD}8.${NC} Advanced Security & NVRAM      ${CYAN}(SIP, NVRAM Reset, Verbose Boot, bputil)${NC}"
        echo -e " ${BOLD}9.${NC} Switch to GUI Mode             ${CYAN}(Return to native dialog windows)${NC}"
        echo -e " ${BOLD}10.${NC} About OxLogic MRTK            ${CYAN}(Architecture, Specs, Lead Developer)${NC}"
        echo -e " ${BOLD}11.${NC} Exit Suite"
        echo -e "${CYAN}=================================================================${NC}"
        read -rp "Select module (1-11): " main_choice

        case $main_choice in
            1) menu_diagnostics ;;
            2) menu_network ;;
            3) menu_date ;;
            4) menu_disks ;;
            5) menu_backup_data ;;
            6) menu_installer ;;
            7) menu_create_bootable_usb ;;
            8) menu_security ;;
            9)
                FORCE_CLI=0
                if ! has_gui; then
                    echo -e "\n${RED}Notice: AppleScript GUI Dialogs cannot interact with WindowServer in this shell.${NC}"
                    echo -e "${YELLOW}Reason: macOS Recovery BaseSystem restricts GUI window creation for root.${NC}"
                    echo "Remaining in Terminal CLI Mode."
                    pause
                fi
                ;;
            10) menu_about ;;
            11)
                echo -e "\n${GREEN}Exiting OxLogic Mac Recovery Toolkit. Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please enter 1-11.${NC}"
                sleep 1
                ;;
        esac
    fi
done