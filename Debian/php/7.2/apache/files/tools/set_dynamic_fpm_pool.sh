#!/bin/bash

# Dynamic PHP-FPM Pool Configuration
# This script calculates and sets optimal PHP-FPM pool settings based on container resources
# To be run during container startup

set -e

#############################################
# CONFIGURABLE PARAMETERS
#############################################

# Resource allocation (in MB)
SYSTEM_OVERHEAD=100       # Base system processes overhead
APACHE_OVERHEAD=150       # Apache processes memory usage
SUPERVISOR_OVERHEAD=20    # Supervisor process memory usage
OTHER_SERVICES=50         # Other services memory usage
MIN_MEMORY_THRESHOLD=100  # Minimum memory required for PHP-FPM to function

# PHP-FPM process settings
DEFAULT_PROCESS_MEMORY=25 # Default memory per PHP-FPM process in MB if can't be detected

# CPU allocation factors
CPU_MULTIPLIER_STANDARD=6  # Standard multiplier for CPU-based worker calculation
CPU_MULTIPLIER_HIGH_MEM=12 # Higher multiplier for memory-rich systems
MEMORY_CPU_RATIO=1024      # Memory (MB) per CPU core threshold for high memory systems

# Worker calculation factors
START_SERVERS_FACTOR=4     # Divisor for calculating pm.start_servers
MIN_SPARE_FACTOR=6         # Divisor for calculating pm.min_spare_servers
MAX_SPARE_FACTOR=3         # Divisor for calculating pm.max_spare_servers

# PHP-FPM configuration file path
PHP_FPM_CONFIG="/etc/php/7.2/fpm/pool.d/www.conf"

# PHP-FPM service name for supervisor
PHP_FPM_SERVICE="php-fpm7.2"

