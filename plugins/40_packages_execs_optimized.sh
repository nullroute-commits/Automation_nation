#!/bin/bash
# Optimized package and executable information plugin
# Minimizes dependencies and optimizes for runtime execution speed
# Focuses on essential package information with minimal external tool usage

ARCH="$1"

# Optimized configuration limits for speed
MAX_PACKAGES=${MAX_PACKAGES:-15}  # Reduced for faster execution
MAX_EXECUTABLES=${MAX_EXECUTABLES:-10}  # Reduced for faster execution
USE_FAST_MODE=${USE_FAST_MODE:-1}  # Enable fast mode by default

get_packages_and_executables() {
    local packages_info
    local executables_info
    
    if [ "$USE_FAST_MODE" = "1" ]; then
        # Fast mode: minimal package detection
        packages_info=$(collect_packages_fast)
        executables_info=$(collect_executables_fast)
    else
        # Standard mode: comprehensive detection
        packages_info=$(collect_packages)
        executables_info=$(collect_executables)
    fi
    
    # Output combined JSON
    cat << EOF
{
  "installed_packages": $packages_info,
  "system_executables": $executables_info,
  "architecture": "$ARCH",
  "collection_mode": "$([ "$USE_FAST_MODE" = "1" ] && echo "fast" || echo "standard")"
}
EOF
}

# Fast package collection with minimal dpkg usage
collect_packages_fast() {
    local packages_json="["
    local first=true
    local count=0
    
    # Only check essential system packages for minimal dependency footprint
    local essential_packages=("libc6" "bash" "coreutils" "systemd" "kernel" "python3" "openssh")
    
    # Use dpkg-query only if absolutely necessary and available
    if command -v dpkg-query >/dev/null 2>&1; then
        for pkg in "${essential_packages[@]}"; do
            if [ $count -ge $MAX_PACKAGES ]; then
                break
            fi
            
            # Quick check for package existence
            if dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' "$pkg*" 2>/dev/null | head -1 | grep -q "install ok installed"; then
                local package_info=$(dpkg-query -W -f='${Package}\t${Version}\n' "$pkg*" 2>/dev/null | head -1)
                local package_name=$(echo "$package_info" | cut -f1)
            local dpkg_output=$(dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' "$pkg*" 2>/dev/null | head -1)
            if echo "$dpkg_output" | grep -q "install ok installed"; then
                local package_name=$(echo "$dpkg_output" | cut -f1)
                local package_version=$(echo "$dpkg_output" | cut -f2)
                
                if [ -n "$package_name" ] && [ -n "$package_version" ]; then
                    if [ "$first" = false ]; then
                        packages_json+=","
                    fi
                    first=false
                    
                    # Escape quotes in version strings
                    package_version=$(echo "$package_version" | sed 's/"/\\"/g')
                    
                    packages_json+='{"name":"'$package_name'","version":"'$package_version'","manager":"dpkg","essential":true}'
                    ((count++))
                fi
            fi
        done
    else
        # Fallback: try alternative package managers with minimal calls
        if command -v rpm >/dev/null 2>&1; then
            for pkg in "${essential_packages[@]}"; do
                if [ $count -ge $MAX_PACKAGES ]; then
                    break
                fi
                
                local rpm_info=$(rpm -q "$pkg" 2>/dev/null | head -1)
                if [[ ! "$rpm_info" =~ "not installed" ]] && [ -n "$rpm_info" ]; then
                    local package_name=$(echo "$rpm_info" | sed 's/-[0-9].*//')
                    local package_version=$(echo "$rpm_info" | sed 's/.*-\([0-9].*\)/\1/')
                    
                    if [ "$first" = false ]; then
                        packages_json+=","
                    fi
                    first=false
                    
                    packages_json+='{"name":"'$package_name'","version":"'$package_version'","manager":"rpm","essential":true}'
                    ((count++))
                fi
            done
        fi
    fi
    
    packages_json+="]"
    echo "$packages_json"
}

# Standard comprehensive package collection (original logic)
collect_packages() {
    local packages_json="["
    local first=true
    local count=0
    
    # Debian/Ubuntu (apt/dpkg) - optimized query
    if command -v dpkg-query >/dev/null 2>&1; then
        # Use more efficient dpkg-query instead of dpkg
        while IFS=$'\t' read -r package version status; do
            if [[ "$status" =~ "install ok installed" ]] && [ $count -lt $MAX_PACKAGES ]; then
                if [ "$first" = false ]; then
                    packages_json+=","
                fi
                first=false
                
                # Escape quotes in version strings
                version_escaped=$(echo "$version" | sed 's/"/\\"/g')
                
                packages_json+='{"name":"'$package'","version":"'$version_escaped'","manager":"dpkg","status":"installed"}'
                ((count++))
            fi
        done < <(dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null | head -$MAX_PACKAGES)
    
    # Red Hat/CentOS/Fedora (rpm) - optimized query
    elif command -v rpm >/dev/null 2>&1; then
        while read -r line; do
            if [ $count -lt $MAX_PACKAGES ]; then
                local package=$(echo "$line" | awk '{print $1}')
                local version=$(echo "$line" | awk '{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
                
                if [ "$first" = false ]; then
                    packages_json+=","
                fi
                first=false
                
                # Escape quotes in version strings
                version_escaped=$(echo "$version" | sed 's/"/\\"/g')
                
                packages_json+='{"name":"'$package'","version":"'$version_escaped'","manager":"rpm","status":"installed"}'
                ((count++))
            fi
        done < <(rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}\n' 2>/dev/null | head -$MAX_PACKAGES)
    
    # Alpine Linux (apk)
    elif command -v apk >/dev/null 2>&1; then
        while read -r line; do
            if [ $count -lt $MAX_PACKAGES ]; then
                local package=$(echo "$line" | awk '{print $1}')
                local version=$(echo "$line" | awk '{print $2}')
                
                if [ "$first" = false ]; then
                    packages_json+=","
                fi
                first=false
                
                packages_json+='{"name":"'$package'","version":"'$version'","manager":"apk","status":"installed"}'
                ((count++))
            fi
        done < <(apk list -I 2>/dev/null | head -$MAX_PACKAGES | awk -F' ' '{print $1, $2}')
    fi
    
    packages_json+="]"
    echo "$packages_json"
}

# Fast executable collection with minimal filesystem scanning
collect_executables_fast() {
    local executables_json="["
    local first=true
    local count=0
    
    # Only check essential system executables for speed
    local essential_execs=("bash" "sh" "python3" "systemctl" "ssh" "curl" "wget" "git")
    
    for exec_name in "${essential_execs[@]}"; do
        if [ $count -ge $MAX_EXECUTABLES ]; then
            break
        fi
        
        local exec_path=$(command -v "$exec_name" 2>/dev/null)
        if [ -n "$exec_path" ] && [ -x "$exec_path" ]; then
            if [ "$first" = false ]; then
                executables_json+=","
            fi
            first=false
            
            # Quick version detection
            local version="unknown"
            case "$exec_name" in
                "bash") version=$($exec_path --version 2>/dev/null | head -1 | awk '{print $4}') ;;
                "python3") version=$($exec_path --version 2>/dev/null | awk '{print $2}') ;;
                "git") version=$($exec_path --version 2>/dev/null | awk '{print $3}') ;;
                "ssh") version=$($exec_path -V 2>&1 | head -1 | awk '{print $1}') ;;
                *) version="present" ;;
            esac
            
            executables_json+='{"name":"'$exec_name'","path":"'$exec_path'","version":"'$version'","essential":true}'
            ((count++))
        fi
    done
    
    executables_json+="]"
    echo "$executables_json"
}

