#!/bin/bash

# Dynamic PHP-FPM Pool Configuration
# This script calculates and sets optimal PHP-FPM pool settings based on container resources
# To be run during container startup

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "[INFO] $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Detect container memory limit
detect_memory_limit() {
    local memory_limit_mb="unknown"
    
    # Try cgroups v2 first
    if [ -f /sys/fs/cgroup/memory.max ]; then
        local mem_bytes
        mem_bytes=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
        if [ "$mem_bytes" != "max" ]; then
            memory_limit_mb=$((mem_bytes / 1024 / 1024))
        fi
    # Then try cgroups v1
    elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        local mem_bytes
        mem_bytes=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        if [ "$mem_bytes" != "9223372036854771712" ]; then
            memory_limit_mb=$((mem_bytes / 1024 / 1024))
        fi
    fi
    
    # If still unknown, try to use total system memory
    if [ "$memory_limit_mb" = "unknown" ] && [ -f /proc/meminfo ]; then
        local total_memory_kb
        total_memory_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        memory_limit_mb=$((total_memory_kb / 1024))
    fi
    
    echo "$memory_limit_mb"
}

# Detect CPU cores
detect_cpu_cores() {
    local cpu_cores
    
    # Try to get CPU quota from cgroups
    if [ -f /sys/fs/cgroup/cpu.max ]; then
        # cgroups v2
        local quota period
        read -r quota period < /sys/fs/cgroup/cpu.max
        if [ "$quota" != "max" ]; then
            cpu_cores=$((quota / period))
        fi
    elif [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -f /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
        # cgroups v1
        local quota period
        quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
        period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
        if [ "$quota" != "-1" ]; then
            cpu_cores=$((quota / period))
        fi
    fi
    
    # If still not set, use nproc
    if [ -z "$cpu_cores" ] || [ "$cpu_cores" -eq 0 ]; then
        cpu_cores=$(nproc)
    fi
    
    echo "$cpu_cores"
}

# Calculate optimal PHP-FPM settings
calculate_fpm_settings() {
    local memory_limit_mb=$1
    local cpu_cores=$2
    local avg_process_memory=${3:-25} # Default to 25MB if not provided
    
    # Define system overhead
    local system_overhead=100
    local apache_overhead=150
    local supervisor_overhead=20
    local other_services=50
    
    local total_overhead=$((system_overhead + apache_overhead + supervisor_overhead + other_services))
    local available_for_fpm=$((memory_limit_mb - total_overhead))
    
    if [ "$available_for_fpm" -lt 100 ]; then
        log_error "Insufficient memory for PHP-FPM (${available_for_fpm}MB available)"
        # Use minimal settings
        echo "5 1 1 3"
        return
    fi
    
    # Calculate optimal max_children
    local optimal_max_children=$((available_for_fpm / avg_process_memory))
    
    # Adjust based on CPU cores to prevent CPU oversubscription
    local cpu_based_limit=$((cpu_cores * 6))
    if [ "$optimal_max_children" -gt "$cpu_based_limit" ]; then
        optimal_max_children=$cpu_based_limit
    fi
    
    # Calculate other settings
    local optimal_start_servers=$((optimal_max_children / 4))
    local optimal_min_spare=$((optimal_max_children / 6))
    local optimal_max_spare=$((optimal_max_children / 3))
    
    # Ensure minimum values
    if [ "$optimal_start_servers" -lt 1 ]; then optimal_start_servers=1; fi
    if [ "$optimal_min_spare" -lt 1 ]; then optimal_min_spare=1; fi
    if [ "$optimal_max_spare" -lt 2 ]; then optimal_max_spare=2; fi
    
    # Return the calculated values
    echo "$optimal_max_children $optimal_start_servers $optimal_min_spare $optimal_max_spare"
}

# Update PHP-FPM pool configuration
update_pool_config() {
    local config_file=$1
    local max_children=$2
    local start_servers=$3
    local min_spare=$4
    local max_spare=$5
    
    # Create backup
    cp "$config_file" "${config_file}.bak"
    
    # Update settings
    sed -i "s/^pm\.max_children\s*=.*/pm.max_children = $max_children/" "$config_file"
    sed -i "s/^pm\.start_servers\s*=.*/pm.start_servers = $start_servers/" "$config_file"
    sed -i "s/^pm\.min_spare_servers\s*=.*/pm.min_spare_servers = $min_spare/" "$config_file"
    sed -i "s/^pm\.max_spare_servers\s*=.*/pm.max_spare_servers = $max_spare/" "$config_file"
    
    log_success "Updated pool configuration in $config_file"
    log_info "  pm.max_children = $max_children"
    log_info "  pm.start_servers = $start_servers"
    log_info "  pm.min_spare_servers = $min_spare"
    log_info "  pm.max_spare_servers = $max_spare"
}

# Main function
main() {
    log_info "Starting dynamic PHP-FPM pool configuration"
    
    # Detect system resources
    local memory_limit_mb
    memory_limit_mb=$(detect_memory_limit)
    log_info "Detected memory limit: ${memory_limit_mb}MB"
    
    local cpu_cores
    cpu_cores=$(detect_cpu_cores)
    log_info "Detected CPU cores: $cpu_cores"
    
    # PHP-FPM configuration file for PHP 7.2 in Debian
    local config_file="/etc/php/7.2/fpm/pool.d/www.conf"
    
    if [ ! -f "$config_file" ]; then
        log_error "PHP-FPM configuration file not found: $config_file"
        exit 1
    fi
    
    log_info "Using PHP-FPM configuration file: $config_file"
    
    # Determine average PHP-FPM process memory
    local avg_process_memory=25  # Default value
    
    # Try to get actual average from running processes
    local fpm_processes
    fpm_processes=$(pgrep -f "php-fpm" 2>/dev/null || pgrep -f "php.*fpm" 2>/dev/null || true)
    
    if [ -n "$fpm_processes" ]; then
        local total_memory=0
        local process_count=0
        
        for pid in $fpm_processes; do
            local proc_memory
            proc_memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1/1024}' || echo "0")
            if [ "$proc_memory" != "0" ]; then
                total_memory=$(echo "$total_memory + $proc_memory" | bc)
                process_count=$((process_count + 1))
            fi
        done
        
        if [ "$process_count" -gt 0 ]; then
            avg_process_memory=$(echo "scale=0; $total_memory / $process_count" | bc)
            log_info "Detected average PHP-FPM process memory: ${avg_process_memory}MB"
        fi
    else
        log_info "Using default average PHP-FPM process memory: ${avg_process_memory}MB"
    fi
    
    # Calculate optimal settings
    log_info "Calculating optimal PHP-FPM settings..."
    local settings
    settings=$(calculate_fpm_settings "$memory_limit_mb" "$cpu_cores" "$avg_process_memory")
    
    read -r max_children start_servers min_spare max_spare <<< "$settings"
    log_info "Calculated optimal settings:"
    log_info "  pm.max_children = $max_children"
    log_info "  pm.start_servers = $start_servers"
    log_info "  pm.min_spare_servers = $min_spare"
    log_info "  pm.max_spare_servers = $max_spare"
    
    # Update pool configuration
    update_pool_config "$config_file" "$max_children" "$start_servers" "$min_spare" "$max_spare"
    
    # Restart PHP-FPM using supervisorctl
    log_info "Restarting PHP-FPM using supervisorctl..."
    if command -v supervisorctl >/dev/null 2>&1; then
        supervisorctl restart php-fpm7.2 || true
        log_success "PHP-FPM restarted successfully"
    else
        log_warn "supervisorctl not found, PHP-FPM will need to be restarted manually"
    fi
    
    log_success "Dynamic PHP-FPM pool configuration completed"
}

# Run the main function
main