#############################################
# END OF CONFIGURABLE PARAMETERS
#############################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Global variables for PHP-FPM settings
FPM_MAX_CHILDREN=0
FPM_START_SERVERS=0
FPM_MIN_SPARE=0
FPM_MAX_SPARE=0

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
    local avg_process_memory=${3:-$DEFAULT_PROCESS_MEMORY} # Use the default value from parameters
    
    local total_overhead=$((SYSTEM_OVERHEAD + APACHE_OVERHEAD + SUPERVISOR_OVERHEAD + OTHER_SERVICES))
    local available_for_fpm=$((memory_limit_mb - total_overhead))
    
    if [ "$available_for_fpm" -lt "$MIN_MEMORY_THRESHOLD" ]; then
        log_error "Insufficient memory for PHP-FPM (${available_for_fpm}MB available)"
        # Use minimal settings
        FPM_MAX_CHILDREN=5
        FPM_START_SERVERS=1
        FPM_MIN_SPARE=1
        FPM_MAX_SPARE=3
        return
    fi
    
    # Calculate and display all methods
    log_info "PHP-FPM Pool Size Calculations:"
    log_info "Memory allocation analysis:"
    log_info "  System overhead: ${SYSTEM_OVERHEAD}MB"
    log_info "  Apache: ${APACHE_OVERHEAD}MB"
    log_info "  Supervisor: ${SUPERVISOR_OVERHEAD}MB"
    log_info "  Other services: ${OTHER_SERVICES}MB"
    log_info "  Total overhead: ${total_overhead}MB"
    log_info "  Available for PHP-FPM: ${available_for_fpm}MB"

    # Calculate memory-based limit
    local memory_based_children=$((available_for_fpm / avg_process_memory))
    log_info "Memory-based calculation: ${memory_based_children} workers (${available_for_fpm}MB ÷ ${avg_process_memory}MB per process)"

    # Calculate CPU-based limit
    local cpu_multiplier=$CPU_MULTIPLIER_STANDARD
    if [ "$memory_limit_mb" -gt $((cpu_cores * MEMORY_CPU_RATIO)) ]; then
        cpu_multiplier=$CPU_MULTIPLIER_HIGH_MEM
    fi
    local cpu_based_limit=$((cpu_cores * cpu_multiplier))
    log_info "CPU-based calculation: ${cpu_based_limit} workers (${cpu_cores} cores × ${cpu_multiplier})"

    # Calculate balanced approach if needed
    local balanced_value=""
    local optimal_max_children
    if [ "$memory_based_children" -gt "$cpu_based_limit" ] && [ "$memory_based_children" -gt $((cpu_based_limit * 2)) ]; then
        balanced_value=$(( (memory_based_children + cpu_based_limit) / 2 ))
        log_info "Balanced calculation: ${balanced_value} workers (average of memory and CPU limits)"
    fi

    # Determine which value to use and mark it
    if [ -n "$balanced_value" ]; then
        optimal_max_children=$balanced_value
        log_info "► RECOMMENDED: Balanced value (${optimal_max_children}) - prevents CPU contention while utilizing memory"
    elif [ "$memory_based_children" -gt "$cpu_based_limit" ]; then
        optimal_max_children=$cpu_based_limit
        log_info "► RECOMMENDED: CPU-based value (${optimal_max_children}) - prevents CPU contention"
    else
        optimal_max_children=$memory_based_children
        log_info "► RECOMMENDED: Memory-based value (${optimal_max_children}) - maximizes memory usage"
    fi
    
    # Calculate other settings
    local optimal_start_servers=$((optimal_max_children / START_SERVERS_FACTOR))
    local optimal_min_spare=$((optimal_max_children / MIN_SPARE_FACTOR))
    local optimal_max_spare=$((optimal_max_children / MAX_SPARE_FACTOR))
    
    # Ensure minimum values
    if [ "$optimal_start_servers" -lt 1 ]; then optimal_start_servers=1; fi
    if [ "$optimal_min_spare" -lt 1 ]; then optimal_min_spare=1; fi
    if [ "$optimal_max_spare" -lt 2 ]; then optimal_max_spare=2; fi
    
    # Set global variables instead of returning values
    FPM_MAX_CHILDREN=$optimal_max_children
    FPM_START_SERVERS=$optimal_start_servers
    FPM_MIN_SPARE=$optimal_min_spare
    FPM_MAX_SPARE=$optimal_max_spare
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
    
    # PHP-FPM configuration file
    local config_file="$PHP_FPM_CONFIG"
    
    if [ ! -f "$config_file" ]; then
        log_error "PHP-FPM configuration file not found: $config_file"
        exit 1
    fi
    
    log_info "Using PHP-FPM configuration file: $config_file"
    
    # Determine average PHP-FPM process memory
    local avg_process_memory=$DEFAULT_PROCESS_MEMORY  # Use default value from parameters
    
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
                total_memory=$(awk "BEGIN {print $total_memory + $proc_memory}")
                process_count=$((process_count + 1))
            fi
        done
        
        if [ "$process_count" -gt 0 ]; then
            avg_process_memory=$(awk "BEGIN {printf \"%.0f\", $total_memory / $process_count}")
            log_info "Detected average PHP-FPM process memory: ${avg_process_memory}MB"
        fi
    else
        log_info "Using default average PHP-FPM process memory: ${avg_process_memory}MB"
    fi
    
    # Calculate optimal settings
    log_info "Calculating optimal PHP-FPM settings..."
    calculate_fpm_settings "$memory_limit_mb" "$cpu_cores" "$avg_process_memory"
    
    # Note: The detailed calculation methods are displayed by the calculate_fpm_settings function
    log_info "Final PHP-FPM settings to be applied:"
    log_info "  pm.max_children = $FPM_MAX_CHILDREN"
    log_info "  pm.start_servers = $FPM_START_SERVERS"
    log_info "  pm.min_spare_servers = $FPM_MIN_SPARE"
    log_info "  pm.max_spare_servers = $FPM_MAX_SPARE"
    
    # Update pool configuration
    update_pool_config "$config_file" "$FPM_MAX_CHILDREN" "$FPM_START_SERVERS" "$FPM_MIN_SPARE" "$FPM_MAX_SPARE"
    
    # Restart PHP-FPM using supervisorctl
    log_info "Restarting PHP-FPM using supervisorctl..."
    if command -v supervisorctl >/dev/null 2>&1; then
        supervisorctl restart "$PHP_FPM_SERVICE" || true
        log_success "PHP-FPM restarted successfully"
    else
        log_warn "supervisorctl not found, PHP-FPM will need to be restarted manually"
    fi
    
    log_success "Dynamic PHP-FPM pool configuration completed"
}

# Run the main function
main