# Standard comprehensive executable collection
collect_executables() {
    local executables_json="["
    local first=true
    local count=0
    
    # Define common paths to scan - optimized order
    local search_paths="/usr/bin /bin /usr/local/bin"
    
    # Use find with limits for better performance
    for path in $search_paths; do
        if [ $count -ge $MAX_EXECUTABLES ]; then
            break
        fi
        
        if [ -d "$path" ]; then
            while IFS= read -r -d '' executable; do
                if [ $count -ge $MAX_EXECUTABLES ]; then
                    break
                fi
                
                local basename_exec=$(basename "$executable")
                
                # Skip if already processed
                if echo "$executables_json" | grep -q "\"$basename_exec\""; then
                    continue
                fi
                
                if [ "$first" = false ]; then
                    executables_json+=","
                fi
                first=false
                
                # Quick version detection for common tools
                local version="unknown"
                case "$basename_exec" in
                    "bash") version=$("$executable" --version 2>/dev/null | head -1 | awk '{print $4}') ;;
                    "python3") version=$("$executable" --version 2>/dev/null | awk '{print $2}') ;;
                    "git") version=$("$executable" --version 2>/dev/null | awk '{print $3}') ;;
                    "vim") version=$("$executable" --version 2>/dev/null | head -1 | awk '{print $5}') ;;
                    *) version="present" ;;
                esac
                
                executables_json+='{"name":"'$basename_exec'","path":"'$executable'","version":"'$version'"}'
                ((count++))
                
            done < <(find "$path" -maxdepth 1 -type f -executable -printf '%p\0' 2>/dev/null | head -z -$((MAX_EXECUTABLES - count)))
        fi
    done
    
    executables_json+="]"
    echo "$executables_json"
}

# Execute main function
get_packages_and_executables