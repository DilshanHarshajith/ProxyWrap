#!/bin/bash

# ============================================
#   ProxyWrap - Advanced ProxyChains Tool
# ============================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

TMP_CONF=$(mktemp)
CHAIN_TYPE="strict_chain"
PROXY_DNS="proxy_dns"
PROXIES=()
CMD=()
DRY_RUN=0
INTERACTIVE=0
PROFILE=""
RETRY=0
DELAY=0
VALIDATE=0
VALIDATION_URL="http://ifconfig.me"

CONFIG_DIR="$HOME/.proxywrap"
mkdir -p "$CONFIG_DIR"

# ========== Color Codes ==========
if [[ -t 1 ]]; then  # Only use colors if stdout is a terminal
    GREEN="\033[1;32m"
    RED="\033[1;31m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;34m"
    NC="\033[0m"
else
    GREEN="" RED="" YELLOW="" BLUE="" NC=""
fi

# ========== Functions ==========

cleanup() {
    [[ -f "$TMP_CONF" ]] && rm -f "$TMP_CONF"
}
trap cleanup EXIT

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $*${NC}"
}

err() {
    echo -e "${RED}[ERROR] $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $*${NC}" >&2
}

usage() {
    cat <<EOF
Usage: $0 [options] -- <command>

Options:
  -p <proxy>           Add proxy (format: "socks5 127.0.0.1 9050")
  -P <file>            Load proxies from file
  -r                   Use random_chain instead of strict_chain
  -n                   Disable proxy_dns
  -i                   Interactive proxy selection
  -d                   Dry-run mode (don't execute command)
  --retry <N>          Retry the command N times if it fails (default: 0)
  --delay <sec>        Random delay between proxies (default: 0)
  --profile <name>     Load/save a proxy profile
  --validate           Validate proxies before use
  --export <file>      Export proxychains config to file
  --timeout <sec>      Connection timeout for validation (default: 5)
  --list-profiles      List available profiles
  --remove-profile <name>  Remove a profile
  -v, --verbose        Verbose output
  -h, --help           Show this help menu

Proxy formats:
  socks4 <host> <port>
  socks5 <host> <port>
  http <host> <port>

Examples:
  $0 -p "socks5 127.0.0.1 9050" -- curl http://ifconfig.me
  $0 -r -P proxies.txt -- curl http://ifconfig.me
  $0 --profile myvpn --validate -i -- firefox
  $0 --list-profiles
EOF
    exit 1
}

validate_proxy() {
    local proto=$1 host=$2 port=$3 timeout=${4:-5}
    
    # Validate proxy format
    if [[ ! "$proto" =~ ^(socks4|socks5|http)$ ]]; then
        echo -e "  ${RED}❌ Invalid protocol: $proto${NC}"
        return 1
    fi
    
    # Validate port number
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        echo -e "  ${RED}❌ Invalid port: $port${NC}"
        return 1
    fi
    
    # Test connection
    if timeout "$timeout" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "  ${GREEN}✅ $proto $host $port${NC}"
        return 0
    else
        echo -e "  ${RED}❌ $proto $host $port (connection failed)${NC}"
        return 1
    fi
}

load_profile() {
    local profile_name="$1"
    local path="$CONFIG_DIR/$profile_name.profile"
    
    if [[ ! -f "$path" ]]; then
        err "Profile not found: $profile_name"
        return 1
    fi
    
    log "Loading profile: $profile_name"
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]] && continue
        
        # Validate proxy format
        if [[ ! "$line" =~ ^(socks4|socks5|http)[[:space:]]+[^[:space:]]+[[:space:]]+[0-9]+$ ]]; then
            warn "Invalid proxy format at line $line_num in profile $profile_name: $line"
            continue
        fi
        
        PROXIES+=("$line")
    done < "$path"
    
    [[ ${#PROXIES[@]} -eq 0 ]] && { err "No valid proxies found in profile: $profile_name"; return 1; }
    log "Loaded ${#PROXIES[@]} proxy(ies) from profile"
}

save_profile() {
    [[ -z "$PROFILE" ]] && return
    local path="$CONFIG_DIR/$PROFILE.profile"
    log "Saving current proxies to profile: $PROFILE"
    
    {
        echo "# ProxyWrap profile: $PROFILE"
        echo "# Created: $(date)"
        echo "# Format: protocol host port"
        echo ""
        printf "%s\n" "${PROXIES[@]}"
    } > "$path"
    
    log "Profile saved with ${#PROXIES[@]} proxy(ies)"
}

list_profiles() {
    local name
    local count
    log "Available profiles:"
    if ls "$CONFIG_DIR"/*.profile >/dev/null 2>&1; then
        for profile in "$CONFIG_DIR"/*.profile; do
            name=$(basename "$profile" .profile)
            count=$(grep -c "^[^#]" "$profile" 2>/dev/null || echo "0")
            echo "  $name ($count proxies)"
        done
    else
        echo "  No profiles found"
    fi
    exit 0
}

remove_profile() {
    local profile_name="$1"
    local path="$CONFIG_DIR/$profile_name.profile"
    
    if [[ -f "$path" ]]; then
        rm -f "$path"
        log "Profile removed: $profile_name"
    else
        err "Profile not found: $profile_name"
        exit 1
    fi
    exit 0
}

interactive_select() {
    log "Interactive mode: select proxy to use"
    echo
    
    if [[ ${#PROXIES[@]} -eq 0 ]]; then
        err "No proxies available for selection"
        exit 1
    fi
    
    PS3="Select proxy (or 'Use All'): "
    select proxy in "${PROXIES[@]}" "Use All"; do
        if [[ "$REPLY" == "$(( ${#PROXIES[@]} + 1 ))" ]]; then
            log "Using all proxies"
            return
        elif [[ -n "${PROXIES[$REPLY-1]:-}" ]]; then
            log "Selected: ${PROXIES[$REPLY-1]}"
            PROXIES=("${PROXIES[$REPLY-1]}")
            return
        else
            echo "Invalid choice. Please try again."
        fi
    done
}

build_config() {
    {
        echo "# ProxyWrap generated configuration"
        echo "# Generated: $(date)"
        echo ""
        echo "$CHAIN_TYPE"
        [[ -n "$PROXY_DNS" ]] && echo "$PROXY_DNS"
        echo "tcp_read_time_out 15000"
        echo "tcp_connect_time_out 8000"
        echo ""
        echo "[ProxyList]"
        for proxy in "${PROXIES[@]}"; do
            echo "$proxy"
        done
    } > "$TMP_CONF"
}

export_config() {
    local file="$1"
    build_config
    cp "$TMP_CONF" "$file"
    log "Config exported to $file"
    exit 0
}

run_command() {
    local tries=0
    local max_tries=$((RETRY + 1))
    
    while [[ $tries -lt $max_tries ]]; do
        if [[ $tries -gt 0 ]]; then
            log "Attempt $((tries + 1))/$max_tries"
        fi
        
        log "Executing: ${CMD[*]}"
        
        if proxychains -f "$TMP_CONF" "${CMD[@]}"; then
            log "Command executed successfully"
            return 0
        else
            local exit_code=$?
            tries=$((tries + 1))
            
            if [[ $tries -lt $max_tries ]]; then
                warn "Command failed (exit code: $exit_code). Retrying in 2 seconds..."
                sleep 2
            else
                err "Command failed after $max_tries attempts (exit code: $exit_code)"
                return $exit_code
            fi
        fi
    done
}

# ========== Argument Parsing ==========

PROXY_SETUP_PROVIDED=0
VERBOSE=0
TIMEOUT=5

while [[ $# -gt 0 ]]; do
    case $1 in
        -p) 
            if [[ -z "${2:-}" ]]; then
                err "Option -p requires an argument"
                exit 1
            fi
            PROXIES+=("$2")
            PROXY_SETUP_PROVIDED=1
            shift 2
            ;;
        -P)
            if [[ -z "${2:-}" ]]; then
                err "Option -P requires an argument"
                exit 1
            fi
            if [[ ! -f "$2" ]]; then
                err "Proxy file not found: $2"
                exit 1
            fi
            line_num=0
            while IFS= read -r line; do
                line_num=$((line_num + 1))
                [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]] && continue
                
                # Validate proxy format
                if [[ ! "$line" =~ ^(socks4|socks5|http)[[:space:]]+[^[:space:]]+[[:space:]]+[0-9]+$ ]]; then
                    warn "Invalid proxy format at line $line_num in $2: $line"
                    continue
                fi
                
                PROXIES+=("$line")
            done < "$2"
            PROXY_SETUP_PROVIDED=1
            shift 2
            ;;
        -r) CHAIN_TYPE="random_chain"; shift ;;
        -n) PROXY_DNS=""; shift ;;
        -i) INTERACTIVE=1; shift ;;
        -d) DRY_RUN=1; shift ;;
        --retry) 
            if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
                err "Option --retry requires a numeric argument"
                exit 1
            fi
            RETRY="$2"
            shift 2
            ;;
        --delay) 
            if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
                err "Option --delay requires a numeric argument"
                exit 1
            fi
            DELAY="$2"
            shift 2
            ;;
        --timeout)
            if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
                err "Option --timeout requires a numeric argument"
                exit 1
            fi
            TIMEOUT="$2"
            shift 2
            ;;
        --validate) VALIDATE=1; shift ;;
        --profile) 
            if [[ -z "${2:-}" ]]; then
                err "Option --profile requires an argument"
                exit 1
            fi
            PROFILE="$2"
            shift 2
            ;;
        --export) 
            if [[ -z "${2:-}" ]]; then
                err "Option --export requires an argument"
                exit 1
            fi
            export_config "$2"
            ;;
        --list-profiles) list_profiles ;;
        --remove-profile)
            if [[ -z "${2:-}" ]]; then
                err "Option --remove-profile requires an argument"
                exit 1
            fi
            remove_profile "$2"
            ;;
        -v|--verbose) VERBOSE=1; shift ;;
        --) shift; CMD=("$@"); break ;;
        -h|--help) usage ;;
        *) err "Unknown option: $1"; usage ;;
    esac
done

# ========== Dependency Check ==========
if ! command -v proxychains >/dev/null 2>&1; then
    err "proxychains is not installed or not in PATH"
    exit 1
fi

# ========== Profile Logic ==========
# Only load profile if no proxy setup was provided
if [[ -n "$PROFILE" && $PROXY_SETUP_PROVIDED -eq 0 ]]; then
    load_profile "$PROFILE"
fi

# ========== Validation ==========
if [[ ${#PROXIES[@]} -eq 0 ]]; then
    err "No proxies specified. Use -p, -P, or --profile to add proxies."
    usage
fi

if [[ ${#CMD[@]} -eq 0 ]]; then
    err "No command specified. Use -- followed by the command to run."
    usage
fi

[[ $INTERACTIVE -eq 1 ]] && interactive_select

# ========== Validate Proxies ==========
if [[ $VALIDATE -eq 1 ]]; then
    log "Validating proxies (timeout: ${TIMEOUT}s)..."
    VALID_PROXIES=()
    
    for proxy in "${PROXIES[@]}"; do
        IFS=' ' read -r proto host port <<< "$proxy"
        if validate_proxy "$proto" "$host" "$port" "$TIMEOUT"; then
            VALID_PROXIES+=("$proxy")
        fi
        
        # Random delay between validation attempts
        [[ $DELAY -gt 0 ]] && sleep $((RANDOM % DELAY + 1))
    done
    
    PROXIES=("${VALID_PROXIES[@]}")
    
    if [[ ${#PROXIES[@]} -eq 0 ]]; then
        err "No working proxies found after validation!"
        exit 1
    fi
    
    log "Validation complete: ${#PROXIES[@]} working proxy(ies)"
fi

# ========== Summary ==========
log "Configuration Summary:"
log "  Chain Type: $CHAIN_TYPE"
{ [[ -n "$PROXY_DNS" ]] && log "  DNS over proxy: Enabled" ; } || log "  DNS over proxy: Disabled"
log "  Active proxies: ${#PROXIES[@]}"
log "  Retry attempts: $RETRY"
[[ $DELAY -gt 0 ]] && log "  Delay between proxies: ${DELAY}s"

if [[ $VERBOSE -eq 1 ]]; then
    log "Active proxies:"
    for proxy in "${PROXIES[@]}"; do
        echo "    $proxy"
    done
fi

# ========== Dry Run ==========
if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}[DRY RUN] Configuration file:${NC}"
    cat "$TMP_CONF"
    echo -e "${YELLOW}[DRY RUN] Would execute:${NC}"
    echo "proxychains -f $TMP_CONF ${CMD[*]}"
    exit 0
fi

# ========== Save Profile + Run ==========
save_profile
build_config

# Show config in verbose mode
if [[ $VERBOSE -eq 1 ]]; then
    log "Generated proxychains config:"
    cat "$TMP_CONF"
fi

run_command